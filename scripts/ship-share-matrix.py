#!/usr/bin/env python3
"""ship-share-matrix.py HOST HJAR PEER PJAR PEERNAME
Native @p sharing gate: HOST shares a calendar with PEER (edit), the peer
accepts, both sides edit, the host revokes; then the same read-only. Then
the refusals a host says back: an edit whose UID another host calendar
holds, and an edit after the host made the share read-only without the
peer hearing yet, and an edit over one the host made since the peer's
last pull (while two of the peer's own edits before a pull both go in). The peer keeps its copy as a conflict, goes read-only in
the second case, and the next pull takes the refused object back out.
Then how a peer reads: a big calendar comes whole the first time, and a
change after that by the host's index and the one object that moved.
Last, writes into another calendar while pulls land are all kept.
PEERNAME is the peer's @p as the host names it (e.g. ~feb)."""
import json, subprocess, sys, time
HOST, HJ, PEER, PJ, PEERNAME = sys.argv[1:6]
P = '/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app'
CAL = 'ssm'
fails = []
KEEP = []

def curl(host, jar, path, body=None, timeout=90):
    cmd = ['curl', '-s', '-m', str(timeout), '-b', jar, host + path]
    if body is not None:
        cmd += ['-X', 'POST', '-H', 'content-type: application/json', '-d', json.dumps(body)]
    return subprocess.run(cmd, capture_output=True, text=True).stdout

def poke(host, jar, body):
    return curl(host, jar, f'/grubbery/api/poke{P}/calendar.calendar?blot=/json', body)

def names(host, jar, cal):
    ev = json.loads(curl(host, jar, '/apps/calendar/events.json') or '[]')
    return sorted(e['meta']['name'] for e in ev if e['cal'] == cal)

def uids(host, jar, cal):
    ev = json.loads(curl(host, jar, '/apps/calendar/events.json') or '[]')
    return {e['meta']['name']: e['id'] for e in ev if e['cal'] == cal}

def done(host, jar, cal, name):
    ev = json.loads(curl(host, jar, '/apps/calendar/events.json') or '[]')
    return [e.get('done') for e in ev if e['cal'] == cal and e['meta']['name'] == name]

def wait(label, fn, secs=75):
    # the peer's pass is nudged every 15 s: on a loaded machine a pass
    # woken once can land after the check gives up; slow is not wrong
    t0 = last = time.time()
    while time.time() - t0 < secs:
        if time.time() - last > 15:
            curl(PEER, PJ, '/apps/calendar/share/sync', {}); last = time.time()
        # a check that throws (a name not there yet) is a no, not a crash
        # that skips the cleanup
        try:
            if fn():
                print(f'  ok   {label} ({time.time()-t0:.0f}s)'); return True
        except Exception: pass
        time.sleep(3)
    print(f'  FAIL {label}'); fails.append(label); return False

def check(label, cond):
    print(('  ok   ' if cond else '  FAIL ') + label)
    if not cond: fails.append(label)

def shares(host, jar):
    return json.loads(curl(host, jar, '/apps/calendar/share/shares.json'))

def cals(host, jar):
    return {c['id']: c for c in json.loads(curl(host, jar, '/apps/calendar/calendars.json'))}

def sync(host, jar):
    curl(host, jar, '/apps/calendar/share/sync', {})

def ev(name, start, dur=30, tags=None):
    return {'cat': 'timed', 'kind': 'once', 'start_ms': start, 'fin': 'dur', 'dur_min': dur,
            'meta': {'name': name, 'tags': tags or []}}

