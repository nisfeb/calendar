#!/usr/bin/env python3
"""The Google gate: both directions against scripts/fake-google.py.

    usage: google-matrix.py SHIP_URL COOKIE_JAR FAKE_URL
    e.g.   google-matrix.py http://127.0.0.1:8081 wex.jar http://127.0.0.1:8092

Configures the nexus to the fake, connects, links the fake's primary
calendar, then: remote add (timed, all-day, weekly with a moved instance,
alarmed) appears on the ship; remote delete and rename; local add / edit /
delete reach the fake exactly once; nothing pulled is pushed back; a forced
410 resyncs; a forced conflict is logged with Google winning; a push Google
does not take stands as a fault in outcomes.json and clears. Cleans up.
Every check runs; exits non-zero if any failed. It rewires the ship's
Google client to the fake and unlinks every Google calendar, so it
refuses a ship that has a real client set up.
"""
import sys, json, time, subprocess

SHIP, JAR, FAKE = sys.argv[1:4]
CAL = SHIP + '/apps/calendar'
POKE = '/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app'
fails = 0


def check(name, ok, detail=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + name + (' — ' + str(detail) if detail and not ok else ''))
    if not ok: fails += 1


def curl(args, data=None, method=None, cookie=True):
    cmd = ['curl', '-s', '-m', '120'] + (['-b', JAR] if cookie else [])
    if method: cmd += ['-X', method]
    if data is not None: cmd += ['-H', 'content-type: application/json', '-d', data]
    out = subprocess.run(cmd + args, capture_output=True, text=True).stdout
    try: return json.loads(out)
    except Exception: return out


def ship_get(path): return curl([CAL + path])
def ship_post(path, body): return curl([CAL + path], json.dumps(body), 'POST')
def poke(body): return curl([SHIP + '/grubbery/api/poke' + POKE + '/calendar.calendar?blot=/json'], json.dumps(body), 'POST')
def ctl(body): return curl([FAKE + '/__control'], json.dumps(body), 'POST', cookie=False)
def gnames(): return sorted(r['meta'].get('name') for r in ship_get('/events.json') if r['cal'].startswith('g-'))
def writes(): return ctl({'op': 'state'})['writes']
def prod(): ship_post('/google/sync', {}); time.sleep(8)


# a ship with a real Google client is not the gate's to rewire
g0 = ship_get('/google.json')
if g0.get('client_id') not in ('', None, 'fake-client'):
    print('refusing: this ship has a Google client set up (%s); run the gate on a test ship' % g0.get('client_id'))
    sys.exit(2)

# setup
ctl({'op': 'reset'})
ship_post('/google/config', {'client_id': 'fake-client', 'client_secret': 'fake-secret', 'auth_url': FAKE + '/o/oauth2/v2/auth', 'token_url': FAKE + '/token', 'api_base': FAKE})
# the redirect URI Google is told is the page's origin, recorded when the
# client is saved: a ship behind a TLS proxy sees itself as http
ship_post('/google/config', {'origin': 'https://example.test'})
loc = subprocess.run(['curl', '-s', '-m', '60', '-b', JAR, '-o', '/dev/null', '-w', '%{redirect_url}', CAL + '/google/connect'], capture_output=True, text=True).stdout
check('connect sends the recorded origin as the redirect URI', 'redirect_uri=https%3A%2F%2Fexample.test%2Fapps%2Fcalendar%2Fgoogle%2Fcallback' in loc, loc)
ship_post('/google/config', {'origin': SHIP})
subprocess.run(['curl', '-s', '-m', '60', '-b', JAR, '-L', '-o', '/dev/null', CAL + '/google/connect'])
g = ship_get('/google.json'); check('connected', g.get('connected') is True, g)
for c in ship_get('/calendars.json'):
    if c['kind'] == 'google': ship_post('/google/unlink', {'id': c['id']})
