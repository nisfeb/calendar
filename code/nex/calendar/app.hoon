::  calendar: events over the rules library
::
::  /calendar.calendar   portable intent: config + events (poke CRUD)
::  /order.calendar-cache     derived index, reinflated on calendar news
::  /main.sig            binds /apps/calendar
::  /requests            window.json + events.json endpoints
::
/<  cal    /lib/calendar.hoon
/<  rules  /lib/rules.hoon
/<  pytz   /lib/pytz.hoon
/<  ics    /lib/ics.hoon
/<  rr     /lib/rrule.hoon
/<  dav    /lib/dav.hoon
::  the rule kinds, compiled in. The ball-era calendar loaded them at run
::  time from /code/lib/rules/ through a granted road; a desk install has
::  no such road to grant, and the kinds are ours, so they are part of the
::  nexus. Events still name a kind by rail ([/lib/rules %weekly]); only
::  the lookup changed.
/<  k-cron         /lib/rules/cron.hoon
/<  k-daily        /lib/rules/daily.hoon
/<  k-every        /lib/rules/every.hoon
/<  k-monthly      /lib/rules/monthly.hoon
/<  k-monthly-nth  /lib/rules/monthly-nth.hoon
/<  k-once         /lib/rules/once.hoon
/<  k-weekly       /lib/rules/weekly.hoon
/<  k-yearly       /lib/rules/yearly.hoon
/<  k-rrule        /lib/rules/rrule.hoon
/&  icon      icon.svg
/&  cal-html  calendar.html
/&  cal-css   calendar.css
/&  cal-js    calendar.js
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Calendar'
            info+s+'Events and schedules'
            color+s+'#1e3a5f'
            image+s+'/grubbery/tiles/icon/calendar'
            href+s+'/apps/calendar'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'calendar'] ['description' s+'Calendar events']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'calendar.calendar'] [[/ %calendar] fresh-calendar:cal]]
          [%fall %& [/ %'order.calendar-cache'] [[/ %calendar-cache] *cache:cal]]
          [%fall %& [/ %'gcal-feeds.json'] [[/ %json] [%o ~]]]
          :*  %fall  %&  [/ %'reminders.json']
              :-  [/ %json]
              ^-  json
              :-  %o
              %-  ~(gas by *(map @t json))
              ~[['lead_min' n+'30'] ['fired_ms' n+'0']]
          ==
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'calendar.html'] [[/ %mime] cal-html]]
          [%over %& [/ %'calendar.css'] [[/ %mime] cal-css]]
          [%over %& [/ %'calendar.js'] [[/ %mime] cal-js]]
          [%fall %& [/ %'carried.json'] [[/ %json] b+|]]
          ::  dav-clients.json: the CalDAV client passwords, hashed
          [%fall %& [/ %'dav-clients.json'] [[/ %json] [%a ~]]]
          [%fall %| /requests empty-dir:loader]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%calendar main: failed")
        ::  a ship that ran the ball-era calendar has its data in a dormant
        ::  instance at /apps/calendar.calendar. Copy it across once, on the
        ::  first rise after the move; the old copy is left untouched.
        ;<  ~  bind:m  carry-old-data
        ;<  ~  bind:m  (bind-http-self:io [~ /apps/calendar])
        (http-dispatch:io %cal)
          ::
          ::  /calendar.calendar: poke CRUD on events
          ::
          [~ %'calendar.calendar']
        ;<  ~  bind:m  (rise-wait:io prod "%calendar events: failed")
        |-
        ;<  [* =sage:tarball]  bind:m  take-poke-from:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?.  ?=(%o -.jon)  $
        =/  act=@t  (gs jon 'action')
        ;<  raw=*  bind:m  (get-state-as:io ,*)
        =/  c=calendar:cal  (lift:cal raw)
        ?:  =('del-event' act)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          ?:  =('' id)  $
          ;<  ~  bind:m  (replace:io (del-ev c id))
          $
        ?:  =('skip-event' act)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  idx=(unit @ud)  (gn jon 'idx')
          ?:  |(=('' id) ?=(~ idx))  $
          =/  ev=(unit event:cal)  (~(get by (events-all:cal c)) id)
          ?~  ev  $
          =/  new=(unit event:cal)
            ?-  -.u.ev
              %date   ~                ::  a date can't be skipped
              %timed   `u.ev(except.bound (~(put in except.bound.u.ev) u.idx))
              %allday  `u.ev(except.bound (~(put in except.bound.u.ev) u.idx))
            ==
          ?~  new  $
          ;<  ~  bind:m  (replace:io (put-ev c id u.new))
          $
        ?:  =('add-calendar' act)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  nm=@t  (gs jon 'name')
          ?:  |(=('' id) =('' nm) (~(has by cals.c) id))  $
          =/  color=@t  (gs jon 'color')
          =/  k=cal:cal  fresh-cal:cal
          =.  props.k  [nm ?:(=('' color) '#1e3a5f' color) %local ~]
          ;<  ~  bind:m  (replace:io c(cals (~(put by cals.c) id k)))
          $
        ?:  =('edit-calendar' act)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  got=(unit cal:cal)  (~(get by cals.c) id)
          ?~  got  $
          =/  nm=@t  (gs jon 'name')
          =/  color=@t  (gs jon 'color')
          =.  name.props.u.got  ?:(=('' nm) name.props.u.got nm)
          =.  color.props.u.got  ?:(=('' color) color.props.u.got color)
          =.  kind.props.u.got
            ?+  (gs jon 'kind')  kind.props.u.got
              %local   %local
              %google  %google
            ==
          ;<  ~  bind:m  (replace:io c(cals (~(put by cals.c) id u.got)))
          $
        ?:  =('del-calendar' act)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          ?:  |(=('' id) =(%default id))  $
          ;<  ~  bind:m  (replace:io c(cals (~(del by cals.c) id)))
          $
        ?:  =('config' act)
          =/  ti=@t  (gs jon 'title')
          =/  zo=@t  (gs jon 'zone')
          =/  hd=(unit @ud)  (gn jon 'horizon_days')
          =.  title.c  ?:(=('' ti) title.c ti)
          =.  zone.c  ?:(=('' zo) zone.c ?:(=('none' zo) ~ `zo))
          =.  horizon.c  ?~(hd horizon.c (mul u.hd ~d1))
          ;<  ~  bind:m  (replace:io c)
          $
        ?:  =('add-feed' act)
          =/  nm=@t   (gs jon 'name')
          =/  url=@t  (gs jon 'url')
          ?:  |(=('' nm) =('' url))  $
          ;<  fv=view:nexus  bind:m
            (peek:io (cord-to-road:tarball './gcal-feeds.json') ~)
          =/  feeds=(map @t json)
            ?.  ?=([%file *] fv)  ~
            =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.fv)))) *json)
            ?.(?=(%o -.j) ~ p.j)
          ;<  ~  bind:m
            %+  over:io  (cord-to-road:tarball './gcal-feeds.json')
            [[/ %json] `json`[%o (~(put by feeds) nm s+url)]]
          $
        ?:  =('del-feed' act)
          =/  nm=@t  (gs jon 'name')
          ?:  =('' nm)  $
          ;<  fv=view:nexus  bind:m
            (peek:io (cord-to-road:tarball './gcal-feeds.json') ~)
          =/  feeds=(map @t json)
            ?.  ?=([%file *] fv)  ~
            =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.fv)))) *json)
            ?.(?=(%o -.j) ~ p.j)
          ;<  ~  bind:m
            %+  over:io  (cord-to-road:tarball './gcal-feeds.json')
            [[/ %json] `json`[%o (~(del by feeds) nm)]]
          $
        ?:  =('sync-feeds' act)
          ::  materialize external ICS feeds as events: drop all
          ::  prior feed-tagged events, re-add fresh (recurring
          ::  VEVENTs are skipped for now)
          ;<  feeds-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball './gcal-feeds.json') ~)
          =/  feeds=(list [nm=@t url=@t])
            ?.  ?=([%file *] feeds-view)  ~
            =/  j=json
              (fall (mole |.(!<(json (need-vase:tarball sang.feeds-view)))) *json)
            ?.  ?=(%o -.j)  ~
            %+  murn  ~(tap by p.j)
            |=([k=@t v=json] ?.(?=(%s -.v) ~ `[k p.v]))
          ?~  feeds
            ~&  >>>  "%calendar sync: no feeds configured"
            $
          ;<  now=@da  bind:m  get-time:io
          ;<  [synced=(map eid:cal event:cal) skipped=@ud]  bind:m
            (do-sync feeds (sub now (mul 90 ~d1)) (add now (mul 2 ~d365)))
          =/  stale=(list @ta)
            %+  murn  ~(tap by (events-all:cal c))
            |=  [id=@ta e=event:cal]
            ?:(=('' (meta-str:cal (get-meta e) 'feed')) ~ `id)
          =.  c  (roll stale |=([id=@ta acc=_c] (del-ev acc id)))
          =.  c  (roll ~(tap by synced) |=([[id=@ta e=event:cal] acc=_c] (put-ev acc id e)))
          ~&  >  "%calendar sync: {(scow %ud ~(wyt by synced))} synced, {(scow %ud skipped)} recurring skipped"
          ;<  ~  bind:m  (replace:io c)
          $
        ?:  =('edit-event' act)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  old=(unit event:cal)  (~(get by (events-all:cal c)) id)
          ?~  old  $
          =/  ev=(unit event:cal)  (parse-event jon zone.c)
          ?~  ev
            ~&  >>>  "%calendar: bad edit-event"
            $
          ::  the shape is replaced but exceptions survive the edit
          =/  merged=event:cal  (carry-except u.old u.ev)
          ;<  new=event:cal  bind:m  (apply-until merged (gn jon 'until_ms'))
          ;<  ~  bind:m  (replace:io (put-ev-in c (cal-arg jon) id new))
          $
        ?:  =('cap-event' act)
          ::  end the series before index dom (this-and-following edits)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  cap=(unit @ud)  (gn jon 'dom')
          ?:  |(=('' id) ?=(~ cap))  $
          =/  old=(unit event:cal)  (~(get by (events-all:cal c)) id)
          ?~  old  $
          =/  new=(unit event:cal)
            ?-  -.u.old
              %date   ~
              %timed   `u.old(dom.bound `u.cap)
              %allday  `u.old(dom.bound `u.cap)
            ==
          ?~  new  $
          ;<  ~  bind:m  (replace:io (put-ev c id u.new))
          $
        ?.  =('add-event' act)  $
        =/  ev=(unit event:cal)  (parse-event jon zone.c)
        ?~  ev
          ~&  >>>  "%calendar: bad add-event"
          $
        ;<  ev2=event:cal  bind:m  (apply-until u.ev (gn jon 'until_ms'))
        ;<  eny=@uvJ  bind:m  get-entropy:io
        ;<  our=@p  bind:m  get-our:io
        =/  id=@ta  (crip "{(scow %uv (end [3 8] eny))}@{(scow %p our)}")
        ;<  ~  bind:m  (replace:io (put-ev-in c (cal-arg jon) id ev2))
        $
          ::
          ::  /order.calendar-cache: reinflate on calendar news
          ::
          [~ %'order.calendar-cache']
        ;<  ~  bind:m  (rise-wait:io prod "%calendar cache: failed")
        =/  road  (cord-to-road:tarball './calendar.calendar')
        ;<  *  bind:m  (keep:io /cal road ~)
        |-
        ;<  =view:nexus  bind:m  (peek:io road ~)
        ?.  ?=([%file *] view)
          ;<  *  bind:m  (take-news:io /cal)
          $
        =/  c=calendar:cal  (cal-of view)
        =/  rails=(list rail:tarball)
          %~  tap  in
          %-  sy
          %+  murn  ~(tap by (events-all:cal c))
          |=  [@ta e=event:cal]
          ^-  (unit rail:tarball)
          ?-  -.e
            %date   ~
            %timed   `kind.recur.e
            %allday  `kind.recur.e
          ==
        ;<  kinds=(map rail:tarball kind:rules)  bind:m  (resolve-kinds rails)
        ;<  now=@da  bind:m  get-time:io
        =/  thru=@da  (add now horizon.c)
        =/  [stops=(map eid:cal @da) o=order:cal]  (inflate:cal (events-all:cal c) kinds thru)
        ;<  ~  bind:m  (replace:io `cache:cal`[thru stops o])
        ;<  *  bind:m  (take-news:io /cal)
        $
          ::
          ::  /reminders.json: tick on utc 5-minute marks, push-notify
          ::  timed events starting lead_min ahead. fired_ms is the
          ::  watermark: everything due in (fired, now] goes out once.
          ::
          [~ %'reminders.json']
        ;<  ~  bind:m  (rise-wait:io prod "%calendar reminders: failed")
        |-
        ;<  now=@da  bind:m  get-time:io
        =/  tick=@da  (add (sub now (mod now ~m5)) ~m5)
        ;<  ~  bind:m  (wait:io tick)
        ;<  now=@da  bind:m  get-time:io
        ;<  st=json  bind:m  (get-state-as:io ,json)
        =/  lead=@dr  (mul (max 1 (fall (gn st 'lead_min') 30)) ~m1)
        =/  fired=@da
          =/  ms=(unit @ud)  (gn st 'fired_ms')
          ?~(ms *@da (ms-to-da u.ms))
        ::  cap lookback so a ship that slept doesn't spam stale
        ::  reminders on wake
        =/  floor=@da  (sub now ~m15)
        =/  from=@da  ?:((gth fired floor) fired floor)
        ;<  cache-view=view:nexus  bind:m
          (peek:io (cord-to-road:tarball './order.calendar-cache') ~)
        ;<  cal-view=view:nexus  bind:m
          (peek:io (cord-to-road:tarball './calendar.calendar') ~)
        =/  ca=cache:cal
          ?.  ?=([%file *] cache-view)  *cache:cal
          (fall (mole |.(!<(cache:cal (need-vase:tarball sang.cache-view)))) *cache:cal)
        =/  c=calendar:cal  (cal-of cal-view)
        =/  lo=@da  (add from lead)
        =/  hi=@da  (add now lead)
        =/  due=(list ref:cal)
          %+  skim  ~(tap in (window:cal order.ca lo hi))
          |=  r=ref:cal
          &((gth l.span.r lo) (lte l.span.r hi))
        ;<  ~  bind:m  (send-reminders due (events-all:cal c) now)
        ::  alarms: a relative one fires when its occurrence minus the
        ::  lead falls in (from, now]; an absolute one when its moment
        ::  does. Occurrences up to 31 days out are considered — the
        ::  ceiling for a relative lead.
        =/  ahead=(list ref:cal)
          ~(tap in (window:cal order.ca from (add now ~d31)))
        ;<  ~  bind:m  (send-pushes (alarm-pushes ahead (entries-all:cal c) from now))
        =/  new-st=json
          :-  %o
          %-  ~(put by ?:(?=(%o -.st) p.st ~))
          ['fired_ms' (numb:enjs:format (da-to-ms now))]
        ;<  ~  bind:m  (replace:io new-st)
        $
          ::
          ::  /requests: window.json, events.json
          ::
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%calendar request: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m
          (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  suffix=path  (slag (lent `path`/apps/calendar) site)
        ::  /dav/...: CalDAV. Its own door: a minted client password over
        ::  HTTP Basic, or the owner's cookie. Never the src==our gate.
        ?:  ?=([%dav *] suffix)
          (dav-request eyre-id req our t.suffix args)
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        ::  /dav-clients.json, /dav-clients, /dav-clients/revoke: the owner
        ::  mints and revokes CalDAV client passwords. The password is
        ::  answered once and stored only as a salted hash.
        ?:  ?=([%'dav-clients.json' ~] suffix)
          ;<  clients=json  bind:m  dav-clients
          =/  rows=json
            :-  %a
            %+  turn  ?:(?=(%a -.clients) p.clients ~)
            |=  c=json
            ^-  json
            :-  %o
            %-  ~(gas by *(map @t json))
            :~  ['id' s+(gs c 'id')]
                ['name' s+(gs c 'name')]
                ['made_ms' (numb:enjs:format (fall (gn c 'made_ms') 0))]
            ==
          (send-json eyre-id rows)
        ?:  &(=('POST' method.request.req) ?=([%'dav-clients' ~] suffix))
          =/  jon=json
            (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
          =/  name=@t  (gs jon 'name')
          ?:  =('' name)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'need a name')])
            (pure:m ~)
          ;<  clients=json  bind:m  dav-clients
          ;<  eny=@uvJ  bind:m  get-entropy:io
          ;<  now=@da  bind:m  get-time:io
          =/  id=@t  (scot %uv (end [3 5] eny))
          =/  salt=@t  (scot %uv (end [3 10] (rsh [3 5] eny)))
          =/  password=@t  (crip (dav-password (rsh [3 15] eny)))
          =/  row=json
            :-  %o
            %-  ~(gas by *(map @t json))
            :~  ['id' s+id]
                ['name' s+name]
                ['salt' s+salt]
                ['hash' s+(dav-hash salt password)]
                ['made_ms' (numb:enjs:format (da-to-ms now))]
            ==
          =/  new=json  [%a (snoc ?:(?=(%a -.clients) p.clients ~) row)]
          ;<  ~  bind:m
            (over:io (cord-to-road:tarball '../dav-clients.json') [[/ %json] new])
          %+  send-json  eyre-id
          %-  pairs:enjs:format
          :~  ['id' s+id]
              ['name' s+name]
              ['password' s+password]
              ['url' s+'/apps/calendar/dav/']
          ==
        ?:  &(=('POST' method.request.req) ?=([%'dav-clients' %revoke ~] suffix))
          =/  jon=json
            (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
          =/  id=@t  (gs jon 'id')
          ;<  clients=json  bind:m  dav-clients
          =/  new=json
            :-  %a
            %+  skip  ?:(?=(%a -.clients) p.clients ~)
            |=(c=json =(id (gs c 'id')))
          ;<  ~  bind:m
            (over:io (cord-to-road:tarball '../dav-clients.json') [[/ %json] new])
          (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
        ?:  ?=([%'window.json' ~] suffix)
          =/  from=(unit @da)  (ms-arg args 'from')
          =/  to=(unit @da)    (ms-arg args 'to')
          ?:  |(?=(~ from) ?=(~ to))
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'need from/to (unix ms)')])
            (pure:m ~)
          ;<  cache-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../order.calendar-cache') ~)
          ;<  cal-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
          =/  ca=cache:cal
            ?.  ?=([%file *] cache-view)  *cache:cal
            (fall (mole |.(!<(cache:cal (need-vase:tarball sang.cache-view)))) *cache:cal)
          =/  c=calendar:cal  (cal-of cal-view)
          ::  refresh-ahead: the cache is derived state, so a read
          ::  past the wall (or with under half the horizon left)
          ::  reinflates and persists rather than serving a silent
          ::  truncation
          ;<  now=@da  bind:m  get-time:io
          ;<  ca=cache:cal  bind:m
            ?.  ?|  (gth u.to thru.ca)
                    (lth thru.ca (add now (div horizon.c 2)))
                ==
              (pure:(fiber:fiber:nexus ,cache:cal) ca)
            =/  m  (fiber:fiber:nexus ,cache:cal)
            =/  rails=(list rail:tarball)
              %~  tap  in
              %-  sy
              %+  murn  ~(tap by (events-all:cal c))
              |=  [@ta e=event:cal]
              ^-  (unit rail:tarball)
              ?-  -.e
                %date    ~
                %timed   `kind.recur.e
                %allday  `kind.recur.e
              ==
            ;<  kinds=(map rail:tarball kind:rules)  bind:m  (resolve-kinds rails)
            =/  thru=@da  (max (add now horizon.c) u.to)
            =/  [stops=(map eid:cal @da) o=order:cal]  (inflate:cal (events-all:cal c) kinds thru)
            =/  new=cache:cal  [thru stops o]
            ;<  ~  bind:m
              %+  over:io  (cord-to-road:tarball '../order.calendar-cache')
              [[/ %calendar-cache] new]
            (pure:m new)
          =/  refs=(list ref:cal)
            ~(tap in (window:cal order.ca u.from u.to))
          =/  owner=(map uid:cal @ta)  (owners c)
          =/  rows=json
            :-  %a
            %+  murn  refs
            |=  r=ref:cal
            ^-  (unit json)
            =/  ev=(unit event:cal)  (~(get by (events-all:cal c)) eid.r)
            ?~  ev  ~
            :-  ~
            %-  pairs:enjs:format
            :~  ['id' s+eid.r]
                ['cal' s+(fall (~(get by owner) eid.r) %default)]
                ['idx' (numb:enjs:format idx.r)]
                ['meta' [%o (get-meta u.ev)]]
                ['cat' s+-.u.ev]
                ['kind' s+(ev-kind u.ev)]
                ['all' b+(all-day:cal u.ev)]
                ['l' (numb:enjs:format (da-to-ms l.span.r))]
                ['r' (numb:enjs:format (da-to-ms r.span.r))]
            ==
          =/  caps=json
            :-  %a
            %+  murn  ~(tap by stops.ca)
            |=  [id=@ta stop=@da]
            ^-  (unit json)
            =/  ev=(unit event:cal)  (~(get by (events-all:cal c)) id)
            ?~  ev  ~
            :-  ~
            %-  pairs:enjs:format
            :~  ['id' s+id]
                ['meta' [%o (get-meta u.ev)]]
                ['stop' (numb:enjs:format (da-to-ms stop))]
            ==
          %+  send-json  eyre-id
          %-  pairs:enjs:format
          :~  ['caps' caps]
              ['rows' rows]
          ==
        ::  /event.json?id=: full rule breakdown for the edit form
        ?:  ?=([%'event.json' ~] suffix)
          =/  id=@ta  (crip (trip (fall (get-key:kv:html-utils 'id' args) '')))
          ;<  cal-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
          =/  c=calendar:cal  (cal-of cal-view)
          =/  ev=(unit event:cal)  (~(get by (events-all:cal c)) id)
          ?~  ev
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'No such event')])
            (pure:m ~)
          =/  ej=json  (event-json:cal id u.ev)
          =/  cid=@ta  (fall (~(get by (owners c)) id) %default)
          (send-json eyre-id ?:(?=(%o -.ej) [%o (~(put by p.ej) 'cal' s+cid)] ej))
        ?:  ?=([%'events.json' ~] suffix)
          ;<  cal-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
          =/  c=calendar:cal  (cal-of cal-view)
          =/  rows=json
            :-  %a
            =/  owner=(map uid:cal @ta)  (owners c)
            %+  turn  ~(tap by (entries-all:cal c))
            |=  [id=@ta e=entry:cal]
            ^-  json
            %-  pairs:enjs:format
            :~  ['id' s+id]
                ['cal' s+(fall (~(get by owner) id) %default)]
                ['etag' s+etag.e]
                ['meta' [%o (get-meta event.e)]]
                ['cat' s+-.event.e]
            ==
          (send-json eyre-id rows)
        ::  /feeds.json: the named external ICS feeds
        ?:  ?=([%'feeds.json' ~] suffix)
          ;<  fv=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../gcal-feeds.json') ~)
          =/  feeds=json
            ?.  ?=([%file *] fv)  [%o ~]
            =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.fv)))) *json)
            ?:(?=(%o -.j) j [%o ~])
          (send-json eyre-id feeds)
        ::  /zones.json: every pytz zone name, for dropdowns
        ::  /calendars.json: every calendar — id, props, seq, entry count
        ?:  ?=([%'calendars.json' ~] suffix)
          ;<  cal-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
          =/  c=calendar:cal  (cal-of cal-view)
          =/  rows=json
            :-  %a
            %+  turn  (sort ~(tap by cals.c) |=([a=[@ta *] b=[@ta *]] (aor -.a -.b)))
            |=  [id=@ta k=cal:cal]
            :-  %o
            %-  ~(gas by *(map @t json))
            :~  ['id' s+id]
                ['name' s+name.props.k]
                ['color' s+color.props.k]
                ['kind' s+kind.props.k]
                ['seq' (numb:enjs:format seq.k)]
                ['count' (numb:enjs:format ~(wyt by entries.k))]
            ==
          (send-json eyre-id rows)
        ::  export.ics[?cal=id]: every calendar, or one, as iCalendar.
        ?:  ?=([%'export.ics' ~] suffix)
          ;<  cal-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
          =/  c=calendar:cal  (cal-of cal-view)
          =/  only=(unit @t)  (get-key:kv:html-utils 'cal' args)
          ;<  now=@da  bind:m  get-time:io
          =/  picked=(list [id=@ta k=cal:cal])
            %+  skim  ~(tap by cals.c)
            |=([id=@ta *] ?~(only & =(u.only id)))
          =/  bodies=(list tape)
            %-  zing
            %+  turn  picked
            |=  [id=@ta k=cal:cal]
            %+  turn  ~(tap by entries.k)
            |=  [u=uid:cal e=entry:cal]
            (write-entry:ics e (exdates-of e) now)
          =/  body=@t  (write-calendar:ics title.c bodies)
          ;<  ~  bind:m
            %+  send-simple:srv  eyre-id
            :_  `(as-octs:mimes:html body)
            [200 ['content-type' 'text/calendar; charset=utf-8'] ['content-disposition' 'attachment; filename="calendar.ics"'] ~]
          (pure:m ~)
        ::  import?cal=id: an iCalendar body; each VEVENT becomes an entry
        ::  in that calendar (%default when unnamed), replacing one with the
        ::  same UID. Answers {imported, skipped}.
        ?:  ?=([%import ~] suffix)
          ?.  =('POST' method.request.req)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[405 ~] `(as-octs:mimes:html 'POST an .ics body')])
            (pure:m ~)
          =/  body=@t  ?~(body.request.req '' q.u.body.request.req)
          =/  target=@ta  (fall (get-key:kv:html-utils 'cal' args) %default)
          ;<  cal-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
          =/  c=calendar:cal  (cal-of cal-view)
          =/  k=cal:cal  (fall (~(get by cals.c) target) fresh-cal:cal)
          =/  ves=(list vevent:ics)  ?:(=('' body) ~ (events:ics body))
          =/  res=[k=cal:cal imported=@ud skipped=@ud]
            %+  roll  ves
            |=  [ve=vevent:ics acc=_[k=k imported=0 skipped=0]]
            =/  got=(unit [e=entry:cal exdates=(list @da)])  (to-entry:ics ve zone.c)
            ?~  got  acc(skipped +(skipped.acc))
            ?:  =('' uid.e.u.got)  acc(skipped +(skipped.acc))
            =/  e=entry:cal  (with-exdates e.u.got exdates.u.got)
            acc(k (put-entry:cal k.acc e), imported +(imported.acc))
          ;<  ~  bind:m
            %+  over:io  (cord-to-road:tarball '../calendar.calendar')
            [[/ %calendar] c(cals (~(put by cals.c) target k.res))]
          %+  send-json  eyre-id
          %-  pairs:enjs:format
          :~  ['imported' (numb:enjs:format imported.res)]
              ['skipped' (numb:enjs:format skipped.res)]
              ['cal' s+target]
          ==
        ?:  ?=([%'zones.json' ~] suffix)
          %+  send-json  eyre-id
          [%a (turn zone-names:pytz |=(n=@t `json`s+n))]
        ::  /config.json: title, display zone, poke target for the client
        ?:  ?=([%'config.json' ~] suffix)
          ::  our own address, read from grant.json (no peek / walk).
          ::  our own address, for the UI's poke url. grant.json is not a
          ::  stable source (the loader prunes it on a reload); the shell's
          ::  link registry is, and it is read through a granted road.
          ;<  base=(unit path)  bind:m  self-base
          =/  ball=tape
            ?~  base  ""
            =/  bt=tape  (spud u.base)
            ?:(?&(?=(^ bt) =('/' i.bt)) t.bt bt)
          ;<  zone-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
          =/  c=calendar:cal  (cal-of zone-view)
          =/  =json
            %-  pairs:enjs:format
            :~  ['title' s+title.c]
                ['zone' ?~(zone.c ~ s+u.zone.c)]
                ['ball' s+(crip ball)]
                ['ship' s+(scot %p our)]
            ==
          (send-json eyre-id json)
        ::  static files; the shell is the default
        =/  filename=@ta
          ?~  suffix  'calendar.html'
          i.suffix
        ;<  file-view=view:nexus  bind:m
          (peek:io (nex-road:io rail [%& / filename]) `[/ %mime])
        ?.  ?=([%file *] file-view)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
          (pure:m ~)
        =/  =mime  !<(mime (need-vase:tarball sang.file-view))
        ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
        (pure:m ~)
      ==
    --
|%
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::
::  +cal-of: a stored calendar view, any shape, or a fresh one
++  cal-of
  |=  vw=view:nexus
  ^-  calendar:cal
  ?.  ?=([%file *] vw)  fresh-calendar:cal
  (fall (mole |.((lift:cal (sang-noun:tarball sang.vw)))) fresh-calendar:cal)
::  +put-ev, +del-ev: an event by id into the calendar that holds it, or
::  %default for a new one. The entry's identity (uid, alarms, props)
::  survives an edit; only the event shape is replaced.
++  put-ev
  |=  [c=calendar:cal id=@ta ev=event:cal]
  ^-  calendar:cal
  (put-ev-in c ~ id ev)
::  +put-ev-in: like put-ev, into a named calendar (an unknown name falls
::  back to where the entry lives, or %default). An existing entry asked
::  into another calendar moves: deleted from the old, put into the new.
++  put-ev-in
  |=  [c=calendar:cal want=(unit @ta) id=@ta ev=event:cal]
  ^-  calendar:cal
  =/  got=(unit [cid=@ta e=entry:cal])  (find-entry:cal c id)
  =/  cid=@ta
    ?:  &(?=(^ want) (~(has by cals.c) u.want))  u.want
    ?~(got %default cid.u.got)
  =?  c  &(?=(^ got) !=(cid.u.got cid))  (del-ev c id)
  =/  k=cal:cal  (fall (~(get by cals.c) cid) fresh-cal:cal)
  =/  e=entry:cal  ?~(got [ev id '' 0 ~ ~] e.u.got(event ev))
  c(cals (~(put by cals.c) cid (put-entry:cal k e)))
::  +cal-arg: the poke's optional calendar name
++  cal-arg
  |=  jon=json
  ^-  (unit @ta)
  =/  v=@t  (gs jon 'cal')
  ?:(=('' v) ~ `(crip (trip v)))
::  +owners: which calendar holds each uid
++  owners
  |=  c=calendar:cal
  ^-  (map uid:cal @ta)
  %-  ~(gas by *(map uid:cal @ta))
  %-  zing
  %+  turn  ~(tap by cals.c)
  |=  [id=@ta k=cal:cal]
  (turn ~(tap by entries.k) |=([u=uid:cal *] [u id]))
++  del-ev
  |=  [c=calendar:cal id=@ta]
  ^-  calendar:cal
  =/  got=(unit [cid=@ta e=entry:cal])  (find-entry:cal c id)
  ?~  got  c
  =/  k=cal:cal  (fall (~(get by cals.c) cid.u.got) fresh-cal:cal)
  c(cals (~(put by cals.c) cid.u.got (del-entry:cal k id)))
::  +self-base: where this instance lives, from the shell's link registry
::  (/sys/link/calendar/dest.lanes: every instance claiming the name,
::  newest first, ours among them). ~ when the road is refused or the
::  registry has no row yet.
++  self-base
  =/  m  (fiber:fiber:nexus ,(unit path))
  ^-  form:m
  ;<  vw=(unit view:nexus)  bind:m
    (peek-soft:io [%& %& /sys/link/calendar %'dest.lanes'] ~)
  ?.  ?=([~ %file *] vw)  (pure:m ~)
  =/  ls=(unit (set lane:tarball))
    (mole |.(!<((set lane:tarball) (need-vase:tarball sang.u.vw))))
  ?~  ls  (pure:m ~)
  =/  dirs=(list path)
    %+  murn  ~(tap in u.ls)
    |=(=lane:tarball ?:(?=(%| -.lane) `p.lane ~))
  ?~  dirs  (pure:m ~)
  (pure:m `i.dirs)
::  +exdates-of: an entry's skipped occurrences as naive moments, through
::  its kind. A %date event has none.
++  exdates-of
  |=  e=entry:cal
  ^-  (list @da)
  =/  ev=event:cal  event.e
  ?:  ?=(%date -.ev)  ~
  =/  rc=recur:cal  recur.ev
  =/  ex=(set @ud)  ?-(-.ev %timed except.bound.ev, %allday except.bound.ev)
  =/  k=(unit kind:rules)  (kind-for kind.rc)
  ?~  k  ~
  %+  murn  (sort ~(tap in ex) lth)
  |=(idx=@ud (fall (mole |.((u.k args.rc start.rc idx))) ~))
::  +with-exdates: EXDATE moments back to indices of the entry's kind.
::  Walks the rule forward, bounded, matching on the moment; an EXDATE the
::  rule never produces is dropped.
++  with-exdates
  |=  [e=entry:cal exdates=(list @da)]
  ^-  entry:cal
  ?~  exdates  e
  =/  ev=event:cal  event.e
  ?:  ?=(%date -.ev)  e
  =/  rc=recur:cal  recur.ev
  =/  k=(unit kind:rules)  (kind-for kind.rc)
  ?~  k  e
  =/  want=(set @da)  (sy exdates)
  =|  got=(set @ud)
  =/  idx=@ud  0
  =/  dead=@ud  0
  |-
  ?:  |(=(0 ~(wyt in want)) (gth dead 400) (gth idx 10.000))
    =/  ev2=event:cal
      ?-  -.ev
        %timed   ev(except.bound (~(uni in except.bound.ev) got))
        %allday  ev(except.bound (~(uni in except.bound.ev) got))
      ==
    e(event ev2)
  =/  m=(unit @da)  (fall (mole |.((u.k args.rc start.rc idx))) ~)
  ?~  m  $(idx +(idx), dead +(dead))
  ?:  (~(has in want) u.m)
    $(idx +(idx), dead 0, got (~(put in got) idx), want (~(del in want) u.m))
  $(idx +(idx), dead 0)
::  ---- CalDAV ----
::  +dav-clients: the minted client passwords, hashed
++  dav-clients
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  vw=view:nexus  bind:m
    (peek:io (cord-to-road:tarball '../dav-clients.json') ~)
  ?.  ?=([%file *] vw)  (pure:m [%a ~])
  (pure:m (fall (mole |.(!<(json (need-vase:tarball sang.vw)))) [%a ~]))
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
  %+  lien  ?:(?=(%a -.clients) p.clients ~)
  |=  c=json
  =((gs c 'hash') (dav-hash (gs c 'salt') password))
::  +dav-request: the CalDAV handler. rest = the path after /dav.
++  dav-request
  |=  [eyre-id=@ta req=inbound-request:eyre our=@p rest=path args=quay:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  verb=@t  (dav-verb req)
  ;<  clients=json  bind:m  dav-clients
  ?.  (dav-authed req clients)
    ;<  ~  bind:m
      %+  send-simple:srv  eyre-id
      :_  `(as-octs:mimes:html 'calendar: a client password is required')
      [401 ['www-authenticate' 'Basic realm="calendar"'] ~]
    (pure:m ~)
  ?:  =('OPTIONS' verb)
    ;<  ~  bind:m
      %+  send-simple:srv  eyre-id
      :_  ~
      :~  200
          ['dav' '1, 3, calendar-access']
          ['allow' 'OPTIONS, GET, PUT, DELETE, PROPFIND, PROPPATCH, REPORT, MKCALENDAR']
      ==
    (pure:m ~)
  ?:  =('POST' verb)
    ;<  ~  bind:m
      (send-simple:srv eyre-id [[405 ['allow' 'OPTIONS, GET, PUT, DELETE, PROPFIND, PROPPATCH, REPORT, MKCALENDAR'] ~] `(as-octs:mimes:html 'calendar: POST needs X-HTTP-Method-Override')])
    (pure:m ~)
  ?.  ?=(?(%'PROPFIND' %'PROPPATCH' %'REPORT' %'MKCALENDAR' %'GET' %'PUT' %'DELETE' %'HEAD') verb)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[405 ~] `(as-octs:mimes:html 'calendar: unknown DAV verb')])
    (pure:m ~)
  ::  the resource: principal, home, a calendar, or an object
  =/  body=@t  ?~(body.request.req '' q.u.body.request.req)
  =/  res=dav-res  (dav-resolve rest)
  ;<  cal-view=view:nexus  bind:m
    (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
  =/  c=calendar:cal  (cal-of cal-view)
  ?:  =('PROPFIND' verb)
    (dav-propfind eyre-id req our c res body)
  ?:  ?=(?(%'GET' %'HEAD') verb)
    (dav-get eyre-id c res)
  ?:  =('REPORT' verb)
    (dav-report eyre-id req our c res body)
  ;<  ~  bind:m  (send-simple:srv eyre-id [[501 ~] `(as-octs:mimes:html 'calendar: not yet')])
  (pure:m ~)
::  +dav-children: the override entries of a parent, in one calendar
++  dav-children
  |=  [k=cal:cal parent=uid:cal]
  ^-  (list entry:cal)
  %+  murn  ~(tap by entries.k)
  |=  [* e=entry:cal]
  ^-  (unit entry:cal)
  ?.  (lien props.e |=([key=@t v=@t] &(=('X-GRUBBERY-PARENT' key) =(parent v))))  ~
  `e
::  +dav-object-ics: one object as iCalendar text: the parent, then its
::  override children (each carrying its RECURRENCE-ID in props)
++  dav-object-ics
  |=  [c=calendar:cal id=@ta =uid:cal now=@da]
  ^-  (unit @t)
  =/  k=(unit cal:cal)  (~(get by cals.c) id)
  ?~  k  ~
  =/  e=(unit entry:cal)  (~(get by entries.u.k) uid)
  ?~  e  ~
  =/  all=(list entry:cal)  [u.e (dav-children u.k uid)]
  :-  ~
  %+  write-calendar:ics  title.c
  (turn all |=(x=entry:cal (write-entry:ics x (exdates-of x) now)))
::  +dav-get: an object's .ics with its ETag
++  dav-get
  |=  [eyre-id=@ta c=calendar:cal res=dav-res]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=(%object -.res)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[405 ~] `(as-octs:mimes:html 'calendar: GET an object')])
    (pure:m ~)
  ;<  now=@da  bind:m  get-time:io
  =/  body=(unit @t)  (dav-object-ics c id.res uid.res now)
  =/  e=(unit entry:cal)
    =/  k=(unit cal:cal)  (~(get by cals.c) id.res)
    ?~(k ~ (~(get by entries.u.k) uid.res))
  ?:  |(?=(~ body) ?=(~ e))
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'calendar: no such object')])
    (pure:m ~)
  ;<  ~  bind:m
    %+  send-simple:srv  eyre-id
    :_  `(as-octs:mimes:html u.body)
    :~  200
        ['content-type' 'text/calendar; charset=utf-8']
        ['etag' (crip "\"{(trip etag.u.e)}\"")]
    ==
  (pure:m ~)
::  +dav-href-res: an href from a request body back to a resource
++  dav-href-res
  |=  h=tape
  ^-  dav-res
  =/  segs=(list @ta)
    %+  turn  (skip (split-tape h '/') |=(t=tape =(~ t)))
    |=(t=tape (crip t))
  ?.  ?=([%apps %calendar %dav *] segs)  [%none ~]
  (dav-resolve t.t.t.segs)
++  split-tape
  |=  [t=tape c=@t]
  ^-  (list tape)
  =|  cur=tape
  =|  out=(list tape)
  |-
  ?~  t  (flop [(flop cur) out])
  ?:  =(c i.t)  $(t t.t, out [(flop cur) out], cur ~)
  $(t t.t, cur [i.t cur])
::  +dav-obj-response: an object with its etag and calendar-data
++  dav-obj-response
  |=  [c=calendar:cal id=@ta =uid:cal now=@da with-data=?]
  ^-  manx
  =/  h=tape  (dav-obj-href id uid)
  =/  k=(unit cal:cal)  (~(get by cals.c) id)
  =/  e=(unit entry:cal)  ?~(k ~ (~(get by entries.u.k) uid))
  ?~  e  (status-response:dav h 404)
  =/  props=(list prop:dav)
    :-  (d-el:dav %getetag ~[(tx:dav "\"{(trip etag.u.e)}\"")])
    ?.  with-data  ~
    =/  ics=(unit @t)  (dav-object-ics c id uid now)
    ?~  ics  ~
    ~[(c-el:dav %'calendar-data' ~[(tx:dav (trip u.ics))])]
  (response:dav h props ~)
::  +dav-report: calendar-multiget, calendar-query, sync-collection
++  dav-report
  |=  [eyre-id=@ta req=inbound-request:eyre our=@p c=calendar:cal res=dav-res body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=(%calendar -.res)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'calendar: REPORT on a calendar')])
    (pure:m ~)
  =/  k=(unit cal:cal)  (~(get by cals.c) id.res)
  ?~  k
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'calendar: no such calendar')])
    (pure:m ~)
  =/  root=(unit manx)  (parse:dav body)
  ?~  root
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'calendar: REPORT needs an XML body')])
    (pure:m ~)
  ;<  now=@da  bind:m  get-time:io
  =/  kind=@tas  (local:dav n.g.u.root)
  =/  id=@ta  id.res
  ::  the parents (never the override children) of this calendar
  =/  parents=(list uid:cal)
    %+  murn  ~(tap by entries.u.k)
    |=([u=uid:cal e=entry:cal] ?:((dav-is-child e) ~ `u))
  ?:  =(%'calendar-multiget' kind)
    =/  hrefs=(list tape)  (turn (kids:dav u.root %href) text:dav)
    =/  responses=marl
      %+  turn  hrefs
      |=  h=tape
      =/  r=dav-res  (dav-href-res h)
      ?.  ?=(%object -.r)  (status-response:dav h 404)
      (dav-obj-response c id.r uid.r now &)
    (dav-send-xml eyre-id 207 (multistatus:dav responses ~))
  ?:  =(%'calendar-query' kind)
    =/  tr=(unit manx)  (find-el:dav u.root %'time-range')
    =/  range=(unit [lo=@da hi=@da])
      ?~  tr  ~
      =/  st=(unit tape)  (attr:dav u.tr %start)
      =/  en=(unit tape)  (attr:dav u.tr %end)
      =/  lo=(unit [d=@da z=?])  ?~(st ~ (parse-dt:ics (crip u.st)))
      =/  hi=(unit [d=@da z=?])  ?~(en ~ (parse-dt:ics (crip u.en)))
      `[?~(lo *@da d.u.lo) ?~(hi (add now (mul 10 ~d365)) d.u.hi)]
    ;<  uids=(list uid:cal)  bind:m
      ?~  range  (pure:(fiber:fiber:nexus ,(list uid:cal)) parents)
      ;<  cache-view=view:nexus  bind:(fiber:fiber:nexus ,(list uid:cal))
        (peek:io (cord-to-road:tarball '../order.calendar-cache') ~)
      =/  ca=cache:cal
        ?.  ?=([%file *] cache-view)  *cache:cal
        (fall (mole |.(!<(cache:cal (need-vase:tarball sang.cache-view)))) *cache:cal)
      ::  ponytail: a range past the inflated horizon answers every parent
      ::  (the client filters); a refresh-ahead here would need the
      ::  kinds resolved as window.json does
      ?:  (gth hi.u.range thru.ca)
        (pure:(fiber:fiber:nexus ,(list uid:cal)) parents)
      =/  refs=(list ref:cal)  ~(tap in (window:cal order.ca lo.u.range hi.u.range))
      =/  seen=(set uid:cal)
        %-  ~(gas in *(set uid:cal))
        %+  murn  refs
        |=  r=ref:cal
        ^-  (unit uid:cal)
        =/  e=(unit entry:cal)  (~(get by entries.u.k) eid.r)
        ?~  e  ~
        =/  par=(list [@t @t])  (skim props.u.e |=([key=@t *] =('X-GRUBBERY-PARENT' key)))
        ?~  par  `eid.r
        `+.i.par
      (pure:(fiber:fiber:nexus ,(list uid:cal)) ~(tap in seen))
    =/  responses=marl
      (turn uids |=(u=uid:cal (dav-obj-response c id u now &)))
    (dav-send-xml eyre-id 207 (multistatus:dav responses ~))
  ?:  =(%'sync-collection' kind)
    =/  tok=tape  ?~(t=(kid:dav u.root %'sync-token') "" (text:dav u.t))
    =/  since=@ud
      =/  segs=(list tape)  (skip (split-tape tok '/') |=(t=tape =(~ t)))
      =/  last=tape  ?~(segs "" (rear segs))
      (fall (rush (crip last) dem) 0)
    ::  the latest change per uid after the token; children never listed
    =/  changes=(list [uid:cal ?(%put %del)])
      =/  ents=(list [key=@ud val=logent:cal])  (tap:on-log:cal log.u.k)
      =/  latest=(map uid:cal ?(%put %del))
        %+  roll  ents
        |=  [[key=@ud val=logent:cal] acc=(map uid:cal ?(%put %del))]
        ?.  (gth key since)  acc
        ?^  (find "#" (trip uid.val))  acc
        (~(put by acc) uid.val kind.val)
      ~(tap by latest)
    =/  responses=marl
      %+  turn  changes
      |=  [u=uid:cal what=?(%put %del)]
      ?:  =(%del what)  (status-response:dav (dav-obj-href id u) 404)
      (dav-obj-response c id u now |)
    =/  token=manx  (d-el:dav %'sync-token' ~[(tx:dav "{dav-root}sync/{(a-co:co seq.u.k)}")])
    (dav-send-xml eyre-id 207 (multistatus:dav responses ~[token]))
  ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'calendar: unsupported report')])
  (pure:m ~)
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
  =/  nm=tape  (dec-seg:dav (trip i.t.t.rest))
  ::  strip a trailing .ics
  =/  n=@ud  (lent nm)
  =/  uid=tape  ?:(&((gte n 4) =(".ics" (slag (sub n 4) nm))) (scag (sub n 4) nm) nm)
  [%object id (crip uid)]
