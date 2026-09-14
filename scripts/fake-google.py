#!/usr/bin/env python3
"""A fake Google Calendar API for the gate. In-memory, single account.

    usage: fake-google.py PORT

Endpoints (a subset of the real ones, same shapes):
  GET  /o/oauth2/v2/auth?...&redirect_uri=R      -> 302 R?code=fake-code&state=
  POST /token                                    -> tokens (code or refresh grant)
  GET  /calendar/v3/users/me/calendarList
  GET  /calendar/v3/calendars/<cid>/events       (syncToken, pageToken, showDeleted)
  POST /calendar/v3/calendars/<cid>/events
  GET/PUT/DELETE /calendar/v3/calendars/<cid>/events/<eid>
  POST /__control  {op: put|delete|gone|reset|state, ...}   the test's hand on the remote
"""
import sys, json, uuid, time, datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs, unquote

PORT = int(sys.argv[1])
TOKEN = 'fake-access-token'
CALS = {'primary@fake': {'id': 'primary@fake', 'summary': 'Fake primary', 'backgroundColor': '#4285f4', 'primary': True},
        'second@fake': {'id': 'second@fake', 'summary': 'Fake second', 'backgroundColor': '#0b8043'}}
EVENTS = {c: {} for c in CALS}        # cid -> eid -> event (deleted ones keep status cancelled)
CHANGES = {c: [] for c in CALS}       # cid -> [eid, ...] in change order (sync tokens index this)
GONE = {c: False for c in CALS}
WRITES = []                           # every write the ship made: (method, cid, eid)
FAIL = {'writes': False}              # __control {op: fail, on: true|false}: writes answer 503


def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.000Z')


def touch(cid, ev):
    ev['updated'] = now_iso(); ev['etag'] = '"%d"' % (len(CHANGES[cid]) + 1)
    EVENTS[cid][ev['id']] = ev; CHANGES[cid].append(ev['id'])


