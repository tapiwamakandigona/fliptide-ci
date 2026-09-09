#!/usr/bin/env python3
"""Exercise the real code6 release using Android's observed UI hierarchy.

Fresh disposable emulator only. No Dart instrumentation, mocking, purchases,
ad taps, external links, app-data clearing or changes to the installed APK.
"""
import json
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

PACKAGE = "com.tsorostudios.fliptide"
ACTIVITY = PACKAGE + "/.MainActivity"


def adb(*args, timeout=45):
    p = subprocess.run(["adb", *args], capture_output=True, text=True, timeout=timeout)
    if p.returncode:
        raise RuntimeError(p.stdout + p.stderr)
    return p.stdout.strip()


def label(node):
    text = node.get("content-desc") or node.get("text") or ""
    return re.sub(r"\s+", " ", text.replace("\\n", "\n")).strip()


def dump(out, name):
    adb("shell", "uiautomator", "dump", "/sdcard/journey.xml")
    text = adb("shell", "cat", "/sdcard/journey.xml")
    (out / f"{name}.xml").write_text(text)
    return list(ET.fromstring(text).iter("node"))


def wait_ui(out, name, predicate, timeout=45):
    until = time.monotonic() + timeout
    while time.monotonic() < until:
        nodes = dump(out, name)
        if predicate(nodes):
            return nodes
        time.sleep(1)
    raise RuntimeError(f"UI condition not reached: {name}; labels={[label(n) for n in nodes if label(n)]}")


def has(nodes, text):
    return any(text in label(n) for n in nodes)


def tap_node(nodes, predicate):
    found = [n for n in nodes if predicate(label(n)) and n.get("clickable") == "true"]
    if len(found) != 1:
        raise RuntimeError(f"Expected one observed enabled tap target; got {len(found)}")
    node = found[0]
    if node.get("enabled") != "true":
        raise RuntimeError("Tap target is disabled")
    x1, y1, x2, y2 = map(int, re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node["bounds"]).groups())
    adb("shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))


def capture(out, name):
    adb("shell", "screencap", "-p", f"/sdcard/{name}.png")
    adb("pull", f"/sdcard/{name}.png", str(out / f"{name}.png"))
    (out / f"{name}-activity.txt").write_text(adb("shell", "dumpsys", "activity", "activities"))


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    if adb("shell", "getprop", "ro.kernel.qemu") != "1":
        raise SystemExit("Refusing to drive a non-emulator device")
    package = adb("shell", "dumpsys", "package", PACKAGE)
    if not re.search(r"\bversionCode=6\b", package) or "versionName=0.3.2" not in package:
        raise SystemExit("Expected the independently verified 0.3.2/code6")
    (out / "installed-package.txt").write_text(package)
    result = {"scope": "Fresh stock Android emulator; no actual phone or Play purchase", "checks": {}}
    initial_pid = adb("shell", "pidof", PACKAGE)
    adb("logcat", "-c")
    try:
        title = wait_ui(out, "fresh-title", lambda ns: has(ns, "PLAY") and has(ns, "First Light"))
        capture(out, "fresh-title")
        result["checks"]["fresh_title_and_first_level"] = True
        tap_node(title, lambda s: s.startswith("PLAY") and "First Light" in s)
        start = wait_ui(out, "level-start", lambda ns: has(ns, "First Light") and has(ns, "attempt 0"))
        capture(out, "level-start")
        size = re.search(r"Physical size: (\d+)x(\d+)", adb("shell", "wm", "size"))
        if size is None:
            raise RuntimeError("Cannot determine actual emulator display size")
        adb("shell", "input", "tap", str(int(size[1]) // 2), str(int(size[2]) // 2))
        first = wait_ui(out, "first-death", lambda ns: has(ns, "attempt 1") and has(ns, "RETRY"))
        capture(out, "first-death")
        result["checks"]["first_attempt_reaches_death_overlay"] = True
        tap_node(first, lambda s: s == "RETRY")
        second = wait_ui(out, "second-death", lambda ns: has(ns, "attempt 2") and has(ns, "RETRY"))
        capture(out, "second-death")
        result["checks"]["retry_advances_attempt_counter"] = True
        before_background = adb("shell", "pidof", PACKAGE)
        adb("shell", "input", "keyevent", "3")
        time.sleep(2)
        (out / "resume-command.txt").write_text(adb("shell", "am", "start", "-W", "-n", ACTIVITY))
        resumed = wait_ui(out, "resumed", lambda ns: has(ns, "attempt 2") and has(ns, "RETRY"))
        after_background = adb("shell", "pidof", PACKAGE)
        if initial_pid != before_background or before_background != after_background:
            raise RuntimeError("Application process changed unexpectedly during journey/resume")
        capture(out, "resumed")
        result["checks"]["background_resume_retains_process_and_attempt"] = True
        tap_node(resumed, lambda s: s == "‹")
        wait_ui(out, "returned-title", lambda ns: has(ns, "PLAY") and has(ns, "First Light"))
        capture(out, "returned-title")
        result["checks"]["returns_to_title"] = True
        adb("root")
        adb("wait-for-device")
        prefs = adb("shell", "cat", f"/data/user/0/{PACKAGE}/shared_prefs/FlutterSharedPreferences.xml")
        (out / "real-play-saved-preferences.xml").write_text(prefs)
        nodes = list(ET.fromstring(prefs))
        deaths = next((int(n.get("value")) for n in nodes if n.get("name") == "flutter.deaths"), None)
        if deaths != 2:
            raise RuntimeError(f"Expected both real attempts to persist: deaths={deaths}")
        result["checks"]["both_real_attempts_persisted"] = True
        result["pid"] = after_background
        result["passed"] = True
    except Exception as error:
        result["passed"] = False
        result["failure"] = str(error)
        raise
    finally:
        logs = adb("logcat", "-b", "main,system,crash", "-d", "-v", "threadtime")
        (out / "logcat.txt").write_text(logs)
        (out / "result.json").write_text(json.dumps(result, indent=2))
        print(json.dumps(result), flush=True)


if __name__ == "__main__":
    main()
