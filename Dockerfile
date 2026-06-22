# vadana-node worker. Mount config.json + the three cert files, then it claims
# and renders video jobs for the master.
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Prefer IPv4 — some hosts' docker bridges resolve pypi to an IPv6 with no route,
# so pip dies with ENETUNREACH. This makes glibc sort IPv4 first.
RUN echo 'precedence ::ffff:0:0/96 100' >> /etc/gai.conf

# ffmpeg + ffprobe drive the whiteboard/screen → video and audio reconstruction
RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY vadana_node ./vadana_node

# Runs as root so it can read the mounted node.key (root-owned, 0600). The key stays
# private; the container is a single-purpose, low-trust renderer.
# config.json + ca.crt/node.crt/node.key are mounted at /app (see docker-compose.yml)
CMD ["python", "-m", "vadana_node.cli", "run"]
