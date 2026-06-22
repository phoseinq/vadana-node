#!/usr/bin/env bash
# vadana-node — run + manage the worker node (installed to /usr/local/bin/vadana-node)
SERVICE=vadana-node
DIR=/opt/vadana-node
PY="$DIR/venv/bin/python"; [ -x "$PY" ] || PY=python3
CFG="$DIR/config.json"

C=$'\033[1;36m'; G=$'\033[1;32m'; R=$'\033[1;31m'; Y=$'\033[1;33m'
D=$'\033[2m'; B=$'\033[1m'; N=$'\033[0m'
pause() { printf "\n   ${D}press Enter to go back…${N}"; read -r _; }

py() { ( cd "$DIR" && "$PY" -m vadana_node.cli "$@" ); }

set_workers() {                      # set_workers N -> update config.json + restart
  "$PY" - "$CFG" "$1" <<'PYEOF'
import json, sys
p, n = sys.argv[1], int(sys.argv[2])
d = json.load(open(p)); d["workers"] = max(1, n)
json.dump(d, open(p, "w"), indent=2)
print(f"workers = {d['workers']}")
PYEOF
  systemctl restart "$SERVICE" 2>/dev/null && echo "restarted"
}

configure() {
  local m ca cert key w
  printf "   master URL (https://IP:8443): "; read -r m
  printf "   ca.crt path  [ca.crt]:   "; read -r ca;   ca=${ca:-ca.crt}
  printf "   node cert    [node.crt]: "; read -r cert; cert=${cert:-node.crt}
  printf "   node key     [node.key]: "; read -r key;  key=${key:-node.key}
  printf "   workers      [1]:        "; read -r w;    w=${w:-1}
  py config --master "$m" --ca "$ca" --cert "$cert" --key "$key" --workers "$w" --config "$CFG"
}

run() {
  case "$1" in
    configure) configure ;;
    enroll)    local blob
               printf 'Paste the enrollment bundle from the master, then Enter:\n' >/dev/tty
               read -r blob </dev/tty
               printf '%s' "$blob" | ( cd "$DIR" && "$PY" -m vadana_node.cli enroll --config "$CFG" ) \
                 && systemctl restart "$SERVICE" 2>/dev/null && echo restarted ;;
    config)    shift; py config "$@" --config "$CFG" ;;
    test)      py test --config "$CFG" ;;
    run)       py run --config "$CFG" ;;
    status)    systemctl status "$SERVICE" --no-pager ;;
    logs)      journalctl -u "$SERVICE" -f ;;
    start)     systemctl enable --now "$SERVICE" && echo "started" ;;
    stop)      systemctl stop "$SERVICE" && echo "stopped" ;;
    restart)   systemctl restart "$SERVICE" && echo "restarted" ;;
    workers)   set_workers "${2:-1}" ;;
    update)    cd "$DIR" && git pull --ff-only \
                 && "$DIR/venv/bin/pip" install -q -r requirements.txt \
                 && systemctl restart "$SERVICE" && echo "updated + restarted" ;;
    uninstall) systemctl disable --now "$SERVICE" 2>/dev/null
               rm -f "/etc/systemd/system/$SERVICE.service"; systemctl daemon-reload
               echo "uninstalled (code left in $DIR)" ;;
    *) echo "usage: vadana-node {enroll|configure|test|run|start|stop|restart|status|logs|workers N|update|uninstall}" >&2; return 2 ;;
  esac
}

menu() {
  local st dot c
  while true; do
    clear 2>/dev/null
    st=$(systemctl is-active "$SERVICE" 2>/dev/null || echo "n/a")
    case "$st" in active) dot="${G}●${N}" ;; inactive|failed) dot="${R}●${N}" ;; *) dot="${Y}●${N}" ;; esac
    printf "\n   ${C}■${N} ${B}vadana-node${N} ${D}· worker${N}\n   service ${dot} %s\n\n" "$st"
    [ -f "$CFG" ] && py test --config "$CFG" 2>/dev/null
    printf "\n   ${C}1${N} enroll (paste bundle from master)   ${C}2${N} test connection\n"
    printf "   ${C}s${N} start   ${C}x${N} stop   ${C}r${N} restart   ${C}t${N} status   ${C}l${N} logs\n"
    printf "   ${C}u${N} update   ${C}q${N} quit\n\n   ${C}›${N} "
    read -r c || break
    case "$c" in
      1) run enroll; pause ;; 2) run test; pause ;;
      s|S) run start; pause ;; x|X) run stop; pause ;; r|R) run restart; pause ;;
      t|T) run status; pause ;; l|L) run logs ;; u|U) run update; pause ;;
      q|Q|0|"") clear 2>/dev/null; exit 0 ;;
      *) ;;
    esac
  done
}

[ -z "$1" ] && menu || run "$@"
