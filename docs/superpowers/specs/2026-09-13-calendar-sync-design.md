# Calendar: its own desk, CalDAV, and two-way Google Calendar

Status: draft for review. 2026-09-13.

## 1. What this is

The grubbery calendar becomes its own app in its own repo (`nisfeb/calendar`),
installed as a stock desk from `~ricsul-bilwyt` the way lattice and auspex are,
and grows two things it does not have today:

- **CalDAV**, so Thunderbird, DAVx5 (Android) and iOS Calendar sync against the
  ship directly. Read and write.
- **Google Calendar, two-way**, so a Google calendar and a ship calendar hold
  the same events, edits flowing both directions.

It starts from the grubbery developers' calendar as it stands on `develop`:
the nexus, the rules library, the ICS reader, the marks, the UI and the six
MCP tools are copied into this repo unchanged and then extended. That code has
the abstractions worth keeping (section 2) and nothing worth throwing away.

## 2. What exists, and what we keep

From `gwbtc/grubbery` `develop`, 741 lines of nexus plus four libraries:

| piece | what it does | keep |
|---|---|---|
| `lib/calendar.hoon` | the event model: `timed` (recurrence, zone, duration or end), `allday` (recurrence, day span), `date` (month/day). Every event has a recurrence, a bound (count, or exceptions) and free-form `meta`. Window inflation with a cache (`order.calendar-cache`). | yes, extended (section 4) |
| `lib/rules.hoon` + `lib/rules/*` | recurrence as **pluggable rule kinds** loaded from a code library road: once, daily, weekly, monthly, monthly-nth, yearly, cron. A kind is a gate from args to occurrences. | yes; this is the abstraction the two integrations hang on |
| `lib/ics.hoon` | RFC 5545 reader: unfolding, VEVENT collection, the three datetime forms. RRULE carried as text. | yes, and it grows a writer and an RRULE translation |
| reminders fiber | ticks on 5-minute UTC marks, pushes due reminders through the notifications app | yes |
| Google feeds | `gcal-feeds.json`: named secret ICS addresses fetched over iris and materialized as `gc-` events in a window | replaced by section 6; the feed path stays as the no-account fallback |
| UI | month, week, day; color; timezone; all-day lanes; search; recurrence editor | yes |
| MCP tools | list, window, add, delete, feeds list, feed read | yes; two more for sync status |
| `lib/pytz` (grubbery ball) | Olson zone data in hoon | needed for VTIMEZONE; vendored into this desk's `code/lib` |

Not there today, and needed: stable UIDs, ETags, tombstones, an ICS writer, an
RRULE kind, alarms as data, multiple calendars, any external write.

## 3. Shape of the desk

```
code/
  bill.json          {"calendar.calendar_app": "/calendar/app"}
  version.json
  tile.json  icon.svg
  nex/calendar/app.hoon        the nexus (from develop, then this spec)
  nex/calendar/ui-app/         calendar.html/js/css (from develop)
  lib/calendar.hoon  rules.hoon  rules/*.hoon  ics.hoon  pytz.hoon  pytz/*
  lib/tool-bundle/  tools.hoon  tools/*.hoon     the MCP tools
  mar/calendar.hoon  calendar-cache.hoon  and the marks the nexus reaches
```

Shell catalog entry on the distributor: `(published our 'calendar' 'nisfeb/calendar' 'main')`.
Subscribers get it through their desk source at `~ricsul-bilwyt`, like the
other two. Version bumps are what replicate.

**Carry.** A ship that ran the ball-era calendar has a dormant instance at
`/apps/calendar.calendar` holding `calendar.calendar`, `reminders.json`,
`gcal-feeds.json`. On the desk install's first writer rise, copy them across the
way lattice does (`+carry-old-data`: veto is not absence, per-child fold,
marker file), then never read the old path again. The ask names
`/apps/calendar.calendar/` as a read-only, once, optional road.

**Ask (weir.json).** bowl, eyre, behn (reminders and sync ticks), iris
(Google and feeds), the notifications poke road, `/sys/link/` (own address for
the UI), and the carry road. No `/sys/ames/*`: nothing in this spec is
ship-to-ship. CalDAV clients and Google both come in over HTTP.

## 4. Data model changes

These serve both integrations and are done first.

- **Calendars.** A ship has a set of calendars, not one. Each is a directory
  `cal/<id>/` with `props.json` (display name, color, kind: `local` |
  `google`, and for google the remote calendar id and sync state) and its
  events. The default calendar is `cal/default/`. The dormant instance's single
  calendar carries into `default`.
