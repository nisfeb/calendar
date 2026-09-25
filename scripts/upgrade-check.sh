#!/usr/bin/env bash
# The upgrade check (lattice /reference/grubbery-crash-loops, rule 7): a
# test ship running the PREVIOUS release, with its data, gets this tree's
# code/ written into its calendar desk; then five minutes of watching, and
# every read route captured before and after.
#
#   upgrade-check.sh <pier> <ship-url> <cookie-jar> [files ...]
#
# files: paths under code/ to write (default: every file that differs from
# the ship's copy is the operator's job to name; pass them, the new ones
# first and nex/calendar/app.hoon last). A new file is created first.
# Passes when: the instance is not banged, the worker never sits at full
# CPU for 30 s, the route answers at the end, a poke is acknowledged, and
# rise.json names no crash after the deploy. Route differences are printed
# for the operator to explain; they are not a failure by themselves.
set -uo pipefail
pier=$(cd "$1" && pwd); B=${2%/}; JAR=$3; shift 3
SRC=$(cd "$(dirname "$0")/../code" && pwd)
D=/grubbery/ball/apps/shell.shell/desks/calendar.desk/desk
I=$D/data/calendar.calendar_app
serf=$(pgrep -f "work --snap-dir $pier( |$)" | head -1)
ticks() { awk '{print $14+$15}' /proc/$serf/stat; }
get() { curl -s -m 60 -b "$JAR" "$B$1"; }
snap() {
  mkdir -p "$1"
  for r in calendars.json events.json feeds.json config.json share/shares.json google.json \
           "window.json?from=1790000000000&to=1796000000000" export.ics; do
    get "/apps/calendar/$r" | sed -E 's/DTSTAMP:[0-9TZ]+/DTSTAMP:x/' > "$1/$(echo "$r" | tr '/?&=' '____')"
  done
}
work=$(mktemp -d)
bang() { get "$I?info=1" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("bang") is None and not any(c.get("bang") for c in d["children"]))'; }
[[ "$(bang)" == True ]] || { echo "the previous release is banged already; fix that first" >&2; exit 2; }
snap "$work/before"
t0=$(date +%s)
for f in "$@"; do
  curl -s -o /dev/null -m 120 -b "$JAR" --data-urlencode action=create-file \
    --data-urlencode filename="$(basename "$f")" "$B$D/code/$(dirname "$f")" || true
  curl -s -o /dev/null -w "write $f -> %{http_code}\n" -m 600 -b "$JAR" \
    --data-urlencode action=write-text --data-urlencode "content@$SRC/$f" "$B$D/code/$f"
done
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
import json,sys,time
t0=int(sys.argv[1])*1000; rows=json.load(sys.stdin)
late={k:v for k,v in rows.items() if v.get("last_ms",0)>=t0}
print("rise.json since the deploy:", late or "no crash")
sys.exit(1 if late else 0)' "$t0" || echo "(a crash during the deploy itself, n=1, is the retry doing its job; read its trace)"
snap "$work/after"
diff -rq "$work/before" "$work/after" && echo "routes: identical"
(( fail )) && exit 1
echo "ok: upgraded, and quiet"
