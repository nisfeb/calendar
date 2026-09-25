# calendar

The grubbery calendar as its own stock desk. Installed from `~ricsul-bilwyt` like lattice and auspex.

- `code/` is the desk: the nexus at `code/nex/calendar/app.hoon`, its UI beside it, the rule kinds, ICS reader and timezone data under `code/lib`, the marks under `code/mar`.
- Design for CalDAV and two-way Google Calendar: `docs/superpowers/specs/2026-09-13-calendar-sync-design.md`.
- `code/version.json` is what replicates: a subscriber re-syncs only when it changes.
- Recovering a ship wedged by an unapproved install (versions 18-19 could lock the ship): `docs/wedged-ship.md`, with `scripts/unwedge.sh` to run it. Fetch the script straight from GitHub, since a wedged ship cannot pull a desk update.
- Using it: `docs/using.md` (the settings screen, tags). Sharing and following over CalDAV: `docs/caldav.md`. Google, two-way: `docs/google.md`.
- Unit tests for the libs: `tests/lib/`, run in seconds with the vendored `scripts/hoon-test-kit` (`docs/hoon-testing.md`).
- Gates, all against `~wex`: `scripts/roundtrip.sh` (export stable through import, and the fixture's own lines kept), `scripts/dav-matrix.py` (through `scripts/dav-proxy.py`), `scripts/google-matrix.py` (against `scripts/fake-google.py`), `scripts/caldav-client-matrix.py` (ship to ship), `scripts/ship-share-matrix.py` (native @p sharing, ship to ship), `scripts/todo-matrix.py` (tasks: API, ICS, CalDAV), `scripts/cross-matrix.py` (tasks inside shared and followed calendars, and a Google calendar shared onward, ship to ship), `scripts/edge-matrix.py` (repeats as RRULEs, the same UID in two calendars, sync tokens, CalDAV name aliases, cancelled events, UTC UNTIL, RRULE slots and COUNT, zones in EXDATE and RECURRENCE-ID, DST gaps, alarm offsets, DAV preconditions, skip undo, splitting a series). The Google gates (`google-matrix.py`, and `cross-matrix.py` with a fake URL) refuse a ship that has a real Google client set up.
