#!/usr/bin/env python3
"""The CalDAV client gate, ship to ship: FOLLOWER follows SOURCE's default
calendar through a client password minted on SOURCE.

    usage: caldav-client-matrix.py SOURCE_URL SOURCE_JAR FOLLOWER_URL FOLLOWER_JAR

Both directions: add / edit / delete on the follower reach the source at
once; the source's changes arrive on the follower's next pass; a moved
instance crosses; nothing echoes; a stale If-Match is logged as a
conflict. Cleans up. Non-zero on the first failure.
"""
import sys, json, time, subprocess

SRC, SJ, FOL, FJ = sys.argv[1:5]
POKE = '/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app'
fails = 0


def check(name, ok, detail=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + name + (' — ' + str(detail) if detail and not ok else ''))
    if not ok: fails += 1


def curl(jar, url, data=None, method=None, raw=False):
    cmd = ['curl', '-s', '-m', '120', '-b', jar]
    if method: cmd += ['-X', method]
    if data is not None: cmd += ['-H', 'content-type: application/json', '-d', data]
    out = subprocess.run(cmd + [url], capture_output=True, text=True).stdout
    if raw: return out
    try: return json.loads(out)
    except Exception: return out


def poke(base, jar, body): return curl(jar, base + '/grubbery/api/poke' + POKE + '/calendar.calendar?blot=/json', json.dumps(body), 'POST')
def names(base, jar, cal): return sorted(r['meta'].get('name') for r in curl(jar, base + '/apps/calendar/events.json') if r['cal'] == cal)
def uid_of(base, jar, name): return [r['id'] for r in curl(jar, base + '/apps/calendar/events.json') if r['meta'].get('name') == name][0]
def prod(): curl(FJ, FOL + '/apps/calendar/caldav/sync', '{}', 'POST'); time.sleep(8)
def src_seq(): return [c['seq'] for c in curl(SJ, SRC + '/apps/calendar/calendars.json') if c['id'] == 'default'][0]


# a client password on the source, a follow on the follower
pw = curl(SJ, SRC + '/apps/calendar/dav-clients', json.dumps({'name': 'client matrix'}), 'POST')
check('password minted', bool(pw.get('password')), pw)
SRC_URL = SRC + '/apps/calendar/dav/cal/default/'
for s in curl(FJ, FOL + '/apps/calendar/caldav/subscriptions.json'):
    if s['url'] == SRC_URL: curl(FJ, FOL + '/apps/calendar/caldav/unsubscribe', json.dumps({'id': s['id']}), 'POST')
# the source must have something to follow, or the pull proves nothing
if not names(SRC, SJ, 'default'):
    poke(SRC, SJ, {'action': 'add-event', 'cat': 'timed', 'kind': 'once', 'start_ms': 1791900000000, 'fin': 'dur', 'dur_min': 30, 'meta': {'name': 'cm seed'}}); time.sleep(3)
