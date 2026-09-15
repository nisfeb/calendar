# calendar

The grubbery calendar as its own stock desk. Installed from `~ricsul-bilwyt` like lattice and auspex.

- `code/` is the desk: the nexus at `code/nex/calendar/app.hoon`, its UI beside it, the rule kinds, ICS reader and timezone data under `code/lib`, the marks under `code/mar`.
- Design for CalDAV and two-way Google Calendar: `docs/superpowers/specs/2026-09-13-calendar-sync-design.md`.
- `code/version.json` is what replicates: a subscriber re-syncs only when it changes.
- Using it: `docs/using.md` (the settings screen, tags). Sharing and following over CalDAV: `docs/caldav.md`. Google, two-way: `docs/google.md`.
- Gates, all against `~wex`: `scripts/roundtrip.sh`, `scripts/dav-matrix.py` (through `scripts/dav-proxy.py`), `scripts/google-matrix.py` (against `scripts/fake-google.py`), `scripts/caldav-client-matrix.py` (ship to ship), `scripts/ship-share-matrix.py` (native @p sharing, ship to ship), `scripts/todo-matrix.py` (tasks: API, ICS, CalDAV), `scripts/cross-matrix.py` (tasks inside shared and followed calendars, and a Google calendar shared onward, ship to ship).
