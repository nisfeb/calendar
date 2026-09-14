::  gcal: Google Calendar's event JSON to a vevent and back. The vevent
::  is the exchange shape both the ICS reader and the DAV writer already
::  speak, so a Google item goes through the same +to-entry as a file.
::
/<  ics    /lib/ics.hoon
/<  cal    /lib/calendar.hoon
/<  rules  /lib/rules.hoon
/<  rr     /lib/rrule.hoon
|%
+$  gitem
  $:  ve=vevent:ics
      gid=@t                    ::  Google's own event id
      updated=@t                ::  Google's updated stamp, verbatim
      cancelled=?
      rid=(unit @t)             ::  an exception instance: RECURRENCE-ID text
      rid-key=@t                ::  its ICS key, with a TZID param when local
  ==
++  get
  |=  [j=json k=@t]
  ^-  (unit json)
  ?.  ?=(%o -.j)  ~
  (~(get by p.j) k)
++  str
  |=  [j=json k=@t]
  ^-  @t
  =/  v=(unit json)  (get j k)
  ?:  ?=([~ %s *] v)  p.u.v
  ''
++  obj
  |=  [j=json k=@t]
  ^-  json
  =/  v=(unit json)  (get j k)
  ?:  ?=([~ %o *] v)  u.v
  [%o ~]
++  arr
  |=  [j=json k=@t]
  ^-  (list json)
  =/  v=(unit json)  (get j k)
  ?:  ?=([~ %a *] v)  p.u.v
  ~
++  num
  |=  [j=json k=@t]
  ^-  @ud
  =/  v=(unit json)  (get j k)
  ?:  ?=([~ %n *] v)  (fall (rush p.u.v dem) 0)
  0
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
  ?:  &(!=('' zone) (known-zone:rules zone))  `[%local zone naive.u.p]
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
  =/  tags=@t  (str (obj (obj item 'extendedProperties') 'private') 'tags')
  =/  extra=(list [@t @t])
    ;:  weld
      ^-  (list [@t @t])
      :~  ['X-GOOGLE-ID' gid]
          ['X-GOOGLE-UPDATED' (str item 'updated')]
      ==
      ^-  (list [@t @t])
      ?:(=('' tags) ~ ~[['CATEGORIES' tags]])
      ^-  (list [@t @t])
      ?~(rid ~ ~[[key.u.rid val.u.rid]])
    ==
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
::  ---- the other way: an entry to a Google event ----
++  rfc3339-of
  |=  d=@da
  ^-  tape
  =/  dt=tape  (dt-text:ics d)
  ::  YYYYMMDDTHHMMSS -> YYYY-MM-DDTHH:MM:SS
  ;:  weld
    (scag 4 dt)  "-"  (scag 2 (slag 4 dt))  "-"  (scag 2 (slag 6 dt))
    "T"  (scag 2 (slag 9 dt))  ":"  (scag 2 (slag 11 dt))  ":"  (scag 2 (slag 13 dt))
  ==
++  date-of
  |=  d=@da
  ^-  tape
  =/  t=tape  (date-text:ics d)
  :(weld (scag 4 t) "-" (scag 2 (slag 4 t)) "-" (scag 2 (slag 6 t)))
::  +time-json: a start or end object
++  time-json
  |=  [d=@da zone=(unit @t) all=?]
  ^-  json
  ?:  all  (pairs:enjs:format ~[['date' s+(crip (date-of d))]])
  ?~  zone  (pairs:enjs:format ~[['dateTime' s+(crip (weld (rfc3339-of d) "Z"))]])
  (pairs:enjs:format ~[['dateTime' s+(crip (rfc3339-of d))] ['timeZone' s+u.zone]])
::  +json-of: a parent entry as a Google event body. exdates are the
::  skipped occurrences realized by the caller.
++  json-of
  |=  [e=entry:cal exdates=(list @da)]
  ^-  json
  =/  ev=event:cal  event.e
  =/  m=meta:cal  ?-(-.ev %timed meta.ev, %allday meta.ev, %date meta.ev)
  =/  name=@t  (meta-str:cal m 'name')
  =/  base=(list [@t json])
    :~  ['summary' s+?:(=('' name) 'Untitled' name)]
        ['description' s+(meta-str:cal m 'note')]
        ['location' s+(meta-str:cal m 'location')]
        ['iCalUID' s+uid.e]
        :-  'reminders'
        %-  pairs:enjs:format
        :~  ['useDefault' b+|]
            :-  'overrides'
            :-  %a
            %+  murn  alarms.e
            |=  a=alarm:cal
            ^-  (unit json)
            ?.  ?=(%rel -.trigger.a)  ~
            `(pairs:enjs:format ~[['method' s+?:(=('email' desc.a) 'email' 'popup')] ['minutes' (numb:enjs:format (div before.trigger.a ~m1))]])
        ==
        :-  'extendedProperties'
        %-  pairs:enjs:format
        :_  ~
        :-  'private'
        %-  pairs:enjs:format
        :-  ['grubbery' s+'1']
        =/  tags=(list @t)  (meta-tags:cal m)
        ?~(tags ~ ~[['tags' s+(crip (sep-join:rr "," (turn tags trip)))]])
    ==
  =/  timing=(list [@t json])
    ?-    -.ev
        %date
      =/  d=@da  (fall (on-date:rules 2.000 month.ev day.ev) *@da)
      :~  ['start' (time-json d ~ &)]
          ['end' (time-json (add d ~d1) ~ &)]
          ['recurrence' [%a ~[s+'RRULE:FREQ=YEARLY']]]
      ==
        %allday
      =/  st=@da  start.recur.ev
      :~  ['start' (time-json st ~ &)]
          ['end' (time-json (add st (mul ~d1 (max 1 days.ev))) ~ &)]
      ==
        %timed
      =/  st=@da  start.recur.ev
      =/  en=@da
        ?-  -.fin.ev
          %to   end.fin.ev
          %dur  (add st d.fin.ev)
        ==
      :~  ['start' (time-json st zone.ev |)]
          ['end' (time-json en zone.ev |)]
      ==
    ==
  =/  recurrence=(list [@t json])
    ?:  ?=(%date -.ev)  ~
    =/  rc=recur:cal  recur.ev
    =/  dom=(unit @ud)  ?-(-.ev %timed dom.bound.ev, %allday dom.bound.ev)
    =/  rt=(unit @t)  (preset-rrule:ics name.kind.rc args.rc start.rc dom)
    ?~  rt  ~
    =/  zone=(unit @t)  ?:(?=(%timed -.ev) zone.ev ~)
    =/  ex=(list json)
      %+  turn  exdates
      |=  x=@da
      ^-  json
      ?:  ?=(%allday -.ev)  s+(crip "EXDATE;VALUE=DATE:{(date-text:ics x)}")
      ?~  zone  s+(crip "EXDATE:{(dt-text:ics x)}Z")
      s+(crip "EXDATE;TZID={(trip u.zone)}:{(dt-text:ics x)}")
    ~[['recurrence' [%a [s+(cat 3 'RRULE:' u.rt) ex]]]]
  (pairs:enjs:format :(weld base timing recurrence))
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
