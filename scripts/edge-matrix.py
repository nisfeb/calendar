#!/usr/bin/env python3
"""The edges gate: what the fourth and fifth review rounds fixed, against
one ship.

    usage: edge-matrix.py SHIP_URL COOKIE_JAR DAV_USER DAV_PASSWORD

SHIP_URL is the ship itself (DAV verbs other than GET/PUT/DELETE go as POST
with X-HTTP-Method-Override, so no proxy is needed). Checks: a preset kind
poked in becomes an rrule; the same UID in two calendars is two events and
`home` picks one; a sync token the calendar never gave is refused; a PUT
under a name that is not the UID is kept at that name; a cancelled event
and a cancelled instance are not shown; an UNTIL in UTC ends the series on
the day its zone meant. Fifth round: RRULE slots (a fifth Friday, Friday
the 13th, COUNT counting occurrences), EXDATE and RECURRENCE-ID in UTC
against a zoned series, a quoted TZID, a colon in a quoted param, a time
in a DST gap, alarms after the start or from the end, DAV DELETE with
If-Match, PROPFIND with no Depth, an object of overrides alone, an
unchanged re-PUT, meta a client PUT does not carry, skip undo, "this and
following" as one action, events.json filtered by window and kind, the
config zone, the window cap, a task due in the calendar's zone, a calendar
id that is not a knot. Cleans up.
"""
import sys, json, time, subprocess, base64, urllib.request, urllib.error

SHIP, JAR, USER, PW = sys.argv[1:5]
CAL = SHIP + '/apps/calendar'
DAV = CAL + '/dav/cal/'
POKE = SHIP + '/grubbery/api/poke/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app/calendar.calendar?blot=/json'
AUTH = 'Basic ' + base64.b64encode(('%s:%s' % (USER, PW)).encode()).decode()
fails = []


def check(name, ok, detail=''):
    print(('ok   ' if ok else 'FAIL ') + name + ('' if ok else ' — ' + str(detail)[:300]))
    if not ok: fails.append(name)


def curl(path, body=None, raw=None):
    cmd = ['curl', '-s', '-m', '120', '-b', JAR, CAL + path]
    if body is not None: cmd += ['-X', 'POST', '-H', 'content-type: application/json', '-d', json.dumps(body)]
    if raw is not None: cmd += ['-X', 'POST', '--data-binary', raw]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    try: return json.loads(out)
    except Exception: return out


def poke(body):
    subprocess.run(['curl', '-s', '-m', '60', '-b', JAR, '-X', 'POST', '-H', 'content-type: application/json',
                    '-d', json.dumps(body), POKE], capture_output=True)


def dav(method, path, body=None, headers=None):
    h = {'authorization': AUTH}
    h.update(headers or {})
    verb = method
    if method not in ('GET', 'PUT', 'DELETE'):
        h['x-http-method-override'] = method; verb = 'POST'
    req = urllib.request.Request(DAV + path, data=body.encode() if body else None, method=verb, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=120) as r: return r.status, r.read().decode(), dict(r.headers)
    except urllib.error.HTTPError as e: return e.code, e.read().decode(), dict(e.headers)


def wait(fn, secs=20):
    t0 = time.time()
    while time.time() - t0 < secs:
        try:
            if fn(): return True
        except Exception: pass
        time.sleep(1.5)
    return False


def rows(frm, to):
    return curl('/window.json?from=%d&to=%d' % (frm, to))['rows']


def events(): return curl('/events.json')


def vcal(*blocks): return 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//edge//EN\r\n' + ''.join(blocks) + 'END:VCALENDAR\r\n'


def vevent(uid, summary, lines): return 'BEGIN:VEVENT\r\nUID:%s\r\nSUMMARY:%s\r\n%sEND:VEVENT\r\n' % (uid, summary, ''.join(l + '\r\n' for l in lines))


# ---- a preset kind poked in is an rrule with the same occurrences
poke({'action': 'add-event', 'cat': 'timed', 'kind': 'weekly', 'start_ms': 1792627200000,   # Thu 2026-10-22 00:00Z
      'args': {'days': ['mon', 'fri'], 'at': 540}, 'zone': 'Europe/Berlin', 'fin': 'dur', 'dur_min': 30,
      'meta': {'name': 'edge preset'}})
