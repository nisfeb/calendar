# Using the calendar

## Settings

The **Settings** button opens one screen with every calendar this ship has and
where each comes from:

- **Calendars** — every calendar with its kind (local, followed, google),
  its color and name (a change saves as you make it), and a count. New
  local calendars are made here; the default one cannot be deleted. An
  `.ics` file imports here into any calendar you can write, each object
  replacing one with its UID.
- **Conflicts** — when an event changed here and on Google, a followed
  calendar or a sharing ship between two syncs (or a push was refused),
  the other side's copy won; your copy is kept here to download, until
  you clear the log.
- **Sharing over CalDAV** — the URL to give Thunderbird, DAVx5 or iOS, and
  the client passwords (one per device, shown once, revocable).
- **Sharing with ships** — share a calendar with another ship by name, read-only or edit; accept the calendars other ships share with you. A calendar shared with you read-only offers no edit, skip or delete in the page. See below.
- **Following a CalDAV calendar** — follow another ship's or a Nextcloud
  calendar, both ways. See `docs/caldav.md`.
- **Google Calendar** — your own OAuth client, connect, link calendars, both
  ways. See `docs/google.md`.
- **ICS feeds** — read-only subscriptions to any `.ics` address.
- **Notifications** — browser notifications from this ship: a notice before
  each timed event (30 minutes by default) and one at each alarm an event
  carries. One subscription serves every app on the ship (furum's too), and a
  browser already on in furum already gets these. Nothing is sent if the
  calendar's push road was refused under Permits.

## Reminders

Every event or task's form has a **Reminders** list: presets before the
start (or a task's due), **The morning of (9:00)** for all-day events,
birthdays and tasks, **Minutes before…** and **At a date and time…** (a wall
clock in the calendar's zone). A task due on a date with no clock counts
from midnight where the calendar is, so the morning preset is 9:00 there
(since version 24; before, such a task's reminders counted from UTC midnight).
The popup shows an occurrence's reminders. They fire on the ship (see
Notifications under Settings) and travel over CalDAV, to Google as its
reminders, and to Talon. A series split with "this and following" carries
its reminders to the new series. Timed events also get the ship's heads-up
before every start, with or without reminders (`lead_min` in the API).

## Tasks

The **Tasks** view (or `k`) lists what is to do in groups: Overdue, Today,
Tomorrow, This week, Later and Undated, each with its count and folding
(the fold is remembered in this browser). Done tasks sit underneath, the
last week's by default; **Show all** brings the older ones back, and
**Delete done older than a week** removes them, after a confirmation, from
the ship and so from every CalDAV client and share. Tick a task there or in
its popup; type at the top to add one. The last words typed can be `#tags`
and a date: `today`, `tomorrow`, a weekday (`fri` is the coming Friday),
`in 3 days`, `next week`, `oct 12`, `2026-10-12`; the line under the box
shows what was read, and the date picker still works when nothing is typed.
Keys in the view: `j`/`k` or the arrows move along the rows, `x` ticks the
one in focus, `n` goes to the box. A task can carry a **priority** (High,
Medium, Low in the form; `!high`, `!med`, `!low` or `!1` to `!9` in the
box): a badge on the row, and the order inside each group, highest first.
It is iCalendar `PRIORITY` (1 highest, 9 lowest), so Thunderbird and
Tasks.org show the same thing.
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

API: `add-event` takes an optional `id`, the new event's id, chosen by the
caller: a poke answers only with its ack, so a client that needs the id
names it. It must not be in use and must hold no `/`, `#` or control
character (at most 255 bytes); otherwise the add is refused. Without one,
the ship makes an id.

API: every event object (`window.json`, `events.json`, `event.json`) carries
`alarms`, `[]` when there are none: `{"kind":"before","s":900,"desc":""}`,
`{"kind":"at","at_ms":…,"desc":""}` or
`{"kind":"offset","from":"start"|"end","after":true|false,"s":600,"desc":""}`
(`s` whole seconds; `desc` verbatim, Google's method lands there).
`add-event` and `edit-event` take an optional `alarms` list in the same
shape: absent keeps the entry's, a list replaces them, `[]` clears them, and
one that cannot be read (an unknown kind, a negative `s`, `at` without
`at_ms`) refuses the whole poke, with the reason on the ship's log. A change
moves the etag and seq like any edit, so CalDAV clients and Google (which
takes `before` alarms) hear of it. `config.json` carries `lead_min`, the
heads-up sent before every timed event (30 by default), and
`{"action":"config","lead_min":N}` sets it; `0` turns it off and leaves the
alarms events carry. Gate: `scripts/edge-matrix.py`.

API: every task object (`events.json`, `event.json`, `window.json` rows
with `cat: "todo"`) carries `priority`, 0 to 9, always present (0 = none,
1 highest). `add-event` and `edit-event` on a task take an optional
`priority`: absent keeps it, 1 to 9 sets it, 0 clears it, anything else
refuses the poke. It is the task's `PRIORITY` over CalDAV.

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

## Reading a part of the calendar

A big calendar need not be read whole. `GET /apps/calendar/window.json?from=<ms>&to=<ms>` answers the occurrences in a window, one row each (`id`, `cal`, `idx`, `l`, `r`, `meta`). `events.json` answers entries, one row per event, and takes the same window: `?from=<ms>&to=<ms>` keeps the events with an occurrence in it (a series that began earlier included, a task due in it included, an undated task not). It also takes `?cat=` (`timed`, `allday`, `date`, `todo`) and `?tag=`, together or alone; `?cat=todo` is the task list. A window is at most 800 days, and a window needs both ends.

Another app on the ship can read the occurrence index itself: `order.calendar-cache` in the calendar's instance, `[thru stops order]` with each occurrence under its event's UID. That shape and those keys stay as they are for such readers; the calendar keeps its own index, keyed `<calendar>/<uid>`, in `index.calendar-cache`.

## Repeats

Every repeating event is an RFC 5545 RRULE (the `rrule` kind), besides a single moment (`once`) and a fixed period in minutes (`every`). The form's Daily, Weekly, Monthly and Yearly choices build one and read one back; a rule the form cannot show (an interval, an UNTIL, several month days) stays as it came and saves unchanged. The older preset kinds (`daily`, `weekly`, `monthly`, `monthly-nth`, `yearly`, and `cron` where it fires once a day) are converted on the way in: an `add-event` poke naming one still works, and a ship's stored events of those kinds are converted once when the new version starts, keeping every skip and cap in place.

An UNTIL given in UTC is compared in the event's own zone, so a series ends on the day its client meant. So is an EXDATE or RECURRENCE-ID in UTC or another zone. A cancelled event or instance (`STATUS:CANCELLED`) is kept but not shown. A time that does not exist (inside the hour a spring-forward skips) is moved forward by the gap, and one that happens twice is the first, as RFC 5545 says.

A count ("Ends after") is how many times the event happens, as COUNT is: a monthly event on the 31st with a count of 3 runs on three 31sts, not three months. It ends after a count or by a date, not both; setting one in the form clears the other.

Skipping one occurrence from its popup leaves a note with **Undo** for a few seconds (`unskip-at`, the same fields as `skip-at`). **This and following** is one action on the ship (`split-event`): the series ends before the occurrence, a new one starts on it with the form's fields, and the skips that fall after it carry over. Its count, left as it was, is what remained of the old one.

## The same event in two calendars

The same UID can live in two calendars (a meeting in your Google calendar and in a calendar a peer shares with you). Each shows as its own event. Pokes that name an event by `id` take an optional `home` (the calendar id) to say which copy; without it the first found is used. `event.json` takes `?cal=` the same way.

## Making a synced calendar local (migrate)

Settings → Calendars → **Make local** on a followed or Google calendar. It
pulls once more, then stops syncing: the sync row goes and the remote ids
come off the events. The calendar stays, with everything in it, as a local
calendar — shareable over CalDAV like any other. The source is not changed;
if you no longer want it there, delete it at the source yourself. Nothing
here ever deletes a calendar for you.

## Sharing a calendar with a ship

Settings → Calendars → **Share…** on a calendar of yours (local, Google, or
followed; not one another ship shared with you): name the ship
(`~sampel-palnet`) and choose read-only or edit. The other ship sees an offer
under Settings → Sharing with ships, and accepts or declines it. An accepted
calendar appears there as a calendar of its own, marked *shared with you*;
it is pulled every few minutes and on demand. With edit, their changes reach
this ship within seconds and are merged like any other sync (conflicts land
in the Google/CalDAV conflict list).

Sharing a Google or followed calendar onward works the same way, with one
thing to know: a peer with edit rights writes into that calendar on your
ship, and your sync carries those edits up to Google or the source as if
you made them. Two syncs in a row also means a hiccup on either can leave
the peer with a stale copy until the next pass.

No passwords: the host lays two usergroups per shared calendar,
`cal-<id>-read` and `cal-<id>-edit`, and grubbery's cross-ship permissions
decide who may read the share and who may poke edits in. The peer keeps
its own copy; a host that is down just means a stale copy until it is back.

What the peer reads each pass stays small as the calendar grows. The host
publishes each shared calendar twice: whole, as `shares/<id>.json` (every
event's text), and as a folder, `shares/<id>/` (an `index.json` with each
event's version tag and file, and one file per event). A pull reads the
index, then fetches only the events whose tag moved. It reads the whole
file instead on a first pull, when more than 40 events moved, or when the
host has no folder it may read (a host on older code). Each accepted row
in `GET /apps/calendar/share/shares.json` says how the last pull that
changed something read the host (`via`: `index` or `whole`, and
`fetched`). A share made before the folder existed
gets it, and its groups the road to it, on the host's next pass.

Sharing again with the same ship changes its mode (read to edit, or back) in place; the peer's row follows without a new offer. An edit the host refuses (the calendar became read-only, or the event could not be read) is said back to the peer, which keeps its copy in the conflict list, takes the host's copy back at once (or drops the object the host never took) and, told the calendar is read-only, stops offering edits. **Revoke** on the host stops the sync and drops the groups. The peer's copy stays, as a local calendar of theirs (the same flip as *migrate*); nothing here ever deletes a calendar for anyone.

The offer rides through the ship's `/public` usergroup, so a peer must have
approved the calendar's `/sys/ames/*` roads in grubbery permits, once. Refuse
them and everything else still works; sharing with ships is just unavailable.

API: `POST /apps/calendar/share/share {id, ship, mode}`, `/share/revoke
{id, ship}`, `/share/accept {key}`, `/share/decline {key}`, `/share/sync`;
`GET /apps/calendar/share/shares.json` lists what is shared out, offered,
and accepted. Gate: `scripts/ship-share-matrix.py`.
