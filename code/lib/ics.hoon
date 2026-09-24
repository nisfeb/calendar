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
/<  pytz   /lib/pytz.hoon
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
      cat=@t                    ::  X-GRUBBERY-CAT; 'todo' for a VTODO
      due=(unit when)           ::  VTODO DUE
      completed=(unit @da)      ::  VTODO COMPLETED
      status=@t                 ::  VTODO STATUS
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
  ?:  &(?=(^ out) |(=(' ' (cut 3 [0 1] i.trimmed)) =('\09' (cut 3 [0 1] i.trimmed))))
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
  ^-  (list [props=(list prop) alarms=(list (list prop)) todo=?])
  =|  out=(list [props=(list prop) alarms=(list (list prop)) todo=?])
  =|  cur=(unit [props=(list prop) alarms=(list (list prop)) todo=?])
  =|  alarm=(unit (list prop))
  |-
  ?~  lines  (flop out)
  =/  l=@t  i.lines
  ?:  =('BEGIN:VEVENT' l)
    $(lines t.lines, cur `[~ ~ |], alarm ~)
  ?:  =('BEGIN:VTODO' l)
    $(lines t.lines, cur `[~ ~ &], alarm ~)
  ?:  |(=('END:VEVENT' l) =('END:VTODO' l))
    ?~  cur  $(lines t.lines)
    =/  fin  [(flop props.u.cur) (flop alarms.u.cur) todo.u.cur]
    $(lines t.lines, cur ~, alarm ~, out [fin out])
  ?~  cur  $(lines t.lines)
  ?:  =('BEGIN:VALARM' l)
    $(lines t.lines, alarm `~)
  ?:  =('END:VALARM' l)
    ?~  alarm  $(lines t.lines)
    $(lines t.lines, alarm ~, cur `u.cur(alarms [(flop u.alarm) alarms.u.cur]))
  =/  t=tape  (trip l)
  =/  i=(unit @ud)  (name-end t)
  ?~  i  $(lines t.lines)
  =/  p=prop  [(crip (scag u.i t)) (crip (slag +(u.i) t))]
  ?^  alarm
    $(lines t.lines, alarm `[p u.alarm])
  $(lines t.lines, cur `u.cur(props [p props.u.cur]))
::  +name-end: where a content line's name and params end: the first
::  colon outside a quoted param value (ATTENDEE;CN="Doe: J":mailto:..)
++  name-end
  |=  t=tape
  ^-  (unit @ud)
  =/  i=@ud  0
  =/  q=?  |
  |-
  ?~  t  ~
  ?:  =('"' i.t)  $(t t.t, i +(i), q !q)
  ?:  &(!q =(':' i.t))  `i
  $(t t.t, i +(i))
::  +naive: a read moment as its wall clock, whatever its form
++  naive
  |=  w=when
  ^-  @da
  ?-(-.w %utc d.w, %local d.w, %day d.w)
::  +base-key: the property name without parameters (DTSTART;TZID=x
::  -> DTSTART)
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
  |=  [props=(list prop) alarms=(list (list prop)) todo=?]
  ^-  vevent
  =/  gv  |=(k=@t ^-(@t (fall (bind (get-prop props k) |=(p=prop (unescape v.p))) '')))
  =/  gr  |=(k=@t ^-(@t (fall (bind (get-prop props k) |=(p=prop v.p)) '')))
  ::  a VTODO: DUE, DURATION and COMPLETED are modeled; STATUS and
  ::  PERCENT-COMPLETE only when it is complete (an open task keeps its
  ::  IN-PROCESS and percent verbatim); DTSTART, RRULE and EXDATE ride
  ::  verbatim too, so a recurring or start-dated task goes back out
  ::  as it came. On a VEVENT STATUS stays extra.
  =/  eaten=(set @t)
    ?.  todo  consumed
    =/  base=(set @t)  (~(dif in consumed) (sy ~['DTSTART' 'RRULE' 'EXDATE']))
    =/  done=?  =('COMPLETED' (gr 'STATUS'))
    (~(gas in base) ?:(done ~['DUE' 'DURATION' 'COMPLETED' 'STATUS' 'PERCENT-COMPLETE'] ~['DUE' 'DURATION' 'COMPLETED']))
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
      (gv 'X-GRUBBERY-ARGS')
      ?:(todo 'todo' (gr 'X-GRUBBERY-CAT'))
      (parse-when props 'DUE')
      (bind (parse-when props 'COMPLETED') naive)
      (gr 'STATUS')
      (skip props |=(p=prop (~(has in eaten) (base-key k.p))))
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
  =/  late=?  !=('-' i.s)
  =/  d=@dr  (parse-duration v.u.tr)
  =/  end=?  =('END' (key-param k.u.tr 'RELATED'))
  ?:  &(!end |(!late =(~s0 d)))  `[[%rel d] desc]
  `[[%off end late d] desc]
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
  %+  murn  (split:rr ',' v.p)
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
  ::  floating time (no TZID) is local with no zone named; the reader
  ::  places it in the calendar's zone
  `[%local (key-param key 'TZID') d.u.dt]
