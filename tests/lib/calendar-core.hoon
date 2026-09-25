::  Unit tests for /lib/calendar-core: the nexus's pure arms. What a poke
::  may put in (the v18 class: nothing unreadable is stored), where an
::  edit or a move lands, a share edit's version check, what a sync pass
::  pushes and suppresses, CalDAV paths, and which feed events a sync
::  deletes.
::
/+  *test, core=calendar-core, cal=calendar, ics, dav, tarball
|%
++  at  ~2026.11.2..10.00.00
++  ms  (da-to-ms:cal at)
++  obj  |=(l=(list [@t json]) ^-(json (pairs:enjs:format l)))
::  weld for json pairs: a dry gate, so a literal list is cast to the type
::  (weld is wet, and a literal ~[['k' s+'v']] mull-grows against it)
++  plus  |=([a=(list [@t json]) b=(list [@t json])] (weld a b))
++  meta  |=(n=@t ^-(json (obj ~[['name' s+n]])))
++  ev
  |=  n=@t
  ^-  event:cal
  [%timed [[/lib/rules %once] ~ at] ~ [%dur ~h1] [~ ~] (malt ~[['name' s+n]])]
++  ent  |=([n=@t u=@t] ^-(entry:cal [(ev n) u '' 0 ~ ~]))
::  a calendar with these calendars, each holding these entries
++  cals
  |=  l=(list [id=@ta es=(list entry:cal)])
  ^-  calendar:cal
  =/  c=calendar:cal  fresh-calendar:cal
  |-
  ?~  l  c
  =/  k=cal:cal  (roll es.i.l |=([e=entry:cal k=_fresh-cal:cal] (put-entry:cal k e)))
  $(l t.l, c c(cals (~(put by cals.c) id.i.l k)))
++  names
  |=  [c=calendar:cal id=@ta]
  ^-  (list @t)
  =/  k=(unit cal:cal)  (~(get by cals.c) id)
  ?~  k  ~
  (sort ~(tap in ~(key by entries.u.k)) aor)
::
::  ==  pokes
::
++  test-parse-event-refuses
  =/  base=(list [@t json])  ~[['cat' s+'allday'] ['start_ms' (numb:enjs:format ms)] ['span_days' (numb:enjs:format 1)]]
  ;:  weld
    ::  no name
    (expect-eq !>(~) !>((parse-event:core (obj (plus base ~[['kind' s+'once']])) ~)))
    ::  rrule args that are not text: refused, never stored
    %+  expect-eq  !>(~)
    !>((parse-event:core (obj (plus base ~[['meta' (meta 'x')] ['kind' s+'rrule'] ['args' (obj ~[['rrule' (numb:enjs:format 5)]])]])) ~))
    ::  a kind that is not a term, and no start
    (expect-eq !>(~) !>((parse-event:core (obj (plus base ~[['meta' (meta 'x')] ['kind' s+'Once!']])) ~)))
    (expect-eq !>(~) !>((parse-event:core (obj ~[['cat' s+'timed'] ['meta' (meta 'x')] ['kind' s+'once']]) ~)))
    ::  a preset whose args phrase no rule is refused (a weekday it cannot read)
    %+  expect-eq  !>(~)
    !>((parse-recur:core (obj ~[['kind' s+'weekly'] ['start_ms' (numb:enjs:format ms)] ['args' (obj ~[['days' a+~[s+'Monday']]])]])))
  ==
::
++  test-parse-event-reads
  =/  timed
    |=  zone=@t
    %+  parse-event:core
      %-  obj
      :~  ['cat' s+'timed']  ['meta' (meta 'x')]  ['kind' s+'once']  ['zone' s+zone]
          ['start_ms' (numb:enjs:format ms)]  ['fin' s+'dur']  ['dur_min' (numb:enjs:format 30)]
      ==
    `'Europe/Berlin'
  ::  ~ when the poke was refused, else the zone it stored
  =/  z  |=(e=(unit event:cal) ^-((unit (unit @t)) ?.(?=([~ %timed *] e) ~ `zone.u.e)))
  ;:  weld
    (expect-eq !>(``'America/New_York') !>((z (timed 'America/New_York'))))
    ::  no zone, or one pytz does not know: the calendar's
    (expect-eq !>(``'Europe/Berlin') !>((z (timed ''))))
    (expect-eq !>(``'Europe/Berlin') !>((z (timed 'Mars/Olympus'))))
    (expect-eq !>([~ ~]) !>((z (timed 'none'))))
    ::  a date is month and day
    %+  expect-eq  !>(`[%date 3 14 (malt ~[['name' s+'pi']])])
    !>((parse-event:core (obj ~[['cat' s+'date'] ['meta' (meta 'pi')] ['month' (numb:enjs:format 3)] ['day' (numb:enjs:format 14)]]) ~))
  ==
::
++  test-parse-event-count-and-preset
  ::  a weekly preset from an older client becomes the rrule it phrases,
  ::  and count 3 is the bound that holds three occurrences
  =/  e
    %+  parse-event:core
      %-  obj
      :~  ['cat' s+'allday']  ['meta' (meta 'x')]  ['kind' s+'weekly']
          ['args' (obj ~[['days' a+~[s+'mon']]])]  ['start_ms' (numb:enjs:format ms)]
          ['span_days' (numb:enjs:format 1)]  ['count' (numb:enjs:format 3)]
      ==
    ~
  ?>  ?=([~ %allday *] e)
  ;:  weld
    (expect-eq !>(%rrule) !>(name.kind.recur.u.e))
    (expect-eq !>(`3) !>(dom.bound.u.e))
  ==