::  hrefs
++  dav-root  "/apps/calendar/dav/"
++  dav-cal-href  |=(id=@ta ^-(tape "{dav-root}cal/{(trip id)}/"))
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
        [%'supported-calendar-component-set' (c-el:dav %'supported-calendar-component-set' ~[[[[%'C' %comp] [[%name "VEVENT"] ~]] ~]])]
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
        [%getcontenttype (d-el:dav %getcontenttype ~[(tx:dav "text/calendar; charset=utf-8; component=VEVENT")])]
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
++  dav-is-child
  |=  e=entry:cal
  ^-  ?
  (lien props.e |=([k=@t *] =('X-GRUBBERY-PARENT' k)))
::  +dav-propfind
++  dav-propfind
  |=  [eyre-id=@ta req=inbound-request:eyre our=@p c=calendar:cal res=dav-res body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?:  ?=(%none -.res)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'calendar: no such resource')])
    (pure:m ~)
  =/  depth=@ud
    =/  d=(unit @t)  (get-header:http 'depth' header-list.request.req)
    ?:(|(?=(~ d) =('0' u.d)) 0 1)
  =/  asked=(list @tas)  (prop-names:dav (parse:dav body))
  =/  self-href=tape
    ?-  -.res
      %principal  dav-root
      %home       "{dav-root}cal/"
      %calendar   (dav-cal-href id.res)
      %object     (dav-obj-href id.res uid.res)
    ==
  =/  known=?
    ?-  -.res
      %principal  &
      %home       &
      %calendar   (~(has by cals.c) id.res)
      %object     ?~(k=(~(get by cals.c) id.res) | (~(has by entries.u.k) uid.res))
    ==
  ?.  known
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'calendar: no such resource')])
    (pure:m ~)
  =/  self=manx  (dav-response our c res self-href asked)
  =/  children=marl
    ?:  =(0 depth)  ~
    ?-    -.res
        %principal  ~
        %object     ~
        %home
      %+  turn  (sort ~(tap by cals.c) |=([a=[@ta *] b=[@ta *]] (aor -.a -.b)))
      |=  [id=@ta *]
      (dav-response our c [%calendar id] (dav-cal-href id) asked)
        %calendar
      =/  k=cal:cal  (fall (~(get by cals.c) id.res) fresh-cal:cal)
      %+  murn  ~(tap by entries.k)
      |=  [u=uid:cal e=entry:cal]
      ^-  (unit manx)
      ?:  (dav-is-child e)  ~
      `(dav-response our c [%object id.res u] (dav-obj-href id.res u) asked)
    ==
  (dav-send-xml eyre-id 207 (multistatus:dav [self children] ~))
++  dav-send-xml
  |=  [eyre-id=@ta code=@ud body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m
    %+  send-simple:srv  eyre-id
    [[code ['content-type' 'application/xml; charset=utf-8'] ~] `(as-octs:mimes:html body)]
  (pure:m ~)
