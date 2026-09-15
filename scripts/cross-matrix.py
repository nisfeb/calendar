#!/usr/bin/env python3
"""cross-matrix.py HOST HJAR PEER PJAR PEERNAME
Tasks across the sync paths: a task in a calendar shared with a ship
(both directions, then migrate on the peer), and a task in a followed
CalDAV calendar (both directions)."""
import json, subprocess, sys, time
HOST, HJ, PEER, PJ, PEERNAME = sys.argv[1:6]
P = '/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app'
fails = []
def curl(host, jar, path, body=None, timeout=90):
    cmd = ['curl', '-s', '-m', str(timeout), '-b', jar, host + path]
    if body is not None: cmd += ['-X', 'POST', '-H', 'content-type: application/json', '-d', json.dumps(body)]
    return subprocess.run(cmd, capture_output=True, text=True).stdout
def poke(host, jar, body): return curl(host, jar, f'/grubbery/api/poke{P}/calendar.calendar?blot=/json', body)
def rows(host, jar, cal):
    return {e['meta']['name']: e for e in json.loads(curl(host, jar, '/apps/calendar/events.json') or '[]') if e['cal'] == cal}
def wait(label, fn, secs=75):
    t0 = time.time()
    while time.time() - t0 < secs:
        try:
            if fn(): print(f'  ok   {label} ({time.time()-t0:.0f}s)'); return True
        except Exception: pass
        time.sleep(3)
    print(f'  FAIL {label}'); fails.append(label); return False
def check(label, cond, detail=''):
    print(('  ok   ' if cond else '  FAIL ') + label + ('' if cond else ' — ' + str(detail)[:200]))
    if not cond: fails.append(label)
def sync(host, jar): curl(host, jar, '/apps/calendar/share/sync', {})
def cals(host, jar): return {c['id']: c for c in json.loads(curl(host, jar, '/apps/calendar/calendars.json'))}
DUE = 1795000000000

print('== task in a calendar shared with a ship')
CAL = 'xm'
poke(HOST, HJ, {'action': 'del-calendar', 'id': CAL})
poke(HOST, HJ, {'action': 'add-calendar', 'id': CAL, 'name': 'xm', 'color': '#336699'})
poke(HOST, HJ, {'action': 'add-event', 'cal': CAL, 'cat': 'todo', 'due_ms': DUE, 'meta': {'name': 'host task', 'tags': ['x']}})
curl(HOST, HJ, '/apps/calendar/share/share', {'id': CAL, 'ship': PEERNAME, 'mode': 'edit'})
key = None
def offered():
    global key
    for k, o in json.loads(curl(PEER, PJ, '/apps/calendar/share/shares.json'))['offers'].items():
        if o['cal'] == CAL: key = k; return True
    return False
wait('peer: offer arrived', offered, 30)
sid = json.loads(curl(PEER, PJ, '/apps/calendar/share/accept', {'key': key}))['id']
sync(PEER, PJ)
wait('peer: task pulled as a task with its due and tag', lambda: rows(PEER, PJ, sid)['host task']['cat'] == 'todo' and rows(PEER, PJ, sid)['host task']['due_ms'] == DUE and not rows(PEER, PJ, sid)['host task']['done'] and rows(PEER, PJ, sid)['host task']['meta']['tags'] == ['x'])
poke(PEER, PJ, {'action': 'done-event', 'id': rows(PEER, PJ, sid)['host task']['id'], 'done': True})
wait('host: the tick pushed', lambda: rows(HOST, HJ, CAL)['host task']['done'] is True)
poke(PEER, PJ, {'action': 'add-event', 'cal': sid, 'cat': 'todo', 'meta': {'name': 'peer undated'}})
wait('host: undated task pushed', lambda: rows(HOST, HJ, CAL)['peer undated']['cat'] == 'todo' and not rows(HOST, HJ, CAL)['peer undated']['due_ms'])
poke(HOST, HJ, {'action': 'done-event', 'id': rows(HOST, HJ, CAL)['host task']['id'], 'done': False})
poke(HOST, HJ, {'action': 'add-event', 'cal': CAL, 'cat': 'timed', 'kind': 'once', 'start_ms': DUE, 'fin': 'dur', 'dur_min': 30, 'meta': {'name': 'host event'}})
sync(PEER, PJ)
wait('peer: untick and an event pulled', lambda: rows(PEER, PJ, sid)['host task']['done'] is False and 'host event' in rows(PEER, PJ, sid))
r = json.loads(curl(PEER, PJ, '/apps/calendar/migrate', {'id': sid}))
check('peer: migrate ok', r.get('ok') is True, r)
check('peer: migrated calendar is local with both tasks and the event', cals(PEER, PJ)[sid]['kind'] == 'local' and set(rows(PEER, PJ, sid)) == {'host task', 'peer undated', 'host event'} and rows(PEER, PJ, sid)['peer undated']['cat'] == 'todo')
poke(PEER, PJ, {'action': 'done-event', 'id': rows(PEER, PJ, sid)['host task']['id'], 'done': True})
time.sleep(8)
check('peer: an edit after migrate stays local', rows(PEER, PJ, sid)['host task']['done'] is True and rows(HOST, HJ, CAL)['host task']['done'] is False)
curl(HOST, HJ, '/apps/calendar/share/revoke', {'id': CAL, 'ship': PEERNAME})
poke(PEER, PJ, {'action': 'del-calendar', 'id': sid}); poke(HOST, HJ, {'action': 'del-calendar', 'id': CAL})

