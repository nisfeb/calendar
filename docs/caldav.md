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

Scheduling (iTIP), free-busy, tasks (VTODO answers 403), journals, ACLs,
shared calendars between users. An event with modified instances
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
