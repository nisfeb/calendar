# Hoon unit tests

The pure libs (`lib/rrule`, `lib/rules`, `lib/ics`, `lib/calendar`, the
rule kinds, and `lib/pytz` under them) have unit suites in `tests/lib/`,
run with [hoon-test-kit](https://github.com/nisfeb/hoon-test-kit) on a
fake ship in about 10 seconds. The nexus (`nex/calendar/app.hoon`) is not
unit-tested: its behaviour is covered by the gates in `scripts/`.

## Running

Once per ship, in its dojo (the owner runs these):

```
|new-desk %calendar-test
|mount %calendar-test
```

then, from the repo:

```sh
scripts/hoon-test-kit/hoon-test.sh <pier> setup    # lib/test and the marks, from %base
scripts/hoon-test-kit/hoon-test.sh <pier>          # every suite
scripts/hoon-test-kit/hoon-test.sh <pier> rrule    # one
```

Each test prints `OK`, `FAILED` (with expected and actual) or `CRASHED`.
The first run builds `lib/pytz` with its 599 zone files, one `/*` each,
and takes a minute or two; later runs take about 10 s.

`hoon-test.conf` sets `DIALECT=grubbery`: the libs import each other with
grubbery's `/<` and pytz reads its zones with `/&`, which clay's ford does
not know, so the kit translates them on the way to the test desk.
`tests/shim/tarball.hoon` stands in for grubbery's `tarball` (the libs
only use its `rail`).

## What the suites hold

- `rrule`: what an RRULE reads as, occurrences (weekly, the 31st as a
  dead slot, UNTIL inclusive and in all its forms, the fifth weekday,
  negative BYMONTHDAY, BYMONTH/BYDAY/BYMONTHDAY limiting DAILY, a YEARLY
  rule starting on its start), COUNT as occurrences, and every cap as a
  pair: 1024 bytes of text, the BY-list lengths, COUNT and an index at
  `max-idx`.
- `ics`: folding and unfolding (line lengths, round trips up to 100 KB,
  UTF-8 never split, tab and space continuations), a COUNT from a file
  capped, DURATION and date edges, the retired cron preset as RRULE, and
  what an export leaves out (grubbery's bookkeeping, every `X-GOOGLE-*`,
  a done task's stale STATUS).
- `calendar`: what the occurrence cache is current for (zone and horizon
  in, title out), a date event's years and their cap, a once event, a
  COUNT bound and `thru` met exactly, and window edges.

## Mutation run, 2026-09-25

`hoon-mutate.py`, default ops (`boundary,conjunct`), 75 mutants over the
five libs. The first suite (17 tests) killed 17 and let 48 survive; 9 were
no-builds (tall `?&`/`?|` conditions split across lines, expected) and one
timed out (`fold` looping forever, which counts as caught).

Writing the suites found one real bug before any mutant ran: `FREQ=weekly`
was refused, because `+parse` upper-cased keys but not values (RFC 5545
3.1: enumerated values are case-insensitive). Fixed.

The real gaps were closed with 11 tests (the suites now hold 28), and
`--only` on those arms proves it: every mutant there is killed, a no-build,
or one of the equivalents below.

### Equivalent survivors, and why

- `da-to-ms` at exactly 1970-01-01: both branches give 0.
- `weekday` at exactly `~2000.1.1`: both branches give Saturday.
- `sort-days` tie: equal days sort the same either way.
- `monthly` and `yearly` slot guard (`gte (mod g n) (lent cand)`): every
  period has the same slots, so the index is always below the length;
  the guard is defensive.
- `nth-of-month`, a negative ordinal at exactly `7 * (n-1)`: the day it
  would give is 0, which `on-date` refuses anyway.
- `walk-recur` and `count-dom` dead-run caps (`gth dead 400`): they bound
  cost, not the answer; a rule with exactly 400 empty slots before a live
  one cannot be written with the supported BY-parts.
- `window` left-scan pre-filter: the final filter decides.
- `to-entry`, an end equal to the start: both give one day, and 0 s.
- `fold`'s back-off bounds: only reachable with invalid UTF-8.
- `to-entry`'s two `same-rule` disjuncts: for a rule that parses, either
  one alone decides (a legacy import path for retired presets).
- `limits`, BYMONTHDAY applied to more than DAILY: a MONTHLY or YEARLY
  rule's candidates are already those days, and RFC 5545 does not allow
  BYMONTHDAY with WEEKLY.
- `lib/pytz` (three): a vendored port; its boundaries sit on exact
  transition instants. Left untested here.
