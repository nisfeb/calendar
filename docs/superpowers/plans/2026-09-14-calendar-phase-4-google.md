# Calendar phase 4: Google Calendar, two-way

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Google calendar linked from the settings page stays in sync both ways: pulled every few minutes with a sync token, pushed on every local change, conflicts logged, all with the user's own OAuth client.

**Architecture:** Config and credential live in three grubs at the instance root (`google.json` for the client and endpoints, `google-auth.json` for the tokens, `google-sync.json` for per-calendar sync tokens, id maps and the push watermark). A linked Google calendar is a ship calendar of kind `%google` whose `remote` is the Google calendar id. One sync fiber (rail `google.sig`) ticks on behn, is prodded by a poke, and also wakes on calendar news: each pass pulls (events.list with the sync token; 410 means a full resync) then pushes (the calendar's log past the watermark, parents only). `lib/gcal.hoon` translates Google event JSON to entries and back, reusing the rrule kind and the DAV override children. Every Google endpoint is a URL in `google.json`, so the gate runs against a fake Google on localhost.

**Tech Stack:** Hoon, iris through a status-aware fetch, `de:json`/`en:json`, Python 3 for the fake Google and the gate.

**Spec:** `docs/superpowers/specs/2026-09-13-calendar-sync-design.md`, section 6.

## Global Constraints

- No model change. Google's event id and `updated` stamp ride in entry `props` (`X-GOOGLE-ID`, `X-GOOGLE-UPDATED`); sync state lives in `google-sync.json`.
- No new roads; iris is already asked.
- The user brings their own OAuth client. No credential is ever answered back to the browser except the connection status; the secret is masked in `google.json` reads.
- Pulled writes advance the push watermark past themselves, so nothing pulled is ever pushed back.
- Every task compiles on `~wex` and is exercised against `scripts/fake-google.py` before it is committed. `code/version.json` bumps to 5 in the last task only.

---

### Task 1: config, OAuth, linking

**Files:**
- Modify: `code/nex/calendar/app.hoon`, `calendar.html`, `calendar.js`, `calendar.css`
- Create: `scripts/fake-google.py`

**Interfaces:**
- `google.json`: `{client_id, client_secret, auth_url, token_url, api_base, tick_min}` (defaults: Google's URLs, tick 5).
- `google-auth.json`: `{refresh_token, access_token, expires_ms}`.
- `google-sync.json`: `{<cal-id>: {google_id, sync_token, last_ms, pushed_seq, ids: {uid: google-event-id}}}`.
- `++  fetch-full  |=(request:http (fiber [status=@ud body=@t]))` — `%cancel` is status 0.
- `++  google-token` — a valid access token, refreshing through `token_url` when `expires_ms` is near; `~` when not connected.
- Routes (owner): `GET google.json` (secret masked, `connected` flag), `POST google/config`, `GET google/connect` (302 to the consent screen: `client_id`, `redirect_uri` = `<origin>/apps/calendar/google/callback`, `scope`, `access_type=offline`, `prompt=consent`, `state`), `GET google/callback?code=` (exchange, store, 302 to `/apps/calendar?google=connected`), `GET google/calendars.json` (calendarList.list), `POST google/link {google_id, name, color}` → a `%google` calendar with id `g-<hash>`, `POST google/unlink {id}` (the ship calendar and its sync entry go; events stay on Google), `POST google/disconnect`.
- UI: a **Google** button and modal: the walkthrough (Cloud project → consent screen in testing → web client → redirect URI shown to copy), client id/secret form, Connect, the Google calendar list with Link, linked calendars with Unlink and last sync, conflicts count.
- `scripts/fake-google.py PORT`: `/token` (code and refresh grants), `/calendar/v3/users/me/calendarList`, `/calendar/v3/calendars/<id>/events` (list with `syncToken`/`pageToken`/`showDeleted`, insert), `/calendar/v3/calendars/<id>/events/<eid>` (get, update via PUT, delete), plus `/__control` (`POST` with `{op: put|delete|gone|reset, ...}`) to make remote changes and force a 410. Bearer checked. State in memory.

- [ ] Compile on wex; through the fake: config → connect (the fake's consent redirects straight back with a code) → calendars.json lists the fake's calendars → link one → `calendars.json` on the ship shows a `google` calendar. Commit.

### Task 2: pull

**Files:**
- Create: `code/lib/gcal.hoon`
- Modify: `code/nex/calendar/app.hoon`

- [ ] `lib/gcal`: `++  entry-of  |=([item=json zone=(unit @t)] (unit [e=entry:cal rid=(unit @t)]))`: `iCalUID` (else `id@google`) → uid; `summary/description/location` → meta; `start/end` `dateTime` (with offset, → utc) or `date` (all-day, `days` from end); `recurrence` RRULE lines → the rrule kind (EXDATE lines → exdates); `reminders.overrides` → alarms; `status: cancelled` → tombstone; `recurringEventId` + `originalStartTime` → an override (rid = the original start as RECURRENCE-ID text); `id`, `updated`, `etag` → props `X-GOOGLE-ID`, `X-GOOGLE-UPDATED`.
- [ ] The sync fiber (rail `google.sig`, on-file; a poke prods it; keep on `calendar.calendar` wakes it for pushes; behn every `tick_min`): for each linked calendar: `events.list` with `syncToken` (or `showDeleted=true&singleEvents=false` full), all pages; each item → put (through `with-exdates` for the parent, children as in DAV PUT) or `del-entry`; cancelled exception instances become skips on the parent; store `nextSyncToken`, `last_ms`, the id map, and `pushed_seq` = the calendar's seq after the writes. 410 → clear the token, full resync next pass (deleted-on-Google entries that are no longer listed are removed on a full resync).
- [ ] Gate through the fake: a timed, an all-day, a weekly-with-exception and an alarmed event created via `/__control` appear on the ship's `events.json`/`window.json`; a `/__control delete` removes one; `gone` forces a full resync and everything still matches. Commit.

### Task 3: push

**Files:**
- Modify: `code/lib/gcal.hoon`, `code/nex/calendar/app.hoon`

- [ ] `++  json-of  |=([e=entry:cal zone=(unit @t)] json)`: the reverse for a parent entry (`start/end`, `recurrence` from the rrule text or the preset via `preset-rrule:ics`, EXDATEs from `exdates-of`, `reminders` with `useDefault: false` and the alarms, `iCalUID` = uid, `extendedProperties.private.grubbery = 1`).
- [ ] Push pass after each pull: walk the calendar's log after `pushed_seq`; per uid the latest change; skip children; put with a known id → `PUT events/<id>`, without → `POST events` (store the returned id in props and the map); del with a known id → `DELETE events/<id>`. 5xx or 429 → stop the pass, keep the watermark, try next tick; 404 on update → insert; 4xx else → log to conflicts, advance. On success `pushed_seq` = seq.
- [ ] Gate: a poke `add-event` into the google calendar reaches the fake within a prod; an edit updates it; a DAV PUT to the calendar reaches it; a delete deletes it; the pulled copy is never pushed back (the fake counts writes). Commit.

### Task 4: conflicts and the settings view

**Files:**
- Modify: `code/nex/calendar/app.hoon`, `calendar.js`, `calendar.html`

- [ ] A pulled item whose uid has a local change after `pushed_seq` (in the log, before this pull) is a conflict: Google's copy wins, the local copy (as ICS text) and Google's `updated` are appended to `google-conflicts.json` `{uid, cal, at, local, remote_updated}`. A push answered 409/412 is logged the same way and the next pull settles it.
- [ ] `GET google/conflicts.json`, `POST google/conflicts/clear`. The modal lists them with the local ICS to copy.
- [ ] Gate: `/__control put` on a uid that also changed locally → one conflict logged, the ship shows Google's version. Commit.

### Task 5: the gate script, docs, version 5

**Files:**
- Create: `scripts/google-matrix.py SHIP_URL COOKIE_JAR FAKE_PORT`, `docs/google.md`
- Modify: `code/version.json` → 5

- [ ] `google-matrix.py`: starts nothing (the fake runs beside it); configures the nexus to the fake, connects, links, then the matrix: both directions add/edit/delete, recurring with exception from Google, alarm both ways, forced 410, forced conflict, no echo. Non-zero on the first failure; cleans up (unlink, disconnect, fake reset).
- [ ] `docs/google.md`: the Cloud console walkthrough with screenshots-in-words, the redirect URI, what syncs and what does not, conflicts.
- [ ] Version 5. Push; wex pulls (the mirror polls now); feb follows; the matrix passes on wex.
