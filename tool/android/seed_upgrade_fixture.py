#!/usr/bin/env python3
"""Seed SYNTHETIC progress into a disposable rooted emulator's code5 install.

No user data or purchase entitlement is copied. The fixture is intentionally
non-Supporter; billing acceptance must use real Play Billing separately.
"""
import datetime
import hashlib
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

PACKAGE = "com.tsorostudios.fliptide"
REMOTE = f"/data/user/0/{PACKAGE}/shared_prefs/FlutterSharedPreferences.xml"


def adb(*args, timeout=45):
    p = subprocess.run(["adb", *args], capture_output=True, text=True, timeout=timeout)
    if p.returncode:
        raise RuntimeError(p.stdout + p.stderr)
    return p.stdout.strip()


def values(xml):
    root = ET.fromstring(xml)
    return {node.attrib["name"]: (node.tag, node.attrib.get("value", node.text or "")) for node in root}


def main():
    mode, out_path = sys.argv[1:3]
    out = Path(out_path)
    out.mkdir(parents=True, exist_ok=True)
    if adb("shell", "getprop", "ro.kernel.qemu") != "1":
        raise SystemExit("Refusing fixture operation outside a disposable emulator")
    if mode == "seed":
        apk = Path(sys.argv[3])
        if hashlib.sha256(apk.read_bytes()).hexdigest() != "16464b50d482b0e25d8870e76bba6562369e0a67537185fd322bb3a50ba7fd48":
            raise SystemExit("Expected exact shipped code5 baseline")
        adb("install", str(apk), timeout=120)
        adb("root")
        adb("wait-for-device")
        if adb("shell", "id", "-u") != "0":
            raise SystemExit("Fixture requires the disposable Google APIs emulator's root shell")
        dump = adb("shell", "dumpsys", "package", PACKAGE)
        (out / "installed-code5.txt").write_text(dump)
        # Android 15 labels this appId (verified in baseline package dump);
        # older versions used userId. User 0 is required for this fixture.
        if "User 0:" not in dump:
            raise SystemExit("Fixture requires the disposable emulator's primary user")
        user = re.search(r"\b(?:appId|userId)=(\d+)", dump)
        if not user:
            raise SystemExit("Cannot identify fixture owner UID")
        utc_date = adb("shell", "date", "-u", "+%Y-%m-%d")
        day = (datetime.date.fromisoformat(utc_date) - datetime.date(2026, 1, 1)).days + 1
        root = ET.Element("map")
        for name, value in {
            "lvl.t1l1.stars": 2, "streak": 4, "lastDay": day - 1,
            "deaths": 7, f"d{day}.attempts": 9,
        }.items():
            ET.SubElement(root, "long", name=f"flutter.{name}", value=str(value))
        ET.SubElement(root, "boolean", name="flutter.supporter", value="false")
        ET.SubElement(root, "boolean", name=f"flutter.d{day}.won", value="false")
        ghost = ET.SubElement(root, "string", name=f"flutter.d{day}.ghost")
        ghost.text = "3,not-a-frame,12"
        best = ET.SubElement(root, "string", name=f"flutter.d{day}.best")
        best.text = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu0.42"
        payload = ET.tostring(root, encoding="unicode", xml_declaration=True)
        local = out / "synthetic-before.xml"
        local.write_text(payload)
        adb("shell", "mkdir", "-p", REMOTE.rsplit("/", 1)[0])
        adb("push", str(local), REMOTE)
        adb("shell", "chown", "-R", f"{user[1]}:{user[1]}", REMOTE.rsplit("/", 1)[0])
        adb("shell", "chmod", "700", REMOTE.rsplit("/", 1)[0])
        adb("shell", "chmod", "600", REMOTE)
        adb("shell", "restorecon", "-R", REMOTE.rsplit("/", 1)[0])
        actual = adb("shell", "cat", REMOTE)
        assert values(actual) == values(payload)
        (out / "fixture.json").write_text(json.dumps({
            "synthetic": True,
            "source_version": 5,
            "day": day,
            "expected": values(payload),
            "no_purchase_simulation": True,
        }, indent=2))
        print("Seeded synthetic progress and damaged optional ghost into code5; no uninstall or clear")
    elif mode == "verify":
        before = json.loads((out / "fixture.json").read_text())
        text = adb("shell", "cat", REMOTE)
        (out / "synthetic-after.xml").write_text(text)
        actual = values(text)
        changed = {key: {"expected": expected, "actual": actual.get(key)}
                   for key, expected in before["expected"].items()
                   if actual.get(key) != tuple(expected)}
        report = {"synthetic": True, "all_existing_fixture_values_preserved": not changed, "changed": changed}
        (out / "upgrade-result.json").write_text(json.dumps(report, indent=2))
        print(json.dumps(report))
        if changed:
            raise SystemExit("FAIL: previously seeded progress was changed during update/cold launch")
    else:
        raise SystemExit("Expected seed or verify")


if __name__ == "__main__":
    main()
