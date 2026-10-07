#!/usr/bin/env bash
# The quiet gate (docs/logging.md; the logging policy's Enforcement): a
# healthy calendar prints nothing; a refused road is said once, with its
# remedy, and recorded; granting it again clears the record.
#
#   quiet-check.sh <pier> <ship-url> <cookie-jar> [files ...]
#
# Captures the ship's console (the tmux pane of the pier's king) while the
# calendar
#   reload       is reloaded: no calendar line;
#   upgrade      with files given (paths under code/, nex/calendar/app.hoon
#                last), takes them through upgrade-check.sh: no calendar
#                line;
#   refuse       loses /sys/behn/ and is reloaded: exactly one line about
#                it, the kernel's for the app it parks ("grubbery: <app> is
#                parked: ..."), naming the permits page; no calendar line;
#                road/behn in outcomes.json;
#   grant        gets it back and is reloaded: the record is gone and the
#                calendar prints nothing;
#   refuse-web   loses /sys/eyre/ and is reloaded. Nothing parks on that
#                road, so the kernel says nothing and the one line is the
#                calendar's, naming the permits page; road/eyre recorded;
#   grant-web    gets it back and is reloaded: the record is gone, with the
#                one "cleared" notice.
# A calendar line is one that begins, after its marker, with "calendar: ",
# or anything in the old style (a %calendar-... noun). Whatever else the
# console shows is the kernel's or a vane's: named and counted, not failed
# (docs/logging.md, Known noise). Needs a kernel with the quiet console
# (grubbery dist/single-release 5ae72f0 or later). The roads are put back
# and the capture stopped whatever happens.
set -uo pipefail
pier=$(cd "$1" && pwd); B=${2%/}; JAR=$3; shift 3
here=$(cd "$(dirname "$0")" && pwd)
I=/grubbery/ball/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app
WAIT=${QUIET_WAIT:-60}
# the console pane: QUIET_PANE (e.g. 0:ryc) when the king was not started
# with the pier as its last argument, else found by the king's tty
king=$(pgrep -f "vere.* $(basename "$pier")/?\$" | head -1)
pane=${QUIET_PANE:-$(tmux list-panes -a -F '#{pane_tty} #{session_name}:#{window_index}.#{pane_index}' |
  awk -v t="$(readlink "/proc/$king/fd/0" 2>/dev/null)" '$1==t{print $2}')}
[[ -n "$pane" ]] || { echo "no tmux pane found for $pier" >&2; exit 2; }
cap=$(mktemp)
post() { curl -s -o /dev/null -m 120 -b "$JAR" --data-urlencode action="$1" "${@:2}" "$B$I"; }
road() { post "$1" --data-urlencode category=poke --data-urlencode road-path="$2"; }
# the record is read through the kernel's route, which answers with the
# calendar's own web road refused
fault() { curl -sL -m 60 -b "$JAR" "$B$I/outcomes.json?raw=1" | python3 -c 'import json,sys
try: print("yes" if sys.argv[1] in json.load(sys.stdin).get("faults", {}) else "no")
except Exception: print("unreadable")' "$1"; }
finish() { tmux pipe-pane -t "$pane"; road add-weir-road /sys/behn/; road add-weir-road /sys/eyre/; post reload-nexus; }
trap finish EXIT
tmux pipe-pane -o -t "$pane" "cat >> $cap"
mark() { sleep 1; printf '\n### %s\n' "$1" >> "$cap"; }

mark reload;      post reload-nexus; sleep "$WAIT"
if (( $# )); then mark upgrade; "$here/upgrade-check.sh" "$pier" "$B" "$JAR" "$@" | tail -4; fi
mark refuse;      road del-weir-road /sys/behn/; post reload-nexus; sleep "$WAIT"; r1=$(fault road/behn)
mark grant;       road add-weir-road /sys/behn/; post reload-nexus; sleep "$WAIT"; g1=$(fault road/behn)
mark refuseweb;   road del-weir-road /sys/eyre/; post reload-nexus; sleep "$WAIT"; r2=$(fault road/eyre)
mark grantweb;    road add-weir-road /sys/eyre/; post reload-nexus; sleep "$WAIT"; g2=$(fault road/eyre)
mark end
tmux pipe-pane -t "$pane"

python3 - "$cap" "$r1" "$g1" "$r2" "$g2" <<'PY'
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
parked = lambda s: [x for x in re.findall(r'>+ +"grubbery: [^"]*is parked[^"]*', joined.get(s, '')) if 'calendar' in x]
fails = []
def check(name, ok, detail=''):
    print(('ok   ' if ok else 'FAIL ') + name + ('' if ok else ' — ' + str(detail)[:400]))
    if not ok: fails.append(name)
for s in ('reload', 'upgrade'):
    if s in seg: check('%s: the calendar prints nothing' % s, not mine(s), mine(s))
p = parked('refuse')
check('refuse: the calendar adds no line of its own', not mine('refuse'), mine('refuse'))
check('refuse: exactly one line about it, the kernel\'s for the parked app', len(p) == 1, p or 'none: this kernel predates the quiet console')
check('refuse: that line names the permits page', len(p) == 1 and 'permits' in p[0].lower(), p)
check('refuse: road/behn is recorded in outcomes.json', sys.argv[2] == 'yes', sys.argv[2])
check('grant: the record clears', sys.argv[3] == 'no', sys.argv[3])
check('grant: the calendar prints nothing', not mine('grant'), mine('grant'))
w = mine('refuseweb')
check('refuse-web: nothing parks, so the kernel says nothing', not parked('refuseweb'), parked('refuseweb'))
check('refuse-web: exactly one line, the calendar\'s, naming the permits page', len(w) == 1 and '/sys/eyre/' in w[0] and 'permits' in w[0].lower(), w)
check('refuse-web: road/eyre is recorded in outcomes.json', sys.argv[4] == 'yes', sys.argv[4])
gw = mine('grantweb')
check('grant-web: the record clears', sys.argv[5] == 'no', sys.argv[5])
check('grant-web: the one cleared notice, and nothing else', len(gw) == 1 and 'road/eyre cleared' in gw[0], gw)
print('--- not the calendar\'s (kernel, vanes, other apps):')
noise = [('the parked app line', r'"grubbery: [^"]*is parked'), ('%sand-applied', r'%sand-applied'), ('%desk-instance-reloaded', r'%desk-instance-reloaded'),
         ('%fiber-crash', r'%fiber-crash'), ('BANG nexus', r'BANG nexus'), ('eyre binding', r'replacing existing binding'),
         ('desk source unreachable', r'%desk-source-unreachable'), ('veto nouns (an older kernel)', r'%weir-veto-at|%process-dart-vetoed|%sand-applying')]
for s in ('reload', 'upgrade', 'refuse', 'grant', 'refuseweb', 'grantweb'):
    if s not in seg: continue
    found = ['%s x%d' % (n, len(re.findall(pat, joined[s]))) for n, pat in noise if re.search(pat, joined[s])]
    print('  %s: %s' % (s, ', '.join(found) or 'nothing known'))
print('QUIET CHECK ' + ('PASSED' if not fails else 'FAILED (%d)' % len(fails)))
sys.exit(1 if fails else 0)
PY
