::  calendar-core: the calendar nexus's pure arms, moved out of
::  nex/calendar/app.hoon so the kit can test them (hoon-test-kit,
::  PLAYBOOK "Testing nexus code"). Nothing here waits, reads the tree,
::  or names a grubbery type; the nexus keeps a one-line alias for each.
::
/<  cal    /lib/calendar.hoon
/<  rules  /lib/rules.hoon
/<  pytz   /lib/pytz.hoon
/<  ics    /lib/ics.hoon
/<  rr     /lib/rrule.hoon
/<  dav    /lib/dav.hoon
/<  gcal   /lib/gcal.hoon
/<  k-every  /lib/rules/every.hoon
/<  k-once   /lib/rules/once.hoon
/<  k-rrule  /lib/rules/rrule.hoon
|%
::  +born: a new calendar, its seq starting where no earlier one of the
::  same id could have reached (milliseconds since 2020), so a sync token
::  from a calendar deleted and made again under the id is told apart
++  born
  |=  now=@da
  ^-  cal:cal
  =/  k=cal:cal  fresh-cal:cal
  k(seq (div (mul (sub now ~2020.1.1) 1.000) ~s1))
::  +kind-is: a calendar that exists and is of this kind
++  kind-is
  |=  [c=calendar:cal id=@ta kind=?(%local %google %caldav %ship)]
  ^-  ?
  =/  k=(unit cal:cal)  (~(get by cals.c) id)
  &(?=(^ k) =(kind kind.props.u.k))
::  +max-reach: how far ahead a cache is ever built (the horizon's cap)
++  max-reach  (mul 3.650 ~d1)
::  +by-uid: the keyed index as other apps read it, each ref under its
::  bare uid (the same UID in two calendars shows as two refs of it)
++  by-uid
  |=  ca=cache:cal
  ^-  cache:cal
  :+  thru.ca
    (~(gas by *(map eid:cal @da)) (turn ~(tap by stops.ca) |=([k=eid:cal d=@da] [uid:(unkey k) d])))
  %+  gas:on-order:cal  *order:cal
  %+  turn  (tap:on-order:cal order.ca)
  |=  [at=@da rs=(set ref:cal)]
  [at (~(run in rs) |=(r=ref:cal r(eid uid:(unkey eid.r))))]
::  +put-ev, +del-ev: an event by id into the calendar that holds it (the
::  one named home first, see +locate), or %default for a new one. The
::  entry's identity (uid, alarms, props) survives an edit; only the event
::  shape is replaced.
++  put-ev
  |=  [c=calendar:cal home=@ta id=@ta ev=event:cal]
  ^-  calendar:cal
  (put-ev-in c ~ home id ev)
::  +put-ev-in: like put-ev, into a named calendar (an unknown name falls
::  back to where the entry lives, or %default). An existing entry asked
::  into another calendar moves, override children and all: deleted from
::  the old, put into the new, less the old calendar's Google ids (they
::  would aim the new calendar's push at the old one's events). A move
::  onto a UID the other calendar holds changes nothing.
++  put-ev-in
  |=  [c=calendar:cal want=(unit @ta) home=@ta id=@ta ev=event:cal]
  ^-  calendar:cal
  =/  got=(unit [cid=@ta e=entry:cal])  (locate c home id)
  =/  cid=@ta
    ?:  &(?=(^ want) (~(has by cals.c) u.want))  u.want
    ?~(got %default cid.u.got)
  =/  move=?  &(?=(^ got) !=(cid.u.got cid))
  ::  a move onto a UID the calendar already holds is refused: it would
  ::  overwrite that entry, and push the overwrite to its remote
  ?:  &(move (~(has by entries:(fall (~(get by cals.c) cid) fresh-cal:cal)) id))  c
  =/  kids=(list entry:cal)
    ?.  move  ~
    ?~  got  ~
    (turn (kids-of:cal (~(got by cals.c) cid.u.got) id) unhome)
  =?  c  move  (del-ev c ?~(got '' cid.u.got) id)
  =/  k=cal:cal  (fall (~(get by cals.c) cid) fresh-cal:cal)
  =/  e=entry:cal  ?~(got [ev id '' 0 ~ ~] e.u.got(event ev))
  =?  e  move  (unhome e)
  =.  k  (put-entry:cal k e)
  =.  k  (roll kids |=([ch=entry:cal acc=_k] (put-entry:cal acc ch)))
  c(cals (~(put by cals.c) cid k))
::  +unhome: an entry less the remote ids of the calendar it came from
++  unhome
  |=  e=entry:cal
  ^-  entry:cal
  e(props (skip props.e |=([key=@t *] =("X-GOOGLE-" (scag 9 (trip key))))))
