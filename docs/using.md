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

**Revoke** on the host stops the sync and drops the groups. The peer's copy
stays, as a local calendar of theirs (the same flip as *migrate*); nothing
here ever deletes a calendar for anyone.

The offer rides through the ship's `/public` usergroup, so a peer must have
approved the calendar's `/sys/ames/*` roads in grubbery permits, once. Refuse
them and everything else still works; sharing with ships is just unavailable.

API: `POST /apps/calendar/share/share {id, ship, mode}`, `/share/revoke
{id, ship}`, `/share/accept {key}`, `/share/decline {key}`, `/share/sync`;
`GET /apps/calendar/share/shares.json` lists what is shared out, offered,
and accepted. Gate: `scripts/ship-share-matrix.py`.
