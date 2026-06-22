#!/usr/bin/env bash
# vadana-node — one-command install. Asks Docker or native.
#   curl -fsSL https://raw.githubusercontent.com/phoseinq/vadana-node/main/install.sh | bash
set -euo pipefail
DIR=/opt/vadana-node
REPO=https://github.com/phoseinq/vadana-node.git

ask() {                              # ask "prompt" [default] -> echoes the answer
  local val=""
  if [ -e /dev/tty ]; then printf '%s' "$1" >/dev/tty; read -r val </dev/tty || true; fi
  printf '%s' "${val:-${2:-}}"
}

fetch_code() {
  if [ -f "$DIR/requirements.txt" ]; then git -C "$DIR" pull --ff-only || true
  else git clone "$REPO" "$DIR"; fi
}

native() {
  apt-get update -y
  apt-get install -y python3 python3-venv python3-pip ffmpeg git
  fetch_code; cd "$DIR"
  python3 -m venv venv
  venv/bin/pip install -qU pip
  venv/bin/pip install -q -r requirements.txt
  cat <<DONE

✓ Installed (native). Drop your ca.crt / node.crt / node.key in $DIR, then:
    cd $DIR
    venv/bin/python -m vadana_node.cli config --master https://<MASTER_IP>:8443 \\
        --ca ca.crt --cert node.crt --key node.key
    venv/bin/python -m vadana_node.cli test          # verify the mTLS connection
    venv/bin/python -m vadana_node.cli run           # add --workers N for parallel builds
DONE
}

docker_mode() {
  command -v docker >/dev/null || { echo "Docker isn't installed — https://docs.docker.com/engine/install/"; exit 1; }
  apt-get install -y -q git
  fetch_code; cd "$DIR"
  cat <<DONE

✓ Code ready for Docker. Put config.json + ca.crt + node.crt + node.key in $DIR, then:
    cd $DIR
    docker compose up -d --build                     # one worker
    docker compose up -d --build --scale worker=3    # three workers
    docker compose logs -f
DONE
}

# one prompt picks the method (or pass: install.sh docker | install.sh native)
case "$(printf '%s' "${1:-$(ask 'Install with Docker? [y/N]: ' n)}" | tr '[:upper:]' '[:lower:]')" in
  y|yes|d|docker) docker_mode ;;
  *)              native ;;
esac
