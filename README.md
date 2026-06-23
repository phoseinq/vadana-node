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

**1. On the master**, run `vadana`, open the **Workers** menu (key `n`), choose
**add** — it asks the node name, auto-detects your server IP, and prints a single
**enrollment bundle**: one base64 line that holds the CA, this node's cert/key, and the
master address. Re-show it any time with **show enrollment bundle**.

> By command: `vadana node add <name>` (the master IP is auto-detected).

**2. On the node machine**, one command — it asks Docker or native:

```bash
curl -fsSL https://raw.githubusercontent.com/phoseinq/vadana-node/main/install.sh | bash
```

Paste the bundle when asked; the installer writes the certs, **pulls the prebuilt image**
(Docker) or sets up a venv (native), starts the worker, and tails the logs.

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

### Docker: pull, don't build

The worker runs the published image `ghcr.io/phoseinq/vadana-node:latest` (CI pushes it on
every release), so updates just pull — no local build:

```bash
docker compose pull && docker compose up -d      # or simply: vadana-node update
```

`build:` stays in the compose file as a local fallback (`docker compose up --build`).

## Requirements

- **Docker** (recommended) — or, for a native install: Python **3.11+** with `ffmpeg`/`ffprobe` on `PATH`
- Reachability to the master's node-API port (default `8443`)
- The enrollment bundle from `vadana node add`

## Certificates & keys

You never run `openssl` — the master's CLI does it all:

- **The master is the CA.** `vadana node init` creates `ca.crt` + `ca.key` (the CA
  key never leaves the master) and the master's own `server.crt`.
- `vadana node add <name>` issues a **client cert + key for that node**, signed by
  the CA, and adds its fingerprint to the master's allowlist.
- The master packs the CA, that node's cert/key, and its address into **one enrollment
  bundle** (a single base64 line). You paste that one string on the node — nothing else to copy.
- On connect (mTLS, both directions): the node proves itself with `node.crt` /
  `node.key` and verifies the master against `ca.crt`; the master verifies the node's
  cert against the CA **and** the allowlist. Revoke any time: `vadana node remove <name>`.

The node stores no secrets beyond its own cert/key.

---

## فارسی

<div dir="rtl" align="right">

### این چیست

مسترِ وادانا (همان رباتِ تلگرام) ویدیوی کلاس می‌سازد. وقتی اسلاتِ ویدیوی خودش پر است،
کار را روی **TLSِ دوطرفه (mTLS)** به یک نودِ کارگر می‌سپارد. نود **نه پروکسیِ ایران دارد
نه توکنِ تلگرام** — مستر هرچه لازم است (پکیجِ ضبط + PDFهای اشتراکی، در یک باندل) را می‌فرستد،
نود رِندر می‌کند و MP4 را برمی‌گرداند. پس نود فقط CPU و ffmpeg است. اگر هیچ نودی وصل نباشد،
مستر خودش همه‌چیز را می‌سازد — هیچ تغییری نمی‌کند.

### راه‌اندازیِ یک نود

**۱) روی مستر** کافیه `vadana` را بزنی، بروی منوی **Workers** (کلیدِ `n`)، گزینهٔ **add** —
اسمِ نود را می‌پرسد، IPِ سرور را خودش پیدا می‌کند، و یک **باندلِ ثبت‌نام** چاپ می‌کند: یک خطِ
base64 که CA، گواهی/کلیدِ همان نود و آدرسِ مستر در آن است. هر وقت خواستی دوباره نشانش بده با
**show enrollment bundle**.

> یا با دستور: `vadana node add <name>` (آی‌پیِ مستر خودکار پیدا می‌شود).

**۲) روی ماشینِ نود** یک دستور (می‌پرسد داکر یا دستی):

```bash
curl -fsSL https://raw.githubusercontent.com/phoseinq/vadana-node/main/install.sh | bash
```

باندل را که خواست paste کن؛ نصب‌کننده گواهی‌ها را می‌نویسد، **ایمیجِ آماده را pull می‌کند** (داکر)
یا venv می‌سازد (دستی)، ورکر را بالا می‌آورد و لاگ را نشان می‌دهد.

**مدیریت** با `vadana-node` — چه نصبِ داکری چه دستی، دستورها یکی‌اند:

```bash
vadana-node                 # منوی تعاملی
vadana-node enroll          # paste کردنِ باندل برای ثبت/عوض‌کردنِ گواهی
vadana-node test            # تستِ اتصالِ mTLS
vadana-node logs            # دیدنِ لاگِ ورکر
vadana-node update          # pull کردنِ آخرین ایمیج (داکر) / git-pull + ری‌استارت (دستی)
vadana-node workers 3       # اجرای N ورکرِ موازی
```

روی مستر `vadana node status` به‌صورتِ زنده نشان می‌دهد کدام ورکرها وصل‌اند.

### داکر: pull به‌جای build

ورکر ایمیجِ منتشرشدهٔ `ghcr.io/phoseinq/vadana-node:latest` را اجرا می‌کند (CI روی هر ریلیز پوش
می‌کند)، پس آپدیت فقط pull است — بدونِ build:

```bash
docker compose pull && docker compose up -d      # یا ساده‌تر: vadana-node update
```

`build:` هم در compose به‌عنوانِ fallbackِ محلی می‌ماند (`docker compose up --build`).

### گواهی و کلید چطور؟

دستی با `openssl` کاری نداری — همه را CLIِ مستر انجام می‌دهد:

- **مستر همان CA است.** `vadana node init` فایل‌های `ca.crt` و `ca.key` را می‌سازد (کلیدِ CA
  هیچ‌وقت از مستر خارج نمی‌شود) و گواهیِ سرورِ خودِ مستر را.
- `vadana node add <name>` برای آن نود یک **گواهی + کلیدِ کلاینت** صادر می‌کند که با CA امضا
  شده، و اثرانگشتش را به allowlistِ مستر اضافه می‌کند.
- مستر، CA و گواهی/کلیدِ آن نود و آدرسش را در **یک باندلِ ثبت‌نام** (یک خطِ base64) بسته‌بندی
  می‌کند. همان یک رشته را روی نود paste می‌کنی — چیزِ دیگری برای کپی نیست.
- موقعِ اتصال (mTLSِ دوطرفه): نود با `node.crt`/`node.key` خودش را اثبات می‌کند و مستر را با
  `ca.crt` وریفای می‌کند؛ مستر هم گواهیِ نود را با CA **و** allowlist چک می‌کند. ابطال هر وقت:
  `vadana node remove <name>`.

</div>

<div align="center"><sub>MIT · <a href="https://github.com/phoseinq">phoseinq</a></sub></div>
