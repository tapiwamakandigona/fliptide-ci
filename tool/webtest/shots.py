"""Look-loop screenshots of the web build (DEMAND §8: phone portrait + desktop
landscape, read them every meaningful change).

Usage: python tool/webtest/shots.py [http://localhost:8765/] → shots/*.png
Requires: a static server where /fliptide-ci/ → build/web (base href), e.g.
  mkdir -p /work/temp/srv && ln -sfn $PWD/build/web /work/temp/srv/fliptide-ci && (cd /work/temp/srv && python3 -m http.server 8765 &)
CHROME_BIN may point at an existing Playwright chromium binary.
"""
import asyncio
import os
import sys

from playwright.async_api import async_playwright

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8765/fliptide-ci/"
CHROME = os.environ.get("CHROME_BIN")  # a Playwright chromium binary; unset = default install
OUT = os.environ.get("SHOTS_OUT", "shots")
VIEWPORTS = {
    "desktop": {"width": 1280, "height": 720},
    "phone": {"width": 390, "height": 844},
    "poki_small": {"width": 640, "height": 360},
    "small_portrait": {"width": 360, "height": 640},
}


async def run(page, name, vp):
    await page.goto(BASE, wait_until="load")
    # Flutter web: wait for the canvas to exist and the first frame to paint.
    await page.wait_for_selector("flutter-view, canvas", state="attached", timeout=60000)
    await asyncio.sleep(4.0)
    await page.screenshot(path=f"{OUT}/{name}_0_title.png")
    # Start, then flip a few times and capture mid-run frames.
    await page.mouse.click(vp["width"] // 2, vp["height"] // 2)
    await asyncio.sleep(0.6)
    await page.screenshot(path=f"{OUT}/{name}_1_run.png")
    await page.keyboard.press("Space")
    await asyncio.sleep(0.35)
    await page.screenshot(path=f"{OUT}/{name}_2_air.png")
    await asyncio.sleep(0.5)
    await page.keyboard.press("Space")
    await asyncio.sleep(1.2)
    await page.screenshot(path=f"{OUT}/{name}_3_late.png")
    # Let it die (no more input) and capture the death card.
    for _ in range(40):
        await asyncio.sleep(0.25)
    await page.screenshot(path=f"{OUT}/{name}_4_death.png")


async def main():
    os.makedirs(OUT, exist_ok=True)
    async with async_playwright() as p:
        browser = await p.chromium.launch(executable_path=CHROME) if CHROME else await p.chromium.launch()
        for name, vp in VIEWPORTS.items():
            ctx = await browser.new_context(viewport=vp, has_touch=(name == "phone"), device_scale_factor=1)
            page = await ctx.new_page()
            logs = []
            page.on("console", lambda m: logs.append(f"[{m.type}] {m.text}"))
            page.on("pageerror", lambda e: logs.append(f"[pageerror] {e}"))
            try:
                await run(page, name, vp)
            finally:
                errs = [l for l in logs if "error" in l.lower()]
                print(f"{name}: {len(logs)} console lines, {len(errs)} errors")
                for l in errs[:5]:
                    print("   ", l[:200])
                await ctx.close()
        await browser.close()
    print("done →", OUT)


if __name__ == "__main__":
    asyncio.run(main())
