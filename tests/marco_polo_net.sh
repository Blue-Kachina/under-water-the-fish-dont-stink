#!/bin/bash
# Online probe for Marco Polo (tests/marco_polo_net_peer.gd): a host with bots
# and two guests (one on a laggy link), each its own headless Godot, over
# localhost.
#   tests/marco_polo_net.sh [path/to/Godot_console.exe] [port]
GODOT="${1:-Godot_console.exe}"
PORT="${2:-24713}"
cd "$(dirname "$0")/.."
LOGS="${MARCO_POLO_NET_LOGS:-$(mktemp -d)}"
mkdir -p "$LOGS"
run() { timeout 300 "$GODOT" --headless --path . res://tests/marco_polo_net_peer.tscn -- --role=$1 --port=$PORT "${@:2}" > "$LOGS/$1.log" 2>&1; echo $? > "$LOGS/$1.code"; }
run host &
sleep 2
run a --lag=60 --jitter=20 --loss=0.02 &
run b --lag=30 &
wait
status=0
for role in host a b; do
	grep -E "^\s+\[|marco_polo_net_peer|SCRIPT ERROR" "$LOGS/$role.log"
	[ "$(cat "$LOGS/$role.code")" = "0" ] || status=1
done
echo "marco_polo_net: $([ $status = 0 ] && echo 'all passed' || echo FAILED) (logs in $LOGS)"
exit $status