cals = ship_get('/google/calendars.json'); check('calendars listed', any(c['id'] == 'primary@fake' for c in cals), cals)
# remote seed, then link (the link pulls)
ctl({'op': 'put', 'event': {'id': 'g-timed', 'summary': 'G timed', 'start': {'dateTime': '2026-10-01T10:00:00-04:00', 'timeZone': 'America/New_York'}, 'end': {'dateTime': '2026-10-01T11:00:00-04:00', 'timeZone': 'America/New_York'}, 'reminders': {'useDefault': False, 'overrides': [{'method': 'popup', 'minutes': 10}]}, 'hangoutLink': 'https://meet.google.com/abc-defg-hij'}})
ctl({'op': 'put', 'event': {'id': 'g-allday', 'summary': 'G all-day', 'start': {'date': '2026-10-03'}, 'end': {'date': '2026-10-05'}}})
ctl({'op': 'put', 'event': {'id': 'g-weekly', 'iCalUID': 'g-weekly@google.com', 'summary': 'G weekly', 'start': {'dateTime': '2026-10-06T09:00:00Z'}, 'end': {'dateTime': '2026-10-06T09:30:00Z'}, 'recurrence': ['RRULE:FREQ=WEEKLY;COUNT=4']}})
ctl({'op': 'put', 'event': {'id': 'g-weekly_2', 'iCalUID': 'g-weekly@google.com', 'recurringEventId': 'g-weekly', 'originalStartTime': {'dateTime': '2026-10-13T09:00:00Z'}, 'summary': 'G weekly (moved)', 'start': {'dateTime': '2026-10-14T11:00:00Z'}, 'end': {'dateTime': '2026-10-14T11:30:00Z'}}})
r = ship_post('/google/link', {'google_id': 'primary@fake', 'name': 'Fake primary', 'color': '#4285f4'}); gc = r.get('id'); time.sleep(10)
check('link', bool(gc), r)
check('remote events pulled', gnames() == ['G all-day', 'G timed', 'G weekly', 'G weekly (moved)'], gnames())
win = ship_get('/window.json?from=1790640000000&to=1793232000000')['rows']
moved = [r for r in win if r['meta'].get('name') == 'G weekly (moved)']
skipped = [r for r in win if r['meta'].get('name') == 'G weekly' and r['idx'] == 1]
check('moved instance shows, original skipped', len(moved) == 1 and not skipped, (len(moved), len(skipped)))
ex = curl([CAL + '/dav/cal/%s/g-timed%%40google.com.ics' % gc])
check('alarm pulled', 'TRIGGER:-PT10M' in str(ex), str(ex)[:200])
check('meet link pulled', 'CONFERENCE;VALUE=URI:https://meet.google.com/abc-defg-hij' in str(ex)
      and [r['meta'].get('conference') for r in ship_get('/events.json') if r['meta'].get('name') == 'G timed'] == ['https://meet.google.com/abc-defg-hij'], str(ex)[:400])
