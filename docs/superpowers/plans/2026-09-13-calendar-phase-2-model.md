# Calendar phase 2: the model

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the calendar the model both integrations need: several calendars, stable UIDs, ETags, a change log with tombstones, an RFC 5545 `rrule` kind, alarms as data, opaque property round-trip, an ICS writer, and an export/import pair that proves it.

**Architecture:** The stored noun becomes a tagged `[%2 ...]` calendar holding a map of calendars, each with entries keyed by UID, a change log and props. The `event` shape from phase 1 is kept unchanged inside an `entry` wrapper, so every codec, the inflation engine and the UI's window contract keep working. The mark's grab lifts the phase 1 noun on read. A new rule kind interprets RRULE text; the existing kinds stay as presets. The ICS library grows a writer; the nexus grows export and import routes.

**Tech Stack:** Hoon (grubbery nexus + fiber io), the existing rules engine, `pytz` for zones, `de-xml`/`en-xml` untouched until phase 3.

**Spec:** `docs/superpowers/specs/2026-09-13-calendar-sync-design.md`, section 4.

## Global Constraints

- The phase 1 noun must load: a ship upgrading from version 1 keeps every event, reminder and feed.
- `event` (lib/calendar) does not change shape. New data hangs on `entry`.
- No new roads in the ask. Everything here is local.
- `code/version.json` bumps to 2 in the last task, not before; subscribers re-sync only on the version change and must get the whole phase.
- Every task compiles on `~wex` before it is committed (write the changed files into the wex calendar desk's `desk/code`, reload the instance, watch the console for `nest-fail`/`mint-*`/`-find`, then `GET /apps/calendar/window.json`).

---

### Task 1: the v2 model and its lift

**Files:**
- Modify: `code/lib/calendar.hoon`
- Modify: `code/mar/calendar.hoon`
- Modify: `code/mar/calendar-cache.hoon` (types only if `ref` changes; it does not)

**Interfaces:**
- Produces: `uid`, `etag`, `alarm`, `props`, `entry`, `cal`, `cal-props`, `logent`, `calendar` (v2), `calendar-1` (the old shape), `lift` (any noun → v2), `entries-all` (v2 → `(map uid entry)`), `events-all` (v2 → `(map eid event)` for the inflation engine), `put-entry`, `del-entry`, `make-etag`, `next-seq`.

- [ ] **Step 1: types**

```hoon
+$  uid    @t
+$  etag   @t
+$  alarm  [trigger=$%([%rel before=@dr] [%abs at=@da]) desc=@t]
::  properties this app does not model, kept verbatim: [key-with-params value]
+$  props  (list [k=@t v=@t])
+$  entry  [=event =uid =etag seq=@ud alarms=(list alarm) =props]
+$  cal-props  [name=@t color=@t kind=?(%local %google) remote=(unit @t)]
+$  logent  [=uid kind=?(%put %del)]
+$  cal
  $:  props=cal-props
      entries=(map uid entry)
      log=((mop @ud logent) lth)
      seq=@ud
  ==
+$  calendar-1
  $:  title=@t  zone=(unit @t)  horizon=@dr  events=(map eid event)  ==
+$  calendar
  $:  %2
      title=@t
      zone=(unit @t)
      horizon=@dr
      cals=(map @ta cal)
  ==
++  on-log  ((on @ud logent) lth)
```

- [ ] **Step 2: lift and helpers**

```hoon
++  make-etag  |=(e=entry ^-(etag (scot %uw (sham [event.e alarms.e props.e]))))
++  lift
  |=  n=*
  ^-  calendar
  ?:  ?=([%2 *] n)  ;;(calendar n)
  =/  old=calendar-1  ;;(calendar-1 n)
  =/  base=cal  [['Calendar' '#1e3a5f' %local ~] ~ ~ 0]
  =/  c=cal
    %+  roll  ~(tap by events.old)
    |=  [[id=eid ev=event] acc=_base]
    (put-entry acc [ev id '' 0 ~ ~])
  [%2 title.old zone.old horizon.old (~(put by *(map @ta cal)) %default c)]
++  put-entry
  |=  [c=cal e=entry]
  ^-  cal
  =/  seq=@ud  +(seq.c)
  =.  e  e(seq seq)
  =.  e  e(etag (make-etag e))
  %_  c
    seq      seq
    entries  (~(put by entries.c) uid.e e)
    log      (put:on-log log.c seq [uid.e %put])
  ==
++  del-entry
  |=  [c=cal =uid]
  ^-  cal
  ?.  (~(has by entries.c) uid)  c
  =/  seq=@ud  +(seq.c)
  %_  c
    seq      seq
    entries  (~(del by entries.c) uid)
    log      (put:on-log log.c seq [uid %del])
  ==
++  events-all
  |=  c=calendar
  ^-  (map eid event)
  %-  ~(gas by *(map eid event))
  %-  zing
  %+  turn  ~(tap by cals.c)
  |=  [* k=cal]
  (turn ~(tap by entries.k) |=([u=uid e=entry] [u event.e]))
++  entries-all  (same shape, entry values)
++  fresh-calendar  `calendar`[%2 'Calendar' ~ (mul 3 ~d365) (~(put by *(map @ta cal)) %default [['Calendar' '#1e3a5f' %local ~] ~ ~ 0])]
```

Keep `event-json`, `calendar-json` (now over `events-all`), `inflate`, `window` unchanged.

- [ ] **Step 3: the mark lifts on grab**

`++  noun  |=(n=* (lift:^calendar n))` in `grab`. `grow` unchanged.

- [ ] **Step 4: compile on wex, then commit** with message "the model has calendars, uids, etags and a log; the phase 1 noun lifts".

### Task 2: the nexus speaks v2

**Files:**
- Modify: `code/nex/calendar/app.hoon`

- [ ] Every `!<(calendar:cal (need-vase ...))` becomes `(lift:cal (sang-noun:tarball sang))` guarded by `mole`. The cache fiber and the window route inflate over `(events-all:cal c)`.
- [ ] Pokes take an optional `cal` field, default `default`: `add-event` builds an `entry` (uid = `<eny>@<ship>`, from `get-our:io`), `edit-event`/`skip-event`/`cap-event` go through `put-entry` (etag and seq move), `del-event` through `del-entry`. `config` unchanged. New pokes `add-calendar {name color}` and `del-calendar {id}` (refuses `default`).
- [ ] `events.json` rows gain `cal`, `uid`, `etag`. New route `GET /apps/calendar/calendars.json`: id, props, seq per calendar.
- [ ] Compile on wex; add an event through the UI; the phase 1 events still show. Commit.

### Task 3: the rrule kind

**Files:**
- Create: `code/lib/rules/rrule.hoon`
- Create: `code/lib/rrule.hoon` (parser + period arithmetic, so the kind file stays a thin gate)
- Test: `code/tests/rrule.hoon` (unit tests over RFC 5545 §3.8.5.3 examples)

- [ ] `+$  rule  [freq=?(%daily %weekly %monthly %yearly) interval=@ud count=(unit @ud) until=(unit @da) byday=(list [ord=(unit @sd) day=wkd]) bymonthday=(list @ud) bymonth=(list @ud) wkst=wkd]` and `++  parse  |=(@t (unit rule))`.
- [ ] The kind: occurrence `idx` is closed-form per period: candidates per period = the BY-set applied to the start's period (sorted); `idx` → period `idx / n`, slot `idx mod n`; period `p` = start's period advanced `p * interval`; the slot's date in that period, or `~` if it does not exist (Feb 30, fifth Monday). `until` past → `~` (the walker's dead-run ends it). `count` is honoured by the caller through `bound.dom`, set at parse time.
- [ ] Register in `kind-table` as `%rrule`; args `{"rrule": "<text>"}`.
- [ ] Tests: daily interval 10 count 5; weekly BYDAY=TU,TH; monthly BYMONTHDAY=1,15; monthly BYDAY=-1FR; yearly BYMONTH=6 BYDAY=TH; the Feb 29 case. Run `-test %/tests/rrule` on wex. Commit.

