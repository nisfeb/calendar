#!/usr/bin/env python3
"""The CalDAV gate: the client matrix, driven by the `caldav` library.

    usage: dav-matrix.py DAV_BASE USER PASSWORD [SHIP_URL COOKIE_JAR]

DAV_BASE is the principal URL as a client sees it — through the
method-override proxy (scripts/dav-proxy.py) or the production nginx.
SHIP_URL + COOKIE_JAR (a curl cookie jar) enable the other direction:
an event added on the ship shows up through sync-collection.

Every check runs; exits non-zero if any failed. Cleans up what it made.
"""
import sys, datetime, json, subprocess, time
import caldav
from caldav.elements import dav

BASE, USER, PW = sys.argv[1:4]
SHIP = sys.argv[4] if len(sys.argv) > 4 else None
JAR = sys.argv[5] if len(sys.argv) > 5 else None
POKE = '/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app'
fails = 0


def check(name, ok, detail=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + name + (' — ' + str(detail) if detail and not ok else ''))
    if not ok: fails += 1


def summaries(cal):
    return sorted(str(e.icalendar_component.get('summary')) for e in cal.events())


c = caldav.DAVClient(url=BASE, username=USER, password=PW)
p = c.principal()
check('principal', str(p.url).endswith('/dav/'), p.url)
cals = p.calendars()
check('calendars listed', len(cals) >= 1, cals)
cal = [x for x in cals if str(x.url).endswith('/default/')][0]

# add
ev = cal.save_event(dtstart=datetime.datetime(2026, 10, 5, 14, 0), dtend=datetime.datetime(2026, 10, 5, 15, 0), summary='matrix created', uid='matrix-created@test')
ev.load(); etag1 = ev.get_property(dav.GetEtag())
check('add', str(ev.icalendar_component.get('summary')) == 'matrix created' and etag1, etag1)
check('add listed', 'matrix created' in summaries(cal))
# edit
ev.icalendar_component['summary'] = 'matrix edited'; ev.save(); ev.load()
etag2 = ev.get_property(dav.GetEtag())
check('edit', str(ev.icalendar_component.get('summary')) == 'matrix edited' and etag1 != etag2, (etag1, etag2))
# conflict
r = c.put(str(ev.url), ev.data, {'Content-Type': 'text/calendar', 'If-Match': '"stale"'})
check('If-Match stale -> 412', r.status == 412, r.status)
# alarm
alarm_ics = """BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//matrix//EN\r\nBEGIN:VEVENT\r\nUID:matrix-alarm@test\r\nDTSTAMP:20260901T000000Z\r\nSUMMARY:matrix alarm\r\nDTSTART:20261007T100000Z\r\nDTEND:20261007T103000Z\r\nBEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT10M\r\nDESCRIPTION:matrix alarm\r\nEND:VALARM\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"""
r = c.put(BASE + 'cal/default/matrix-alarm%40test.ics', alarm_ics, {'Content-Type': 'text/calendar'})
al = c.request(BASE + 'cal/default/matrix-alarm%40test.ics', 'GET')
check('alarm round-trips', r.status in (201, 204) and 'TRIGGER:-PT10M' in al.raw, r.status)
# recurring with an exception
weekly = """BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//matrix//EN\r\nBEGIN:VEVENT\r\nUID:matrix-weekly@test\r\nDTSTAMP:20260901T000000Z\r\nSUMMARY:matrix weekly\r\nDTSTART:20261006T090000Z\r\nDTEND:20261006T093000Z\r\nRRULE:FREQ=WEEKLY;COUNT=4\r\nEND:VEVENT\r\nBEGIN:VEVENT\r\nUID:matrix-weekly@test\r\nDTSTAMP:20260901T000000Z\r\nRECURRENCE-ID:20261013T090000Z\r\nSUMMARY:matrix weekly (moved)\r\nDTSTART:20261014T110000Z\r\nDTEND:20261014T113000Z\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"""
r = c.put(BASE + 'cal/default/matrix-weekly%40test.ics', weekly, {'Content-Type': 'text/calendar'})
got = c.request(BASE + 'cal/default/matrix-weekly%40test.ics', 'GET').raw
check('recurring with exception', r.status == 201 and got.count('BEGIN:VEVENT') == 2 and 'RECURRENCE-ID' in got, r.status)
check('children hidden from listing', 'matrix weekly (moved)' not in summaries(cal))
rng = cal.date_search(datetime.datetime(2026, 10, 13), datetime.datetime(2026, 10, 15), expand=False)
check('calendar-query time-range', any(str(e.icalendar_component.get('uid')) == 'matrix-weekly@test' for e in rng))
# sync-collection
coll = cal.objects_by_sync_token(load_objects=False); n0 = len(list(coll)); tok = coll.sync_token
upd, dele = coll.sync()
check('sync-collection settles', len(upd) == 0 and len(dele) == 0, (n0, tok))
# delete
for uid in ('matrix-created@test', 'matrix-alarm@test', 'matrix-weekly@test'):
    r = c.request(BASE + 'cal/default/' + uid.replace('@', '%40') + '.ics', 'DELETE')
    check('delete ' + uid, r.status == 204, r.status)
upd, dele = coll.sync()
check('sync-collection reports the deletes', len(dele) == 3, (len(upd), len(dele)))
check('nothing of ours left', not [s for s in summaries(cal) if s.startswith('matrix')])
# calendars
# a run that crashed may have left it
for x in p.calendars():
    if str(x.url).rstrip('/').endswith('/matrixcal'): x.delete()
new = p.make_calendar(name='matrix cal', cal_id='matrixcal')
check('mkcalendar', 'matrixcal' in [str(x.url).split('/')[-2] for x in p.calendars()])
new.set_properties([dav.DisplayName('matrix cal renamed')])
props = new.get_properties([dav.DisplayName()], depth=0)
check('proppatch displayname', 'matrix cal renamed' in json.dumps({str(k): v for k, v in props.items()}), props)
new.delete()
check('calendar deleted', 'matrixcal' not in [str(x.url).split('/')[-2] for x in p.calendars()])
# the other direction: added on the ship, seen by the client
if SHIP and JAR:
    coll = cal.objects_by_sync_token(load_objects=False); list(coll)
    body = json.dumps({'action': 'add-event', 'cat': 'timed', 'kind': 'once', 'start_ms': 1791000000000, 'fin': 'dur', 'dur_min': 15, 'meta': {'name': 'matrix from ship'}})
    subprocess.run(['curl', '-s', '-m', '60', '-b', JAR, '-X', 'POST', '-H', 'content-type: application/json', '-d', body, '-o', '/dev/null', SHIP + '/grubbery/api/poke' + POKE + '/calendar.calendar?blot=/json'], check=True)
    time.sleep(4)
    upd, dele = coll.sync()
    check('ship -> client via sync-collection', any('matrix from ship' in (u.data or '') for u in upd), len(upd))
    for u in upd:
        if 'matrix from ship' in (u.data or ''): u.delete()

print('MATRIX', 'FAILED (%d)' % fails if fails else 'PASSED')
sys.exit(1 if fails else 0)