check('nothing pushed back', writes() == [], writes())
# remote delete + rename
ctl({'op': 'delete', 'id': 'g-allday'}); ctl({'op': 'put', 'event': {'id': 'g-timed', 'summary': 'G timed renamed', 'start': {'dateTime': '2026-10-01T14:00:00Z'}, 'end': {'dateTime': '2026-10-01T15:00:00Z'}}}); prod()
check('remote delete and rename', gnames() == ['G timed renamed', 'G weekly', 'G weekly (moved)'], gnames())
# local add / edit / delete, each once
poke({'action': 'add-event', 'cal': gc, 'cat': 'timed', 'kind': 'weekly', 'start_ms': 1791385200000, 'args': {'days': ['thu']}, 'count': 3, 'fin': 'dur', 'dur_min': 45, 'meta': {'name': 'from ship', 'note': 'pushed'}}); time.sleep(10)
w = writes(); check('local add pushed once', [x[0] for x in w] == ['insert'], w)
uid = [r['id'] for r in ship_get('/events.json') if r['meta'].get('name') == 'from ship'][0]
st = ctl({'op': 'state'})['events']['primary@fake']; mine = [e for e in st.values() if e.get('extendedProperties')]
check('pushed event has the rule', mine and mine[0].get('recurrence') == ['RRULE:FREQ=WEEKLY;BYDAY=TH;COUNT=3'], mine and mine[0].get('recurrence'))
poke({'action': 'edit-event', 'id': uid, 'cat': 'timed', 'kind': 'weekly', 'start_ms': 1791385200000, 'args': {'days': ['thu']}, 'count': 3, 'fin': 'dur', 'dur_min': 45, 'meta': {'name': 'from ship edited'}}); time.sleep(10)
w = writes(); check('local edit pushed once', [x[0] for x in w] == ['insert', 'update'], w)
# alarm the other way: import an alarmed event into the google calendar
ics = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//m//EN\r\nBEGIN:VEVENT\r\nUID:ship-alarm@test\r\nDTSTAMP:20260901T000000Z\r\nSUMMARY:ship alarm\r\nDTSTART:20261020T100000Z\r\nDTEND:20261020T103000Z\r\nBEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT15M\r\nDESCRIPTION:x\r\nEND:VALARM\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
subprocess.run(['curl', '-s', '-m', '60', '-b', JAR, '-X', 'POST', '--data-binary', ics, '-o', '/dev/null', CAL + '/import?cal=' + gc]); time.sleep(10)
st = ctl({'op': 'state'})['events']['primary@fake']; al = [e for e in st.values() if e.get('summary') == 'ship alarm']
check('alarm pushed', al and al[0].get('reminders', {}).get('overrides') == [{'method': 'popup', 'minutes': 15}], al and al[0].get('reminders'))
poke({'action': 'del-event', 'id': uid}); time.sleep(10)
w = writes(); check('local delete pushed', w[-1][0] == 'delete', w)
prod(); check('no echo after a pull', len(writes()) == 4, writes())
# a Meet asked for: the push names conferenceDataVersion=1, Google makes one,
# and its link comes back as the event's join link, the request gone
poke({'action': 'add-event', 'cal': gc, 'cat': 'timed', 'kind': 'once', 'start_ms': 1791385200000, 'fin': 'dur', 'dur_min': 30, 'meta': {'name': 'meet me', 'call': 'meet'}}); time.sleep(10)
st = ctl({'op': 'state'})['events']['primary@fake']; mm = [e for e in st.values() if e.get('summary') == 'meet me']
link = mm and mm[0].get('hangoutLink', '')
row = [r for r in ship_get('/events.json') if r['meta'].get('name') == 'meet me']
check('meet made on the push', bool(link) and link.startswith('https://meet.google.com/fake-'), mm)
check('meet link kept on the ship, request gone', row and row[0]['meta'].get('conference') == link and 'call' not in row[0]['meta'], row and row[0]['meta'])
if row: poke({'action': 'del-event', 'id': row[0]['id']}); time.sleep(8)
# forced 410
ctl({'op': 'gone'}); prod()
check('410 resync keeps everything', gnames() == ['G timed renamed', 'G weekly', 'G weekly (moved)', 'ship alarm'], gnames())
# forced conflict
ship_post('/google/conflicts/clear', {})
ctl({'op': 'fail', 'on': True})
poke({'action': 'edit-event', 'id': 'g-timed@google.com', 'cat': 'timed', 'kind': 'once', 'start_ms': 1790863200000, 'fin': 'dur', 'dur_min': 60, 'meta': {'name': 'edited here'}}); time.sleep(8)
# the push Google would not take stands as a fault: recorded, and not said, since a 503 is nobody's to act on (docs/logging.md)
def push_faults(): return {k: v for k, v in (ship_get('/outcomes.json').get('faults') or {}).items() if k.startswith('google-push/')}
for _ in range(6):
    if push_faults(): break
    time.sleep(3)
