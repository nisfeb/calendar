::  Unit tests for /lib/rules: placing a wall-clock moment in a zone (the
::  DST gap and overlap as RFC 5545 3.3.5 says), reading one back, and
::  the calendar arithmetic every kind stands on.
::
/+  *test, rules
|%
++  ny  `(unit @t)``'America/New_York'
::
++  test-known-zone
  ;:  weld
    (expect !>((known-zone:rules 'America/New_York')))
    (expect !>((known-zone:rules 'Europe/Berlin')))
    (expect !>(!(known-zone:rules 'Mars/Olympus')))
    (expect !>(!(known-zone:rules '')))
  ==
::
++  test-place
  ;:  weld
    ::  standard time: 09:00 EST is 14:00 UTC
    (expect-eq !>(`~2026.11.2..14.00.00) !>((place:rules ny ~2026.11.2..09.00.00)))
    ::  summer time: 09:00 EDT is 13:00 UTC
    (expect-eq !>(`~2026.7.1..13.00.00) !>((place:rules ny ~2026.7.1..09.00.00)))
    ::  a spring-forward gap: 02:30 does not exist, and is 03:30 EDT
    (expect-eq !>(`~2027.3.14..07.30.00) !>((place:rules ny ~2027.3.14..02.30.00)))
    ::  a fall-back overlap: 01:30 happens twice; the first (EDT) is taken
    (expect-eq !>(`~2026.11.1..05.30.00) !>((place:rules ny ~2026.11.1..01.30.00)))
    ::  UTC is itself
    (expect-eq !>(`~2026.11.2..09.00.00) !>((place:rules ~ ~2026.11.2..09.00.00)))
  ==
::
++  test-wall
  ;:  weld
    (expect-eq !>(~2026.11.2..09.00.00) !>((wall:rules ny ~2026.11.2..14.00.00)))
    (expect-eq !>(~2026.7.1..09.00.00) !>((wall:rules ny ~2026.7.1..13.00.00)))
    ::  no zone, or one pytz does not know, is UTC: never a crash
    (expect-eq !>(~2026.11.2..14.00.00) !>((wall:rules ~ ~2026.11.2..14.00.00)))
    (expect-eq !>(~2026.11.2..14.00.00) !>((wall:rules `'Mars/Olympus' ~2026.11.2..14.00.00)))
  ==
::
++  test-weekday
  ;:  weld
    (expect-eq !>(0) !>((weekday:rules ~2026.11.2)))
    (expect-eq !>(6) !>((weekday:rules ~2026.11.8..23.59.59)))
    ::  before ~2000.1.1 (a Saturday) the count runs backwards
    (expect-eq !>(4) !>((weekday:rules ~1999.12.31)))
    (expect-eq !>(4) !>((weekday:rules ~1999.12.31..23.59.59)))
    (expect-eq !>(5) !>((weekday:rules ~2000.1.1)))
    (expect-eq !>(3) !>((weekday:rules ~1970.1.1)))
  ==
::
++  test-month-arithmetic
  ;:  weld
    (expect-eq !>(29) !>((days-in-month:rules 2.024 2)))
    (expect-eq !>(28) !>((days-in-month:rules 2.026 2)))
    (expect-eq !>(28) !>((days-in-month:rules 2.100 2)))
    (expect-eq !>(29) !>((days-in-month:rules 2.000 2)))
    (expect-eq !>(30) !>((days-in-month:rules 2.026 4)))
    (expect-eq !>(31) !>((days-in-month:rules 2.026 12)))
    (expect-eq !>([2.027 2]) !>((month-add:rules 2.026 11 3)))
    (expect-eq !>([2.026 12]) !>((month-add:rules 2.026 11 1)))
    (expect-eq !>([2.026 11]) !>((month-add:rules 2.026 11 0)))
    (expect-eq !>(`~2024.2.29) !>((on-date:rules 2.024 2 29)))
    (expect-eq !>(~) !>((on-date:rules 2.026 2 29)))
    (expect-eq !>(~) !>((on-date:rules 2.026 13 1)))
    (expect-eq !>(~) !>((on-date:rules 2.026 1 0)))
    (expect-eq !>(`~2026.1.31) !>((on-date:rules 2.026 1 31)))
    (expect-eq !>(~2026.11.2) !>((day-floor:rules ~2026.11.2..23.59.59)))
  ==
--
