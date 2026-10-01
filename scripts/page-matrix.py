#!/usr/bin/env python3
"""The page gate for the Tasks view and the reminders editor, in headless
Firefox over Marionette (scripts/marionette.py). Seeds tasks by poke into a
calendar of its own, opens the Tasks view, and checks: the groups (Overdue,
Today, Tomorrow, This week, Later, Undated) hold the right tasks; done
tasks older than a week hide until Show all; the quick-add parser reads
dates and #tags, and a quick-add lands with the due and tag it read; the
form's reminders editor sets presets that read back from event.json, and
removes them; j and x move along the rows and tick one. Cleans up.

    usage: page-matrix.py SHIP_URL COOKIE_JAR      (e.g. http://localhost:8085 nec.jar)
"""
import sys, os, json, time, subprocess, datetime, zoneinfo
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from marionette import Firefox

SHIP, JAR = sys.argv[1].rstrip('/'), sys.argv[2]
CAL = SHIP + '/apps/calendar'
POKE = SHIP + '/grubbery/api/poke/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app/calendar.calendar?blot=/json'
DAY = 86400000
fails = []


def check(name, ok, detail=''):
    print(('ok   ' if ok else 'FAIL ') + name + ('' if ok else ' — ' + str(detail)[:300]))
    if not ok: fails.append(name)


def curl(path):
    out = subprocess.run(['curl', '-s', '-m', '60', '-b', JAR, CAL + path], capture_output=True, text=True).stdout
    try: return json.loads(out)
    except Exception: return out


def poke(body):
    subprocess.run(['curl', '-s', '-m', '60', '-b', JAR, '-X', 'POST', '-H', 'content-type: application/json', '-d', json.dumps(body), POKE], capture_output=True)


def wait(fn, secs=20):
    t0 = time.time()
    while time.time() - t0 < secs:
        try:
            v = fn()
            if v: return v
        except Exception: pass
        time.sleep(1)
    return None


def tasks(): return [e for e in curl('/events.json?cat=todo') if e.get('cal') == 'page-two']


def task(name):
    for e in tasks():
        if e['meta']['name'] == name: return e
    return None


# today, where the calendar is
zone = (curl('/config.json') or {}).get('zone') or 'UTC'
today_d = datetime.datetime.now(zoneinfo.ZoneInfo(zone)).date()
today = (today_d - datetime.date(1970, 1, 1)).days
now_ms = int(time.time() * 1000)

poke({'action': 'add-calendar', 'id': 'page-two', 'name': 'page gate', 'color': '#336699'})
seed = {'page overdue': today - 1, 'page today': today, 'page tomorrow': today + 1, 'page week': today + 3, 'page later': today + 30, 'page undated': None}
for name, d in seed.items():
    b = {'action': 'add-event', 'cal': 'page-two', 'cat': 'todo', 'meta': {'name': name}, 'id': name.replace(' ', '-') + '@page'}
    if d is not None: b['due_ms'] = d * DAY
    poke(b)
poke({'action': 'add-event', 'cal': 'page-two', 'cat': 'todo', 'meta': {'name': 'page done old'}, 'id': 'page-done-old@page', 'due_ms': (today - 20) * DAY, 'done_ms': now_ms - 10 * DAY})
poke({'action': 'add-event', 'cal': 'page-two', 'cat': 'todo', 'meta': {'name': 'page done new'}, 'id': 'page-done-new@page', 'done_ms': now_ms - 3600000})
check('seeded', wait(lambda: len(tasks()) == 8), len(tasks()))
check('events.json task rows carry done_ms', abs(((task('page done old') or {}).get('done_ms') or 0) - (now_ms - 10 * DAY)) <= 1, task('page done old'))

