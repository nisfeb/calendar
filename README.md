# calendar

The grubbery calendar as its own stock desk. Installed from `~ricsul-bilwyt` like lattice and auspex.

- `code/` is the desk: the nexus at `code/nex/calendar/app.hoon`, its UI beside it, the rule kinds, ICS reader and timezone data under `code/lib`, the marks under `code/mar`.
- Design for CalDAV and two-way Google Calendar: `docs/superpowers/specs/2026-09-13-calendar-sync-design.md`.
- `code/version.json` is what replicates: a subscriber re-syncs only when it changes.
