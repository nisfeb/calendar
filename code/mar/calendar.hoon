::  calendar: portable calendar intent — config + events
::
::  ^calendar skips the door sample's face to reach the lib import.
::
/<  calendar  /lib/calendar.hoon
|_  =calendar:calendar
++  grab
  |%
  ::  any stored shape loads; a phase 1 noun is lifted on the way in
  ++  noun  |=(n=* (lift:^calendar n))
  --
++  grow
  |%
  ++  noun  calendar
  ++  json  (calendar-json:^calendar calendar)
  ++  mime
    =/  jon=^json  json
    [/application/json (as-octs:mimes:html (en:json:html jon))]
  --
--
