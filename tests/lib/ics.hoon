::  Unit tests for /lib/ics: folding long lines out and back, and a COUNT
::  read from a file held to the cap.
::
/+  *test, ics, cal=calendar
|%
::  a content line of n octets
++  long  |=(n=@ud ^-(tape (weld "DESCRIPTION:" (reap (sub n 12) 'x'))))
::  each folded line, less its CRLF
++  pieces
  |=  t=tape
  ^-  (list @t)
  %+  turn  (to-wain:format (crip t))
  |=(l=@t ?:(=(13 (cut 3 [(dec (met 3 l)) 1] l)) (end [3 (dec (met 3 l))] l) l))
::
++  test-fold-lines-fit
  =/  ps=(list @t)  (pieces (fold:ics (long 1.000)))
  ;:  weld
    (expect !>((levy ps |=(p=@t (lte (met 3 p) 75)))))
    ::  a continuation starts with the space that marks it
    (expect !>((levy (slag 1 ps) |=(p=@t =(' ' (end 3 p))))))
    (expect-eq !>(14) !>((lent ps)))
  ==
::
++  test-fold-unfold-round-trip
  ;:  weld
    (expect-eq !>(~[(crip (long 40))]) !>((unfold:ics (crip (fold:ics (long 40))))))
    (expect-eq !>(~[(crip (long 75))]) !>((unfold:ics (crip (fold:ics (long 75))))))
    (expect-eq !>(~[(crip (long 76))]) !>((unfold:ics (crip (fold:ics (long 76))))))
    ::  large: the join is linear now, and must still be exact
    (expect-eq !>(~[(crip (long 100.000))]) !>((unfold:ics (crip (fold:ics (long 100.000))))))
  ==
::
++  test-fold-keeps-utf8-whole
  ::  é is two octets: no fold may split one
  =/  t=tape  (weld "SUMMARY:" `tape`(zing `(list tape)`(reap 100 "é")))
  =/  ps=(list @t)  (pieces (fold:ics t))
  ;:  weld
    (expect-eq !>(~[(crip t)]) !>((unfold:ics (crip (fold:ics t)))))
    ::  no piece after the first begins (past its space) inside a character
    (expect !>((levy (slag 1 ps) |=(p=@t !=(0x80 (dis 0xc0 (cut 3 [1 1] p)))))))
  ==
::
++  test-unfold-joins-tab-and-space
  %+  expect-eq  !>(~['SUMMARY:abcdef' 'UID:x'])
  !>((unfold:ics 'SUMMARY:ab\0d\0a cd\0d\0a\09ef\0d\0aUID:x\0d\0a'))
