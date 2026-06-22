# vadana-node worker. Mount config.json + the three cert files, then it claims
# and renders video jobs for the master.
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# ffmpeg + ffprobe drive the whiteboard/screen → video and audio reconstruction
RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY vadana_node ./vadana_node

RUN useradd -m -u 10001 node && chown -R node /app
USER node

# config.json + ca.crt/node.crt/node.key are mounted at /app (see docker-compose.yml)
CMD ["python", "-m", "vadana_node.cli", "run"]