def run_round(mode):
    print(f'== {mode} share')
    poke(HOST, HJ, {'action': 'del-calendar', 'id': CAL})
    poke(HOST, HJ, {'action': 'add-calendar', 'id': CAL, 'name': 'ssm', 'color': '#336699'})
    poke(HOST, HJ, {'action': 'add-event', 'cal': CAL, **ev('seed', 1795000000000)})
    r = json.loads(curl(HOST, HJ, '/apps/calendar/share/share', {'id': CAL, 'ship': PEERNAME, 'mode': mode}))
    check('host: share accepted', r.get('ok') is True)
    check('host: peer notified', r.get('notified') is True)
    key = None
    def offered():
        nonlocal key
        for k, o in shares(PEER, PJ)['offers'].items():
            if o['cal'] == CAL: key = k; return True
        return False
    wait('peer: offer arrived', offered, 30)
    if key is None: return
    sid = json.loads(curl(PEER, PJ, '/apps/calendar/share/accept', {'key': key}))['id']
    sync(PEER, PJ)
    wait('peer: pulled seed', lambda: names(PEER, PJ, sid) == ['seed'])
    check('peer: calendar kind ship', cals(PEER, PJ).get(sid, {}).get('kind') == 'ship')
    poke(PEER, PJ, {'action': 'add-event', 'cal': sid, **ev('peer added', 1795100000000, tags=['pushed'])})
    if mode == 'edit':
        wait('host: peer add pushed', lambda: 'peer added' in names(HOST, HJ, CAL))
        u = uids(PEER, PJ, sid).get('peer added')
        poke(PEER, PJ, {'action': 'edit-event', 'cal': sid, 'id': u, **ev('peer edited', 1795100000000, 45)})
        wait('host: peer edit pushed', lambda: names(HOST, HJ, CAL) == ['peer edited', 'seed'])
        poke(PEER, PJ, {'action': 'del-event', 'cal': sid, 'id': u})
        wait('host: peer delete pushed', lambda: names(HOST, HJ, CAL) == ['seed'])
    else:
        time.sleep(8)
        check('peer: read-only edit dropped', names(PEER, PJ, sid) == ['seed'])
        check('host: nothing pushed', names(HOST, HJ, CAL) == ['seed'])
        poke(PEER, PJ, {'action': 'del-event', 'id': uids(PEER, PJ, sid)['seed']})
        time.sleep(3)
        check('peer: read-only delete by id dropped', names(PEER, PJ, sid) == ['seed'])
        # a tick on a task: an edit a writable calendar would take
        poke(HOST, HJ, {'action': 'add-event', 'cal': CAL, 'cat': 'todo', 'meta': {'name': 'ro task'}}); sync(PEER, PJ)
        wait('peer: task pulled', lambda: done(PEER, PJ, sid, 'ro task') == [False])
        poke(PEER, PJ, {'action': 'done-event', 'id': uids(PEER, PJ, sid)['ro task'], 'done': True})
        time.sleep(3)
        check('peer: read-only tick dropped', done(PEER, PJ, sid, 'ro task') == [False])
        poke(HOST, HJ, {'action': 'del-event', 'id': uids(HOST, HJ, CAL)['ro task']}); sync(PEER, PJ)
        wait('peer: task gone again', lambda: names(PEER, PJ, sid) == ['seed'])
        # the host upgrades the share to edit: the row follows, no second offer
        curl(HOST, HJ, '/apps/calendar/share/share', {'id': CAL, 'ship': PEERNAME, 'mode': 'edit'})
        wait('peer: mode upgrade lands on the row', lambda: shares(PEER, PJ)['accepted'].get(sid, {}).get('mode') == 'edit' and not shares(PEER, PJ)['offers'], 30)
        poke(PEER, PJ, {'action': 'add-event', 'cal': sid, **ev('peer after upgrade', 1795150000000)})
        wait('host: push works after the upgrade', lambda: 'peer after upgrade' in names(HOST, HJ, CAL))
        poke(PEER, PJ, {'action': 'del-event', 'id': uids(PEER, PJ, sid)['peer after upgrade']})
        wait('host: and so does a delete', lambda: names(HOST, HJ, CAL) == ['seed'])
        curl(HOST, HJ, '/apps/calendar/share/share', {'id': CAL, 'ship': PEERNAME, 'mode': 'read'})
        wait('peer: downgrade lands too', lambda: shares(PEER, PJ)['accepted'].get(sid, {}).get('mode') == 'read', 30)
    poke(HOST, HJ, {'action': 'add-event', 'cal': CAL, **ev('host added', 1795200000000)})
    sync(PEER, PJ)
    wait('peer: host add pulled', lambda: names(PEER, PJ, sid) == ['host added', 'seed'])
    hu = uids(HOST, HJ, CAL)
    poke(HOST, HJ, {'action': 'edit-event', 'cal': CAL, 'id': hu['host added'], **ev('host edited', 1795200000000)})
    poke(HOST, HJ, {'action': 'del-event', 'cal': CAL, 'id': hu['seed']})
    sync(PEER, PJ)
    wait('peer: host edit and delete pulled', lambda: names(PEER, PJ, sid) == ['host edited'])
    row = shares(PEER, PJ)['accepted'].get(sid, {})
    check('peer: row clean', row.get('error', '') == '')
    r = json.loads(curl(HOST, HJ, '/apps/calendar/share/revoke', {'id': CAL, 'ship': PEERNAME}))
    check('host: revoke ok', r.get('ok') is True)
    check('host: share row gone', CAL not in shares(HOST, HJ)['shares'])
    wait('peer: copy became local', lambda: cals(PEER, PJ).get(sid, {}).get('kind') == 'local')
    check('peer: data kept', names(PEER, PJ, sid) == ['host edited'])
    check('peer: sync row gone', sid not in shares(PEER, PJ)['accepted'])
    if mode == 'edit': poke(PEER, PJ, {'action': 'del-calendar', 'id': sid})
    else: KEEP.append(sid)

