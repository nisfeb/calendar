# Using the calendar

## Settings

The **Settings** button opens one screen with every calendar this ship has and
where each comes from:

- **Calendars** — every calendar with its kind (local, followed, google),
  its color and name (editable), and a count. New local calendars are made
  here; the default one cannot be deleted.
- **Sharing over CalDAV** — the URL to give Thunderbird, DAVx5 or iOS, and
  the client passwords (one per device, shown once, revocable).
- **Following a CalDAV calendar** — follow another ship's or a Nextcloud
  calendar, both ways. See `docs/caldav.md`.
- **Google Calendar** — your own OAuth client, connect, link calendars, both
  ways. See `docs/google.md`.
- **ICS feeds** — read-only subscriptions to any `.ics` address.

## Tags

An event takes tags in its form (comma separated). The popup shows them, and
the header's tag filter narrows every view to one tag.

Tags are iCalendar `CATEGORIES` (RFC 5545), so Thunderbird, DAVx5 and iOS
show and edit them as categories, and they survive export, import and
following. Google has no field for them; there they ride in the event's
private extended properties and come back intact.

API: `GET /apps/calendar/tags.json` lists tags with counts;
`window.json` and `events.json` take `?tag=<tag>`; rows carry `meta.tags`.