print('== task in a followed CalDAV calendar')
FCAL = 'xf'
poke(HOST, HJ, {'action': 'del-calendar', 'id': FCAL})
poke(HOST, HJ, {'action': 'add-calendar', 'id': FCAL, 'name': 'xf', 'color': '#993366'})
poke(HOST, HJ, {'action': 'add-event', 'cal': FCAL, 'cat': 'todo', 'due_ms': DUE, 'meta': {'name': 'src task'}})
poke(HOST, HJ, {'action': 'add-event', 'cal': FCAL, 'cat': 'timed', 'kind': 'once', 'start_ms': DUE, 'fin': 'dur', 'dur_min': 30, 'meta': {'name': 'src event'}})
pw = json.loads(curl(HOST, HJ, '/apps/calendar/dav-clients', {'name': 'cross matrix'}))
url = HOST + f'/apps/calendar/dav/cal/{FCAL}/'
for s in json.loads(curl(PEER, PJ, '/apps/calendar/caldav/subscriptions.json')):
    if s['url'] == url: curl(PEER, PJ, '/apps/calendar/caldav/unsubscribe', {'id': s['id']})
r = json.loads(curl(PEER, PJ, '/apps/calendar/caldav/subscribe', {'url': url, 'user': 'cross', 'password': pw['password'], 'name': 'xf follow', 'color': '#f9a804'}))
fid = r.get('id')
check('followed', bool(fid), r)
def fsync(): curl(PEER, PJ, '/apps/calendar/caldav/sync', {})
fsync()
wait('follower: task and event pulled, task intact', lambda: rows(PEER, PJ, fid)['src task']['cat'] == 'todo' and rows(PEER, PJ, fid)['src task']['due_ms'] == DUE and 'src event' in rows(PEER, PJ, fid))
poke(PEER, PJ, {'action': 'done-event', 'id': rows(PEER, PJ, fid)['src task']['id'], 'done': True})
wait('source: the tick pushed over CalDAV', lambda: rows(HOST, HJ, FCAL)['src task']['done'] is True)
poke(PEER, PJ, {'action': 'add-event', 'cal': fid, 'cat': 'todo', 'meta': {'name': 'follower undated'}})
wait('source: undated task pushed over CalDAV', lambda: rows(HOST, HJ, FCAL).get('follower undated', {}).get('cat') == 'todo')
poke(HOST, HJ, {'action': 'del-event', 'id': rows(HOST, HJ, FCAL)['src task']['id']}); time.sleep(2); fsync()
wait('follower: a task deleted at the source goes', lambda: 'src task' not in rows(PEER, PJ, fid))
conf = json.loads(curl(PEER, PJ, '/apps/calendar/google/conflicts.json'))
check('no conflict logged along the way', not [c for c in conf if c.get('cal') in (fid,)], conf)
curl(PEER, PJ, '/apps/calendar/caldav/unsubscribe', {'id': fid})
poke(HOST, HJ, {'action': 'del-calendar', 'id': FCAL})
curl(HOST, HJ, '/apps/calendar/dav-clients/revoke', {'id': pw.get('id')})
if len(sys.argv) > 6:
    FAKE = sys.argv[6]
    print('== a Google-linked calendar shared onward (fake Google at %s)' % FAKE)
    def ctl(body): return json.loads(subprocess.run(['curl', '-s', '-m', '60', '-X', 'POST', '-H', 'content-type: application/json', '-d', json.dumps(body), FAKE + '/__control'], capture_output=True, text=True).stdout or '{}')
    def writes(): return ctl({'op': 'state'})['writes']
    def gsync(): curl(HOST, HJ, '/apps/calendar/google/sync', {})
    ctl({'op': 'reset'})
    curl(HOST, HJ, '/apps/calendar/google/config', {'client_id': 'fake-client', 'client_secret': 'fake-secret', 'auth_url': FAKE + '/o/oauth2/v2/auth', 'token_url': FAKE + '/token', 'api_base': FAKE})
    subprocess.run(['curl', '-s', '-m', '60', '-b', HJ, '-L', '-o', '/dev/null', HOST + '/apps/calendar/google/connect'])
    for c in json.loads(curl(HOST, HJ, '/apps/calendar/calendars.json')):
        if c['kind'] == 'google': curl(HOST, HJ, '/apps/calendar/google/unlink', {'id': c['id']})
    ctl({'op': 'put', 'event': {'id': 'g-seed', 'summary': 'G seed', 'start': {'dateTime': '2026-11-02T10:00:00Z'}, 'end': {'dateTime': '2026-11-02T11:00:00Z'}}})
    r = json.loads(curl(HOST, HJ, '/apps/calendar/google/link', {'google_id': 'primary@fake', 'name': 'Fake shared', 'color': '#4285f4'})); gc = r.get('id'); time.sleep(10)
    check('host: google calendar linked and seeded', bool(gc) and 'G seed' in rows(HOST, HJ, gc), (gc, list(rows(HOST, HJ, gc))))
    r = json.loads(curl(HOST, HJ, '/apps/calendar/share/share', {'id': gc, 'ship': PEERNAME, 'mode': 'edit'}))
    check('host: a google calendar can be shared', r.get('ok') is True, r)
    key = None
    def offered2():
        global key
        for k, o in json.loads(curl(PEER, PJ, '/apps/calendar/share/shares.json'))['offers'].items():
            if o['cal'] == gc: key = k; return True
        return False
    wait('peer: offer arrived', offered2, 30)
    gsid = json.loads(curl(PEER, PJ, '/apps/calendar/share/accept', {'key': key}))['id']; sync(PEER, PJ)
    wait('peer: google seed pulled through the host', lambda: 'G seed' in rows(PEER, PJ, gsid))
    poke(PEER, PJ, {'action': 'add-event', 'cal': gsid, 'cat': 'timed', 'kind': 'once', 'start_ms': 1793700000000, 'fin': 'dur', 'dur_min': 30, 'meta': {'name': 'from peer'}})
    wait('host: peer add arrived', lambda: 'from peer' in rows(HOST, HJ, gc))
    gsync()
    def gevents(): return json.dumps(ctl({'op': 'state'}).get('events', {}))
    wait('google: peer add pushed up, once', lambda: [w[0] for w in writes()] == ['insert'] and 'from peer' in gevents())
    ctl({'op': 'put', 'event': {'id': 'g-later', 'summary': 'G later', 'start': {'dateTime': '2026-11-03T10:00:00Z'}, 'end': {'dateTime': '2026-11-03T11:00:00Z'}}})
    gsync(); time.sleep(4); sync(PEER, PJ)
    wait('peer: a later google event reaches the peer', lambda: 'G later' in rows(PEER, PJ, gsid))
    pu = rows(PEER, PJ, gsid)['from peer']['id']
    poke(PEER, PJ, {'action': 'edit-event', 'cal': gsid, 'id': pu, 'cat': 'timed', 'kind': 'once', 'start_ms': 1793700000000, 'fin': 'dur', 'dur_min': 45, 'meta': {'name': 'from peer v2'}})
    wait('host: peer edit arrived', lambda: 'from peer v2' in rows(HOST, HJ, gc))
    gsync()
    wait('google: the edit is one update, no echo', lambda: [w[0] for w in writes()] == ['insert', 'update'] and 'from peer v2' in gevents())
    time.sleep(20); sync(PEER, PJ); gsync(); time.sleep(10)
    check('no ping-pong after two more passes', [w[0] for w in writes()] == ['insert', 'update'] and rows(PEER, PJ, gsid)['from peer v2']['cat'] == 'timed', writes())
    curl(HOST, HJ, '/apps/calendar/share/revoke', {'id': gc, 'ship': PEERNAME}); time.sleep(3)
    poke(PEER, PJ, {'action': 'del-calendar', 'id': gsid})
    curl(HOST, HJ, '/apps/calendar/google/unlink', {'id': gc}); ctl({'op': 'reset'})
print('CROSS MATRIX ' + ('PASSED' if not fails else 'FAILED: ' + ', '.join(fails)))
sys.exit(1 if fails else 0)
