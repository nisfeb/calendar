::  calendar: events over the recurrence engine
::
::  An event is one of three shapes, not a rule with modifiers:
::
::    %timed   a recurrence in a zone; each tick lasts per `fin`
::             (a point, a duration, or a wall-clock end time).
::             meetings, calls.
::    %allday  a recurrence in date-space; each tick is N whole
::             days, timezone-independent. trips, conferences.
::    %date    a bare recurring calendar date [month day]. no clock,
::             no anchor, no bounds. birthdays, holidays.
::
::  %timed and %allday wrap a `recur` — a pure clock (idx -> moment)
::  living as a file in /lib/rules/. The recurrence is nested one
::  layer in and shared by both shapes: `weekly` is written once and
::  either shape wraps it. %date needs no clock at all.
::
::  recur args are a json object end to end: the client sends them,
::  the grub stores them, the kind file reads them, the codec emits
::  them back. Self-describing, no per-kind knowledge outside the
::  kind file itself.
::
::  The calendar grub is portable intent: config + events. The order
::  index (occurrence times -> refs) is derived state in a sibling
::  cache grub, reinflated on news, blow-away-able. Both span edges
::  are indexed so boundary-straddling occurrences are found; each
::  ref carries its full span so queries never re-evaluate.
::
/<  rules  /lib/rules.hoon
|%
+$  eid    @ta
::  display payload, opaque to the engine: a json object read by the
::  UI and tools, passed through verbatim like recur args. Convention:
::  'name' (required nonempty at write), 'note', 'color'; anything
::  else ('location', 'gcal_id', ...) rides along untouched.
::
+$  meta   (map @t json)
+$  span   span:rules
::  a clock placed in the world: a kind file + its args + the anchor
::  for idx 0. shared by %timed and %allday.
::
+$  recur  [kind=rail:tarball args=(map @t json) start=@da]
::  optional clipping of the index space
::
+$  bound  [dom=(unit @ud) except=(set @ud)]
::  how a timed tick ends. %dur is the common case: start + a
::  duration (a dot is %dur ~s0), works with any recurrence. %to
::  names an absolute wall-clock end — a single event with both
::  endpoints given, never recurring.
::
+$  fin
  $%  [%dur d=@dr]
      [%to end=@da]
  ==
::
+$  event
  $%  [%timed =recur zone=(unit @t) =fin =bound =meta]
      [%allday =recur days=@ud =bound =meta]
      [%date month=@ud day=@ud =meta]
  ==
::
::  the phase 1 noun: one calendar, events by id. Kept so a stored one
::  still loads; +lift turns it into the current shape.
+$  calendar-1
  $:  title=@t
      zone=(unit @t)
      horizon=@dr
      events=(map eid event)
  ==
::  an event's identity and history around its unchanged shape. uid is the
::  iCalendar UID (the phase 1 id for carried events, <random>@<ship> for
::  new ones, verbatim from a client or Google). etag is a hash of what a
::  client would get back. seq is the calendar's change counter at the
::  last write. alarms and props are what CalDAV clients will send that
::  the event shape does not model; they round-trip untouched.
+$  uid    @t
+$  etag   @t
+$  alarm  [trigger=$%([%rel before=@dr] [%abs at=@da]) desc=@t]
+$  props  (list [k=@t v=@t])
+$  entry  [=event =uid =etag seq=@ud alarms=(list alarm) =props]
+$  cal-props  [name=@t color=@t kind=$~(%local ?(%local %google %caldav)) remote=(unit @t)]
+$  logent  [=uid kind=?(%put %del)]
::  a calendar: its entries, and an append-only log of every put and
::  delete by seq, so a sync client asking "what changed since N" hears
::  about deletions too.
+$  cal
  $:  props=cal-props
      entries=(map uid entry)
      log=((mop @ud logent) lth)
      seq=@ud
  ==
+$  calendar
  $:  %2
      title=@t
      zone=(unit @t)   ::  display zone for the UI
      horizon=@dr      ::  how far ahead the cache inflates
      cals=(map @ta cal)
  ==