++  get-meta
  |=  e=event:cal
  ^-  meta:cal
  ?-(-.e %timed meta.e, %allday meta.e, %date meta.e)
::  +ev-kind: the recurrence kind name, or 'date'
::
++  ev-kind
  |=  e=event:cal
  ^-  @t
  ?-(-.e %date 'date', %timed name.kind.recur.e, %allday name.kind.recur.e)
::  +carry-except: preserve the old event's skipped indices onto the
::  freshly-parsed replacement (only where both have a bound)
::
++  carry-except
  |=  [old=event:cal new=event:cal]
  ^-  event:cal
  =/  ex=(set @ud)
    ?-(-.old %date ~, %timed except.bound.old, %allday except.bound.old)
  ?~  ex  new
  ?-  -.new
    %date   new
    %timed   new(except.bound ex)
    %allday  new(except.bound ex)
  ==
::
++  gs
  |=  [jon=json k=@t]
  ^-  @t
  ?.  ?=(%o -.jon)  ''
  (fall (bind (~(get by p.jon) k) |=(=json ?>(?=(%s -.json) p.json))) '')
::
++  gn
  |=  [jon=json k=@t]
  ^-  (unit @ud)
  ?.  ?=(%o -.jon)  ~
  =/  j=(unit json)  (~(get by p.jon) k)
  ?~  j  ~
  ?.  ?=(%n -.u.j)  ~
  (rush p.u.j dem)
