::  Unit tests for /lib/rrule: what an RRULE reads as, and the caps that
::  keep a rule from anyone (a share peer, a feed, Google) from holding the
::  ship. Each cap is tested as a pair: at the cap, and one past it.
::
/+  *test, rr=rrule
|%
++  rule  |=(t=@t ^-(rule:rr (need (parse:rr t))))
::  a Monday, 10:00
++  s0  ~2026.11.2..10.00.00
::  "FREQ=DAILY;INTERVAL=00…01", exactly n bytes: a legal rule of any size
++  sized
  |=  n=@ud
  ^-  @t
  (crip (weld "FREQ=DAILY;INTERVAL=" (weld (reap (sub n 21) '0') "1")))
::  "FREQ=<f>;<key>=<v>,<v>,…", n times
++  listed
  |=  [f=tape key=tape v=tape n=@ud]
  ^-  @t
  %-  crip
  (zing `(list tape)`~["FREQ=" f ";" key "=" (zing (join "," (reap n v)))])
::
++  test-parse-reads-and-refuses
  ;:  weld
    (expect !>(?=(^ (parse:rr 'FREQ=DAILY'))))
    (expect !>(?=(^ (parse:rr 'freq=weekly;byday=MO,WE'))))
    ::  what is not read is refused, never guessed
    (expect !>(?=(~ (parse:rr 'FREQ=HOURLY'))))
    (expect !>(?=(~ (parse:rr 'FREQ=MONTHLY;BYSETPOS=1'))))
    (expect !>(?=(~ (parse:rr 'INTERVAL=2'))))
    (expect !>(?=(~ (parse:rr 'FREQ=YEARLY;BYDAY=20MO'))))
    ::  an INTERVAL of 0 is 1, not a rule that never moves
    (expect-eq !>(1) !>(interval:(rule 'FREQ=DAILY;INTERVAL=0')))
    (expect-eq !>(`3) !>(count:(rule 'FREQ=DAILY;COUNT=3')))
  ==
::
++  test-parse-text-cap
  ;:  weld
    (expect-eq !>(1.024) !>((met 3 (sized 1.024))))
    (expect !>(?=(^ (parse:rr (sized 1.024)))))
    (expect !>(?=(~ (parse:rr (sized 1.025)))))
  ==
::
++  test-parse-list-caps
  ;:  weld
    (expect !>(?=(^ (parse:rr (listed "WEEKLY" "BYDAY" "MO" 64)))))
    (expect !>(?=(~ (parse:rr (listed "WEEKLY" "BYDAY" "MO" 65)))))
    (expect !>(?=(^ (parse:rr (listed "MONTHLY" "BYMONTHDAY" "1" 62)))))
    (expect !>(?=(~ (parse:rr (listed "MONTHLY" "BYMONTHDAY" "1" 63)))))
    (expect !>(?=(^ (parse:rr (listed "DAILY" "BYMONTH" "1" 12)))))
    (expect !>(?=(~ (parse:rr (listed "DAILY" "BYMONTH" "1" 13)))))
  ==
::
++  test-occurrences
  =/  wk  (rule 'FREQ=WEEKLY;BYDAY=MO,WE')
  =/  m31  (rule 'FREQ=MONTHLY;BYMONTHDAY=31')
  ;:  weld
    (expect-eq !>(`s0) !>((occurrence:rr wk s0 0)))
    (expect-eq !>(`(add s0 ~d2)) !>((occurrence:rr wk s0 1)))
    (expect-eq !>(`(add s0 ~d7)) !>((occurrence:rr wk s0 2)))
    ::  the 31st of a month that has none is a dead slot, not a moved one
    (expect-eq !>(`~2026.10.31..10.00.00) !>((occurrence:rr m31 ~2026.10.31..10.00.00 0)))
    (expect-eq !>(~) !>((occurrence:rr m31 ~2026.10.31..10.00.00 1)))
    (expect-eq !>(`~2026.12.31..10.00.00) !>((occurrence:rr m31 ~2026.10.31..10.00.00 2)))
    ::  nothing before the start, nothing after UNTIL
    (expect-eq !>(~) !>((occurrence:rr (rule 'FREQ=DAILY;UNTIL=20261103T000000Z') s0 1)))
  ==
::
++  test-count-counts-occurrences
  =/  m31  (rule 'FREQ=MONTHLY;BYMONTHDAY=31')
  =/  at  ~2026.10.31..10.00.00
  ;:  weld
    ::  three 31sts: Oct, Dec, Jan, so the bound is index 4 (Nov is dead)
    (expect-eq !>(4) !>((count-dom:rr m31 at 3)))
    (expect-eq !>(3) !>((dom-count:rr m31 at 4)))
    (expect-eq !>(5) !>((count-dom:rr (rule 'FREQ=DAILY') s0 5)))
    (expect-eq !>(5) !>((dom-count:rr (rule 'FREQ=DAILY') s0 5)))
  ==
