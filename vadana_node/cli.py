"""
vadana-node — run a worker that renders heavy video jobs for a vadana master.

    vadana-node config --master https://HOST:8443 --ca ca.crt --cert node.crt --key node.key
    vadana-node test      # verify the mTLS connection to the master
    vadana-node run       # start the worker loop
"""
from __future__ import annotations

import argparse
import asyncio
import json
import logging
import sys

from .worker import NodeConfig, client_context, run_worker

DEFAULT_CONFIG = "config.json"


def _load(path: str) -> NodeConfig:
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    return NodeConfig(master=d["master"], ca=d.get("ca"), cert=d.get("cert"),
                      key=d.get("key"), poll_interval=float(d.get("poll_interval", 5.0)),
                      workers=int(d.get("workers", 1)))


def cmd_config(args) -> int:
    cfg = {"master": args.master, "ca": args.ca, "cert": args.cert,
           "key": args.key, "poll_interval": float(args.poll or 5.0),
           "workers": int(args.workers or 1)}
    with open(args.config, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2)
    print(f"✓ wrote {args.config} (master {args.master}, {cfg['workers']} worker(s))")
    return 0


def cmd_test(args) -> int:
    import aiohttp
    cfg = _load(args.config)

    async def ping():
        ctx = client_context(cfg.ca, cfg.cert, cfg.key) if cfg.ca else None
        conn = aiohttp.TCPConnector(ssl=ctx) if ctx else aiohttp.TCPConnector()
        async with aiohttp.ClientSession(connector=conn, base_url=cfg.master) as s:
            r = await s.get("/ping")
            print(f"✓ connected to {cfg.master}: {await r.json()}")

    try:
        asyncio.run(ping())
        return 0
    except Exception as e:
        print(f"✗ cannot reach {cfg.master}: {e}")
        return 1


def cmd_run(args) -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    cfg = _load(args.config)
    n = max(1, int(args.workers or cfg.workers))
    print(f"{n} worker(s) connecting to {cfg.master} …")

    async def _all():
        await asyncio.gather(*[run_worker(cfg) for _ in range(n)])

    asyncio.run(_all())
    return 0


def cmd_enroll(args) -> int:
    import base64
    import io
    import tarfile
    blob = (args.bundle or sys.stdin.read()).strip()
    buf = io.BytesIO(base64.b64decode(blob))
    with tarfile.open(fileobj=buf, mode="r:gz") as tar:
        for name in ("ca.crt", "node.crt", "node.key"):
            with open(name, "wb") as f:
                f.write(tar.extractfile(name).read())
        master = tar.extractfile("master").read().decode().strip()
    cfg = {"master": master, "ca": "ca.crt", "cert": "node.crt", "key": "node.key",
           "workers": int(args.workers or 1)}
    with open(args.config, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2)
    print(f"✓ enrolled (master {master}, {cfg['workers']} worker(s))")
    return 0


def main(argv=None) -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    p = argparse.ArgumentParser(prog="vadana-node")
    sub = p.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("config")
    c.add_argument("--master", required=True)
    c.add_argument("--ca", required=True)
    c.add_argument("--cert", required=True)
    c.add_argument("--key", required=True)
    c.add_argument("--poll")
    c.add_argument("--workers")
    c.add_argument("--config", default=DEFAULT_CONFIG)

    for name in ("test", "run"):
        sp = sub.add_parser(name)
        sp.add_argument("--config", default=DEFAULT_CONFIG)
        if name == "run":
            sp.add_argument("--workers", help="number of parallel worker loops (default 1)")

    e = sub.add_parser("enroll")
    e.add_argument("bundle", nargs="?", help="the base64 bundle (or piped on stdin)")
    e.add_argument("--workers")
    e.add_argument("--config", default=DEFAULT_CONFIG)

    args = p.parse_args(argv)
    return {"config": cmd_config, "test": cmd_test, "run": cmd_run,
            "enroll": cmd_enroll}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
