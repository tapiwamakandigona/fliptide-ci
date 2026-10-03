"""Prune verification (directive 2026-09-02i item 1).

Serves a web build dir locally at /fliptide-ci/ with gzip, throttles Chromium to
10 Mbps / 40 ms RTT (cache off), blocks every non-local host, and reports:
  * which files the loader actually requested (+ any 404)
  * raw and gzip bytes actually transferred to first frame
  * flutter-first-frame time
  * whether the solver autoplay (?auto=1) reaches a running game (screenshot)
Mode "skwasm" = what Chromium >= 119 loads. Mode "canvaskit" rewrites the
bootstrap in flight to force renderer "canvaskit" — the exact fallback path
Safari / Firefox / Chrome < 119 take — so the pruned package is proven for both.

Usage: CHROME_BIN=... python tool/webtest/verify_prune.py <build_dir> [skwasm|canvaskit]
"""
import asyncio, gzip, os, sys, threading, time
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from playwright.async_api import async_playwright

CHROME = os.environ.get("CHROME_BIN")
PORT = 8791
PREFIX = "/fliptide-ci/"


class GzHandler(SimpleHTTPRequestHandler):
    def log_message(self, *a):  # quiet
        pass

    def translate_path(self, path):
        path = path.split("?", 1)[0]
        if not path.startswith(PREFIX):
            return os.path.join(self.directory, "__nope__")
        return super().translate_path("/" + path[len(PREFIX):])

    def send_head(self):
        path = self.translate_path(self.path)
        if os.path.isdir(path):
            path = os.path.join(path, "index.html")
        if not os.path.isfile(path):
            self.send_error(404)
            return None
        with open(path, "rb") as f:
            data = gzip.compress(f.read(), 6)
        self.send_response(200)
        self.send_header("Content-Type", self.guess_type(path))
        self.send_header("Content-Encoding", "gzip")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        import io
        return io.BytesIO(data)

    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm", ".mjs": "text/javascript"}


def serve(directory):
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), partial(GzHandler, directory=directory))
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


async def run(build_dir, mode):
    srv = serve(build_dir)
    base = f"http://127.0.0.1:{PORT}{PREFIX}"
    requested, blocked, missing, errors = {}, [], [], []
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path=CHROME) if CHROME else await p.chromium.launch()
        ctx = await b.new_context(viewport={"width": 1280, "height": 720})
        await ctx.add_init_script("window.__fff=null; window.addEventListener('flutter-first-frame', ()=>{window.__fff=performance.now()});")
        pg = await ctx.new_page()
        pg.on("pageerror", lambda e: errors.append(str(e)))

        async def route(r):
            url = r.request.url
            if not url.startswith(f"http://127.0.0.1:{PORT}/"):
                blocked.append(url)
                await r.abort()
                return
            if mode == "canvaskit" and url.split("?")[0].endswith("flutter_bootstrap.js"):
                resp = await r.fetch()
                body = (await resp.body()).decode()
                assert 'canvasKitVariant: "full"' in body
                body = body.replace('canvasKitVariant: "full"', 'canvasKitVariant: "full", renderer: "canvaskit"')
                await r.fulfill(status=200, content_type="text/javascript", body=body)
                return
            await r.continue_()

        await pg.route("**/*", route)

        async def on_resp(resp):
            name = resp.url.split("?")[0].replace(base, "") or "index.html"
            if resp.status == 404:
                missing.append(name)
                return
            try:
                body = await resp.body()
                requested[name] = (len(body), len(gzip.compress(body, 6)))
            except Exception:
                pass

        pg.on("response", lambda r: asyncio.ensure_future(on_resp(r)))
        cdp = await ctx.new_cdp_session(pg)
        await cdp.send("Network.enable")
        await cdp.send("Network.setCacheDisabled", {"cacheDisabled": True})
        await cdp.send("Network.emulateNetworkConditions", {"offline": False, "latency": 40, "downloadThroughput": 10_000_000 / 8, "uploadThroughput": 5_000_000 / 8})
        await pg.goto(base + "?auto=1", wait_until="load")
        fff = None
        for _ in range(160):
            fff = await pg.evaluate("window.__fff")
            if fff:
                break
            await asyncio.sleep(0.25)
        first_frame_files = dict(requested)
        await asyncio.sleep(1.0)
        await pg.screenshot(path=f"prune_{mode}_0_title.png")
        await pg.mouse.click(640, 360)  # start
        await asyncio.sleep(6)
        await pg.screenshot(path=f"prune_{mode}_1_running.png")
        renderer = await pg.evaluate("(() => { const c=document.querySelector('flutter-view canvas, flt-glass-pane canvas, canvas'); return c ? (c.getContext ? 'canvas' : 'unknown') : 'no-canvas'; })()")
        await b.close()
    srv.shutdown()
    raw = sum(v[0] for v in first_frame_files.values())
    gz = sum(v[1] for v in first_frame_files.values())
    print(f"mode={mode}  first-frame={fff/1000 if fff else None} s  (10 Mbps / 40 ms, cache off)")
    print(f"files to first frame={len(first_frame_files)}  raw={raw/1e6:.2f} MB  gzip={gz/1e6:.2f} MB")
    for k, (r, g) in sorted(first_frame_files.items(), key=lambda kv: -kv[1][0])[:8]:
        print(f"  {r/1e6:5.2f} MB raw {g/1e6:5.2f} MB gz  {k}")
    print(f"404s: {missing}")
    print(f"blocked third-party requests: {blocked}")
    print(f"page errors: {errors}")
    print(f"renderer surface: {renderer}")
    ok = bool(fff) and not missing and not blocked and not errors and fff / 1000 <= 5 and gz <= 6_291_456
    print("RESULT:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    d = sys.argv[1]
    m = sys.argv[2] if len(sys.argv) > 2 else "skwasm"
    sys.exit(asyncio.run(run(d, m)))
