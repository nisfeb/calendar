#!/usr/bin/env python3
"""todo-matrix.py HOST JAR DAV_BASE USER PASSWORD
Tasks (VTODO): the poke API, the listings, export/import, and CalDAV
(a client's todos() and events() through comp-filter, done via STATUS)."""
import sys, json, subprocess, time, datetime
import caldav
HOST, JAR, BASE, USER, PW = sys.argv[1:6]
P = '/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app'
fails = []
def curl(path, body=None, raw=None, timeout=90):
    cmd = ['curl', '-s', '-m', str(timeout), '-b', JAR, HOST + path]
    if body is not None: cmd += ['-X', 'POST', '-H', 'content-type: application/json', '-d', json.dumps(body)]
    if raw is not None: cmd += ['-X', 'POST', '--data-binary', raw]
    return subprocess.run(cmd, capture_output=True, text=True).stdout
def poke(body): return curl(f'/grubbery/api/poke{P}/calendar.calendar?blot=/json', body)
def check(label, cond, detail=''):
    print(('  ok   ' if cond else '  FAIL ') + label + ('' if cond else ' — ' + str(detail)[:200]))
    if not cond: fails.append(label)
def todos():
    return {e['meta']['name']: e for e in json.loads(curl('/apps/calendar/events.json')) if e['cat'] == 'todo'}
def wait(fn, secs=20):
    t0 = time.time()
    while time.time() - t0 < secs:
        try:
            if fn(): return True
        except Exception: pass
        time.sleep(1.5)
    return False
DUE = 1792454400000  # 2026-10-20
for n in ['gate task', 'imported task', 'dav task']:
    pass
poke({'action': 'add-event', 'cat': 'todo', 'due_ms': DUE, 'meta': {'name': 'gate task', 'tags': ['gate']}})
check('poke: task listed with due', wait(lambda: todos()['gate task']['due_ms'] == DUE and todos()['gate task']['done'] is False))
tid = todos()['gate task']['id']
win = lambda: [r for r in json.loads(curl('/apps/calendar/window.json?from=1792000000000&to=1793000000000'))['rows'] if r['id'] == tid]
check('window: task on its due day, all-day', wait(lambda: len(win()) == 1 and win()[0]['all'] and win()[0]['l'] == DUE and win()[0]['done'] is False), win())
check('events.json?tag filters tasks', wait(lambda: 'gate task' in {e['meta']['name'] for e in json.loads(curl('/apps/calendar/events.json?tag=gate'))}))
poke({'action': 'done-event', 'id': tid, 'done': True})
check('done-event ticks it', wait(lambda: todos()['gate task']['done'] is True and win()[0]['done'] is True))
ics = curl('/apps/calendar/export.ics?cal=default')
vt = ics[ics.find('BEGIN:VTODO'):ics.find('END:VTODO')]
check('export: VTODO with DUE and COMPLETED', 'DUE;VALUE=DATE:20261020' in vt and 'STATUS:COMPLETED' in vt and 'COMPLETED:' in vt and 'CATEGORIES:gate' in vt, vt)
poke({'action': 'done-event', 'id': tid, 'done': False})
check('done-event unticks it', wait(lambda: todos()['gate task']['done'] is False))
body = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//gate//EN\r\nBEGIN:VTODO\r\nUID:imported-task@test\r\nDTSTAMP:20260901T000000Z\r\nSUMMARY:imported task\r\nDUE:20261021T170000Z\r\nSTATUS:NEEDS-ACTION\r\nPRIORITY:5\r\nEND:VTODO\r\nEND:VCALENDAR\r\n"
r = curl('/apps/calendar/import?cal=default', raw=body)
check('import: VTODO accepted', '"imported":1' in r, r)
check('import: listed, due kept', wait(lambda: todos()['imported task']['due_ms'] == 1792602000000), todos().get('imported task'))
ex = curl('/apps/calendar/export.ics?cal=default')
check('export: foreign PRIORITY kept', 'PRIORITY:5' in ex[ex.find('imported-task@test'):ex.find('imported-task@test') + 400])
# a client's shapes: a zoned DUE, a start-only task, a recurring one, an in-process one
body = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//gate//EN\r\n" + \
  "BEGIN:VTODO\r\nUID:zoned-task@test\r\nDTSTAMP:20260901T000000Z\r\nSUMMARY:zoned task\r\nDUE;TZID=America/New_York:20261023T170000\r\nEND:VTODO\r\n" + \
  "BEGIN:VTODO\r\nUID:start-task@test\r\nDTSTAMP:20260901T000000Z\r\nSUMMARY:start task\r\nDTSTART;VALUE=DATE:20261024\r\nEND:VTODO\r\n" + \
  "BEGIN:VTODO\r\nUID:weekly-task@test\r\nDTSTAMP:20260901T000000Z\r\nSUMMARY:weekly task\r\nDTSTART;VALUE=DATE:20261025\r\nDUE;VALUE=DATE:20261026\r\nRRULE:FREQ=WEEKLY\r\nEND:VTODO\r\n" + \
  "BEGIN:VTODO\r\nUID:half-task@test\r\nDTSTAMP:20260901T000000Z\r\nSUMMARY:half task\r\nSTATUS:IN-PROCESS\r\nPERCENT-COMPLETE:60\r\nEND:VTODO\r\n" + \
  "END:VCALENDAR\r\n"
