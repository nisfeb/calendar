# Google Calendar, two-way

Press **Google** on the calendar page. You bring your own OAuth client; the
app has no shared credential.

## Making the client (once, about five minutes)

1. console.cloud.google.com → make a project (any name).
2. **APIs & Services → Library** → enable **Google Calendar API**.
3. **APIs & Services → OAuth consent screen** → External → app name and your
   email. Then **Publish app** so its status is *In production*. Left in
   *Testing*, Google lets the sign-in last only 7 days for Calendar access,
   and you would press Connect again every week. Published and unverified is
   fine for your own use: Google shows an "unverified app" warning at
   Connect, which you click through (Advanced → go to the app). A project
   inside a company's Google Workspace can choose *Internal* instead: no
   warning, no test users, and the sign-in lasts.
4. **Credentials → Create credentials → OAuth client ID → Web application**.
   Under *Authorized redirect URIs* add exactly the URI the Google panel shows:
   `https://<your-host>/apps/calendar/google/callback`.
5. Paste the client id and secret into the panel, **Save**, then **Connect**.
   Google asks for consent, then sends you back; the panel lists your
   calendars. **Link** the ones you want on the ship.

The refresh token lives in `google-auth.json` inside the calendar's own tree
and nowhere else. **Disconnect** forgets it.

## A work account (Google Workspace)

It links the same way; what works depends on what the company's admin
allows.

- **Directly.** Connect and sign in with the work account. A client made in
  a project inside the company's organization can be *Internal* (above).
  One made in a personal project needs the admin to allow it: many
  companies block apps they have not approved from reaching Calendar, and
  Google answers "Access blocked … by your admin". The admin can trust the
  client id in the admin console.
- **Through a personal account.** Share the work calendar with your
  personal Google address (full event details, or edit rights for your
  changes to go back), then link it from the personal account; the panel
  lists every calendar an account can see. Companies often allow only
  free/busy outside the organization, and then there is nothing to read.
- **Not these.** The calendar's secret iCal address is often turned off in
  a company, and an ICS feed here skips repeating events. Following it over
  CalDAV does not work: Google's CalDAV needs an OAuth sign-in, and the
  follower signs in with a password.

Attendees, invitations and Meet links do not come across (see below), so a
meeting shows without its video link unless the link is in its
description.

## What syncs

- Every `tick_min` minutes (default 5), on **Sync now**, and right after a
  local change: the linked calendar is pulled with a sync token (a full
  listing when Google says the token expired) and local changes since the
  last push go out.
- Events map by iCalendar UID. Timed, all-day, recurring (RRULE, EXDATE),
  reminders (popup/email minutes ↔ alarms), a modified instance of a series
  (kept as the parent plus a child; the ship shows the moved one).
- A local change goes out as one insert, patch or delete. What was pulled is never pushed back, and neither is a local change Google's copy won over in a conflict. A patch sends only what the ship models, so guests, visibility and colors set on Google stay as they are.
- A calendar Google will not let you write (a holiday calendar, one shared with you read-only) logs each refused change as a conflict and moves on; later changes still go out.

## Conflicts

Changed on both sides between two syncs, or a push Google refused: Google's
copy wins and the local copy is kept as ICS in the conflict log (the panel
shows the count; Settings → Conflicts lists them with each local copy to
download, and clears the log; `GET /apps/calendar/google/conflicts.json`
and `POST /apps/calendar/google/conflicts/clear` do the same). The pull
knows its own push when it comes back (Google's `updated` stamp is the one
the push kept), so a local edit made since is not taken for a clash.

## Not synced

Attendees, invitations and Meet or other conference links (they stay on Google untouched), calendar sharing and ACLs, Google Tasks (a task in a Google-linked calendar stays on the ship; Google Calendar has no VTODO), colors beyond the calendar's own, and a local edit of a single instance of a Google series (the parent goes; the override child stays local).

## The gate

```
python3 scripts/fake-google.py 8092 &
python3 scripts/google-matrix.py http://127.0.0.1:8081 <cookie-jar> http://127.0.0.1:8092
```

The gate points the ship's Google client at the fake and unlinks every
Google calendar, so it refuses a ship with a real client set up.

Connect, link, remote add / delete / rename, local add / edit / delete each
pushed once, no echo, a moved instance, alarms both ways, a forced 410, a
forced conflict. The fake's control endpoint plays Google's side.
