::  Unit tests for /lib/gcal: Google event JSON to the exchange shape.
::
/+  *test, gcal, ics, cal=calendar
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
::
::  guests: Google's attendees and organizer reach meta with their answers
::  and the owner marked self; meta's guests go back as attendees, and a
::  ship (no email) is not Google's
++  test-guests-from-and-to-google
  =/  g=gitem:gcal
    %-  item
    '{"id":"g2","summary":"s","start":{"dateTime":"2026-11-02T10:00:00Z"},"end":{"dateTime":"2026-11-02T11:00:00Z"},"organizer":{"email":"boss@x.test"},"attendees":[{"email":"ana@x.test","displayName":"Ana \\"A\\"","responseStatus":"accepted"},{"email":"me@x.test","self":true,"responseStatus":"needsAction"}]}'
  =/  m=meta:cal  (read-meta:ics ve.g)
  =/  out=(list [@t json])
    %-  attendees-of:gcal
    %+  ~(put by m)  'guests'
    :-  %a
    :~  (pairs:enjs:format ~[['email' s+'ana@x.test'] ['status' s+'accepted']])
        (pairs:enjs:format ~[['ship' s+'~zod'] ['status' s+'needs-action']])
    ==
  ;:  weld
    %+  expect-eq
      !>  :-  ~
          :-  %a
          :~  (pairs:enjs:format ~[['email' s+'ana@x.test'] ['name' s+'Ana A'] ['status' s+'accepted']])
              (pairs:enjs:format ~[['email' s+'me@x.test'] ['status' s+'needs-action'] ['self' b+&]])
          ==
    !>((~(get by m) 'guests'))
    (expect-eq !>(`(pairs:enjs:format ~[['email' s+'boss@x.test']])) !>((~(get by m) 'organizer')))
    %+  expect-eq
      !>(~[['attendees' [%a ~[(pairs:enjs:format ~[['email' s+'ana@x.test'] ['responseStatus' s+'accepted']])]]]])
    !>(out)
    ::  no guests in meta: Google's list is left alone
    (expect-eq !>(~) !>((attendees-of:gcal (~(del by m) 'guests'))))
  ==
::
::  a push for an event pulled before guests were read keeps Google's
::  guests it never saw, and does not repeat the ones it names
++  test-merge-attendees
  =/  body=json  (need (de:json:html '{"summary":"s","attendees":[{"email":"a@x"}]}'))
  =/  cur=json  (need (de:json:html '{"attendees":[{"email":"a@x","responseStatus":"accepted"},{"email":"b@x"}]}'))
  %+  expect-eq
    !>  (need (de:json:html '{"summary":"s","attendees":[{"email":"a@x"},{"email":"b@x"}]}'))
  !>((merge-attendees:gcal body cur))
--