check('preset poke listed', wait(lambda: any(e['meta']['name'] == 'edge preset' for e in events())))
pid = [e['id'] for e in events() if e['meta']['name'] == 'edge preset'][0]
ev = curl('/event.json?id=' + urllib.request.quote(pid))
check('preset stored as rrule', ev.get('kind') == 'rrule' and ev['args'].get('rrule') == 'FREQ=WEEKLY;BYDAY=MO,FR', ev)
occ = sorted(r['l'] for r in rows(1792627200000, 1793232000000) if r['id'] == pid)
# Fri 2026-10-23 09:00 CEST = 07:00Z; Mon 10-26 09:00 CET = 08:00Z (DST ends 10-25)
check('preset occurrences at 09:00 local across DST', occ[:2] == [1792738800000, 1793001600000], occ)
poke({'action': 'del-event', 'id': pid})

# ---- the same UID in two calendars
poke({'action': 'add-calendar', 'id': 'edge-two', 'name': 'edge two', 'color': '#336699'})
time.sleep(2)
one = vcal(vevent('edge-dup@test', 'edge dup', ['DTSTART:20261101T100000Z', 'DTEND:20261101T110000Z']))
curl('/import?cal=default', raw=one); curl('/import?cal=edge-two', raw=one)
def dups(): return [r for r in rows(1793500000000, 1793600000000) if r['id'] == 'edge-dup@test']
check('same UID in two calendars shows twice', wait(lambda: sorted(r['cal'] for r in dups()) == ['default', 'edge-two']), dups())
poke({'action': 'del-event', 'id': 'edge-dup@test', 'home': 'edge-two'})
check('home deletes only that copy', wait(lambda: [r['cal'] for r in dups()] == ['default']), dups())
poke({'action': 'del-event', 'id': 'edge-dup@test', 'home': 'default'})

# ---- a sync token the calendar never gave
cals = {c['id']: c for c in curl('/calendars.json')}
seq = cals['edge-two']['seq']
check('a new calendar starts its seq high', seq > 10 ** 9, seq)
rep = '<?xml version="1.0"?><D:sync-collection xmlns:D="DAV:"><D:sync-token>/apps/calendar/dav/sync/%d</D:sync-token><D:sync-level>1</D:sync-level><D:prop><D:getetag/></D:prop></D:sync-collection>'
st, body, _ = dav('REPORT', 'edge-two/', rep % 5, {'depth': '1', 'content-type': 'application/xml'})
check('a token from before the calendar is refused', st == 403 and 'valid-sync-token' in body, (st, body[:200]))
st, body, _ = dav('REPORT', 'edge-two/', rep % (seq + 1000), {'depth': '1', 'content-type': 'application/xml'})
check('a token past its seq is refused', st == 403, st)
st, body, _ = dav('REPORT', 'edge-two/', rep % seq, {'depth': '1', 'content-type': 'application/xml'})
check('its own token is fine', st == 207, st)

# ---- a PUT under a name that is not the UID
obj = vcal(vevent('odd uid/with slash@test', 'edge alias', ['DTSTART:20261102T100000Z', 'DTEND:20261102T110000Z']))
st, _, h = dav('PUT', 'edge-two/random-name-123.ics', obj, {'content-type': 'text/calendar'})
check('PUT under another name', st in (201, 204), st)
st, got, _ = dav('GET', 'edge-two/random-name-123.ics')
check('GET at that name gives the object, its own UID', st == 200 and 'UID:odd uid/with slash@test' in got, (st, got[:200]))
st, listing, _ = dav('PROPFIND', 'edge-two/', '<?xml version="1.0"?><D:propfind xmlns:D="DAV:"><D:prop><D:getetag/></D:prop></D:propfind>', {'depth': '1'})
check('listed at that name', 'random-name-123.ics' in listing, listing[:300])
st, _, _ = dav('DELETE', 'edge-two/random-name-123.ics')
check('DELETE at that name', st == 204, st)

# ---- cancelled: an event, and one instance of a series
can = vcal(vevent('edge-cancelled@test', 'edge cancelled', ['DTSTART:20261103T100000Z', 'DTEND:20261103T110000Z', 'STATUS:CANCELLED']))
curl('/import?cal=edge-two', raw=can)
ser = vcal(vevent('edge-series@test', 'edge series', ['DTSTART:20261104T100000Z', 'DURATION:PT1H', 'RRULE:FREQ=DAILY;COUNT=3']),
           vevent('edge-series@test', 'edge series', ['RECURRENCE-ID:20261105T100000Z', 'DTSTART:20261105T100000Z', 'DURATION:PT1H', 'STATUS:CANCELLED']))
