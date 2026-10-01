# Logging: what the calendar prints, and what it records instead

The calendar follows the Foundation's Logging Management Policy (draft of
2026-10-01): a healthy calendar prints nothing; a line on the console means
something left its normal range and a person can act on it; everything else
is kept as state that can be read back. This file is the calendar's side of
that: the lines it can print, the records it keeps, the audit that got it
there, and the gate that holds it.

## What the calendar can print

Every line begins `calendar: `, so `grep 'calendar: '` over a console
transcript finds all of them and nothing else. There are three.

| Marker | Line | When | What to do |
|---|---|---|---|
| `>>>` | `calendar: <what>; <remedy> (<key> in outcomes.json)` | A fault a person must act on begins: Google or a followed calendar refuses the ship's sign-in or its changes (a 4xx other than a rate limit), or the web road alone is refused. Once, when the record is first written, or when a fault that was nobody's to act on becomes one. | The remedy is in the line. |
| `>>` | the same shape | A fault that degrades without stopping: the share inbox road not laid, a Google listing cut at 500 pages, a remote listing that left out the calendar. Once. | The remedy is in the line. |
| `>` | `calendar: <key> cleared` | A fault the console had heard of has cleared. | Nothing. |

Nothing prints on a success, on a routine change (a share offered, a
calendar resynced), per item of a set, or per retry while a fault stands.

Two things are the kernel's to say, and the calendar adds a record and no
second line (grubbery `dist/single-release` from 5ae72f0):

- **A crash.** The kernel prints every fiber crash with its trace
  (`%fiber-crash <path> in=<input>`). The calendar's restart helper counts
  it in `rise.json`, with the next try, and prints nothing.
- **A refused road a fiber waits on.** The kernel parks the fiber and
  prints one line for the app: `grubbery: <app> is parked: it may not
  poke <road>; grant it at /apps/grubbery/permits, then reload`. The
  calendar records `road/behn` or `road/bowl` with what stopped.

A refused road that parks nothing is the calendar's to say, since the
kernel is silent on a refusal an app takes softly. That is `road/inbox`
(the share inbox roads) and `road/eyre`: the kernel's web bind swallows a
refusal, so with `/sys/eyre/` alone refused the page and CalDAV stop
answering and nothing else would speak. When the timer or the clock is
refused as well, as on a fresh install that is refused everything, the
kernel's parked line covers the app and `road/eyre` is recorded only.

## What it records, and where to read it

| Record | Holds | Bound | Read it |
|---|---|---|---|
| `outcomes.json`, `faults` | The conditions that stand now, by key: `{since_ms, last_ms, count, level, said, what, remedy}`. Removed when the condition clears. | 50 keys; a full map drops its stalest for a new one. Keys are per condition and calendar, never per object. | `GET /apps/calendar/outcomes.json`; Settings, Faults and refusals; the grub in the explorer. |
| `outcomes.json`, `refusals` | The last refused pokes: `{at_ms, action, id, from, why}`. A poke is acknowledged before it is read, so its refusal has no other way back to the client. | 20 rows, the oldest dropped. | The same. |
| `rise.json` | Per fiber: crashes in a row, the last one's time, the next try. Counted even with the clock refused, then without times. | One row per fiber. | The grub in the explorer. |
| `google-conflicts.json` | Edits the other side won, with this ship's copy. | 500 rows, one per calendar and object. | Settings, Conflicts; `GET /apps/calendar/conflicts.json`. |
| The kernel's bang on a grub | A fiber the kernel parked: a dart refused by the weir on a road the calendar does not ask softly (`/sys/push/`, `/sys/iris/`, `/sys/eyre/`), or a nexus that did not build. | One per grub. | The instance's `?info=1`; the explorer. |

Fault keys: `google-auth`, `google-pull/<cal>`, `google-pages/<cal>`,
`google-push/<cal>`, `caldav-list/<cal>`, `caldav-get/<cal>`,
`caldav-push/<cal>`, `share-push/<cal>`, `road/behn`, `road/bowl`,
`road/eyre`, `road/inbox`.

