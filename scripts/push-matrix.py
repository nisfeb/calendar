#!/usr/bin/env python3
"""The browser notifications gate: headless Firefox, driven over Marionette
(scripts/marionette.py), logs in with the cookie jar, opens Settings, turns
notifications on (the kernel's worker at the calendar's scope, a real push
endpoint), pokes an event with an alarm due in a few minutes, waits for the
ship's reminders fiber to push it, and checks the worker showed it with the
event's name and the alarm's text. Then turns notifications off and deletes
the event.

    usage: push-matrix.py SHIP_URL COOKIE_JAR      (e.g. http://localhost:8085 nec.jar)

Needs firefox on the PATH and a route to Mozilla's push service. Takes up
to eight minutes: the fiber ticks on 5-minute marks. Exits 1 on a failure.
"""
import sys, os, json, time, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from marionette import Firefox

BASE, JAR = sys.argv[1].rstrip('/'), sys.argv[2]
POKE = BASE + '/grubbery/api/poke/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app/calendar.calendar?blot=/json'


def poke(body):
    subprocess.run(['curl', '-s', '-o', '/dev/null', '-m', '60', '-b', JAR, '-X', 'POST', '-H', 'content-type: application/json', '-d', json.dumps(body), POKE])


ok = False
with Firefox() as ff:
    ff.login(BASE, JAR)
    ff.goto(BASE + '/apps/calendar')
    time.sleep(2)
    page = ff.js("""
      var b = document.getElementById('push-toggle'), s = document.getElementById('push-status');
      document.getElementById('settings-btn').click();
      return {title: document.title, has: !!b, text: b && b.textContent, disabled: b && b.disabled, status: s && s.textContent,
              secure: window.isSecureContext, push: 'PushManager' in window};""")
    print('page:', json.dumps(page))
    r = ff.js_async("""
      var done = arguments[0];
      var b = document.getElementById('push-toggle'), s = document.getElementById('push-status');
      var t = document.getElementById('toast-text');
      var t0 = Date.now(); b.click();
      (function poll() {
        var st = {text: b.textContent, disabled: b.disabled, status: s.textContent, toast: t && t.textContent,
                  toastShown: t && !document.getElementById('toast').classList.contains('hidden'), ms: Date.now() - t0};
        var sub = null; try { sub = localStorage.getItem('cal-push-sub'); } catch (e) {}
        st.subId = sub;
        if ((!b.disabled && st.ms > 1500) || st.ms > 45000) return done(st);
        setTimeout(poll, 500);
      })();""")
    print('after click:', json.dumps(r))
    if not r.get('subId'):
        print('PUSH MATRIX FAILED'); sys.exit(1)
    now_ms = int(time.time() * 1000)
    name = 'push e2e %d' % (now_ms // 1000)
    poke({'action': 'add-event', 'id': 'push-e2e@test', 'cat': 'timed', 'kind': 'once', 'start_ms': now_ms + 3600000,
          'zone': 'none', 'fin': 'dur', 'dur_min': 30, 'meta': {'name': name},
          'alarms': [{'kind': 'before', 's': 3600 - 150, 'desc': 'e2e alarm'}]})   # fires two and a half minutes from now
    print('poked event with an alarm due in ~150 s; waiting for the 5-minute tick (up to 8 min)')
    got = None
    for i in range(50):
        got = ff.js_async("""
          var done = arguments[0];
          navigator.serviceWorker.getRegistration('/apps/calendar').then(function(r) { return r.getNotifications(); })
            .then(function(ns) { done(ns.map(function(n) { return {title: n.title, body: n.body, tag: n.tag, icon: n.icon}; })); },
                  function(e) { done({error: String(e)}); });""")
        if got and isinstance(got, list) and len(got): break
        time.sleep(10)
    print('notifications shown by the worker:', json.dumps(got))
    ok = bool(got) and isinstance(got, list) and got[0].get('title') == name and got[0].get('body') == 'e2e alarm'
    poke({'action': 'del-event', 'id': 'push-e2e@test'})
    r2 = ff.js_async("""
      var done = arguments[0]; var b = document.getElementById('push-toggle');
      var t0 = Date.now(); b.click();
      (function poll() { if ((!b.disabled && Date.now() - t0 > 1500) || Date.now() - t0 > 30000) return done(b.textContent); setTimeout(poll, 500); })();""")
    print('unsubscribed:', r2)
print('PUSH MATRIX ' + ('PASSED' if ok else 'FAILED'))
sys.exit(0 if ok else 1)