- **Identity.** Every event has a `uid` (iCalendar UID, generated as
  `<random>@<ship>` for events born here, taken verbatim from a client or
  Google otherwise) and an `etag` = a hash of the stored event. The event's
  path is `cal/<id>/ev/<uid>`. The old `eid` becomes the uid.
- **Change tracking.** `cal/<id>/log`: an append-only sequence of `[seq uid
  kind]` with kind `%put` or `%del`. The calendar's ctag and sync-token are the
  latest seq. Deleted events leave a tombstone in the log so a client asking
  "what changed since token N" hears about deletions. The log is compacted past
  `max-dead` (already a constant) once every client token is newer.
- **Recurrence.** A new rule kind, `rrule`, interprets RFC 5545 RRULE text
  directly (FREQ, INTERVAL, COUNT, UNTIL, BYDAY with ordinals, BYMONTHDAY,
  BYMONTH, WKST). It becomes the canonical form; the existing kinds remain as
  the editor's presets and serialize to RRULE. EXDATE maps to `except`,
  RDATE to a per-event extra-dates list. Anything `rrule` cannot express is kept
  as text and inflated by nothing, which is what happens today.
- **Alarms.** `VALARM` becomes data on the event (trigger relative to start,
  or absolute; display only). The reminders fiber reads event alarms as well as
  `reminders.json`, so a reminder set in Thunderbird fires on the ship.
- **Round-trip.** Properties this app does not model (ATTENDEE, ORGANIZER,
  CATEGORIES, X-*) are stored on the event as an opaque property list and
  written back verbatim. A client must get back what it wrote, or it will keep
  rewriting.
- **Timezones.** `zone` stays the event's timezone name. Serialization emits
  local time with `TZID` and a `VTIMEZONE` generated from `pytz`, because iOS
  and DAVx5 want the zone definition in the object and recurring events across
  a DST change are wrong in plain UTC.

Migration of the stored `calendar.calendar` noun: a versioned state with an
`on-load` that lifts `eid` to `uid`, assigns etags, and writes seq 0. Nothing
is thrown away.

## 5. CalDAV

**Where.** `/apps/calendar/dav/`. Also `/.well-known/caldav` redirecting to
it, which is what iOS and DAVx5 discover with; Thunderbird takes the calendar
URL directly.

**Auth.** CalDAV clients cannot log in through the ship's web login. HTTP
Basic: username is the ship name, password is a **client password** the user
mints on the calendar's settings page (one per client, revocable, shown once,
stored hashed in `dav/clients.json`). Every DAV request is checked in-app;
the ship cookie is accepted too so the browser can poke at it. Requests reach
the nexus unauthenticated the way lattice's clearweb ones do; the nexus does
the check, never eyre.

**Methods and depth.** eyre passes any method string, so the router switches
on it:

| method | on | does |
|---|---|---|
| `OPTIONS` | anything | `DAV: 1, 3, calendar-access`, `Allow` |
| `PROPFIND` depth 0/1 | principal, home, calendar, event | `current-user-principal`, `calendar-home-set`, `displayname`, `resourcetype`, `supported-calendar-component-set` (VEVENT), `getctag`, `sync-token`, `getetag`, `calendar-color` |
| `REPORT` | calendar | `calendar-query` with `time-range` (inflated through the existing window), `calendar-multiget`, `sync-collection` (from the log) |
| `GET` | event | the `.ics` with `ETag` |
| `PUT` | event | create or replace; honours `If-None-Match: *` and `If-Match`; 412 on mismatch; returns the new `ETag` |
| `DELETE` | event | tombstone; 204 |
| `MKCALENDAR` | home | a new local calendar |
| `PROPPATCH` | calendar | display name, color |

XML in and out through `de-xml:html` and `en-xml:html`, which are in zuse.
Namespaces to handle: `DAV:`, `urn:ietf:params:xml:ns:caldav`,
`http://apple.com/ns/ical/` (color), `http://calendarserver.org/ns/` (ctag).

**Object mapping.** One event per `.ics` object, as clients expect. A recurring
event with modified instances (`RECURRENCE-ID`) is one object with several
VEVENTs; the overrides are stored on the parent event keyed by recurrence id.

**What it does not do.** Scheduling (iTIP, attendees receiving invitations),
free-busy, tasks (VTODO), journals, ACLs, shared calendars between users. A
`VTODO` PUT is rejected with 403 and a clear body.

