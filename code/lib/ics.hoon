::  ics: RFC 5545, read and written
::
::  Reading: unfolding, VEVENTs with their VALARMs, the three datetime
::  forms, RRULE as text, EXDATE, DURATION, and every property this app
::  does not model kept verbatim in `extra` so it goes back out unchanged.
::  Writing: one VEVENT per entry, DTSTART with TZID (Olson name, no
::  VTIMEZONE in this phase) or VALUE=DATE, DTEND or DURATION, RRULE from
::  the rule (presets translated, rrule verbatim), EXDATE, VALARM, the
::  app's own kind and args in X-GRUBBERY-* so its own export re-imports
::  without loss, then `extra` verbatim. Lines folded at 75 octets.
::
/<  rules  /lib/rules.hoon
/<  cal    /lib/calendar.hoon
/<  rr     /lib/rrule.hoon
|%
+$  when
  $%  [%utc d=@da]              ::  ...Z
      [%local zone=@t d=@da]    ::  ;TZID=... naive local moment
      [%day d=@da]              ::  VALUE=DATE, day-floored
  ==
+$  prop  [k=@t v=@t]
+$  vevent
  $:  uid=@t
      summary=@t
      location=@t
      description=@t
      start=(unit when)
      end=(unit when)
      duration=(unit @dr)
      rrule=@t                  ::  raw RRULE text; '' = single event
      exdates=(list when)
      alarms=(list alarm:cal)
      sequence=@ud
      kind=@t                   ::  X-GRUBBERY-KIND, '' when foreign
      args=@t                   ::  X-GRUBBERY-ARGS, json text
      cat=@t                    ::  X-GRUBBERY-CAT
      extra=(list prop)         ::  everything else, verbatim
  ==
::  the keys this reader consumes; anything else is `extra`
++  consumed
  ^-  (set @t)
  %-  sy
  ^-  (list @t)
  :~  'UID'  'SUMMARY'  'LOCATION'  'DESCRIPTION'  'DTSTART'  'DTEND'  'DURATION'
      'RRULE'  'EXDATE'  'SEQUENCE'  'DTSTAMP'  'CREATED'  'LAST-MODIFIED'
      'X-GRUBBERY-KIND'  'X-GRUBBERY-ARGS'  'X-GRUBBERY-CAT'
  ==
::  ---- reading ----
++  events
  |=  body=@t
  ^-  (list vevent)
  (turn (vevents (unfold body)) parse-vevent)
::  +unfold: split lines, strip \0d, join continuation lines
++  unfold
  |=  body=@t
  ^-  (list @t)
  =/  raw=(list @t)  (to-wain:format body)
  =/  trimmed=(list @t)
    %+  turn  raw
    |=  l=@t
    =/  len=@ud  (met 3 l)
    ?:  =(0 len)  l
    ?.  =(13 (cut 3 [(dec len) 1] l))  l
    (cut 3 [0 (dec len)] l)
  =/  out=(list @t)  ~
  |-
  ?~  trimmed  (flop out)
  ?:  &(?=(^ out) =(' ' (cut 3 [0 1] i.trimmed)))
    %=  $
      trimmed  t.trimmed
      out  [(cat 3 i.out (cut 3 [1 (dec (met 3 i.trimmed))] i.trimmed)) t.out]
    ==
  $(trimmed t.trimmed, out [i.trimmed out])
