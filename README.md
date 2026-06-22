<div align="center">

# vadana-node

**A lightweight worker that renders heavy video jobs for a [vadana-extractor](https://github.com/phoseinq/vadana-extractor) master.**
**یک نودِ سبک که ساختِ ویدیوهای سنگین را برای مسترِ [vadana-extractor](https://github.com/phoseinq/vadana-extractor) به عهده می‌گیرد.**

</div>

---

## What it is

The vadana master (the Telegram bot) builds class videos. When its own video slot
is busy, it hands the job to a worker node over **mutually-authenticated TLS**. The
node has **no Iran proxy and no Telegram token** — the master ships it everything it
needs (the recording package plus the shared PDFs, in one bundle), the node renders,
and posts the mp4 back. So a node is just CPU + ffmpeg.

If no node is connected, the master builds everything itself — nothing changes.

## Run a node

**1. On the master**, register this node and get a bundle:

```bash
vadana node init --host <MASTER_IP>      # once: creates the CA + server cert
vadana node add mynode --host <MASTER_IP>
```

That prints three files to copy: `ca.crt`, `node-mynode.crt`, `node-mynode.key`.

**2. On the node machine**, one command — it asks Docker or native:

```bash
curl -fsSL https://raw.githubusercontent.com/phoseinq/vadana-node/main/install.sh | bash
```

Put the three files in the install dir as `ca.crt`, `node.crt`, `node.key`. A native
install gives you a **`vadana-node`** command (and an interactive menu):

```bash
vadana-node                 # menu: configure, test, start, logs
# or directly:
vadana-node configure       # master URL + cert paths + workers
vadana-node test            # verify the mTLS handshake
vadana-node start           # run as a systemd service
```

**Multiple workers** on one machine (parallel builds):

```bash
vadana-node configure       # set "workers" when prompted, or:
vadana-node workers 3       # native (updates config + restarts the service)
docker compose up -d --build --scale worker=3     # Docker
```

Back on the master, `vadana node status` shows which workers are connected.

## Requirements

- Python **3.11+**, `ffmpeg`/`ffprobe` on `PATH`
- Reachability to the master's node-API port (default `8443`)
- The three cert files from `vadana node add`

## Security

mTLS both ways: the node verifies the master against the pinned CA, and the master
verifies (and allow-lists) the node's certificate. Revoke a node from the master
with `vadana node remove <name>`. The node stores no secrets beyond its own cert.

<div align="center"><sub>MIT · <a href="https://github.com/phoseinq">phoseinq</a></sub></div>
