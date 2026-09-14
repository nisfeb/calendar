#!/usr/bin/env bash
# Export every calendar, import the file into a fresh calendar, export that
# one, and compare the VEVENT blocks (DTSTAMP and SEQUENCE — both assigned
# by the ship on write — stripped, order-insensitive).
# The gate for phase 2: what goes out comes back identical.
#   usage: roundtrip.sh HOST JAR   (JAR = a curl cookie jar for the ship)
set -uo pipefail
H=$1; J=$2; B=$H/apps/calendar; P=/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app
T=$(mktemp -d)
delcal() { curl -s -m 60 -b "$J" -X POST -H 'content-type: application/json' -d '{"action":"del-calendar","id":"roundtrip"}' -o /dev/null "$H/grubbery/api/poke$P/calendar.calendar?blot=/json"; }
delcal; sleep 3
curl -s -m 120 -b "$J" "$B/export.ics" > "$T/a.ics"
n=$(grep -c '^BEGIN:VEVENT' "$T/a.ics"); echo "export: $n events, $(wc -c < "$T/a.ics") bytes"; [ "$n" -gt 0 ] || { echo "ROUNDTRIP FAILED: nothing to round-trip"; exit 1; }
curl -s -m 60 -b "$J" -X POST -H 'content-type: application/json' -d '{"action":"add-calendar","id":"roundtrip","name":"roundtrip","color":"#888888"}' -o /dev/null "$H/grubbery/api/poke$P/calendar.calendar?blot=/json"
sleep 3
echo "import: $(curl -s -m 300 -b "$J" -X POST --data-binary "@$T/a.ics" "$B/import?cal=roundtrip")"
sleep 5
curl -s -m 120 -b "$J" "$B/export.ics?cal=roundtrip" > "$T/b.ics"
# one line per VEVENT (its lines joined with a separator), sorted, so blocks are
# compared whole rather than as a multiset of lines across the file
norm() { tr -d '\r' < "$1" | awk '/^BEGIN:VEVENT/{b=1;blk=""} b{ if ($0 !~ /^(DTSTAMP|SEQUENCE)/) blk=blk $0 "\x1f" } /^END:VEVENT/{b=0; print blk}' | sort | tr '\037' '\n' | sed 's/^END:VEVENT$/&\n----/'; }
if diff <(norm "$T/a.ics") <(norm "$T/b.ics") > "$T/diff.txt"; then echo "ROUNDTRIP PASSED ($(grep -c '^BEGIN:VEVENT' "$T/b.ics") events)"; rc=0; else echo "ROUNDTRIP FAILED"; head -40 "$T/diff.txt"; rc=1; fi
delcal; exit $rc
