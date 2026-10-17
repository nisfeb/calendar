#!/usr/bin/env python3
"""talon-matrix.py SHIP_URL COOKIE_JAR
Talon calls (trunk wire 19): an event that asks for one (meta call
'talon') gets a link from trunk, which becomes its join link and a line
in its note; an edit does not ask again; taking the call off ends the
link, and asking again gives a new one; deleting the event closes its
room; trunk refusing (calendar switched off on the trunk page) is a fault
that says what to do. Cleans up.

The ship needs %trunk at wire 19 with a call server and its public
address set, grubbery's trunk mark carrying app links, the peek road to
the calendar's answer path granted, and "calendar (through grubbery)"
switched on at /apps/trunk (TESTING.md). It refuses a ship whose trunk
is older."""
import sys, json, subprocess, time, re

SHIP, JAR = sys.argv[1].rstrip('/'), sys.argv[2]
POKE = SHIP + '/grubbery/api/poke/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app/calendar.calendar?blot=/json'
ROOMS = SHIP + '/grubbery/api/file/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app/talon-rooms.json'
fails = []


def curl(url, body=None):
    cmd = ['curl', '-s', '-L', '-m', '60', '-b', JAR, url]
    if body is not None: cmd += ['-H', 'content-type: application/json', '-d', json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    try: return json.loads(out)
    except Exception: return out


def poke(body): curl(POKE, body)
def meta(uid):
    e = curl(SHIP + '/apps/calendar/event.json?id=' + uid.replace('@', '%40'))
    return e.get('meta', {}) if isinstance(e, dict) else {}
def faults(): return (curl(SHIP + '/apps/calendar/outcomes.json') or {}).get('faults') or {}
def allow(on): curl(SHIP + '/apps/trunk/action', {'app-hosting': {'agent': 'grubbery/calendar', 'allow': on}})


def check(label, cond, detail=''):
    print(('ok   ' if cond else 'FAIL ') + label + ('' if cond else ' — ' + str(detail)[:300]))
    if not cond: fails.append(label)


def wait(fn, secs=60):
    t0 = time.time()
    while time.time() - t0 < secs:
        try:
            v = fn()
            if v: return v
        except Exception: pass
        time.sleep(3)
    return None


def ev(name, dur=30, **m):
    mm = {'name': name}; mm.update(m)
    return {'cat': 'timed', 'kind': 'once', 'start_ms': 1793023200000, 'fin': 'dur', 'dur_min': dur, 'meta': mm}


ver = curl(SHIP + '/~/scry/trunk/version.json')
if not isinstance(ver, dict) or ver.get('wire', 0) < 19:
    print('refusing: this ship\'s trunk is not at wire 19 (%s)' % ver); sys.exit(2)
allow(True)
UID = 'talon-gate@gate'
poke({'action': 'del-event', 'id': UID}); time.sleep(3)

# a link made, onto the event
poke(dict(ev('talon gate', note='agenda', call='talon'), action='add-event', id=UID))
m1 = wait(lambda: meta(UID).get('conference') and meta(UID))
url1 = (m1 or {}).get('conference', '')
check('the event gets a link from trunk', re.search(r'/join/#.+/[0-9a-f]{32}$', url1 or '') is not None, m1)
check('the link is in the note, the call no longer asked for', m1 and url1 in m1.get('note', '') and m1.get('note', '').startswith('agenda') and 'call' not in m1 and m1.get('talon_room', '').startswith('e-'), m1)
room = (m1 or {}).get('talon_room', '')
check('the room is kept', room in (curl(ROOMS) or {}), curl(ROOMS))

# an edit keeps the link and asks nothing
poke(dict(ev('talon gate renamed', **{k: v for k, v in (m1 or {}).items() if k != 'name'}), action='edit-event', id=UID))
time.sleep(10)
check('an edit keeps the link', meta(UID).get('conference') == url1 and meta(UID).get('name') == 'talon gate renamed', meta(UID))

# the call taken off ends the link; asking again gives a new one
poke(dict(ev('talon gate renamed', note='agenda'), action='edit-event', id=UID))
check('taking the call off closes the room', wait(lambda: room not in (curl(ROOMS) or {})), curl(ROOMS))
poke(dict(ev('talon gate renamed', note='agenda', call='talon'), action='edit-event', id=UID))
m2 = wait(lambda: meta(UID).get('conference') and meta(UID))
url2 = (m2 or {}).get('conference', '')
check('asking again gives a new link', url2 and url2 != url1 and (m2 or {}).get('talon_room') == room, (url1, url2))

# deleting the event closes its room
poke({'action': 'del-event', 'id': UID})
check('deleting the event closes its room', wait(lambda: room not in (curl(ROOMS) or {})), curl(ROOMS))

# trunk refusing: a fault that says what to do
allow(False)
poke(dict(ev('talon refused', call='talon'), action='add-event', id='talon-off@gate'))
f = wait(lambda: faults().get('talon'))
check('a refusal is a fault naming the fix', f and 'apps may not host calls' in f.get('what', '') and '/apps/trunk' in f.get('remedy', ''), f)
allow(True)
poke({'action': 'del-event', 'id': 'talon-off@gate'})
check('cleanup', wait(lambda: not (curl(ROOMS) or {})), curl(ROOMS))
print('TALON MATRIX', 'FAILED (%d)' % len(fails) if fails else 'PASSED')
sys.exit(1 if fails else 0)