::  +vevents: each BEGIN:VEVENT..END:VEVENT as its properties in order,
::  with its VALARM blocks collected separately. Keys keep their
::  parameters ('DTSTART;TZID=...').
++  vevents
  |=  lines=(list @t)
  ^-  (list [props=(list prop) alarms=(list (list prop))])
  =|  out=(list [props=(list prop) alarms=(list (list prop))])
  =|  cur=(unit [props=(list prop) alarms=(list (list prop))])
  =|  alarm=(unit (list prop))
  |-
  ?~  lines  (flop out)
  =/  l=@t  i.lines
  ?:  =('BEGIN:VEVENT' l)
    $(lines t.lines, cur `[~ ~], alarm ~)
  ?:  =('END:VEVENT' l)
    ?~  cur  $(lines t.lines)
    =/  fin  [(flop props.u.cur) (flop alarms.u.cur)]
    $(lines t.lines, cur ~, alarm ~, out [fin out])
  ?~  cur  $(lines t.lines)
  ?:  =('BEGIN:VALARM' l)
    $(lines t.lines, alarm `~)
  ?:  =('END:VALARM' l)
    ?~  alarm  $(lines t.lines)
    $(lines t.lines, alarm ~, cur `u.cur(alarms [(flop u.alarm) alarms.u.cur]))
  =/  t=tape  (trip l)
  =/  i=(unit @ud)  (find ":" t)
  ?~  i  $(lines t.lines)
  =/  p=prop  [(crip (scag u.i t)) (crip (slag +(u.i) t))]
  ?^  alarm
    $(lines t.lines, alarm `[p u.alarm])
  $(lines t.lines, cur `u.cur(props [p props.u.cur]))
::  +base-key: the property name without parameters
++  base-key
  |=  k=@t
  ^-  @t
  =/  t=tape  (trip k)
  =/  i=(unit @ud)  (find ";" t)
  ?~(i k (crip (scag u.i t)))
::  +get-prop: first value (and full key) for a property name
++  get-prop
  |=  [props=(list prop) name=@t]
  ^-  (unit prop)
  ?~  props  ~
  ?:(=(name (base-key k.i.props)) `i.props $(props t.props))
++  all-props
  |=  [props=(list prop) name=@t]
  ^-  (list prop)
  (skim props |=(p=prop =(name (base-key k.p))))
++  parse-vevent
  |=  [props=(list prop) alarms=(list (list prop))]
  ^-  vevent
  =/  gv  |=(k=@t ^-(@t (fall (bind (get-prop props k) |=(p=prop (unescape v.p))) '')))
  =/  gr  |=(k=@t ^-(@t (fall (bind (get-prop props k) |=(p=prop v.p)) '')))
  :*  (gr 'UID')
      (gv 'SUMMARY')
      (gv 'LOCATION')
      (gv 'DESCRIPTION')
      (parse-when props 'DTSTART')
      (parse-when props 'DTEND')
      (bind (get-prop props 'DURATION') |=(p=prop (parse-duration v.p)))
      (gr 'RRULE')
      (parse-exdates props)
      (murn alarms parse-alarm)
      (fall (rush (gr 'SEQUENCE') dem) 0)
      (gr 'X-GRUBBERY-KIND')
      (gr 'X-GRUBBERY-ARGS')
      (gr 'X-GRUBBERY-CAT')
      (skip props |=(p=prop (~(has in consumed) (base-key k.p))))
  ==
++  parse-alarm
  |=  props=(list prop)
  ^-  (unit alarm:cal)
  =/  tr=(unit prop)  (get-prop props 'TRIGGER')
  ?~  tr  ~
  =/  desc=@t  (fall (bind (get-prop props 'DESCRIPTION') |=(p=prop (unescape v.p))) '')
  ?:  =('DATE-TIME' (key-param k.u.tr 'VALUE'))
    =/  dt=(unit [d=@da z=?])  (parse-dt v.u.tr)
    ?~  dt  ~
    `[[%abs d.u.dt] desc]
  =/  s=tape  (trip v.u.tr)
  ?~  s  ~
  =/  neg=?  =('-' i.s)
  =/  d=@dr  (parse-duration (crip ?:(neg t.s s)))
  `[[%rel ?:(neg d ~s0)] desc]