::  +key-param: extract ;PARAM=value from a property key
++  key-param
  |=  [key=@t param=@t]
  ^-  @t
  =/  t=tape  (trip key)
  =/  needle=tape  ";{(trip param)}="
  =/  i=(unit @ud)  (find needle t)
  ?~  i  ''
  =/  rest=tape  (slag (add u.i (lent needle)) t)
  ::  a quoted value (TZID="America/New_York") is the text inside
  ?:  &(?=(^ rest) =('"' i.rest))
    (crip (scag (fall (find ~['"'] t.rest) (lent t.rest)) t.rest))
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
::  +unescape / +escape: TEXT values, RFC 5545 3.3.11
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
  ::  a fold never splits a UTF-8 character: back off while the next
  ::  octet continues one
  =.  take
    |-  ^-  @ud
    ?:  |((lte take 1) (gte (add at take) len))  take
    ?.  =(0x80 (dis 0xc0 (cut 3 [(add at take) 1] c)))  take
    $(take (dec take))
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
::  +preset-text: the RRULE a retired preset kind's args phrase (daily,
::  weekly, monthly, monthly-nth, yearly), ~ when they phrase none
++  preset-text
  |=  [kind=@ta args=(map @t json) start=@da]
  ^-  (unit tape)
  =/  a  ~(. ja:rules args)
  ?+    kind  ~
      %daily    `"FREQ=DAILY"
      %weekly
    =/  ds=(list wkd:rules)  (wkds:a 'days')
    ?~  ds  ~
    `(weld "FREQ=WEEKLY;BYDAY=" (sep-join:rr "," (turn ds wkd-text:rr)))
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
    `:(weld "FREQ=MONTHLY;BYDAY=" u.n (wkd-text:rr u.w))
      %yearly
    =/  d=@ud  (num:a 'day')
    ::  the month the kind read; the start's only when there is none
    =/  mo=@ud  =/(n (num:a 'month') ?:(=(0 n) m:(yore start) n))
    ?:(=(0 d) ~ `"FREQ=YEARLY;BYMONTH={(a-co:co mo)};BYMONTHDAY={(a-co:co d)}")
  ==