::
++  ms-to-da  |=(ms=@ud `@da`(add ~1970.1.1 (div (mul ms ~s1) 1.000)))
++  da-to-ms  |=(d=@da `@ud`(div (mul (sub d ~1970.1.1) 1.000) ~s1))
::
++  ms-arg
  |=  [args=quay:eyre k=@t]
  ^-  (unit @da)
  =/  v=(unit @t)  (get-key:kv:html-utils k args)
  ?~  v  ~
  (bind (rush u.v dem) ms-to-da)
::
++  send-json
  |=  [eyre-id=@ta =json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bod=octs  (as-octs:mimes:html (en:json:html json))
  ;<  ~  bind:m
    (send-simple:srv eyre-id [[200 ['content-type' 'application/json'] ~] `bod])
  (pure:m ~)
::  +send-reminders: one push per due timed occurrence. The tag is
::  eid+idx so a re-send replaces rather than stacks.
::
++  send-reminders
  |=  [due=(list ref:cal) events=(map eid:cal event:cal) now=@da]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  due  (pure:m ~)
  =/  r=ref:cal  i.due
  =/  ev=(unit event:cal)  (~(get by events) eid.r)
  ?.  &(?=(^ ev) ?=(%timed -.u.ev))
    $(due t.due)
  =/  name=@t  (meta-str:cal (get-meta u.ev) 'name')
  =/  mins=@ud
    (div ?:((gth l.span.r now) (sub l.span.r now) 0) ~m1)
  =/  body=@t
    (crip ?:(=(0 mins) "starting now" "in {(scow %ud mins)} min"))
  =/  tag=@t
    (crip "cal-{(trip eid.r)}-{(scow %ud idx.r)}")
  ;<  ~  bind:m
    (send-push:io [~ ~ ~ [name body ~ `'/apps/calendar' `tag]])
  $(due t.due)
::  +alarm-pushes: the alarms due in (from, now], as pushes. tag
::  cal-<uid>-<idx>-<n> for a relative alarm n of occurrence idx,
::  cal-<uid>-a-<n> for an absolute one (it belongs to the entry).
++  alarm-pushes
  |=  [ahead=(list ref:cal) entries=(map uid:cal entry:cal) from=@da now=@da]
  ^-  (list [name=@t body=@t tag=@t])
  =/  in-win  |=(at=@da &((gth at from) (lte at now)))
  =/  rel=(list [name=@t body=@t tag=@t])
    %-  zing
    %+  turn  ahead
    |=  r=ref:cal
    ^-  (list [name=@t body=@t tag=@t])
    =/  en=(unit entry:cal)  (~(get by entries) eid.r)
    ?~  en  ~
    =/  name=@t  (meta-str:cal (get-meta event.u.en) 'name')
    =/  mins=@ud  (div ?:((gth l.span.r now) (sub l.span.r now) 0) ~m1)
    =/  body=@t  (crip ?:(=(0 mins) "starting now" "in {(scow %ud mins)} min"))
    =/  als=(list alarm:cal)  alarms.u.en
    =/  n=@ud  0
    |-  ^-  (list [name=@t body=@t tag=@t])
    ?~  als  ~
    =/  rest  $(als t.als, n +(n))
    ?.  ?=(%rel -.trigger.i.als)  rest
    ?.  (gte l.span.r before.trigger.i.als)  rest
    ?.  (in-win (sub l.span.r before.trigger.i.als))  rest
    :_  rest
    :+  name
      ?:(=('' desc.i.als) body desc.i.als)
    (crip "cal-{(trip eid.r)}-{(scow %ud idx.r)}-{(scow %ud n)}")
  =/  abs=(list [name=@t body=@t tag=@t])
    %-  zing
    %+  turn  ~(tap by entries)
    |=  [u=uid:cal en=entry:cal]
    ^-  (list [name=@t body=@t tag=@t])
    =/  name=@t  (meta-str:cal (get-meta event.en) 'name')
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
++  send-pushes
  |=  pushes=(list [name=@t body=@t tag=@t])
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  pushes  (pure:m ~)
  ;<  ~  bind:m
    (send-push:io [~ ~ ~ [name.i.pushes body.i.pushes ~ `'/apps/calendar' `tag.i.pushes]])
  $(pushes t.pushes)
::  +do-sync: fetch each feed, parse its ICS, and convert single
::  (non-recurring) vevents inside [lo hi] into events tagged with
::  feed name + uid. Stable ids: same feed+uid = same event id.
::
++  do-sync
  |=  [feeds=(list [nm=@t url=@t]) lo=@da hi=@da]
  =/  m  (fiber:fiber:nexus ,[(map eid:cal event:cal) skipped=@ud])
  ^-  form:m
  =/  out=(map eid:cal event:cal)  ~
  =/  skipped=@ud  0
  |-
  ?~  feeds  (pure:m [out skipped])
  ~&  >  "%calendar sync: fetching {(trip nm.i.feeds)}"
  ;<  body=@t  bind:m  (fetch:io [%'GET' url.i.feeds ~ ~])
  =/  evs=(list vevent:ics)  ?:(=('' body) ~ (events:ics body))
  =/  res=[got=(map eid:cal event:cal) sk=@ud]
    %+  roll  evs
    |=  [ve=vevent:ics acc=[got=(map eid:cal event:cal) sk=@ud]]
    ?.  =('' rrule.ve)  acc(sk +(sk.acc))
    =/  ev=(unit event:cal)  (ics-event ve nm.i.feeds lo hi)
    ?~  ev  acc
    =/  id=@ta  (crip "gc-{(trip (scot %uw (mug [nm.i.feeds uid.ve])))}")
    acc(got (~(put by got.acc) id u.ev))
  %=  $
    feeds    t.feeds
    out      (~(uni by out) got.res)
    skipped  (add skipped sk.res)
  ==
::  +ics-event: one parsed vevent to a ship event. Date-only becomes
::  %allday; datetimes become a %timed %once, TZID as the zone and
::  DTEND as an absolute %to end.
::
++  ics-event
  |=  [ve=vevent:ics feed=@t lo=@da hi=@da]
  ^-  (unit event:cal)
  ?~  start.ve  ~
  =/  s=when:ics  u.start.ve
  =/  sd=@da  ?-(-.s %utc d.s, %local d.s, %day d.s)
  ?:  |((lth sd lo) (gth sd hi))  ~
  =/  =meta:cal
    %-  ~(gas by *(map @t json))
    ^-  (list [@t json])
    ;:  weld
      ^-  (list [@t json])
      ~[['name' s+?:(=('' summary.ve) 'Untitled' summary.ve)]]
      ^-  (list [@t json])
      ?:(=('' location.ve) ~ ~[['note' s+location.ve]])
      ^-  (list [@t json])
      ~[['feed' s+feed] ['uid' s+uid.ve]]
    ==
  ?:  ?=(%day -.s)
    =/  days=@ud
      ?~  end.ve  1
      ?.  ?=(%day -.u.end.ve)  1
      (max 1 (div (sub d.u.end.ve d.s) ~d1))
    `[%allday [[/lib/rules %once] ~ d.s] days [~ ~] meta]
  =/  zone=(unit @t)  ?:(?=(%local -.s) `zone.s ~)
  =/  =fin:cal
    ?~  end.ve  [%dur ~s0]
    ?-  -.u.end.ve
      %day    [%dur ~s0]
      %utc    [%to d.u.end.ve]
      %local  [%to d.u.end.ve]
    ==
  `[%timed [[/lib/rules %once] ~ sd] zone fin [~ ~] meta]
::  +weir-json: the roads calendar actually reaches (declared for the shell).
::
::  +carry-old-data: the grubs the ball-era calendar kept, copied from the
::  dormant instance at /apps/calendar.calendar into this one, once. The
::  road is optional and read-only; a veto is "nothing to carry", not an
::  error. Each grub's payload is written verbatim, boom or not, the way
::  lattice's carry does it. Marks itself done so a later rise never reads
::  the old copy again.
::
++  carry-old-data
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  marker  (cord-to-road:tarball './carried.json')
  ;<  mv=view:nexus  bind:m  (peek:io marker ~)
  =/  done=?
    ?.  ?=([%file *] mv)  |
    =/  j=(unit json)  (mole |.(!<(json (need-vase:tarball sang.mv))))
    ?:(?=([~ %b *] j) p.u.j |)
  ?:  done  (pure:m ~)
  =/  old=path  /apps/'calendar.calendar'
  ;<  vw=(unit view:nexus)  bind:m  (peek-soft:io [%& %| old] ~)
  ?~  vw
    ~&  >>>  [%calendar-carry-road-refused old]
    (pure:m ~)
  ?.  ?=([%ball *] u.vw)
    ;<  ~  bind:m  (over:io marker [[/ %json] `json`b+&])
    (pure:m ~)
  =/  bol=bole:tarball  (ball-to-bole:tarball ball.u.vw)
  =/  want=(list @ta)  ~['calendar.calendar' 'gcal-feeds.json' 'reminders.json']
  =/  fis=(list [nam=@ta =bask:tarball gain=?])
    ?~  fil.bol  ~
    %+  murn  want
    |=  nam=@ta
    ^-  (unit [@ta bask:tarball ?])
    =/  got  (~(get by contents.u.fil.bol) nam)
    ?~  got  ~
    `[nam bask.u.got gain.u.got]
  ~&  >  [%calendar-carrying-old-data (lent fis)]
  |-
  ?~  fis
    (over:io marker [[/ %json] `json`b+&])
  ;<  ~  bind:m  (over:io (cord-to-road:tarball (crip "./{(trip nam.i.fis)}")) bask.i.fis)
  $(fis t.fis)
++  weir-json
  ^-  json
  =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (line '/sys/bowl.sig' 'read the current time and our ship — every fiber uses get-time / get-our')
          (line '/sys/eyre/' 'bind its HTTP route and send page responses')
          (line '/sys/behn/' 'the reminders fiber ticks on 5-minute marks to fire due reminders')
          (line '/sys/push/' 'send a reminder as a notification when an event is about to start. Refuse this and the calendar still works; reminders just do not fire')
          (line '/sys/iris/' 'fetch the Google calendar feeds you add, by their secret address. Refuse this and feeds are unavailable; your own events are unaffected')
      ==
      :-  'peek'
      :-  %a
      :~  (line '/sys/link/' 'look up where this app is installed, so the page can address its own writer. Refuse this and the page cannot save events')
          (line '/apps/calendar.calendar/' 'copy your existing events, reminders and feeds across from where the calendar used to live. Read-only, once, and the old copy is left untouched. Refuse it and this install starts empty')
      ==
  ==
::  +resolve-kinds: load kind gates from the code namespace
::
::  +kind-table: the rule kinds by name. An event names its kind by rail
::  ([/lib/rules %weekly]); the name is the lookup key, the path is
::  history.
::
++  kind-table
  ^-  (map @ta kind:rules)
  %-  ~(gas by *(map @ta kind:rules))
  :~  [%cron k-cron]
      [%daily k-daily]
      [%every k-every]
      [%monthly k-monthly]
      [%monthly-nth k-monthly-nth]
      [%once k-once]
      [%weekly k-weekly]
      [%yearly k-yearly]
      [%rrule k-rrule]
  ==
++  kind-for
  |=  =rail:tarball
  ^-  (unit kind:rules)
  (~(get by kind-table) name.rail)
++  resolve-kinds
  |=  rails=(list rail:tarball)
  =/  m  (fiber:fiber:nexus ,(map rail:tarball kind:rules))
  ^-  form:m
  %-  pure:m
  %-  ~(gas by *(map rail:tarball kind:rules))
  %+  murn  rails
  |=  r=rail:tarball
  ^-  (unit [rail:tarball kind:rules])
  =/  k=(unit kind:rules)  (kind-for r)
  ?~(k ~ `[r u.k])
::  +apply-until: compile an until-date into dom by scanning the
::  rule's instances. Explicit count (dom already set) wins; sugar
::  only — the stored rule never knows about the date.
::
++  apply-until
  ::  compile an until-date into the index cap (dom) by walking the
  ::  kind's moments. Explicit count wins; only for shapes with a
  ::  recur (timed/allday). Sugar — the stored event keeps only dom.
  ::
  |=  [e=event:cal until=(unit @ud)]
  =/  m  (fiber:fiber:nexus ,event:cal)
  ^-  form:m
  ?~  until  (pure:m e)
  =/  rd=(unit [=recur:cal dom=(unit @ud)])
    ?-  -.e
      %date   ~
      %timed   `[recur.e dom.bound.e]
      %allday  `[recur.e dom.bound.e]
    ==
  ?~  rd  (pure:m e)
  ?.  ?=(~ dom.u.rd)  (pure:m e)  ::  explicit count wins
  =/  =recur:cal  recur.u.rd
  =/  lim=@da  (ms-to-da u.until)
  =/  kg=(unit kind:rules)  (kind-for kind.recur)
  ?~  kg  (pure:m e)
  =/  cap=@ud
    =/  idx=@ud  0
    =/  dead=@ud  0
    |-  ^-  @ud
    ?:  |((gth dead 400) (gth idx 10.000))  idx
    =/  moment=(unit @da)
      (fall (mole |.((u.kg args.recur start.recur idx))) ~)
    ?~  moment  $(idx +(idx), dead +(dead))
    ?:  (gth u.moment lim)  idx
    $(idx +(idx), dead 0)
  %-  pure:m
  ?-  -.e
    %date   e
    %timed   e(dom.bound `cap)
    %allday  e(dom.bound `cap)
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
  `[[/lib/rules (slav %tas kind)] args u.start]
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
  ::  timed / allday both wrap a recur
  =/  rec=(unit recur:cal)  (parse-recur jon)
  ?~  rec  ~
  =/  dom=(unit @ud)
    =/  n=(unit @ud)  (gn jon 'count')
    ?^  n  ?:(=(0 u.n) ~ n)
    ::  an RRULE's COUNT is its cap
    ?.  =(%rrule name.kind.u.rec)  ~
    =/  r=(unit rule:rr)  (parse:rr (str:~(. ja:rules args.u.rec) 'rrule'))
    ?~(r ~ count.u.r)
  =/  =bound:cal  [dom ~]
  ?:  =('allday' cat)
    =/  days=@ud  (max 1 (fall (gn jon 'span_days') 1))
    `[%allday u.rec days bound meta]
  ::  timed
  =/  zone=(unit @t)
    =/  z=@t  (gs jon 'zone')
    ?:  =('none' z)  ~
    ?:(=('' z) dz `z)
  =/  =fin:cal
    =/  f=@t  (gs jon 'fin')
    ?:  =('to' f)  [%to (fall (bind (gn jon 'end_ms') ms-to-da) *@da)]
    [%dur (mul (fall (gn jon 'dur_min') 0) ~m1)]
  `[%timed u.rec zone fin bound meta]
--
