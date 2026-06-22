"""
The worker loop: connect to the master over mTLS, claim a video job, download the
bundle (recording zip + the shared PDFs the master appended under _pdfs/), render
it, and post the mp4 back. The node holds no Iran proxy and no Telegram token — it
only does CPU work, so it stays small and low-trust.
"""
from __future__ import annotations

import asyncio
import logging
import os
import shutil
import ssl
import tempfile
import zipfile
from dataclasses import dataclass

import aiohttp

log = logging.getLogger("vadana.node")


@dataclass
class NodeConfig:
    master: str                     # https://master-host:8443
    ca: str | None = None           # path to ca.crt (None -> plain http, for tests)
    cert: str | None = None         # path to this node's cert
    key: str | None = None          # path to this node's key
    poll_interval: float = 5.0
    workers: int = 1                # parallel worker loops (run --workers overrides)


def client_context(ca: str, cert: str, key: str) -> ssl.SSLContext:
    """mTLS client context: present the node cert, verify the master against the CA.
    Hostname checking is off — the private CA plus the required client cert are the
    trust anchor, and the master's IP may change."""
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ctx.load_cert_chain(cert, key)
    ctx.load_verify_locations(ca)
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_REQUIRED
    return ctx


def _render(bundle_path: str, work: str, out: str, prog) -> str | None:
    """Render the bundle to `out`. Extracts the PDFs the master appended under
    _pdfs/ (sorted by name = page order) and uses them as backgrounds. Reuses the
    exact vadana render pipeline (denoise included)."""
    from .render import video as video_mod
    zf = zipfile.ZipFile(bundle_path)
    pdf_dir = os.path.join(work, "pdfs")
    os.makedirs(pdf_dir, exist_ok=True)
    pdfs = []
    for name in sorted(n for n in zf.namelist() if n.startswith("_pdfs/") and n.lower().endswith(".pdf")):
        dst = os.path.join(pdf_dir, os.path.basename(name))
        with open(dst, "wb") as f:
            f.write(zf.read(name))
        pdfs.append(dst)
    res = video_mod.make_full_video(zf, work, out, 2, 4.0, prog, pdfs or None)
    if res is None:
        res = video_mod.make_media_video(zf, work, out, pdfs or None, 2, prog)
    return res


async def _claim(s):
    r = await s.post("/jobs/claim")
    return await r.json() if r.status == 200 else None


async def _download(s, job_id, dst):
    r = await s.get(f"/jobs/{job_id}/package")
    r.raise_for_status()
    with open(dst, "wb") as f:
        async for chunk in r.content.iter_chunked(65536):
            f.write(chunk)


async def _post_progress(s, job_id, latest):
    try:
        await s.post(f"/jobs/{job_id}/progress", json={"stage": latest["stage"], "pct": latest["pct"]})
    except Exception:
        pass


async def _handle(s, job):
    job_id = job["job_id"]
    work = tempfile.mkdtemp(prefix="vn_")
    bundle = os.path.join(work, "bundle.zip")
    out = os.path.join(work, "out.mp4")
    try:
        log.info("job %s: downloading bundle", job_id)
        await _download(s, job_id, bundle)
        latest = {"stage": "render", "pct": 0.0}

        def prog(stage, pct):
            latest["stage"], latest["pct"] = stage, float(pct)

        rt = asyncio.create_task(asyncio.to_thread(_render, bundle, work, out, prog))
        while not rt.done():
            await asyncio.sleep(2.0)
            await _post_progress(s, job_id, latest)
        await rt                                       # re-raises a render failure
        log.info("job %s: posting result", job_id)
        with open(out, "rb") as f:
            await s.post(f"/jobs/{job_id}/result", data=f)
    except Exception as e:
        log.error("job %s failed: %s", job_id, e)
        try:
            await s.post(f"/jobs/{job_id}/fail", json={"reason": str(e)[:200]})
        except Exception:
            pass
    finally:
        shutil.rmtree(work, ignore_errors=True)


def _session(cfg: NodeConfig):
    if cfg.ca:
        conn = aiohttp.TCPConnector(ssl=client_context(cfg.ca, cfg.cert, cfg.key))
    else:
        conn = aiohttp.TCPConnector()                  # plain http (tests only)
    return aiohttp.ClientSession(connector=conn, base_url=cfg.master)


async def run_worker(cfg: NodeConfig, once: bool = False) -> None:
    async with _session(cfg) as s:
        connected = None                               # None=unknown, True/False=last known state
        while True:
            job = None
            try:
                r = await s.get("/ping")               # connection check + heartbeat
                r.raise_for_status()                   # 403 (cert not allowed) / 5xx count as down
                if connected is not True:
                    log.info("✓ connected to %s", cfg.master)
                    connected = True
                job = await _claim(s)
                if job:
                    await _handle(s, job)
            except Exception as e:
                if connected is not False:             # log the drop once, then keep retrying
                    log.warning("✗ disconnected from %s (%s) — reconnecting every %ss",
                                cfg.master, e, cfg.poll_interval)
                    connected = False
            if once:
                return
            await asyncio.sleep(cfg.poll_interval)
