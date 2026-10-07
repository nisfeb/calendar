#!/usr/bin/env python3
"""The phone notifications gate: a reminder reaches trunk's push-notice.

Stands up a UnifiedPush endpoint on this machine, registers it with the
ship's %trunk as a device with the "notice" cap (through eyre's channel,
as Talon would), pokes an event with an alarm due in a few minutes, waits
for the ship's reminders fiber to tick, and checks the notice that lands:
trunk's event, the event's tag, name and alarm text. Then checks the
calendar's outcomes.json recorded no trunk fault, and cleans up.

    usage: trunk-matrix.py SHIP_URL COOKIE_JAR [LISTEN_PORT]
           (e.g. http://localhost:8085 ryc.jar 8195)

Needs %trunk at wire 12 or later on the ship, with its notices switch on,
and the kernel's mark for trunk. Takes up to eight minutes: the fiber ticks
on 5-minute marks. Exits 1 on a failure.
"""
import sys, os, json, time, threading, subprocess, uuid, urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

BASE, JAR = sys.argv[1].rstrip('/'), sys.argv[2]
PORT = int(sys.argv[3]) if len(sys.argv) > 3 else 8195
APP = '/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app'
POKE = BASE + '/grubbery/api/poke' + APP + '/calendar.calendar?blot=/json'
DEVICE = 'cal-e2e'
posts = []


class Endpoint(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get('content-length') or 0))
        posts.append({'path': self.path, 'ttl': self.headers.get('ttl'), 'urgency': self.headers.get('urgency'),
                      'body': body.decode(errors='replace')})
        self.send_response(200); self.end_headers()

    def log_message(self, *a):
        pass


def curl(args):
    return subprocess.run(['curl', '-s', '-m', '60', '-b', JAR] + args, capture_output=True, text=True).stdout


def poke(body):
    curl(['-o', '/dev/null', '-X', 'POST', '-H', 'content-type: application/json', '-d', json.dumps(body), POKE])


def trunk(action):
    """A trunk-action poke the way a client sends it: eyre's channel."""
    chan = BASE + '/~/channel/' + uuid.uuid4().hex
    msg = [{'id': 1, 'action': 'poke', 'ship': ship, 'app': 'trunk', 'mark': 'trunk-action', 'json': action}]
    out = subprocess.run(['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}', '-m', '60', '-b', JAR, '-X', 'PUT',
                          '-H', 'content-type: application/json', '-d', json.dumps(msg), chan], capture_output=True, text=True).stdout
    if out not in ('200', '204'):
        print('trunk poke failed:', out); sys.exit(1)
    curl(['-o', '/dev/null', '-X', 'DELETE', chan])


ship = curl([BASE + '/~/name']).strip().lstrip('~')
if not ship:
    print('no ship name from /~/name'); sys.exit(1)
server = HTTPServer(('127.0.0.1', PORT), Endpoint)
threading.Thread(target=server.serve_forever, daemon=True).start()
print('listening on 127.0.0.1:%d; registering device %s with ~%s' % (PORT, DEVICE, ship))
trunk({'push-register': {'id': DEVICE, 'platform': 'unifiedpush',
                         'endpoint': 'http://127.0.0.1:%d/up/%s' % (PORT, DEVICE), 'caps': ['notice']}})
time.sleep(2)

now_ms = int(time.time() * 1000)
name = 'trunk e2e %d' % (now_ms // 1000)
eid = 'trunk-e2e@test'
poke({'action': 'add-event', 'id': eid, 'cat': 'timed', 'kind': 'once', 'start_ms': now_ms + 3600000,
      'zone': 'none', 'fin': 'dur', 'dur_min': 30, 'meta': {'name': name},
      'alarms': [{'kind': 'before', 's': 3600 - 150, 'desc': 'e2e alarm'}]})   # fires two and a half minutes from now
print('poked event with an alarm due in ~150 s; waiting for the 5-minute tick (up to 8 min)')
got = None
for i in range(50):
    hits = [p for p in posts if DEVICE in p['path']]
    if hits:
        got = hits[0]; break
    time.sleep(10)
print('notice at the endpoint:', json.dumps(got))
ok = False
if got:
    try:
        n = json.loads(got['body'])
    except ValueError:
        n = {}
    # the tag is the web push's: cal-<calendar>/<event id>-<occurrence>-<alarm>
    ok = (n.get('event') == 'notice' and str(n.get('tag', '')).startswith('cal-') and eid in str(n.get('tag', ''))
          and n.get('title') == name and n.get('body') == 'e2e alarm' and got['ttl'] == '3600' and got['urgency'] == 'high')
    print('checks:', 'event', n.get('event'), '| tag', n.get('tag'), '| title ok', n.get('title') == name,
          '| body ok', n.get('body') == 'e2e alarm', '| ttl', got['ttl'], '| urgency', got['urgency'])
faults = json.loads(curl([BASE + '/grubbery/ball' + APP + '/outcomes.json?raw=1']) or '{}').get('faults') or {}
bad = [k for k in faults if k in ('road/scry', 'road/gall', 'road/code', 'trunk-marc', 'trunk-notice')]
print('trunk faults recorded:', bad or 'none')
ok = ok and not bad
poke({'action': 'del-event', 'id': eid})
trunk({'push-unregister': DEVICE})
server.shutdown()
print('TRUNK MATRIX ' + ('PASSED' if ok else 'FAILED'))
sys.exit(0 if ok else 1)
