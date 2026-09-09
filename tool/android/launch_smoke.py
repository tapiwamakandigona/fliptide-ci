#!/usr/bin/env python3
"""Native smoke of a real release APK on a disposable CI emulator.

Never use on a person's phone: this installs the supplied APK. It does not
uninstall, clear app data, alter the build, mock purchases or hide crashes.
An emulator pass is not an itel/ARM64 pass.
"""
import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path

PACKAGE = "com.tsorostudios.fliptide"
ACTIVITY = f"{PACKAGE}/.MainActivity"


def adb(*args, timeout=45):
    result = subprocess.run(
        ["adb", *args], text=True, capture_output=True, timeout=timeout
    )
    return result.returncode, result.stdout + result.stderr


def main():
    apk = Path(sys.argv[1])
    out = Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    report = {
        "apk_sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
        "package": PACKAGE,
        "device": {},
        "launches": [],
        "scope": "Stock x86_64 emulator, not physical itel or Play-generated ARM splits",
    }
    for prop in ("ro.build.version.sdk", "ro.build.version.release", "ro.product.model", "ro.product.cpu.abi"):
        report["device"][prop] = adb("shell", "getprop", prop)[1].strip()
    code, text = adb("install", "-r", str(apk), timeout=120)
    (out / "install.txt").write_text(text)
    if code != 0 or "Success" not in text:
        raise RuntimeError(f"Release APK install failed: {text}")
    (out / "installed-package.txt").write_text(adb("shell", "dumpsys", "package", PACKAGE)[1])
    failed = False
    for attempt in range(1, 4):
        adb("shell", "am", "force-stop", PACKAGE)
        adb("logcat", "-c")
        rc, start = adb("shell", "am", "start", "-W", "-n", ACTIVITY)
        (out / f"start-{attempt}.txt").write_text(start)
        time.sleep(8)
        pid_code, pid = adb("shell", "pidof", PACKAGE)
        logs = adb("logcat", "-b", "main,system,crash", "-d", "-v", "threadtime")[1]
        (out / f"logcat-{attempt}.txt").write_text(logs)
        activity = adb("shell", "dumpsys", "activity", "activities")[1]
        (out / f"activity-{attempt}.txt").write_text(activity)
        gfx = adb("shell", "dumpsys", "gfxinfo", PACKAGE)[1]
        (out / f"gfx-{attempt}.txt").write_text(gfx)
        adb("shell", "uiautomator", "dump", "/sdcard/launch.xml")
        adb("pull", "/sdcard/launch.xml", str(out / f"ui-{attempt}.xml"))
        adb("shell", "screencap", "-p", "/sdcard/launch.png")
        adb("pull", "/sdcard/launch.png", str(out / f"screen-{attempt}.png"))
        alive = pid_code == 0 and bool(pid.strip())
        foreground = any(PACKAGE in line and "ResumedActivity" in line for line in activity.splitlines())
        result = {
            "attempt": attempt,
            "am_start_exit": rc,
            "alive_after_8s": alive,
            "foreground": foreground,
            "pid": pid.strip(),
            "fatal_markers": [
                line for line in logs.splitlines()
                if re.search(r"FATAL EXCEPTION|Fatal signal|JNI DETECTED ERROR|Unable to (?:start activity|instantiate|load)|Could not (?:create|set up)|ClassNotFoundException|NoClassDefFoundError|UnsatisfiedLinkError|SIGABRT|SIGSEGV", line)
            ],
        }
        report["launches"].append(result)
        print(json.dumps(result), flush=True)
        (out / "summary.json").write_text(json.dumps(report, indent=2))
        if not alive or not foreground or rc != 0:
            failed = True
            break
    report["passed"] = not failed
    (out / "summary.json").write_text(json.dumps(report, indent=2))
    if failed:
        raise SystemExit("FAIL: shipped release did not remain running in the foreground; see captured native logs")
    print("PASS: three cold starts remain alive and foreground; inspect UI/log evidence separately")


if __name__ == "__main__":
    main()