### Task 4: the ICS writer and the fuller reader

**Files:**
- Modify: `code/lib/ics.hoon`

- [ ] Reader: `vevent` gains `description`, `dtstamp`, `sequence`, `alarms=(list alarm)` (VALARM blocks: TRIGGER relative or absolute, DESCRIPTION), `exdates=(list when)`, `props` (every other property, key with params and value, verbatim). Fold continuation lines is already there.
- [ ] `++  presets-to-rrule`: the phase 1 kinds by name and args → RRULE text (daily, weekly BYDAY, monthly BYMONTHDAY, monthly-nth BYDAY with ordinal, yearly, once → none, every → INTERVAL, cron → none, kept as `X-GRUBBERY-CRON`).
- [ ] `++  write-entry  |=([=entry zone=(unit @t)] tape)`: `BEGIN:VEVENT`, `UID`, `DTSTAMP`, `SEQUENCE`, `SUMMARY` from meta `name`, `LOCATION`/`DESCRIPTION` from meta, `DTSTART` (`;TZID=` local or `;VALUE=DATE`), `DTEND` or `DURATION`, `RRULE` (preset → text, or the rrule arg verbatim), `EXDATE` per `except` index realized through the kind, one `VALARM` per alarm, then `props` verbatim, `END:VEVENT`. Lines folded at 75 octets per RFC.
- [ ] `++  write-calendar  |=((list [entry (unit @t)]) @t)`: `BEGIN:VCALENDAR`, `VERSION:2.0`, `PRODID:-//nisfeb//calendar//EN`, the events, `END:VCALENDAR`. `VTIMEZONE` is deliberately not emitted in this phase (Olson `TZID` names only); phase 3's client matrix decides whether it is needed.
- [ ] `++  to-entry  |=([ve=vevent default-zone=(unit @t)] (unit entry))`: the reverse: `%allday` for `VALUE=DATE`, `%timed` otherwise, `once` when no RRULE, `rrule` kind when there is one, alarms and props carried.
- [ ] Unit tests: write then read a timed, an all-day, a recurring and an alarmed event; equal. Commit.