A fault a person can do nothing about is recorded and not printed: a remote
that does not answer or answers 5xx, a rate limit (429), a host ship that
is offline, objects a pass could not fetch. It prints later only if it
becomes someone's to act on, which is a refusal (any other 4xx).

Messages carry a calendar's id, an HTTP status and fixed words. They never
carry an event's content, a URL (it may hold credentials), a token, or a raw
noun or tang.

## Debug output

There is none, so there is no `++ dbg`. The audit found no print whose only
reader is someone debugging: every site was a success line (deleted), a
fault (recorded), or a refusal (recorded). A flag with no readers would be
dead code; the first diagnostic print anyone adds brings the flag with it,
defined in the helper core of `nex/calendar/app.hoon`, which the nexus core
above it can see.

## The audit, 2026-10-01

Thirty-nine print sites: 37 in `nex/calendar/app.hoon` (23 at `>>>`, 2 at
`>>`, 7 at `>`, 2 conditional, 3 unmarked) and 2 in `lib/pytz.hoon`.

| Was | Sites | Now |
|---|---|---|
| `>>>` on every refused poke: a bad or refused add, edit or split, an id taken | 9 | No line. The reason goes to `outcomes.json` `refusals`. |
| `>>>` raw noun on every share edit refused to a peer | 1 | No line. The peer is told as before (the queued refusal); the host's ring records it with the ship. |
| `>>` raw noun per conflicting object | 1 | No line. `google-conflicts.json` was already the record. |
| `>` on a share's mode change, an offer, a revoke, a dropped share | 4 | Deleted: routine, and `shares.json` holds each. |
| `>` on a Google resync after a 410 | 1 | Deleted: a normal recovery. |
| `>` feed sync "fetching" and "N synced", `>>>` per failed feed | 3 | Deleted: the sync is a request and its answer names what failed. |
| `>` "timezones were successfully loaded!" and its commented twin in `lib/pytz` | 2 | Deleted. |
| `>>>` raw noun every pass while Google's token refresh, a pull, or a push fails (the push stop twice) | 5 | A fault per condition and calendar. One line when it begins, only for a 4xx; cleared by the first pass that works. |
| `>>>` raw noun every pass for a CalDAV listing failure or an incomplete listing, with the URL | 2 | The same; no URL in the line. |
| `>>>` raw noun per object for a CalDAV fetch that times out or fails, with the href | 2 | One counted fault per calendar, not printed. |
| `>>>` raw noun every pass while a CalDAV push or a push to a host ship stops | 3 | A fault per calendar; printed for a 401, recorded otherwise. |
| `>>>` a raw tang when a host ship nacks a poke | 1 | Deleted: the push that failed records `share-push/<cal>`. |
| `>>` on every reload while the registry or the inbox road is refused | 2 | The `road/inbox` fault, one `>>` line with the permit to grant. |
| Unmarked: the first two crashes of a streak with their traces, then a line per crash | 1 | No line: the kernel prints each crash with its trace, and the calendar's would be the same cause twice. `rise.json` counts them. |
| Unmarked: "no clock (weir?)" and "no timer (weir?)", per fiber, only after a crash | 2 | No line: the road faults below, and a crash with no clock is still counted in `rise.json`. |

Two failures printed nothing and recorded nothing, which the policy
counts as a defect as much as noise.

A refused timer or clock road on a clean start. Measured on `~nec` (kernel
785d015) with `/sys/behn/` refused and the instance reloaded: 144 console
lines, none from the calendar and no calendar record; reminders and
syncing had simply stopped. Now the main fiber, which needs neither road,
asks both softly at start (`+check-roads`) and records `road/behn` or
`road/bowl` with what stopped; the console line is the kernel's. Measured
again with the quiet-console kernel: the same refusal and reload put
three lines on the console, none the calendar's (the kernel's one parked
line, with two fibers parked; `%sand-applied`; eyre's binding line), and
the record in `outcomes.json`.