curl('/import?cal=edge-two', raw=ser)
def shown(name, frm=1793664000000, to=1794528000000): return sorted(r['l'] for r in rows(frm, to) if r['meta']['name'] == name)
check('a cancelled event is not shown', wait(lambda: shown('edge series') and not shown('edge cancelled')), shown('edge cancelled'))
check('a cancelled instance is only a skip', wait(lambda: len(shown('edge series')) == 2), shown('edge series'))

# ---- an UNTIL in UTC ends the series on the day its zone meant
# Asia/Tokyo daily 09:00 (00:00Z); UNTIL 2026-11-12T00:00:00Z is the 09:00 of the 12th there
tok = vcal(vevent('edge-until@test', 'edge until', ['DTSTART;TZID=Asia/Tokyo:20261110T090000', 'DURATION:PT30M', 'RRULE:FREQ=DAILY;UNTIL=20261112T000000Z']))
curl('/import?cal=edge-two', raw=tok)
check('UTC UNTIL keeps the last day', wait(lambda: len(shown('edge until')) == 3), shown('edge until'))

# ---- fifth round: RRULE slots
def occ(name, frm, to): return sorted(r['l'] for r in rows(frm, to) if r['meta']['name'] == name)
curl('/import?cal=edge-two', raw=vcal(vevent('edge-fri@test', 'edge fri', ['DTSTART:20261106T100000Z', 'DURATION:PT1H', 'RRULE:FREQ=MONTHLY;BYDAY=FR;COUNT=13'])))
# November and December have four Fridays, January five: the 13th is Jan 29
check('a fifth Friday is a slot', wait(lambda: occ('edge fri', 1793491200000, 1803859200000)[-1:] == [1801216800000]), occ('edge fri', 1793491200000, 1803859200000))
curl('/import?cal=edge-two', raw=vcal(vevent('edge-f13@test', 'edge f13', ['DTSTART:20261101T100000Z', 'DURATION:PT1H', 'RRULE:FREQ=MONTHLY;BYDAY=FR;BYMONTHDAY=13;COUNT=2'])))
check('BYDAY limits BYMONTHDAY (Friday the 13th)', wait(lambda: occ('edge f13', 1793491200000, 1861833600000) == [1794564000000, 1818151200000]), occ('edge f13', 1793491200000, 1861833600000))
curl('/import?cal=edge-two', raw=vcal(vevent('edge-31@test', 'edge 31', ['DTSTART:20261031T100000Z', 'DURATION:PT1H', 'RRULE:FREQ=MONTHLY;BYMONTHDAY=31;COUNT=3'])))
check('COUNT counts occurrences, not slots', wait(lambda: occ('edge 31', 1790812800000, 1806537600000) == [1793440800000, 1798711200000, 1801389600000]), occ('edge 31', 1790812800000, 1806537600000))
st, got, _ = dav('GET', 'edge-two/edge-31%40test.ics')
check('and goes out as the same COUNT', 'COUNT=3' in got, got[:400])
ev31 = curl('/event.json?id=edge-31%40test&cal=edge-two')
check('event.json counts occurrences', ev31.get('count') == 3, ev31.get('count') if isinstance(ev31, dict) else ev31)
# a COUNT is walked one occurrence at a time, and anyone who hands us an event
# picks it: the walk stops at 10000 (+max-idx). A million, not 1e11: on a
# ship without the cap this costs seconds, not days.
t0 = time.time()
curl('/import?cal=edge-two', raw=vcal(vevent('edge-huge@test', 'edge huge', ['DTSTART:20261101T100000Z', 'DURATION:PT1H', 'RRULE:FREQ=DAILY;COUNT=1000000'])))
check('a huge COUNT imports quickly', time.time() - t0 < 30, '%.1fs' % (time.time() - t0))
evh = curl('/event.json?id=edge-huge%40test&cal=edge-two&idx=100000000000000')
check('and is capped, as is an idx', isinstance(evh, dict) and evh.get('count') == 10000 and evh.get('before') == 10000, evh)