**Client matrix, and the gate.** Thunderbird (network calendar, CalDAV URL),
DAVx5 (account by well-known), iOS (CalDAV account, advanced settings if
discovery fails). For each: add, edit, delete, recurring with exception,
reminder, and the same in the other direction, seen on the ship's UI. Plus the
`caldav` Python library driving the same matrix against `~wex` in CI. Nothing
ships until all three clients pass by hand and the script passes in CI.

## 6. Google Calendar, two-way

**Auth.** OAuth 2.0 authorization code flow, redirect to
`https://<ship-host>/apps/calendar/google/callback`. The user brings their own
OAuth client (client id and secret from Google Cloud console), pasted once into
the settings page; the app has no shared client. Scope
`https://www.googleapis.com/auth/calendar`. The refresh token lives in
`google/auth.json`, which is in the app's own tree and nowhere else. The ask
names this: "hold a Google credential for the calendar you connect; refuse
this and Google sync is unavailable, everything else works".

**Model.** Each connected Google calendar is a ship calendar of kind `google`
under `cal/<id>/` with `props.json` holding `googleId`, `syncToken`, and the
last sync time. Events map by iCalendar UID: Google's `iCalUID` is our `uid`.
Google's own event `id` is kept in the event's opaque properties for updates.

**Pull.** A sync fiber per Google calendar, on a behn tick (default every 5
minutes, configurable) and on demand: `events.list` with `syncToken`
(incremental; on 410 GONE, a full resync with `showDeleted`). Each item becomes
a put or a tombstone in the log, with its `updated` stamp. Recurrence comes as
RRULE strings, so the `rrule` kind (section 4) does the work; Google's
exception instances (events with `recurringEventId` and
`originalStartTime`) become overrides on the parent.

**Push.** A local put or delete on a `google` calendar goes out as
`events.insert`, `events.update` or `events.delete` right away (with a short
retry backoff on 5xx and 429), and the returned `updated` and `id` are stored.
The change is logged locally first, so a client on CalDAV and Google see the
same seq.

**Conflicts.** Last writer wins by `updated` timestamp; on a tie the ship's
copy wins. A conflict is logged to `google/conflicts.json` with both versions
so nothing is lost silently; the settings page lists them.

**Alarms.** Google reminders map to VALARM and back (`useDefault` off on
events we write, explicit overrides carried).

**What it does not do.** Attendees and invitations (stored opaque, never
sent), calendar sharing, ACLs, Google Tasks, colors beyond the calendar's own.

**Rate.** One list call per calendar per tick, one write per local change.
Well inside Google's quota for a person.

## 7. Phases

Each phase is installable and useful on its own.

1. **The desk.** Repo laid out as section 3, the develop code moved in, carry
   from the dormant instance, catalog entry, install on `~wex` and `~feb`,
   release to `~ricsul-bilwyt`. No new features. Gate: the calendar you have
   today, at the new address, with its events and reminders.
2. **Model.** Calendars, uid, etag, log, `rrule` kind, alarms as data, opaque
   round-trip, ICS writer, VTIMEZONE. Plus `GET /apps/calendar/export.ics`
   as the first user-visible fruit. Gate: export, re-import into a fresh
   calendar, byte-identical objects.
3. **CalDAV.** Section 5, read-only first (PROPFIND, REPORT, GET), then
   write. Gate: the client matrix.
4. **Google.** Section 6. Gate: a test Google account, the matrix in both
   directions, a forced 410 resync, a forced conflict.

## 8. Testing

- Unit: `rules` (existing tests grow `rrule` vectors from RFC 5545's examples),
  the ICS reader and writer round-trip, the XML property responses.
- Integration on `~wex`: the CalDAV script matrix; a fake Google (a small local
  HTTP server answering the five endpoints used) for CI, the real one by hand.
- Cross-ship: nothing here is cross-ship. If that changes, the lesson from the
  lattice release applies: a test that reads from another ship, not a
  before-and-after on one.
- Never against `~ricsul-bilwyt` until it has passed on `~wex`.

## 9. Open questions

- One OAuth client per user is a chore. A shared client owned by nisfeb would
  be smoother and means the refresh tokens of every user trust one secret.
  Default here is per-user; say if you want the shared one.
- Multiple calendars in the UI (a calendar picker and per-calendar color) is
  UI work not costed here; phase 2 makes it necessary.
- Whether `/.well-known/caldav` can be bound by a nexus on this ship depends
  on what else claims well-known; lattice does not. To confirm on `~wex`
  before phase 3.
