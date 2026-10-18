#!/usr/bin/env bash
# The upgrade check (lattice /reference/grubbery-crash-loops, rule 7): a
# test ship running the PREVIOUS release, with its data, gets the
# candidate the way a release reaches it; then five minutes of watching,
# and every read route captured before and after.
#
#   upgrade-check.sh <pier> <ship-url> <cookie-jar> [code-dir]
#
# code-dir: the candidate's code/ (default: this checkout's). It goes on
# through scripts/dev-deploy.py: the files that differ are written into
# the tree the desk follows, then its version is stamped, so the desk
# takes the whole tree in one event, as a release from the forge does.
# Writing into the desk one file at a time would build every in-between
# state (new libraries under the old app), which no subscriber ever sees.
# A ship already on the candidate has nothing to upgrade: exit 2.
# Passes when: the deploy is taken, the instance is not banged, the worker
# never sits at full CPU for 30 s, the route answers at the end, a poke is
# acknowledged, and rise.json shows no fiber crashing since the deploy,
# but for one crash (n=1) within 90 s of the desk taking it (the retry
# doing its job). Taken is the desk's code/version.json naming the stamp
# dev-deploy wrote, within ten minutes.
# Route differences are printed for the operator to explain; they are not
# a failure by themselves. The captures are kept when they differ, and
# removed whatever happens otherwise.
set -uo pipefail
(( $# >= 3 )) || { echo "usage: upgrade-check.sh <pier> <ship-url> <cookie-jar> [code-dir]" >&2; exit 2; }
pier=$(cd "$1" && pwd) || exit 2
B=${2%/}; JAR=$3
here=$(cd "$(dirname "$0")" && pwd)
CODE=$(cd "${4:-$here/../code}" && pwd) || exit 2
D=/grubbery/ball/apps/shell.shell/desks/calendar.desk/desk
I=$D/data/calendar.calendar_app
serf=$(pgrep -f "work --snap-dir $pier( |$)" | head -1)
[[ -n "$serf" ]] || { echo "no worker for $pier" >&2; exit 2; }
ticks() { awk '{print $14+$15}' "/proc/$serf/stat"; }
# -L: a raw read answers with a redirect to the kernel's file route
get() { curl -sL -m 60 -b "$JAR" "$B$1"; }
snap() {
  mkdir -p "$1"
  for r in calendars.json events.json feeds.json config.json share/shares.json google.json \
           "window.json?from=1790000000000&to=1796000000000" export.ics; do
    get "/apps/calendar/$r" | sed -E 's/DTSTAMP:[0-9TZ]+/DTSTAMP:x/' > "$1/$(echo "$r" | tr '/?&=' '____')"
  done
}
work=$(mktemp -d)
keep=0
trap '(( keep )) || rm -rf "$work"' EXIT
bang() { get "$I?info=1" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("bang") is None and not any(c.get("bang") for c in d["children"]))'; }
[[ "$(bang)" == True ]] || { echo "the previous release is banged already; fix that first" >&2; exit 2; }
snap "$work/before"
t0=$(date +%s)
python3 "$here/dev-deploy.py" "$B" "$JAR" --code "$CODE" > "$work/deploy.log" 2>&1
dep=$?
tail -n 1 "$work/deploy.log"
(( dep == 0 )) || { cat "$work/deploy.log"; echo "FAIL: the deploy was not taken (dev-deploy exit $dep)"; exit 1; }
grep -qE '^  /calendar-dev/code/' "$work/deploy.log" ||
  { echo "nothing to upgrade: the ship already runs this code" >&2; exit 2; }
# taken means the desk runs the stamp dev-deploy wrote: until then the
# old code runs (a desk that does not follow the dev tree never does)
stamp=$(sed -n 's/.*version.json = \([^ ]*\).*/\1/p' "$work/deploy.log" | tail -n 1)
for i in $(seq 1 60); do
  [[ "$(get "$D/code/version.json?raw=1")" == *"\"$stamp\""* ]] && break
  sleep 10
done
[[ "$(get "$D/code/version.json?raw=1")" == *"\"$stamp\""* ]] ||
  { echo "FAIL: the desk never took version $stamp (does it follow /calendar-dev/code?)"; exit 1; }
t1=$(date +%s)
fail=0; hot=0
for i in $(seq 1 30); do
  a=$(ticks); sleep 10; b=$(ticks)
  (( b-a > 950 )) && hot=$((hot+1)) || hot=0
  (( hot >= 3 )) && { echo "FAIL: 30 s at full CPU"; fail=1; break; }
done
[[ "$(bang)" == True ]] || { echo "FAIL: banged after the upgrade"; fail=1; }
code=$(curl -s -o /dev/null -w '%{http_code}' -m 30 -b "$JAR" "$B/apps/calendar")
[[ "$code" == 200 ]] || { echo "FAIL: /apps/calendar answered $code"; fail=1; }
ack=$(curl -s -o /dev/null -w '%{http_code}' -m 30 -b "$JAR" -H 'content-type: application/json' \
  -d '{"action":"noop"}' "$B/grubbery/api/poke${I#/grubbery/ball}/calendar.calendar?blot=/json")
[[ "$ack" == 200 ]] || { echo "FAIL: a poke answered $ack"; fail=1; }
get "$I/rise.json?raw=1" | python3 -c '
import json,sys
t0, t1 = int(sys.argv[1])*1000, int(sys.argv[2])*1000
rows=json.load(sys.stdin)
late={k:v for k,v in rows.items() if v.get("last_ms",0)>=t0}
print("rise.json since the deploy:", late or "no crash")
# one crash while the tree landed is the retry doing its job; one after,
# or a second, is not
bad={k:v for k,v in late.items() if v.get("n",0)>1 or v.get("last_ms",0)>t1+90000}
if late and not bad: print("(one crash as the deploy landed, n=1: the retry doing its job; read its trace)")
sys.exit(1 if bad else 0)' "$t0" "$t1" || { echo "FAIL: rise.json shows a fiber crashing after the deploy, or twice, or could not be read"; fail=1; }
snap "$work/after"
if diff -rq "$work/before" "$work/after"; then echo "routes: identical"; else keep=1; echo "captures kept in $work"; fi
(( fail )) && exit 1
echo "ok: upgraded, and quiet"
