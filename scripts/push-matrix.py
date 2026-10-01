#!/usr/bin/env python3
"""The browser notifications gate: headless Firefox, driven over Marionette,
logs in with the cookie jar, opens Settings, turns notifications on (the
kernel's worker at the calendar's scope, a real push endpoint), pokes an
event with an alarm due in a few minutes, waits for the ship's reminders
fiber to push it, and checks the worker showed it with the event's name
and the alarm's text. Then turns notifications off and deletes the event.

    usage: push-matrix.py SHIP_URL COOKIE_JAR      (e.g. http://localhost:8085 nec.jar)

Needs firefox on the PATH and a route to Mozilla's push service. Takes up
to eight minutes: the fiber ticks on 5-minute marks. Exits 1 on a failure.
"""

import sys, os, json, socket, subprocess, tempfile, time, shutil
BASE, JAR = sys.argv[1].rstrip('/'), sys.argv[2]
host = BASE.split('//')[1].split(':')[0]
PORT = 2829
prof = tempfile.mkdtemp(prefix='ffpush-')
open(prof + '/user.js', 'w').write('\n'.join('user_pref(%s, %s);' % (json.dumps(k), json.dumps(v)) for k, v in {
    'marionette.port': PORT, 'permissions.default.desktop-notification': 1,
    'dom.webnotifications.enabled': True, 'dom.push.enabled': True, 'dom.push.connection.enabled': True,
    'dom.serviceWorkers.enabled': True, 'browser.shell.checkDefaultBrowser': False,
    'datareporting.policy.dataSubmissionEnabled': False, 'toolkit.telemetry.reportingpolicy.firstRun': False,
    'browser.startup.homepage_override.mstone': 'ignore', 'app.update.enabled': False,
    'remote.active-protocols': 2}.items()))
ff = subprocess.Popen(['firefox', '--headless', '--marionette', '--no-remote', '--profile', prof, 'about:blank'],
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
sock = None
for _ in range(60):
    try: sock = socket.create_connection(('127.0.0.1', PORT), timeout=5); break
    except OSError: time.sleep(0.5)
if not sock: print('FAIL: marionette did not come up'); ff.kill(); sys.exit(1)
sock.settimeout(60)
def recv():
    buf = b''
    while b':' not in buf: buf += sock.recv(1)
    n = int(buf.split(b':')[0]); body = buf.split(b':', 1)[1]
    while len(body) < n: body += sock.recv(n - len(body))
    return json.loads(body)
recv()  # hello
mid = [0]
def cmd(name, params):
    mid[0] += 1
    msg = json.dumps([0, mid[0], name, params]).encode()
    sock.sendall(str(len(msg)).encode() + b':' + msg)
    while True:
        r = recv()
        if r[0] == 1 and r[1] == mid[0]:
            if r[2]: raise RuntimeError(name + ': ' + json.dumps(r[2])[:300])
            return r[3]
cmd('WebDriver:NewSession', {'capabilities': {}})
try:
    cmd('WebDriver:Navigate', {'url': BASE + '/~/login'})
    for line in open(JAR):
        f = line.rstrip('\n').split('\t')
        if len(f) == 7 and f[5].startswith('urbauth-'):
            cmd('WebDriver:AddCookie', {'cookie': {'name': f[5], 'value': f[6], 'path': '/'}})
    cmd('WebDriver:Navigate', {'url': BASE + '/apps/calendar'})
    time.sleep(2)
    r = cmd('WebDriver:ExecuteScript', {'script': """
      var b = document.getElementById('push-toggle'), s = document.getElementById('push-status');
      document.getElementById('settings-btn').click();
      return {title: document.title, has: !!b, text: b && b.textContent, disabled: b && b.disabled, status: s && s.textContent,
              secure: window.isSecureContext, push: 'PushManager' in window};""", 'args': []})['value']
    print('page:', json.dumps(r))
    r = cmd('WebDriver:ExecuteAsyncScript', {'script': """
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
      })();""", 'args': []})['value']
    print('after click:', json.dumps(r))

    assert r.get('subId'), 'no subscription'
    import time as _t
    now_ms = int(_t.time() * 1000)
    start = now_ms + 60 * 60 * 1000                      # an hour out
    s = 60 * 60 - 150                                   # fires two and a half minutes from now
    name = 'push e2e %d' % (now_ms // 1000)
    body = json.dumps({'action': 'add-event', 'id': 'push-e2e@test', 'cat': 'timed', 'kind': 'once', 'start_ms': start,
                       'zone': 'none', 'fin': 'dur', 'dur_min': 30, 'meta': {'name': name},
                       'alarms': [{'kind': 'before', 's': s, 'desc': 'e2e alarm'}]})
    POKE = BASE + '/grubbery/api/poke/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app/calendar.calendar?blot=/json'
    subprocess.run(['curl', '-s', '-o', '/dev/null', '-m', '60', '-b', JAR, '-X', 'POST', '-H', 'content-type: application/json', '-d', body, POKE])
    print('poked event with an alarm due in ~150 s; waiting for the 5-minute tick (up to 8 min)')
    got = None
    for i in range(50):
        got = cmd('WebDriver:ExecuteAsyncScript', {'script': """
          var done = arguments[0];
          navigator.serviceWorker.getRegistration('/apps/calendar').then(function(r) { return r.getNotifications(); })
            .then(function(ns) { done(ns.map(function(n) { return {title: n.title, body: n.body, tag: n.tag, icon: n.icon}; })); },
                  function(e) { done({error: String(e)}); });""", 'args': []})['value']
        if got and isinstance(got, list) and len(got): break
        time.sleep(10)
    print('notifications shown by the worker:', json.dumps(got))
    ok = bool(got) and isinstance(got, list) and got[0].get('title') == name and got[0].get('body') == 'e2e alarm'
    print('PUSH MATRIX ' + ('PASSED' if ok else 'FAILED'))
    subprocess.run(['curl', '-s', '-o', '/dev/null', '-m', '60', '-b', JAR, '-X', 'POST', '-H', 'content-type: application/json',
                    '-d', json.dumps({'action': 'del-event', 'id': 'push-e2e@test'}), POKE])
    r2 = cmd('WebDriver:ExecuteAsyncScript', {'script': """
      var done = arguments[0]; var b = document.getElementById('push-toggle');
      var t0 = Date.now(); b.click();
      (function poll() { if ((!b.disabled && Date.now() - t0 > 1500) || Date.now() - t0 > 30000) return done(b.textContent); setTimeout(poll, 500); })();""", 'args': []})['value']
    print('unsubscribed:', r2)
    sys.exit(0 if ok else 1)
finally:
    try: cmd('Marionette:Quit', {})
    except Exception: pass
    ff.wait(timeout=10) if ff.poll() is None else None
    shutil.rmtree(prof, ignore_errors=True)
