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

**2. On the node machine**, put those three files here as `ca.crt`, `node.crt`,
`node.key` (rename on copy), then either Docker or native:

**Docker (recommended):**

```bash
# config.json + ca.crt + node.crt + node.key all sit next to docker-compose.yml
python -m vadana_node.cli config --master https://<MASTER_IP>:8443 \
    --ca ca.crt --cert node.crt --key node.key
docker compose up -d --build
docker compose logs -f
```

**Native:**

```bash
pip install -r requirements.txt           # + ffmpeg on PATH
python -m vadana_node.cli config --master https://<MASTER_IP>:8443 \
    --ca ca.crt --cert node.crt --key node.key
python -m vadana_node.cli test            # verify the mTLS handshake
python -m vadana_node.cli run             # start claiming jobs
```

## Requirements

- Python **3.11+**, `ffmpeg`/`ffprobe` on `PATH`
- Reachability to the master's node-API port (default `8443`)
- The three cert files from `vadana node add`

## Security

mTLS both ways: the node verifies the master against the pinned CA, and the master
verifies (and allow-lists) the node's certificate. Revoke a node from the master
with `vadana node remove <name>`. The node stores no secrets beyond its own cert.

<div align="center"><sub>MIT · <a href="https://github.com/phoseinq">phoseinq</a></sub></div>
