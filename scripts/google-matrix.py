#!/usr/bin/env python3
"""The Google gate: both directions against scripts/fake-google.py.

    usage: google-matrix.py SHIP_URL COOKIE_JAR FAKE_URL
    e.g.   google-matrix.py http://127.0.0.1:8081 wex.jar http://127.0.0.1:8092

Configures the nexus to the fake, connects, links the fake's primary
calendar, then: remote add (timed, all-day, weekly with a moved instance,
alarmed) appears on the ship; remote delete and rename; local add / edit /
delete reach the fake exactly once; nothing pulled is pushed back; a forced
410 resyncs; a forced conflict is logged with Google winning. Cleans up.
Exits non-zero on the first failure.
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


# setup
ctl({'op': 'reset'})
ship_post('/google/config', {'client_id': 'fake-client', 'client_secret': 'fake-secret', 'auth_url': FAKE + '/o/oauth2/v2/auth', 'token_url': FAKE + '/token', 'api_base': FAKE})
subprocess.run(['curl', '-s', '-m', '60', '-b', JAR, '-L', '-o', '/dev/null', CAL + '/google/connect'])
g = ship_get('/google.json'); check('connected', g.get('connected') is True, g)
for c in ship_get('/calendars.json'):
    if c['kind'] == 'google': ship_post('/google/unlink', {'id': c['id']})
cals = ship_get('/google/calendars.json'); check('calendars listed', any(c['id'] == 'primary@fake' for c in cals), cals)
# remote seed, then link (the link pulls)
ctl({'op': 'put', 'event': {'id': 'g-timed', 'summary': 'G timed', 'start': {'dateTime': '2026-10-01T10:00:00-04:00', 'timeZone': 'America/New_York'}, 'end': {'dateTime': '2026-10-01T11:00:00-04:00', 'timeZone': 'America/New_York'}, 'reminders': {'useDefault': False, 'overrides': [{'method': 'popup', 'minutes': 10}]}}})
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
# forced 410
ctl({'op': 'gone'}); prod()
check('410 resync keeps everything', gnames() == ['G timed renamed', 'G weekly', 'G weekly (moved)', 'ship alarm'], gnames())
# forced conflict
ship_post('/google/conflicts/clear', {})
ctl({'op': 'fail', 'on': True})
poke({'action': 'edit-event', 'id': 'g-timed@google.com', 'cat': 'timed', 'kind': 'once', 'start_ms': 1790863200000, 'fin': 'dur', 'dur_min': 60, 'meta': {'name': 'edited here'}}); time.sleep(8)
ctl({'op': 'put', 'event': {'id': 'g-timed', 'summary': 'edited on google', 'start': {'dateTime': '2026-10-01T14:00:00Z'}, 'end': {'dateTime': '2026-10-01T15:00:00Z'}}}); ctl({'op': 'fail', 'on': False}); prod()
cs = ship_get('/google/conflicts.json')
check('conflict logged, google kept', len(cs) == 1 and 'edited on google' in gnames() and 'SUMMARY:edited here' in cs[0]['local'], (len(cs), gnames()))
# cleanup
ship_post('/google/conflicts/clear', {}); ship_post('/google/unlink', {'id': gc}); ship_post('/google/disconnect', {}); ctl({'op': 'reset'})
check('cleanup', not [c for c in ship_get('/calendars.json') if c['kind'] == 'google'] and ship_get('/google.json').get('connected') is False)
print('GOOGLE MATRIX', 'FAILED (%d)' % fails if fails else 'PASSED')
sys.exit(1 if fails else 0)
