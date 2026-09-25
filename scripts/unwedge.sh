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
#   2. in the gaps, logs in and grants every road the calendar declares
#      (code/nex/calendar/app.hoon +weir-json) through the explorer's
#      add-weir-road form, which sands the path without the app's help;
#   3. stops interrupting, so the next retransmit of the update builds and
#      rises clean, and waits until the desk reports version 20 or later.
#
# Takes a few minutes. Safe to rerun. Needs bash, curl, tmux, pgrep, awk.
set -u
pier=$1; pane=$2; port=$3; code=$4
u=http://127.0.0.1:$port
app=/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app
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
grant() {
  say "$1 $2: $(curl -s -b "$jar" -m 900 -o /dev/null -w '%{http_code}' -X POST "$u/grubbery/ball$app" \
    --data-urlencode action=add-weir-road --data-urlencode "category=$1" --data-urlencode "road-path=$2")"
}
for r in /sys/bowl.sig /sys/eyre/ /sys/behn/ /sys/push/ /sys/iris/ /sys/gall/ /sys/ames/registry /sys/ames/usergroups/; do grant poke "$r"; done
for r in /sys/link/ /sys/ames/usergroups/ /sys/ames/ships/; do grant read "$r"; done
grant write /sys/ames/usergroups/

# 3. let the update land
kill $loop 2>/dev/null; wait $loop 2>/dev/null
say "roads granted; no more interrupts. Waiting for the update to land (a build takes a few minutes)"
for i in $(seq 1 40); do
  sleep 30
  v=$(curl -s -b "$jar" -m 20 "$u/grubbery/ball/apps/shell.shell/desks/calendar.desk/desk/code/version.json" | grep -o '[0-9]\+')
  c=$(curl -s -b "$jar" -m 20 -o /dev/null -w '%{http_code}' "$u/apps/calendar")
  say "version ${v:-?} calendar ${c}"
  [ "${v:-0}" -ge 20 ] && [ "$c" = 200 ] && { say "done"; exit 0; }
done
say "still not on version 20 after 20 minutes: POST /apps/grubbery/desks/sync {\"name\":\"calendar\"} with the cookie, or check that ~ricsul-bilwyt is reachable"
exit 1