def conflicts(host, jar):
    return json.loads(curl(host, jar, '/apps/calendar/google/conflicts.json') or '[]')

def refused(uid, why):
    return lambda: any(c['uid'] == uid and why in c['why'] and 'peer taken' in c['local'] for c in conflicts(PEER, PJ))

def run_refusal():
    print('== refusals the host says back')
    TAKEN = 'ssm-taken@test'
    poke(HOST, HJ, {'action': 'del-calendar', 'id': CAL})
    poke(HOST, HJ, {'action': 'add-calendar', 'id': CAL, 'name': 'ssm', 'color': '#336699'})
    poke(HOST, HJ, {'action': 'add-event', 'cal': CAL, **ev('seed', 1795000000000)})
    one = lambda name: ('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//ssm//EN\r\nBEGIN:VEVENT\r\nUID:%s\r\nSUMMARY:%s\r\n'
                        'DTSTART:20261201T100000Z\r\nDURATION:PT1H\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n') % (TAKEN, name)
    # the host keeps this UID in its default calendar
    subprocess.run(['curl', '-s', '-m', '60', '-b', HJ, '-X', 'POST', '--data-binary', one('host own'), HOST + '/apps/calendar/import?cal=default'], capture_output=True)
    curl(PEER, PJ, '/apps/calendar/google/conflicts/clear', {})
    curl(HOST, HJ, '/apps/calendar/share/share', {'id': CAL, 'ship': PEERNAME, 'mode': 'edit'})
    key = None
    def offered():
        nonlocal key
        for k, o in shares(PEER, PJ)['offers'].items():
            if o['cal'] == CAL: key = k; return True
        return False
    if not wait('peer: offer arrived', offered, 30): return
    sid = json.loads(curl(PEER, PJ, '/apps/calendar/share/accept', {'key': key}))['id']
    sync(PEER, PJ)
    wait('peer: pulled seed', lambda: names(PEER, PJ, sid) == ['seed'])
    try:
        # 1. a UID another calendar of the host holds is not the peer's to write
        subprocess.run(['curl', '-s', '-m', '60', '-b', PJ, '-X', 'POST', '--data-binary', one('peer taken'), PEER + '/apps/calendar/import?cal=' + sid], capture_output=True)
        wait('peer: the refusal is logged with its copy', refused(TAKEN, 'another calendar'))
        check('host: its own copy untouched', [e['meta']['name'] for e in json.loads(curl(HOST, HJ, '/apps/calendar/events.json')) if e['id'] == TAKEN] == ['host own'])
        check('host: the shared calendar did not take it', 'peer taken' not in names(HOST, HJ, CAL))
        check('peer: still edit', shares(PEER, PJ)['accepted'].get(sid, {}).get('mode') == 'edit')
        sync(PEER, PJ)
        wait('peer: the next pull takes the refused object out', lambda: names(PEER, PJ, sid) == ['seed'])
        # 2. the host made the share read-only; the peer has not heard yet
        hs = shares(HOST, HJ)['shares']
        hs[CAL] = {PEERNAME: 'read'}
        subprocess.run(['curl', '-s', '-m', '60', '-b', HJ, '-X', 'POST', '-H', 'content-type: application/json', '-d', json.dumps(hs),
                        HOST + '/grubbery/api/over' + P + '/shares.json?blot=/json'], capture_output=True)
        check('peer: still thinks it may edit', shares(PEER, PJ)['accepted'].get(sid, {}).get('mode') == 'edit')
        poke(PEER, PJ, {'action': 'add-event', 'cal': sid, **ev('peer while read', 1795300000000)})
        wait('peer: the edit is pushed, refused, and logged with its copy',
             lambda: any('read-only' in c['why'] and 'peer while read' in c['local'] for c in conflicts(PEER, PJ)))
        wait('peer: told read-only, it is read-only', lambda: shares(PEER, PJ)['accepted'].get(sid, {}).get('mode') == 'read' and cals(PEER, PJ)[sid]['readonly'] is True, 30)
        check('host: nothing taken', names(HOST, HJ, CAL) == ['seed'])
        sync(PEER, PJ)
        wait('peer: the next pull takes it back out', lambda: names(PEER, PJ, sid) == ['seed'])
    finally:
        curl(HOST, HJ, '/apps/calendar/share/revoke', {'id': CAL, 'ship': PEERNAME})
        poke(HOST, HJ, {'action': 'del-event', 'id': TAKEN, 'home': 'default'})
        poke(HOST, HJ, {'action': 'del-calendar', 'id': CAL})
        time.sleep(3)
        poke(PEER, PJ, {'action': 'del-calendar', 'id': sid})
        curl(PEER, PJ, '/apps/calendar/google/conflicts/clear', {})

