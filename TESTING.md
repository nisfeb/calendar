# Testing the calendar

The calendar is tested on its own fleet set from
[hoon-development](https://github.com/nisfeb/hoon-development), never on
`~ricsul-bilwyt`. Pushing to `main` is a release (docs/releasing.md), so
test here first.

| | |
|---|---|
| set | `calendar` (in hoon-development's `fleet/sets.conf`) |
| ship | `~rux`, fake, pier `~/fleet/piers/rux` |
| HTTP | http://localhost:8121 (loopback ames in `~/fleet/piers/rux/.http.ports`) |
| dojo | `tmux attach -t fleet`, window `rux` |
| grubbery | the dev platform's pin (hoon-development `platform/grubbery.ref`) |
| calendar | a dev desk at `/apps/shell.shell/desks/calendar.desk`, the same path as on ricsul, following `/calendar-dev/code` in the ball |
| test desk | `%calendar-test`, mounted, set up for the kit |

Below, `F=~/software/personal/hoon-development/fleet/fleet` and
`U=~/software/personal/hoon-development/bridge/u`. Set `FLEET_WHO` to
your session's name so claims know who is asking.

## Reset

```sh
$F reset calendar compiled   # calendar installed and approved, test desk set up: ~7 s
$F reset calendar            # golden: grubbery and %unix, no calendar
$F ls                        # is ~rux up?
$F up calendar               # restart it from its event log (vere 4.6 sometimes segfaults)
```

Start every test from `compiled`. Refresh it after a deploy that tests
should start from: `$F snap calendar compiled`. For a throwaway point,
`$F --fast snap calendar before-x` takes seconds.

## Offline tests (no ship)

The browser's Google setup validation and save/connect handlers can be tested
with Node.js, without credentials or a ship:

```sh
node tests/js/google-setup.test.cjs
node --check code/nex/calendar/calendar.js
```

These cover Web-client import, callback matching, endpoint exclusion, secret
reuse, failed saves, save-before-navigation and account-replacement cancellation.
They do not establish that Google's live consent or the Hoon sync backend works.
For the UI, open `/apps/calendar#google` in a browser, verify setup expands,
copy the callback, and check import failures and a refused save. Run the fake
Google gate and the normal release gates before shipping.

```sh
scripts/offline-tests.sh            # all five suites at once, ~90 s
scripts/offline-tests.sh ics rrule  # by name
python3 scripts/hoon-test-kit/offline-test.py tests/lib/rrule.hoon test-occurrences  # one arm
```

They run the suites in `tests/lib` through `vere eval` with the kit's
`offline-test.py`, taking `test.hoon` from the dev platform's `%base`. It
reads `hoon-test.conf`: with `DIALECT=grubbery` it follows the libs' `/<`
imports under `code/`, binds pytz's `/&` zone directory, and puts the
`PRELUDE` shims in every lib. The 599 zone files are most of each suite's
minute, so the wrapper runs the suites in parallel. The ship run is the
verdict.

## Ship tests

```sh
scripts/hoon-test-kit/hoon-test.sh ~/fleet/piers/rux          # every suite, ~10 s
scripts/hoon-test-kit/hoon-test.sh ~/fleet/piers/rux rrule    # one suite
```

The kit finds vere in `~/software`, so `VERE` need not be set.
`hoon-test.conf` names the libs and suites. On a fresh set (golden, or a
rebuilt pier) make the test desk once: `|new-desk %calendar-test` and
`|mount %calendar-test` in the dojo, then
`scripts/hoon-test-kit/hoon-test.sh ~/fleet/piers/rux setup`. The first
run after that builds pytz and takes about 90 s.

The HTTP gates in `scripts/` (README.md lists them) run against `~rux`
too. They write data, so reset afterwards. A cookie and a CalDAV client
password:

```sh
scripts/hoon-test-kit/ship-cookie.sh ~/fleet/piers/rux http://localhost:8121 /tmp/rux.jar
curl -s -b /tmp/rux.jar -H 'content-type: application/json' \
  -d '{"name":"gate"}' http://localhost:8121/apps/calendar/dav-clients   # {"password": ...}
python3 scripts/edge-matrix.py http://localhost:8121 /tmp/rux.jar rux <password>   # ~3 min
$F reset calendar compiled
```

`compiled` keeps the session the jar above was minted for, so the jar
works after a reset. `roundtrip.sh` needs events on the ship first (a
fresh `compiled` has none). The ship-to-ship gates (`caldav-client`,
`ship-share`, `cross`) need a second ship, which this set does not have;
the Google gates need `scripts/fake-google.py`, and the CalDAV ones
`scripts/dav-proxy.py` and a venv with `caldav` (docs/caldav.md).

## Deploying a change to ~rux

```sh
scripts/dev-deploy.py http://localhost:8121 /tmp/rux.jar
```

It writes the files of `code/` that differ into `/calendar-dev/code` and
stamps that tree's `version.json` with a dev version, which makes the desk
pull: about 30 s for a few files, 11 min for all 621. It refuses any ship
that is not on localhost. A release that adds a road needs approving
again: `--approve` posts the instance's own `weir.json` as `granted` to
`/apps/grubbery/permits` (`approve-weir`), then reloads its permits.
Without `granted` this kernel grants an empty weir.

How `compiled` was made, from the golden: `dev-deploy.py ... --add`
(which also POSTs `/apps/grubbery/desks/add`), then `--approve`, then the
test desk.

## Looking inside with u

```sh
$U calendar our
$U calendar kids /calendar-dev/code                     # files in a ball dir
$U calendar file /apps/shell.shell/desks/calendar.desk/version.json
$U calendar kids /apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app
```

`u` guards its subcommands. A raw `.^` in an expression that misses kills
every thread on the ship: check a path with `kids` first. Never point u,
the fleet commands or these scripts at a ship outside `calendar`.
