#!/bin/bash
# unwedge.sh <pier> <tmux-pane> <http-port> <login-code>
#
# Recover a ship wedged by the calendar's permit-veto loop (docs/wedged-ship.md):
# a sandboxed install (permits never approved) receiving version 18 or 19 spins
# forever inside the event that delivers the update, at 100% CPU, answering
# nothing. This script runs ON THE HOST that runs the ship, with the ship
# attached in a tmux pane (start it inside tmux for the occasion if it is not):
#
#   1. interrupts the spinning event with ^C every time the serf has been
#      pegged for 2 s. Nothing legitimate can finish while the roads are
#      missing, so every long event in this phase is the loop;
#   2. in the gaps, logs in and grants the roads versions 18 and 19
#      declared (listed below; roads added since, such as /sys/scry/, are
#      left to the Permits page). On the current kernel (the shell at
#      /apps/shell) that is one approve-weir POST to /apps/grubbery/permits
#      with those roads as `granted`; on the old one (/apps/shell.shell),
#      the explorer's add-weir-road form, road by road. Either sands the
#      path without the app's help;
#   3. stops interrupting, so the next retransmit of the update builds and
#      rises clean, and waits until the desk reports version 20 or later.
#
# Takes a few minutes. Safe to rerun. Needs bash, curl, tmux, pgrep, awk.
set -u
pier=$1; pane=$2; port=$3; code=$4
u=http://127.0.0.1:$port
jar=$(mktemp)
say() { echo "$(date -u +%FT%TZ) $*"; }

# 1. the ^C loop
( while :; do
    pid=$(pgrep -f "work --snap-dir $pier" | head -1)
    [ -z "$pid" ] && { sleep 2; continue; }
    a=$(awk '{print $14+$15}' /proc/"$pid"/stat 2>/dev/null); sleep 2
    b=$(awk '{print $14+$15}' /proc/"$pid"/stat 2>/dev/null)
    [ -n "$a" ] && [ -n "$b" ] && [ $((b-a)) -ge 180 ] && tmux send-keys -t "$pane" C-c
  done ) &
loop=$!
trap 'kill $loop 2>/dev/null; rm -f "$jar"' EXIT

# 2. log in and grant; each request waits in the ship's queue for a gap
say "login: $(curl -s -c "$jar" -m 900 -o /dev/null -w '%{http_code}' -X POST "$u/~/login" --data-urlencode "password=$code")"
grep -q urbauth "$jar" || { say "login failed (wrong code, or the ship is not answering on :$port)"; exit 1; }
# which shell this kernel has: GET /grubbery/api/peek/apps/ lists it
if curl -s -b "$jar" -m 900 "$u/grubbery/api/peek/apps/" | grep -q '"shell"'; then
  desk=/apps/shell/desks/calendar.desk; read=$u/grubbery/api/peek
else
  desk=/apps/shell.shell/desks/calendar.desk; read=$u/grubbery/ball
fi
app=$desk/desk/data/calendar.calendar_app
POKE='/sys/bowl.sig /sys/eyre/ /sys/behn/ /sys/push/ /sys/iris/ /sys/gall/ /sys/ames/registry /sys/ames/usergroups/'
PEEK='/sys/link/ /sys/ames/usergroups/ /sys/ames/ships/'
MAKE='/sys/ames/usergroups/'
arr() { local r s=; for r in "$@"; do s="$s${s:+,}{\"road\":\"$r\"}"; done; echo "[$s]"; }
grant() {
  say "$1 $2: $(curl -s -b "$jar" -m 900 -o /dev/null -w '%{http_code}' -X POST "$u/grubbery/ball$app" \
    --data-urlencode action=add-weir-road --data-urlencode "category=$1" --data-urlencode "road-path=$2")"
}
if [ "$desk" = /apps/shell/desks/calendar.desk ]; then
  # approve-weir drops any road the app's weir.json does not ask for
  body="{\"action\":\"approve-weir\",\"app\":\"$app\",\"picks\":{},\"granted\":{\"poke\":$(arr $POKE),\"peek\":$(arr $PEEK),\"make\":$(arr $MAKE)}}"
  say "approve-weir: $(curl -s -b "$jar" -m 900 -o /dev/null -w '%{http_code}' -H 'content-type: application/json' -d "$body" "$u/apps/grubbery/permits")"
  say "reload: $(curl -s -b "$jar" -m 900 -o /dev/null -w '%{http_code}' -H 'content-type: application/json' -d "{\"app\":\"$app\"}" "$u/apps/grubbery/permits/reload")"
else
  for r in $POKE; do grant poke "$r"; done
  for r in $PEEK; do grant read "$r"; done
  for r in $MAKE; do grant write "$r"; done
fi

# 3. let the update land
kill $loop 2>/dev/null; wait $loop 2>/dev/null
say "roads granted; no more interrupts. Waiting for the update to land (a build takes a few minutes)"
for i in $(seq 1 40); do
  sleep 30
  v=$(curl -s -b "$jar" -m 20 "$read$desk/desk/code/version.json" | grep -o '[0-9]\+' | head -1)
  c=$(curl -s -b "$jar" -m 20 -o /dev/null -w '%{http_code}' "$u/apps/calendar")
  say "version ${v:-?} calendar ${c}"
  [ "${v:-0}" -ge 20 ] && [ "$c" = 200 ] && { say "done"; exit 0; }
done
say "still not on version 20 after 20 minutes: POST /apps/grubbery/desks/sync {\"name\":\"calendar\"} with the cookie, or check that ~ricsul-bilwyt is reachable"
exit 1
