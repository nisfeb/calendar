#!/usr/bin/env bash
# The refusing-weir check (lattice /reference/grubbery-crash-loops, rule 8):
# take one road out of the calendar instance's poke weir, reload it, and
# watch: the fibers must park (the worker's CPU near 0), never spin. A
# fresh install refuses everything until its permits are approved, and a
# user can uncheck any road, so this is a state every ship can be in.
#
#   weir-check.sh <pier> <ship-url> <cookie-jar> <road> [seconds]
#   e.g. weir-check.sh ~/software/feb http://localhost:8081 feb.jar /sys/behn/
#
# A spin is interrupted from the ship's dojo (tmux pane found from the
# pier's king process); kill -INT to the worker does not interrupt it. The
# road is put back and the instance reloaded whatever happens. Exits 1 on
# a spin.
set -uo pipefail
pier=$(cd "$1" && pwd); B=${2%/}; JAR=$3; ROAD=$4; SECS=${5:-360}
I=/grubbery/ball/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app
serf=$(pgrep -f "work --snap-dir $pier( |$)" | head -1)
king=$(pgrep -f "vere.* $(basename "$pier")/?\$" | head -1)
pane=$(tmux list-panes -a -F '#{pane_tty} #{session_name}:#{window_index}.#{pane_index}' |
  awk -v t="$(readlink /proc/$king/fd/0 2>/dev/null)" '$1==t{print $2}')
[[ -n "$serf" ]] || { echo "no worker for $pier" >&2; exit 2; }
ticks() { awk '{print $14+$15}' /proc/$serf/stat; }
post() { curl -s -o /dev/null -w "$1 -> %{http_code}\n" -m 120 -b "$JAR" --data-urlencode action=$1 "${@:2}" "$B$I"; }
restore() {
  post add-weir-road --data-urlencode category=poke --data-urlencode road-path="$ROAD"
  post reload-nexus
}
trap restore EXIT
post del-weir-road --data-urlencode category=poke --data-urlencode road-path="$ROAD"
post reload-nexus
hot=0; spun=0
for ((t=5; t<=SECS; t+=5)); do
  a=$(ticks); sleep 5; b=$(ticks); c=$((b-a))
  echo "[${t}s] worker cpu ${c}/500"
  if (( c > 450 )); then hot=$((hot+1)); else hot=0; fi
  if (( hot >= 6 )); then
    echo "SPIN: 30 s at full CPU; ^C in ${pane:-?}"; spun=1
    [[ -n "$pane" ]] && tmux send-keys -t "$pane" C-c
    break
  fi
done
(( spun )) && { echo "FAIL: the calendar spins with $ROAD refused"; exit 1; }
echo "ok: the calendar parks with $ROAD refused"