::
+$  ref    [=eid idx=@ud =span]
+$  order  ((mop @da (set ref)) lth)
::  thru: the wall we aimed for. stops: per event, where a
::  fuel-capped walk actually ended short of thru — absent for
::  events that were fully walked.
::
+$  cache  [thru=@da stops=(map eid @da) =order]
++  on-order  ((on @da (set ref)) lth)
::
++  on-log    ((on @ud logent) lth)
++  fresh-cal  `cal`[['Calendar' '#1e3a5f' %local ~] ~ ~ 0]
++  fresh-calendar
  ^-  calendar
  [%2 'Calendar' ~ (mul 3 ~d365) (~(put by *(map @ta cal)) %default fresh-cal)]
::  +make-etag: what a client would get back, hashed. The uid and seq are
::  identity, not content, so they are left out.
++  make-etag
  |=  e=entry
  ^-  etag
  (scot %uw (sham [event.e alarms.e props.e]))
::  +lift: any stored calendar noun to the current shape. A phase 1
::  calendar becomes the %default calendar; its ids become uids; every
::  event is entered once so the log starts complete.
++  lift
  |=  n=*
  ^-  calendar
  ?:  ?=([%2 *] n)  ;;(calendar n)
  =/  old=calendar-1  ;;(calendar-1 n)
  =/  c=cal
    %+  roll  ~(tap by events.old)
    |=  [[id=eid ev=event] acc=_fresh-cal]
    (put-entry acc [ev id '' 0 ~ ~])
  [%2 title.old zone.old horizon.old (~(put by *(map @ta cal)) %default c)]