::
++  test-count-cap
  =/  day  (rule 'FREQ=DAILY')
  ;:  weld
    ::  a COUNT past the cap walks to the cap and no further: 99999999999
    ::  would have held the ship for days
    (expect-eq !>(max-idx:rr) !>((count-dom:rr day s0 max-idx:rr)))
    (expect-eq !>(max-idx:rr) !>((count-dom:rr day s0 +(max-idx:rr))))
    (expect-eq !>(max-idx:rr) !>((count-dom:rr day s0 99.999.999.999)))
    (expect-eq !>(max-idx:rr) !>((dom-count:rr day s0 max-idx:rr)))
    (expect-eq !>(max-idx:rr) !>((dom-count:rr day s0 1.000.000.000.000.000)))
    (expect-eq !>((dec max-idx:rr)) !>((dom-count:rr day s0 (dec max-idx:rr))))
  ==
::
++  test-of-args-memo-is-of-args
  =/  a=(map @t json)  (malt ~[['rrule' s+'FREQ=WEEKLY;BYDAY=TU']])
  =/  b=(map @t json)  (malt ~[['rrule' s+'FREQ=HOURLY']])
  ;:  weld
    (expect-eq !>((of-args:rr a)) !>((of-args-memo:rr a)))
    (expect-eq !>((of-args:rr b)) !>((of-args-memo:rr b)))
    (expect !>(?=(^ (of-args-memo:rr a))))
  ==
::
++  test-until-forms-and-inclusive
  ;:  weld
    ::  date only (8), and a time without Z (15): both read, as UTC
    (expect-eq !>(~2026.11.3) !>((parse-until:rr '20261103')))
    (expect-eq !>(~2026.11.3..09.30.00) !>((parse-until:rr '20261103T093000')))
    (expect-eq !>(~2026.11.3..09.30.00) !>((parse-until:rr '20261103T093000Z')))
    (expect-eq !>(*@da) !>((parse-until:rr '2026110')))
    ::  UNTIL is inclusive: an occurrence exactly at it is kept
    (expect-eq !>(`(add s0 ~d1)) !>((occurrence:rr (rule 'FREQ=DAILY;UNTIL=20261103T100000Z') s0 1)))
    (expect-eq !>(~) !>((occurrence:rr (rule 'FREQ=DAILY;UNTIL=20261103T095959Z') s0 1)))
  ==
::
++  test-nth-weekday-edges
  ;:  weld
    ::  October 2026 has five Fridays and five Saturdays; the fifth
    ::  Saturday is its last day
    (expect-eq !>(`~2026.10.30) !>((nth-of-month:rr 2.026 10 --5 %fri)))
    (expect-eq !>(`~2026.10.31) !>((nth-of-month:rr 2.026 10 --5 %sat)))
    (expect-eq !>(~) !>((nth-of-month:rr 2.026 11 --5 %fri)))
    (expect-eq !>(~) !>((nth-of-month:rr 2.026 10 --6 %fri)))
    (expect-eq !>(`~2026.10.1) !>((nth-of-month:rr 2.026 10 -5 %thu)))
    (expect-eq !>(`~2026.10.30) !>((nth-of-month:rr 2.026 10 -1 %fri)))
  ==
::
++  test-negative-monthday
  ;:  weld
    (expect-eq !>(1) !>((resolve-dom:rr -31 31)))
    (expect-eq !>(0) !>((resolve-dom:rr -32 31)))
    (expect-eq !>(31) !>((resolve-dom:rr -1 31)))
    (expect-eq !>(5) !>((resolve-dom:rr --5 31)))
  ==
::
++  test-limits-on-daily
  ;:  weld
    ::  BYMONTH limits DAILY: the 30th and 31st of December are not in it
    =/  r  (rule 'FREQ=DAILY;BYMONTH=1')
    ;:  weld
      (expect-eq !>(~) !>((occurrence:rr r ~2026.12.30..10.00.00 0)))
      (expect-eq !>(`~2027.1.1..10.00.00) !>((occurrence:rr r ~2026.12.30..10.00.00 2)))
    ==
    ::  BYDAY limits a DAILY with an INTERVAL: every other day, Mondays only
    =/  r  (rule 'FREQ=DAILY;INTERVAL=2;BYDAY=MO')
    ;:  weld
      (expect-eq !>(`s0) !>((occurrence:rr r s0 0)))
      (expect-eq !>(~) !>((occurrence:rr r s0 1)))
      (expect-eq !>(`(add s0 ~d14)) !>((occurrence:rr r s0 7)))
    ==
    ::  BYMONTHDAY limits DAILY
    =/  r  (rule 'FREQ=DAILY;BYMONTHDAY=1')
    ;:  weld
      (expect-eq !>(~) !>((occurrence:rr r ~2026.11.30..10.00.00 0)))
      (expect-eq !>(`~2026.12.1..10.00.00) !>((occurrence:rr r ~2026.11.30..10.00.00 1)))
    ==
  ==
::
++  test-yearly-starts-on-its-start
  ::  the start's own day is occurrence 0, not a slot already passed
  =/  r  (rule 'FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=1,15')
  ;:  weld
    (expect-eq !>(`~2027.3.1..09.00.00) !>((occurrence:rr r ~2027.3.1..09.00.00 0)))
    (expect-eq !>(`~2027.3.15..09.00.00) !>((occurrence:rr r ~2027.3.1..09.00.00 1)))
    (expect-eq !>(`~2028.3.1..09.00.00) !>((occurrence:rr r ~2027.3.1..09.00.00 2)))
  ==
--