r = curl('/apps/calendar/import?cal=default', raw=body)
check('import: four client-shaped tasks', '"imported":4' in r, r)
check('zoned DUE is absolute (21:00Z)', wait(lambda: todos()['zoned task']['due_ms'] == 1792789200000), todos().get('zoned task'))
check('start-only task has no due', wait(lambda: 'start task' in todos() and not todos()['start task']['due_ms']), todos().get('start task'))
ex = curl('/apps/calendar/export.ics?cal=default')
seg = lambda uid: ex[ex.find('UID:' + uid):].split('END:VTODO')[0]
check('export: start-only keeps DTSTART, gains no DUE', 'DTSTART;VALUE=DATE:20261024' in seg('start-task@test') and 'DUE' not in seg('start-task@test'), seg('start-task@test'))
check('export: RRULE and DTSTART ride verbatim', 'RRULE:FREQ=WEEKLY' in seg('weekly-task@test') and 'DTSTART;VALUE=DATE:20261025' in seg('weekly-task@test') and 'DUE;VALUE=DATE:20261026' in seg('weekly-task@test'), seg('weekly-task@test'))
check('export: IN-PROCESS and percent kept, no NEEDS-ACTION', 'STATUS:IN-PROCESS' in seg('half-task@test') and 'PERCENT-COMPLETE:60' in seg('half-task@test') and 'NEEDS-ACTION' not in seg('half-task@test'), seg('half-task@test'))
poke({'action': 'done-event', 'id': todos()['half task']['id'], 'done': True})
check('ticking replaces the old status', wait(lambda: 'STATUS:COMPLETED' in (lambda e: e[e.find('half-task@test'):e.find('half-task@test') + 500])(curl('/apps/calendar/export.ics?cal=default')) and 'IN-PROCESS' not in (lambda e: e[e.find('half-task@test'):e.find('half-task@test') + 500])(curl('/apps/calendar/export.ics?cal=default'))))
poke({'action': 'add-event', 'cat': 'todo', 'meta': {'name': 'undated task'}})
check('undated task listed', wait(lambda: 'undated task' in todos()))
# CalDAV
c = caldav.DAVClient(url=BASE, username=USER, password=PW)
cal = [x for x in c.principal().calendars() if str(x.url).endswith('/default/')][0]
comps = cal.get_supported_components()
check('dav: component set has VTODO and VEVENT', 'VTODO' in comps and 'VEVENT' in comps, comps)
t = cal.save_todo(summary='dav task', due=datetime.date(2026, 10, 22), uid='dav-task@test')
check('dav: save_todo listed on the ship', wait(lambda: todos()['dav task']['due_ms'] == 1792627200000), todos().get('dav task'))
names = sorted(str(x.icalendar_component.get('summary')) for x in cal.todos())
ranged = [str(x.icalendar_component.get('summary')) for x in cal.search(todo=True, start=datetime.datetime(2026, 10, 1), end=datetime.datetime(2026, 10, 31), expand=False)]
check('dav: time-range query still returns the undated task', 'undated task' in ranged and 'gate task' in ranged, ranged)
check('dav: todos() are the tasks', set(['gate task', 'imported task', 'dav task']) <= set(names), names)
ev_names = [str(x.icalendar_component.get('summary')) for x in cal.events()]
check('dav: events() has no task', not any(n in ev_names for n in ['gate task', 'imported task', 'dav task']), ev_names)
t.load(); t.icalendar_component['status'] = 'COMPLETED'; t.save()
check('dav: STATUS:COMPLETED marks done', wait(lambda: todos()['dav task']['done'] is True))
done_names = [str(x.icalendar_component.get('summary')) for x in cal.todos(include_completed=False)]
check('dav: completed task drops out of the open list', 'dav task' not in done_names and 'gate task' in done_names, done_names)
MINE = ('gate task', 'imported task', 'dav task', 'zoned task', 'start task', 'weekly task', 'half task', 'undated task')
for n, e in todos().items():
    if n in MINE: poke({'action': 'del-event', 'id': e['id']})
check('cleanup', wait(lambda: not any(n in todos() for n in MINE)))
print('TODO MATRIX ' + ('PASSED' if not fails else 'FAILED: ' + ', '.join(fails)))
sys.exit(1 if fails else 0)