# ---- fifth round: zones in the object
curl('/import?cal=edge-two', raw=vcal(vevent('edge-ex@test', 'edge ex', ['DTSTART;TZID=America/New_York:20261102T090000', 'DURATION:PT30M', 'RRULE:FREQ=DAILY;COUNT=3', 'EXDATE:20261103T140000Z'])))
check('a UTC EXDATE skips a zoned occurrence', wait(lambda: occ('edge ex', 1793491200000, 1795132800000) == [1793628000000, 1793800800000]), occ('edge ex', 1793491200000, 1795132800000))
curl('/import?cal=edge-two', raw=vcal(vevent('edge-rid@test', 'edge rid', ['DTSTART;TZID=America/New_York:20261109T090000', 'DURATION:PT30M', 'RRULE:FREQ=DAILY;COUNT=3']),
                                      vevent('edge-rid@test', 'edge rid', ['RECURRENCE-ID:20261110T140000Z', 'DTSTART;TZID=America/New_York:20261110T120000', 'DURATION:PT30M'])))
check('a UTC RECURRENCE-ID moves a zoned occurrence', wait(lambda: occ('edge rid', 1793491200000, 1795132800000) == [1794232800000, 1794330000000, 1794405600000]), occ('edge rid', 1793491200000, 1795132800000))
curl('/import?cal=edge-two', raw=vcal(vevent('edge-q@test', 'edge q', ['DTSTART;TZID="America/New_York":20261112T090000', 'DURATION:PT30M', 'ATTENDEE;CN="Doe: J":mailto:j@example.com'])))
check('a quoted TZID is its zone', wait(lambda: occ('edge q', 1793491200000, 1795132800000) == [1794492000000]), occ('edge q', 1793491200000, 1795132800000))
st, got, _ = dav('GET', 'edge-two/edge-q%40test.ics')
check('a colon in a quoted param stays in it', 'ATTENDEE;CN="Doe: J":mailto:j@example.com' in got.replace('\r\n ', ''), got[:500])
curl('/import?cal=edge-two', raw=vcal(vevent('edge-gap@test', 'edge gap', ['DTSTART;TZID=America/New_York:20270314T023000', 'DURATION:PT30M'])))
check('a time in a DST gap moves forward', wait(lambda: occ('edge gap', 1804000000000, 1806000000000) == [1805009400000]), occ('edge gap', 1804000000000, 1806000000000))
al = 'BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:PT15M\r\nDESCRIPTION:after\r\nEND:VALARM\r\nBEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER;RELATED=END:-PT5M\r\nDESCRIPTION:before end\r\nEND:VALARM'
curl('/import?cal=edge-two', raw=vcal(vevent('edge-al@test', 'edge al', ['DTSTART:20261113T100000Z', 'DURATION:PT1H', al])))
time.sleep(2)
st, got, _ = dav('GET', 'edge-two/edge-al%40test.ics')
check('alarms after the start and from the end go out as they came', 'TRIGGER:PT15M' in got and 'TRIGGER;RELATED=END:-PT5M' in got, got[:800])

# ---- fifth round: DAV
st, _, h = dav('PUT', 'edge-two/edge-im.ics', vcal(vevent('edge-im', 'edge im', ['DTSTART:20261114T100000Z', 'DURATION:PT1H'])), {'content-type': 'text/calendar'})
etag = h.get('ETag') or h.get('etag') or ''
st, _, _ = dav('DELETE', 'edge-two/edge-im.ics', None, {'if-match': '"stale"'})
check('DELETE with a stale If-Match is 412', st == 412, st)
st, _, _ = dav('DELETE', 'edge-two/edge-im.ics', None, {'if-match': etag})
check('DELETE with the current one goes', st == 204, (st, etag))
st, listing, _ = dav('PROPFIND', 'edge-two/', '<?xml version="1.0"?><D:propfind xmlns:D="DAV:"><D:prop><D:getetag/></D:prop></D:propfind>')
check('PROPFIND with no Depth lists the members', st == 207 and listing.count('<D:response>') > 1, (st, listing.count('<D:response>')))
oo = vcal(vevent('edge-oo@test', 'edge only override', ['RECURRENCE-ID:20261116T100000Z', 'DTSTART:20261116T110000Z', 'DURATION:PT1H']))
st, _, _ = dav('PUT', 'edge-two/edge-oo%40test.ics', oo, {'content-type': 'text/calendar'})
st2, got, _ = dav('GET', 'edge-two/edge-oo%40test.ics')
check('an object of overrides alone is kept', st in (201, 204) and 'RECURRENCE-ID:20261116T100000Z' in got, (st, got[:300]))
series = vcal(vevent('edge-re@test', 'edge re', ['DTSTART:20261117T100000Z', 'DURATION:PT1H', 'RRULE:FREQ=DAILY;COUNT=3']),
              vevent('edge-re@test', 'edge re', ['RECURRENCE-ID:20261118T100000Z', 'DTSTART:20261118T120000Z', 'DURATION:PT1H']))
