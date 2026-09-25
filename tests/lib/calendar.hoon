::  Unit tests for /lib/calendar: what the occurrence cache is current
::  for, and the walks that build it staying bounded.
::
/+  *test, cal=calendar, once=rules-once, krr=rules-rrule, tarball
|%
++  kind-for
  |=  r=rail:tarball
  ^-  (unit kind:rules:cal)
  ?:  =(%once name.r)  `once
  ?:  =(%rrule name.r)  `krr
  ~
++  at  ~2026.11.2..10.00.00
++  timed-once
  ^-  event:cal
  [%timed [[/lib/rules %once] ~ at] ~ [%dur ~h1] [~ ~] ~]
::
++  test-cache-ver-follows-zone
  =/  c  fresh-calendar:cal
  ;:  weld
    (expect !>(!=((cache-ver:cal c) (cache-ver:cal c(zone `'Europe/Berlin')))))
    (expect !>(!=((cache-ver:cal c) (cache-ver:cal c(horizon ~d1)))))
    (expect-eq !>((cache-ver:cal c)) !>((cache-ver:cal c(title 'renamed'))))
  ==
::
++  test-inflate-date-years
  =/  o  (inflate-date:cal ~ %bday 3 1 ~2029.6.1)
  ::  1970 through 2029, one a year: a day's span puts both its edges in
  (expect-eq !>((mul 2 60)) !>((lent (tap:on-order:cal o))))
::
++  test-inflate-date-cap
  ::  a thru a million years out walks no more than max-live years
  =/  o  (inflate-date:cal ~ %bday 3 1 (year [[& 1.000.000] 1 1 [0 0 0 ~]]))
  =/  last  (ram:on-order:cal o)
  ?>  ?=(^ last)
  ;:  weld
    (expect-eq !>((mul 2 +(max-live:cal))) !>((lent (tap:on-order:cal o))))
    (expect-eq !>((add 1.970 max-live:cal)) !>(y:(yore key.u.last)))
  ==
::
++  test-inflate-once
  =/  res  (inflate:cal (malt ~[[%one timed-once]]) kind-for (add at ~d30) ~)
  =/  keys=(list @da)  (turn (tap:on-order:cal order.res) head)
  ;:  weld
    ::  a once event is one span: its start and its end
    (expect-eq !>(~[at (add at ~h1)]) !>(keys))
    (expect-eq !>(~) !>(stops.res))
  ==
::
++  test-window
  =/  res  (inflate:cal (malt ~[[%one timed-once]]) kind-for (add at ~d30) ~)
  ;:  weld
    (expect-eq !>(1) !>(~(wyt in (window:cal order.res (sub at ~h1) (add at ~m1)))))
    ::  a span ending exactly at from is over
    (expect-eq !>(0) !>(~(wyt in (window:cal order.res (add at ~h1) (add at ~h2)))))
    (expect-eq !>(0) !>(~(wyt in (window:cal order.res (add at ~d1) (add at ~d2)))))
  ==
::
++  daily
  |=  dom=(unit @ud)
  ^-  event:cal
  :*  %timed  [[/lib/rules %rrule] (malt ~[['rrule' s+'FREQ=DAILY']]) at]
      ~  [%dur ~h1]  [dom ~]  ~
  ==
++  starts
  |=  [e=event:cal thru=@da]
  ^-  (list @da)
  %+  murn  (tap:on-order:cal order:(inflate:cal (malt ~[[%e e]]) kind-for thru ~))
  |=  [k=@da rs=(set ref:cal)]
  ?.((lien ~(tap in rs) |=(r=ref:cal =(k l.span.r))) ~ `k)
::
++  test-walk-bound-and-thru
  ;:  weld
    ::  a COUNT bound of 3 is three occurrences, not four
    (expect-eq !>(~[at (add at ~d1) (add at ~d2)]) !>((starts (daily `3) (add at ~d30))))
    ::  an occurrence exactly at thru is in; the next is not
    (expect-eq !>(~[at (add at ~d1) (add at ~d2)]) !>((starts (daily ~) (add at ~d2))))
  ==
::
++  test-window-edges
  =/  zero=event:cal  [%timed [[/lib/rules %once] ~ at] ~ [%dur ~s0] [~ ~] ~]
  =/  z  (inflate:cal (malt ~[[%z zero]]) kind-for (add at ~d1) ~)
  =/  one  (inflate:cal (malt ~[[%one timed-once]]) kind-for (add at ~d30) ~)
  ;:  weld
    ::  windows are [from to): a span starting at to is not in
    (expect-eq !>(0) !>(~(wyt in (window:cal order.one (sub at ~h2) at))))
    ::  a zero-length span at from is
    (expect-eq !>(1) !>(~(wyt in (window:cal order.z at (add at ~h1)))))
  ==
--
