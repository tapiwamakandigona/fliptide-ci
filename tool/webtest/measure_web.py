"""F2 measurement: compressed transfer to first playable frame + flutter-first-frame time,
network throttled to 10 Mbps / 40 ms RTT via CDP, cache disabled.
Usage: CHROME_BIN=... python tool/webtest/measure_web.py https://tapiwamakandigona.github.io/fliptide-ci/
"""
import os
import asyncio, sys, time
from playwright.async_api import async_playwright
CHROME = os.environ.get("CHROME_BIN")
BASE = sys.argv[1] if len(sys.argv) > 1 else "https://tapiwamakandigona.github.io/flip-ci/"
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path=CHROME) if CHROME else await p.chromium.launch()
        ctx = await b.new_context(viewport={"width":1280,"height":720})
        await ctx.add_init_script("window.__fff=null; window.addEventListener('flutter-first-frame', ()=>{window.__fff=performance.now()});")
        pg = await ctx.new_page()
        cdp = await ctx.new_cdp_session(pg)
        await cdp.send("Network.enable")
        await cdp.send("Network.setCacheDisabled", {"cacheDisabled": True})
        await cdp.send("Network.emulateNetworkConditions", {"offline": False, "latency": 40, "downloadThroughput": 10_000_000/8, "uploadThroughput": 5_000_000/8})
        enc = {}
        async def on_fin(r):
            try:
                enc[r.url.split('/')[-1] or 'index'] = (await r.body(), r.headers.get('content-encoding',''))
            except Exception: pass
        sizes={}
        def on_resp(r):
            asyncio.ensure_future(on_fin(r))
        pg.on("response", on_resp)
        t0=time.time()
        await pg.goto(BASE, wait_until="load")
        fff=None
        for i in range(120):
            fff = await pg.evaluate("window.__fff")
            if fff: break
            await asyncio.sleep(0.25)
        wall=time.time()-t0
        await asyncio.sleep(1)
        await pg.screenshot(path="throttled_first.png")
        # transfer sizes from CDP would be ideal; approximate gz by re-compressing bodies when server sent gzip
        import gzip
        raw=0; gz=0
        for k,(body,ce) in enc.items():
            raw+=len(body); gz+= len(gzip.compress(body, 6)) if ce else len(body)
        print(f"requests={len(enc)} raw={raw/1e6:.2f} MB  est_gz_transfer={gz/1e6:.2f} MB")
        for k,(body,ce) in sorted(enc.items(), key=lambda kv:-len(kv[1][0]))[:5]: print(f"  {len(body)/1e6:5.2f} MB raw  enc={ce or 'none'}  {k}")
        print(f"flutter-first-frame at {fff/1000 if fff else None} s (perf.now) ; wall since goto {wall:.1f}s ; throttle 10 Mbps / 40 ms RTT, cache disabled")
        await b.close()
asyncio.run(main())