::  +put-entry: write an entry; seq and etag move, the log records it.
++  put-entry
  |=  [c=cal e=entry]
  ^-  cal
  =/  seq=@ud  +(seq.c)
  =.  seq.e  seq
  =.  etag.e  (make-etag e)
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
::  +find-entry: which calendar holds a uid, and the entry
++  find-entry
  |=  [c=calendar =uid]
  ^-  (unit [id=@ta =entry])
  =/  cs=(list [id=@ta k=cal])  ~(tap by cals.c)
  |-
  ?~  cs  ~
  =/  e=(unit entry)  (~(get by entries.k.i.cs) uid)
  ?^  e  `[id.i.cs u.e]
  $(cs t.cs)
::  +entries-all, +events-all: every calendar flattened, keyed by uid. The
::  inflation engine and the window contract are written over events by
::  id; a uid is that id now.
++  entries-all
  |=  c=calendar
  ^-  (map uid entry)
  %-  ~(gas by *(map uid entry))
  %-  zing
  %+  turn  ~(tap by cals.c)
  |=([* k=cal] ~(tap by entries.k))
++  events-all
  |=  c=calendar
  ^-  (map eid event)
  (~(run by (entries-all c)) |=(e=entry event.e))
::
::  dead-run stops rules gone quiet (once exhausted, unreachable
::  dates); fuel stops high-frequency rules exploding the index
::
++  max-dead  400
++  max-live  10.000
::
++  da-to-ms  |=(d=@da `@ud`(div (mul (sub d ~1970.1.1) 1.000) ~s1))
::
++  put-ref
  |=  [o=order at=@da r=ref]
  ^-  order
  =/  cur=(set ref)  (fall (get:on-order o at) ~)
  (put:on-order o at (~(put in cur) r))
::  +add-spans: index every realization of one occurrence, both edges
::
++  add-spans
  |=  [o=order id=eid idx=@ud spans=(list span)]
  ^-  order
  ?~  spans  o
  =.  o  (put-ref o l.i.spans [id idx i.spans])
  =?  o  !=(l.i.spans r.i.spans)
    (put-ref o r.i.spans [id idx i.spans])
  $(spans t.spans)
::  +dress-timed: a naive wall moment -> its UTC spans, per zone+fin.
::  A DST gap yields none; a fall-back overlap yields two.
::
++  dress-timed
  |=  [zone=(unit @t) =fin moment=@da]
  ^-  (list span)
  ?-    -.fin
      ::  end relative: each realized start + the duration
      %dur
    %+  turn  (realize:rules zone moment)
    |=(l=@da `span`[l (add l d.fin)])
  ::
      ::  end absolute: realize both wall-clock endpoints, pair the
      ::  earliest of each. single (non-recurring) events only.
      %to
    =/  ls=(list @da)  (realize:rules zone moment)
    =/  rs=(list @da)  (realize:rules zone end.fin)
    ?:  |(?=(~ ls) ?=(~ rs))  ~
    ~[[i.ls i.rs]]
  ==
::  +dress-allday: a naive moment -> one UTC-date span of N days
::
++  dress-allday
  |=  [days=@ud moment=@da]
  ^-  span
  =/  l=@da  (day-floor:rules moment)
  [l (add l (mul (max 1 days) ~d1))]
::  +inflate: build the order index for all events through thru.
::  stops records, per event, where a fuel-capped walk ended short
::  of thru — the honest per-event walls.
::
++  inflate
  |=  [events=(map eid event) kinds=(map rail:tarball kind:rules) thru=@da]
  ^-  [stops=(map eid @da) =order]
  =/  out=order  ~
  =/  stops=(map eid @da)  ~
  =/  todo=(list [=eid =event])  ~(tap by events)
  |-
  ?~  todo  [stops out]
  =/  id=eid  eid.i.todo
  =/  ev=event  event.i.todo
  =/  res=[=order stop=(unit @da)]
    ?-    -.ev
        %date
      [(inflate-date out id month.ev day.ev thru) ~]
    ::
        %timed
      =/  k=(unit kind:rules)  (~(get by kinds) kind.recur.ev)
      ?~  k  [out ~]
      %^    walk-recur
          [out id recur.ev bound.ev u.k thru]
        idx=0  ^-  $-(@da (list span))
      |=(m=@da (dress-timed zone.ev fin.ev m))
    ::
        %allday
      =/  k=(unit kind:rules)  (~(get by kinds) kind.recur.ev)
      ?~  k  [out ~]
      %^    walk-recur
          [out id recur.ev bound.ev u.k thru]
        idx=0  ^-  $-(@da (list span))
      |=(m=@da ~[(dress-allday days.ev m)])
    ==
  =.  out  order.res
  =?  stops  ?=(^ stop.res)  (~(put by stops) id u.stop.res)
  $(todo t.todo)
::  +walk-recur: walk idx forward from the anchor, dressing each live
::  moment, until it passes thru or the dead/fuel guards trip.
::  stop is the last walked moment when fuel ran out short of thru —
::  the event's coverage truly ends there. ~ = fully walked (passed
::  thru, hit its count, or the rule exhausted).
::
++  walk-recur
  |=  $:  [out=order id=eid =recur =bound k=kind:rules thru=@da]
          idx=@ud  dress=$-(@da (list span))
      ==
  ^-  [order (unit @da)]
  =/  dead=@ud  0
  =/  fuel=@ud  max-live
  =/  last=(unit @da)  ~
  |-
  ?:  =(0 fuel)  [out last]
  ?:  (gth dead max-dead)  [out ~]
  ?:  &(?=(^ dom.bound) (gte idx u.dom.bound))  [out ~]
  =/  moment=(unit @da)
    (fall (mole |.((k args.recur start.recur idx))) ~)
  ?~  moment  $(idx +(idx), dead +(dead))
  ?:  (gth u.moment thru)  [out ~]
  ?:  (~(has in except.bound) idx)
    $(idx +(idx), dead 0, fuel (dec fuel), last `u.moment)
  =.  out  (add-spans out id idx (dress u.moment))
  $(idx +(idx), dead 0, fuel (dec fuel), last `u.moment)
::  +inflate-date: a bare [month day] enumerated per year across
::  [1970, year-of-thru]. idx = year - 1970, a stable per-year handle.
::  Surfaces in past windows because it walks from 1970 forward.
::
++  inflate-date
  |=  [out=order id=eid month=@ud day=@ud thru=@da]
  ^-  order
  =/  y0=@ud  1.970
  =/  y1=@ud  y:(yore thru)
  =/  y=@ud  y0
  |-
  ?:  (gth y y1)  out
  =/  d=(unit @da)  (on-date:rules y month day)
  =?  out  ?=(^ d)
    (add-spans out id (sub y y0) ~[[u.d (add u.d ~d1)]])
  $(y +(y))
::  +window: refs whose span overlaps [from to], deduplicated. Edges
::  inside the window are the fast path; spans reaching in from the
::  left (including ones containing the whole window) are found by
::  scanning entries before from and keeping those whose stored right
::  edge crosses into it. Exact — no length bound.
::
++  window
  |=  [o=order from=@da to=@da]
  ^-  (set ref)
  =/  hits=(set ref)
    %+  roll  (tap:on-order (lot:on-order o `(sub from 1) `(add to 1)))
    |=  [[@da refs=(set ref)] acc=(set ref)]
    (~(uni in acc) refs)
  =/  left=(list [@da (set ref)])  (tap:on-order (lot:on-order o ~ `from))
  =.  hits
    |-  ^-  (set ref)
    ?~  left  hits
    =/  rs=(list ref)  ~(tap in +.i.left)
    |-
    ?~  rs  ^$(left t.left)
    =?  hits  (gte r.span.i.rs from)  (~(put in hits) i.rs)
    $(rs t.rs)
  ::  exact overlap: spans are [l r) — r is exclusive, an event
  ::  ending at from is over — and windows are [from to). keep
  ::  zero-length instants sitting exactly on from.
  %-  ~(gas in *(set ref))
  %+  skim  ~(tap in hits)
  |=  r=ref
  ?&  (lth l.span.r to)
      ?|  (gth r.span.r from)
          &(=(l.span.r r.span.r) (gte r.span.r from))
  ==  ==
