# A ship wedged by the calendar

Versions 18 and 19 could lock a ship whose calendar was installed but never
approved on the Permits page. Version 20 cannot. This is what happens, how to
tell, and how to get a ship back.

## What happens

A desk app is born sandboxed: an empty weir, permitting nothing, until its
declared roads are approved in the shell. The calendar's first act in every
fiber is a poke to `/sys/bowl.sig` for the time and our ship. On a sandboxed
install that poke is vetoed, the fiber fails, and grubbery restarts a failed
fiber at once, inside the same event. In 18 and 19 the restart path made the
same hard poke again, so the event never ends: the serf sits at 100% CPU, the
console prints `vetoed node operation ... bowl.sig` forever, HTTP stops
answering, and the event log stops advancing.

The event that spins is the one delivering the update from `~ricsul-bilwyt`.
It never commits, so the desk stays on the old version, and ames retransmits
the message every few seconds, so a restart of the ship lands in the same
loop within a minute. `|suspend` and `|revive` do not help for the same
reason. Version 20 parks the fiber instead of retrying, so once a ship has 20
a refused road costs a feature, not the ship.

## How to tell

- `top`: the ship's `work` process at 100% for minutes.
- The console: `%calendar main: failed` and `vetoed node operation on wire
  /sys/eny dest ... bowl.sig` repeating.
- The web UI does not load; a request to `/apps/calendar` never answers.
- If you can read it, the desk's `code/version.json` says 17, 18 or 19.

## Recovery

Two things have to happen: the spinning event has to be interrupted, and the
calendar's roads have to be granted before the update can land. Nothing else
works: a restart replays the loop, and the update cannot be skipped.

The ship must be attached, because ^C in the dojo is the only way to abort a
running event (`kill -INT` on the process does nothing). If it runs detached,
stop it and start it again inside tmux for the occasion.

### With the script

On the host that runs the ship:

```
scripts/unwedge.sh <pier> <tmux-pane> <http-port> <login-code>
```

It sends ^C whenever the serf has been pegged for two seconds, logs in and
grants each declared road through the explorer in the gaps, then stops
interrupting and waits for the desk to report version 20. Rerunning it is
safe. Get the login code with `+code` in the dojo; the line may take a few
interrupts to be answered.

### By hand

1. Press ^C in the dojo. The console prints `interrupt`; the loop comes back
   within seconds, so keep pressing it every few seconds throughout step 2.
2. In another terminal, log in and grant the roads:

```
curl -c jar -X POST http://localhost:8080/~/login --data-urlencode password=<code>
for r in /sys/bowl.sig /sys/eyre/ /sys/behn/ /sys/push/ /sys/iris/ /sys/gall/ /sys/ames/registry /sys/ames/usergroups/; do
  curl -b jar -X POST 'http://localhost:8080/grubbery/ball/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app' \
    --data-urlencode action=add-weir-road --data-urlencode category=poke --data-urlencode road-path=$r
done
```

   Each request waits in the ship's queue until a ^C lets it through. The
   poke roads are enough to stop the loop; the Permits page can grant the
   rest afterwards.
3. Stop pressing ^C. The next retransmit builds and rises; a few minutes
   later `code/version.json` reads 20 and `/apps/calendar` answers.

Do not use the Permits page's approve for step 2 while the ship is looping:
the page needs several round trips, and a POST to `/apps/grubbery/permits`
without a `granted` object replaces the weir with an empty one.

## Keeping it from happening again

The calendar side is fixed in version 20. The class of bug is grubbery's: a
fiber that fails is restarted immediately and without limit inside one event,
so any deterministic failure on rise is an infinite loop. A cap on restarts
per event, after which the fiber is parked and the failure printed once,
would make every app's crash a dead feature instead of a dead ship.