def run_stale_edit():
    # a peer's edit names the host version it came from (base): an edit the
    # host made since is not overwritten, and the peer keeps its copy as a
    # conflict; two edits of the peer's own before a pull both go in
    print('== a peer edit over a newer host edit')
    poke(HOST, HJ, {'action': 'del-calendar', 'id': CAL})
    poke(HOST, HJ, {'action': 'add-calendar', 'id': CAL, 'name': 'ssm', 'color': '#336699'})
    poke(HOST, HJ, {'action': 'add-event', 'cal': CAL, **ev('seed', 1795000000000)})
    curl(PEER, PJ, '/apps/calendar/google/conflicts/clear', {})
    curl(HOST, HJ, '/apps/calendar/share/share', {'id': CAL, 'ship': PEERNAME, 'mode': 'edit'})
    key = None
    def offered():
        nonlocal key
        for k, o in shares(PEER, PJ)['offers'].items():
            if o['cal'] == CAL: key = k; return True
        return False
    if not wait('peer: offer arrived', offered, 30): return
    sid = json.loads(curl(PEER, PJ, '/apps/calendar/share/accept', {'key': key}))['id']
    sync(PEER, PJ)
    wait('peer: pulled seed', lambda: names(PEER, PJ, sid) == ['seed'])
    try:
        uid = uids(HOST, HJ, CAL)['seed']
        # the host edits, then the peer edits its older copy before pulling
        poke(HOST, HJ, {'action': 'edit-event', 'id': uid, 'home': CAL, **ev('host moved', 1795003600000)})
        poke(PEER, PJ, {'action': 'edit-event', 'id': uid, 'home': sid, **ev('peer renamed', 1795000000000)})
        wait('peer: the stale edit is refused and logged with its copy',
             lambda: any('changed on the host' in c['why'] and 'peer renamed' in c['local'] for c in conflicts(PEER, PJ)), 120)
        check('host: its edit stands', names(HOST, HJ, CAL) == ['host moved'])
        sync(PEER, PJ)
        wait('peer: the next pull brings the host\'s edit', lambda: names(PEER, PJ, sid) == ['host moved'])
        # two edits of the peer's own before a pull: both go in
        curl(PEER, PJ, '/apps/calendar/google/conflicts/clear', {})
        poke(PEER, PJ, {'action': 'edit-event', 'id': uid, 'home': sid, **ev('peer one', 1795003600000)})
        wait('host: the peer\'s first edit', lambda: names(HOST, HJ, CAL) == ['peer one'])
        poke(PEER, PJ, {'action': 'edit-event', 'id': uid, 'home': sid, **ev('peer two', 1795003600000)})
        wait('host: and its second, before any pull', lambda: names(HOST, HJ, CAL) == ['peer two'])
        check('peer: no refusal for its own edits', not [c for c in conflicts(PEER, PJ) if 'refused' in c['why']])
    finally:
        curl(HOST, HJ, '/apps/calendar/share/revoke', {'id': CAL, 'ship': PEERNAME})
        poke(HOST, HJ, {'action': 'del-calendar', 'id': CAL})
        time.sleep(3)
        poke(PEER, PJ, {'action': 'del-calendar', 'id': sid})
        curl(PEER, PJ, '/apps/calendar/google/conflicts/clear', {})

