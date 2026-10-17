::  Unit tests for /lib/gcal: Google event JSON to the exchange shape.
::
/+  *test, gcal, ics
|%
::  a Google item from its JSON text
++  item
  |=  t=@t
  ^-  gitem:gcal
  (need (item-of:gcal (need (de:json:html t))))
::  the join link a pulled item reads into meta
++  join
  |=  t=@t
  ^-  (unit json)
  (~(get by (read-meta:ics ve:(item t))) 'conference')
::
::  the join link: a conference's video entry point (Meet, or Zoom through
::  its add-on) wins over the bare Meet link; none, no link
++  test-join-link-from-google
  =/  base  '"id":"g1","summary":"s","start":{"dateTime":"2026-11-02T10:00:00Z"},"end":{"dateTime":"2026-11-02T11:00:00Z"}'
  ;:  weld
    %+  expect-eq  !>(`s+'https://zoom.us/j/9')
    !>((join (rap 3 ~['{' base ',"hangoutLink":"https://meet.google.com/x","conferenceData":{"entryPoints":[{"entryPointType":"phone","uri":"tel:+1"},{"entryPointType":"video","uri":"https://zoom.us/j/9"}]}}'])))
    %+  expect-eq  !>(`s+'https://meet.google.com/x')
    !>((join (rap 3 ~['{' base ',"hangoutLink":"https://meet.google.com/x"}'])))
    (expect-eq !>(~) !>((join (rap 3 ~['{' base '}']))))
  ==
--