dav('PUT', 'edge-two/edge-re%40test.ics', series, {'content-type': 'text/calendar'})
seq0 = {c['id']: c for c in curl('/calendars.json')}['edge-two']['seq']
dav('PUT', 'edge-two/edge-re%40test.ics', series, {'content-type': 'text/calendar'})
seq1 = {c['id']: c for c in curl('/calendars.json')}['edge-two']['seq']
check('the same object again is no change', seq0 == seq1, (seq0, seq1))
poke({'action': 'add-event', 'cal': 'edge-two', 'cat': 'timed', 'kind': 'once', 'start_ms': 1795000000000, 'fin': 'dur', 'dur_min': 30,
      'meta': {'name': 'edge meta', 'color': '#123456', 'x_key': 'kept'}})
wait(lambda: any(e['meta']['name'] == 'edge meta' for e in events()))
mu = [e['id'] for e in events() if e['meta']['name'] == 'edge meta'][0]
st, got, h = dav('GET', 'edge-two/' + urllib.request.quote(mu, safe='') + '.ics')
bare = '\r\n'.join(l for l in got.split('\r\n') if not l.startswith('COLOR')).replace('SUMMARY:edge meta', 'SUMMARY:edge meta 2')
dav('PUT', 'edge-two/' + urllib.request.quote(mu, safe='') + '.ics', bare, {'content-type': 'text/calendar'})
def meta2():
    e = [e for e in events() if e['id'] == mu][0]['meta']
    return e.get('name') == 'edge meta 2' and e.get('color') == '#123456' and e.get('x_key') == 'kept'
check('a client PUT keeps the color and meta it does not carry', wait(meta2), [e['meta'] for e in events() if e['id'] == mu])

# ---- fifth round: skip undo, split
poke({'action': 'add-event', 'cal': 'edge-two', 'cat': 'timed', 'kind': 'rrule', 'args': {'rrule': 'FREQ=DAILY'}, 'start_ms': 1795300000000,
      'fin': 'dur', 'dur_min': 30, 'count': 5, 'meta': {'name': 'edge split'}})
wait(lambda: any(e['meta']['name'] == 'edge split' for e in events()))
su = [e['id'] for e in events() if e['meta']['name'] == 'edge split'][0]
day = 86400000
poke({'action': 'skip-at', 'id': su, 'home': 'edge-two', 'start_ms': 1795300000000 + day})
check('skip-at skips', wait(lambda: curl('/event.json?id=' + urllib.request.quote(su) + '&cal=edge-two')['except'] == [1]))
poke({'action': 'unskip-at', 'id': su, 'home': 'edge-two', 'start_ms': 1795300000000 + day})
check('unskip-at puts it back', wait(lambda: curl('/event.json?id=' + urllib.request.quote(su) + '&cal=edge-two')['except'] == []))
poke({'action': 'skip-at', 'id': su, 'home': 'edge-two', 'start_ms': 1795300000000 + 3 * day})
wait(lambda: curl('/event.json?id=' + urllib.request.quote(su) + '&cal=edge-two')['except'] == [3])
poke({'action': 'split-event', 'id': su, 'home': 'edge-two', 'idx': 2, 'cal': 'edge-two', 'cat': 'timed', 'kind': 'rrule', 'args': {'rrule': 'FREQ=DAILY'},
      'start_ms': 1795300000000 + 2 * day + 3600000, 'fin': 'dur', 'dur_min': 30, 'count': 3, 'meta': {'name': 'edge split b'}})