def run_index():
    print('== a share read by its index')
    poke(HOST, HJ, {'action': 'del-calendar', 'id': CAL})
    poke(HOST, HJ, {'action': 'add-calendar', 'id': CAL, 'name': 'ssm', 'color': '#336699'})
    many = 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//ssm//EN\r\n' + ''.join(
        'BEGIN:VEVENT\r\nUID:ssm-many-%d@test\r\nSUMMARY:many %02d\r\nDTSTART:20261201T%02d0000Z\r\nDURATION:PT30M\r\nEND:VEVENT\r\n' % (i, i, i % 24)
        for i in range(45)) + 'END:VCALENDAR\r\n'
    subprocess.run(['curl', '-s', '-m', '60', '-b', HJ, '-X', 'POST', '--data-binary', many, HOST + '/apps/calendar/import?cal=' + CAL], capture_output=True)
    curl(HOST, HJ, '/apps/calendar/share/share', {'id': CAL, 'ship': PEERNAME, 'mode': 'read'})
    key = None
    def offered():
        nonlocal key
        for k, o in shares(PEER, PJ)['offers'].items():
            if o['cal'] == CAL: key = k; return True
        return False
    if not wait('peer: offer arrived', offered, 30): return
    sid = json.loads(curl(PEER, PJ, '/apps/calendar/share/accept', {'key': key}))['id']
    row = lambda: shares(PEER, PJ)['accepted'].get(sid, {})
    try:
        sync(PEER, PJ)
        wait('peer: 45 events came whole', lambda: len(names(PEER, PJ, sid)) == 45 and row().get('via') == 'whole')
        u = uids(HOST, HJ, CAL)['many 07']
        poke(HOST, HJ, {'action': 'edit-event', 'cal': CAL, 'id': u, **ev('many 07 moved', 1796200000000)})
        sync(PEER, PJ)
        wait('peer: an edit came by the index, one object fetched',
             lambda: 'many 07 moved' in names(PEER, PJ, sid) and row().get('via') == 'index' and row().get('fetched') == 1, 60)
        poke(HOST, HJ, {'action': 'del-event', 'id': uids(HOST, HJ, CAL)['many 08']})
        sync(PEER, PJ)
        wait('peer: a delete came by the index, nothing fetched',
             lambda: 'many 08' not in names(PEER, PJ, sid) and len(names(PEER, PJ, sid)) == 44 and row().get('via') == 'index' and row().get('fetched') == 0, 60)
    finally:
        curl(HOST, HJ, '/apps/calendar/share/revoke', {'id': CAL, 'ship': PEERNAME})
        poke(HOST, HJ, {'action': 'del-calendar', 'id': CAL})
        time.sleep(3)
        poke(PEER, PJ, {'action': 'del-calendar', 'id': sid})

