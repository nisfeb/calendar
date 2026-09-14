# Calendar phase 3: CalDAV

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thunderbird, DAVx5 and iOS read and write the ship's calendars over CalDAV, authenticated with per-client passwords, with sync-collection so clients stay cheap.

**Architecture:** One handler in the nexus under `/apps/calendar/dav/`, switching on the HTTP method. The runtime (vere `_http_vec_to_meth`) answers 400 to any verb outside GET/PUT/POST/HEAD/CONNECT/DELETE/OPTIONS/TRACE, and lull's `method` mold is that same closed set, so DAV verbs arrive as `POST` with `X-HTTP-Method-Override`. In production nginx (already in front of `~ricsul-bilwyt`) rewrites the verb; on `~wex` a small Python proxy does the same for the test matrix. The nexus honours the real method too, so a runtime patch later needs no nexus change. XML in and out through `de-xml:html` / `en-xml:html`, matching element local names (the prefix before `:` is ignored). ETag is the entry's etag, ctag and sync-token are the calendar's seq, tombstones come from the log.

**Tech Stack:** Hoon (nexus + fiber io), zuse XML and base64, `shax` for password hashing, Python 3 + `caldav` 3.x for the gate.

**Spec:** `docs/superpowers/specs/2026-09-13-calendar-sync-design.md`, section 5.

## Global Constraints

- No model change: `entry`, `cal`, `calendar` keep their v2 shape. DAV state lives in `dav/clients.json` (a grub in the instance) and in entry `props`.
- No new roads. The ask does not change.
- Every DAV request is authenticated in the nexus: HTTP Basic against a minted client password, or the owner's ship cookie (`authenticated.req`). Never eyre.
- The verb is `(fall (get-header:http 'x-http-method-override' headers) method)` when the method is POST; otherwise the method.
- Paths: principal `/apps/calendar/dav/`, home `/apps/calendar/dav/cal/`, calendar `/apps/calendar/dav/cal/<id>/`, object `/apps/calendar/dav/cal/<id>/<uid>.ics`. `/.well-known/caldav` is the proxy's job (301 to the principal).
- Every task compiles on `~wex` and is exercised through `scripts/dav-proxy.py` before it is committed. `code/version.json` bumps to 4 in the last task only.

---

### Task 1: the door — auth, verb, OPTIONS, client passwords

**Files:**
- Modify: `code/nex/calendar/app.hoon`
- Modify: `code/nex/calendar/calendar.html`, `calendar.js` (a CalDAV modal)
- Create: `scripts/dav-proxy.py`

**Interfaces:**
- Produces: `++  dav-verb  |=(req=inbound-request:eyre @t)`; `++  dav-auth  |=([req=inbound-request:eyre clients=json] ?)`; grub `dav/clients.json` = `[{id,name,salt,hash,made_ms}]` (hash = `(scot %ux (shax (rap 3 salt password ~)))`); routes `GET /apps/calendar/dav-clients.json` (owner), `POST /apps/calendar/dav-clients {name}` → `{id, password}` shown once, `DELETE`-as-`POST /apps/calendar/dav-clients/revoke {id}`; `OPTIONS` on any dav path → 200 with `DAV: 1, 3, calendar-access` and `Allow`.

- [ ] In the requests fiber, before the `src == our` gate: if `suffix` starts with `%dav`, run `(dav-request eyre-id req src our)` and stop. Inside, `authenticated.req` passes; else parse `authorization: Basic <b64>` with `de:base64:mimes:html`, split at the first `:`, hash the password with each client's salt, compare to `hash`. No match → 401 with `WWW-Authenticate: Basic realm="calendar"`.
- [ ] `OPTIONS` → 200, headers `DAV: 1, 3, calendar-access`, `Allow: OPTIONS, GET, PUT, DELETE, PROPFIND, PROPPATCH, REPORT, MKCALENDAR`. Unknown verb → 405. `POST` to a dav path without an override → 405.
- [ ] Client minting: password = 24 chars from entropy (`get-entropy:io`, base32 of 15 bytes). The modal (a "CalDAV" button in the header) lists clients, mints one showing the password once with the URL to paste, revokes.
- [ ] `scripts/dav-proxy.py LISTEN_PORT SHIP_URL`: forwards everything; a non-standard verb becomes POST with `X-HTTP-Method-Override: <verb>`; `/.well-known/caldav` → 301 to `/apps/calendar/dav/`. Stdlib only (`http.server`, `urllib`).
- [ ] Check on wex through the proxy: `curl -u wex:<pw> -X OPTIONS http://127.0.0.1:8091/apps/calendar/dav/` → 200 with the DAV header; wrong password → 401; PROPFIND (via proxy) → 501 for now. Commit.

### Task 2: PROPFIND

**Files:**
- Modify: `code/nex/calendar/app.hoon`
- Create: `code/lib/dav.hoon` (XML helpers: `++  local-name`, `++  find-el`, `++  multistatus`, `++  response`, `++  propstat`, property builders)