gf = push_faults()
check('a push Google does not take is a fault, recorded and not said', len(gf) == 1 and list(gf.values())[0]['said'] is False and list(gf.values())[0]['level'] == 'error', gf)
ctl({'op': 'put', 'event': {'id': 'g-timed', 'summary': 'edited on google', 'start': {'dateTime': '2026-10-01T14:00:00Z'}, 'end': {'dateTime': '2026-10-01T15:00:00Z'}}}); ctl({'op': 'fail', 'on': False}); prod()
check('the fault clears when a push pass goes through', not push_faults(), push_faults())
cs = ship_get('/google/conflicts.json')
check('conflict logged, google kept', len(cs) == 1 and 'edited on google' in gnames() and 'SUMMARY:edited here' in cs[0]['local'], (len(cs), gnames()))
# a Google edit the ship has not pulled yet: the push names the old etag
# (If-Match), Google refuses it, and Google's edit stands
ship_post('/google/conflicts/clear', {})
ctl({'op': 'put', 'event': {'id': 'g-timed', 'summary': 'google side', 'start': {'dateTime': '2026-10-01T14:00:00Z'}, 'end': {'dateTime': '2026-10-01T15:00:00Z'}}})
poke({'action': 'edit-event', 'id': 'g-timed@google.com', 'cat': 'timed', 'kind': 'once', 'start_ms': 1790863200000, 'fin': 'dur', 'dur_min': 60, 'meta': {'name': 'ship side'}}); time.sleep(10)
st = ctl({'op': 'state'})['events']['primary@fake']
cs = ship_get('/google/conflicts.json')
check('a stale push does not overwrite google', st['g-timed']['summary'] == 'google side' and len(cs) == 1 and 'SUMMARY:ship side' in cs[0]['local'], (st['g-timed']['summary'], len(cs)))
prod(); check('and the next pull brings google\'s', 'google side' in gnames(), gnames())
# guests: Google's attendees and organizer come in as meta guests, the
# owner's answer goes back (the whole list, so only the answer changes),
# and guests added here go out with sendUpdates=all so Google mails them
ctl({'op': 'put', 'event': {'id': 'g-guests', 'summary': 'G guests', 'start': {'dateTime': '2026-10-21T14:00:00Z'}, 'end': {'dateTime': '2026-10-21T15:00:00Z'},
     'organizer': {'email': 'boss@x.test', 'displayName': 'Boss'},
     'attendees': [{'email': 'ana@x.test', 'displayName': 'Ana', 'responseStatus': 'accepted'}, {'email': 'me@fake', 'self': True, 'responseStatus': 'needsAction'}]}})
prod()
row = [r for r in ship_get('/events.json') if r['meta'].get('name') == 'G guests']
gm = row and row[0]['meta'] or {}
check('guests pulled', gm.get('organizer', {}).get('email') == 'boss@x.test'
      and {(g['email'], g.get('status'), bool(g.get('self'))) for g in gm.get('guests', [])} == {('ana@x.test', 'accepted', False), ('me@fake', 'needs-action', True)}, gm)
n0 = len(writes())
poke({'action': 'rsvp', 'id': 'g-guests@google.com', 'status': 'accepted'}); time.sleep(10)
st = ctl({'op': 'state'}); ev = st['events']['primary@fake']['g-guests']
check('rsvp pushed with the whole list', len(st['writes']) == n0 + 1
      and {(a['email'], a.get('responseStatus')) for a in ev.get('attendees', [])} == {('ana@x.test', 'accepted'), ('me@fake', 'accepted')}, ev.get('attendees'))
check('the push asks google to mail guests', 'sendUpdates=all' in (st['queries'] or [''])[-1], st['queries'][-1:])
poke({'action': 'add-event', 'cal': gc, 'cat': 'timed', 'kind': 'once', 'start_ms': 1791385200000, 'fin': 'dur', 'dur_min': 30,
      'meta': {'name': 'invite out', 'guests': [{'email': 'bo@x.test', 'status': 'needs-action'}]}}); time.sleep(10)
