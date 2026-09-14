# CalDAV

The calendar speaks CalDAV at `/apps/calendar/dav/` (the principal). Calendars
live under `/apps/calendar/dav/cal/<id>/`, one `.ics` object per event.

## Client passwords

Open the calendar, press **CalDAV**, mint a password per client. The password
is shown once and stored as a salted sha-256 in `dav-clients.json`. Username is
your ship name (anything is accepted; the password identifies the client).
Revoke from the same panel.

## Clients

- **Thunderbird**: New Calendar → On the Network → username `~your-ship`,
  location `https://<host>/apps/calendar/dav/` → it finds every calendar.
- **DAVx5**: Add account → Login with URL and user name → base URL
  `https://<host>/` (well-known) or `https://<host>/apps/calendar/dav/`.
- **iOS**: Settings → Calendar → Accounts → Add → Other → CalDAV. Server
  `<host>`; if discovery fails, Advanced Settings → Account URL
  `https://<host>/apps/calendar/dav/`.

## The verb problem, and nginx

The runtime (vere) only passes GET, PUT, POST, HEAD, DELETE, OPTIONS, CONNECT
and TRACE to the ship; PROPFIND, PROPPATCH, REPORT and MKCALENDAR are answered
400 before the ship sees them. The nexus therefore also reads the verb from
`X-HTTP-Method-Override` on a POST. In production the nginx in front of the
ship rewrites the verb:

```nginx
location /apps/calendar/dav/ {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    if ($request_method ~ ^(PROPFIND|PROPPATCH|REPORT|MKCALENDAR)$) {
        proxy_method POST;
        proxy_set_header X-HTTP-Method-Override $request_method;
    }
}
location = /.well-known/caldav { return 301 /apps/calendar/dav/; }
```

(`proxy_set_header` inside `if` needs the outer `proxy_set_header Host`
repeated inside the block on some nginx versions.)

For a ship with nothing in front of it, `scripts/dav-proxy.py PORT SHIP_URL`
does the same on localhost.

The native alternative is a runtime patch: `_http_vec_to_meth` in
`pkg/vere/io/http.c` passes the DAV verbs, and lull's `method` mold lists
them. The nexus needs no change for that.

## What it does not do

Scheduling (iTIP), free-busy, journals, ACLs, shared calendars between
users (sharing with other ships is native, see `docs/using.md`). Tasks
(VTODO) are supported: DUE, STATUS, COMPLETED, a comp-filter on
calendar-query, and VTODO in the component set. An event with modified instances
(RECURRENCE-ID) is stored as a parent plus override children (uid
`<parent>#<recurrence-id>`); the ship's own views show the moved instance and
skip the original occurrence.

## The gate

```
python3 scripts/dav-proxy.py 8091 http://127.0.0.1:8081 &
python3 scripts/dav-matrix.py http://127.0.0.1:8091/apps/calendar/dav/ wex <password> http://127.0.0.1:8081 <cookie-jar>
```

Add, edit, a stale If-Match, an alarm, a recurring event with an exception,
calendar-query, sync-collection, deletes, MKCALENDAR, PROPPATCH, and an event
added on the ship reaching the client. Thunderbird, DAVx5 and iOS by hand.

## Following a remote calendar (the client side)

Settings → *Following a CalDAV calendar*: the collection URL (for another
ship, `https://<host>/apps/calendar/dav/cal/<id>/`), a username and a
password (on another ship, a client password minted under *Sharing*). The
remote's events arrive as a calendar of their own; edits here go back to the
source as PUT and DELETE at once, the source's changes arrive on the next
pass (every `tick_min` minutes, or **Sync now**).

The pull uses `sync-collection`, and falls back to a PROPFIND etag diff on a
server without it. Because the runtime's outbound HTTP has the same closed
verb set as its inbound, REPORT and PROPFIND leave the ship as POST with
`X-HTTP-Method-Override`. Servers that honour it: our own calendars,
SabreDAV-based ones (Nextcloud, Baïkal, ownCloud). Servers that do not:
iCloud, Google's CalDAV endpoint (use the Google section instead), Radicale.

The remote credentials are stored in `caldav-remotes.json` in the calendar's
own tree, in the clear — they are what authenticates each request. Use a
per-app password on the remote, never your account password.

A 412 on push (the remote changed the same object) is logged as a conflict
with the local copy; the next pull brings the remote's version.
