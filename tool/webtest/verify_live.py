"""F7 verification: solver-driven ?auto=1 run on a live URL -> CLEARED, then SHARE -> clipboard text.
Usage: CHROME_BIN=... python tool/webtest/verify_live.py https://tapiwamakandigona.github.io/fliptide-ci/
"""
import os
import asyncio, sys
from playwright.async_api import async_playwright
CHROME = os.environ.get("CHROME_BIN")
BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8765/flip-ci/"
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path=CHROME) if CHROME else await p.chromium.launch()
        ctx = await b.new_context(viewport={"width":1280,"height":720}, permissions=["clipboard-read","clipboard-write"])
        pg = await ctx.new_page()
        errs=[]; pg.on("pageerror", lambda e: errs.append(str(e)[:200]))
        await pg.goto(BASE+"?auto=1", wait_until="load"); await asyncio.sleep(4)
        await pg.screenshot(path="live_auto_0_title.png")
        await pg.mouse.click(640,360)  # start
        await asyncio.sleep(6); await pg.screenshot(path="live_auto_1_mid.png")
        await asyncio.sleep(26); await pg.screenshot(path="live_auto_2_end.png")
        # click SHARE (text) → clipboard
        await pg.mouse.click(594, 647); await asyncio.sleep(0.8)  # SHARE sits in the bottom fifth since 198a1d6 (1280x720)
        txt = await pg.evaluate("navigator.clipboard.readText()")
        print("CLIPBOARD:\n"+txt); print("len", len(txt))
        await pg.screenshot(path="live_auto_3_shared.png")
        # code deep link
        
        print("pageerrors:", errs[:3])
        await b.close()
asyncio.run(main())
