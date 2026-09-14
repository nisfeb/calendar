::  rrule: RFC 5545 RRULE text as a rule kind
::
::  The engine asks a kind one question: what is occurrence idx of this
::  rule, anchored at start? Answering it in closed form is what keeps the
::  index walk linear, so the rule is read as periods (the day, week, month
::  or year of the start, advanced INTERVAL at a time) each holding a small
::  sorted list of candidate days from the BY-parts. idx names a period and
::  a slot in it. A slot that names a day the period does not have (the
::  31st of April, a fifth Monday) is ~, which the engine treats as a dead
::  index, the same way the shipped kinds do.
::
::  Read: FREQ DAILY|WEEKLY|MONTHLY|YEARLY, INTERVAL, COUNT, UNTIL, BYDAY
::  (with ordinals), BYMONTHDAY (negative from the end), BYMONTH, WKST.
::  Anything else present (BYHOUR, BYMINUTE, BYSECOND, BYSETPOS, BYWEEKNO,
::  BYYEARDAY, SECONDLY, MINUTELY, HOURLY) makes +parse answer ~: the rule
::  is kept as text by whoever holds it and produces no occurrences here,
::  rather than wrong ones.
::
::  Known deviation: COUNT is applied by the caller as a bound on idx, so a
::  rule whose periods hold non-existent days (BYMONTHDAY=31, monthly)
::  yields fewer real occurrences than COUNT. DAILY ignores BYMONTH and
::  BYDAY as limiters.
::
/<  rules  /lib/rules.hoon
|%
+$  freq   ?(%daily %weekly %monthly %yearly)
+$  byday  [ord=(unit @sd) day=wkd:rules]
+$  rule
  $:  =freq
      interval=@ud
      count=(unit @ud)
      until=(unit @da)
      byday=(list byday)
      bymonthday=(list @sd)
      bymonth=(list @ud)
      wkst=wkd:rules
  ==
++  supported
  ^-  (set @t)
  (sy ~['FREQ' 'INTERVAL' 'COUNT' 'UNTIL' 'BYDAY' 'BYMONTHDAY' 'BYMONTH' 'WKST'])
::  +parse: RRULE text to a rule, ~ when malformed or unsupported.
++  parse
  |=  t=@t
  ^-  (unit rule)
  =/  parts=(list [k=@t v=@t])
    %+  murn  (split ';' t)
    |=  p=@t
    =/  kv=(list @t)  (split '=' p)
    ?.  ?=([@ @ ~] kv)  ~
    `[(crip (cuss (trip i.kv))) i.t.kv]
  ?:  (lien parts |=([k=@t *] !(~(has in supported) k)))  ~
  =/  get  |=(k=@t ^-((unit @t) (bind (find-part parts k) |=([* v=@t] v))))
  =/  fq=(unit @t)  (get 'FREQ')
  ?~  fq  ~
  =/  fr=(unit freq)
    ?:  =('DAILY' u.fq)    `%daily
    ?:  =('WEEKLY' u.fq)   `%weekly
    ?:  =('MONTHLY' u.fq)  `%monthly
    ?:  =('YEARLY' u.fq)   `%yearly
    ~
  ?~  fr  ~
  =/  =freq  u.fr
  =/  interval=@ud  (max 1 (fall (bind (get 'INTERVAL') |=(v=@t (fall (rush v dem) 1))) 1))
  =/  count=(unit @ud)  (bind (get 'COUNT') |=(v=@t (fall (rush v dem) 0)))
  =/  until=(unit @da)  (bind (get 'UNTIL') parse-until)
  =/  byday=(list byday)
    %+  murn  (fall (bind (get 'BYDAY') |=(v=@t (split ',' v))) ~)
    parse-byday
  =/  bymonthday=(list @sd)
    %+  murn  (fall (bind (get 'BYMONTHDAY') |=(v=@t (split ',' v))) ~)
    parse-signed
  =/  bymonth=(list @ud)
    %+  murn  (fall (bind (get 'BYMONTH') |=(v=@t (split ',' v))) ~)
    |=(v=@t (rush v dem))
  =/  wkst=wkd:rules  (fall (biff (get 'WKST') parse-wkd) %mon)
  `[freq interval count until byday bymonthday bymonth wkst]
