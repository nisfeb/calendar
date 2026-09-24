::  rules: typed recurrence rules
::
::  A rule is a clock: it ticks at moments. An event is a clock plus
::  how long each tick lasts (extent), in what time-frame (frame),
::  over what range (start..dom, except). Those four axes are
::  orthogonal — the kind knows nothing of them.
::
::  A kind lives as a file in the namespace (/lib/rules/<name>.hoon)
::  and is a pure point generator: [args start idx] -> the naive
::  local left-moment of occurrence idx, or ~ if that index has no
::  occurrence (april 31st, non-leap feb 29). start anchors idx 0.
::  Occurrence n is closed-form in n — no iterating, no materialized
::  schedules.
::
::  lib/calendar dresses each tick into UTC spans: an all-day tick is
::  a calendar day, never zone-shifted; a timed one is a wall-clock
::  moment placed through pytz (zone=~ is UTC), +place.
::
::  Skipping an occurrence adds its index to except=; moving one is a
::  skip plus a separate %once event. Zone names are pytz names
::  ('America/New_York'); an unknown name crashes, so validate at
::  write time.
::
/<  pytz  /lib/pytz.hoon
|%
::  +known-zone: a name pytz has; an unknown one would crash the walker
++  known-zone  has-zone:pytz
+$  wkd   ?(%mon %tue %wed %thu %fri %sat %sun)
+$  span  [l=@da r=@da]
::
::  a kind is a clock: idx -> a naive local moment, nothing else.
::  start anchors idx 0. ~ = this index has no occurrence (april
::  31st, non-leap feb 29). args is a json object (self-describing,
::  never a raw noun); the kind reads its own args by key via +ja,
::  so the kind file is the single source of truth for its params.
::  The event layer (lib/calendar) dresses each moment with a shape.
::
+$  kind  $-([args=(map @t json) start=@da idx=@ud] (unit @da))
::  +ja: typed reads from a json-arg map, via jo:json-utils + dejs.
::  Missing key -> zero of the type. Wrong-typed value crashes into
::  the caller's mole — the event goes quiet rather than lying.
::
++  ja
  |_  args=(map @t json)
  ++  dug   |*([k=@t de=$-(json *) fel=*] (fall (bind (~(get by args) k) de) fel))
  ++  wkdp  (su:dejs:format (perk %mon %tue %wed %thu %fri %sat %sun ~))
  ++  num   |=(k=@t ^-(@ud (dug k ni:dejs:format 0)))
  ::  a time-of-day arg is either minutes after midnight (480) or a
  ::  clock string ("08:00")
  ++  mins
    |=  k=@t
    ^-  @dr
    =/  j=(unit json)  (~(get by args) k)
    ?:  ?=([~ %s *] j)
      =/  hm=(unit [h=@ud m=@ud])
        (rush p.u.j ;~(plug dem ;~(pfix col dem)))
      ?~  hm  ~s0
      (add (mul h.u.hm ~h1) (mul m.u.hm ~m1))
    (mul (num k) ~m1)
  ++  str   |=(k=@t ^-(@t (dug k so:dejs:format '')))
  ++  wkds  |=(k=@t ^-((list wkd) (dug k (ar:dejs:format wkdp) ~)))
  ++  nums  |=(k=@t ^-((list @ud) (dug k (ar:dejs:format ni:dejs:format) ~)))
  --
::  +realize: all UTC instants of a wall-clock instant. UTC (zone=~)
::  has exactly one; zoned gets every valid pytz conversion (none in
::  a DST gap, two in an overlap).
::
++  realize
  |=  [zone=(unit @t) local=@da]
  ^-  (list @da)
  ?~  zone  ~[local]
  (~(tz-to-utc-list zn:pytz u.zone) local)
::  +place: the one instant a wall-clock moment stands for (RFC 5545
::  3.3.5): the first of two in a fall-back overlap, and in a
::  spring-forward gap the offset from before it, so 02:30 on a skipped
::  hour is 03:30. ~ when the zone cannot place it at all.
++  place
  |=  [zone=(unit @t) local=@da]
  ^-  (unit @da)
  =/  ls=(list @da)  (realize zone local)
  ?^  ls  `i.ls
  ::  the offset a day before: no zone moves its clock twice in a day
  =/  before=(list @da)  (realize zone (sub local ~d1))
  ?~(before ~ `(add i.before ~d1))
::  +wall: a UTC instant as the wall clock of a zone (~, or one pytz does
::  not know, is UTC)
++  wall
  |=  [zone=(unit @t) utc=@da]
  ^-  @da
  ?~  zone  utc
  ?.  (known-zone u.zone)  utc
  (fall (bind (~(utc-to-tz zn:pytz u.zone) utc) tail) utc)
::  +wkd-num: monday-zero weekday numbering
::
++  wkd-num
  |=  w=wkd
  ^-  @ud
  ?-  w
    %mon  0
    %tue  1
    %wed  2
    %thu  3
    %fri  4
    %sat  5
    %sun  6
  ==
::  +weekday: monday-zero weekday of a date (~2000.1.1 was a saturday)
::
++  weekday
  |=  d=@da
  ^-  @ud
  ?:  (gte d ~2000.1.1)
    (mod (add 5 (div (sub d ~2000.1.1) ~d1)) 7)
  ::  whole days back to the day that holds d: a midnight is on its own
  ::  day, not the one before
  =/  back=@ud  (div (add (sub ~2000.1.1 d) (dec ~d1)) ~d1)
  (mod (sub (add 5 (mul 7 back)) back) 7)
::
++  day-floor  |=(d=@da (sub d (mod d ~d1)))
::
++  days-in-month
  |=  [y=@ud m=@ud]
  ^-  @ud
  (snag (dec m) ?:((yelp y) moy:yo moh:yo))
::  +month-add: add n months to a 1-indexed [year month]
::
++  month-add
  |=  [y=@ud m=@ud n=@ud]
  ^-  [y=@ud m=@ud]
  =/  t=@ud  (add (dec m) n)
  [(add y (div t 12)) +((mod t 12))]
::  +on-date: midnight of a calendar date, ~ if it doesn't exist
::
++  on-date
  |=  [y=@ud m=@ud d=@ud]
  ^-  (unit @da)
  ?:  |(=(0 d) =(0 m) (gth m 12))  ~
  ?:  (gth d (days-in-month y m))  ~
  `(year [[%.y y] m d 0 0 0 ~])
--