check('source has events to follow', len(names(SRC, SJ, 'default')) > 0)
r = curl(FJ, FOL + '/apps/calendar/caldav/subscribe', json.dumps({'url': SRC_URL, 'user': 'source', 'password': pw['password'], 'name': 'source default', 'color': '#f9a804'}), 'POST')
cid = r.get('id'); time.sleep(12)
check('followed', bool(cid), r)
check('initial pull matches the source', names(FOL, FJ, cid) == names(SRC, SJ, 'default'), (names(FOL, FJ, cid), names(SRC, SJ, 'default')))
before = len(names(SRC, SJ, 'default'))
# follower -> source
poke(FOL, FJ, {'action': 'add-event', 'cal': cid, 'cat': 'timed', 'kind': 'once', 'start_ms': 1792000000000, 'fin': 'dur', 'dur_min': 30, 'meta': {'name': 'cm from follower', 'tags': ['crossed']}}); time.sleep(10)
check('follower add reaches the source', 'cm from follower' in names(SRC, SJ, 'default'), names(SRC, SJ, 'default'))
u = uid_of(FOL, FJ, 'cm from follower')
poke(FOL, FJ, {'action': 'edit-event', 'id': u, 'cat': 'timed', 'kind': 'once', 'start_ms': 1792000000000, 'fin': 'dur', 'dur_min': 30, 'meta': {'name': 'cm from follower edited', 'tags': ['crossed']}}); time.sleep(10)
check('follower edit reaches the source', 'cm from follower edited' in names(SRC, SJ, 'default'))
seq0 = src_seq(); prod(); check('no echo on the next pass', src_seq() == seq0, (seq0, src_seq()))
ics = curl(SJ, SRC + '/apps/calendar/export.ics', raw=True)
check('tags crossed as CATEGORIES', 'CATEGORIES:crossed' in ics)
# source -> follower, with a moved instance
ics_weekly = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//cm//EN\r\nBEGIN:VEVENT\r\nUID:cm-weekly@test\r\nDTSTAMP:20260901T000000Z\r\nSUMMARY:cm weekly\r\nDTSTART:20261110T090000Z\r\nDTEND:20261110T093000Z\r\nRRULE:FREQ=WEEKLY;COUNT=4\r\nEND:VEVENT\r\nBEGIN:VEVENT\r\nUID:cm-weekly@test\r\nDTSTAMP:20260901T000000Z\r\nRECURRENCE-ID:20261117T090000Z\r\nSUMMARY:cm weekly (moved)\r\nDTSTART:20261118T110000Z\r\nDTEND:20261118T113000Z\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
subprocess.run(['curl', '-s', '-m', '60', '-b', SJ, '-X', 'POST', '--data-binary', ics_weekly, '-o', '/dev/null', SRC + '/apps/calendar/import?cal=default'])
poke(SRC, SJ, {'action': 'add-event', 'cat': 'timed', 'kind': 'once', 'start_ms': 1792003600000, 'fin': 'dur', 'dur_min': 30, 'meta': {'name': 'cm from source'}}); time.sleep(4)
prod()
fn = names(FOL, FJ, cid)
check('source add reaches the follower', 'cm from source' in fn, fn)
check('moved instance crosses as parent + child', 'cm weekly' in fn and 'cm weekly (moved)' in fn, fn)
win = curl(FJ, FOL + '/apps/calendar/window.json?from=1794000000000&to=1796000000000')['rows']
check('follower shows the moved one and skips the original', any(r['meta'].get('name') == 'cm weekly (moved)' for r in win) and not any(r['meta'].get('name') == 'cm weekly' and r['idx'] == 1 for r in win))
# deletes both ways
poke(FOL, FJ, {'action': 'del-event', 'id': u}); time.sleep(10)
check('follower delete reaches the source', 'cm from follower edited' not in names(SRC, SJ, 'default'))
poke(SRC, SJ, {'action': 'del-event', 'id': uid_of(SRC, SJ, 'cm from source')}); poke(SRC, SJ, {'action': 'del-event', 'id': 'cm-weekly@test'}); time.sleep(3); prod()
check('source deletes reach the follower', not [n for n in names(FOL, FJ, cid) if n.startswith('cm ') and n != 'cm seed'], names(FOL, FJ, cid))
check('source back to where it started', len(names(SRC, SJ, 'default')) == before, (before, len(names(SRC, SJ, 'default'))))
# a conflict: the source changes an object, the follower edits the same one before its next pull
poke(SRC, SJ, {'action': 'add-event', 'cat': 'timed', 'kind': 'once', 'start_ms': 1792100000000, 'fin': 'dur', 'dur_min': 30, 'meta': {'name': 'cm clash'}}); time.sleep(3); prod()
cu = uid_of(FOL, FJ, 'cm clash')
poke(SRC, SJ, {'action': 'edit-event', 'id': cu, 'cat': 'timed', 'kind': 'once', 'start_ms': 1792100000000, 'fin': 'dur', 'dur_min': 30, 'meta': {'name': 'cm clash (source)'}}); time.sleep(3)
curl(FJ, FOL + '/apps/calendar/google/conflicts/clear', '{}', 'POST')
poke(FOL, FJ, {'action': 'edit-event', 'id': cu, 'cat': 'timed', 'kind': 'once', 'start_ms': 1792100000000, 'fin': 'dur', 'dur_min': 30, 'meta': {'name': 'cm clash (follower)'}}); time.sleep(10)
cs = curl(FJ, FOL + '/apps/calendar/google/conflicts.json')
check('412 on push is logged as a conflict', any(c['uid'] == cu for c in cs), cs)
prod()
check("the source's version wins on the follower", 'cm clash (source)' in names(FOL, FJ, cid), names(FOL, FJ, cid))
poke(SRC, SJ, {'action': 'del-event', 'id': cu}); time.sleep(2); prod()
curl(FJ, FOL + '/apps/calendar/google/conflicts/clear', '{}', 'POST')
# cleanup
curl(FJ, FOL + '/apps/calendar/caldav/unsubscribe', json.dumps({'id': cid}), 'POST')
curl(SJ, SRC + '/apps/calendar/dav-clients/revoke', json.dumps({'id': pw['id']}), 'POST')
check('cleanup', not [c for c in curl(FJ, FOL + '/apps/calendar/calendars.json') if c['kind'] == 'caldav'])
print('CALDAV CLIENT MATRIX', 'FAILED (%d)' % fails if fails else 'PASSED')
sys.exit(1 if fails else 0)
