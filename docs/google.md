# Google Calendar, two-way

Open **Settings → Google Calendar** in your system browser (or open the
Calendar page with `#google`). You bring your own OAuth client; the app has no
shared credential. Google rejects sign-in inside embedded app webviews.

**One account, several calendars:** Calendar currently keeps one Google
authorization. Link any calendars that account can access. Reconnecting with
another account replaces the authorization for every existing Google link;
it does not add an independent account. Do not connect three accounts in
sequence expecting three simultaneous authorizations. Native multi-account
support needs a backend change, not three Cloud projects.

## Making the client (once)

1. console.cloud.google.com → select or make a project. Keep the same project
   selected for API enablement and the OAuth client.
2. **APIs & Services → Library** → enable **Google Calendar API** (also listed
   in the Library's Google Workspace section). Confirm it is enabled. Creating
   a client does not enable this service; Gmail API and CalDAV API are not needed.
3. **Google Auth Platform → Branding** (previously **APIs & Services → OAuth
   consent screen**, which now opens Auth Platform's Overview) → app name and
   requested contact information. Under **Audience**, choose by the account
   that will perform OAuth. **Internal** requires that account to belong to
   the project's Workspace organization. Calendars shared with it may belong
   to personal Gmail or other organizations, subject to sharing policy.
   **External** is needed when the account signing in is outside the project's
   organization or is personal Gmail. For External Testing, add the connecting
   account to Test users; Calendar authorizations expire after seven days.
   For ongoing use, choose Internal when eligible, or **Publish app** for
   External so its status is *In production*, then reconnect. Publishing does
   not verify the app or override Workspace policy. Personal use may qualify
   for a verification exception; proceed through an unverified-app notice only
   if you recognize your own project and requested Calendar permissions.
   If Publish app is disabled with a link to Branding, finish and save its
   required fields first. Any homepage or policy links must describe your app.
4. **Google Auth Platform → Clients → Create client → Web application**
   (or **Credentials → Create credentials → OAuth client ID**).
   If a matching Web client is already saved on the ship, inspect and keep it
   instead of creating another.
   Under *Authorized redirect URIs* add exactly the URI the Google panel shows:
   `https://<your-host>/apps/calendar/google/callback`.
   Use **Copy redirect URI** in the panel. Include the whole path, HTTPS and
   no trailing slash; Authorized JavaScript origins is a different field.
5. Save the secret securely when Google creates it. The Console only shows or
   downloads it once; the client detail page later shows just its last four
   characters. If Calendar already has the matching secret saved, leave that
   field blank to retain it. If it is lost everywhere, follow Google's **Add
   secret** rotation flow and update the ship before retiring the old secret.
   Import the Web client's downloaded JSON, or paste its matching client ID
   and secret. Import validates the exact redirect URI and ignores endpoint
   URLs in the file. The file is read in the browser; only the client ID and
   secret are submitted to your ship when you save. Keep the file private.
   Press **Save and connect**.
   Google asks for consent, then sends you back; the panel lists your
   calendars. **Link** the ones you want on the ship.
6. Press **Sync now** and check each linked calendar's last successful sync
   and error. Compare an existing Google event with the ship. Authorization
   saved, a link created, and a sync requested are different stages;
   none alone proves that events have arrived.

Google's [web-server OAuth guide](https://developers.google.com/identity/protocols/oauth2/web-server),
[audience settings](https://support.google.com/cloud/answer/15549945) and
[personal-use exceptions](https://support.google.com/cloud/answer/13464323)
explain these requirements. Tokens can still expire or be revoked in
production; reconnect when necessary.

Google documents the one-time secret display under
[Manage OAuth clients](https://support.google.com/cloud/answer/15549257#client-secret-hashing).

### Connected, but Google answers HTTP 403

The released UI's **Connected** status means a refresh token is stored; it
does not prove Calendar API calls work. First check **APIs & Services → Library
→ Google Calendar API** in the same project as the client. Authorization and
API enablement are independent. If the API was disabled, enable it, allow
configuration to propagate, then use **Refresh calendar list** (or close and
reopen Settings on older versions). Keep the existing client and grant.
If it still fails, check granted Calendar permissions and Workspace policy;
403 can have several causes. Do not rotate secrets or repeatedly reconnect
different accounts merely to troubleshoot a disabled API.

A live setup checked on 2026-10-16 had a matching Web client and HTTPS
callback, and showed Connected, while Google Calendar API was disabled in
that client's project. After the owner enabled the API, connected and linked
a calendar, the released app imported existing events and recorded a
successful sync. The important distinction is authorization versus API
availability versus linked-calendar sync. This validates the setup diagnosis;
it is not an end-to-end test of the proposed onboarding changes.

The Console navigation and one-time secret display were checked on 2026-10-16.
**Branding**, **Audience**, **Clients**, and **Data Access** are now separate
sections of Google Auth Platform. The old OAuth consent screen link opens its
Overview; API enablement remains in APIs & Services.

The redirect URI the ship tells Google is the one the panel showed when you
saved: the page records the address it was opened at (`redirect_uri` in
`google.json`). A ship behind a TLS proxy sees its own requests as plain
http, and Google refuses an http redirect for anything but localhost, so
save the client from the address you want registered, `https://<your-host>`.
A `redirect_uri_mismatch` error from Google means the two differ: save again
from the right address, or change the URI registered for the client.
Calendar 31 fixed the proxy-related callback mismatch; update older installs
and save again. The preflight checks cannot verify Google's live configuration
or Workspace policy, so a locally valid client can still be refused by Google.

The refresh token lives in `google-auth.json` inside the calendar's own tree
and is never returned by the Calendar HTTP API. **Disconnect** forgets it on
the ship; revoke the grant in your Google account too to withdraw access at
Google. The ship and its backups remain part of the credential trust boundary.

### Use an Internal project with shared calendars

For an organization-owned project, **Google Auth Platform → Audience → Make
internal → Confirm** limits OAuth sign-in to that organization. This affects
all OAuth clients in the project, so check that no external users need to
sign in. Reconnect the same organization account from the ship afterward;
keep its saved client, calendar links and sharing permissions. In a live
setup on 2026-10-16, the Console then showed **Internal**, and the same account
could authorize access to its own calendar and calendars shared from other
organizations. Verify each link's last successful sync after reconnecting.

Internal avoids the specific External Testing seven-day refresh-token rule;
it does not guarantee that tokens can never expire or be revoked. Google
explains [refresh-token expiration](https://developers.google.com/identity/protocols/oauth2/#expiration).

## A work account (Google Workspace)

It links the same way; what works depends on what the company's admin
allows.

- **Directly.** Connect and sign in with the work account. A client made in
  a project inside the company's organization can be *Internal* (above).
  One made in a personal project needs the admin to allow it: many
  companies block apps they have not approved from reaching Calendar, and
  Google answers "Access blocked … by your admin". The admin can trust the
  client id in the admin console.
- **Through the connected account.** Share the work calendar with the
  Google address already connected to the ship only with its owner's permission and within the
  organization's policy. This discloses the calendar to that account. Use
  full event details, or edit rights for your
  changes to go back, then link it from the connected account; the panel
  lists every calendar an account can see. Companies often allow only
  free/busy outside the organization, and then there is nothing to read.
- **Not these.** The calendar's secret iCal address is often turned off in
  a company, and an ICS feed here skips repeating events. Following it over
  CalDAV does not work: Google's CalDAV needs an OAuth sign-in, and the
  follower signs in with a password.

Attendees, invitations and Meet links do not come across (see below), so a
meeting shows without its video link unless the link is in its
description.


### Give the connected account event-editing access

1. In Google Calendar, switch to the account that owns the calendar to add.
2. Open **Settings → Settings for my calendars → [calendar] → Shared with**.
   Confirm its Calendar ID identifies the intended calendar; its display name
   may be an old custom name rather than the account's email address.
3. Choose **Add people and groups** and enter the Google account already
   connected to the ship.
4. For two-way event management, select **Make changes and see all event
   details** (older interfaces call this **Make changes to events**). This
   grants reading, creation, editing and deletion, including private event
   details. **Make changes (see private events as free/busy)** does not expose
   private-event details. **Make changes and manage sharing** is broader than
   needed; it also allows changing who can access the calendar.
5. Review the recipient and permission and press **Send**. Workspace policy
   may restrict external sharing even when an option appears in the dialog.
6. Switch to the connected account and add the shared calendar to its calendar
   list using the invitation link, or **Other calendars → + → Subscribe to
   calendar**, then select the owner's email for their primary calendar.
   Confirm it appears in Google Calendar and shows the expected editor access.
7. Reopen the ship's Google settings (or **Refresh calendar list**), then
   **Link** the newly visible calendar and **Sync now**. Keep the same OAuth
   account; do not reconnect as the calendar's owner.
8. Check the successful sync time and existing events. When creating an event
   on the ship, choose the intended Google-linked calendar, not a local one.

This authorizes event management on the shared calendar. The integration's
limits on invitations, attendees, conference links and recurring-instance
edits still apply. See Google's
[calendar sharing guide](https://support.google.com/calendar/answer/37082).

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
