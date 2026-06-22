import asyncio
import socket

from aiohttp import web

from vadana_node import worker
from vadana_node.worker import NodeConfig, run_worker


def _free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


def _stub_app(state):
    routes = web.RouteTableDef()

    @routes.get("/ping")
    async def ping(r):
        return web.json_response({"ok": True})

    @routes.post("/jobs/claim")
    async def claim(r):
        if state["job"] and not state["claimed"]:
            state["claimed"] = True
            return web.json_response({"job_id": "j1", "rec_id": "rec1"})
        return web.Response(status=204)

    @routes.get("/jobs/{id}/package")
    async def pkg(r):
        return web.Response(body=state["bundle"])

    @routes.post("/jobs/{id}/progress")
    async def prog(r):
        state["progress"] = await r.json()
        return web.Response(status=204)

    @routes.post("/jobs/{id}/result")
    async def result(r):
        state["result"] = await r.read()
        return web.Response(status=204)

    @routes.post("/jobs/{id}/fail")
    async def fail(r):
        state["fail"] = await r.json()
        return web.Response(status=204)

    app = web.Application()
    app.add_routes(routes)
    return app


def test_worker_claims_downloads_renders_posts(monkeypatch):
    asyncio.run(_body(monkeypatch))


def test_worker_logs_disconnect_and_skips_claim_on_bad_ping(caplog):
    asyncio.run(_disconnect_body(caplog))


async def _disconnect_body(caplog):
    import logging

    routes = web.RouteTableDef()

    @routes.get("/ping")
    async def ping(r):
        return web.Response(status=403)               # cert not allowed -> counts as down

    @routes.post("/jobs/claim")
    async def claim(r):
        raise AssertionError("must not claim while disconnected")

    app = web.Application()
    app.add_routes(routes)
    port = _free_port()
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", port)
    await site.start()
    try:
        caplog.set_level(logging.WARNING)
        cfg = NodeConfig(master=f"http://127.0.0.1:{port}", poll_interval=0.01)
        await run_worker(cfg, once=True)              # must not raise, must not claim
        assert "disconnected" in caplog.text.lower()
    finally:
        await runner.cleanup()


async def _body(monkeypatch):
    state = {"job": True, "claimed": False, "bundle": b"PK\x03\x04stub-bundle",
             "progress": None, "result": None, "fail": None}

    # stub the heavy render so the test stays fast and ffmpeg-free
    def stub_render(bundle_path, work, out, prog):
        prog("encode", 80)
        with open(out, "wb") as f:
            f.write(b"RENDERED-MP4")
        return out
    monkeypatch.setattr(worker, "_render", stub_render)

    port = _free_port()
    runner = web.AppRunner(_stub_app(state))
    await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", port)
    await site.start()
    try:
        cfg = NodeConfig(master=f"http://127.0.0.1:{port}", poll_interval=0.1)
        await run_worker(cfg, once=True)
        assert state["claimed"] is True               # it claimed the job
        assert state["result"] == b"RENDERED-MP4"      # downloaded, rendered, posted the mp4
    finally:
        await runner.cleanup()
