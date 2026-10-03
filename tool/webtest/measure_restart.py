"""F3 measurement (web): restart latency death -> first accepted sim step, 10 samples via ?perf=1 + window.__fliptideRestartMs.
Usage: CHROME_BIN=... python tool/webtest/measure_restart.py http://localhost:8765/fliptide-ci/
"""
import os
import asyncio, sys, statistics
from playwright.async_api import async_playwright
CHROME = os.environ.get("CHROME_BIN")
BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8765/fliptide-ci/"
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path=CHROME) if CHROME else await p.chromium.launch()
        pg = await b.new_page(viewport={"width":1280,"height":720})
        await pg.goto(BASE+"?perf=1", wait_until="load"); await asyncio.sleep(4)
        await pg.mouse.click(640,360); await asyncio.sleep(0.3)  # start
        for i in range(10):
            # run without input until death (first hazard kills within ~2-4 s)
            for _ in range(400):
                st = await pg.evaluate("window.__fliptideState || ''")
                if st.startswith("dead"): break
                await asyncio.sleep(0.01)
            # hammer Space every 20 ms until the run restarts
            for _ in range(60):
                await pg.keyboard.press("Space")
                await asyncio.sleep(0.02)
                if (await pg.evaluate("window.__fliptideState || ''")).startswith("running"): break
        await asyncio.sleep(0.5)
        vals = await pg.evaluate("(window.__fliptideRestartMs||[])")
        print("restart ms samples:", vals)
        if vals: print(f"n={len(vals)} median={statistics.median(vals)} max={max(vals)}")
        await pg.screenshot(path="perf.png")
        await b.close()
asyncio.run(main())
