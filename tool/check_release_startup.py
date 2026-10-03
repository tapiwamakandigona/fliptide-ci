#!/usr/bin/env python3
"""Check the exact reflective Room constructor in a release APK or AAB.

Dependency-free DEX inspection, deliberately separate from Dart source tests.
AndroidX Startup invokes WorkManager before the Flutter activity. Room calls
Class.forName("androidx.work.impl.WorkDatabase_Impl").newInstance(), which needs
the public no-argument constructor in the final minified binary.
"""
import hashlib
import json
import struct
import sys
import zipfile
from pathlib import Path

DATABASE = "Landroidx/work/impl/WorkDatabase_Impl;"


def uleb(data, offset):
    value = 0
    for shift in range(0, 35, 7):
        byte = data[offset]
        offset += 1
        value |= (byte & 0x7F) << shift
        if not byte & 0x80:
            return value, offset
    raise ValueError("Invalid DEX unsigned LEB128")


def declared_methods(data, wanted):
    if data[:4] != b"dex\n" or data[7] != 0:
        raise ValueError("Unsupported DEX header")
    if struct.unpack_from("<I", data, 40)[0] != 0x12345678:
        raise ValueError("Unsupported DEX byte order")
    strings_count, strings_offset = struct.unpack_from("<II", data, 56)
    types_count, types_offset = struct.unpack_from("<II", data, 64)
    _, protos_offset = struct.unpack_from("<II", data, 72)
    _, methods_offset = struct.unpack_from("<II", data, 88)
    classes_count, classes_offset = struct.unpack_from("<II", data, 96)
    strings = []
    for i in range(strings_count):
        offset = struct.unpack_from("<I", data, strings_offset + 4 * i)[0]
        _, offset = uleb(data, offset)
        end = data.index(b"\0", offset)
        strings.append(data[offset:end].decode("utf-8", errors="replace"))
    types = [
        strings[struct.unpack_from("<I", data, types_offset + 4 * i)[0]]
        for i in range(types_count)
    ]
    for i in range(classes_count):
        start = classes_offset + 32 * i
        class_index, flags = struct.unpack_from("<II", data, start)
        if types[class_index] != wanted:
            continue
        offset = struct.unpack_from("<I", data, start + 24)[0]
        if not offset:
            return {"class_flags": flags, "methods": []}
        counts = []
        for _ in range(4):
            value, offset = uleb(data, offset)
            counts.append(value)
        for _ in range(counts[0] + counts[1]):
            _, offset = uleb(data, offset)
            _, offset = uleb(data, offset)
        result = []
        for count in counts[2:]:
            method_index = 0
            for _ in range(count):
                delta, offset = uleb(data, offset)
                method_index += delta
                access, offset = uleb(data, offset)
                code_offset, offset = uleb(data, offset)
                owner, proto, name = struct.unpack_from(
                    "<HHI", data, methods_offset + 8 * method_index
                )
                _, return_type, parameters_offset = struct.unpack_from(
                    "<III", data, protos_offset + 12 * proto
                )
                parameters = []
                if parameters_offset:
                    size = struct.unpack_from("<I", data, parameters_offset)[0]
                    parameters = [
                        types[struct.unpack_from("<H", data, parameters_offset + 4 + 2 * j)[0]]
                        for j in range(size)
                    ]
                result.append({
                    "owner": types[owner],
                    "name": strings[name],
                    "descriptor": "(" + "".join(parameters) + ")" + types[return_type],
                    "access": access,
                    "has_code": code_offset != 0,
                })
        return {"class_flags": flags, "methods": result}
    return None


def inspect(path):
    path = Path(path)
    hits = []
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise ValueError("Release archive CRC failure")
        for name in archive.namelist():
            if name.endswith(".dex"):
                found = declared_methods(archive.read(name), DATABASE)
                if found is not None:
                    hits.append({"dex": name, **found})
    constructors = [
        method
        for hit in hits
        for method in hit["methods"]
        if method["name"] == "<init>" and method["descriptor"] == "()V"
    ]
    passed = (
        len(hits) == 1
        and not hits[0]["class_flags"] & 0x600  # neither abstract nor interface
        and len(constructors) == 1
        and constructors[0]["access"] & 0x1  # public
        and constructors[0]["has_code"]
    )
    return {
        "file": path.name,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "reflective_class": DATABASE,
        "class_count": len(hits),
        "public_noarg_constructors": constructors,
        "passed": bool(passed),
    }


if __name__ == "__main__":
    reports = [inspect(path) for path in sys.argv[1:]]
    if not reports:
        raise SystemExit("Usage: check_release_startup.py APK_OR_AAB [APK_OR_AAB ...]")
    print(json.dumps(reports, indent=2))
    if not all(report["passed"] for report in reports):
        raise SystemExit("FAIL: minified release is missing Room's public no-argument WorkDatabase_Impl constructor")
