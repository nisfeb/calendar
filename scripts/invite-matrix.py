#!/usr/bin/env python3
"""invite-matrix.py HOST HJAR GUEST GJAR HOSTNAME GUESTNAME
Invitations to one event, ship to ship. HOST invites GUEST by @p (meta
ships); the guest's ship lists it; the guest accepts onto a calendar of
its choosing and the host hears the answer; the host's changes follow to
the copy; the host's next invitation offers the same calendar; a decline
reaches the host; the copy never invites anyone itself; taking the guest
off, or deleting the event, takes the copy and the invitation away.
Cleans up. HOSTNAME and GUESTNAME are the ships' @p (e.g. ~bes ~reb)."""
import sys, json, subprocess, time

HOST, HJ, GUEST, GJ, HOSTNAME, GUESTNAME = sys.argv[1:7]
P = '/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app'
fails = []


def curl(host, jar, path, body=None, timeout=90):
    cmd = ['curl', '-s', '-m', str(timeout), '-b', jar, host + path]
    if body is not None:
        cmd += ['-X', 'POST', '-H', 'content-type: application/json', '-d', json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    try: return json.loads(out)
    except Exception: return out


def poke(host, jar, body): return curl(host, jar, f'/grubbery/api/poke{P}/calendar.calendar?blot=/json', body)
def events(host, jar, cal): return [e for e in (curl(host, jar, '/apps/calendar/events.json') or []) if e['cal'] == cal]
def invites(host, jar): return curl(host, jar, '/apps/calendar/invites.json') or []


def check(label, cond, detail=''):
    print(('ok   ' if cond else 'FAIL ') + label + ('' if cond else ' — ' + str(detail)[:300]))
    if not cond: fails.append(label)


def wait(fn, secs=90):
    t0 = time.time()
    while time.time() - t0 < secs:
        try:
            v = fn()
            if v: return v
        except Exception: pass
        time.sleep(3)
    return None


def meet(name, ships, start=1793023200000, extra=None):
    m = {'name': name, 'ships': ships}
    m.update(extra or {})
    return {'cal': 'inv', 'cat': 'timed', 'kind': 'once', 'start_ms': start, 'fin': 'dur', 'dur_min': 60, 'meta': m}


def row(name):
    return ([r for r in invites(GUEST, GJ) if r.get('name') == name] or [None])[0]


def host_ships(name):
    e = [x for x in events(HOST, HJ, 'inv') if x['meta']['name'].startswith(name)]
    return e and {g['ship']: g.get('status') for g in e[0]['meta'].get('ships', [])}


for host, jar, cal in ((HOST, HJ, 'inv'), (GUEST, GJ, 'urbit')):
    poke(host, jar, {'action': 'del-calendar', 'id': cal})
    poke(host, jar, {'action': 'add-calendar', 'id': cal, 'name': 'invite gate ' + cal})
wait(lambda: 'urbit' in {c['id'] for c in curl(GUEST, GJ, '/apps/calendar/calendars.json')}, 30)

# the invitation arrives
poke(HOST, HJ, dict(meet('inv meeting', [{'ship': GUESTNAME, 'status': 'needs-action'}], extra={'location': 'Room 1'}), action='add-event', id='inv-meeting@gate'))
r = wait(lambda: row('inv meeting'))
check('the guest lists the invitation, unanswered', r and r['host'] == HOSTNAME and r['status'] == '' and 'ics' not in r, r)

# accepted onto a calendar the guest picks
a = curl(GUEST, GJ, '/apps/calendar/invites/answer', {'key': r['key'] if r else '', 'status': 'accepted', 'cal': 'urbit'})
check('the answer is taken and the host told', isinstance(a, dict) and a.get('ok') and a.get('told') and a.get('cal') == 'urbit', a)
cp = wait(lambda: [e for e in events(GUEST, GJ, 'urbit') if e['meta']['name'] == 'inv meeting'])
cm = cp and cp[0]['meta'] or {}
check('the copy is on the chosen calendar, marked as the host\'s', cm.get('host') == HOSTNAME and cm.get('location') == 'Room 1'
      and [g.get('status') for g in cm.get('ships', []) if g.get('self')] == ['accepted'], cm)
check('the host hears the answer', wait(lambda: host_ships('inv meeting') == {GUESTNAME: 'accepted'}), host_ships('inv meeting'))

# the host's change follows
poke(HOST, HJ, dict(meet('inv meeting moved', [{'ship': GUESTNAME, 'status': 'accepted'}], start=1793026800000, extra={'location': 'Room 2'}), action='edit-event', id='inv-meeting@gate'))
moved = wait(lambda: [e for e in events(GUEST, GJ, 'urbit') if e['meta']['name'] == 'inv meeting moved'])
check('the host\'s change reaches the copy, the answer kept', moved and moved[0]['meta'].get('location') == 'Room 2'
      and [g.get('status') for g in moved[0]['meta'].get('ships', []) if g.get('self')] == ['accepted'], moved)

# one occurrence of an invited series moved: no second invitation, and the
# guest's copy shows the move
poke(HOST, HJ, {'action': 'add-event', 'cal': 'inv', 'id': 'inv-weekly@gate', 'cat': 'timed', 'kind': 'weekly', 'start_ms': 1792404000000,
                'args': {'days': ['mon'], 'at': 600}, 'count': 3, 'fin': 'dur', 'dur_min': 60,
                'meta': {'name': 'inv weekly', 'ships': [{'ship': GUESTNAME, 'status': 'needs-action'}]}})
rw = wait(lambda: row('inv weekly'))
curl(GUEST, GJ, '/apps/calendar/invites/answer', {'key': rw['key'] if rw else '', 'status': 'accepted', 'cal': 'urbit'})
wait(lambda: [e for e in events(GUEST, GJ, 'urbit') if e['meta']['name'] == 'inv weekly'])
poke(HOST, HJ, {'action': 'edit-at', 'id': 'inv-weekly@gate', 'at_ms': 1792404000000 + 7 * 86400000, 'cat': 'timed', 'kind': 'once',
                'start_ms': 1792404000000 + 8 * 86400000, 'fin': 'dur', 'dur_min': 60,
                'meta': {'name': 'inv weekly (Tuesday)', 'ships': [{'ship': GUESTNAME, 'status': 'accepted'}]}})
gw = wait(lambda: [e for e in events(GUEST, GJ, 'urbit') if e['meta']['name'] == 'inv weekly (Tuesday)'])
check('a moved occurrence reaches the copy in its series', gw and len([e for e in events(GUEST, GJ, 'urbit') if e['meta']['name'] == 'inv weekly']) == 1, events(GUEST, GJ, 'urbit'))
check('and sends no second invitation', len([r for r in invites(GUEST, GJ) if r.get('name', '').startswith('inv weekly')]) == 1, invites(GUEST, GJ))
poke(HOST, HJ, {'action': 'del-event', 'id': 'inv-weekly@gate'})

# the next invitation from that host offers the same calendar; a decline reaches the host
poke(HOST, HJ, dict(meet('inv drinks', [{'ship': GUESTNAME, 'status': 'needs-action'}], start=1793050800000), action='add-event', id='inv-drinks@gate'))
r2 = wait(lambda: row('inv drinks'))
check('the next invitation offers the calendar picked last time', r2 and r2.get('route') == 'urbit', r2)
d = curl(GUEST, GJ, '/apps/calendar/invites/answer', {'key': r2['key'] if r2 else '', 'status': 'declined'})
check('a decline puts nothing on a calendar', isinstance(d, dict) and d.get('told') and not [e for e in events(GUEST, GJ, 'urbit') if e['meta']['name'] == 'inv drinks'], d)
check('the host hears the decline', wait(lambda: host_ships('inv drinks') == {GUESTNAME: 'declined'}), host_ships('inv drinks'))

# a copy is not the guest's to send on
time.sleep(10)
check('the copy sends no invitation of its own', not invites(HOST, HJ), invites(HOST, HJ))

# taken off the guest list: the copy and the invitation go
poke(HOST, HJ, dict(meet('inv meeting moved', [], start=1793026800000), action='edit-event', id='inv-meeting@gate'))
check('taken off the list, the copy goes', wait(lambda: not [e for e in events(GUEST, GJ, 'urbit') if e['meta']['name'].startswith('inv meeting')] and not row('inv meeting moved')),
      events(GUEST, GJ, 'urbit'))
# deleted: the invitation goes
poke(HOST, HJ, {'action': 'del-event', 'id': 'inv-drinks@gate'})
check('a deleted event takes its invitation away', wait(lambda: not row('inv drinks')), invites(GUEST, GJ))

for host, jar, cal in ((HOST, HJ, 'inv'), (GUEST, GJ, 'urbit')):
    poke(host, jar, {'action': 'del-calendar', 'id': cal})
print('INVITE MATRIX', 'FAILED (%d)' % len(fails) if fails else 'PASSED')
sys.exit(1 if fails else 0)