def run_writes_during_pulls():
    print('== writes while pulls land')
    import threading
    poke(HOST, HJ, {'action': 'del-calendar', 'id': CAL})
    poke(HOST, HJ, {'action': 'add-calendar', 'id': CAL, 'name': 'ssm', 'color': '#336699'})
    poke(HOST, HJ, {'action': 'add-event', 'cal': CAL, **ev('churn', 1795000000000)})
    curl(HOST, HJ, '/apps/calendar/share/share', {'id': CAL, 'ship': PEERNAME, 'mode': 'read'})
    key = None
    def offered():
        nonlocal key
        for k, o in shares(PEER, PJ)['offers'].items():
            if o['cal'] == CAL: key = k; return True
        return False
    if not wait('peer: offer arrived', offered, 30): return
    sid = json.loads(curl(PEER, PJ, '/apps/calendar/share/accept', {'key': key}))['id']
    wait('peer: pulled', lambda: names(PEER, PJ, sid) == ['churn'])
    u = uids(HOST, HJ, CAL)['churn']
    stop = []
    def churn():
        # the host changes the event and the peer pulls, over and over, so
        # the peer's pulls keep writing its calendar
        n = 0
        while not stop:
            n += 1
            poke(HOST, HJ, {'action': 'edit-event', 'cal': CAL, 'id': u, **ev('churn', 1795000000000, 30 + n % 50)})
            curl(PEER, PJ, '/apps/calendar/share/sync', {})
    t = threading.Thread(target=churn); t.start()
    try:
        for i in range(30):
            poke(PEER, PJ, {'action': 'add-event', 'cat': 'todo', 'meta': {'name': 'wdp %02d' % i}})
            time.sleep(0.3)
    finally:
        stop.append(1); t.join()
    mine = lambda: sorted(e['meta']['name'] for e in json.loads(curl(PEER, PJ, '/apps/calendar/events.json?cat=todo') or '[]') if e['meta']['name'].startswith('wdp '))
    wait('peer: all 30 writes kept through the pulls', lambda: len(mine()) == 30, 30)
    if len(mine()) != 30: print('       kept', len(mine()), 'of 30')
    for e in json.loads(curl(PEER, PJ, '/apps/calendar/events.json?cat=todo') or '[]'):
        if e['meta']['name'].startswith('wdp '): poke(PEER, PJ, {'action': 'del-event', 'id': e['id'], 'home': e['cal']})
    curl(HOST, HJ, '/apps/calendar/share/revoke', {'id': CAL, 'ship': PEERNAME})
    poke(HOST, HJ, {'action': 'del-calendar', 'id': CAL})
    time.sleep(3)
    poke(PEER, PJ, {'action': 'del-calendar', 'id': sid})

run_round('edit')
run_round('read')
# the copy from the first round stayed (local) under the mug id; a fresh share must still be acceptable
run_round('edit')
# the peer deleted its copy (the edit rounds do); a fresh share must still offer and accept
poke(HOST, HJ, {'action': 'add-event', 'cal': CAL, **ev('seed', 1795000000000)})
curl(HOST, HJ, '/apps/calendar/share/share', {'id': CAL, 'ship': PEERNAME, 'mode': 'read'})
wait('peer: offer arrives again after a local delete', lambda: any(o['cal'] == CAL for o in shares(PEER, PJ)['offers'].values()), 30)
k2 = [k for k, o in shares(PEER, PJ)['offers'].items() if o['cal'] == CAL]
if k2:
    r = json.loads(curl(PEER, PJ, '/apps/calendar/share/accept', {'key': k2[0]}))
    check('peer: accept works again', 'id' in r)
    if 'id' in r: KEEP.append(r['id'])
curl(HOST, HJ, '/apps/calendar/share/revoke', {'id': CAL, 'ship': PEERNAME})
poke(HOST, HJ, {'action': 'del-calendar', 'id': CAL})
for k in KEEP: poke(PEER, PJ, {'action': 'del-calendar', 'id': k})
run_refusal()
run_stale_edit()
run_index()
run_writes_during_pulls()
print('SHIP SHARE MATRIX ' + ('PASSED' if not fails else 'FAILED: ' + ', '.join(fails)))
sys.exit(1 if fails else 0)
