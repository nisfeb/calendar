::  calendar-cache: derived order index over a calendar — regenerable
::
/<  cal  /lib/calendar.hoon
|_  =cache:cal
++  grab
  |%
  ::  ponytail: taken as it is, not clammed: only the cache fiber writes
  ::  one, from its own typed build, and a clam of the order is 200 ms
  ::  at 1,400 events, asked several times a change
  ++  noun  |=(n=* !<(cache:cal [-:!>(*cache:cal) n]))
  --
++  grow
  |%
  ++  noun  cache
  --
--
