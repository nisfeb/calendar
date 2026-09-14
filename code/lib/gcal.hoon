::  gcal: Google Calendar's event JSON to a vevent and back. The vevent
::  is the exchange shape both the ICS reader and the DAV writer already
::  speak, so a Google item goes through the same +to-entry as a file.
::
/<  ics    /lib/ics.hoon
/<  cal    /lib/calendar.hoon
|%
+$  gitem
  $:  ve=vevent:ics
      gid=@t                    ::  Google's own event id
      updated=@t                ::  Google's updated stamp, verbatim
      cancelled=?
      rid=(unit @t)             ::  an exception instance: RECURRENCE-ID text
      rid-key=@t                ::  its ICS key, with a TZID param when local
  ==
++  str  |=([j=json k=@t] ^-(@t ?.(?=(%o -.j) '' ?~(v=(~(get by p.j) k) '' ?:(?=(%s -.u.v) p.u.v '')))))
++  obj  |=([j=json k=@t] ^-(json ?.(?=(%o -.j) [%o ~] (fall (~(get by p.j) k) [%o ~]))))
++  arr  |=([j=json k=@t] ^-((list json) ?.(?=(%o -.j) ~ ?~(v=(~(get by p.j) k) ~ ?:(?=(%a -.u.v) p.u.v ~)))))
++  num  |=([j=json k=@t] ^-(@ud ?.(?=(%o -.j) 0 ?~(v=(~(get by p.j) k) 0 ?:(?=(%n -.u.v) (fall (rush p.u.v dem) 0) 0)))))
::  +parse-rfc3339: "2026-09-14T10:00:00-04:00" / "...Z" / "2026-09-14"
::  → the wall clock as written (naive) and the offset, or ~
++  parse-rfc3339
  |=  t=@t
  ^-  (unit [naive=@da utc=? off=(unit [neg=? d=@dr]) day=?])
  =/  s=tape  (trip t)
  ?:  =(10 (lent s))
    =/  d=(unit [d=@da z=?])  (parse-dt:ics (crip (skip s |=(c=@t =('-' c)))))
    ?~(d ~ `[d.u.d %.n ~ %.y])
  ?.  (gte (lent s) 19)  ~
  =/  date=tape  (skip (scag 10 s) |=(c=@t =('-' c)))
  =/  clock=tape  (skip (scag 8 (slag 11 s)) |=(c=@t =(':' c)))
  =/  rest=tape  (slag 19 s)
  =.  rest  (strip-frac rest)
  =/  d=(unit [d=@da z=?])  (parse-dt:ics (crip :(weld date "T" clock "Z")))
  ?~  d  ~
  ?~  rest  `[d.u.d %.n ~ %.n]
  ?:  =('Z' i.rest)  `[d.u.d %.y ~ %.n]
  ?.  ?=(?(%'+' %'-') i.rest)  `[d.u.d %.n ~ %.n]
  =/  hh=@ud  (fall (rush (crip (scag 2 t.rest)) dem) 0)
  =/  mm=@ud  (fall (rush (crip (slag 3 t.rest)) dem) 0)
  `[d.u.d %.n `[=('-' i.rest) (add (mul hh ~h1) (mul mm ~m1))] %.n]
++  strip-frac
  |=  t=tape
  ^-  tape
  ?~  t  ~
  ?.  =('.' i.t)  t
  (drop-until `tape`t.t)
++  drop-until
  |=  t=tape
  ^-  tape
  ?~  t  ~
  ?:  |(=('+' i.t) =('-' i.t) =('Z' i.t))  t
  $(t t.t)