::  +parse-duration: P[nW][nD][T[nH][nM][nS]], leading sign ignored
++  parse-duration
  |=  v=@t
  ^-  @dr
  =/  s=tape  (trip v)
  =.  s  ?:(&(?=(^ s) |(=('-' i.s) =('+' i.s))) t.s s)
  ?.  &(?=(^ s) =('P' i.s))  ~s0
  =/  rest=tape  t.s
  =|  acc=@dr
  =|  num=@ud
  =|  time=?
  |-
  ?~  rest  acc
  ?:  =('T' i.rest)  $(rest t.rest, time &, num 0)
  ?:  &((gte i.rest '0') (lte i.rest '9'))
    $(rest t.rest, num (add (mul num 10) (sub i.rest '0')))
  =/  unit=@dr
    ?+  i.rest  ~s0
      %'W'  ~d7
      %'D'  ~d1
      %'H'  ~h1
      %'M'  ?:(time ~m1 ~s0)
      %'S'  ~s1
    ==
  $(rest t.rest, acc (add acc (mul num unit)), num 0)
++  parse-exdates
  |=  props=(list prop)
  ^-  (list when)
  %-  zing
  %+  turn  (all-props props 'EXDATE')
  |=  p=prop
  ^-  (list when)
  %+  murn  (split ',' v.p)
  |=  one=@t
  (when-of k.p one)
::  +parse-when: a DTSTART/DTEND property to a typed moment
++  parse-when
  |=  [props=(list prop) name=@t]
  ^-  (unit when)
  =/  hit=(unit prop)  (get-prop props name)
  ?~  hit  ~
  (when-of k.u.hit v.u.hit)
++  when-of
  |=  [key=@t val=@t]
  ^-  (unit when)
  =/  dt=(unit [d=@da z=?])  (parse-dt val)
  ?~  dt  ~
  ?:  =(8 (met 3 val))  `[%day d.u.dt]
  ?:  z.u.dt  `[%utc d.u.dt]
  =/  zone=@t  (key-param key 'TZID')
  ?:  =('' zone)  `[%utc d.u.dt]   ::  floating time: treat as UTC
  `[%local zone d.u.dt]
::  +key-param: extract ;PARAM=value from a property key
++  key-param
  |=  [key=@t param=@t]
  ^-  @t
  =/  t=tape  (trip key)
  =/  needle=tape  ";{(trip param)}="
  =/  i=(unit @ud)  (find needle t)
  ?~  i  ''
  =/  rest=tape  (slag (add u.i (lent needle)) t)
  =/  j=(unit @ud)  (find ";" rest)
  (crip ?~(j rest (scag u.j rest)))
::  +parse-dt: 'yyyymmdd' | 'yyyymmddThhmmss[Z]' -> [@da utc?]
++  parse-dt
  |=  v=@t
  ^-  (unit [d=@da z=?])
  =/  nu  |=([a=@ud b=@ud] (fall (rush (cut 3 [a b] v) dem) 0))
  =/  len=@ud  (met 3 v)
  =/  yy=@ud  (nu 0 4)
  =/  mm=@ud  (nu 4 2)
  =/  dd=@ud  (nu 6 2)
  ?:  |(=(0 yy) =(0 mm) =(0 dd) (gth mm 12) (gth dd 31))  ~
  ?:  =(8 len)
    `[(year [[%.y yy] mm [dd 0 0 0 ~]]) %.n]
  ?.  |(=(15 len) =(16 len))  ~
  ?.  =('T' (cut 3 [8 1] v))  ~
  =/  utc=?  &(=(16 len) =('Z' (cut 3 [15 1] v)))
  =/  d=@da
    (year [[%.y yy] mm [dd (nu 9 2) (nu 11 2) (nu 13 2) ~]])
  `[d utc]
++  split
  |=  [sep=@t t=@t]
  ^-  (list @t)
  =/  s=tape  (trip t)
  =|  cur=tape
  =|  out=(list @t)
  |-
  ?~  s  (flop [(crip (flop cur)) out])
  ?:  =(i.s sep)  $(s t.s, cur ~, out [(crip (flop cur)) out])
  $(s t.s, cur [i.s cur])
::  +unescape / +escape: TEXT values, RFC 5545 3.3.11
::  +key-name: a property key without its params (DTSTART;TZID=x -> DTSTART)
++  key-name
  |=  k=@t
  ^-  @t
  =/  t=tape  (trip k)
  =/  at=(unit @ud)  (find ";" t)
  ?~(at k (crip (scag u.at t)))
