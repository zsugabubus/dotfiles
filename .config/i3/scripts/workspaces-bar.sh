#!/bin/sh
TIMEOUT=1.6
BAR_ID=workspaces

while [ $# -gt 0 ]; do
  case "$1" in
  --socket=*) SOCKET=${1#*=}; ;;
  --bar_id=*) BAR_ID=${1#*=}; ;;
  esac
  shift
done

echo '{"version":1,"stop_signal": 18}'
echo '['
echo '[]'

i3-msg -t subscribe -m '[ "workspace" ]' |
while read; do
  kill $tid 2>/dev/null
  (
    i3-msg bar hidden_state show "$BAR_ID" &&
    sleep $TIMEOUT &&
    i3-msg bar hidden_state hide "$BAR_ID"
  ) &>/dev/null &
  tid=$!
done
i3-nagbar -m EXIT