::  +when-of: a Google start/end object to a when. A timeZone names the
::  wall clock's zone; without one, the offset makes it UTC.
++  when-of
  |=  o=json
  ^-  (unit when:ics)
  =/  dt=@t  (str o 'dateTime')
  =/  dd=@t  (str o 'date')
  ?.  =('' dd)
    =/  p  (parse-rfc3339 dd)
    ?~(p ~ `[%day naive.u.p])
  ?:  =('' dt)  ~
  =/  p  (parse-rfc3339 dt)
  ?~  p  ~
  =/  zone=@t  (str o 'timeZone')
  ?.  =('' zone)  `[%local zone naive.u.p]
  ?~  off.u.p  `[%utc naive.u.p]
  ::  local clock with an offset: back to UTC
  `[%utc ?:(neg.u.off.u.p (add naive.u.p d.u.off.u.p) (sub naive.u.p d.u.off.u.p))]
::  +rid-text: an originalStartTime as RECURRENCE-ID text, with its key
++  rid-of
  |=  o=json
  ^-  (unit [key=@t val=@t])
  =/  w=(unit when:ics)  (when-of o)
  ?~  w  ~
  =/  [params=tape value=tape]  (when-text:ics u.w)
  `[(crip (weld "RECURRENCE-ID" params)) (crip value)]
::  +item-of: one Google event to the exchange shape
++  item-of
  |=  item=json
  ^-  (unit gitem)
  =/  gid=@t  (str item 'id')
  ?:  =('' gid)  ~
  =/  uid=@t  (str item 'iCalUID')
  =.  uid  ?:(=('' uid) (cat 3 gid '@google.com') uid)
  =/  cancelled=?  =('cancelled' (str item 'status'))
  =/  start=(unit when:ics)  (when-of (obj item 'start'))
  =/  end=(unit when:ics)  (when-of (obj item 'end'))
  =/  lines=(list @t)
    %+  murn  (arr item 'recurrence')
    |=(j=json ?:(?=(%s -.j) `p.j ~))
  =/  rrule=@t
    =/  hit=(list @t)  (skim lines |=(l=@t =("RRULE:" (scag 6 (trip l)))))
    ?~(hit '' (crip (slag 6 (trip i.hit))))
  =/  exdates=(list when:ics)
    %-  zing
    %+  turn  (skim lines |=(l=@t =("EXDATE" (scag 6 (trip l)))))
    |=  l=@t
    ^-  (list when:ics)
    =/  t=tape  (trip l)
    =/  at=(unit @ud)  (find ":" t)
    ?~  at  ~
    =/  key=@t  (crip (scag u.at t))
    %+  murn  (split-commas (slag +(u.at) t))
    |=(v=tape (when-of:ics key (crip v)))
  =/  alarms=(list alarm:cal)
    =/  rem=json  (obj item 'reminders')
    %+  turn  (arr rem 'overrides')
    |=  o=json
    ^-  alarm:cal
    [[%rel (mul (num o 'minutes') ~m1)] (str o 'method')]
  =/  rid=(unit [key=@t val=@t])
    ?:  =('' (str item 'recurringEventId'))  ~
    (rid-of (obj item 'originalStartTime'))
  =/  extra=(list [@t @t])
    %+  weld
      ^-  (list [@t @t])
      :~  ['X-GOOGLE-ID' gid]
          ['X-GOOGLE-UPDATED' (str item 'updated')]
      ==
    ?~(rid ~ ~[[key.u.rid val.u.rid]])
  :-  ~
  :*  ^-  vevent:ics
      :*  uid
          (str item 'summary')
          (str item 'location')
          (str item 'description')
          start
          end
          ~
          rrule
          exdates
          alarms
          (num item 'sequence')
          ''
          ''
          ''
          extra
      ==
      gid
      (str item 'updated')
      cancelled
      ?~(rid ~ `val.u.rid)
      ?~(rid '' key.u.rid)
  ==
++  split-commas
  |=  t=tape
  ^-  (list tape)
  =|  cur=tape
  =|  out=(list tape)
  |-
  ?~  t  (flop [(flop cur) out])
  ?:  =(',' i.t)  $(t t.t, out [(flop cur) out], cur ~)
  $(t t.t, cur [i.t cur])
--
