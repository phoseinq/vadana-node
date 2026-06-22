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

**1. On the master**, run `vadana`, open the **Workers** menu (key `n`), and choose
**add** — it asks the node name, auto-detects your server IP, and prints a bundle of
three files: `ca.crt`, `node-<name>.crt`, `node-<name>.key`.

> By command instead: `vadana node init --host <MASTER_IP>` then `vadana node add <name> --host <MASTER_IP>`.

**2. On the node machine**, one command — it asks Docker or native:

```bash
curl -fsSL https://raw.githubusercontent.com/phoseinq/vadana-node/main/install.sh | bash
```

Put the three files in the install dir as `ca.crt`, `node.crt`, `node.key`, then run
**`vadana-node`** (interactive menu) → **configure** (master URL + cert files + workers)
→ **start**.

```bash
vadana-node                 # interactive menu: configure · test · start · logs
vadana-node configure       # interactive: prompts for master + cert files + workers
# or non-interactive:
vadana-node config --master https://<MASTER_IP>:8443 --ca ca.crt --cert node.crt --key node.key
vadana-node test            # verify the mTLS handshake
vadana-node start           # run as a systemd service
vadana-node workers 3       # parallel workers (updates config + restarts)
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

## Certificates & keys

You never run `openssl` — the master's CLI does it all:

- **The master is the CA.** `vadana node init` creates `ca.crt` + `ca.key` (the CA
  key never leaves the master) and the master's own `server.crt`.
- `vadana node add <name>` issues a **client cert + key for that node**, signed by
  the CA, and adds its fingerprint to the master's allowlist.
- Copy **three files** to the node and name them `ca.crt`, `node.crt`, `node.key`.
  Nothing else.
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
اسمِ نود را می‌پرسد، IPِ سرور را خودش پیدا می‌کند، و باندلِ سه‌فایلی
(`ca.crt`، `node-<name>.crt`، `node-<name>.key`) را چاپ می‌کند.

> یا با دستور: `vadana node init --host <MASTER_IP>` بعد `vadana node add <name> --host <MASTER_IP>`.

**۲) روی ماشینِ نود** یک دستور (می‌پرسد داکر یا دستی):

```bash
curl -fsSL https://raw.githubusercontent.com/phoseinq/vadana-node/main/install.sh | bash
```

آن سه فایل را در پوشهٔ نصب با نام‌های `ca.crt`، `node.crt`، `node.key` بگذار. نصبِ دستی یک
دستورِ **`vadana-node`** (با منوی تعاملی) می‌دهد:

```bash
vadana-node                 # منو: configure، test، start، logs
vadana-node configure       # آدرسِ مستر + مسیرِ گواهی‌ها + تعدادِ workerها
vadana-node test            # تستِ اتصالِ mTLS
vadana-node start           # اجرا به‌صورتِ سرویس
```

**چند ورکر** روی یک ماشین: `vadana-node workers 3` (دستی) یا `docker compose up --scale worker=3`
(داکر). روی مستر `vadana node status` نشان می‌دهد کدام ورکرها وصل‌اند.

### گواهی و کلید چطور؟

دستی با `openssl` کاری نداری — همه را CLIِ مستر انجام می‌دهد:

- **مستر همان CA است.** `vadana node init` فایل‌های `ca.crt` و `ca.key` را می‌سازد (کلیدِ CA
  هیچ‌وقت از مستر خارج نمی‌شود) و گواهیِ سرورِ خودِ مستر را.
- `vadana node add <name>` برای آن نود یک **گواهی + کلیدِ کلاینت** صادر می‌کند که با CA امضا
  شده، و اثرانگشتش را به allowlistِ مستر اضافه می‌کند.
- **سه فایل** را روی نود کپی کن با نام‌های `ca.crt`، `node.crt`، `node.key`. همین.
- موقعِ اتصال (mTLSِ دوطرفه): نود با `node.crt`/`node.key` خودش را اثبات می‌کند و مستر را با
  `ca.crt` وریفای می‌کند؛ مستر هم گواهیِ نود را با CA **و** allowlist چک می‌کند. ابطال هر وقت:
  `vadana node remove <name>`.

</div>

<div align="center"><sub>MIT · <a href="https://github.com/phoseinq">phoseinq</a></sub></div>