st = ctl({'op': 'state'}); io = [e for e in st['events']['primary@fake'].values() if e.get('summary') == 'invite out']
check('guests added here go to google', io and io[0].get('attendees') == [{'email': 'bo@x.test', 'responseStatus': 'needsAction'}], io and io[0].get('attendees'))
# only this one: a series with a guest, one occurrence moved here becomes
# an edit of Google's instance (<series>_<start in UTC>), guests and all,
# and the series itself is not sent again
poke({'action': 'add-event', 'cal': gc, 'cat': 'timed', 'kind': 'weekly', 'start_ms': 1792404000000, 'args': {'days': ['mon'], 'at': 600}, 'count': 4, 'zone': 'America/New_York',
      'fin': 'dur', 'dur_min': 60, 'meta': {'name': 'all hands', 'guests': [{'email': 'bo@x.test', 'status': 'needs-action'}]}}); time.sleep(10)
ah = [r for r in ship_get('/events.json') if r['meta'].get('name') == 'all hands']
st = ctl({'op': 'state'}); series = [e for e in st['events']['primary@fake'].values() if e.get('summary') == 'all hands' and not e.get('recurringEventId')]
check('series with a guest pushed', ah and series, (ah, series))
n0 = len(st['writes'])
# the second Monday, 2026-10-26 10:00 New York (14:00Z), moved to Tuesday 11:00
poke({'action': 'edit-at', 'id': ah[0]['id'], 'at_ms': 1793023200000, 'cat': 'timed', 'kind': 'once', 'start_ms': 1792404000000 + 8 * 86400000 + 3600000,
      'zone': 'America/New_York', 'fin': 'dur', 'dur_min': 60, 'meta': {'name': 'all hands (Tuesday)', 'guests': [{'email': 'bo@x.test', 'status': 'needs-action'}]}}); time.sleep(10)
st = ctl({'op': 'state'}); new = st['writes'][n0:]
inst = st['events']['primary@fake'].get(series[0]['id'] + '_20261026T140000Z', {}) if series else {}
check('one instance edit, the series not sent again', [w[0] for w in new] == ['update'] and new and new[0][2] == series[0]['id'] + '_20261026T140000Z', new)
check('the instance moved with its guests', inst.get('summary') == 'all hands (Tuesday)' and inst.get('start', {}).get('dateTime', '').startswith('2026-10-27T11:00:00')
      and inst.get('attendees') == [{'email': 'bo@x.test', 'responseStatus': 'needsAction'}] and inst.get('iCalUID') == series[0].get('iCalUID'), inst)
win = ship_get('/window.json?from=1792368000000&to=1794355200000')['rows']
names = sorted((r['meta'].get('name'), r['l']) for r in win if r['meta'].get('name', '').startswith('all hands'))
check('the ship shows the moved one in place of the second', [n for n, _ in names].count('all hands') == 3 and [n for n, _ in names].count('all hands (Tuesday)') == 1, names)
prod(); check('no echo of the instance after a pull', len(writes()) == n0 + 1, writes()[n0:])
# the same for an all-day series: the instance id is the date alone
D = 86400000
poke({'action': 'add-event', 'cal': gc, 'cat': 'allday', 'kind': 'weekly', 'start_ms': 1792454400000, 'args': {'days': ['tue']}, 'count': 3, 'span_days': 1,
      'meta': {'name': 'offsite'}}); time.sleep(10)
st = ctl({'op': 'state'}); offs = [e for e in st['events']['primary@fake'].values() if e.get('summary') == 'offsite' and not e.get('recurringEventId')]
off = [r for r in ship_get('/events.json') if r['meta'].get('name') == 'offsite']
n0 = len(st['writes'])
# 2026-10-27, the second Tuesday, moved to Wednesday
poke({'action': 'edit-at', 'id': off[0]['id'] if off else '', 'at_ms': 1792454400000 + 7 * D, 'cat': 'allday', 'kind': 'once', 'start_ms': 1792454400000 + 8 * D, 'span_days': 1,
      'meta': {'name': 'offsite (Wednesday)'}}); time.sleep(10)