::  +cal-arg: the poke's optional calendar name
++  cal-arg
  |=  jon=json
  ^-  (unit @ta)
  =/  v=@t  (gs jon 'cal')
  ?:(=('' v) ~ `(crip (trip v)))
++  del-ev
  |=  [c=calendar:cal home=@ta id=@ta]
  ^-  calendar:cal
  =/  got=(unit [cid=@ta e=entry:cal])  (locate c home id)
  ?~  got  c
  =/  k=cal:cal  (fall (~(get by cals.c) cid.u.got) fresh-cal:cal)
  c(cals (~(put by cals.c) cid.u.got (del-object k id)))
::  +del-object: an entry and its override children with it
++  del-object
  |=  [k=cal:cal u=uid:cal]
  ^-  cal:cal
  =.  k  (roll (kids-of:cal k u) |=([ch=entry:cal acc=_k] (del-entry:cal acc uid.ch)))
  (del-entry:cal k u)
::  +skips-of, +set-skips: an event's skipped indices, read and replaced
++  skips-of
  |=  ev=event:cal
  ^-  (set @ud)
  ?+(-.ev ~ %timed except.bound.ev, %allday except.bound.ev)
++  set-skips
  |=  [ev=event:cal ex=(set @ud)]
  ^-  event:cal
  ?-  -.ev
    ?(%date %todo)  ev
    %timed   ev(except.bound ex)
    %allday  ev(except.bound ex)
  ==
::  +add-skips: more skipped indices on an event with a recurrence
++  add-skips
  |=  [ev=event:cal got=(set @ud)]
  ^-  event:cal
  ?-  -.ev
    ?(%date %todo)  ev
    %timed   ev(except.bound (~(uni in except.bound.ev) got))
    %allday  ev(except.bound (~(uni in except.bound.ev) got))
  ==
::  +dav-password: up to 24 base-32 characters from entropy
++  dav-password
  |=  eny=@
  ^-  tape
  =/  raw=tape  (trip (scot %uv (end [3 15] eny)))
  =/  body=tape  (slag 2 raw)
  ::  ponytail: leading zero digits are dropped by scot, so this is
  ::  20-24 characters, not always 24
  (skip body |=(c=@t =('.' c)))
::  +dav-hash: a salted sha-256, as text
++  dav-hash
  |=  [salt=@t password=@t]
  ^-  @t
  (scot %ux (shax (rap 3 ~[salt ':' password])))
::  +dav-verb: the DAV verb. The runtime only passes GET/PUT/POST/HEAD/
::  DELETE/OPTIONS/CONNECT/TRACE, so a proxy sends the others as POST
::  with X-HTTP-Method-Override.
++  dav-verb
  |=  req=inbound-request:eyre
  ^-  @t
  =/  m=@t  method.request.req
  ?.  =('POST' m)  m
  =/  ov=(unit @t)  (get-header:http 'x-http-method-override' header-list.request.req)
  ?~  ov  m
  (crip (cuss (trip u.ov)))
::  +dav-authed: the owner's cookie, or Basic with a minted password
++  dav-authed
  |=  [req=inbound-request:eyre clients=json]
  ^-  ?
  ?:  authenticated.req  &
  =/  au=(unit @t)  (get-header:http 'authorization' header-list.request.req)
  ?~  au  |
  =/  t=tape  (trip u.au)
  ?.  (gte (lent t) 6)  |
  ?.  =("basic " (cass (scag 6 t)))  |
  =/  dec=(unit octs)  (de:base64:mimes:html (crip (slag 6 t)))
  ?~  dec  |
  =/  pair=tape  (trip q.u.dec)
  =/  at=(unit @ud)  (find ":" pair)
  ?~  at  |
  =/  password=@t  (crip (slag +(u.at) pair))
  ?:  =('' password)  |
  %+  lien  ?:(?=([%a *] clients) p.clients ~)
  |=  c=json
  =((gs c 'hash') (dav-hash (gs c 'salt') password))
::  +dav-rid: an override's RECURRENCE-ID prop, if it has one
++  dav-rid
  |=  ve=vevent:ics
  ^-  (unit [key=@t val=@t])
  (bind (get-prop:ics extra.ve 'RECURRENCE-ID') |=(p=prop:ics [k.p v.p]))
::  +lead-of: the VEVENT an object is kept by: the one without a
::  RECURRENCE-ID, or, in an object of overrides alone (an invitation to
::  one instance of someone else's series), the first of them
++  lead-of
  |=  ves=(list vevent:ics)
  ^-  (unit vevent:ics)
  =/  ps=(list vevent:ics)  (skip ves |=(v=vevent:ics ?=(^ (dav-rid v))))
  ?^  ps  `i.ps
  ?~(ves ~ `i.ves)
::  +alias-object: an object stored under a name that is not its UID (a
::  client's random filename for a UID that is not URL-safe, a peer's key)
::  is kept under that name, its own UID aside in X-GRUBBERY-UID, so GET,
::  DELETE and the listings all answer at the name the client used, and
::  the object still goes out with its own UID
++  alias-object
  |=  [ves=(list vevent:ics) key=@t]
  ^-  [ves=(list vevent:ics) extra=(list [@t @t])]
  =/  lead=(unit vevent:ics)  (lead-of ves)
  ?~  lead  [ves ~]
  =/  real=@t  uid.u.lead
  ?:  |(=('' real) =(key real))  [ves ~]
  [(turn ves |=(v=vevent:ics v(uid key))) ~[['X-GRUBBERY-UID' real]]]
::  +object-etags: an object's entries (the parent and its overrides) by
::  uid, as etags
++  object-etags
  |=  [k=cal:cal u=uid:cal]
  ^-  (map uid:cal etag:cal)
  =/  e=(unit entry:cal)  (~(get by entries.k) u)
  ?~  e  ~
  %-  ~(gas by *(map uid:cal etag:cal))
  (turn [u.e (kids-of:cal k u)] |=(x=entry:cal [uid.x etag.x]))
::  +with-extra: read props with the caller's own on top (a Google id,
::  say). Google ids read from a file are dropped: only a Google pull
::  says what the Google copy is.
++  with-extra
  |=  [props=(list [k=@t v=@t]) extra=(list [@t @t])]
  ^-  (list [k=@t v=@t])
  %+  weld  extra
  %+  skip  props
  |=  [key=@t *]
  ?|  =("X-GOOGLE-" (scag 9 (trip key)))
      (lien extra |=([x=@t *] =(x key)))
  ==
::  +keep-meta: a re-read event keeps what the file has no word for: meta
::  keys ICS does not carry, and a color a client that knows no COLOR
::  left out. Name, note, location and tags are the file's.
++  keep-meta
  |=  [old=event:cal new=event:cal]
  ^-  event:cal
  =/  own=(set @t)  (sy ~['name' 'note' 'location' 'tags'])
  =/  kept=meta:cal
    %-  ~(uni by (malt (skip ~(tap by (meta-of:cal old)) |=([k=@t *] (~(has in own) k)))))
    (meta-of:cal new)
  ?-  -.new
    %timed   new(meta kept)
    %allday  new(meta kept)
    %date    new(meta kept)
    %todo    new(meta kept)
  ==
::  +props-rid-moment: a RECURRENCE-ID (an override's props, a read
::  VEVENT's extra) as the naive moment of its parent's series: one in UTC
::  or another zone is moved to the series' own (+series-wall:ics)
++  props-rid-moment
  |=  [props=(list [k=@t v=@t]) par=event:cal]
  ^-  (unit @da)
  =/  rid=(unit prop:ics)  (get-prop:ics props 'RECURRENCE-ID')
  ?~  rid  ~
  %+  bind  (when-of:ics k.u.rid v.u.rid)
  |=(w=when:ics (series-wall:ics w ?:(?=(%timed -.par) zone.par ~)))
++  dav-unquote
  |=  t=@t
  ^-  @t
  =/  s=tape  (trip t)
  =.  s  ?:(=("W/" (scag 2 s)) (slag 2 s) s)
  =.  s  ?:(&(!=(0 (lent s)) =('"' (snag 0 s))) (slag 1 s) s)
  =.  s  ?:(&(!=(0 (lent s)) =('"' (rear s))) (snip s) s)
  (crip s)
::  +dav-href-res: an href from a request body back to a resource
++  dav-href-res
  |=  h=tape
  ^-  dav-res
  ::  an absolute href (some clients send one) is its path; each segment
  ::  is percent-decoded here, as the request path is by +parse-url
  =/  segs=(list @ta)
    %+  turn  (skip (split:rr '/' (crip (norm-href h))) |=(t=@t =('' t)))
    |=(t=@t (crip (dec-seg:dav (trip t))))
  ?.  ?=([%apps %calendar %dav *] segs)  [%none ~]
  (dav-resolve t.t.t.segs)
::  +dav-res: what a dav path names
+$  dav-res
  $%  [%principal ~]
      [%home ~]
      [%calendar id=@ta]
      [%object id=@ta =uid:cal]
      [%none ~]
  ==
++  dav-resolve
  |=  rest=path
  ^-  dav-res
  ::  a trailing slash parses as an empty last segment
  =.  rest  (skip rest |=(s=@ta =('' s)))
  ?~  rest  [%principal ~]
  ?.  =(%cal i.rest)  [%none ~]
  ?~  t.rest  [%home ~]
  =/  id=@ta  i.t.rest
  ?~  t.t.rest  [%calendar id]
  ?^  t.t.t.rest  [%none ~]
  ::  the request path is percent-decoded already (+parse-url)
  =/  nm=tape  (trip i.t.t.rest)
  ::  strip a trailing .ics
  =/  n=@ud  (lent nm)
  =/  uid=tape  ?:(&((gte n 4) =(".ics" (slag (sub n 4) nm))) (scag (sub n 4) nm) nm)
  [%object id (crip uid)]
::  hrefs
++  dav-root  "/apps/calendar/dav/"
++  dav-cal-href  |=(id=@ta ^-(tape "{dav-root}cal/{(enc-seg:dav (trip id))}/"))
++  dav-obj-href
  |=  [id=@ta =uid:cal]
  ^-  tape
  "{(dav-cal-href id)}{(enc-seg:dav (trip uid))}.ics"
::  +dav-props-for: the props of a resource, by local name
++  dav-props-for
  |=  [our=@p c=calendar:cal res=dav-res]
  ^-  (list [n=@tas p=prop:dav])
  ?-    -.res
      %none  ~
      %principal
    :~  [%resourcetype (d-el:dav %resourcetype ~[(d-el:dav %collection ~) (d-el:dav %principal ~)])]
        [%displayname (d-el:dav %displayname ~[(tx:dav (scow %p our))])]
        [%'current-user-principal' (d-el:dav %'current-user-principal' ~[(href:dav dav-root)])]
        [%'principal-URL' (d-el:dav %'principal-URL' ~[(href:dav dav-root)])]
        [%'calendar-home-set' (c-el:dav %'calendar-home-set' ~[(href:dav "{dav-root}cal/")])]
        [%'calendar-user-address-set' (c-el:dav %'calendar-user-address-set' ~[(href:dav dav-root)])]
    ==
      %home
    :~  [%resourcetype (d-el:dav %resourcetype ~[(d-el:dav %collection ~)])]
        [%displayname (d-el:dav %displayname ~[(tx:dav "Calendars")])]
        [%'current-user-principal' (d-el:dav %'current-user-principal' ~[(href:dav dav-root)])]
    ==
      %calendar
    =/  k=(unit cal:cal)  (~(get by cals.c) id.res)
    ?~  k  ~
    =/  tok=tape  "{dav-root}sync/{(a-co:co seq.u.k)}"
    :~  [%resourcetype (d-el:dav %resourcetype ~[(d-el:dav %collection ~) (c-el:dav %calendar ~)])]
        [%displayname (d-el:dav %displayname ~[(tx:dav (trip name.props.u.k))])]
        [%'calendar-color' (el:dav [%'A' %'calendar-color'] ~[(tx:dav (trip color.props.u.k))])]
        [%'supported-calendar-component-set' (c-el:dav %'supported-calendar-component-set' ~[[[[%'C' %comp] [[%name "VEVENT"] ~]] ~] [[[%'C' %comp] [[%name "VTODO"] ~]] ~]])]
        [%getctag (el:dav [%'CS' %getctag] ~[(tx:dav (a-co:co seq.u.k))])]
        [%'sync-token' (d-el:dav %'sync-token' ~[(tx:dav tok)])]
        [%'current-user-principal' (d-el:dav %'current-user-principal' ~[(href:dav dav-root)])]
        [%owner (d-el:dav %owner ~[(href:dav dav-root)])]
        :-  %'supported-report-set'
        %+  d-el:dav  %'supported-report-set'
        %+  turn  `(list @tas)`~[%'calendar-query' %'calendar-multiget' %'sync-collection']
        |=  r=@tas
        (d-el:dav %'supported-report' ~[(d-el:dav %report ~[?:(=(%'sync-collection' r) (d-el:dav r ~) (c-el:dav r ~))])])
        :-  %'current-user-privilege-set'
        %+  d-el:dav  %'current-user-privilege-set'
        ~[(d-el:dav %privilege ~[(d-el:dav %read ~)]) (d-el:dav %privilege ~[(d-el:dav %write ~)])]
    ==
      %object
    =/  k=(unit cal:cal)  (~(get by cals.c) id.res)
    ?~  k  ~
    =/  e=(unit entry:cal)  (~(get by entries.u.k) uid.res)
    ?~  e  ~
    :~  [%resourcetype (d-el:dav %resourcetype ~)]
        [%getetag (d-el:dav %getetag ~[(tx:dav "\"{(trip etag.u.e)}\"")])]
        [%getcontenttype (d-el:dav %getcontenttype ~[(tx:dav "text/calendar; charset=utf-8; component={?:(?=(%todo -.event.u.e) "VTODO" "VEVENT")}")])]
    ==
  ==
::  +dav-response: one <response> for a resource, filtered to the asked props
++  dav-response
  |=  [our=@p c=calendar:cal res=dav-res h=tape asked=(list @tas)]
  ^-  manx
  =/  have=(list [n=@tas p=prop:dav])  (dav-props-for our c res)
  ?~  asked
    (response:dav h (turn have |=([* p=prop:dav] p)) ~)
  =/  found=(list prop:dav)
    %+  murn  `(list @tas)`asked
    |=  n=@tas
    =/  got=(list [n=@tas p=prop:dav])  (skim have |=([m=@tas *] =(m n)))
    ?~(got ~ `p.i.got)
  =/  missing=(list @tas)
    (skip `(list @tas)`asked |=(n=@tas (lien have |=([m=@tas *] =(m n)))))
  (response:dav h found missing)
::  +dav-is-child: an override entry; never listed on its own
++  dav-is-child  |=(e=entry:cal ?=(^ (parent-of:cal e)))
++  google-defaults
  ^-  json
  %-  pairs:enjs:format
  :~  ['client_id' s+'']
      ['client_secret' s+'']
      ['auth_url' s+'https://accounts.google.com/o/oauth2/v2/auth']
      ['token_url' s+'https://oauth2.googleapis.com/token']
      ['api_base' s+'https://www.googleapis.com']
      ['tick_min' (numb:enjs:format 5)]
  ==
++  form-body
  |=  kvs=(list [k=tape v=tape])
  ^-  octs
  %-  as-octs:mimes:html
  %-  crip
  %-  sep-join:rr
  :-  "&"
  (turn kvs |=([k=tape v=tape] "{k}={(enc-seg:dav v)}"))
::  +suppressed: the log rows a sync pass itself wrote, as [uid key],
::  from the row. The push skips exactly those; nothing else.
++  suppressed
  |=  row=json
  ^-  (set [@t @ud])
  %-  ~(gas in *(set [@t @ud]))
  %+  murn  (arr:gcal row 'suppressed')
  |=  j=json
  ^-  (unit [@t @ud])
  ?.  ?=([%a *] j)  ~
  ?.  ?=([* * ~] p.j)  ~
  =/  u=json  i.p.j
  =/  k=json  i.t.p.j
  ?.  &(?=([%s *] u) ?=([%n *] k))  ~
  `[p.u (fall (rush p.k dem) 0)]
::  +suppress-json: the set back to the row, pruned of rows the
::  watermark has passed
++  suppress-json
  |=  [sup=(set [@t @ud]) floor=@ud]
  ^-  json
  :-  %a
  %+  turn  (skip ~(tap in sup) |=([* key=@ud] (lte key floor)))
  |=([u=@t key=@ud] `json`[%a ~[s+u (numb:enjs:format key)]])
::  +since-log: the log rows past a watermark, oldest first
++  since-log
  |=  [k=cal:cal since=@ud]
  ^-  (list [key=@ud val=logent:cal])
  (tap:on-log:cal (lot:on-log:cal log.k `since ~))