::  +cron-rule: a cron kind that fires once a day on a plain pattern (every
::  day, some weekdays, or some days of the month, every month) as RRULE
::  text and its time of day; ~ for anything richer
++  cron-rule
  |=  args=(map @t json)
  ^-  (unit [text=tape at=@dr])
  =/  a  ~(. ja:rules args)
  =/  mins=(list @ud)  (nums:a 'mins')
  =/  hrs=(list @ud)  (nums:a 'hrs')
  ?.  &(?=([@ ~] mins) ?=([@ ~] hrs))  ~
  ?.  (gte ~(wyt in (sy (nums:a 'mons'))) 12)  ~
  =/  doms=(set @ud)  (sy (nums:a 'doms'))
  =/  dows=(set @ud)  (sy (nums:a 'dows'))
  =/  at=@dr  (add (mul i.hrs ~h1) (mul i.mins ~m1))
  =/  day  |=(n=@ud (snag (mod n 7) `(list tape)`~["SU" "MO" "TU" "WE" "TH" "FR" "SA"]))
  ?:  &((gte ~(wyt in doms) 31) (gte ~(wyt in dows) 7))  `["FREQ=DAILY" at]
  ?:  (gte ~(wyt in doms) 31)
    `[(weld "FREQ=WEEKLY;BYDAY=" (sep-join:rr "," (turn (sort ~(tap in dows) lth) day))) at]
  ?:  (gte ~(wyt in dows) 7)
    `[(weld "FREQ=MONTHLY;BYMONTHDAY=" (sep-join:rr "," (turn (sort ~(tap in doms) lth) a-co:co))) at]
  ~
::  +as-rrule: a retired preset kind (daily, weekly, monthly, monthly-nth,
::  yearly; cron when +cron-rule phrases it) as the rrule kind, with the
::  same occurrences at the same indices, so skips and caps stay where
::  they were. The preset counted from the first day of its period
::  (the start's day, month or year) at the time its args named; the
::  rule starts there. Any other recur comes back as it was, and so does
::  a preset whose args phrase no rule.
++  as-rrule
  |=  rc=recur:cal
  ^-  recur:cal
  =/  kind=@ta  name.kind.rc
  ?.  ?=(?(%daily %weekly %monthly %monthly-nth %yearly %cron) kind)  rc
  =/  got=(unit [text=tape at=@dr])
    ?:  =(%cron kind)  (cron-rule args.rc)
    %+  bind  (preset-text kind args.rc start.rc)
    |=(t=tape [t (mins:~(. ja:rules args.rc) 'at')])
  ?~  got  rc
  =/  =date  (yore (day-floor:rules start.rc))
  =/  base=@da
    ?+  kind  (day-floor:rules start.rc)
      ?(%monthly %monthly-nth)  (year [[%.y y.date] m.date 1 0 0 0 ~])
      %yearly                   (year [[%.y y.date] 1 1 0 0 0 ~])
    ==
  [[/lib/rules %rrule] (~(put by *(map @t json)) 'rrule' s+(crip text.u.got)) (add base at.u.got)]
::  +preset-rrule: a kind and its args as RRULE text for export: the rrule
::  kind's own text, a whole-day `every`, or a retired preset's (read back
::  from an old export); ~ for one that has none (once, cron, an `every`
::  that is not whole days). COUNT is how many occurrences lie below the
::  bound (+count-of).
++  preset-rrule
  |=  [kind=@ta args=(map @t json) start=@da dom=(unit @ud)]
  ^-  (unit @t)
  =/  a  ~(. ja:rules args)
  =/  body=(unit tape)
    ?+    kind  (preset-text kind args start)
        %rrule    `(trip (str:a 'rrule'))
        %every
      =/  p=@dr  (mins:a 'period')
      ?:  |(=(~s0 p) !=(0 (mod p ~d1)))  ~
      `"FREQ=DAILY;INTERVAL={(a-co:co (div p ~d1))}"
    ==
  ?~  body  ~
  ?~  dom  `(crip u.body)
  ::  the cap is the count; an rrule's own COUNT or UNTIL gives way to
  ::  it (a series capped here, "this and following", ends there too)
  =/  own=(list tape)
    ?.  =(%rrule kind)  ~[u.body]
    %+  skip  (turn (split:rr ';' (crip u.body)) trip)
    |=(p=tape |(=("COUNT=" (cuss (scag 6 p))) =("UNTIL=" (cuss (scag 6 p)))))
  =/  n=@ud  (count-of [[/lib/rules kind] args start] u.dom)
  `(crip :(weld (sep-join:rr ";" own) ";COUNT=" (a-co:co n)))
::  +dom-of, +count-of: a COUNT as the index bound that holds that many
::  occurrences, and back. Only an rrule has slots with none (the 31st of
::  April); every other kind's indices are all occurrences.
++  dom-of
  |=  [rc=recur:cal n=@ud]
  ^-  @ud
  ?.  =(%rrule name.kind.rc)  n
  =/  r=(unit rule:rr)  (of-args:rr args.rc)
  ?~(r n (count-dom:rr u.r start.rc n))
++  count-of
  |=  [rc=recur:cal dom=@ud]
  ^-  @ud
  ?.  =(%rrule name.kind.rc)  dom
  =/  r=(unit rule:rr)  (of-args:rr args.rc)
  ?~(r dom (dom-count:rr u.r start.rc dom))
::  +series-wall: a read moment as the wall clock of a series in zone (~
::  is UTC). An EXDATE or RECURRENCE-ID in UTC, or in another zone, names
::  the series' instant only once it is moved there; a floating one, or
::  one in a zone pytz does not know, is the series' own wall already.
++  series-wall
  |=  [w=when zone=(unit @t)]
  ^-  @da
  ?-    -.w
    %day  d.w
    %utc  (wall:rules zone d.w)
  ::
      %local
    ?.  (known-zone:rules zone.w)  d.w
    ?:  =(`zone.w zone)  d.w
    (wall:rules zone (fall (place:rules `zone.w d.w) d.w))
  ==
::  +write-entry: one VEVENT. exdates are the skipped occurrences as
::  naive moments, realized by the caller through the kind.
++  write-entry
  |=  [e=entry:cal exdates=(list @da) now=@da]
  ^-  tape
  =/  ev=event:cal  event.e
  =/  m=meta:cal  (meta-of:cal ev)
  =/  bd=bound:cal  ?-(-.ev %timed bound.ev, %allday bound.ev, ?(%date %todo) *bound:cal)
  =/  comp=tape  ?:(?=(%todo -.ev) "VTODO" "VEVENT")
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
    ::  a task: DUE as a date when it sits on midnight, else a moment;
    ::  STATUS and COMPLETED say whether it is done
        %todo
      ;:  weld
        ^-  (list tape)
        ?~  due.ev  ~
        =/  d=@da  u.due.ev
        ::  a date only when there is no DATE-TIME start riding along
        ::  (RFC 5545 3.8.2.3: DUE and DTSTART share a value type)
        =/  st=(unit prop)  (get-prop props.e 'DTSTART')
        =/  timed-start=?  &(?=(^ st) ?=(~ (find "VALUE=DATE" (trip k.u.st))))
        =/  w=when  ?:(&(=(d (day-floor:rules d)) !timed-start) [%day d] [%utc d])
        =/  wt  (when-text w)
        ~[(line (weld "DUE" params.wt) value.wt)]
        ^-  (list tape)
        ?~  done.ev
          ::  an open task keeps the STATUS it came with
          ?^((get-prop props.e 'STATUS') ~ ~[(line "STATUS" "NEEDS-ACTION")])
        ::  ~1970.1.1 marks STATUS:COMPLETED read without a COMPLETED stamp
        :-  (line "STATUS" "COMPLETED")
        :-  (line "PERCENT-COMPLETE" "100")
        ?:(=(~1970.1.1 u.done.ev) ~ ~[(line "COMPLETED" (weld (dt-text u.done.ev) "Z"))])
      ==
    ==
  =/  recur-lines=(list tape)
    ?-    -.ev
        %todo  ~
        %date
      ~[(line "RRULE" "FREQ=YEARLY") (line "X-GRUBBERY-CAT" "date")]
        ?(%timed %allday)
      =/  rc=recur:cal  recur.ev
      =/  kind=@ta  name.kind.rc
      =/  rt=(unit @t)  (fall (mole |.((preset-rrule kind args.rc start.rc dom.bd))) ~)
      =/  zone=(unit @t)  ?:(?=(%timed -.ev) zone.ev ~)
      ;:  weld
        ?~(rt ~ ~[(line "RRULE" (trip u.rt))])
        ~[(line "X-GRUBBERY-KIND" (trip kind)) (line "X-GRUBBERY-ARGS" (escape (en:json:html [%o args.rc])))]
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
            %off
          %+  line  ?:(end.trigger.a "TRIGGER;RELATED=END" "TRIGGER")
          (weld ?:(late.trigger.a "" "-") (duration-text d.trigger.a))
        ==
        (line "DESCRIPTION" (escape ?:(=('' desc.a) (ms 'name') desc.a)))
        (weld "END:VALARM" crlf)
    ==
  %-  zing
  ;:  weld
    ~[(weld "BEGIN:" (weld comp crlf))]
    ::  the object's own UID: kept aside when a client stored it under
    ::  another name (+alias-object in the app), or an override child's
    ::  parent's, as RFC 5545 wants
    =/  own=(unit prop)  (get-prop props.e 'X-GRUBBERY-UID')
    =/  parent=(unit prop)  (get-prop props.e 'X-GRUBBERY-PARENT')
    ~[(line "UID" (trip ?^(own v.u.own ?^(parent v.u.parent uid.e))))]
    ~[(line "DTSTAMP" (weld (dt-text now) "Z"))]
    ~[(line "SEQUENCE" (a-co:co seq.e))]
    ~[(line "SUMMARY" (escape (ms 'name')))]
    ?:(=('' (ms 'location')) ~ ~[(line "LOCATION" (escape (ms 'location')))])
    ?:(=('' (ms 'note')) ~ ~[(line "DESCRIPTION" (escape (ms 'note')))])
    =/  tags=(list @t)  (meta-tags:cal m)
    ?~(tags ~ ~[(line "CATEGORIES" (sep-join:rr "," (turn tags |=(t=@t (escape t)))))])
    ?:(=('' (ms 'color')) ~ ~[(line "COLOR" (escape (ms 'color')))])
    timing
    recur-lines
    alarm-lines
    %+  turn
      %+  skip  props.e
      |=  p=prop
      ?|  =('X-GRUBBERY-PARENT' k.p)
          =('X-GRUBBERY-KIDS' k.p)
          =('X-GRUBBERY-UID' k.p)
          ::  the Google ids are this ship's bookkeeping, not the event's
          =("X-GOOGLE-" (scag 9 (trip k.p)))
          ?&  ?=(%todo -.ev)  ?=(^ done.ev)
              ?=(^ (find ~[(base-key k.p)] ~['STATUS' 'PERCENT-COMPLETE' 'COMPLETED']))
      ==  ==
    |=(p=prop (line (trip k.p) (trip v.p)))
    ~[(weld "END:" (weld comp crlf))]
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
::  +local-until: an RRULE's UNTIL in UTC (a Z on it) as the wall clock
::  of the event's zone, which the kind compares with its naive
::  occurrences; kept in args beside the rule, which goes out as it came
++  local-until
  |=  [rc=recur:cal zone=@t]
  ^-  recur:cal
  =/  text=@t  (str:~(. ja:rules args.rc) 'rrule')
  =/  u=(list @t)
    (skim (split:rr ';' text) |=(p=@t =("UNTIL=" (cuss (scag 6 (trip p))))))
  ?~  u  rc
  =/  v=tape  (slag 6 (trip i.u))
  ?.  &(?=(^ v) =('Z' (rear v)))  rc
  =/  r=(unit rule:rr)  (parse:rr text)
  ?~  r  rc
  ?~  until.u.r  rc
  =/  wall=(unit @da)  (bind (~(utc-to-tz zn:pytz zone) u.until.u.r) tail)
  ?~  wall  rc
  rc(args (~(put by args.rc) 'until_naive' (numb:enjs:format (da-to-ms:cal u.wall))))
::  +read-meta: name, note, location, tags, color of a read component.
::  CATEGORIES (RFC 5545) are the tags and COLOR (RFC 7986) the color;
::  they ride in meta, not props
++  read-meta
  |=  ve=vevent
  ^-  meta:cal
  =/  tags=(list @t)
    %-  zing
    %+  turn  (skim extra.ve |=(p=prop =('CATEGORIES' (base-key k.p))))
    |=(p=prop (split-categories v.p))
  =/  color=(unit prop)  (get-prop extra.ve 'COLOR')
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
    ^-  (list [@t json])
    ?~(color ~ ~[['color' s+(unescape v.u.color)]])
  ==
::  +meta-prop: a prop read into meta, so not kept verbatim as well
++  meta-prop  |=(p=prop ?=(?(%'CATEGORIES' %'COLOR') (base-key k.p)))
::  +to-entry: a read VEVENT as an entry (uid kept, etag and seq left for
::  +put-entry) plus its EXDATEs as naive moments of the series (for the
::  caller to map to indices through the kind). ~ when there is no usable
::  start. dz is the calendar's zone: a floating time, or a TZID pytz does
::  not know (a Windows name from Outlook, say), is read in it, not a
::  crash in the walker and not UTC.
++  to-entry
  |=  [ve=vevent dz=(unit @t)]
  ^-  (unit [e=entry:cal exdates=(list @da)])
  =/  zone-of  |=(z=@t ^-((unit @t) ?:((known-zone:rules z) `z dz)))
  =/  =meta:cal  (read-meta ve)
  =.  extra.ve  (skip extra.ve meta-prop)
  ::  a task: DUE (or DTSTART) is the due moment; COMPLETED or
  ::  STATUS:COMPLETED marks it done
  ?:  =('todo' cat.ve)
    ::  DUE, or DTSTART+DURATION (RFC 5545 3.6.2); a start alone is a
    ::  start, not a deadline. A zoned moment becomes absolute.
    =/  abs
      |=  w=when
      ^-  @da
      ?.  ?=(%local -.w)  (naive w)
      =/  z=(unit @t)  (zone-of zone.w)
      ?~  z  d.w
      (fall (place:rules z d.w) d.w)
    =/  due=(unit @da)
      ?^  due.ve  `(abs u.due.ve)
      ?:  &(?=(^ start.ve) ?=(^ duration.ve))  `(add (abs u.start.ve) u.duration.ve)
      ~
    =/  done=(unit @da)
      ?^  completed.ve  completed.ve
      ?:(=('COMPLETED' status.ve) `~1970.1.1 ~)
    `[[[%todo due done meta] uid.ve '' 0 alarms.ve extra.ve] ~]
  ?~  start.ve  ~
  =/  s=when  u.start.ve
  =/  sd=@da  (naive s)
  ::  a rule with its COUNT left out, for comparing two phrasings of it
  =/  bare  |=(t=@t (bind (parse:rr t) |=(r=rule:rr r(count ~))))
  ::  our own kind and args, only while the object still says what they
  ::  say: a client that moved the time or changed the repeat wins, and
  ::  the event becomes the rule the client wrote. A time-of-day kind
  ::  exported at midnight (before the first occurrence was the start)
  ::  still reads as ours. Args the kind cannot run are not ours either.
  =/  own-args=(unit (map @t json))
    ?:  |(=('' args.ve) =('' kind.ve))  ~
    =/  j=(unit json)  (de:json:html args.ve)
    ?.  ?=([~ %o *] j)  ~
    =/  kind=@ta  kind.ve
    =/  said=(unit (unit @t))  (mole |.((preset-rrule kind p.u.j sd ~)))
    ?~  said  ~
    =/  same-rule=?
      ?~  u.said  =('' rrule.ve)
      ?|  =(u.u.said rrule.ve)
          &(?=(^ (bare rrule.ve)) =((bare u.u.said) (bare rrule.ve)))
      ==
    ?.  same-rule  ~
    ?:  &(=(%every kind) =(~s0 (fall (mole |.((mins:~(. ja:rules p.u.j) 'period'))) ~s0)))  ~
    ?.  (~(has by p.u.j) 'at')  `p.u.j
    =/  tod=@dr  (sub sd (day-floor:rules sd))
    =/  at=(unit @dr)  (mole |.((mins:~(. ja:rules p.u.j) 'at')))
    ?.  &(?=(^ at) |(=(~s0 tod) =(tod u.at)))  ~
    `p.u.j
  ::  a retired preset read back from an old export becomes the rrule it
  ::  phrases (+as-rrule)
  =/  rc=recur:cal
    ?:  &(!=('' kind.ve) ?=(^ own-args))
      =/  own=recur:cal  [[/lib/rules kind.ve] u.own-args sd]
      (fall (mole |.((as-rrule own))) own)
    ?:  =('' rrule.ve)
      [[/lib/rules %once] ~ sd]
    [[/lib/rules %rrule] (~(put by *(map @t json)) 'rrule' s+rrule.ve) sd]
  ::  COUNT is how many occurrences there are: the bound is the index
  ::  that holds that many (+dom-of)
  =/  dom=(unit @ud)
    =/  n=(unit @ud)  ?:(=('' rrule.ve) ~ (biff (parse:rr rrule.ve) |=(r=rule:rr count.r)))
    ?~(n ~ `(dom-of rc u.n))
  =/  common  [uid.ve '' 0 alarms.ve extra.ve]
  ?:  =('date' cat.ve)
    =/  =date  (yore sd)
    `[[[%date m.date d.t.date meta] common] ~]
  ?:  |(?=(%day -.s) =('allday' cat.ve))
    =/  days=@ud
      ?~  end.ve  1
      ?.  ?=(%day -.u.end.ve)  1
      ?:  (lte d.u.end.ve sd)  1
      (max 1 (div (sub d.u.end.ve sd) ~d1))
    `[[[%allday rc days [dom ~] meta] common] (turn exdates.ve naive)]
  =/  zone=(unit @t)  ?:(?=(%local -.s) (zone-of zone.s) ~)
  =?  rc  &(?=(^ zone) =(%rrule name.kind.rc))  (local-until rc u.zone)
  =/  =fin:cal
    ?^  duration.ve  [%dur u.duration.ve]
    ?~  end.ve  [%dur ~s0]
    =/  ed=@da  (series-wall u.end.ve zone)
    ?:  =('' rrule.ve)  [%to ed]
    [%dur ?:((gth ed sd) (sub ed sd) ~s0)]
  :-  ~
  :-  [[%timed rc zone fin [dom ~] meta] common]
  (turn exdates.ve |=(w=when (series-wall w zone)))
--
