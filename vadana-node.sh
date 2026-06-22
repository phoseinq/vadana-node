#!/usr/bin/env bash
# vadana-node — run + manage the worker node. Works for both install types:
#   native  -> systemd service vadana-node
#   docker  -> docker compose project in /opt/vadana-node
# It auto-detects which one you have and routes start/stop/logs/etc accordingly.
SERVICE=vadana-node
DIR=/opt/vadana-node
PY="$DIR/venv/bin/python"; [ -x "$PY" ] || PY=python3
CFG="$DIR/config.json"
MODE=docker; [ -f "/etc/systemd/system/$SERVICE.service" ] && MODE=native

C=$'\033[1;36m'; G=$'\033[1;32m'; R=$'\033[1;31m'; Y=$'\033[1;33m'
D=$'\033[2m'; B=$'\033[1m'; N=$'\033[0m'
pause() { printf "\n   ${D}press Enter to go back…${N}"; read -r _; }

dc() { ( cd "$DIR" && docker compose "$@" ); }

svc_start()   { if [ "$MODE" = native ]; then systemctl enable --now "$SERVICE"; else dc up -d; fi; }
svc_stop()    { if [ "$MODE" = native ]; then systemctl stop "$SERVICE"; else dc down; fi; }
svc_restart() { if [ "$MODE" = native ]; then systemctl restart "$SERVICE"; else dc up -d --force-recreate; fi; }
svc_status()  { if [ "$MODE" = native ]; then systemctl status "$SERVICE" --no-pager; else dc ps; fi; }
svc_logs()    { if [ "$MODE" = native ]; then journalctl -u "$SERVICE" -f; else dc logs -f; fi; }
svc_active()  { if [ "$MODE" = native ]; then systemctl is-active "$SERVICE" 2>/dev/null
                else [ -n "$(dc ps -q 2>/dev/null)" ] && echo active || echo inactive; fi; }

do_test() {                          # verify mTLS to the master
  if [ "$MODE" = native ]; then ( cd "$DIR" && "$PY" -m vadana_node.cli test --config "$CFG" )
  else dc run --rm worker python -m vadana_node.cli test; fi
}

do_enroll() {                        # paste the one-line bundle from the master -> certs + config + restart
  local blob m w
  printf 'Paste the enrollment bundle from the master, then Enter:\n' >/dev/tty
  read -r blob </dev/tty
  [ -z "$blob" ] && { echo "no bundle pasted."; return 1; }
  ( cd "$DIR" && printf '%s' "$blob" | base64 -d | tar -xz ) || { echo "bad bundle."; return 1; }
  m=$(cat "$DIR/master"); rm -f "$DIR/master"
  w=$(grep -oP '"workers"\s*:\s*\K[0-9]+' "$CFG" 2>/dev/null || echo 1)
  cat > "$CFG" <<EOF
{ "master": "$m", "ca": "ca.crt", "cert": "node.crt", "key": "node.key", "workers": $w }
EOF
  echo "✓ enrolled (master $m, $w worker(s))"
  svc_restart && echo restarted
}

set_workers() {                      # N -> scale (docker) or config+restart (native)
  local n="${1:-1}"; [ "$n" -ge 1 ] 2>/dev/null || n=1
  if [ "$MODE" = native ]; then
    "$PY" - "$CFG" "$n" <<'PYEOF'
import json, sys
p, n = sys.argv[1], int(sys.argv[2])
d = json.load(open(p)); d["workers"] = n
json.dump(d, open(p, "w"), indent=2)
PYEOF
    systemctl restart "$SERVICE" && echo "workers=$n, restarted"
  else
    dc up -d --scale worker="$n" && echo "scaled to $n worker(s)"
  fi
}

run() {
  case "$1" in
    enroll)  shift; do_enroll "$@" ;;
    test)    do_test ;;
    start)   svc_start   && echo started ;;
    stop)    svc_stop    && echo stopped ;;
    restart) svc_restart && echo restarted ;;
    status)  svc_status ;;
    logs)    svc_logs ;;
    workers) set_workers "${2:-1}" ;;
    update)  ( cd "$DIR" && git pull --ff-only -q ) || return 1
             if [ "$MODE" = native ]; then "$DIR/venv/bin/pip" install -q -r "$DIR/requirements.txt" && systemctl restart "$SERVICE" && echo updated
             elif printf 'pulling latest image…\n'; dc pull --quiet; then dc up -d && echo updated
             else printf 'no image — building…\n'; dc --progress quiet up -d --build && echo updated; fi ;;
    uninstall)
             if [ "$MODE" = native ]; then systemctl disable --now "$SERVICE" 2>/dev/null
               rm -f "/etc/systemd/system/$SERVICE.service"; systemctl daemon-reload
             else dc down; fi
             echo "uninstalled (code left in $DIR)" ;;
    *) echo "usage: vadana-node {enroll|test|start|stop|restart|status|logs|workers N|update|uninstall}" >&2; return 2 ;;
  esac
}

menu() {
  local st dot c wn
  while true; do
    clear 2>/dev/null
    st=$(svc_active)
    case "$st" in active) dot="${G}●${N}" ;; *) dot="${R}●${N}" ;; esac
    printf "\n   ${C}■${N} ${B}vadana-node${N} ${D}· worker (%s)${N}\n   service ${dot} %s\n\n" "$MODE" "$st"
    printf "   ${C}1${N} enroll / replace certificate (paste bundle)   ${C}2${N} test connection\n"
    printf "   ${C}s${N} start   ${C}x${N} stop   ${C}r${N} restart   ${C}t${N} status   ${C}l${N} logs\n"
    printf "   ${C}w${N} workers   ${C}u${N} update   ${C}q${N} quit\n\n   ${C}›${N} "
    read -r c || break
    case "$c" in
      1) run enroll; pause ;; 2) run test; pause ;;
      s|S) run start; pause ;; x|X) run stop; pause ;; r|R) run restart; pause ;;
      t|T) run status; pause ;; l|L) run logs ;;
      w|W) printf "   how many workers? "; read -r wn; [ -n "$wn" ] && run workers "$wn"; pause ;;
      u|U) run update; pause ;;
      q|Q|0|"") clear 2>/dev/null; exit 0 ;;
      *) ;;
    esac
  done
}

[ -z "$1" ] && menu || run "$@"