::  +wrote-between: the log rows in (from, to], as [uid key]
++  wrote-between
  |=  [k=cal:cal from=@ud to=@ud]
  ^-  (set [@t @ud])
  %-  ~(gas in *(set [@t @ud]))
  %+  murn  (since-log k from)
  |=([key=@ud val=logent:cal] ?.((lte key to) ~ `[uid.val key]))
::  +pending-uids: the uids with a local change the push has not sent
::  yet: log rows above the watermark that no pass wrote itself
++  pending-uids
  |=  [k=cal:cal since=@ud sup=(set [@t @ud])]
  ^-  (set uid:cal)
  %-  ~(gas in *(set uid:cal))
  %+  murn  (since-log k since)
  |=([key=@ud val=logent:cal] ?:((~(has in sup) [uid.val key]) ~ `uid.val))
::  +rows-of: the rows above the watermark for these uids. A pull that
::  let the remote win for a uid suppresses the local change it
::  replaced, so the push does not undo the remote's win.
++  rows-of
  |=  [k=cal:cal since=@ud uids=(set uid:cal)]
  ^-  (set [@t @ud])
  %-  ~(gas in *(set [@t @ud]))
  %+  murn  (since-log k since)
  |=([key=@ud val=logent:cal] ?.((~(has in uids) uid.val) ~ `[uid.val key]))
::  +child-row: a log row of an override child. A live entry says so in
::  its props. A deleted one was named <parent>#<recurrence-id>, and its
::  parent is here or went in the same rows (logged); a real UID with a #
::  in it names no such parent, and is an object of its own.
++  child-row
  |=  [k=cal:cal u=uid:cal logged=(set uid:cal)]
  ^-  ?
  =/  e=(unit entry:cal)  (~(get by entries.k) u)
  ?^  e  ?=(^ (parent-of:cal u.e))
  =/  t=tape  (flop (trip u))
  =/  at=(unit @ud)  (find "#" t)
  ?~  at  |
  =/  par=@t  (crip (flop (slag +(u.at) t)))
  |((~(has by entries.k) par) (~(has in logged) par))
::  +changes-since: what a push sends: the latest change per object past
::  the watermark, the pass's own rows left out. A child's change is its
::  parent's too (+restamp:cal re-logs the parent), so child rows go.
++  changes-since
  |=  [k=cal:cal since=@ud sup=(set [@t @ud])]
  ^-  (list [uid:cal ?(%put %del)])
  =/  rows=(list [key=@ud val=logent:cal])  (since-log k since)
  =/  logged=(set uid:cal)  (~(gas in *(set uid:cal)) (turn rows |=([* val=logent:cal] uid.val)))
  %~  tap  by
  %+  roll  rows
  |=  [[key=@ud val=logent:cal] acc=(map uid:cal ?(%put %del))]
  ?:  |((~(has in sup) [uid.val key]) (child-row k uid.val logged))  acc
  (~(put by acc) uid.val kind.val)
::  +omap: a json object's map, or none
++  omap  |=(j=json ^-((map @t json) ?:(?=([%o *] j) p.j ~)))
::  +row-put: fields onto a sync row
++  row-put
  |=  [row=json kvs=(list [@t json])]
  ^-  json
  ?.  ?=([%o *] row)  row
  [%o (~(gas by p.row) kvs)]
::  +google-stop: a status that ends a push and keeps the watermark: no
::  answer, a server error, auth, a rate limit. Any other refusal (a
::  read-only calendar's 403, say) is that change's alone, logged.
++  google-stop
  |=  [status=@ud res=json]
  ^-  ?
  ?:  |(=(0 status) (gte status 500) =(429 status) =(401 status))  &
  ?.  =(403 status)  |
  =/  errs=(list json)  (arr:gcal (obj:gcal res 'error') 'errors')
  =/  why=@t  ?~(errs '' (gs i.errs 'reason'))
  ?=(^ (find ~[why] `(list @t)`~['rateLimitExceeded' 'userRateLimitExceeded' 'quotaExceeded' 'dailyLimitExceeded']))
++  dav-origin
  |=  url=@t
  ^-  tape
  =/  t=tape  (trip url)
  =/  at=(unit @ud)  (find "//" t)
  ?~  at  ""
  =/  rest=tape  (slag (add 2 u.at) t)
  =/  sl=(unit @ud)  (find "/" rest)
  ?~(sl t (scag (add (add 2 u.at) u.sl) t))
::  +dav-href-path: an href from a response as a path: an absolute URI
::  loses its scheme and authority; one with a control character is
::  refused (~) rather than welded into a request line
++  dav-href-path
  |=  h=tape
  ^-  (unit tape)
  ::  pretty-printed XML may wrap an href in whitespace
  =.  h  (flop (skip-ws:dav (flop (skip-ws:dav h))))
  ?:  (lien h |=(c=@t |((lth c 32) =(127 c))))  ~
  =/  low=tape  (cass h)
  =/  pre=@ud
    ?:  =("https://" (scag 8 low))  8
    ?:  =("http://" (scag 7 low))  7
    0
  ?:  =(0 pre)  `h
  =/  rest=tape  (slag pre h)
  =/  sl=(unit @ud)  (find "/" rest)
  ?~(sl `"/" `(slag u.sl rest))
++  hdr-of
  |=  [headers=(list [@t @t]) name=@t]
  ^-  @t
  (fall (get-header:http name headers) '')
::  +response-href: an object's href from a <response>, as a path; ~ for
::  the collection itself or anything that is not an .ics
++  response-href
  |=  r=manx
  ^-  (unit tape)
  =/  h=(unit manx)  (kid:dav r %href)
  ?~  h  ~
  =/  hp=(unit tape)  (dav-href-path (text:dav u.h))
  ?~  hp  ~
  =/  n=@ud  (lent u.hp)
  ?.  &((gte n 4) =(".ics" (slag (sub n 4) u.hp)))  ~
  hp
++  with-slash  |=(t=tape ^-(tape ?:(&(?=(^ t) =('/' (rear t))) t (snoc t '/'))))
++  norm-href  |=(h=tape ^-(tape (fall (dav-href-path h) h)))
::  the calendar desk's instance lives at the same path on every ship
++  cal-instance  `path`/apps/'shell.shell'/desks/'calendar.desk'/desk/data/'calendar.calendar_app'
++  ug-base  `path`/sys/ames/usergroups
++  public-grp  `path`/sys/ames/usergroups/'public.grp'
::  +group-name: a usergroup per shared calendar and mode; the id is
::  made safe for a term
++  group-name
  |=  [id=@ta mode=@t]
  ^-  @t
  =/  safe=tape
    %+  turn  (trip id)
    |=(c=@t ?:(|(&((gte c 'a') (lte c 'z')) &((gte c '0') (lte c '9')) =('-' c)) c '-'))
  (crip "cal-{safe}-{(trip mode)}")
::  +ship-read-only: a calendar shared with us read-only takes no edits here
++  ship-read-only
  |=  [c=calendar:cal id=@ta]
  ^-  ?
  =/  k=(unit cal:cal)  (~(get by cals.c) id)
  ?~  k  |
  ?.  ?=(%ship kind.props.u.k)  |
  =/  r=(unit @t)  remote.props.u.k
  ?~  r  |
  ::  the mode rides in remote as "<host>/<cal>#<mode>"
  =/  t=tape  (flop (trip u.r))
  =/  at=(unit @ud)  (find "#" t)
  ?~(at | =("read" (flop (scag u.at t))))
::  +share-object-name: an object's file in a share's folder, named by a
::  hash of its uid (a uid can hold any character a file name cannot)
++  share-object-name
  |=  u=@t
  ^-  @ta
  (crip (weld ((x-co:co 32) (sham u)) ".json"))
::  +share-base-ok: may a peer's edit (or delete) of uid go in? Yes when
::  it names no base (a new object, or a peer on older code, which is
::  last-writer-wins as before), or when the host's copy is still the
::  version it names, or the one this peer's own last write left (the
::  host keeps a peer's object in its own words, so its etag is one the
::  peer never sees). No when the host deleted it since.
++  share-base-ok
  |=  [writes=json cid=@ta u=@t peer=@p base=@t cur=(unit entry:cal)]
  ^-  ?
  ?:  =('' base)  &
  ?~  cur  |
  ?|  =(etag.u.cur base)
      =(etag.u.cur (gs (obj:gcal (obj:gcal writes cid) u) (scot %p peer)))
  ==
::  +has-objects: a share file or index that names its objects (maybe
::  none), as opposed to one that could not be read
++  has-objects
  |=  j=json
  ^-  ?
  ?=([~ %o *] (~(get by (omap j)) 'objects'))
::  +locate: an entry by id, in the calendar named home when it holds one
::  (the same UID can live in two calendars), else in whichever does
++  locate
  |=  [c=calendar:cal home=@ta id=@ta]
  ^-  (unit [cid=@ta e=entry:cal])
  =/  k=(unit cal:cal)  (~(get by cals.c) home)
  =/  e=(unit entry:cal)  ?~(k ~ (~(get by entries.u.k) id))
  ?^  e  `[home u.e]
  (find-entry:cal c id)
::  +event-of: one event by id, as +locate finds it
++  event-of
  |=  [c=calendar:cal home=@ta id=@ta]
  ^-  (unit event:cal)
  (bind (locate c home id) |=([* e=entry:cal] event.e))
::  +keyed: every live entry keyed <calendar>/<uid>, so the same UID in two
::  calendars is two events, each shown and each addressed through its
::  own calendar. A cancelled one (STATUS:CANCELLED) is not shown.
++  keyed
  |=  c=calendar:cal
  ^-  (map eid:cal entry:cal)
  %-  ~(gas by *(map eid:cal entry:cal))
  %-  zing
  %+  turn  ~(tap by cals.c)
  |=  [id=@ta k=cal:cal]
  %+  murn  ~(tap by entries.k)
  |=  [u=uid:cal e=entry:cal]
  ^-  (unit [eid:cal entry:cal])
  ?:  (cancelled e)  ~
  `[(crip "{(trip id)}/{(trip u)}") e]
++  keyed-events  |=(c=calendar:cal (~(run by (keyed c)) |=(e=entry:cal event.e)))
::  +unkey: a <calendar>/<uid> key back to its halves (calendar ids have no
::  slash). A key from a cache made before calendars were in it is a uid.
++  unkey
  |=  key=eid:cal
  ^-  [cid=@ta =uid:cal]
  =/  t=tape  (trip key)
  =/  at=(unit @ud)  (find "/" t)
  ?~  at  ['' key]
  [(crip (scag u.at t)) (crip (slag +(u.at) t))]
::  +cancelled: an entry its source marked STATUS:CANCELLED
++  cancelled
  |=  e=entry:cal
  ^-  ?
  =/  st=(unit prop:ics)  (get-prop:ics props.e 'STATUS')
  &(?=(^ st) =('CANCELLED' v.u.st))
::  +ev-kind: the recurrence kind name, or 'date'
::
++  ev-kind
  |=  e=event:cal
  ^-  @t
  ?-(-.e %date 'date', %todo 'todo', %timed name.kind.recur.e, %allday name.kind.recur.e)
++  gs
  |=  [jon=json k=@t]
  ^-  @t
  ?.  ?=([%o *] jon)  ''
  =/  j=(unit json)  (~(get by p.jon) k)
  ?:(?=([~ %s *] j) p.u.j '')
::
++  gn
  |=  [jon=json k=@t]
  ^-  (unit @ud)
  ?.  ?=([%o *] jon)  ~
  =/  j=(unit json)  (~(get by p.jon) k)
  ?~  j  ~
  ?.  ?=([%n *] u.j)  ~
  (rush p.u.j dem)
::
++  ms-to-da  |=(ms=@ud `@da`(add ~1970.1.1 (div (mul ms ~s1) 1.000)))
++  da-to-ms  da-to-ms:cal
::
++  ms-arg
  |=  [args=quay:eyre k=@t]
  ^-  (unit @da)
  =/  v=(unit @t)  (get-key:kv:html-utils k args)
  ?~  v  ~
  (bind (rush u.v dem) ms-to-da)
::
::  +cross-site: a request another site's page made, as the browser
::  says (Sec-Fetch-Site). One without the header (curl, the gates, an
::  old browser) is not refused.
++  cross-site
  |=  req=inbound-request:eyre
  ^-  ?
  =/  site=(unit @t)  (get-header:http 'sec-fetch-site' header-list.request.req)
  ?=([~ ?(%'cross-site' %'same-site')] site)
::  +lead-pushes: one push per due timed occurrence. The tag is
::  eid+idx so a re-send replaces rather than stacks.
++  lead-pushes
  |=  [due=(list ref:cal) events=(map eid:cal event:cal) now=@da]
  ^-  (list [name=@t body=@t tag=@t])
  %+  murn  due
  |=  r=ref:cal
  ^-  (unit [name=@t body=@t tag=@t])
  =/  ev=(unit event:cal)  (~(get by events) eid.r)
  ?.  &(?=(^ ev) ?=(%timed -.u.ev))  ~
  =/  mins=@ud  (div ?:((gth l.span.r now) (sub l.span.r now) 0) ~m1)
  :-  ~
  :+  (meta-str:cal (meta-of:cal u.ev) 'name')
    (crip ?:(=(0 mins) "starting now" "in {(scow %ud mins)} min"))
  (crip "cal-{(trip eid.r)}-{(scow %ud idx.r)}")
::  +alarm-pushes: the alarms due in (from, now], as pushes. tag
::  cal-<uid>-<idx>-<n> for a relative alarm n of occurrence idx,
::  cal-<uid>-a-<n> for an absolute one (it belongs to the entry).
++  alarm-pushes
  |=  [ahead=(list ref:cal) entries=(map eid:cal entry:cal) from=@da now=@da zone=(unit @t)]
  ^-  (list [name=@t body=@t tag=@t])
  =/  in-win  |=(at=@da &((gth at from) (lte at now)))
  =/  rel=(list [name=@t body=@t tag=@t])
    %-  zing
    %+  turn  ahead
    |=  r=ref:cal
    ^-  (list [name=@t body=@t tag=@t])
    =/  en=(unit entry:cal)  (~(get by entries) eid.r)
    ?~  en  ~
    =/  name=@t  (meta-str:cal (meta-of:cal event.u.en) 'name')
    ::  a task's relative alarm counts from its due moment (RFC 5545
    ::  3.8.6.3), not from the day it sits on; an all-day occurrence's
    ::  from midnight where the calendar is, not in UTC
    =/  local  |=(d=@da (fall (fall (mole |.((place:rules zone d))) ~) d))
    =/  [at=@da end=@da]
      ?:  ?=(%todo -.event.u.en)  =/(d (fall due.event.u.en l.span.r) [d d])
      ?.  (all-day:cal event.u.en)  [l.span.r r.span.r]
      [(local l.span.r) (local r.span.r)]
    =/  mins=@ud  (div ?:((gth at now) (sub at now) 0) ~m1)
    =/  body=@t  (crip ?:(=(0 mins) "starting now" "in {(scow %ud mins)} min"))
    =/  als=(list alarm:cal)  alarms.u.en
    =/  n=@ud  0
    |-  ^-  (list [name=@t body=@t tag=@t])
    ?~  als  ~
    =/  rest  $(als t.als, n +(n))
    ::  when it fires: before the start, or %off from the start or the end
    =/  fire=(unit @da)
      ?-  -.trigger.i.als
        %abs  ~
        %rel  ?.((gte at before.trigger.i.als) ~ `(sub at before.trigger.i.als))
          %off
        =/  base=@da  ?:(end.trigger.i.als end at)
        ?:  late.trigger.i.als  `(add base d.trigger.i.als)
        ?.((gte base d.trigger.i.als) ~ `(sub base d.trigger.i.als))
      ==
    ?~  fire  rest
    ?.  (in-win u.fire)  rest
    :_  rest
    :+  name
      ?:(=('' desc.i.als) body desc.i.als)
    (crip "cal-{(trip eid.r)}-{(scow %ud idx.r)}-{(scow %ud n)}")
  =/  abs=(list [name=@t body=@t tag=@t])
    %-  zing
    %+  turn  ~(tap by entries)
    |=  [u=eid:cal en=entry:cal]
    ^-  (list [name=@t body=@t tag=@t])
    =/  name=@t  (meta-str:cal (meta-of:cal event.en) 'name')
    =/  als=(list alarm:cal)  alarms.en
    =/  n=@ud  0
    |-  ^-  (list [name=@t body=@t tag=@t])
    ?~  als  ~
    =/  rest  $(als t.als, n +(n))
    ?.  ?=(%abs -.trigger.i.als)  rest
    ?.  (in-win at.trigger.i.als)  rest
    :_  rest
    :+  name
      ?:(=('' desc.i.als) 'reminder' desc.i.als)
    (crip "cal-{(trip u)}-a-{(scow %ud n)}")
  (weld rel abs)
::  +do-sync: fetch each feed, parse its ICS, and convert single
::  (non-recurring) vevents inside [lo hi] into events tagged with
::  feed name + uid. Stable ids: same feed+uid = same event id. ok names
::  the feeds that answered and read; seen is every event id they hold,
::  in the window or not, so +apply-feeds deletes only what a feed that
::  answered no longer has.
+$  feed-sync
  $:  got=(map eid:cal event:cal)
      seen=(set eid:cal)
      ok=(set @t)
      skipped=@ud
  ==
++  feed-id
  |=  [nm=@t uid=@t]
  ^-  @ta
  (crip "gc-{(trip (scot %uw (mug [nm uid])))}")
::  +apply-feeds: a sync's events into the calendar. A feed event goes
::  only when its feed answered and no longer holds it.
++  apply-feeds
  |=  res=feed-sync
  |=  c=calendar:cal
  ^-  calendar:cal
  =/  stale=(list @ta)
    %+  murn  ~(tap by (events-all:cal c))
    |=  [id=@ta e=event:cal]
    =/  f=@t  (meta-str:cal (meta-of:cal e) 'feed')
    ?:  |(=('' f) !(~(has in ok.res) f) (~(has in seen.res) id))  ~
    `id
  =.  c  (roll stale |=([id=@ta acc=_c] (del-ev acc '' id)))
  (roll ~(tap by got.res) |=([[id=@ta e=event:cal] acc=_c] (put-ev acc '' id e)))
::  +ics-event: one parsed single vevent inside [lo hi] as a ship event,
::  read the way an import reads it, tagged with its feed and uid
++  ics-event
  |=  [ve=vevent:ics feed=@t lo=@da hi=@da dz=(unit @t)]
  ^-  (unit event:cal)
  ?~  start.ve  ~
  =/  sd=@da  (naive:ics u.start.ve)
  ?:  |((lth sd lo) (gth sd hi))  ~
  =/  got=(unit (unit [e=entry:cal exdates=(list @da)]))  (mole |.((to-entry:ics ve dz)))
  ?.  ?=([~ ~ *] got)  ~
  =/  ev=event:cal  event.e.u.u.got
  =/  meta=meta:cal  (~(gas by (meta-of:cal ev)) ~[['feed' s+feed] ['uid' s+uid.ve]])
  :-  ~
  ?-  -.ev
    %timed   ev(meta meta)
    %allday  ev(meta meta)
    %date    ev(meta meta)
    %todo    ev(meta meta)
  ==
::  +migrate-kinds: every event of a retired preset kind as the rrule it
::  phrases (+as-rrule:ics). Its indices do not move, so skips and caps
::  stay put; each changed entry is logged, so it goes out once to
::  wherever its calendar syncs.
++  migrate-kinds
  |=  c=calendar:cal
  ^-  calendar:cal
  %=    c
      cals
    %-  ~(run by cals.c)
    |=  k=cal:cal
    %+  roll  ~(val by entries.k)
    |=  [e=entry:cal acc=_k]
    =/  ev=event:cal  event.e
    ?:  ?=(?(%date %todo) -.ev)  acc
    ::  args the preset cannot read (a day named "Monday", say) leave the
    ::  event as it is: quiet, as the preset kind left it, never a crash
    ::  at every start
    =/  rc=recur:cal  (fall (mole |.((as-rrule:ics recur.ev))) recur.ev)
    ?:  =(rc recur.ev)  acc
    %+  put-entry:cal  acc
    ?-  -.ev
      %timed   e(event ev(recur rc))
      %allday  e(event ev(recur rc))
    ==
  ==
::  +kind-table: the rule kinds by name. An event names its kind by rail
::  ([/lib/rules %weekly]); the name is the lookup key, the path is
::  history.
::
++  kind-table
  ^-  (map @ta kind:rules)
  %-  ~(gas by *(map @ta kind:rules))
  :~  [%every k-every]
      [%once k-once]
      [%rrule k-rrule]
  ==
::  +parse-recur: json -> a shared clock [kind args start]. args
::  pass through as the 'args' object verbatim — only the kind file
::  knows what they mean.
::
++  parse-recur
  |=  jon=json
  ^-  (unit recur:cal)
  =/  kind=@t  (gs jon 'kind')
  ?:  =('' kind)  ~
  =/  start=(unit @da)  (bind (gn jon 'start_ms') ms-to-da)
  ?~  start  ~
  =/  args=(map @t json)
    =/  a=(unit json)  (~(get jo:json-utils jon) /args)
    ?.(?=([~ %o *] a) ~ p.u.a)
  =/  kn=(unit @tas)  (slaw %tas kind)
  ?~  kn  ~
  ::  a preset kind (daily, weekly, ...) from an older client is the rrule
  ::  it phrases; args it cannot read make the poke a bad one, not a crash
  (mole |.((as-rrule:ics [[/lib/rules u.kn] args u.start])))
::  +parse-event: json -> one of the three event shapes. dz is the
::  calendar's default zone for timed events with none named.
::
++  parse-event
  |=  [jon=json dz=(unit @t)]
  ^-  (unit event:cal)
  =/  cat=@t  (gs jon 'cat')
  ::  meta passes through verbatim; only 'name' is required
  =/  =meta:cal
    =/  mj=(unit json)  (~(get jo:json-utils jon) /meta)
    ?.(?=([~ %o *] mj) ~ p.u.mj)
  ?:  =('' (meta-str:cal meta 'name'))  ~
  ::  date: a bare recurring date, no clock
  ?:  =('date' cat)
    =/  mo=(unit @ud)  (gn jon 'month')
    =/  dy=(unit @ud)  (gn jon 'day')
    ?:  |(?=(~ mo) ?=(~ dy))  ~
    `[%date u.mo u.dy meta]
  ::  todo: a task, due (optional) and done (optional) as moments
  ?:  =('todo' cat)
    `[%todo (bind (gn jon 'due_ms') ms-to-da) (bind (gn jon 'done_ms') ms-to-da) meta]
  ::  timed / allday both wrap a recur
  =/  rec=(unit recur:cal)  (parse-recur jon)
  ?~  rec  ~
  ::  rrule args that cannot even be read (an "rrule" that is not text)
  ::  make the poke a bad one: stored, every later read would trip on them
  =/  rule=(unit (unit rule:rr))
    ?.  =(%rrule name.kind.u.rec)  `~
    (mole |.((of-args:rr args.u.rec)))
  ?~  rule  ~
  ::  count (or an RRULE's COUNT) is how many occurrences; the bound is
  ::  the index that holds that many (+dom-of)
  =/  dom=(unit @ud)
    =/  n=(unit @ud)
      =/  c=(unit @ud)  (gn jon 'count')
      ?^  c  ?:(=(0 u.c) ~ c)
      (biff u.rule |=(r=rule:rr count.r))
    ?~(n ~ `(fall (mole |.((dom-of:ics u.rec u.n))) u.n))
  =/  =bound:cal  [dom ~]
  ?:  =('allday' cat)
    =/  days=@ud  (max 1 (fall (gn jon 'span_days') 1))
    `[%allday u.rec days bound meta]
  ::  timed
  =/  zone=(unit @t)
    =/  z=@t  (gs jon 'zone')
    ?:  =('none' z)  ~
    ?:  =('' z)  dz
    ?:((known-zone:rules z) `z dz)
  =/  =fin:cal
    =/  f=@t  (gs jon 'fin')
    ?:  =('to' f)  [%to (fall (bind (gn jon 'end_ms') ms-to-da) *@da)]
    [%dur (mul (fall (gn jon 'dur_min') 0) ~m1)]
  `[%timed u.rec zone fin bound meta]
--
