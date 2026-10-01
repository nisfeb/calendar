#!/usr/bin/env bash
# The quiet gate (docs/logging.md; the logging policy's Enforcement): a
# healthy calendar prints nothing; a refused road prints exactly one line,
# with its remedy, and is recorded; granting it again clears the record.
#
#   quiet-check.sh <pier> <ship-url> <cookie-jar> [files ...]
#
# Captures the ship's console (the tmux pane of the pier's king) while the
# calendar
#   reload   is reloaded: no calendar line;
#   upgrade  with files given (paths under code/, nex/calendar/app.hoon
#            last), takes them through upgrade-check.sh: no calendar line;
#   refuse   loses /sys/behn/ and is reloaded: exactly one line about it,
#            naming the permits page, and a road/behn fault in
#            outcomes.json. The line is the kernel's, for the fibers it
#            parks ("grubbery: <app> is parked: ..."); the calendar adds
#            the record and no second line;
#   grant    gets the road back and is reloaded: the fault is gone, and
#            the calendar prints nothing.
# A calendar line is one that begins, after its marker, with "calendar: ".
# Whatever else the console shows in that time is the kernel's or a
# vane's: counted and sampled, not failed (docs/logging.md, Known noise).
# The road is put back and the capture stopped whatever happens.
set -uo pipefail
pier=$(cd "$1" && pwd); B=${2%/}; JAR=$3; shift 3
here=$(cd "$(dirname "$0")" && pwd)
I=/grubbery/ball/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app
WAIT=${QUIET_WAIT:-60}
king=$(pgrep -f "vere.* $(basename "$pier")/?\$" | head -1)
pane=$(tmux list-panes -a -F '#{pane_tty} #{session_name}:#{window_index}.#{pane_index}' |
  awk -v t="$(readlink "/proc/$king/fd/0" 2>/dev/null)" '$1==t{print $2}')
[[ -n "$pane" ]] || { echo "no tmux pane found for $pier" >&2; exit 2; }
cap=$(mktemp)
post() { curl -s -o /dev/null -m 120 -b "$JAR" --data-urlencode action="$1" "${@:2}" "$B$I"; }
road() { post "$1" --data-urlencode category=poke --data-urlencode road-path=/sys/behn/; }
fault() { curl -s -m 60 -b "$JAR" "$B/apps/calendar/outcomes.json" | python3 -c 'import json,sys
try: print("yes" if "road/behn" in json.load(sys.stdin).get("faults", {}) else "no")
except Exception: print("unreadable")'; }
finish() { tmux pipe-pane -t "$pane"; road add-weir-road; post reload-nexus; }
trap finish EXIT
tmux pipe-pane -o -t "$pane" "cat >> $cap"
mark() { sleep 1; printf '\n### %s\n' "$1" >> "$cap"; }

mark reload;  post reload-nexus; sleep "$WAIT"
if (( $# )); then mark upgrade; "$here/upgrade-check.sh" "$pier" "$B" "$JAR" "$@" | tail -4; fi
mark refuse;  road del-weir-road; post reload-nexus; sleep "$WAIT"; refused=$(fault)
mark grant;   road add-weir-road; post reload-nexus; sleep "$WAIT"; granted=$(fault)
mark end
tmux pipe-pane -t "$pane"

python3 - "$cap" "$refused" "$granted" <<'PY'
import re, sys
raw = open(sys.argv[1], 'rb').read().decode('utf-8', 'replace')
txt = re.sub(r'\x1b\[[0-9;?]*[A-Za-z]|\x1b[()][A-Za-z0-9]|\r', '', raw)
seg, cur = {}, None
for l in txt.split('\n'):
    m = re.match(r'### (\w+)$', l.strip())
    if m: cur = m.group(1); seg[cur] = []; continue
    if cur and l.strip(): seg[cur].append(l)
# The terminal wraps a long line and the dojo redraws its prompt and
# spinner in front of one, so a line is looked for anywhere in the
# segment with its wraps joined, never at a line's start.
joined = {k: ''.join(v) for k, v in seg.items()}
# a calendar line: the convention ("calendar: ..."), or anything in the
# old style (a %calendar-... noun, a "%calendar ..." tape) that a change
# might bring back
mine = lambda s: re.findall(r'>+ +"calendar: [^"]*|%calendar[-: ][^\]"]{0,80}', joined.get(s, ''))
parked = lambda s: re.findall(r'>+ +"grubbery: [^"]*is parked[^"]*', joined.get(s, ''))
fails = []
def check(name, ok, detail=''):
    print(('ok   ' if ok else 'FAIL ') + name + ('' if ok else ' — ' + str(detail)[:400]))
    if not ok: fails.append(name)
for s in ('reload', 'upgrade'):
    if s in seg: check('%s: the calendar prints nothing' % s, not mine(s), mine(s))
p = [x for x in parked('refuse') if 'calendar' in x]
check('refuse: the calendar adds no line of its own', not mine('refuse'), mine('refuse'))
check('refuse: exactly one line about it, the kernel\'s for the parked app', len(p) == 1, p or 'none: a kernel before quiet-console prints its veto nouns instead')
check('refuse: that line names the permits page', len(p) == 1 and 'permits' in p[0].lower(), p)
check('refuse: the fault is recorded in outcomes.json', sys.argv[2] == 'yes', sys.argv[2])
check('grant: the record clears', sys.argv[3] == 'no', sys.argv[3])
check('grant: the calendar prints nothing', not mine('grant'), mine('grant'))
print('--- not the calendar\'s (kernel, vanes, other apps):')
noise = [('the parked app line', r'"grubbery: [^"]*is parked'), ('%sand-applied', r'%sand-applied'), ('%sand-applying', r'%sand-applying'),
         ('veto nouns', r'%weir-veto-at|%process-dart-vetoed'), ('eyre binding', r'replacing existing binding'), ('desk source unreachable', r'%desk-source-unreachable')]
for s in ('reload', 'upgrade', 'refuse', 'grant'):
    if s not in seg: continue
    found = ['%s x%d' % (n, len(re.findall(pat, joined[s]))) for n, pat in noise if re.search(pat, joined[s])]
    print('  %s: %s' % (s, ', '.join(found) or 'nothing known'))
print('QUIET CHECK ' + ('PASSED' if not fails else 'FAILED (%d)' % len(fails)))
sys.exit(1 if fails else 0)
PY