### Task 5: export and import routes

**Files:**
- Modify: `code/nex/calendar/app.hoon`

- [ ] `GET /apps/calendar/export.ics[?cal=id]`: `text/calendar`, `Content-Disposition: attachment`, all calendars or one.
- [ ] `POST /apps/calendar/import?cal=id` with an ICS body: each VEVENT → `to-entry` → `put-entry` (UID from the file; an existing UID is replaced). Answers `{imported, skipped}`.
- [ ] Gate script `scripts/roundtrip.sh HOST COOKIE`: export, create a calendar, import into it, export that one, compare the VEVENT blocks (order-insensitive, DTSTAMP stripped). Must be identical. Commit.

### Task 6: reminders read alarms

**Files:**
- Modify: `code/nex/calendar/app.hoon` (the reminders fiber)

- [ ] Due = events starting within `lead` (as today) plus every alarm whose trigger falls in `(from, now]`. One push per alarm, tag `cal-<uid>-<idx>-<n>`. Commit.

### Task 7: the UI knows about calendars

**Files:**
- Modify: `code/nex/calendar/calendar.js`, `calendar.html`

- [ ] A calendar selector in the add/edit form (default selected), the calendar's color on rows, `calendars.json` fetched at load, an Export link. Commit.

### Task 8: version 2

- [ ] `code/version.json` → 2. Push. wex re-syncs; the phase 1 events are still there; the gate script passes; feb (a subscriber of wex) follows and its carried events survive. Then the catalog entry goes into `dist/single-release`.
