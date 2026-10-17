# Google Calendar, two-way

Open **Settings → Google Calendar** on the calendar page, in a real browser: Google refuses sign-in inside an app's embedded webview. `/apps/calendar#google` opens the panel directly. You bring your own OAuth client. The app has no shared credential.

**One account, several calendars.** The ship keeps one Google sign-in. Link any calendars that account can reach, including calendars other accounts share with it (below). Connecting a different account replaces the sign-in for every linked calendar. It does not add a second one.

## Making the client (once, about five minutes)

Google's console moved the OAuth pages into **Google Auth platform** in 2025. Older guides that say "OAuth consent screen" or "Credentials → Create credentials" describe menus that no longer look that way.

1. At console.cloud.google.com, open the project picker at the top, press **New project**, give any name, and select the new project.
2. Menu → **APIs & Services → Library**, search **Google Calendar API**, press **Enable**.
3. Menu → **Google Auth platform** → **Get started**. App information: an app name and your email. Audience: **External** (or **Internal**, see below). Contact information: your email. Agree to the policy and press **Create**.
4. External only: open **Audience** and press **Publish app** so the status is *In production*. Left in *Testing*, Google lets the sign-in last only 7 days for Calendar access, and you would press Connect again every week. Published and unverified is fine for your own use: Google shows an "unverified app" warning at Connect, which you click through (**Advanced** → go to the app). A project inside a company's Google Workspace can choose *Internal* instead: no warning, no publishing, and the sign-in lasts.
5. Open **Clients** → **Create client**. Application type **Web application**. Under **Authorized redirect URIs** press **Add URI** and paste exactly the URI the Google panel shows: `https://<your-host>/apps/calendar/google/callback`. Press **Create**.
6. Google shows the client id and secret in a dialog, and the secret only this once. Import the client's downloaded JSON in the panel, or copy both into it, and press **Save and connect**. The import reads only the client id and secret, and refuses a file whose redirect URIs lack the panel's. If the dialog is already closed, open the client under **Clients** and press **Add secret** for a new one. Google asks for consent, then sends you back, and the panel lists your calendars. **Link** the ones you want on the ship.

The redirect URI the ship tells Google is the one the panel showed when you
saved: the page records the address it was opened at (`redirect_uri` in
`google.json`). A ship behind a TLS proxy sees its own requests as plain
http, and Google refuses an http redirect for anything but localhost, so
save the client from the address you want registered, `https://<your-host>`.
A `redirect_uri_mismatch` error from Google means the two differ: save again
from the right address, or change the URI registered for the client.

A stored sign-in does not prove the Calendar API answers. If the calendar list says Google answered 403, check that **Google Calendar API** is enabled in the same project as the client, then press **Refresh calendar list**. Keep the client and the sign-in you have. If it still fails, check the Calendar permissions granted and the Workspace admin's app policy.

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
- **Several accounts through one.** The same trick gathers all your calendars under the account the ship signs in with. In the account that owns a calendar, open **Settings for my calendars → the calendar → Shared with → Add people and groups**, give the connected account **Make changes and see all event details**, and send. In the connected account, add the calendar from the invitation. Then press **Refresh calendar list** here and **Link** it.
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
