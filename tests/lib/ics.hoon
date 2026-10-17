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
::
::  priority: PRIORITY read into meta (not kept verbatim as well), and
::  written back out from meta
++  test-priority-in-and-out
  =/  task=event:cal  [%todo `~2026.11.2 ~ (~(gas by *meta:cal) `(list [@t json])`~[['name' s+'t'] ['priority' (numb:enjs:format 2)]])]
  =/  out=tape  (write-entry:ics [task 't@test' '' 0 ~ ~] ~ ~2026.11.1)
  =/  bare=event:cal  [%todo `~2026.11.2 ~ (malt ~[['name' s+'t']])]
  =/  plain=tape  (write-entry:ics [bare 't@test' '' 0 ~ ~] ~ ~2026.11.1)
  =/  body=@t
    %-  crip
    %-  zing
    %+  turn
      :~  "BEGIN:VCALENDAR"
          "VERSION:2.0"
          "BEGIN:VTODO"
          "UID:p@test"
          "SUMMARY:p"
          "DUE;VALUE=DATE:20261102"
          "PRIORITY:5"
          "X-KEEP:k"
          "END:VTODO"
          "END:VCALENDAR"
      ==
    |=(l=tape (weld l crlf:ics))
  =/  ves=(list vevent:ics)  (events:ics body)
  ;:  weld
    (expect !>(?=(^ (find "PRIORITY:2" out))))
    (expect !>(?=(~ (find "PRIORITY" plain))))
    (expect-eq !>(1) !>((lent ves)))
    (expect-eq !>(5) !>((meta-priority:cal (read-meta:ics (snag 0 ves)))))
    (expect !>((meta-prop:ics ['PRIORITY' '5'])))
    (expect !>(!(meta-prop:ics ['X-KEEP' 'k'])))
  ==