++  find-part
  |=  [parts=(list [k=@t v=@t]) k=@t]
  ^-  (unit [@t @t])
  ?~  parts  ~
  ?:(=(k k.i.parts) `i.parts $(parts t.parts))
++  split
  |=  [sep=@t t=@t]
  ^-  (list @t)
  =/  s=tape  (trip t)
  =/  c=@t  sep
  =|  cur=tape
  =|  out=(list @t)
  |-
  ?~  s  (flop [(crip (flop cur)) out])
  ?:  =(i.s c)  $(s t.s, cur ~, out [(crip (flop cur)) out])
  $(s t.s, cur [i.s cur])
++  parse-wkd
  |=  v=@t
  ^-  (unit wkd:rules)
  ?+  (crip (cuss (trip v)))  ~
    %'MO'  `%mon
    %'TU'  `%tue
    %'WE'  `%wed
    %'TH'  `%thu
    %'FR'  `%fri
    %'SA'  `%sat
    %'SU'  `%sun
  ==
::  +parse-byday: "MO", "2TU", "-1FR"
++  parse-byday
  |=  v=@t
  ^-  (unit byday)
  =/  s=tape  (trip v)
  ?:  (lth (lent s) 2)  ~
  =/  day=(unit wkd:rules)  (parse-wkd (crip (slag (sub (lent s) 2) s)))
  ?~  day  ~
  =/  head=tape  (scag (sub (lent s) 2) s)
  ?~  head  `[~ u.day]
  =/  ord=(unit @sd)  (parse-signed (crip head))
  ?~  ord  ~
  ?:  =(--0 u.ord)  ~
  `[ord u.day]
++  parse-signed
  |=  v=@t
  ^-  (unit @sd)
  =/  s=tape  (trip v)
  ?~  s  ~
  ?:  =('-' i.s)
    (bind (rush (crip t.s) dem) |=(n=@ud (new:si | n)))
  ?:  =('+' i.s)
    (bind (rush (crip t.s) dem) |=(n=@ud (new:si & n)))
  (bind (rush v dem) |=(n=@ud (new:si & n)))
::  +parse-until: YYYYMMDD or YYYYMMDDTHHMMSS[Z], read as UTC
++  parse-until
  |=  v=@t
  ^-  @da
  =/  s=tape  (trip v)
  =/  num  |=(t=tape ^-(@ud (fall (rush (crip t) dem) 0)))
  ?:  (lth (lent s) 8)  *@da
  =/  y=@ud  (num (scag 4 s))
  =/  m=@ud  (num (scag 2 (slag 4 s)))
  =/  d=@ud  (num (scag 2 (slag 6 s)))
  =/  base=@da  (fall (on-date:rules y m d) *@da)
  ?:  (lth (lent s) 15)  base
  =/  hh=@ud  (num (scag 2 (slag 9 s)))
  =/  mm=@ud  (num (scag 2 (slag 11 s)))
  =/  ss=@ud  (num (scag 2 (slag 13 s)))
  :(add base (mul hh ~h1) (mul mm ~m1) (mul ss ~s1))
::  +occurrence: occurrence idx of the rule anchored at start, as a naive
::  moment carrying start's time of day, or ~.
++  occurrence
  |=  [r=rule start=@da idx=@ud]
  ^-  (unit @da)
  =/  day0=@da  (day-floor:rules start)
  =/  tod=@dr  (sub start day0)
  =/  got=(unit @da)
    ?-  freq.r
      %daily    `(add day0 (mul ~d1 (mul interval.r idx)))
      %weekly   (weekly r day0 idx)
      %monthly  (monthly r day0 idx)
      %yearly   (yearly r day0 idx)
    ==
  ?~  got  ~
  =/  at=@da  (add u.got tod)
  ?:  &(?=(^ until.r) (gth at u.until.r))  ~
  ?:  (lth at start)  ~
  `at
::  +weekly: the week of the start, per WKST; BYDAY as offsets from the
::  week's first day; days in that week before the start are not
::  occurrences, so idx counts from the first candidate on or after it.
++  weekly
  |=  [r=rule day0=@da idx=@ud]
  ^-  (unit @da)
  =/  wstart=@da
    (sub day0 (mul ~d1 (mod (sub (add (weekday:rules day0) 7) (wkd-num:rules wkst.r)) 7)))
  =/  offsets=(list @ud)
    %+  sort
      ?~  byday.r  ~[(mod (sub (add (weekday:rules day0) 7) (wkd-num:rules wkst.r)) 7)]
      %+  turn  byday.r
      |=(b=byday (mod (sub (add (wkd-num:rules day.b) 7) (wkd-num:rules wkst.r)) 7))
    lth
  =/  n=@ud  (lent offsets)
  ?:  =(0 n)  ~
  =/  pre=@ud  (lent (skim offsets |=(o=@ud (lth (add wstart (mul o ~d1)) day0))))
  =/  g=@ud  (add idx pre)
  =/  period=@ud  (div g n)
  =/  slot=@ud  (snag (mod g n) offsets)
  `(add wstart (mul ~d1 (add (mul 7 (mul interval.r period)) slot)))
::  +month-candidates: the days of [y m] a monthly rule names, sorted
++  month-candidates
  |=  [r=rule y=@ud m=@ud default-dom=@ud]
  ^-  (list (unit @da))
  =/  len=@ud  (days-in-month:rules y m)
  ?^  bymonthday.r
    %+  turn  (sort bymonthday.r |=([a=@sd b=@sd] (lth (abs:si a) (abs:si b))))
    |=  d=@sd
    ^-  (unit @da)
    =/  dom=@ud  ?:((syn:si d) (abs:si d) (sub +(len) (min len (abs:si d))))
    (on-date:rules y m dom)
  ?^  byday.r
    %-  sort-days
    %-  zing
    %+  turn  byday.r
    |=  b=byday
    ^-  (list (unit @da))
    ?^  ord.b
      ~[(nth-of-month y m u.ord.b day.b)]
    %+  turn  (gulf 1 5)
    |=(k=@ud (nth-of-month y m (new:si & k) day.b))
  ~[(on-date:rules y m default-dom)]
++  sort-days
  |=  l=(list (unit @da))
  ^-  (list (unit @da))
  %+  sort  (skim l |=(u=(unit @da) ?=(^ u)))
  |=([a=(unit @da) b=(unit @da)] (lth (fall a *@da) (fall b *@da)))
::  +nth-of-month: the ord-th weekday of a month, negative from the end
++  nth-of-month
  |=  [y=@ud m=@ud ord=@sd w=wkd:rules]
  ^-  (unit @da)
  =/  n=@ud  (abs:si ord)
  ?:  |(=(0 n) (gth n 5))  ~
  =/  first=@da  (year [[%.y y] m 1 0 0 0 ~])
  =/  len=@ud  (days-in-month:rules y m)
  ?:  (syn:si ord)
    =/  shift=@ud  (mod (sub (add (wkd-num:rules w) 7) (weekday:rules first)) 7)
    =/  dom=@ud  (add +(shift) (mul 7 (dec n)))
    ?:((gth dom len) ~ (on-date:rules y m dom))
  =/  last=@da  (add first (mul ~d1 (dec len)))
  =/  back=@ud  (mod (sub (add (weekday:rules last) 7) (wkd-num:rules w)) 7)
  =/  dom-last=@ud  (sub len back)
  ?:  (lth dom-last (mul 7 (dec n)))  ~
  (on-date:rules y m (sub dom-last (mul 7 (dec n))))
++  monthly
  |=  [r=rule day0=@da idx=@ud]
  ^-  (unit @da)
  =/  =date  (yore day0)
  =/  cand0=(list (unit @da))  (month-candidates r y.date m.date d.t.date)
  =/  n=@ud  (lent cand0)
  ?:  =(0 n)  ~
  =/  pre=@ud  (lent (skim cand0 |=(u=(unit @da) &(?=(^ u) (lth u.u day0)))))
  =/  g=@ud  (add idx pre)
  =/  period=@ud  (div g n)
  =/  [y=@ud m=@ud]  (month-add:rules y.date m.date (mul interval.r period))
  =/  cand=(list (unit @da))  (month-candidates r y m d.t.date)
  ?:  (gte (mod g n) (lent cand))  ~
  (snag (mod g n) cand)
::  +yearly: BYMONTH (or the start's month) crossed with the monthly
::  candidates of each; the start's month and day when nothing is named.
++  yearly
  |=  [r=rule day0=@da idx=@ud]
  ^-  (unit @da)
  =/  =date  (yore day0)
  =/  months=(list @ud)  ?~(bymonth.r ~[m.date] (sort bymonth.r lth))
  =/  cands
    |=  y=@ud
    ^-  (list (unit @da))
    %-  zing
    %+  turn  months
    |=(m=@ud (month-candidates r y m d.t.date))
  =/  cand0=(list (unit @da))  (cands y.date)
  =/  n=@ud  (lent cand0)
  ?:  =(0 n)  ~
  =/  pre=@ud  (lent (skim cand0 |=(u=(unit @da) &(?=(^ u) (lth u.u day0)))))
  =/  g=@ud  (add idx pre)
  =/  period=@ud  (div g n)
  =/  cand=(list (unit @da))  (cands (add y.date (mul interval.r period)))
  ?:  (gte (mod g n) (lent cand))  ~
  (snag (mod g n) cand)
::  +to-text: a rule back to RRULE text, for the ICS writer
++  wkd-text
  |=  w=wkd:rules
  ^-  tape
  ?-(w %mon "MO", %tue "TU", %wed "WE", %thu "TH", %fri "FR", %sat "SA", %sun "SU")
++  sd-text
  |=  d=@sd
  ^-  tape
  ?:((syn:si d) (a-co:co (abs:si d)) ['-' (a-co:co (abs:si d))])
++  byday-text
  |=  b=byday
  ^-  tape
  (weld ?~(ord.b "" (sd-text u.ord.b)) (wkd-text day.b))
++  sep-join
  |=  [sep=tape ls=(list tape)]
  ^-  tape
  ?~  ls  ~
  ?~  t.ls  i.ls
  (weld i.ls (weld sep $(ls t.ls)))
++  to-text
  |=  r=rule
  ^-  @t
  =/  fq=tape
    ?-  freq.r
      %daily    "DAILY"
      %weekly   "WEEKLY"
      %monthly  "MONTHLY"
      %yearly   "YEARLY"
    ==
  =/  parts=(list tape)  ~[(weld "FREQ=" fq)]
  =?  parts  !=(1 interval.r)  (snoc parts (weld "INTERVAL=" (a-co:co interval.r)))
  =?  parts  ?=(^ count.r)  (snoc parts (weld "COUNT=" (a-co:co u.count.r)))
  =?  parts  ?=(^ until.r)  (snoc parts (weld "UNTIL=" (until-text u.until.r)))
  =/  bd=(list tape)  (turn byday.r byday-text)
  =?  parts  !=(~ bd)  (snoc parts (weld "BYDAY=" (sep-join "," bd)))
  =/  bmd=(list tape)  (turn bymonthday.r sd-text)
  =?  parts  !=(~ bmd)  (snoc parts (weld "BYMONTHDAY=" (sep-join "," bmd)))
  =/  bm=(list tape)  (turn bymonth.r |=(m=@ud (a-co:co m)))
  =?  parts  !=(~ bm)  (snoc parts (weld "BYMONTH=" (sep-join "," bm)))
  =?  parts  !=(%mon wkst.r)  (snoc parts (weld "WKST=" (wkd-text wkst.r)))
  (crip (sep-join ";" parts))
++  until-text
  |=  d=@da
  ^-  tape
  =/  =date  (yore d)
  =/  pad  |=(n=@ud ^-(tape ?:((lth n 10) ['0' (a-co:co n)] (a-co:co n))))
  ;:  weld
    (a-co:co y.date)  (pad m.date)  (pad d.t.date)
    "T"  (pad h.t.date)  (pad m.t.date)  (pad s.t.date)  "Z"
  ==
--