st = ctl({'op': 'state'}); new = st['writes'][n0:]
oi = st['events']['primary@fake'].get(offs[0]['id'] + '_20261027', {}) if offs else {}
check('an all-day instance moves by its date', [w[0] for w in new] == ['update'] and oi.get('start') == {'date': '2026-10-28'} and oi.get('summary') == 'offsite (Wednesday)', (new, oi))
# a series with no zone: Google names its instance's original start in
# UTC, and the moved one still shows once after a pull
poke({'action': 'add-event', 'cal': gc, 'cat': 'timed', 'kind': 'weekly', 'start_ms': 1792404000000, 'args': {'days': ['mon'], 'at': 600}, 'count': 3,
      'fin': 'dur', 'dur_min': 30, 'meta': {'name': 'utc standup'}}); time.sleep(10)
us = [r for r in ship_get('/events.json') if r['meta'].get('name') == 'utc standup']
# the second Monday, 2026-10-26 10:00 UTC, moved an hour later
poke({'action': 'edit-at', 'id': us[0]['id'] if us else '', 'at_ms': 1792404000000 + 7 * D, 'cat': 'timed', 'kind': 'once', 'start_ms': 1792404000000 + 7 * D + 3600000,
      'fin': 'dur', 'dur_min': 30, 'meta': {'name': 'utc standup (late)'}}); time.sleep(10)
prod()
win = ship_get('/window.json?from=1792368000000&to=1794355200000')['rows']
nm = sorted(r['meta'].get('name') for r in win if r['meta'].get('name', '').startswith('utc standup'))
check('a no-zone series\' moved instance shows once after a pull', nm == ['utc standup', 'utc standup', 'utc standup (late)'], nm)
# a guest taken off a meeting made here is off it on Google too
poke({'action': 'add-event', 'cal': gc, 'id': 'two-guests@gate', 'cat': 'timed', 'kind': 'once', 'start_ms': 1791385200000, 'fin': 'dur', 'dur_min': 30,
      'meta': {'name': 'two guests', 'guests': [{'email': 'a@x.test', 'status': 'needs-action'}, {'email': 'b@x.test', 'status': 'needs-action'}]}}); time.sleep(10)
poke({'action': 'edit-event', 'id': 'two-guests@gate', 'cat': 'timed', 'kind': 'once', 'start_ms': 1791385200000, 'fin': 'dur', 'dur_min': 30,
      'meta': {'name': 'two guests', 'guests': [{'email': 'a@x.test', 'status': 'needs-action'}]}}); time.sleep(10)
st = ctl({'op': 'state'}); tg = [e for e in st['events']['primary@fake'].values() if e.get('summary') == 'two guests']
check('a guest taken off is off on google', tg and [a['email'] for a in tg[0].get('attendees', [])] == ['a@x.test'], tg and tg[0].get('attendees'))
for nm in ('G guests', 'invite out', 'all hands', 'offsite', 'utc standup', 'two guests'):
    for r in ship_get('/events.json'):
        if r['meta'].get('name') == nm: poke({'action': 'del-event', 'id': r['id']})
time.sleep(8)
# cleanup
ship_post('/google/conflicts/clear', {}); ship_post('/google/unlink', {'id': gc}); ship_post('/google/disconnect', {}); ctl({'op': 'reset'})
check('cleanup', not [c for c in ship_get('/calendars.json') if c['kind'] == 'google'] and ship_get('/google.json').get('connected') is False)
print('GOOGLE MATRIX', 'FAILED (%d)' % fails if fails else 'PASSED')
sys.exit(1 if fails else 0)
