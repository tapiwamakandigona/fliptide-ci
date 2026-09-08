#!/usr/bin/env python3
"""Original Fliptide launch icon: a gold runner switching between two tides.

Palette is sourced verbatim from lib/game/palette.dart. No external artwork,
fonts, network access or runtime packages. Pillow is a build-time tool only.
Use --check to compare pixels and validate the existing resource contract.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
BG = "#0B0F1A"
SLAB = "#2A3352"
EDGE = "#4B5A8A"
GOLD = "#FFC93C"
GOLD_DARK = "#B8861B"
TEXT = "#F4F6FF"
SPIKE = "#FF4D5E"


def master() -> Image.Image:
    image = Image.new("RGB", (1024, 1024), BG)
    draw = ImageDraw.Draw(image)
    # Quiet corridor bands, asymmetrical hazard cue, legible without words.
    draw.rectangle((0, 0, 1024, 212), fill=SLAB)
    draw.rectangle((0, 812, 1024, 1024), fill=SLAB)
    draw.rectangle((0, 204, 1024, 215), fill=EDGE)
    draw.rectangle((0, 809, 1024, 820), fill=EDGE)
    draw.polygon([(722, 216), (826, 216), (774, 298)], fill=SPIKE)
    draw.polygon([(198, 809), (302, 809), (250, 727)], fill=SPIKE)
    # Opposed arcs say "flip", not "jump". Squared end caps echo the game.
    draw.arc((254, 264, 762, 762), 212, 354, fill=GOLD_DARK, width=33)
    draw.arc((254, 264, 762, 762), 32, 174, fill=GOLD, width=33)
    draw.polygon([(723, 441), (785, 489), (708, 508)], fill=GOLD_DARK)
    draw.polygon([(311, 516), (234, 535), (296, 583)], fill=GOLD)
    # Runner is a real readable focal point, not the default Flutter glyph.
    draw.rounded_rectangle((369, 363, 655, 653), radius=47, fill=GOLD_DARK)
    draw.rounded_rectangle((369, 349, 655, 629), radius=47, fill=GOLD)
    draw.rectangle((398, 380, 617, 395), fill=TEXT)
    draw.rounded_rectangle((449, 452, 482, 510), radius=10, fill=BG)
    draw.rounded_rectangle((549, 452, 582, 510), radius=10, fill=BG)
    return image


def outputs():
    image = master()
    targets = {
        f"android/app/src/main/res/mipmap-{density}/ic_launcher.png": size
        for density, size in [
            ("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
            ("xxhdpi", 144), ("xxxhdpi", 192),
        ]
    }
    targets.update({
        path.replace("/ic_launcher.png", "/ic_launcher_round.png"): size
        for path, size in list(targets.items())
    })
    targets.update({
        "web/favicon.png": 64,
        "web/icons/Icon-192.png": 192,
        "web/icons/Icon-512.png": 512,
        "web/icons/Icon-maskable-192.png": 192,
        "web/icons/Icon-maskable-512.png": 512,
        "docs/play-store/icon-512.png": 512,
    })
    return {
        path: image.resize((size, size), Image.Resampling.LANCZOS)
        for path, size in targets.items()
    }


def validate_xml():
    res = ROOT / "android/app/src/main/res"
    for folder in ["mipmap-anydpi-v26", "mipmap-anydpi-v33"]:
        for name in ["ic_launcher.xml", "ic_launcher_round.xml"]:
            tree = ET.parse(res / folder / name).getroot()
            assert tree.tag == "adaptive-icon"
            assert tree.find("foreground") is not None
            assert tree.find("background") is not None
            if folder.endswith("v33"):
                assert tree.find("monochrome") is not None
    vector = ET.parse(res / "drawable/ic_launcher_foreground.xml").getroot()
    android = "{http://schemas.android.com/apk/res/android}"
    assert vector.attrib[android + "viewportWidth"] == "108"
    assert vector.attrib[android + "viewportHeight"] == "108"
    manifest = ET.parse(ROOT / "android/app/src/main/AndroidManifest.xml").getroot()
    assert manifest.find("application").attrib[android + "roundIcon"] == "@mipmap/ic_launcher_round"


def main():
    check = argparse.ArgumentParser()
    check.add_argument("--check", action="store_true")
    args = check.parse_args()
    for name, expected in outputs().items():
        path = ROOT / name
        if args.check:
            assert path.is_file(), f"Missing {name}"
            actual = Image.open(path).convert("RGB")
            assert actual.size == expected.size, f"Size mismatch: {name}"
            assert actual.tobytes() == expected.tobytes(), f"Pixel mismatch: {name}"
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            expected.save(path, optimize=True)
    validate_xml()
    print(f"VERIFIED: {len(outputs())} original raster icons, adaptive/round/monochrome resource XML.")


if __name__ == "__main__":
    main()