::
::  the join link: the first CONFERENCE (RFC 7986) read into meta, not
::  kept verbatim as well, and written back out as a URI with no control
::  characters, so a link cannot smuggle in a line of its own
++  test-conference-in-and-out
  =/  m=meta:cal  (malt `(list [@t json])`~[['name' s+'x'] ['conference' s+'https://meet.google.com/abc-defg-hij']])
  =/  ev=event:cal  [%timed [[/lib/rules %once] ~ ~2026.11.2..10.00.00] ~ [%dur ~h1] [~ ~] m]
  =/  out=tape  (write-entry:ics [ev 'x@test' '' 0 ~ ~] ~ ~2026.11.1)
  =/  bad=event:cal  [%timed [[/lib/rules %once] ~ ~2026.11.2..10.00.00] ~ [%dur ~h1] [~ ~] (~(put by m) 'conference' s+'https://x.test/\0d\0aX-EVIL:1')]
  =/  evil=tape  (write-entry:ics [bad 'x@test' '' 0 ~ ~] ~ ~2026.11.1)
  =/  body=@t
    %-  crip
    %-  zing
    %+  turn
      :~  "BEGIN:VCALENDAR"
          "BEGIN:VEVENT"
          "UID:c@test"
          "SUMMARY:c"
          "DTSTART:20261102T100000Z"
          "CONFERENCE;VALUE=URI;FEATURE=VIDEO;LABEL=Join:https://zoom.us/j/1"
          "END:VEVENT"
          "END:VCALENDAR"
      ==
    |=(l=tape (weld l crlf:ics))
  =/  ves=(list vevent:ics)  (events:ics body)
  ;:  weld
    (expect !>(?=(^ (find "CONFERENCE;VALUE=URI;FEATURE=VIDEO:https://meet.google.com/abc-defg-hij" out))))
    (expect !>(?=(~ (find "\0d\0aX-EVIL" evil))))
    (expect-eq !>(1) !>((lent ves)))
    (expect-eq !>(`s+'https://zoom.us/j/1') !>((~(get by (read-meta:ics (snag 0 ves))) 'conference')))
    (expect !>((meta-prop:ics ['CONFERENCE;VALUE=URI' 'https://zoom.us/j/1'])))
  ==
::
::  guests: ATTENDEE and ORGANIZER read into meta, written back as lines
::  with a known status only, and a ship guest (no email) not written
++  test-guests-in-and-out
  =/  body=@t
    %-  crip
    %-  zing
    %+  turn
      :~  "BEGIN:VCALENDAR"
          "BEGIN:VEVENT"
          "UID:g@test"
          "SUMMARY:g"
          "DTSTART:20261102T100000Z"
          "ORGANIZER;CN=Boss:mailto:boss@x.test"
          "ATTENDEE;CN=\"Doe: J\";PARTSTAT=TENTATIVE;ROLE=REQ-PARTICIPANT:MAILTO:doe@x.test"
          "END:VEVENT"
          "END:VCALENDAR"
      ==
    |=(l=tape (weld l crlf:ics))
  =/  m=meta:cal  (read-meta:ics (snag 0 (events:ics body)))
  =/  w=meta:cal
    %-  malt
    ^-  (list [@t json])
    :~  ['name' s+'w']
        ['organizer' (pairs:enjs:format ~[['email' s+'boss@x.test']])]
        :-  'guests'
        :-  %a
        :~  (pairs:enjs:format ~[['email' s+'ana@x.test'] ['name' s+'Ana'] ['status' s+'accepted']])
            (pairs:enjs:format ~[['email' s+'bo@x.test'] ['status' s+'bogus;X=1']])
            (pairs:enjs:format ~[['ship' s+'~zod']])
        ==
    ==
  =/  ev=event:cal  [%timed [[/lib/rules %once] ~ ~2026.11.2..10.00.00] ~ [%dur ~h1] [~ ~] w]
  =/  out=tape  (write-entry:ics [ev 'w@test' '' 0 ~ ~] ~ ~2026.11.1)
  ::  a line an older version kept verbatim gives way to meta's
  =/  old=tape  (write-entry:ics [ev 'w@test' '' 0 ~ ~[['ATTENDEE;CN=Old' 'mailto:old@x.test']]] ~ ~2026.11.1)
  ;:  weld
    (expect !>(?=(~ (find "old@x.test" old))))
    %+  expect-eq
      !>(`[%a ~[(pairs:enjs:format ~[['email' s+'doe@x.test'] ['name' s+'Doe: J'] ['status' s+'tentative']])]])
    !>((~(get by m) 'guests'))
    (expect-eq !>(`(pairs:enjs:format ~[['email' s+'boss@x.test'] ['name' s+'Boss']])) !>((~(get by m) 'organizer')))
    (expect !>(?=(^ (find "ORGANIZER:mailto:boss@x.test" out))))
    (expect !>(?=(^ (find "ATTENDEE;CN=\"Ana\";PARTSTAT=ACCEPTED:mailto:ana@x.test" out))))
    (expect !>(?=(^ (find "ATTENDEE:mailto:bo@x.test" out))))
    (expect !>(?=(~ (find "~zod" out))))
    (expect !>((meta-prop:ics ['ATTENDEE;CN=x' 'mailto:a@b'])))
  ==
::
::  an open task's STATUS, typed or kept from a file, is written before
::  its alarms either way, so an export is the same through an import
++  test-open-task-status-in-place
  =/  task=event:cal  [%todo `~2026.11.2 ~ (malt ~[['name' s+'t']])]
  =/  typed=entry:cal  [task 't@test' '' 0 ~[[[%rel ~h1] 'an hour']] ~]
  =/  kept=entry:cal  [task 't@test' '' 0 ~[[[%rel ~h1] 'an hour']] ~[['STATUS' 'NEEDS-ACTION']]]
  =/  a=tape  (write-entry:ics typed ~ ~2026.11.1)
  =/  b=tape  (write-entry:ics kept ~ ~2026.11.1)
  =/  before
    |=  t=tape
    ^-  ?
    =/  s=(unit @ud)  (find "STATUS:NEEDS-ACTION" t)
    =/  v=(unit @ud)  (find "BEGIN:VALARM" t)
    &(?=(^ s) ?=(^ v) (lth u.s u.v))
  ;:  weld
    (expect !>((before a)))
    (expect !>((before b)))
    (expect-eq !>(1) !>((lent (fand "STATUS:" b))))
    (expect-eq !>(a) !>(b))
  ==
--
