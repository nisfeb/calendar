# Google Calendar, two-way

Press **Google** on the calendar page. You bring your own OAuth client; the
app has no shared credential.

## Making the client (once, about five minutes)

1. console.cloud.google.com → make a project (any name).
2. **APIs & Services → Library** → enable **Google Calendar API**.
3. **APIs & Services → OAuth consent screen** → External → app name and your
   email → add yourself under **Test users**. It can stay in Testing.
4. **Credentials → Create credentials → OAuth client ID → Web application**.
   Under *Authorized redirect URIs* add exactly the URI the Google panel shows:
   `https://<your-host>/apps/calendar/google/callback`.
5. Paste the client id and secret into the panel, **Save**, then **Connect**.
   Google asks for consent, then sends you back; the panel lists your
   calendars. **Link** the ones you want on the ship.

The refresh token lives in `google-auth.json` inside the calendar's own tree
and nowhere else. **Disconnect** forgets it.

## What syncs

- Every `tick_min` minutes (default 5), on **Sync now**, and right after a
  local change: the linked calendar is pulled with a sync token (a full
  listing when Google says the token expired) and local changes since the
  last push go out.
- Events map by iCalendar UID. Timed, all-day, recurring (RRULE, EXDATE),
  reminders (popup/email minutes ↔ alarms), a modified instance of a series
  (kept as the parent plus a child; the ship shows the moved one).
- A local change goes out as one insert, update or delete. What was pulled is
  never pushed back.

## Conflicts

Changed on both sides between two syncs, or a push Google refused: Google's
copy wins and the local copy is kept as ICS in the conflict log (the panel
shows the count; `GET /apps/calendar/google/conflicts.json` lists them,
`POST /apps/calendar/google/conflicts/clear` empties it).

## Not synced

Attendees and invitations, calendar sharing and ACLs, Google Tasks (a task
in a Google-linked calendar stays on the ship; Google Calendar has no VTODO), colors
beyond the calendar's own, a local edit of a single instance of a Google
series (the parent goes; the override child stays local).

## The gate

```
python3 scripts/fake-google.py 8092 &
python3 scripts/google-matrix.py http://127.0.0.1:8081 <cookie-jar> http://127.0.0.1:8092
```

Connect, link, remote add / delete / rename, local add / edit / delete each
pushed once, no echo, a moved instance, alarms both ways, a forced 410, a
forced conflict. The fake's control endpoint plays Google's side.