class H(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def send(self, code, obj=None, headers=None):
        data = json.dumps(obj).encode() if obj is not None else b''
        self.send_response(code)
        for k, v in (headers or {}).items(): self.send_header(k, v)
        self.send_header('Content-Type', 'application/json'); self.send_header('Content-Length', str(len(data)))
        self.end_headers(); self.wfile.write(data)

    def body(self):
        n = int(self.headers.get('Content-Length') or 0)
        return self.rfile.read(n) if n else b''

    def authed(self):
        return self.headers.get('Authorization') == 'Bearer ' + TOKEN

    def log_message(self, fmt, *a): sys.stderr.write('%s %s\n' % (self.command, self.path))

    def do_GET(self):
        u = urlparse(self.path); q = parse_qs(u.query); p = unquote(u.path)
        if p == '/o/oauth2/v2/auth':
            r = q['redirect_uri'][0]; self.send(302, None, {'Location': r + '?code=fake-code&state=' + q.get('state', [''])[0]}); return
        if not self.authed(): self.send(401, {'error': {'code': 401, 'message': 'no bearer'}}); return
        if p == '/calendar/v3/users/me/calendarList':
            self.send(200, {'items': list(CALS.values())}); return
        parts = p.split('/')
        if len(parts) >= 6 and parts[3] == 'calendars' and parts[5] == 'events':
            cid = parts[4]
            if cid not in CALS: self.send(404, {'error': {'code': 404}}); return
            if len(parts) == 7:
                ev = EVENTS[cid].get(parts[6]); self.send(200 if ev else 404, ev or {'error': {'code': 404}}); return
            if GONE[cid] and 'syncToken' in q:
                GONE[cid] = False; self.send(410, {'error': {'code': 410, 'message': 'Sync token is no longer valid'}}); return
            start = 0
            if 'syncToken' in q: start = int(q['syncToken'][0].split('-')[1])
            if 'pageToken' in q: start = int(q['pageToken'][0].split('-')[1])
            ids = CHANGES[cid][start:] if ('syncToken' in q or 'pageToken' in q) else None
            if ids is None:
                items = [e for e in EVENTS[cid].values() if e.get('status') != 'cancelled' or q.get('showDeleted', ['false'])[0] == 'true']
                self.send(200, {'items': items, 'nextSyncToken': 'tok-%d' % len(CHANGES[cid])}); return
            seen = []; items = []
            for eid in ids:
                if eid in seen: continue
                seen.append(eid); items.append(EVENTS[cid][eid])
            self.send(200, {'items': items, 'nextSyncToken': 'tok-%d' % len(CHANGES[cid])}); return
        self.send(404, {'error': {'code': 404}})

    def do_POST(self):
        u = urlparse(self.path); p = unquote(u.path); raw = self.body()
        if p == '/token':
            form = parse_qs(raw.decode())
            if form.get('grant_type') == ['authorization_code'] and form.get('code') != ['fake-code']:
                self.send(400, {'error': 'invalid_grant', 'error_description': 'bad code'}); return
            self.send(200, {'access_token': TOKEN, 'refresh_token': 'fake-refresh', 'expires_in': 3600, 'token_type': 'Bearer'}); return
        if p == '/__control':
            c = json.loads(raw or b'{}'); op = c.get('op'); cid = c.get('cal', 'primary@fake')
            if op == 'reset':
                for k in EVENTS: EVENTS[k] = {}; CHANGES[k] = []; GONE[k] = False
                WRITES.clear(); FAIL['writes'] = False; self.send(200, {'ok': True}); return
            if op == 'put':
                ev = c['event']; ev.setdefault('id', uuid.uuid4().hex[:12]); ev.setdefault('status', 'confirmed')
                ev.setdefault('iCalUID', ev['id'] + '@google.com'); touch(cid, ev); self.send(200, ev); return
            if op == 'delete':
                ev = EVENTS[cid][c['id']]; ev['status'] = 'cancelled'; touch(cid, ev); self.send(200, ev); return
            if op == 'gone':
                GONE[cid] = True; self.send(200, {'ok': True}); return
            if op == 'fail':
                FAIL['writes'] = bool(c.get('on', True)); self.send(200, {'ok': True}); return
            if op == 'state':
                self.send(200, {'events': EVENTS, 'writes': WRITES}); return
            self.send(400, {'error': 'bad op'}); return
        if not self.authed(): self.send(401, {'error': {'code': 401}}); return
        parts = p.split('/')
        if len(parts) == 6 and parts[3] == 'calendars' and parts[5] == 'events':
            if FAIL['writes']: self.send(503, {'error': {'code': 503, 'message': 'forced'}}); return
            cid = parts[4]; ev = json.loads(raw); ev['id'] = uuid.uuid4().hex[:12]; ev.setdefault('status', 'confirmed')
            ev.setdefault('iCalUID', ev['id'] + '@google.com'); touch(cid, ev); WRITES.append(('insert', cid, ev['id'])); self.send(200, ev); return
        self.send(404, {'error': {'code': 404}})

    def do_PUT(self):
        p = unquote(urlparse(self.path).path); raw = self.body()
        if not self.authed(): self.send(401, {'error': {'code': 401}}); return
        parts = p.split('/')
        if len(parts) == 7 and parts[5] == 'events':
            if FAIL['writes']: self.send(503, {'error': {'code': 503, 'message': 'forced'}}); return
            cid, eid = parts[4], parts[6]
            if eid not in EVENTS[cid]: self.send(404, {'error': {'code': 404}}); return
            ev = json.loads(raw); ev['id'] = eid; ev.setdefault('status', 'confirmed'); ev.setdefault('iCalUID', EVENTS[cid][eid].get('iCalUID'))
            touch(cid, ev); WRITES.append(('update', cid, eid)); self.send(200, ev); return
        self.send(404, {'error': {'code': 404}})

    def do_DELETE(self):
        p = unquote(urlparse(self.path).path)
        if not self.authed(): self.send(401, {'error': {'code': 401}}); return
        parts = p.split('/')
        if len(parts) == 7 and parts[5] == 'events':
            cid, eid = parts[4], parts[6]
            if eid not in EVENTS[cid]: self.send(404, {'error': {'code': 404}}); return
            ev = EVENTS[cid][eid]; ev['status'] = 'cancelled'; touch(cid, ev); WRITES.append(('delete', cid, eid))
            self.send_response(204); self.send_header('Content-Length', '0'); self.end_headers(); return
        self.send(404, {'error': {'code': 404}})


print('fake-google on %d' % PORT, file=sys.stderr)
ThreadingHTTPServer(('127.0.0.1', PORT), H).serve_forever()
