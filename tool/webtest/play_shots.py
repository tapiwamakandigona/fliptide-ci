"""Play Store phone screenshots: 8 real gameplay frames at 1080x1920 (360x640 @3x),
HUD visible, captured from the live (or local) web build — no mock-ups.
Usage: CHROME_BIN=... python tool/webtest/play_shots.py [BASE_URL] → docs/play-store/screens/*.png
Frames: 1 title · 2 code entry · 3 first run · 4 on the ceiling · 5 mid-course (solver)
        6 death overlay · 7 attempt 2 (fresh restart) · 8 CLEARED (solver)
Coordinates are for the 360x640 layout (CODE button top-right, start = centre tap).
"""
import asyncio, os, sys
from playwright.async_api import async_playwright

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8765/fliptide-ci/"
CHROME = os.environ.get("CHROME_BIN")
OUT = os.environ.get("SHOTS_OUT", "docs/play-store/screens")
VP = {"width": 360, "height": 640}
AUTO = BASE + ("&" if "?" in BASE else "?") + "auto=1"


async def fresh(ctx, url):
    pg = await ctx.new_page()
    errs = []
    pg.on("pageerror", lambda e: errs.append(str(e)))
    await pg.goto(url, wait_until="load")
    await pg.wait_for_selector("flutter-view, canvas", state="attached", timeout=60000)
    await asyncio.sleep(4)
    return pg, errs


async def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".png"):
            os.remove(os.path.join(OUT, f))
    all_errs = []
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path=CHROME) if CHROME else await p.chromium.launch()
        ctx = await b.new_context(viewport=VP, device_scale_factor=3, has_touch=True)

        # 1 title, 2 code entry
        pg, e = await fresh(ctx, BASE); all_errs += e
        await pg.screenshot(path=f"{OUT}/1-title.png")
        await pg.mouse.click(313, 43)          # CODE button
        await asyncio.sleep(1.0)
        await pg.screenshot(path=f"{OUT}/2-code-entry.png")
        await pg.close()

        # 3 first run, 4 flip, 6 death, 7 ghost + X on attempt 2
        pg, e = await fresh(ctx, BASE); all_errs += e
        await pg.mouse.click(180, 320); await asyncio.sleep(0.7)
        await pg.screenshot(path=f"{OUT}/3-first-run.png")
        await pg.keyboard.press("Space"); await asyncio.sleep(0.35)
        await pg.screenshot(path=f"{OUT}/4-on-the-ceiling.png")
        await asyncio.sleep(10)                # hands off → death
        await pg.screenshot(path=f"{OUT}/6-death.png")
        await pg.mouse.click(180, 320)         # tap anywhere → retry
        await asyncio.sleep(0.6)               # early in attempt 2 (sub-second restart)
        await pg.screenshot(path=f"{OUT}/7-attempt-2.png")
        await pg.close()

        # 5 mid-course, 8 cleared (solver autoplay)
        pg, e = await fresh(ctx, AUTO); all_errs += e
        await pg.mouse.click(180, 320)
        await asyncio.sleep(12)
        await pg.screenshot(path=f"{OUT}/5-mid-course.png")
        await asyncio.sleep(22)
        await pg.screenshot(path=f"{OUT}/8-cleared.png")
        await pg.close()
        await b.close()
    print("pageerrors:", all_errs, "→", sorted(os.listdir(OUT)))


asyncio.run(main())
