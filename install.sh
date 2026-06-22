#!/usr/bin/env bash
# vadana-node — one command: asks Docker or native, you paste the enrollment bundle,
# then it brings the worker up and tails the logs.
#   curl -fsSL https://raw.githubusercontent.com/phoseinq/vadana-node/main/install.sh | bash
set -euo pipefail
DIR=/opt/vadana-node
REPO=https://github.com/phoseinq/vadana-node.git
MASTER=""; WORKERS=1

ask() {                              # ask "prompt" [default] -> echoes the answer
  local val=""
  if [ -e /dev/tty ]; then printf '%s' "$1" >/dev/tty; read -r val </dev/tty || true; fi
  printf '%s' "${val:-${2:-}}"
}

fetch_code() {
  if [ -f "$DIR/requirements.txt" ]; then git -C "$DIR" pull --ff-only || true
  else git clone "$REPO" "$DIR"; fi
}

enroll() {                           # paste the one-line bundle -> ca/node/key + $MASTER + $WORKERS
  local blob
  printf '\nPaste the enrollment bundle from the master (vadana node add), then Enter:\n' >/dev/tty
  blob=$(ask '> ')
  [ -z "$blob" ] && return 1
  printf '%s' "$blob" | base64 -d | tar -xz        # -> ca.crt node.crt node.key master
  MASTER=$(cat master); rm -f master
  WORKERS=$(ask 'workers [1]: ' 1)
}

write_config() {                     # $1 = workers count to record in config.json
  cat > config.json <<EOF
{ "master": "$MASTER", "ca": "ca.crt", "cert": "node.crt", "key": "node.key", "workers": $1 }
EOF
}

native() {
  apt-get update -y
  apt-get install -y python3 python3-venv python3-pip ffmpeg git
  fetch_code; cd "$DIR"
  python3 -m venv venv
  venv/bin/pip install -qU pip
  venv/bin/pip install -q -r requirements.txt
  install -m 755 vadana-node.sh /usr/local/bin/vadana-node
  cp systemd/vadana-node.service /etc/systemd/system/
  systemctl daemon-reload
  if enroll; then
    write_config "$WORKERS"
    systemctl enable --now vadana-node; sleep 1
    printf '\n✓ running (%s worker(s)).  logs:  vadana-node logs   (or: journalctl -u vadana-node -f)\n\n' "$WORKERS"
    journalctl -u vadana-node -n 12 --no-pager || true
  else
    printf '\nNo bundle pasted. Later:  vadana-node enroll   then   vadana-node start\n'
  fi
}

docker_mode() {
  command -v docker >/dev/null || { echo "Docker isn't installed — https://docs.docker.com/engine/install/"; exit 1; }
  apt-get install -y -q git
  fetch_code; cd "$DIR"
  install -m 755 vadana-node.sh /usr/local/bin/vadana-node   # the manage CLI works in docker mode too
  if enroll; then
    write_config 1                   # each container runs one loop; --scale is the parallelism
    printf 'pulling the worker image…\n'
    if docker compose pull --quiet 2>/dev/null; then
      docker compose up -d --scale worker="$WORKERS"
    else
      printf 'no prebuilt image — building locally…\n'
      docker compose --progress quiet up -d --build --scale worker="$WORKERS"
    fi
    printf '\n✓ running (%s worker(s)).  logs:  docker compose logs -f\n\n' "$WORKERS"
    sleep 2; docker compose logs --tail=15 || true
  else
    printf '\nNo bundle pasted. Put config.json + certs in %s then: docker compose up -d --build\n' "$DIR"
  fi
}

# one prompt picks the method (or pass: install.sh docker | install.sh native)
case "$(printf '%s' "${1:-$(ask 'Install with Docker? [y/N]: ' n)}" | tr '[:upper:]' '[:lower:]')" in
  y|yes|d|docker) docker_mode ;;
  *)              native ;;
esac
