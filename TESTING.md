# Testing the calendar

The calendar is tested on two fleet sets from [hoon-development](https://github.com/nisfeb/hoon-development): `calendar`, and `calendar-pair` for the ship-to-ship gates (below). It is never tested on `~ricsul-bilwyt`. Pushing to `main` is a release (docs/releasing.md), so test here first.

| | |
|---|---|
| set | `calendar` (in hoon-development's `fleet/sets.conf`) |
| ship | `~rux`, fake, pier `~/fleet/piers/rux` |
| HTTP | http://localhost:8121 (the `public` line of `~/fleet/piers/rux/.http.ports`) |
| dojo | `tmux attach -t fleet`, window `rux` |
| grubbery | the dev platform's pin (hoon-development `platform/grubbery.ref`) |
| calendar | a dev desk at `/apps/shell.shell/desks/calendar.desk`, the same path as on ricsul, following `/calendar-dev/code` in the ball |
| test desk | `%calendar-test`, mounted, set up for the kit |

Below, `F=~/software/personal/hoon-development/fleet/fleet` and `U=~/software/personal/hoon-development/bridge/u`. Set `FLEET_WHO` to your session's name so claims know who is asking.

## Reset

```sh
$F reset calendar v33        # calendar 33 installed and approved, test desk set up
$F reset calendar            # golden: grubbery and %unix, no calendar
$F ls                        # is ~rux up? (calendar ... ~rux:up)
$F up calendar               # restart it from its event log (vere 4.6 sometimes segfaults)
```

The set's snapshots are `golden`, `v33` and `pre-trunk` (Talon calls, below). Start every test from `v33`, then deploy the candidate onto it (below). A point that tests should start from gets a snapshot of its own: `$F snap calendar <name>`. For a throwaway point, `$F --fast snap calendar before-x` takes seconds.

## Offline tests (no ship)

The Google panel's setup checks run in Node, with no ship:

```sh
node tests/js/google-setup.test.cjs
```

```sh
scripts/offline-tests.sh            # all six suites at once, ~90 s
scripts/offline-tests.sh ics rrule  # by name
python3 scripts/hoon-test-kit/offline-test.py tests/lib/rrule.hoon test-occurrences  # one arm
```

They run the suites in `tests/lib` through `vere eval` with the kit's `offline-test.py`, taking `test.hoon` from the dev platform's `%base`. It reads `hoon-test.conf`: with `DIALECT=grubbery` it follows the libs' `/<` imports under `code/`, binds pytz's `/&` zone directory, and puts the `PRELUDE` shims in every lib. The 599 zone files are most of each suite's minute, so the wrapper runs the suites in parallel. The ship run is the verdict.

## Ship tests

```sh
scripts/hoon-test-kit/hoon-test.sh ~/fleet/piers/rux          # every suite, ~10 s
scripts/hoon-test-kit/hoon-test.sh ~/fleet/piers/rux rrule    # one suite
```

The kit finds vere in `~/software`, so `VERE` need not be set. `hoon-test.conf` names the libs and suites. On a fresh set (golden, or a rebuilt pier) make the test desk once: `|new-desk %calendar-test` and `|mount %calendar-test` in the dojo, then `scripts/hoon-test-kit/hoon-test.sh ~/fleet/piers/rux setup`. The first run after that builds pytz and takes about 90 s.

The HTTP gates in `scripts/` (README.md lists them) run against `~rux` too. They write data, so reset afterwards. A cookie and a CalDAV client password:

```sh
scripts/hoon-test-kit/ship-cookie.sh ~/fleet/piers/rux http://localhost:8121 /tmp/rux.jar
curl -s -b /tmp/rux.jar -H 'content-type: application/json' \
  -d '{"name":"gate"}' http://localhost:8121/apps/calendar/dav-clients   # {"password": ...}
python3 scripts/edge-matrix.py http://localhost:8121 /tmp/rux.jar rux <password>   # ~3 min
$F reset calendar v33
```

A reset brings back the sessions the snapshot holds, so a jar minted after it stops working: mint a new one. Use `localhost` in every URL, since a jar minted for localhost is not sent to 127.0.0.1. `roundtrip.sh` imports its fixture first on a ship with no events. The ship-to-ship gates run on the pair below. The Google gates need `scripts/fake-google.py`, and the CalDAV ones `scripts/dav-proxy.py` and a venv with `caldav` (docs/caldav.md).

`weir-check.sh` and `quiet-check.sh` find the dojo's tmux pane from the king's terminal. If quiet-check cannot, name it: `QUIET_PANE=fleet:rux`.

## Deploying a change to ~rux

```sh
scripts/dev-deploy.py http://localhost:8121 /tmp/rux.jar
```

It writes the files of `code/` that differ into `/calendar-dev/code` and stamps that tree's `version.json` with a dev version, which makes the desk pull: about 30 s for a few files, 11 min for all 621. It refuses any ship that is not on localhost. A release that adds a road needs approving again: `--approve` posts the instance's own `weir.json` as `granted` to `/apps/grubbery/permits` (`approve-weir`), then reloads its permits. Without `granted` this kernel grants an empty weir.

How a calendar snapshot is made from the golden: `dev-deploy.py ... --add` (which also POSTs `/apps/grubbery/desks/add`), then `--approve`, then the test desk.

## Two ships: calendar-pair

The ship-to-ship gates (`ship-share-matrix.py`, `invite-matrix.py`, `caldav-client-matrix.py`, `cross-matrix.py`) need two ships, and run on the set `calendar-pair`.

| | |
|---|---|
| set | `calendar-pair` (in hoon-development's `fleet/sets.conf`) |
| ships | `~bes` and `~reb`, fake, piers `~/fleet/piers/bes` and `~/fleet/piers/reb` |
| HTTP | http://localhost:8138 (`~bes`) and http://localhost:8139 (`~reb`) |
| dojo | `tmux attach -t fleet`, windows `bes` and `reb` |
| snapshots | `golden` and `v33`, as for `calendar` |

```sh
$F reset calendar-pair v33
$F ls                        # calendar-pair ... ~bes:up ~reb:up
scripts/hoon-test-kit/ship-cookie.sh ~/fleet/piers/bes http://localhost:8138 /tmp/bes.jar
scripts/hoon-test-kit/ship-cookie.sh ~/fleet/piers/reb http://localhost:8139 /tmp/reb.jar
scripts/dev-deploy.py http://localhost:8138 /tmp/bes.jar
scripts/dev-deploy.py http://localhost:8139 /tmp/reb.jar
python3 scripts/invite-matrix.py http://localhost:8138 /tmp/bes.jar http://localhost:8139 /tmp/reb.jar ~bes ~reb
python3 scripts/ship-share-matrix.py http://localhost:8138 /tmp/bes.jar http://localhost:8139 /tmp/reb.jar ~reb
$F reset calendar-pair v33
```

The other two take the same URLs and jars; each script's docstring gives its arguments. For a mixed-version run, put the previous release on one ship (`dev-deploy.py --code`, docs/releasing.md §7).

## What no gate or suite covers

These work as far as anyone has looked by hand, but nothing here would catch them breaking:

- ICS feeds (`add-feed`, `sync-feeds`): only the `apply-feeds` unit test.
- A revoked CalDAV client password being refused: the gates revoke only while cleaning up, and none asserts a 401.
- Tasks: **Delete done older than a week**, and `GET /apps/calendar/tags.json`.
- Invitations: the inbox cap of 100 (with every row unanswered, a new invitation is dropped), the `invite-max` size refusal, and a copy never landing on an event of the guest's own.
- `lib/gcal`'s `parse-rfc3339`, `when-of`, `rid-of` and `json-of` have no tests of their own, and `lib/dav` has no suite (calendar-core's tests reach some of it).
- The fibers (the poke loop, the sync passes, the HTTP handlers, `rise-later`): only the gates reach them. The kit's `hoon/fiber-test.hoon` can drive a fiber in a unit test; nothing here uses it yet.

## Looking inside with u

```sh
$U calendar our
$U calendar kids /calendar-dev/code                     # files in a ball dir
$U calendar file /apps/shell.shell/desks/calendar.desk/version.json
$U calendar kids /apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app
```

`u` guards its subcommands. A raw `.^` in an expression that misses kills every thread on the ship: check a path with `kids` first. Never point u, the fleet commands or these scripts at a ship outside `calendar` and `calendar-pair`.

## Talon calls (talon-matrix.py)

`scripts/talon-matrix.py` needs %trunk at wire 19 on the test ship, which the fleet's platform does not install. On ~rux it went like this (2026-10-17), with trunk's own README ("The desk") for the trunk part:

1. Snapshot first: `$F --fast snap calendar pre-trunk`.
2. In the dojo `|mount %landscape`, `|new-desk %trunk`, `|mount %trunk`; copy trunk's `app lib mar sur gen desk.bill desk.docket-0` into the mount, plus the base and landscape files its README lists (the marks now include `css`); `|commit %trunk`, `|install our %trunk`. `/~/scry/trunk/version.json` then says 19.
3. Only then widen grubbery's trunk mark: copy trunk's `docs/grubbery-trunk-action.hoon` over both `grubbery/gub/mar/clay/trunk/trunk-action.hoon` and `grubbery/gub/mar/clay/trunk/trunk/action.hoon` in the pier, and `|commit %grubbery`.
4. A call server and the public address, as POSTs to `/apps/trunk/action`: `{"set-sfu":{"base":"http://127.0.0.1:8445","group":"talon","key":"<k>"}}` (a local Galène; trunk's session ran one) and `{"set-origin":"http://localhost:8121"}`.
5. Grant the calendar the peek road `/sys/gall/subs/~rux/trunk/app/grubbery/calendar/`: approve-weir at `/apps/grubbery/permits` with the instance's `weir.json` plus that road as `granted`, then `/apps/grubbery/permits/reload`.

The gate switches "calendar (through grubbery)" on and off itself. Return to the snapshot afterwards.