::  +all-day: does this event render in date-space (no zone)?
::
++  all-day  |=(e=event ?=(?(%allday %date) -.e))
::  +meta-str: a string key from a meta map, '' when absent
::
++  meta-str
  |=  [m=meta k=@t]
  ^-  @t
  =/  j=(unit json)  (~(get by m) k)
  ?.(?=([~ %s *] j) '' p.u.j)
::  +recur-json: kind + anchor + args. args pass through verbatim —
::  the kind file is the only place that knows what they mean.
::
++  recur-json
  |=  =recur
  ^-  (list [@t json])
  :~  ['kind' s+name.kind.recur]
      ['start_ms' (numb:enjs:format (da-to-ms start.recur))]
      ['args' [%o args.recur]]
  ==
::  +event-json: full event breakdown for the edit form — the
::  reverse of the nexus parser, per category.
::
++  event-json
  |=  [id=@ta e=event]
  ^-  json
  =/  m=meta  ?-(-.e %timed meta.e, %allday meta.e, %date meta.e)
  =/  common=(list [@t json])
    :~  ['id' s+id]
        ['cat' s+-.e]
        ['meta' [%o m]]
    ==
  =/  rest=(list [@t json])
    ?-    -.e
        %date
      :~  ['month' (numb:enjs:format month.e)]
          ['day' (numb:enjs:format day.e)]
      ==
    ::
        %timed
      =/  fin-fields=(list [@t json])
        ?-  -.fin.e
          %dur  ~[['fin' s+'dur'] ['dur_min' (numb:enjs:format (div d.fin.e ~m1))]]
          %to   ~[['fin' s+'to'] ['end_ms' (numb:enjs:format (da-to-ms end.fin.e))]]
        ==
      ;:  weld
        (recur-json recur.e)
        ^-  (list [@t json])
        :~  ['zone' `json`?~(zone.e s+'none' s+u.zone.e)]
            ['count' (numb:enjs:format (fall dom.bound.e 0))]
        ==
        fin-fields
      ==
    ::
        %allday
      %+  weld  (recur-json recur.e)
      :~  ['span_days' (numb:enjs:format days.e)]
          ['count' (numb:enjs:format (fall dom.bound.e 0))]
      ==
    ==
  [%o (~(gas by *(map @t json)) (weld common rest))]
::  +calendar-json: whole-calendar display codec for the mark
::
++  calendar-json
  |=  c=calendar
  ^-  json
  %-  pairs:enjs:format
  :~  ['title' s+title.c]
      ['zone' ?~(zone.c ~ s+u.zone.c)]
      ['horizon_days' (numb:enjs:format (div horizon.c ~d1))]
      :-  'calendars'
      :-  %a
      %+  turn  ~(tap by cals.c)
      |=  [id=@ta k=cal]
      %-  pairs:enjs:format
      :~  ['id' s+id]
          ['name' s+name.props.k]
          ['color' s+color.props.k]
          ['kind' s+kind.props.k]
          ['seq' (numb:enjs:format seq.k)]
          ['count' (numb:enjs:format ~(wyt by entries.k))]
      ==
      :-  'events'
      :-  %a
      %+  turn  ~(tap by (entries-all c))
      |=  [u=uid e=entry]
      ^-  json
      =/  base=json  (event-json u event.e)
      ?.  ?=(%o -.base)  base
      :-  %o
      %-  ~(gas by p.base)
      :~  ['uid' s+u]
          ['etag' s+etag.e]
          ['seq' (numb:enjs:format seq.e)]
      ==
  ==
--
