# Calendar phase 5: CalDAV client (subscribe to a remote calendar)

**Goal:** A ship calendar can follow a remote CalDAV collection — another ship's calendar, Nextcloud, Baïkal — both ways: pulled with sync-collection, pushed with PUT and DELETE.

**Architecture:** The same shape as the Google side. A subscribed calendar is a ship calendar of kind `%caldav`; `caldav-remotes.json` holds one row per linked calendar (url, user, password, sync token, href/etag per uid, push watermark). The sync fiber's pass runs the Google rows and then the CalDAV rows. Outbound REPORT and PROPFIND go as POST with `X-HTTP-Method-Override`, because iris has the same closed verb set the server side has; our own calendars and SabreDAV-based servers (Nextcloud, Baïkal) honour it. Objects are fetched by GET and pushed by PUT with If-Match, so the same ICS reader/writer and put-parent/put-override do the work.

**Spec:** section 5 gains the client side; this plan is its argument.

## Global Constraints

- `cal-props.kind` grows a `%caldav` case (a union grows; stored nouns are unaffected).
- Credentials for the remote live in `caldav-remotes.json` in the instance's own tree, plain (they are what authenticates); never answered to the browser.
- Nothing pulled is pushed back: the pull advances the watermark past its own writes, as Google does.
- Every task compiles on `~wex` and is exercised ship-to-ship (feb follows a wex calendar) before commit. Version 7 at the end.

### Task 1: rows, routes, the modal
- `POST /apps/calendar/caldav/subscribe {url, user, password, name, color}` → a `%caldav` calendar `c-<hash>` and its row; `POST caldav/unsubscribe {id}`; `GET caldav/subscriptions.json` (no passwords); `POST caldav/sync`.
- The CalDAV modal gains a "Follow a remote calendar" form and the list of followed calendars with Unfollow and last sync.

### Task 2: pull
- `++  dav-fetch [row method path body headers]`: Basic auth, override header on non-native verbs, status + body.
- `sync-collection` REPORT with the row's token (empty = everything); each response href with a 200 propstat → GET the .ics → `events:ics` → put-parent / put-override (children replaced), record href and etag; a 404 status response → delete the entry and its children. Store the new token. If the REPORT is refused (403/400/501) fall back to PROPFIND depth 1 with getetag and diff etags against the map.

### Task 3: push
- The log past the watermark: put → PUT `<collection>/<uid>.ics` (If-Match with the stored etag when known) with the parent and its children as one VCALENDAR; del → DELETE the href. 412 → conflict logged (the next pull settles it). 5xx/0 → stop, keep the watermark.

### Task 4: gate, docs, version 7
- `scripts/caldav-client-matrix.py`: feb follows a wex calendar through a minted password; both directions, a moved instance, delete both ways, no echo, a 412 conflict.
- `docs/caldav.md` gains the client section (which servers work, which do not, why).