check('split: the old series ends before it', wait(lambda: occ('edge split', 1795000000000, 1796000000000) == [1795300000000, 1795300000000 + day]), occ('edge split', 1795000000000, 1796000000000))
check('split: the new one starts there and keeps the skip', wait(lambda: occ('edge split b', 1795000000000, 1796000000000) == [1795300000000 + 2 * day + 3600000, 1795300000000 + 4 * day + 3600000]), occ('edge split b', 1795000000000, 1796000000000))

# ---- fifth round: events.json filtered on the ship
poke({'action': 'add-event', 'cal': 'edge-two', 'cat': 'timed', 'kind': 'once', 'start_ms': 1796119200000, 'fin': 'dur', 'dur_min': 30, 'meta': {'name': 'edge in'}})
poke({'action': 'add-event', 'cal': 'edge-two', 'cat': 'timed', 'kind': 'once', 'start_ms': 1803981600000, 'fin': 'dur', 'dur_min': 30, 'meta': {'name': 'edge out'}})
poke({'action': 'add-event', 'cal': 'edge-two', 'cat': 'timed', 'kind': 'rrule', 'args': {'rrule': 'FREQ=WEEKLY'}, 'start_ms': 1790845200000, 'fin': 'dur', 'dur_min': 30, 'meta': {'name': 'edge weekly'}})
poke({'action': 'add-event', 'cal': 'edge-two', 'cat': 'todo', 'due_ms': 1796169600000, 'meta': {'name': 'edge task'}})
poke({'action': 'add-event', 'cal': 'edge-two', 'cat': 'todo', 'meta': {'name': 'edge undated'}})
wait(lambda: {'edge in', 'edge out', 'edge weekly', 'edge task', 'edge undated'} <= {e['meta']['name'] for e in events()})
def ranged(): return {e['meta']['name'] for e in curl('/events.json?from=1796083200000&to=1796688000000') if e['cal'] == 'edge-two'}
check('events.json in a window: what happens in it, a series from before it, a task due in it', wait(lambda: {'edge in', 'edge weekly', 'edge task'} <= ranged() and not {'edge out', 'edge undated'} & ranged()), ranged())
todo = curl('/events.json?cat=todo')
check('events.json?cat=todo is the tasks alone', all(e['cat'] == 'todo' for e in todo) and {'edge task', 'edge undated'} <= {e['meta']['name'] for e in todo}, [e['cat'] for e in todo][:10])
half = subprocess.run(['curl', '-s', '-m', '60', '-o', '/dev/null', '-w', '%{http_code}', '-b', JAR, CAL + '/events.json?from=1796083200000'], capture_output=True, text=True).stdout
check('a window needs both ends', half == '400', half)

# ---- fifth round: config, window, tasks, ids
z0 = curl('/config.json').get('zone')
poke({'action': 'config', 'zone': 'Not/AZone'}); time.sleep(2)
check('an unknown zone is not taken', curl('/config.json').get('zone') == z0, curl('/config.json').get('zone'))
wide = subprocess.run(['curl', '-s', '-m', '60', '-o', '/dev/null', '-w', '%{http_code}', '-b', JAR, CAL + '/window.json?from=0&to=1790000000000'], capture_output=True, text=True).stdout
check('a window wider than 800 days is refused', wide == '400', wide)
poke({'action': 'config', 'zone': 'America/Los_Angeles'})
poke({'action': 'add-event', 'cal': 'edge-two', 'cat': 'todo', 'due_ms': 1792558800000, 'meta': {'name': 'edge due'}})
check('a task due at 22:00 in the zone sits on that day', wait(lambda: [r['l'] for r in rows(1792300000000, 1792700000000) if r['meta']['name'] == 'edge due'] == [1792454400000]),
      [r['l'] for r in rows(1792300000000, 1792700000000) if r['meta']['name'] == 'edge due'])
poke({'action': 'config', 'zone': z0 or 'none'})
poke({'action': 'add-calendar', 'id': 'Bad/ID', 'name': 'bad', 'color': '#336699'}); time.sleep(2)
check('a calendar id that is not a knot is refused', 'Bad/ID' not in {c['id'] for c in curl('/calendars.json')})

# ---- cleanup
poke({'action': 'del-calendar', 'id': 'edge-two'})
check('cleanup', wait(lambda: 'edge-two' not in {c['id'] for c in curl('/calendars.json')}))
print('EDGE MATRIX ' + ('PASSED' if not fails else 'FAILED (%d)' % len(fails)))
sys.exit(1 if fails else 0)
