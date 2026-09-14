#!/usr/bin/env python3
"""A method-override proxy for testing CalDAV against a ship.

The runtime answers 400 to any verb it does not know (PROPFIND, REPORT,
PROPPATCH, MKCALENDAR), so this proxy forwards those as POST with
X-HTTP-Method-Override, the way the production nginx does. It also answers
/.well-known/caldav with a redirect to the principal, for DAVx5 and iOS.

    usage: dav-proxy.py LISTEN_PORT SHIP_URL      e.g. 8091 http://127.0.0.1:8081
"""
import sys, urllib.request, urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(sys.argv[1]); SHIP = sys.argv[2].rstrip('/')
NATIVE = {'GET', 'PUT', 'POST', 'HEAD', 'DELETE', 'OPTIONS'}
HOP = {'host', 'connection', 'keep-alive', 'transfer-encoding', 'content-length', 'te', 'trailer', 'upgrade', 'proxy-connection'}


class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def proxy(self):
        if self.path.startswith('/.well-known/caldav'):
            self.send_response(301); self.send_header('Location', '/apps/calendar/dav/'); self.send_header('Content-Length', '0'); self.end_headers(); return
        n = int(self.headers.get('Content-Length') or 0)
        body = self.rfile.read(n) if n else None
        verb = self.command
        headers = {k: v for k, v in self.headers.items() if k.lower() not in HOP}
        method = verb
        if verb not in NATIVE:
            method = 'POST'; headers['X-HTTP-Method-Override'] = verb
        req = urllib.request.Request(SHIP + self.path, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                status, rh, data = r.status, r.headers, r.read()
        except urllib.error.HTTPError as e:
            status, rh, data = e.code, e.headers, e.read()
        except Exception as e:
            self.send_response(502); msg = str(e).encode(); self.send_header('Content-Length', str(len(msg))); self.end_headers(); self.wfile.write(msg); return
        self.send_response(status)
        for k, v in rh.items():
            if k.lower() not in HOP: self.send_header(k, v)
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        if verb != 'HEAD': self.wfile.write(data)

    def log_message(self, fmt, *args):
        sys.stderr.write('%s %s -> %s\n' % (self.command, self.path, args[1] if len(args) > 1 else ''))


for v in ['GET', 'PUT', 'POST', 'HEAD', 'DELETE', 'OPTIONS', 'PROPFIND', 'PROPPATCH', 'REPORT', 'MKCALENDAR', 'MKCOL', 'MOVE', 'COPY', 'LOCK', 'UNLOCK']:
    setattr(Handler, 'do_' + v, Handler.proxy)

print('dav-proxy: %d -> %s' % (PORT, SHIP), file=sys.stderr)
ThreadingHTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