::  +split-categories: a CATEGORIES value on its unescaped commas, each
::  part unescaped and trimmed of spaces
++  split-categories
  |=  v=@t
  ^-  (list @t)
  =/  t=tape  (trip v)
  =|  cur=tape
  =|  out=(list tape)
  =/  parts=(list tape)
    |-
    ?~  t  (flop [(flop cur) out])
    ?:  &(=('\\' i.t) ?=(^ t.t))  $(t t.t.t, cur [i.t.t i.t cur])
    ?:  =(',' i.t)  $(t t.t, out [(flop cur) out], cur ~)
    $(t t.t, cur [i.t cur])
  %+  murn  parts
  |=  part=tape
  ^-  (unit @t)
  =/  u=@t  (unescape (crip part))
  =/  trimmed=tape  (trim-spaces (trip u))
  ?:(=(~ trimmed) ~ `(crip trimmed))
++  trim-spaces
  |=  t=tape
  ^-  tape
  (flop (skip-lead (flop (skip-lead t))))
++  skip-lead
  |=  t=tape
  ^-  tape
  ?~  t  ~
  ?:  =(' ' i.t)  $(t t.t)
  t
++  unescape
  |=  v=@t
  ^-  @t
  =/  s=tape  (trip v)
  =|  out=tape
  |-
  ?~  s  (crip (flop out))
  ?.  &(=('\\' i.s) ?=(^ t.s))  $(s t.s, out [i.s out])
  =/  c=@t  i.t.s
  =/  r=@t  ?:(|(=('n' c) =('N' c)) '\0a' c)
  $(s t.t.s, out [r out])
++  escape
  |=  v=@t
  ^-  tape
  =/  s=tape  (trip v)
  =|  out=tape
  |-
  ?~  s  (flop out)
  =/  c=@t  i.s
  ?:  =('\\' c)   $(s t.s, out ['\\' '\\' out])
  ?:  =(';' c)    $(s t.s, out [';' '\\' out])
  ?:  =(',' c)    $(s t.s, out [',' '\\' out])
  ?:  =('\0a' c)  $(s t.s, out ['n' '\\' out])
  ?:  =('\0d' c)  $(s t.s)
  $(s t.s, out [c out])
::  ---- writing ----
++  crlf  "\0d\0a"
::  +fold: a content line to folded lines, 75 octets each
++  fold
  |=  line=tape
  ^-  tape
  =/  c=@t  (crip line)
  =/  len=@ud  (met 3 c)
  =|  out=tape
  =/  at=@ud  0
  |-
  ?:  (gte at len)  out
  =/  take=@ud  (min (sub len at) ?:(=(0 at) 75 74))
  =/  piece=tape  (trip (cut 3 [at take] c))
  =/  chunk=tape  ?:(=(0 at) (weld piece crlf) :(weld " " piece crlf))
  $(at (add at take), out (weld out chunk))
++  pad2  |=(n=@ud ^-(tape ?:((lth n 10) ['0' (a-co:co n)] (a-co:co n))))
++  date-text
  |=  d=@da
  ^-  tape
  =/  =date  (yore d)
  :(weld (a-co:co y.date) (pad2 m.date) (pad2 d.t.date))
++  dt-text
  |=  d=@da
  ^-  tape
  =/  =date  (yore d)
  :(weld (date-text d) "T" (pad2 h.t.date) (pad2 m.t.date) (pad2 s.t.date))
::  +when-text: the property suffix (params) and value for a moment
++  when-text
  |=  w=when
  ^-  [params=tape value=tape]
  ?-  -.w
    %utc    ["" (weld (dt-text d.w) "Z")]
    %local  [";TZID={(trip zone.w)}" (dt-text d.w)]
    %day    [";VALUE=DATE" (date-text d.w)]
  ==
++  duration-text
  |=  d=@dr
  ^-  tape
  =/  secs=@ud  (div d ~s1)
  =/  days=@ud  (div secs 86.400)
  =/  hrs=@ud   (div (mod secs 86.400) 3.600)
  =/  mins=@ud  (div (mod secs 3.600) 60)
  =/  ss=@ud    (mod secs 60)
  ;:  weld
    "P"
    ?:(=(0 days) "" (weld (a-co:co days) "D"))
    ?:(&(=(0 hrs) =(0 mins) =(0 ss)) ?:(=(0 days) "T0S" "") "T")
    ?:(=(0 hrs) "" (weld (a-co:co hrs) "H"))
    ?:(=(0 mins) "" (weld (a-co:co mins) "M"))
    ?:(=(0 ss) "" (weld (a-co:co ss) "S"))
  ==
++  line
  |=  [k=tape v=tape]
  ^-  tape
  (fold :(weld k ":" v))
::  +preset-rrule: a shipped kind and its args as RRULE text, ~ when the
::  kind has no RRULE shape (once, cron, an `every` that is not whole
::  days). COUNT is appended from the bound.
++  preset-rrule
  |=  [kind=@ta args=(map @t json) start=@da dom=(unit @ud)]
  ^-  (unit @t)
  =/  a  ~(. ja:rules args)
  =/  wkd-text
    |=  w=wkd:rules
    ^-  tape
    ?-(w %mon "MO", %tue "TU", %wed "WE", %thu "TH", %fri "FR", %sat "SA", %sun "SU")
  =/  body=(unit tape)
    ?+    kind  ~
        %rrule    `(trip (str:a 'rrule'))
        %daily    `"FREQ=DAILY"
        %weekly
      =/  ds=(list wkd:rules)  (wkds:a 'days')
      ?~  ds  ~
      `(weld "FREQ=WEEKLY;BYDAY=" (sep-join:rr "," (turn ds wkd-text)))
        %monthly
      =/  d=@ud  (num:a 'day')
      ?:(=(0 d) ~ `"FREQ=MONTHLY;BYMONTHDAY={(a-co:co d)}")
        %monthly-nth
      =/  o=@t  (str:a 'ord')
      =/  w=(unit wkd:rules)  (rush (str:a 'day') (perk %mon %tue %wed %thu %fri %sat %sun ~))
      ?~  w  ~
      =/  n=(unit tape)
        ?+  o  ~
          %first   `"1"
          %second  `"2"
          %third   `"3"
          %fourth  `"4"
          %last    `"-1"
        ==
      ?~  n  ~
      `:(weld "FREQ=MONTHLY;BYDAY=" u.n (wkd-text u.w))
        %yearly
      =/  d=@ud  (num:a 'day')
      =/  =date  (yore start)
      ?:(=(0 d) ~ `"FREQ=YEARLY;BYMONTH={(a-co:co m.date)};BYMONTHDAY={(a-co:co d)}")
        %every
      =/  p=@dr  (mins:a 'period')
      ?:  |(=(~s0 p) !=(0 (mod p ~d1)))  ~
      `"FREQ=DAILY;INTERVAL={(a-co:co (div p ~d1))}"
    ==
  ?~  body  ~
  ?:  &(?=(^ dom) !=(%rrule kind))
    `(crip :(weld u.body ";COUNT=" (a-co:co u.dom)))
  `(crip u.body)
::  +write-entry: one VEVENT. exdates are the skipped occurrences as
::  naive moments, realized by the caller through the kind.
++  write-entry
  |=  [e=entry:cal exdates=(list @da) now=@da]
  ^-  tape
  =/  ev=event:cal  event.e
  =/  m=meta:cal  ?-(-.ev %timed meta.ev, %allday meta.ev, %date meta.ev)
  =/  bd=bound:cal  ?-(-.ev %timed bound.ev, %allday bound.ev, %date *bound:cal)
  =/  ms  |=(k=@t (meta-str:cal m k))
  =/  timing=(list tape)
    ?-    -.ev
        %timed
      =/  st  (when-text ?~(zone.ev [%utc start.recur.ev] [%local u.zone.ev start.recur.ev]))
      :-  (line (weld "DTSTART" params.st) value.st)
      ?-  -.fin.ev
          %dur  ~[(line "DURATION" (duration-text d.fin.ev))]
          %to
        =/  en  (when-text ?~(zone.ev [%utc end.fin.ev] [%local u.zone.ev end.fin.ev]))
        ~[(line (weld "DTEND" params.en) value.en)]
      ==
        %allday
      =/  st  (when-text [%day start.recur.ev])
      =/  en  (when-text [%day (add start.recur.ev (mul ~d1 (max 1 days.ev)))])
      ~[(line (weld "DTSTART" params.st) value.st) (line (weld "DTEND" params.en) value.en)]
        %date
      =/  st  (when-text [%day (fall (on-date:rules 2.000 month.ev day.ev) *@da)])
      ~[(line (weld "DTSTART" params.st) value.st)]
    ==
  =/  recur-lines=(list tape)
    ?-    -.ev
        %date
      ~[(line "RRULE" "FREQ=YEARLY") (line "X-GRUBBERY-CAT" "date")]
        ?(%timed %allday)
      =/  rc=recur:cal  recur.ev
      =/  kind=@ta  name.kind.rc
      =/  rt=(unit @t)  (preset-rrule kind args.rc start.rc dom.bd)
      =/  zone=(unit @t)  ?:(?=(%timed -.ev) zone.ev ~)
      ;:  weld
        ?~(rt ~ ~[(line "RRULE" (trip u.rt))])
        ~[(line "X-GRUBBERY-KIND" (trip kind)) (line "X-GRUBBERY-ARGS" (trip (en:json:html [%o args.rc])))]
        ?:(?=(%allday -.ev) ~[(line "X-GRUBBERY-CAT" "allday")] ~)
        %+  turn  exdates
        |=  x=@da
        =/  w=when  ?:(?=(%allday -.ev) [%day x] ?~(zone [%utc x] [%local u.zone x]))
        =/  wt  (when-text w)
        (line (weld "EXDATE" params.wt) value.wt)
      ==
    ==
  =/  alarm-lines=(list tape)
    %-  zing
    %+  turn  alarms.e
    |=  a=alarm:cal
    ^-  (list tape)
    :~  (weld "BEGIN:VALARM" crlf)
        (line "ACTION" "DISPLAY")
        ?-  -.trigger.a
          %rel  (line "TRIGGER" (weld "-" (duration-text before.trigger.a)))
          %abs  (line "TRIGGER;VALUE=DATE-TIME" (weld (dt-text at.trigger.a) "Z"))
        ==
        (line "DESCRIPTION" (escape ?:(=('' desc.a) (ms 'name') desc.a)))
        (weld "END:VALARM" crlf)
    ==
  %-  zing
  ;:  weld
    ~[(weld "BEGIN:VEVENT" crlf)]
    ~[(line "UID" (trip uid.e))]
    ~[(line "DTSTAMP" (weld (dt-text now) "Z"))]
    ~[(line "SEQUENCE" (a-co:co seq.e))]
    ~[(line "SUMMARY" (escape (ms 'name')))]
    ?:(=('' (ms 'location')) ~ ~[(line "LOCATION" (escape (ms 'location')))])
    ?:(=('' (ms 'note')) ~ ~[(line "DESCRIPTION" (escape (ms 'note')))])
    =/  tags=(list @t)  (meta-tags:cal m)
    ?~(tags ~ ~[(line "CATEGORIES" (sep-join:rr "," (turn tags |=(t=@t (escape t)))))])
    ?:(=('' (ms 'color')) ~ ~[(line "COLOR" (trip (ms 'color')))])
    timing
    recur-lines
    alarm-lines
    %+  turn  (skip props.e |=(p=prop =('X-GRUBBERY-PARENT' k.p)))
    |=(p=prop (line (trip k.p) (trip v.p)))
    ~[(weld "END:VEVENT" crlf)]
  ==
++  write-calendar
  |=  [name=@t bodies=(list tape)]
  ^-  @t
  %-  crip
  %-  zing
  ;:  weld
    ~[(weld "BEGIN:VCALENDAR" crlf)]
    ~[(line "VERSION" "2.0")]
    ~[(line "PRODID" "-//nisfeb//calendar//EN")]
    ~[(line "CALSCALE" "GREGORIAN")]
    ~[(line "X-WR-CALNAME" (escape name))]
    bodies
    ~[(weld "END:VCALENDAR" crlf)]
  ==
::  +to-entry: a read VEVENT as an entry (uid kept, etag and seq left for
::  +put-entry) plus its EXDATEs as naive moments for the caller to map to
::  indices through the kind. ~ when there is no usable start.
++  to-entry
  |=  [ve=vevent dz=(unit @t)]
  ^-  (unit [e=entry:cal exdates=(list @da)])
  ?~  start.ve  ~
  =/  s=when  u.start.ve
  =/  sd=@da  ?-(-.s %utc d.s, %local d.s, %day d.s)
  ::  CATEGORIES (RFC 5545) are the tags; they ride in meta, not props
  =/  tags=(list @t)
    %-  zing
    %+  turn  (skim extra.ve |=(p=prop =('CATEGORIES' (key-name k.p))))
    |=(p=prop (split-categories v.p))
  =.  extra.ve  (skip extra.ve |=(p=prop =('CATEGORIES' (key-name k.p))))
  =/  =meta:cal
    %-  ~(gas by *(map @t json))
    ^-  (list [@t json])
    ;:  weld
      ^-  (list [@t json])
      ~[['name' s+?:(=('' summary.ve) 'Untitled' summary.ve)]]
      ^-  (list [@t json])
      ?:(=('' location.ve) ~ ~[['location' s+location.ve]])
      ^-  (list [@t json])
      ?:(=('' description.ve) ~ ~[['note' s+description.ve]])
      ^-  (list [@t json])
      ?~(tags ~ ~[['tags' [%a (turn tags |=(t=@t `json`s+t))]]])
    ==
  =/  own-args=(unit (map @t json))
    ?:  =('' args.ve)  ~
    =/  j=(unit json)  (de:json:html args.ve)
    ?.(?=([~ %o *] j) ~ `p.u.j)
  =/  rc=recur:cal
    ?:  &(!=('' kind.ve) ?=(^ own-args))
      [[/lib/rules kind.ve] u.own-args sd]
    ?:  =('' rrule.ve)
      [[/lib/rules %once] ~ sd]
    [[/lib/rules %rrule] (~(put by *(map @t json)) 'rrule' s+rrule.ve) sd]
  =/  dom=(unit @ud)
    ?:  =('' rrule.ve)  ~
    =/  r=(unit rule:rr)  (parse:rr rrule.ve)
    ?~(r ~ count.u.r)
  =/  ex=(list @da)
    %+  turn  exdates.ve
    |=(w=when ?-(-.w %utc d.w, %local d.w, %day d.w))
  =/  common  [uid.ve '' 0 alarms.ve extra.ve]
  ?:  =('date' cat.ve)
    =/  =date  (yore sd)
    `[[[%date m.date d.t.date meta] common] ex]
  ?:  |(?=(%day -.s) =('allday' cat.ve))
    =/  days=@ud
      ?~  end.ve  1
      ?.  ?=(%day -.u.end.ve)  1
      (max 1 (div (sub d.u.end.ve sd) ~d1))
    `[[[%allday rc days [dom ~] meta] common] ex]
  ::  an unknown TZID falls back to UTC rather than a crash in the walker
  =/  zone=(unit @t)  ?:(&(?=(%local -.s) (known-zone:rules zone.s)) `zone.s ~)
  =/  =fin:cal
    ?^  duration.ve  [%dur u.duration.ve]
    ?~  end.ve  [%dur ~s0]
    =/  ed=@da  ?-(-.u.end.ve %utc d.u.end.ve, %local d.u.end.ve, %day d.u.end.ve)
    ?:  =('' rrule.ve)  [%to ed]
    [%dur ?:((gth ed sd) (sub ed sd) ~s0)]
  `[[[%timed rc zone fin [dom ~] meta] common] ex]
--
