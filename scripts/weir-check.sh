#!/usr/bin/env bash
# The refusing-weir check (lattice /reference/grubbery-crash-loops, rule 8):
# take one road out of the calendar instance's poke weir, reload it, and
# watch: the fibers must park (the worker's CPU near 0), never spin. A
# fresh install refuses everything until its permits are approved, and a
# user can uncheck any road, so this is a state every ship can be in.
#
#   weir-check.sh <pier> <ship-url> <cookie-jar> <road> [seconds]
#   e.g. weir-check.sh ~/fleet/piers/rux http://localhost:8121 /tmp/rux.jar /sys/behn/
#
# A spin is interrupted from the ship's dojo (tmux pane found from the
# pier's king process); kill -INT to the worker does not interrupt it. The
# road is put back and the instance reloaded whatever happens. For a road
# the calendar asks hard (/sys/behn/, /sys/bowl.sig): a fiber must show
# parked once it is refused (else the road named was not one the weir
# holds, and nothing was tested), and none once it is back. Exits 1 on a
# spin, on either of those, or when the ship does not take a step. The
# steps go through scripts/permit.py (the shell's approve-weir and reload).
set -uo pipefail
pier=$(cd "$1" && pwd) || exit 2; B=${2%/}; JAR=$3; ROAD=$4; SECS=${5:-360}
here=$(cd "$(dirname "$0")" && pwd)
permit() { python3 "$here/permit.py" "$B" "$JAR" "$@"; }
serf=$(pgrep -f "work --snap-dir $pier( |$)" | head -1)
# the king is the worker's parent
king=$([[ -n "$serf" ]] && ps -o ppid= -p "$serf" | tr -d ' ')
pane=$(tmux list-panes -a -F '#{pane_tty} #{session_name}:#{window_index}.#{pane_index}' |
  awk -v t="$(readlink /proc/$king/fd/0 2>/dev/null)" '$1==t{print $2}')
[[ -n "$serf" ]] || { echo "no worker for $pier" >&2; exit 2; }
ticks() { awk '{print $14+$15}' /proc/$serf/stat; }
post() { permit "$@" && echo "$1 ${*:2} -> ok" || { echo "$1 ${*:2} -> refused"; false; }; }
# a fiber parked (or crashed) shows as a bang under the instance: the
# paths that have one, compared with the ones that had one before (a bang
# that was there already says nothing of this road)
banged() { permit banged; }
base=$(banged)
[[ "$base" != unreadable ]] || { echo "the instance cannot be read; check the cookie" >&2; exit 2; }
parked() { local now; now=$(banged); [[ "$now" != unreadable && "$now" != "$base" ]] && echo yes || echo no; }
settles() { local want=$1 t; for t in $(seq 1 12); do [[ "$(parked)" == "$want" ]] && return 0; sleep 5; done; return 1; }
restore() {
  local ok=1
  post grant poke "$ROAD" || ok=0
  post reload || ok=0
  (( ok )) || { echo "FAIL: $ROAD may still be refused; check /apps/grubbery/permits and reload the calendar"; exit 1; }
  settles no || { echo "FAIL: a fiber is still parked a minute after $ROAD came back"; exit 1; }
}
trap restore EXIT
post refuse poke "$ROAD" ||
  { echo "FAIL: $ROAD was not taken out of the weir"; exit 1; }
post reload || { echo "FAIL: the instance was not reloaded"; exit 1; }
settles yes || { echo "FAIL: no fiber parked with $ROAD refused: is it a road the weir holds, exactly as written?"; exit 1; }
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
