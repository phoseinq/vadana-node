<div align="center">

<img src="assets/banner.svg" alt="vadana-node" width="720">

<br />

**A lightweight worker that renders heavy video jobs for a [vadana-extractor](https://github.com/phoseinq/vadana-extractor) master.**

<br />

[![CI](https://img.shields.io/github/actions/workflow/status/phoseinq/vadana-node/ci.yml?label=CI&logo=github&logoColor=white)](https://github.com/phoseinq/vadana-node/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/phoseinq/vadana-node?label=release&color=2CA5E0&logo=github&logoColor=white)](https://github.com/phoseinq/vadana-node/releases)
[![Docker](https://img.shields.io/badge/ghcr.io-vadana--node-2496ED?logo=docker&logoColor=white)](https://github.com/phoseinq/vadana-node/pkgs/container/vadana-node)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<br />

**English** · [فارسی](README.fa.md)

</div>

<br />

## 🧩 What it is

The vadana master (the Telegram bot) builds class videos. When its own video slot is busy, it hands the job to a worker node over **mutually-authenticated TLS**. The node has **no Iran proxy and no Telegram token** — the master ships it everything it needs (the recording package plus the shared PDFs, in one bundle), the node renders, and posts the mp4 back. So a node is just CPU + ffmpeg.

If no node is connected, the master builds everything itself — nothing changes.

<br />

## 🚀 Run a node

**1. On the master**, run `vadana`, open the **Workers** menu (key `n`), choose **add** — it asks the node name, auto-detects your server IP, and prints a single **enrollment bundle**: one base64 line that holds the CA, this node's cert/key, and the master address. Re-show it any time with **show enrollment bundle**.

> By command: `vadana node add <name>` (the master IP is auto-detected).

**2. On the node machine**, one command — it asks Docker or native:

```bash
curl -fsSL https://raw.githubusercontent.com/phoseinq/vadana-node/main/install.sh | bash
```

Paste the bundle when asked; the installer writes the certs, **pulls the prebuilt image** (Docker) or sets up a venv (native), starts the worker, and tails the logs.

**Manage it** with `vadana-node` — same commands whether you installed with Docker or native:

```bash
vadana-node                 # interactive menu
vadana-node enroll          # paste a bundle to enroll / replace the certificate
vadana-node test            # verify the mTLS handshake
vadana-node logs            # follow the worker logs
vadana-node update          # pull the latest image (Docker) / git-pull + restart (native)
vadana-node workers 3       # run N parallel workers
```

Back on the master, `vadana node status` shows live which workers are connected.

<details><summary><b>Docker: pull, don't build</b></summary>

<br />

The worker runs the published image `ghcr.io/phoseinq/vadana-node:latest` (CI pushes it on every release), so updates just pull — no local build:

```bash
docker compose pull && docker compose up -d      # or simply: vadana-node update
```

`build:` stays in the compose file as a local fallback (`docker compose up --build`).

</details>

<br />

## ✅ Requirements

- **Docker** (recommended) — or, for a native install: Python **3.11+** with `ffmpeg`/`ffprobe` on `PATH`
- Reachability to the master's node-API port (default `8443`)
- The enrollment bundle from `vadana node add`

<br />

## 🔐 Certificates & keys

You never run `openssl` — the master's CLI does it all:

- **The master is the CA.** `vadana node init` creates `ca.crt` + `ca.key` (the CA key never leaves the master) and the master's own `server.crt`.
- `vadana node add <name>` issues a **client cert + key for that node**, signed by the CA, and adds its fingerprint to the master's allowlist.
- The master packs the CA, that node's cert/key, and its address into **one enrollment bundle** (a single base64 line). You paste that one string on the node — nothing else to copy.
- On connect (mTLS, both directions): the node proves itself with `node.crt` / `node.key` and verifies the master against `ca.crt`; the master verifies the node's cert against the CA **and** the allowlist. Revoke any time: `vadana node remove <name>`.

The node stores no secrets beyond its own cert/key.

<br />

---

<div align="center"><sub>MIT · made by <a href="https://github.com/phoseinq">phoseinq</a></sub></div>
