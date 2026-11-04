#!/usr/bin/env python3
"""The scale gate: an import's cost does not grow with the rest of the
store, and a one-event change stays near what it costs on a small one.

    usage: scale-matrix.py SHIP_URL COOKIE_JAR [N_ONEOFF N_SERIES]

Imports a Google-shaped calendar (default 1,300 one-offs and 100 weekly
series, each with an organizer, five guests, a 2 KB description and an
alarm) into a new calendar scale-a, one event into it three times, the
same again under new UIDs into scale-b, then deletes both. Each request
is timed; the ship answers nothing while one runs. Fails when the second
import costs over 1.5 times the first, or a one-event change on the big
store over 2.5 times one on the store as it was, or a delete of a big
calendar over 3 times that. Takes about two minutes; the first change
after a reload builds the cache whole, so it runs one change first.
"""
import datetime as dt, json, random, subprocess, sys, tempfile, time

BASE, JAR = sys.argv[1].rstrip('/'), sys.argv[2]
N1, NS = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else (1300, 100)
POKE = BASE + '/grubbery/api/poke/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app/calendar.calendar?blot=/json'
fails = []


def check(name, ok, detail=''):
    print(('  ok   ' if ok else '  FAIL ') + name + ('' if ok else ' -- %s' % (detail,)), flush=True)
    if not ok: fails.append(name)


def curl(*a, t=1800):
    return subprocess.run(['curl', '-s', '-m', str(t), '-b', JAR, *a], capture_output=True, text=True).stdout


def quiet():
    # the ship answers a cheap route at once, five times running
    calm = 0
    while calm < 5:
        t = time.time(); ok = curl('-o', '/dev/null', '-w', '%{http_code}', BASE + '/~/name', t=5) == '200'
        calm = calm + 1 if ok and time.time() - t < 0.3 else 0
        time.sleep(0.5)


def timed(f):
    quiet(); t = time.time(); out = f(); return time.time() - t, out


def ics(prefix, n1, ns):
    random.seed(7)
    names = ['Avery Hale', 'Blake Moreno', 'Casey Lin', 'Devon Price', 'Emery Shaw', 'Finley Ross', 'Gray Patel', 'Harper Quinn', 'Indy Cole', 'Jules Reyes']
    now = dt.datetime(2026, 11, 3, 12, tzinfo=dt.timezone.utc)
    fmt = lambda d: d.strftime('%Y%m%dT%H%M%SZ')
    desc = ('Agenda and notes. ' * 120)[:2000]
    out = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//scale//EN']

    def ev(uid, start, mins, title, rrule=None):
        o = ['BEGIN:VEVENT', 'DTSTART:' + fmt(start), 'DTEND:' + fmt(start + dt.timedelta(minutes=mins)), 'DTSTAMP:' + fmt(now)]
        if rrule: o.append('RRULE:' + rrule)
        org = random.choice(names)
        o.append(f'ORGANIZER;CN={org}:mailto:{org.split()[0].lower()}@example.com')
        o += [f'ATTENDEE;PARTSTAT=ACCEPTED;CN={g}:mailto:{g.split()[0].lower()}@example.com' for g in random.sample(names, 5)]
        o += ['UID:' + uid, 'DESCRIPTION:' + desc, 'LOCATION:Room 4', 'SUMMARY:' + title,
              'BEGIN:VALARM', 'ACTION:DISPLAY', 'DESCRIPTION:reminder', 'TRIGGER:-PT10M', 'END:VALARM', 'END:VEVENT']
        return o
    for i in range(n1):
        s = (now + dt.timedelta(days=random.uniform(-730, 90))).replace(minute=random.choice([0, 30]), second=0, microsecond=0)
        out += ev(f'{prefix}{i:05d}@scale', s, random.choice([30, 60, 90]), f'Meeting {i % 300}')
    for j in range(ns):
        s = (now - dt.timedelta(days=random.uniform(30, 700))).replace(minute=0, second=0, microsecond=0)
        until = '' if j % 3 else ';UNTIL=' + fmt(now + dt.timedelta(days=random.uniform(-200, 200)))
        out += ev(f'{prefix}s{j:04d}@scale', s, 60, f'Weekly {j}', 'FREQ=WEEKLY' + until)
    out.append('END:VCALENDAR')
    f = tempfile.NamedTemporaryFile('w', suffix='.ics', delete=False)
    f.write('\r\n'.join(out) + '\r\n'); f.close()
    return f.name


def imp(cal, path):
    return lambda: json.loads(curl('-X', 'POST', '-H', 'content-type: text/calendar', '--data-binary', '@' + path,
                                   f'{BASE}/apps/calendar/import?cal={cal}') or '{}')


def delcal(cal):
    return lambda: curl('-o', '/dev/null', '-w', '%{http_code}', '-H', 'content-type: application/json',
                        '-d', json.dumps({'action': 'del-calendar', 'id': cal}), POKE)


n = 0
def one(cal):
    global n
    n += 1
    return imp(cal, ics(f'scale-one-{int(time.time())}-{n}-', 1, 0))


for c in ('scale-a', 'scale-b'): timed(delcal(c))
timed(one('scale-a'))                       # the build after a reload, if one is due
t_small, _ = timed(one('scale-a'))
t1, r1 = timed(imp('scale-a', ics('a', N1, NS)))
check('the first import takes every object', r1.get('imported') == N1 + NS, r1)
ones = sorted(timed(one('scale-a'))[0] for _ in range(3))
t_one = ones[1]
t2, r2 = timed(imp('scale-b', ics('b', N1, NS)))
check('the second import takes every object', r2.get('imported') == N1 + NS, r2)
t_del, _ = timed(delcal('scale-b'))
timed(delcal('scale-a'))
print(f'one event on the store as it was {t_small:.1f} s; import of {N1 + NS} {t1:.1f} s; one event then {t_one:.1f} s; '
      f'the second import {t2:.1f} s; its delete {t_del:.1f} s', flush=True)
check('an import into a full store costs about what one into the store before did', t2 <= 1.5 * t1, f'{t2:.1f} s against {t1:.1f} s')
check('a one-event change on the big store stays near one on the small', t_one <= 2.5 * t_small, f'{t_one:.1f} s against {t_small:.1f} s')
check('deleting a big calendar costs seconds', t_del <= 3 * t_small, f'{t_del:.1f} s against {t_small:.1f} s')
print('SCALE MATRIX ' + ('PASSED' if not fails else 'FAILED (%d)' % len(fails)))
sys.exit(1 if fails else 0)
