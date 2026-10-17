#!/bin/bash
# Online co-op probe for Unnatural (tests/unnatural_net_peer.gd): a host, a
# guest on a laggy link, and a late joiner, each its own headless Godot, over
# localhost.
#   tests/unnatural_net.sh [path/to/Godot_console.exe] [port]
GODOT="${1:-Godot_console.exe}"
PORT="${2:-24712}"
cd "$(dirname "$0")/.."
LOGS="${UNNATURAL_NET_LOGS:-$(mktemp -d)}"
mkdir -p "$LOGS"
run() { timeout 300 "$GODOT" --headless --path . res://tests/unnatural_net_peer.tscn -- --role=$1 --port=$PORT "${@:2}" > "$LOGS/$1.log" 2>&1; echo $? > "$LOGS/$1.code"; }
run host &
sleep 2
run guest --lag=60 --jitter=20 --loss=0.02 &
sleep 40
run late --lag=30 &
wait
status=0
for role in host guest late; do
	grep -E "^\s+\[|unnatural_net_peer|SCRIPT ERROR" "$LOGS/$role.log"
	[ "$(cat "$LOGS/$role.code")" = "0" ] || status=1
done
echo "unnatural_net: $([ $status = 0 ] && echo 'all passed' || echo FAILED) (logs in $LOGS)"
exit $status
