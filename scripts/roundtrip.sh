#!/usr/bin/env bash
# Export every calendar, import the file into a fresh calendar, export that
# one, and compare the VEVENT and VTODO blocks (DTSTAMP and SEQUENCE — both
# assigned by the ship on write — stripped, order-insensitive). Then the
# fixture (scripts/fixtures/roundtrip.ics) in and out: what it says that
# the ship does not model comes back as it went in.
# The gate for phase 2: what goes out comes back identical.
#   usage: roundtrip.sh HOST JAR   (JAR = a curl cookie jar for the ship)
set -uo pipefail
H=$1; J=$2; B=$H/apps/calendar; P=/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app
D=$(dirname "$0")
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
poke() { curl -s -m 60 -b "$J" -X POST -H 'content-type: application/json' -d "$1" -o /dev/null "$H/grubbery/api/poke$P/calendar.calendar?blot=/json"; }
has() { curl -s -m 60 -b "$J" "$B/calendars.json" | grep -q "\"id\":\"$1\""; }
delcal() { poke "{\"action\":\"del-calendar\",\"id\":\"$1\"}"; }
rc=0
delcal roundtrip; delcal roundtrip-fx; sleep 3
curl -s -m 120 -b "$J" "$B/export.ics" > "$T/a.ics"
n=$(grep -cE '^BEGIN:(VEVENT|VTODO)' "$T/a.ics"); echo "export: $n events and tasks, $(wc -c < "$T/a.ics") bytes"; [ "$n" -gt 0 ] || { echo "ROUNDTRIP FAILED: nothing to round-trip"; exit 1; }
poke '{"action":"add-calendar","id":"roundtrip","name":"roundtrip","color":"#888888"}'
sleep 3
# the import would make the calendar itself; a poke that did not land
# means the poke path is wrong, and the cleanup below would not land either
has roundtrip || { echo "ROUNDTRIP FAILED: the add-calendar poke did not land (poke path $P)"; exit 1; }
echo "import: $(curl -s -m 300 -b "$J" -X POST --data-binary "@$T/a.ics" "$B/import?cal=roundtrip")"
sleep 5
curl -s -m 120 -b "$J" "$B/export.ics?cal=roundtrip" > "$T/b.ics"
# one line per VEVENT (its lines joined with a separator), sorted, so blocks are
# compared whole rather than as a multiset of lines across the file
norm() { tr -d '\r' < "$1" | awk '/^BEGIN:(VEVENT|VTODO)/{b=1;blk=""} b{ if ($0 !~ /^(DTSTAMP|SEQUENCE)/) blk=blk $0 "\x1f" } /^END:(VEVENT|VTODO)/{b=0; print blk}' | sort | tr '\037' '\n' | sed -E 's/^END:(VEVENT|VTODO)$/&\n----/'; }
if diff <(norm "$T/a.ics") <(norm "$T/b.ics") > "$T/diff.txt"; then echo "export stable ($(grep -cE '^BEGIN:(VEVENT|VTODO)' "$T/b.ics") events and tasks)"; else echo "FAIL export(import(export)) differs"; head -40 "$T/diff.txt"; rc=1; fi
# the fixture: the original's own lines survive
echo "fixture import: $(curl -s -m 120 -b "$J" -X POST --data-binary "@$D/fixtures/roundtrip.ics" "$B/import?cal=roundtrip-fx")"
sleep 4
curl -s -m 120 -b "$J" "$B/export.ics?cal=roundtrip-fx" | tr -d '\r' > "$T/fx.ics"
for want in 'LOCATION:Room 4' 'X-FOREIGN-PROP;LANG=en:kept verbatim' 'DESCRIPTION:two days\, with a comma' 'TRIGGER:-PT15M' 'DTSTART;TZID=America/New_York:20260921T100000' 'EXDATE:20260917T120000Z' 'COUNT=5' 'DTEND;VALUE=DATE:20260922'; do
  grep -qF "$want" "$T/fx.ics" || { echo "FAIL fixture lost: $want"; rc=1; }
done
delcal roundtrip; delcal roundtrip-fx; sleep 3
if has roundtrip || has roundtrip-fx; then echo "FAIL cleanup: a roundtrip calendar is left"; rc=1; fi
[ $rc = 0 ] && echo "ROUNDTRIP PASSED" || echo "ROUNDTRIP FAILED"
exit $rc