with Firefox() as ff:
    ff.login(SHIP, JAR)
    ff.goto(CAL + '?view=tasks')
    check('tasks view shows the seeds', ff.wait("return document.querySelector('#task-open') && document.querySelector('#task-open').textContent.indexOf('page today') >= 0 ? 1 : 0"))
    groups = ff.js("""var out = {}; document.querySelectorAll('#task-open details.tg').forEach(function(d) {
        d.querySelectorAll('.task-row .t-name').forEach(function(n) { if (n.textContent.indexOf('page ') === 0) out[n.textContent] = d.dataset.g; }); }); return out;""")
    want = {'page overdue': 'Overdue', 'page today': 'Today', 'page tomorrow': 'Tomorrow', 'page week': 'This week', 'page later': 'Later', 'page undated': 'Undated'}
    check('each task sits in its group', groups == want, groups)
    counts = ff.js("return Array.prototype.map.call(document.querySelectorAll('#task-open details.tg'), function(d) { return [d.dataset.g, +d.querySelector('.tg-n').textContent, d.querySelectorAll('.task-row').length]; })")
    check('group headers count their rows', counts and all(c[1] == c[2] and c[1] > 0 for c in counts), counts)
    done_names = ff.js("return Array.prototype.map.call(document.querySelectorAll('#task-done .t-name'), function(n) { return n.textContent; })")
    note = ff.js("return document.getElementById('task-done-note').textContent")
    check('done this week shown, older hidden', 'page done new' in done_names and 'page done old' not in done_names and 'hidden' in note, (done_names, note))
    ff.js("document.getElementById('task-done-all').click()")
    check('Show all brings the old ones back', ff.wait("return Array.prototype.some.call(document.querySelectorAll('#task-done .t-name'), function(n) { return n.textContent === 'page done old'; }) ? 1 : 0"))
    # the quick-add parser, with a fixed today
    fri = today + ((4 - (today + 3) % 7 + 7) % 7 or 7)
    y = today_d.year
    oct12 = (datetime.date(y, 10, 12) - datetime.date(1970, 1, 1)).days
    if oct12 < today: oct12 = (datetime.date(y + 1, 10, 12) - datetime.date(1970, 1, 1)).days
    cases = [('pay rent fri #home', 'pay rent', fri, ['home']), ('call mom tomorrow', 'call mom', today + 1, []),
             ('taxes in 3 days', 'taxes', today + 3, []), ('dentist oct 12', 'dentist', oct12, []),
             ('just a name', 'just a name', None, []), ('x 2026-12-31', 'x', (datetime.date(2026, 12, 31) - datetime.date(1970, 1, 1)).days, []),
             ('review next week #work #q4', 'review', today + 7, ['work', 'q4']), ('#tag', '#tag', None, [])]
    for text, name, due, tags in cases:
        got = ff.js("return window.parseQuickTask(arguments[0], arguments[1])", text, today)
        check('quick-add reads "%s"' % text, got == {'name': name, 'due': due, 'tags': tags}, got)
    # a quick-add through the box
    ff.js("""var i = document.getElementById('task-name'); i.value = 'page quick tomorrow #gate'; i.dispatchEvent(new Event('input'));
        document.getElementById('task-cal').value = 'page-two';""")
    hint = ff.js("return document.getElementById('task-hint').textContent")
    check('the hint shows what was read', 'Due' in hint and '#gate' in hint, hint)
    ff.js("document.getElementById('task-save').click()")
    q = wait(lambda: task('page quick'))
    check('the quick-add landed with its due and tag', q and q.get('due_ms') == (today + 1) * DAY and q['meta'].get('tags') == ['gate'], q)
    # reminders in the form: open 'page today', add the morning preset and 45 minutes, save
    def open_row(name):
        ff.js("""var want = arguments[0]; var n = Array.prototype.find.call(document.querySelectorAll('#task-open .t-name'), function(x) { return x.textContent === want; });
            if (n) n.parentNode.click();""", name)
        return ff.wait("return document.getElementById('modal-back').classList.contains('open') && document.getElementById('f-name').value === arguments[0] ? 1 : 0", 20, name)
    check('the row opens its form', open_row('page today'))
    ff.js("""var s = document.getElementById('f-alarm-add'); s.value = 'morning'; s.dispatchEvent(new Event('change'));
        s.value = 'custom'; s.dispatchEvent(new Event('change')); document.getElementById('f-alarm-min').value = '45'; document.getElementById('f-alarm-ok').click();""")
    rows = ff.js("return Array.prototype.map.call(document.querySelectorAll('#f-alarms .alarm-row span'), function(x) { return x.textContent; })")
    check('the editor lists what was added', rows == ['9:00 the day of', '45 min before'], rows)
    ff.js("document.getElementById('f-save').click()")
    want_al = [{'kind': 'offset', 'from': 'start', 'after': True, 's': 32400, 'desc': ''}, {'kind': 'before', 's': 2700, 'desc': ''}]
    check('saved reminders read back from event.json', wait(lambda: curl('/event.json?id=page-today%40page&cal=page-two').get('alarms') == want_al), curl('/event.json?id=page-today%40page&cal=page-two').get('alarms'))
    check('the popover text knows them', ff.js("return alarmText({kind:'offset',from:'start',after:true,s:32400,desc:''}, 'todo') + ' / ' + alarmText({kind:'before',s:86400,desc:''}, 'timed')") == '9:00 the day of / 1 day before')
    ff.wait("return !document.getElementById('modal-back').classList.contains('open') ? 1 : 0")
    time.sleep(1.5)
    check('the row opens again with them', open_row('page today') and ff.js("return document.querySelectorAll('#f-alarms .alarm-row').length") == 2)
    ff.js("document.querySelector('#f-alarms .alarm-row .nav-btn').click(); document.querySelector('#f-alarms .alarm-row .nav-btn').click(); document.getElementById('f-save').click()")
    check('removing them all saves []', wait(lambda: curl('/event.json?id=page-today%40page&cal=page-two').get('alarms') == []), curl('/event.json?id=page-today%40page&cal=page-two').get('alarms'))
    ff.wait("return !document.getElementById('modal-back').classList.contains('open') ? 1 : 0")
    # keys: focus the overdue row, j moves to the next, x ticks it
    ff.js("""var n = Array.prototype.find.call(document.querySelectorAll('#task-open .t-name'), function(x) { return x.textContent === 'page overdue'; }); n.parentNode.focus();
        document.dispatchEvent(new KeyboardEvent('keydown', {key: 'j', bubbles: true}));""")
    focused = ff.js("return document.activeElement && document.activeElement.querySelector('.t-name') ? document.activeElement.querySelector('.t-name').textContent : ''")
    check('j moves to the next row', focused == 'page today', focused)
    ff.js("document.dispatchEvent(new KeyboardEvent('keydown', {key: 'x', bubbles: true}))")
    check('x ticks the row in focus', wait(lambda: (task('page today') or {}).get('done') is True), task('page today'))

poke({'action': 'del-calendar', 'id': 'page-two'})
check('cleanup', wait(lambda: 'page-two' not in {c['id'] for c in curl('/calendars.json')}))
print('PAGE MATRIX ' + ('PASSED' if not fails else 'FAILED (%d)' % len(fails)))
sys.exit(1 if fails else 0)