::
::  ==  where an edit lands
::
++  test-put-ev-in
  =/  c  (cals ~[[%a ~[(ent 'one' 'u1')]] [%b ~]])
  =/  moved  (put-ev-in:core c `%b '' 'u1' (ev 'moved'))
  =/  both  (cals ~[[%a ~[(ent 'one' 'u1')]] [%b ~[(ent 'theirs' 'u1')]]])
  ;:  weld
    ::  a move: out of a, into b
    (expect-eq !>(~) !>((names moved %a)))
    (expect-eq !>(~['u1']) !>((names moved %b)))
    ::  a move onto a UID b already holds changes nothing
    (expect-eq !>(both) !>((put-ev-in:core both `%b 'a' 'u1' (ev 'over'))))
    ::  an unknown target: it stays where it lives
    (expect-eq !>(~['u1']) !>((names (put-ev-in:core c `%nope '' 'u1' (ev 'x')) %a)))
    ::  a new id with no target goes to %default
    (expect-eq !>(~['u9']) !>((names (put-ev-in:core c ~ '' 'u9' (ev 'new')) %default)))
  ==
::
++  test-locate-and-keys
  =/  c  (cals ~[[%a ~[(ent 'in a' 'u')]] [%b ~[(ent 'in b' 'u')]]])
  ;:  weld
    (expect-eq !>(`%b) !>((bind (locate:core c %b 'u') head)))
    (expect-eq !>(`%a) !>((bind (locate:core c %a 'u') head)))
    (expect !>(?=(^ (locate:core c '' 'u'))))
    (expect-eq !>(~) !>((locate:core c %a 'nobody')))
    ::  the same UID in two calendars is two keys
    (expect-eq !>(2) !>(~(wyt by (keyed:core c))))
    (expect-eq !>([%cal 'uid']) !>((unkey:core 'cal/uid')))
    (expect-eq !>([%cal 'a/b']) !>((unkey:core 'cal/a/b')))
    (expect-eq !>(['' 'plain']) !>((unkey:core 'plain')))
  ==
::
::  ==  sharing
::
++  test-share-base-ok
  =/  writes=json  (obj ~[['c' (obj ~[['u' (obj ~[['~zod' s+'H1']])]])]])
  =/  cur  |=(t=@t `(unit entry:cal)``[(ev 'x') 'u' t 0 ~ ~])
  ;:  weld
    ::  no base: a new object, or a peer on older code
    (expect !>((share-base-ok:core writes %c 'u' ~zod '' (cur 'H9'))))
    ::  the host still has the version the peer pulled
    (expect !>((share-base-ok:core writes %c 'u' ~zod 'H0' (cur 'H0'))))
    ::  the host has what this peer's own last write left
    (expect !>((share-base-ok:core writes %c 'u' ~zod 'H0' (cur 'H1'))))
    ::  an edit since, by the host or another peer: refused
    (expect !>(!(share-base-ok:core writes %c 'u' ~zod 'H0' (cur 'H2'))))
    (expect !>(!(share-base-ok:core writes %c 'u' ~bus 'H0' (cur 'H1'))))
    ::  deleted on the host since the pull: refused
    (expect !>(!(share-base-ok:core writes %c 'u' ~zod 'H0' ~)))
    (expect !>((has-objects:core (obj ~[['objects' (obj ~)]]))))
    (expect !>(!(has-objects:core (obj ~))))
    (expect !>(!(has-objects:core (obj ~[['objects' a+~]]))))
  ==
::
::  ==  what a sync pass pushes
::
++  test-changes-since
  =/  k=cal:cal  (roll `(list entry:cal)`~[(ent 'one' 'u1') (ent 'two' 'u2')] |=([e=entry:cal k=_fresh-cal:cal] (put-entry:cal k e)))
  =.  k  (del-entry:cal k 'u1')
  ::  an override child of u2: its change is its parent's
  =.  k  (put-entry:cal k [(ev 'kid') 'u2#r' '' 0 ~ ~[['X-GRUBBERY-PARENT' 'u2']]])
  =/  all  (sort (changes-since:core k 0 ~) aor)
  =/  rows  (since-log:core k 0)
  =/  u2-rows=(set [@t @ud])  (~(gas in *(set [@t @ud])) (murn rows |=([key=@ud val=logent:cal] ?.(=('u2' uid.val) ~ `[uid.val key]))))
  ;:  weld
    (expect-eq !>(~[['u1' %del] ['u2' %put]]) !>(all))
    ::  past the watermark only
    (expect-eq !>(~) !>((changes-since:core k seq.k ~)))
    ::  a pass's own writes (suppressed) are not pushed back
    (expect-eq !>(~[['u1' %del]]) !>((changes-since:core k 0 u2-rows)))
    (expect-eq !>((sy ~['u1' 'u2' 'u2#r'])) !>((pending-uids:core k 0 ~)))
    (expect-eq !>((sy ~['u1' 'u2#r'])) !>((pending-uids:core k 0 u2-rows)))
  ==
::
++  test-child-row
  =/  k=cal:cal  (put-entry:cal fresh-cal:cal (ent 'p' 'p'))
  ;:  weld
    ::  a deleted child, named <parent>#<recurrence-id>, whose parent is here
    (expect !>((child-row:core k 'p#20261102' ~)))
    ::  or went in the same rows
    (expect !>((child-row:core fresh-cal:cal 'q#1' (sy ~['q']))))
    ::  a real UID with a # and no such parent is an object of its own
    (expect !>(!(child-row:core k 'a#b' ~)))
  ==
::
++  test-suppressed-round-trip
  =/  sup=(set [@t @ud])  (sy ~[['a' 3] ['b' 7] ['c' 9]])
  =/  row=json  (obj ~[['suppressed' (suppress-json:core sup 3)]])
  ;:  weld
    ::  rows at or under the watermark are pruned; the rest read back
    (expect-eq !>((sy ~[['b' 7] ['c' 9]])) !>((suppressed:core row)))
    (expect-eq !>(~) !>((suppressed:core (obj ~[['suppressed' s+'junk']]))))
  ==
::
++  test-wrote-between
  =/  k=cal:cal  (roll `(list entry:cal)`~[(ent 'a' 'a') (ent 'b' 'b') (ent 'c' 'c')] |=([e=entry:cal k=_fresh-cal:cal] (put-entry:cal k e)))
  =/  keys  (turn (since-log:core k 0) head)
  ?>  ?=([@ @ @ ~] keys)
  (expect-eq !>((sy ~[['b' i.t.keys] ['c' i.t.t.keys]])) !>((wrote-between:core k i.keys i.t.t.keys)))
::
++  test-google-stop
  =/  err  |=(r=@t (obj ~[['error' (obj ~[['errors' a+~[(obj ~[['reason' s+r]])]]])]]))
  ;:  weld
    (expect !>((google-stop:core 0 ~)))
    (expect !>((google-stop:core 500 ~)))
    (expect !>((google-stop:core 503 ~)))
    (expect !>((google-stop:core 429 ~)))
    (expect !>((google-stop:core 401 ~)))
    (expect !>((google-stop:core 403 (err 'rateLimitExceeded'))))
    (expect !>(!(google-stop:core 403 (err 'forbiddenForNonOrganizer'))))
    (expect !>(!(google-stop:core 404 ~)))
    (expect !>(!(google-stop:core 412 ~)))
  ==
::
::  ==  CalDAV paths
::
++  test-dav-paths
  ;:  weld
    (expect-eq !>([%principal ~]) !>((dav-resolve:core ~)))
    (expect-eq !>([%principal ~]) !>((dav-resolve:core `path`~[''])))
    (expect-eq !>([%home ~]) !>((dav-resolve:core /cal)))
    (expect-eq !>([%calendar %work]) !>((dav-resolve:core /cal/work)))
    (expect-eq !>([%object %work 'a@b']) !>((dav-resolve:core `path`~[%cal %work 'a@b.ics'])))
    (expect-eq !>([%object %work 'x']) !>((dav-resolve:core /cal/work/x)))
    (expect-eq !>([%none ~]) !>((dav-resolve:core /cal/work/a/b)))
    (expect-eq !>([%none ~]) !>((dav-resolve:core /elsewhere)))
    ::  hrefs from a request body: percent-decoded, absolute or not
    (expect-eq !>([%object %work 'a@b']) !>((dav-href-res:core "/apps/calendar/dav/cal/work/a%40b.ics")))
    (expect-eq !>([%home ~]) !>((dav-href-res:core "https://ship.example/apps/calendar/dav/cal/")))
    (expect-eq !>([%none ~]) !>((dav-href-res:core "/apps/other/dav/cal/")))
    (expect-eq !>('abc') !>((dav-unquote:core '"abc"')))
    (expect-eq !>('abc') !>((dav-unquote:core 'W/"abc"')))
  ==
::
++  test-cross-site
  =/  req  |=(h=(list [@t @t]) =/(r *inbound-request:eyre r(header-list.request h)))
  ;:  weld
    (expect !>((cross-site:core (req ~[['sec-fetch-site' 'cross-site']]))))
    (expect !>((cross-site:core (req ~[['sec-fetch-site' 'same-site']]))))
    (expect !>(!(cross-site:core (req ~[['sec-fetch-site' 'same-origin']]))))
    (expect !>(!(cross-site:core (req ~))))
  ==
::
::  ==  feeds
::
++  test-apply-feeds
  =/  fe
    |=  [n=@t feed=@t]
    ^-  event:cal
    [%timed [[/lib/rules %once] ~ at] ~ [%dur ~h1] [~ ~] (malt ~[['name' s+n] ['feed' s+feed]])]
  =/  c  %-  cals
    :~  :-  %default
        :~  [(fe 'a gone' 'a') 'fa1' '' 0 ~ ~]  [(fe 'a kept' 'a') 'fa2' '' 0 ~ ~]
            [(fe 'b' 'b') 'fb1' '' 0 ~ ~]  (ent 'mine' 'm1')
    ==  ==
  ::  feed a answered holding fa2 (out of the window, so seen but not got)
  ::  and a new fa3; feed b did not answer
  =/  res=feed-sync:core  [(malt ~[[%fa3 (fe 'a new' 'a')]]) (sy ~[%fa2 %fa3]) (sy ~['a']) 0]
  (expect-eq !>(~['fa2' 'fa3' 'fb1' 'm1']) !>((names ((apply-feeds:core res) c) %default)))
::
::  ==  CalDAV auth, verbs, XML
::
++  basic  |=(t=@t ^-(@t (cat 3 'Basic ' (en:base64:mimes:html (as-octs:mimes:html t)))))
++  req
  |=  [m=@t h=(list [@t @t])]
  ^-  inbound-request:eyre
  ::  the bunt's authenticated is %.y (a loobean bunts to yes): a
  ::  request from outside is %.n
  =/  r  *inbound-request:eyre
  r(authenticated |, method.request `method:http`;;(method:http m), header-list.request h)
::
++  test-dav-authed
  =/  clients=json  [%a ~[(obj ~[['salt' s+'s1'] ['hash' s+(dav-hash:core 's1' 'pw')]])]]
  =/  au  |=(h=(list [@t @t]) (dav-authed:core (req 'GET' h) clients))
  ;:  weld
    ::  the owner's cookie
    (expect !>((dav-authed:core =/(r (req 'GET' ~) r(authenticated &)) clients)))
    ::  a minted password, whatever the user name
    (expect !>((au ~[['authorization' (basic 'phone:pw')]])))
    (expect !>((au ~[['authorization' (basic ':pw')]])))
    (expect !>((au ~[['authorization' (cat 3 'basic ' (en:base64:mimes:html (as-octs:mimes:html 'x:pw')))]])))
    ::  and nothing else
    (expect !>(!(au ~)))
    (expect !>(!(au ~[['authorization' (basic 'phone:wrong')]])))
    (expect !>(!(au ~[['authorization' (basic 'phone:')]])))
    (expect !>(!(au ~[['authorization' (basic 'no-colon')]])))
    (expect !>(!(au ~[['authorization' 'Bearer pw']])))
    (expect !>(!(au ~[['authorization' 'Basic']])))
    (expect !>(!(au ~[['authorization' 'Basic !!!notbase64']])))
    (expect !>(!(dav-authed:core (req 'GET' ~[['authorization' (basic 'u:pw')]]) [%a ~])))
  ==
::
++  test-dav-verb-and-password
  =/  pw=tape  (dav-password:core 0v1a.2b3c4.d5e6f.g7h8i.j9k0l)
  ;:  weld
    (expect-eq !>('GET') !>((dav-verb:core (req 'GET' ~))))
    (expect-eq !>('POST') !>((dav-verb:core (req 'POST' ~))))
    ::  a proxy's override, upper-cased; only on a POST
    (expect-eq !>('PROPFIND') !>((dav-verb:core (req 'POST' ~[['x-http-method-override' 'propfind']]))))
    (expect-eq !>('PUT') !>((dav-verb:core (req 'PUT' ~[['x-http-method-override' 'DELETE']]))))
    ::  a password is 20-24 characters, never a dot
    (expect !>(&((gte (lent pw) 20) (lte (lent pw) 24))))
    (expect !>(?=(~ (find "." pw))))
    (expect-eq !>(pw) !>((dav-password:core 0v1a.2b3c4.d5e6f.g7h8i.j9k0l)))
  ==
::
++  test-dav-props
  =/  c  (cals ~[[%work ~[(ent 'one' 'u1')]]])
  =/  names  |=(l=(list [n=@tas *]) (turn l head))
  ;:  weld
    (expect-eq !>(~) !>((dav-props-for:core ~zod c [%none ~])))
    (expect-eq !>(6) !>((lent (dav-props-for:core ~zod c [%principal ~]))))
    (expect-eq !>(3) !>((lent (dav-props-for:core ~zod c [%home ~]))))
    (expect-eq !>(~) !>((dav-props-for:core ~zod c [%calendar %nope])))
    (expect !>(?=(^ (find ~[%'sync-token'] (names (dav-props-for:core ~zod c [%calendar %work]))))))
    (expect-eq !>(~) !>((dav-props-for:core ~zod c [%object %work 'nobody'])))
    (expect-eq !>(~[%resourcetype %getetag %getcontenttype]) !>((names (dav-props-for:core ~zod c [%object %work 'u1']))))
    ::  asked props: found, and the ones it lacks named as missing
    %+  expect-eq
      !>((response:dav "/x/" (turn (skim (dav-props-for:core ~zod c [%home ~]) |=([n=@tas *] =(%displayname n))) tail) ~[%bogus]))
    !>((dav-response:core ~zod c [%home ~] "/x/" ~[%displayname %bogus]))
    %+  expect-eq
      !>((response:dav "/x/" (turn (dav-props-for:core ~zod c [%home ~]) tail) ~))
    !>((dav-response:core ~zod c [%home ~] "/x/" ~))
  ==
::
++  test-hrefs
  ;:  weld
    (expect-eq !>(`"/a/b.ics") !>((dav-href-path:core "https://ship.example/a/b.ics")))
    (expect-eq !>(`"/a/b.ics") !>((dav-href-path:core "HTTP://ship.example/a/b.ics")))
    (expect-eq !>(`"/") !>((dav-href-path:core "https://ship.example")))
    (expect-eq !>(`"/a b.ics") !>((dav-href-path:core "  /a b.ics \0a")))
    (expect-eq !>(~) !>((dav-href-path:core "/a\0db.ics")))
    (expect-eq !>(`"/a/b.ics") !>((response-href:core (response:dav "/a/b.ics" ~ ~))))
    (expect-eq !>(`"/x.ics") !>((response-href:core (response:dav "/x.ics" ~ ~))))
    (expect-eq !>(~) !>((response-href:core (response:dav "/a/" ~ ~))))
    (expect-eq !>(~) !>((response-href:core (response:dav "ics" ~ ~))))
    (expect-eq !>("a/") !>((with-slash:core "a")))
    (expect-eq !>("a/") !>((with-slash:core "a/")))
    (expect-eq !>("/") !>((with-slash:core "")))
    (expect-eq !>([%object %w '']) !>((dav-resolve:core `path`~[%cal %w '.ics'])))
    (expect-eq !>([%object %w 'ics']) !>((dav-resolve:core `path`~[%cal %w 'ics'])))
  ==
::
::  ==  reminders
::
++  alarm-at
  |=  [als=(list alarm:cal) e=event:cal]
  ^-  (map eid:cal entry:cal)
  (malt ~[[%e [e 'e' '' 0 als ~]]])
++  ref  |=(idx=@ud ^-(ref:cal [%e idx [at (add at ~h1)]]))
++  pushes
  |=  [als=(list alarm:cal) from=@da now=@da]
  (alarm-pushes:core ~[(ref 2)] (alarm-at als (ev 'standup')) from now ~)
::
++  test-alarm-window
  =/  ten=(list alarm:cal)  ~[[[%rel ~m10] '']]
  ;:  weld
    ::  due at start - 10 min: in (from, now], so from is out and now is in
    %+  expect-eq  !>(~[['standup' 'in 10 min' 'cal-e-2-0']])
    !>((pushes ten (sub at ~m11) (sub at ~m10)))
    (expect-eq !>(~) !>((pushes ten (sub at ~m10) (sub at ~m9))))
    (expect-eq !>(~) !>((pushes ten (sub at ~m12) (sub at ~m11))))
    ::  its own text, when it has one
    %+  expect-eq  !>(~[['standup' 'bring notes' 'cal-e-2-0']])
    !>((pushes ~[[[%rel ~m10] 'bring notes']] (sub at ~m11) (sub at ~m10)))
    ::  the second alarm of an entry is -1
    %+  expect-eq  !>(~[['standup' 'starting now' 'cal-e-2-1']])
    !>((pushes ~[[[%rel ~m10] ''] [[%rel ~s0] '']] (sub at ~s1) at))
    ::  an alarm before the epoch of time fires nowhere
    (expect-eq !>(~) !>((pushes ~[[[%rel (add at ~d1)] '']] *@da at)))
  ==
::
++  test-alarm-offsets
  ;:  weld
    ::  after the start, from the start
    %+  expect-eq  !>(~[['standup' 'starting now' 'cal-e-2-0']])
    !>((pushes ~[[[%off | & ~m5] '']] (add at ~m4) (add at ~m5)))
    ::  before the end
    %+  expect-eq  !>(~[['standup' 'starting now' 'cal-e-2-0']])
    !>((pushes ~[[[%off & | ~m5] '']] (add at ~m54) (add at ~m55)))
    ::  after the end
    (expect-eq !>(1) !>((lent (pushes ~[[[%off & & ~m5] '']] (add at ~m64) (add at ~m65)))))
    ::  before the start
    (expect-eq !>(1) !>((lent (pushes ~[[[%off | | ~m5] '']] (sub at ~m6) (sub at ~m5)))))
    ::  an absolute alarm belongs to the entry: -a-
    %+  expect-eq  !>(~[['standup' 'reminder' 'cal-e-a-0']])
    !>((alarm-pushes:core ~ (alarm-at ~[[[%abs at] '']] (ev 'standup')) (sub at ~s1) at ~))
    (expect-eq !>(~) !>((alarm-pushes:core ~ (alarm-at ~[[[%abs at] '']] (ev 'standup')) at (add at ~s1) ~)))
  ==
::
++  test-alarm-task-and-lead
  =/  task=event:cal  [%todo `(add at ~h3) ~ (malt ~[['name' s+'file taxes']])]
  ;:  weld
    ::  a task's alarm counts from its due moment, not its day
    %+  expect-eq  !>(~[['file taxes' 'in 60 min' 'cal-e-2-0']])
    !>((alarm-pushes:core ~[(ref 2)] (alarm-at ~[[[%rel ~h1] '']] task) (add at ~m119) (add at ~h2) ~))
    ::  leads: one per due timed occurrence
    %+  expect-eq  !>(~[['standup' 'in 5 min' 'cal-e-2']])
    !>((lead-pushes:core ~[(ref 2)] (malt ~[[%e (ev 'standup')]]) (sub at ~m5)))
    %+  expect-eq  !>(~[['standup' 'starting now' 'cal-e-2']])
    !>((lead-pushes:core ~[(ref 2)] (malt ~[[%e (ev 'standup')]]) at))
    (expect-eq !>(~) !>((lead-pushes:core ~[(ref 2)] (malt ~[[%e task]]) at)))
    (expect-eq !>(~) !>((lead-pushes:core ~[(ref 2)] ~ at)))
  ==
::
::  ==  the rest of the helpers
::
++  test-group-name
  ;:  weld
    (expect-eq !>('cal-work-edit') !>((group-name:core %work 'edit')))
    ::  a-z 0-9 - kept, at both ends of each range; the rest become -
    (expect-eq !>('cal-az09-------read') !>((group-name:core 'az09-AZ_.~' 'read')))
  ==
::
++  test-read-only-and-kinds
  =/  sh
    |=  r=(unit @t)
    =/  c  (cals ~[[%s ~]])
    =/  k  (~(got by cals.c) %s)
    c(cals (~(put by cals.c) %s k(props [name.props.k color.props.k %ship r])))
  ;:  weld
    (expect !>((ship-read-only:core (sh `'~zod/cal#read') %s)))
    (expect !>(!(ship-read-only:core (sh `'~zod/cal#edit') %s)))
    (expect !>(!(ship-read-only:core (sh ~) %s)))
    (expect !>(!(ship-read-only:core (sh `'~zod/cal') %s)))
    (expect !>(!(ship-read-only:core (cals ~[[%s ~]]) %s)))
    (expect !>(!(ship-read-only:core (cals ~) %nope)))
    (expect !>((kind-is:core (sh ~) %s %ship)))
    (expect !>(!(kind-is:core (sh ~) %s %local)))
    (expect !>(!(kind-is:core (sh ~) %nope %ship)))
    (expect-eq !>(`%work) !>((cal-arg:core (obj ~[['cal' s+'work']]))))
    (expect-eq !>(~) !>((cal-arg:core (obj ~[['cal' s+'']]))))
    (expect-eq !>(~) !>((cal-arg:core (obj ~))))
  ==
::
++  test-props-in-and-out
  =/  e  `entry:cal`[(ev 'x') 'u' '' 0 ~ ~[['X-GOOGLE-ID' 'g'] ['X-GOOGLE-ETAG' '"1"'] ['LOCATION' 'here']]]
  ;:  weld
    ::  a moved entry leaves its old calendar's Google ids behind
    (expect-eq !>(~[['LOCATION' 'here']]) !>(props:(unhome:core e)))
    ::  a file's Google ids are dropped; the caller's own props win
    %+  expect-eq  !>(~[['X-GOOGLE-ID' 'mine'] ['LOCATION' 'here']])
    !>((with-extra:core ~[['X-GOOGLE-ID' 'theirs'] ['X-GOOGLE-UPDATED' 't'] ['LOCATION' 'here']] ~[['X-GOOGLE-ID' 'mine']]))
    %+  expect-eq  !>(~[['CATEGORIES' 'b'] ['LOCATION' 'here']])
    !>((with-extra:core ~[['CATEGORIES' 'a'] ['LOCATION' 'here']] ~[['CATEGORIES' 'b']]))
    (expect !>((cancelled:core e(props ~[['STATUS' 'CANCELLED']]))))
    (expect !>(!(cancelled:core e(props ~[['STATUS' 'CONFIRMED']]))))
    (expect !>(!(cancelled:core e)))
  ==
::
++  test-alias-object
  =/  ves  (events:ics 'BEGIN:VCALENDAR\0d\0aBEGIN:VEVENT\0d\0aUID:real\0d\0aSUMMARY:x\0d\0aDTSTART:20261102T100000Z\0d\0aEND:VEVENT\0d\0aEND:VCALENDAR\0d\0a')
  =/  al  (alias-object:core ves 'client-name')
  ;:  weld
    ::  kept under the client's name, its own UID aside
    (expect-eq !>(~['client-name']) !>((turn ves.al |=(v=vevent:ics uid.v))))
    (expect-eq !>(~[['X-GRUBBERY-UID' 'real']]) !>(extra.al))
    ::  under its own UID, or with none: as it is
    (expect-eq !>([ves ~]) !>((alias-object:core ves 'real')))
    (expect-eq !>([~ ~]) !>((alias-object:core ~ 'x')))
  ==
::
++  test-move-takes-its-overrides
  =/  kid  `entry:cal`[(ev 'moved instance') 'p#r' '' 0 ~ ~[['X-GRUBBERY-PARENT' 'p'] ['X-GOOGLE-ID' 'g']]]
  =/  c  (cals ~[[%a ~[(ent 'parent' 'p') kid]] [%b ~]])
  =/  moved  (put-ev-in:core c `%b '' 'p' (ev 'parent'))
  ;:  weld
    (expect-eq !>(~['p' 'p#r']) !>((names moved %b)))
    (expect-eq !>(~) !>((names moved %a)))
    ::  and the child leaves its Google id behind too
    (expect-eq !>(~[['X-GRUBBERY-PARENT' 'p']]) !>(props:(~(got by entries:(~(got by cals.moved) %b)) 'p#r')))
  ==
::
++  test-migrate-kinds
  ::  the v18 incident: a v17 event with a day it cannot read ("Monday")
  ::  stays as it was, and the rest of the calendar still converts
  =/  preset
    |=  days=(list @t)
    ^-  event:cal
    [%timed [[/lib/rules %weekly] (malt ~[['days' a+(turn days |=(d=@t s+d))]]) at] ~ [%dur ~h1] [~ ~] ~]
  =/  todo=event:cal  [%todo ~ ~ ~]
  =/  c  (cals ~[[%a ~[[(preset ~['mon']) 'good' '' 0 ~ ~] [(preset ~['Monday']) 'bad' '' 0 ~ ~] [todo 't' '' 0 ~ ~]]]])
  =/  m  (migrate-kinds:core c)
  =/  kind-of  |=(u=@t =/(e event:(~(got by entries:(~(got by cals.m) %a)) u) ?.(?=(%timed -.e) %none name.kind.recur.e)))
  ;:  weld
    (expect-eq !>(%rrule) !>((kind-of 'good')))
    (expect-eq !>(%weekly) !>((kind-of 'bad')))
    (expect-eq !>(%none) !>((kind-of 't')))
    ::  and a second pass changes nothing
    (expect-eq !>(m) !>((migrate-kinds:core m)))
  ==
::
++  test-rows-of-and-feeds-window
  =/  k=cal:cal  (roll `(list entry:cal)`~[(ent 'a' 'a') (ent 'b' 'b')] |=([e=entry:cal k=_fresh-cal:cal] (put-entry:cal k e)))
  =/  one  |=(t=@t (snag 0 (events:ics (crip "BEGIN:VCALENDAR\0d\0aBEGIN:VEVENT\0d\0aUID:f\0d\0aSUMMARY:f\0d\0aDTSTART:{(trip t)}\0d\0aEND:VEVENT\0d\0aEND:VCALENDAR\0d\0a"))))
  ;:  weld
    (expect-eq !>(~['a']) !>((turn ~(tap in (rows-of:core k 0 (sy ~['a']))) head)))
    (expect-eq !>(~) !>((rows-of:core k 0 ~)))
    ::  a feed event exactly at either end of the window is in
    (expect !>(?=(^ (ics-event:core (one '20261102T100000Z') 'f' at (add at ~d1) ~))))
    (expect !>(?=(^ (ics-event:core (one '20261103T100000Z') 'f' at (add at ~d1) ~))))
    (expect !>(?=(~ (ics-event:core (one '20261103T100001Z') 'f' at (add at ~d1) ~))))
    (expect !>(?=(~ (ics-event:core (one '20261102T095959Z') 'f' at (add at ~d1) ~))))
  ==
::
++  test-dav-report-namespaces
  ::  sync-collection is DAV's; calendar-query and -multiget are CalDAV's
  =/  c  (cals ~[[%work ~]])
  =/  xml=tape
    %-  zing
    %+  turn  (dav-props-for:core ~zod c [%calendar %work])
    |=([n=@tas p=manx] ?.(=(%'supported-report-set' n) ~ (en-xml:html p)))
  ;:  weld
    (expect !>(?=(^ (find "<D:sync-collection" xml))))
    (expect !>(?=(^ (find "<C:calendar-query" xml))))
    (expect !>(?=(^ (find "<C:calendar-multiget" xml))))
    (expect !>(?=(~ (find "<C:sync-collection" xml))))
  ==
::
++  test-dav-content-type
  =/  task=entry:cal  [[%todo ~ ~ (malt ~[['name' s+'t']])] 't' '' 0 ~ ~]
  =/  c  (cals ~[[%work ~[(ent 'e' 'e') task]]])
  =/  ct
    |=  u=@t
    ^-  tape
    %-  zing
    %+  turn  (dav-props-for:core ~zod c [%object %work u])
    |=([n=@tas p=manx] ?.(=(%getcontenttype n) ~ (en-xml:html p)))
  ;:  weld
    (expect !>(?=(^ (find "component=VEVENT" (ct 'e')))))
    (expect !>(?=(^ (find "component=VTODO" (ct 't')))))
  ==
::
++  test-parse-event-fin
  =/  e
    %+  parse-event:core
      %-  obj
      :~  ['cat' s+'timed']  ['meta' (meta 'x')]  ['kind' s+'once']
          ['start_ms' (numb:enjs:format ms)]  ['fin' s+'to']
          ['end_ms' (numb:enjs:format (da-to-ms:cal (add at ~h2)))]
      ==
    ~
  =/  d
    %+  parse-event:core
      %-  obj
      :~  ['cat' s+'timed']  ['meta' (meta 'x')]  ['kind' s+'once']
          ['start_ms' (numb:enjs:format ms)]  ['dur_min' (numb:enjs:format 45)]
      ==
    ~
  ;:  weld
    (expect-eq !>(`[%to (add at ~h2)]) !>(?.(?=([~ %timed *] e) ~ `fin.u.e)))
    (expect-eq !>(`[%dur ~m45]) !>(?.(?=([~ %timed *] d) ~ `fin.u.d)))
  ==
::
++  test-alarm-all-day-is-local
  ::  an all-day occurrence's alarm counts from midnight where the
  ::  calendar is (05:00 UTC in New York in November), not from UTC midnight
  =/  day=event:cal  [%allday [[/lib/rules %once] ~ ~2026.11.3] 1 [~ ~] (malt ~[['name' s+'trip']])]
  =/  r=ref:cal  [%e 0 [~2026.11.3 ~2026.11.4]]
  =/  ens  (malt ~[[%e [day 'e' '' 0 ~[[[%rel ~h1] '']] ~]]])
  =/  ny  `(unit @t)``'America/New_York'
  ;:  weld
    (expect-eq !>(1) !>((lent (alarm-pushes:core ~[r] ens ~2026.11.3..03.59.59 ~2026.11.3..04.00.00 ny))))
    (expect-eq !>(0) !>((lent (alarm-pushes:core ~[r] ens ~2026.11.2..22.59.59 ~2026.11.2..23.00.00 ny))))
    ::  with no zone, UTC midnight
    (expect-eq !>(1) !>((lent (alarm-pushes:core ~[r] ens ~2026.11.2..22.59.59 ~2026.11.2..23.00.00 ~))))
  ==
--
