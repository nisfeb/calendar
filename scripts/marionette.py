"""Headless Firefox over Marionette, for the page gates: a scratch profile
with notifications allowed and push on, the length-prefixed JSON protocol,
and a login from a curl cookie jar. Needs firefox on the PATH.

    with Firefox() as ff:
        ff.login('http://localhost:8085', 'nec.jar')
        ff.goto('http://localhost:8085/apps/calendar')
        ff.js('return document.title')
"""
import json, shutil, socket, subprocess, tempfile, time


def free_port():
    s = socket.socket(); s.bind(('127.0.0.1', 0)); p = s.getsockname()[1]; s.close(); return p


class Firefox:
    def __init__(self):
        self.port = free_port()
        self.prof = tempfile.mkdtemp(prefix='ffgate-')
        prefs = {'marionette.port': self.port, 'permissions.default.desktop-notification': 1,
                 'dom.webnotifications.enabled': True, 'dom.push.enabled': True, 'dom.push.connection.enabled': True,
                 'dom.serviceWorkers.enabled': True, 'browser.shell.checkDefaultBrowser': False,
                 'datareporting.policy.dataSubmissionEnabled': False, 'toolkit.telemetry.reportingpolicy.firstRun': False,
                 'browser.startup.homepage_override.mstone': 'ignore', 'app.update.enabled': False,
                 'dom.disable_beforeunload': True, 'remote.active-protocols': 2}
        open(self.prof + '/user.js', 'w').write('\n'.join('user_pref(%s, %s);' % (json.dumps(k), json.dumps(v)) for k, v in prefs.items()))
        self.ff = subprocess.Popen(['firefox', '--headless', '--marionette', '--no-remote', '--profile', self.prof, 'about:blank'],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.sock = None
        for _ in range(80):
            try: self.sock = socket.create_connection(('127.0.0.1', self.port), timeout=5); break
            except OSError: time.sleep(0.5)
        if not self.sock: self.quit(); raise RuntimeError('marionette did not come up')
        self.sock.settimeout(90)
        self._recv()  # hello
        self.mid = 0
        self.cmd('WebDriver:NewSession', {'capabilities': {}})

    def _recv(self):
        buf = b''
        while b':' not in buf: buf += self.sock.recv(1)
        n = int(buf.split(b':')[0]); body = buf.split(b':', 1)[1]
        while len(body) < n: body += self.sock.recv(n - len(body))
        return json.loads(body)

    def cmd(self, name, params):
        self.mid += 1
        msg = json.dumps([0, self.mid, name, params]).encode()
        self.sock.sendall(str(len(msg)).encode() + b':' + msg)
        while True:
            r = self._recv()
            if r[0] == 1 and r[1] == self.mid:
                if r[2]: raise RuntimeError(name + ': ' + json.dumps(r[2])[:400])
                return r[3]

    def goto(self, url): self.cmd('WebDriver:Navigate', {'url': url})

    def js(self, script, *args): return self.cmd('WebDriver:ExecuteScript', {'script': script, 'args': list(args)})['value']

    def js_async(self, script, *args): return self.cmd('WebDriver:ExecuteAsyncScript', {'script': script, 'args': list(args)})['value']

    def login(self, base, jar):
        """the jar's eyre cookie, set on the ship's origin (no domain: localhost)"""
        self.goto(base.rstrip('/') + '/~/login')
        for line in open(jar):
            f = line.rstrip('\n').split('\t')
            if len(f) == 7 and f[5].startswith('urbauth-'):
                self.cmd('WebDriver:AddCookie', {'cookie': {'name': f[5], 'value': f[6], 'path': '/'}})

    def wait(self, script, secs=20, *args):
        """poll a script until it returns something truthy; that value, or None"""
        t0 = time.time()
        while time.time() - t0 < secs:
            v = self.js(script, *args)
            if v: return v
            time.sleep(0.5)
        return None

    def quit(self):
        try: self.cmd('Marionette:Quit', {})
        except Exception: pass
        try: self.ff.wait(timeout=10)
        except Exception: self.ff.kill()
        shutil.rmtree(self.prof, ignore_errors=True)

    def __enter__(self): return self
    def __exit__(self, *a): self.quit()