A refused web road. The kernel's bind used to say `bind-http-self: vetoed`
and, in the quiet-console release, says nothing; no fiber waits on that
road, so nothing parks. The main fiber now makes the bind itself, softly
(`+soft-bind`), records `road/eyre`, and prints the one `>>>` line when
that road alone is refused.

## Known noise

Lines the calendar does not write, seen on the console while its gate
runs. They are the kernel's or a vane's; the quiet gate names and counts
them and does not fail on them. As of grubbery `dist/single-release`
5ae72f0:

| Line | From | When |
|---|---|---|
| `>>> "grubbery: <app> is parked: it may not <poke> <road>; grant it at /apps/grubbery/permits, then reload"` | grubbery | A fiber parks on a refused road: once per app while any of its fibers is parked. |
| `%fiber-crash <path> in=<input>` and the trace, unmarked | grubbery | Every fiber crash. |
| `BANG nexus <path>` and the error, unmarked | grubbery | A nexus that does not build, when the fault begins. |
| `> [%sand-applied dest=...]` | grubbery | A permit granted or removed: one line per change, the operator's own act. |
| `> [%desk-instance-reloaded ...]` | grubbery's desk nexus | A release reloads the instance. |
| `>> [%desk-source-unreachable ...]` | grubbery's desk nexus | A desk whose source does not answer, on the first failure. |
| `eyre: replacing existing binding at /apps/calendar` | eyre | Every reload of the instance. |

Before that release the kernel printed two multi-line `>>>` nouns
(`%weir-veto-at`, `%process-dart-vetoed`) for every refused dart and the
whole weir on every permit change; those are behind its debug flag now.

## The quiet gate

`scripts/quiet-check.sh <pier> <ship-url> <cookie-jar> [files ...]`
captures the ship's console and takes the calendar through the policy's
gate on a test ship. It needs a kernel with the quiet console.

1. Reload: the calendar prints nothing.
2. Upgrade, when files are given (through `upgrade-check.sh`, from the
   release the ship holds, with its data): nothing.
3. Refuse `/sys/behn/` and reload: exactly one line about it, the
   kernel's for the parked app, naming the permits page; no calendar
   line; `road/behn` in `outcomes.json`.
4. Grant it and reload: the record is gone, and the calendar prints
   nothing.
5. Refuse `/sys/eyre/` and reload: nothing parks, so the one line is the
   calendar's, naming the permits page; `road/eyre` recorded.
6. Grant it and reload: the record is gone, with the one `cleared` notice.

It joins the release checklist in `docs/releasing.md` beside the weir
check. The other gates hold the records: `edge-matrix.py` and
`todo-matrix.py` read refused pokes' reasons back from `outcomes.json`,
and `google-matrix.py` checks that a push Google does not take stands as
a fault, unsaid, and clears when a pass goes through. A fresh install is
the policy's first step; on a test ship that already holds the calendar,
the reload stands in for it. The gate counts as the calendar's any line in
the convention and any in the old style (a `%calendar-...` noun), so a
print that skips the convention fails it too.

In review: a change that adds a print says its level and why the fact is
not a record instead; a print on a success path or inside a loop over data
is refused.

## Open questions, for the policy's review

- The kernel's crash line is unmarked, which the policy's table reads as
  debug level, and it prints on every crash of a fiber that keeps
  crashing. The calendar defers to it rather than print a second line;
  whether a crash is a warning, said once per streak, is the kernel's
  audit to settle. The calendar's `rise.json` already holds the count.
- The `cleared` notice is printed for faults the console heard of. The
  policy allows it and does not require it.
- `outcomes.json` is the calendar's own path and shape. If the Foundation
  settles on one standard fault record for every app, it moves there.
- A refused road has two records: the kernel's bang on each parked grub
  and the calendar's `road/...` fault. They say different things (what was
  refused; what stopped), and the Settings page can only show the second.
  One standard fault record would let it show both.
- The kernel's web bind is silent on a refusal, so each app that serves a
  page has to notice it for itself, as the calendar now does. A kernel
  line for "an app's only web binding was refused" would cover them all.
