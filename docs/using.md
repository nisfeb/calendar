# Using the calendar

## Settings

The **Settings** button opens one screen with every calendar this ship has and
where each comes from:

- **Calendars** — every calendar with its kind (local, followed, google),
  its color and name (editable), and a count. New local calendars are made
  here; the default one cannot be deleted.
- **Sharing over CalDAV** — the URL to give Thunderbird, DAVx5 or iOS, and
  the client passwords (one per device, shown once, revocable).
- **Sharing with ships** — share a local calendar with another ship by
  name, read-only or edit; accept the calendars other ships share with
  you. See below.
- **Following a CalDAV calendar** — follow another ship's or a Nextcloud
  calendar, both ways. See `docs/caldav.md`.
- **Google Calendar** — your own OAuth client, connect, link calendars, both
  ways. See `docs/google.md`.
- **ICS feeds** — read-only subscriptions to any `.ics` address.

## Tasks

The **Tasks** view (or `k`) lists what is to do, soonest due first and undated
last, with the done ones folded underneath. Tick a task there or in its popup;
type a name at the top to add one, with an optional due date and calendar.
A task with a due date also sits on that day in the month, week and day views,
with a box that shows whether it is done. The event form has a **Task** kind
with the same two fields, so a task can carry a note, tags and a color like
any event.

Tasks are iCalendar `VTODO` (RFC 5545): `DUE` (a zoned one becomes absolute),
`DTSTART`+`DURATION` as the due when there is no `DUE`, `STATUS` and
`COMPLETED` in and out. A start date alone, a repeat rule (`RRULE`),
`STATUS:IN-PROCESS` with a percent, `PRIORITY` and the rest ride verbatim and
go back out as they came; here such a task is one item, placed by its due
(a recurring task's per-instance overrides are not kept). A relative alarm
on a task counts from its due moment. A calendar shared with you read-only
refuses edits from every side: the app, CalDAV clients, and import. Over CalDAV the calendar
advertises `VTODO` in its component set, `calendar-query` honours a
`comp-filter` for `VTODO` or `VEVENT`, and so Thunderbird's task list, Tasks.org
and DAVx5 see them as tasks. Google Calendar has no tasks (they live in Google
Tasks, a separate API), so a task in a Google-linked calendar stays on this
ship. Sharing with ships and following over CalDAV carry tasks like events.

API: `add-event` with `cat: "todo"`, `due_ms` and `done_ms` (both optional);
`done-event {id, done}` ticks or unticks; `events.json` rows carry `due_ms`
and `done`, `window.json` rows `done`. Gate: `scripts/todo-matrix.py`.

## Tags

An event takes tags in its form (comma separated). The popup shows them, and
the header's tag filter narrows every view to one tag.

Tags are iCalendar `CATEGORIES` (RFC 5545), so Thunderbird, DAVx5 and iOS
show and edit them as categories, and they survive export, import and
following. Google has no field for them; there they ride in the event's
private extended properties and come back intact.

API: `GET /apps/calendar/tags.json` lists tags with counts;
`window.json` and `events.json` take `?tag=<tag>`; rows carry `meta.tags`.

## Making a synced calendar local (migrate)

Settings → Calendars → **Make local** on a followed or Google calendar. It
pulls once more, then stops syncing: the sync row goes and the remote ids
come off the events. The calendar stays, with everything in it, as a local
calendar — shareable over CalDAV like any other. The source is not changed;
if you no longer want it there, delete it at the source yourself. Nothing
here ever deletes a calendar for you.

## Sharing a calendar with a ship

Settings → Calendars → **Share…** on a local calendar: name the ship
(`~sampel-palnet`) and choose read-only or edit. The other ship sees an offer
under Settings → Sharing with ships, and accepts or declines it. An accepted
calendar appears there as a calendar of its own, marked *shared with you*;
it is pulled every few minutes and on demand. With edit, their changes reach
this ship within seconds and are merged like any other sync (conflicts land
in the Google/CalDAV conflict list).

No passwords: the host lays two usergroups per shared calendar,
`cal-<id>-read` and `cal-<id>-edit`, and grubbery's cross-ship permissions
decide who may read the share file and who may poke edits in. The peer keeps
its own copy; a host that is down just means a stale copy until it is back.

Sharing again with the same ship changes its mode (read to edit, or back)
in place; the peer's row follows without a new offer. **Revoke** on the host
stops the sync and drops the groups. The peer's copy
stays, as a local calendar of theirs (the same flip as *migrate*); nothing
here ever deletes a calendar for anyone.

The offer rides through the ship's `/public` usergroup, so a peer must have
approved the calendar's `/sys/ames/*` roads in grubbery permits, once. Refuse
them and everything else still works; sharing with ships is just unavailable.

API: `POST /apps/calendar/share/share {id, ship, mode}`, `/share/revoke
{id, ship}`, `/share/accept {key}`, `/share/decline {key}`, `/share/sync`;
`GET /apps/calendar/share/shares.json` lists what is shared out, offered,
and accepted. Gate: `scripts/ship-share-matrix.py`.