::
++  test-count-from-a-file-is-capped
  =/  body=@t
    %-  crip
    ;:  weld
      "BEGIN:VCALENDAR\0d\0aBEGIN:VEVENT\0d\0aUID:big@test\0d\0aSUMMARY:big\0d\0a"
      "DTSTART:20261101T100000Z\0d\0aDURATION:PT1H\0d\0a"
      "RRULE:FREQ=DAILY;COUNT=99999999999\0d\0aEND:VEVENT\0d\0aEND:VCALENDAR\0d\0a"
    ==
  =/  ves  (events:ics body)
  ?>  ?=([* ~] ves)
  =/  got  (to-entry:ics i.ves ~)
  ?>  ?=(^ got)
  =/  ev  event.e.u.got
  ?>  ?=(%timed -.ev)
  (expect-eq !>(`10.000) !>(dom.bound.ev))
::
++  test-duration-digits
  ;:  weld
    (expect-eq !>(~m10) !>((parse-duration:ics 'PT10M')))
    (expect-eq !>(~d9) !>((parse-duration:ics 'P9D')))
    (expect-eq !>((add ~h1 ~m30)) !>((parse-duration:ics 'PT1H30M')))
    (expect-eq !>(~d14) !>((parse-duration:ics 'P2W')))
  ==
::
++  test-date-edges
  ;:  weld
    (expect-eq !>(`[~2026.12.31..23.59.00 &]) !>((parse-dt:ics '20261231T235900Z')))
    (expect-eq !>(`[~2026.12.31 |]) !>((parse-dt:ics '20261231')))
    (expect-eq !>(~) !>((parse-dt:ics '20261301')))
    (expect-eq !>(~) !>((parse-dt:ics '20261232')))
    (expect-eq !>("20261010") !>((date-text:ics ~2026.10.10)))
    (expect-eq !>("20260909") !>((date-text:ics ~2026.9.9)))
  ==
::
++  cron
  |=  [mons=(list @ud) doms=(list @ud) dows=(list @ud)]
  ^-  (map @t json)
  =/  ns  |=(l=(list @ud) [%a (turn l |=(n=@ud (numb:enjs:format n)))])
  %-  malt
  ^-  (list [@t json])
  :~  ['mins' (ns ~[30])]  ['hrs' (ns ~[9])]
      ['mons' (ns mons)]  ['doms' (ns doms)]  ['dows' (ns dows)]
  ==
::
++  test-cron-rule
  =/  all-mons  (gulf 1 12)
  =/  all-doms  (gulf 1 31)
  =/  all-dows  (gulf 0 6)
  =/  at  (add ~h9 ~m30)
  ;:  weld
    (expect-eq !>(`["FREQ=DAILY" at]) !>((cron-rule:ics (cron all-mons all-doms all-dows))))
    (expect-eq !>(`["FREQ=WEEKLY;BYDAY=MO,WE,FR" at]) !>((cron-rule:ics (cron all-mons all-doms ~[1 3 5]))))
    (expect-eq !>(`["FREQ=MONTHLY;BYMONTHDAY=1,15" at]) !>((cron-rule:ics (cron all-mons ~[1 15] all-dows))))
    ::  eleven months, or both lists partial, is richer than one rule
    (expect-eq !>(~) !>((cron-rule:ics (cron (gulf 1 11) all-doms all-dows))))
    (expect-eq !>(~) !>((cron-rule:ics (cron all-mons ~[1] ~[1]))))
  ==
::
++  test-export-leaves-bookkeeping-out
  =/  ev=event:cal  [%timed [[/lib/rules %once] ~ ~2026.11.2..10.00.00] ~ [%dur ~h1] [~ ~] (malt ~[['name' s+'x']])]
  =/  props=(list [@t @t])
    :~  ['X-GRUBBERY-PARENT' 'p']  ['X-GRUBBERY-KIDS' 'k']  ['X-GRUBBERY-UID' 'u']
        ['X-GOOGLE-ID' 'g']  ['X-GOOGLE-ETAG' '"3"']  ['X-GOOGLE-REMINDERS' 'default']
        ['X-KEEP' 'kept']  ['STATUS' 'CONFIRMED']
    ==
  =/  out=tape  (write-entry:ics [ev 'x@test' '' 0 ~ props] ~ ~2026.11.1)
  =/  has  |=(t=tape ?=(^ (find t out)))
  =/  todo=event:cal  [%todo `~2026.11.2 `~2026.11.3 (malt ~[['name' s+'t']])]
  =/  done=tape  (write-entry:ics [todo 't@test' '' 0 ~ ~[['STATUS' 'NEEDS-ACTION'] ['X-KEEP' 'kept']]] ~ ~2026.11.1)
  ;:  weld
    (expect !>((has "X-KEEP:kept")))
    (expect !>(!(has "X-GRUBBERY-PARENT")))
    (expect !>(!(has "X-GRUBBERY-KIDS")))
    (expect !>(!(has "X-GRUBBERY-UID")))
    (expect !>(!(has "X-GOOGLE-")))
    ::  an event's own STATUS goes out: only a done task's is replaced
    (expect !>((has "STATUS:CONFIRMED")))
    ::  a done task's own STATUS goes out, never a stale one kept from a file
    (expect !>(?=(^ (find "X-KEEP:kept" done))))
    (expect !>(?=(~ (find "STATUS:NEEDS-ACTION" done))))
  ==
--