- [ ] `de-xml` the body (empty body = allprop). Requested props = the children of `prop` by local name; `allprop` = the full set below.
- [ ] Depth from the `depth` header (default 0). Responses:
  - principal `/dav/`: `resourcetype` (collection, principal), `current-user-principal` (href `/apps/calendar/dav/`), `calendar-home-set` (href `/apps/calendar/dav/cal/`), `displayname` (ship name), `principal-URL`.
  - home `/dav/cal/`: `resourcetype` collection; depth 1 adds each calendar.
  - calendar `/dav/cal/<id>/`: `resourcetype` (collection, `C:calendar`), `displayname`, `calendar-color` (`ical:calendar-color`), `supported-calendar-component-set` (VEVENT), `getctag` (`cs:getctag` = seq), `sync-token` (`/apps/calendar/dav/sync/<seq>`), `supported-report-set` (calendar-query, calendar-multiget, sync-collection), `current-user-privilege-set` (read, write). Depth 1 adds each object with `getetag` and `getcontenttype text/calendar`.
  - object: `getetag`, `getcontenttype`, `resourcetype` (empty).
  A requested prop we do not have → a second propstat with 404.
- [ ] 207 `multistatus`, `content-type: application/xml; charset=utf-8`, namespaces declared on the root: `D` (DAV:), `C` (caldav), `CS` (calendarserver), `A` (apple ical).
- [ ] Check: `python3 -c "import caldav; ..."` through the proxy: `principal()`, `calendars()` lists the ship's calendars with their names. Commit.

### Task 3: REPORT and GET

**Files:**
- Modify: `code/nex/calendar/app.hoon`, `code/lib/dav.hoon`

- [ ] `GET /dav/cal/<id>/<uid>.ics`: the entry (parent + its override children, see Task 4) via `write-calendar:ics`, `ETag: "<etag>"`, `content-type: text/calendar`. 404 when unknown.
- [ ] `REPORT calendar-multiget`: each `href` → a response with `getetag` and `calendar-data` (the same text as GET); unknown href → 404 response.
- [ ] `REPORT calendar-query`: with `time-range start/end` → refs from `window:cal` on the cache (refresh-ahead as window.json does) mapped to their parent uid, deduplicated; without → every non-child entry. Same response shape as multiget.
- [ ] `REPORT sync-collection`: token `/apps/calendar/dav/sync/<n>` (empty = 0). Walk the log after n: latest kind per uid; `%put` → response with etag, `%del` → response with `status 404`. Root `sync-token` = current seq. Children are never listed.
- [ ] Check with `caldav`: `calendar.events()` returns the ship's events with correct summaries; `calendar.date_search` for a window; `calendar.objects_by_sync_token()` twice, the second empty. Commit.

### Task 4: PUT, DELETE, MKCALENDAR, PROPPATCH, overrides

**Files:**
- Modify: `code/nex/calendar/app.hoon`, `code/lib/ics.hoon`

- [ ] `PUT /dav/cal/<id>/<name>.ics`: body → `events:ics`; the VEVENT without `RECURRENCE-ID` is the parent, `to-entry`, uid from the body (the file name is not trusted). `If-None-Match: *` with an existing uid → 412. `If-Match: "<etag>"` not equal to the stored etag → 412. VTODO/VJOURNAL only → 403 with a plain body. Success: 201 (new) or 204, `ETag` header.
- [ ] Overrides: each VEVENT with `RECURRENCE-ID` becomes a child entry, uid `<uid>#<rid-text>`, props gain `['X-GRUBBERY-PARENT' uid]` and `['RECURRENCE-ID' rid-text]`; the parent's `except` gains the occurrence index found by walking the kind (as `with-exdates` does). A PUT replaces the parent's whole override set (delete children not in the body). GET/REPORT emit the parent then its children in one VCALENDAR; children carry the RECURRENCE-ID line through `props`, and `write-entry` skips the X-GRUBBERY-PARENT prop. DAV listings skip children.
- [ ] `DELETE` object: `del-entry` the parent and its children (each logs `%del`), 204. Unknown → 404.
- [ ] `MKCALENDAR /dav/cal/<id>/`: body's `displayname` and `calendar-color` (defaults: id, `#1e3a5f`), 201; exists → 405.
- [ ] `PROPPATCH /dav/cal/<id>/`: `displayname`, `calendar-color` → `edit-calendar` semantics; 207 with 200 propstats for those, 403 for others.
- [ ] Check with `caldav`: create, update (etag changes), delete an event; a weekly event, then PUT it back with one moved instance and watch the ship's `window.json` show the moved occurrence; DELETE removes both. Commit.

### Task 5: the gate, the docs, version 4

**Files:**
- Create: `scripts/dav-matrix.py HOST_THROUGH_PROXY USER PASSWORD`
- Create: `docs/caldav.md` (nginx snippet, client setup for Thunderbird / DAVx5 / iOS, the runtime note)
- Modify: `code/version.json` → 4

- [ ] `dav-matrix.py`: principal, calendars, add / edit / delete, recurring with one exception, alarm; then the other direction: events added on the ship (through the poke API with the cookie) appear via sync-collection. Exits non-zero on the first failure.
- [ ] `docs/caldav.md`: the nginx `location` that rewrites verbs (`if ($request_method ~ ^(PROPFIND|PROPPATCH|REPORT|MKCALENDAR)$) { proxy_method POST; proxy_set_header X-HTTP-Method-Override $request_method; }`) and the `/.well-known/caldav` redirect; the per-client URL `https://<host>/apps/calendar/dav/`; the runtime patch (`_http_vec_to_meth` + lull `method`) as the native alternative.
- [ ] Version 4. Push; wex re-syncs (poke the mirror's pull); the matrix passes; feb follows. The by-hand client matrix (Thunderbird, DAVx5, iOS) is the user's, against wex through the proxy.
