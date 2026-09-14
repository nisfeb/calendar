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
/<  gcal   /lib/gcal.hoon
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
            color+s+'#101541'
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
          ::  google.json: the user's own OAuth client and the endpoints
          ::  (every URL is here so the gate can point them at a fake)
          [%fall %& [/ %'google.json'] [[/ %json] google-defaults]]
          ::  google-auth.json: the tokens. Never answered to the browser.
          [%fall %& [/ %'google-auth.json'] [[/ %json] [%o ~]]]
          ::  google-sync.json: per linked calendar, the sync token, the
          ::  id map and the push watermark
          [%fall %& [/ %'google-sync.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'google-conflicts.json'] [[/ %json] [%a ~]]]
          ::  caldav-remotes.json: the remote CalDAV calendars this ship
          ::  follows — url, credentials, sync token, href and etag per
          ::  uid, the push watermark. Never answered to the browser.
          [%fall %& [/ %'caldav-remotes.json'] [[/ %json] [%o ~]]]
          ::  sharing with ships. shares.json: which ship may see which
          ::  calendar, and how; /shares/<id>.json: the derived file a
          ::  peer reads; shares.sig: the inbox other ships poke offers
          ::  into; share-offers.json: what was offered to us; 
          ::  ship-remotes.json: the calendars we accepted, one row each
          [%fall %& [/ %'shares.json'] [[/ %json] [%o ~]]]
          [%fall %| /shares empty-dir:loader]
          [%fall %& [/ %'shares.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'share-offers.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'ship-remotes.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'google.sig'] [[/ %sig] ~]]
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
        ::  any ship may poke our share inbox: the road rides on /public
        ;<  ~  bind:m  lay-inbox-road
        (http-dispatch:io %cal)
          ::
          ::  /calendar.calendar: poke CRUD on events
          ::
          [~ %'calendar.calendar']
        ;<  ~  bind:m  (rise-wait:io prod "%calendar events: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?.  ?=(%o -.jon)  $
        =/  act=@t  (gs jon 'action')
        ;<  raw=*  bind:m  (get-state-as:io ,*)
        =/  c=calendar:cal  (lift:cal raw)
        ::  a foreign ship: only an edit to a calendar shared with it
        =/  src=(unit @p)  (get-poke-src:io from)
        ?^  src
          =/  cid=@ta  (crip (trip (gs jon 'cal')))
          ;<  shares=json  bind:m  (read-json-grub './' 'shares.json')
          =/  mode=@t  (gs (obj:gcal shares cid) (scot %p u.src))
          ?.  =('edit' mode)
            ~&  >>>  [%calendar-share-poke-refused u.src cid act]
            $
          =/  k=(unit cal:cal)  (~(get by cals.c) cid)
          ?~  k  $
          ?:  =('share-put' act)
            =/  ves=(list vevent:ics)  (fall (mole |.((events:ics (gs jon 'ics')))) ~)
            =/  put=(unit [k=cal:cal =uid:cal])  (put-object u.k ves zone.c '' ~)
            ?~  put  $
            ;<  ~  bind:m  (replace:io c(cals (~(put by cals.c) cid k.u.put)))
            $
          ?:  =('share-del' act)
            =/  u=@t  (gs jon 'uid')
            =/  kk=cal:cal
              %+  roll  (dav-children u.k u)
              |=([ch=entry:cal acc=_u.k] (del-entry:cal acc uid.ch))
            ;<  ~  bind:m  (replace:io c(cals (~(put by cals.c) cid (del-entry:cal kk u))))
            $
          $
        ::  a read-only shared calendar takes no local edits; an action
        ::  that names only an id is judged by the calendar that owns it
        =/  named=@ta  (crip (trip (gs jon 'cal')))
        =/  owner=@ta  (fall (~(get by (owners c)) (crip (trip (gs jon 'id')))) '')
        ?:  &(!=('' named) (ship-read-only c named))  $
        ?:  &(!=('' owner) (ship-read-only c owner))  $
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
              ?(%date %todo)  ~        ::  a date or a task can't be skipped
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
          ::  the kind is not editable here: a synced calendar becomes
          ::  local through migrate, which also retires its sync row
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
        ?:  =('done-event' act)
          ::  tick or untick a task
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  old=(unit event:cal)  (~(get by (events-all:cal c)) id)
          ?~  old  $
          ?.  ?=(%todo -.u.old)  $
          ;<  now=@da  bind:m  get-time:io
          =/  done=(unit @da)
            =/  j=(unit json)  (~(get by p.jon) 'done')
            ?:(?=([~ %b %.n] j) ~ `now)
          ;<  ~  bind:m  (replace:io (put-ev c id u.old(done done)))
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
              %todo   ~
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
            %todo   ~
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
          ::
          ::  /google.sig: the Google sync fiber (phase 4 task 2 fills it)
          ::
          [~ %'google.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%calendar google: failed")
        ::  a pass on every tick and prod (pull then push); on calendar
        ::  news, push only — a pass's own writes wake it, and a push-only
        ::  pass with nothing past the watermark does nothing
        =/  cal-road  (cord-to-road:tarball './calendar.calendar')
        ;<  *  bind:m  (keep:io /cal cal-road ~)
        |-
        ;<  cfg=json  bind:m  (google-config './')
        =/  tick=@dr  (mul ~m1 (max 1 (fall (gn cfg 'tick_min') 5)))
        ;<  now=@da  bind:m  get-time:io
        ;<  ~  bind:m  (set-timer:io /tick (add now tick))
        ;<  what=?(%news %poke)  bind:m  (take-any /cal)
        ;<  ~  bind:m  (cancel-timer:io /tick)
        ;<  ~  bind:m  (google-pass =(%poke what))
        ;<  ~  bind:m  (caldav-pass =(%poke what))
        ;<  ~  bind:m  share-pass
        ;<  ~  bind:m  (ship-pass =(%poke what))
        ::  a grant approved after the rise: the inbox road lands here
        ;<  ~  bind:m  lay-inbox-road
        $
          ::
          ::  /shares.sig: other ships poke offers (and revocations) of
          ::  calendars they share with us. The sender is the transport's;
          ::  the payload is data. An offer waits until the owner accepts.
          ::
          [~ %'shares.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%calendar shares inbox: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        =/  src=(unit @p)  (get-poke-src:io from)
        ?~  src  $
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?.  ?=(%o -.jon)  $
        =/  act=@t  (gs jon 'action')
        =/  cal-id=@t  (gs jon 'cal')
        ?:  =('' cal-id)  $
        =/  key=@t  (crip "{(scow %p u.src)}/{(trip cal-id)}")
        ;<  offers=json  bind:m  (read-json-grub './' 'share-offers.json')
        =/  cur=(map @t json)  ?:(?=(%o -.offers) p.offers ~)
        ?:  =('offer' act)
          ;<  now=@da  bind:m  get-time:io
          =/  mode=@t  ?:(=('edit' (gs jon 'mode')) 'edit' 'read')
          ::  already accepted: the host changed the mode; the row and the
          ::  calendar follow, no second offer
          ;<  rows=json  bind:m  (read-json-grub './' 'ship-remotes.json')
          =/  rm=(map @t json)  ?:(?=(%o -.rows) p.rows ~)
          =/  hit=(list [id=@t row=json])  (skim ~(tap by rm) |=([* r=json] =(key (gs r 'key'))))
          ;<  cal-view=view:nexus  bind:m  (peek:io (grub-road './' 'calendar.calendar') ~)
          =/  c=calendar:cal  (cal-of cal-view)
          =/  live=(unit [id=@t row=json k=cal:cal])
            ?~  hit  ~
            =/  k=(unit cal:cal)  (~(get by cals.c) id.i.hit)
            ?~(k ~ `[id.i.hit row.i.hit u.k])
          ::  a row whose calendar was deleted here is stale: it goes, and
          ::  the offer is a fresh one
          ;<  ~  bind:m
            ?:  |(?=(~ hit) ?=(^ live))  (pure:(fiber:fiber:nexus ,~) ~)
            (write-json-grub './' 'ship-remotes.json' [%o (~(del by rm) id.i.hit)])
          ?^  live
            =/  row=json  ?.(?=(%o -.row.u.live) row.u.live [%o (~(put by p.row.u.live) 'mode' s+mode)])
            ;<  ~  bind:m  (write-json-grub './' 'ship-remotes.json' [%o (~(put by rm) id.u.live row)])
            =.  remote.props.k.u.live  `(crip "{(trip key)}#{(trip mode)}")
            ;<  ~  bind:m  (dav-write './' c(cals (~(put by cals.c) id.u.live k.u.live)))
            ~&  >  [%calendar-share-mode key mode]
            $
          ::  ponytail: a full inbox drops new offers; 200 is far past
          ::  anything a person gets
          ?:  &((gte ~(wyt by cur) 200) !(~(has by cur) key))  $
          =/  row=json
            %-  pairs:enjs:format
            :~  ['host' s+(scot %p u.src)]
                ['cal' s+cal-id]
                ['name' s+(gs jon 'name')]
                ['color' s+(gs jon 'color')]
                ['mode' s+mode]
                ['base' s+(gs jon 'base')]
                ['at_ms' (numb:enjs:format (da-to-ms now))]
            ==
          ;<  ~  bind:m  (write-json-grub './' 'share-offers.json' [%o (~(put by cur) key row)])
          ~&  >  [%calendar-share-offered key]
          $
        ?:  =('revoke' act)
          ;<  ~  bind:m  (write-json-grub './' 'share-offers.json' [%o (~(del by cur) key)])
          ::  an accepted calendar stays, with its data: it becomes a
          ::  local calendar of ours, the same flip migrate does
          ;<  rows=json  bind:m  (read-json-grub './' 'ship-remotes.json')
          =/  rm=(map @t json)  ?:(?=(%o -.rows) p.rows ~)
          =/  hit=(list [id=@t row=json])  (skim ~(tap by rm) |=([* r=json] =(key (gs r 'key'))))
          ?~  hit  $
          ;<  ~  bind:m  (write-json-grub './' 'ship-remotes.json' [%o (~(del by rm) id.i.hit)])
          ;<  cal-view=view:nexus  bind:m  (peek:io (grub-road './' 'calendar.calendar') ~)
          =/  c=calendar:cal  (cal-of cal-view)
          =/  k=(unit cal:cal)  (~(get by cals.c) id.i.hit)
          ?~  k  $
          =.  props.u.k  props.u.k(kind %local, remote ~)
          ;<  ~  bind:m  (dav-write './' c(cals (~(put by cals.c) id.i.hit u.k)))
          ~&  >  [%calendar-share-revoked key]
          $
        $
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
        ?:  ?=([%google *] suffix)
          (google-request eyre-id req our t.suffix args)
        ?:  ?=([%caldav *] suffix)
          (caldav-request eyre-id req t.suffix)
        ?:  ?=([%share *] suffix)
          (share-request eyre-id req our t.suffix)
        ::  POST /migrate {id}: a followed or Google calendar becomes a
        ::  local one — one last pull, then the sync row goes and the
        ::  remote ids come off the events. The source is never touched;
        ::  deleting it there is the user's own act.
        ?:  &(=('POST' method.request.req) ?=([%migrate ~] suffix))
          =/  jon=json
            (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          ;<  cal-view=view:nexus  bind:m  (peek:io (grub-road '../' 'calendar.calendar') ~)
          =/  c=calendar:cal  (cal-of cal-view)
          =/  k=(unit cal:cal)  (~(get by cals.c) id)
          ?~  k
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'calendar: no such calendar')])
            (pure:m ~)
          =/  kind=?(%local %google %caldav %ship)  kind.props.u.k
          ?:  ?=(%local kind)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'calendar: already local')])
            (pure:m ~)
          ::  1. one last pull, so nothing on the remote is missed
          =/  rows-name=@t
            ?-  kind
              %google  'google-sync.json'
              %caldav  'caldav-remotes.json'
              %ship    'ship-remotes.json'
            ==
          ;<  rows=json  bind:m  (read-json-grub '../' rows-name)
          =/  row=(unit json)  ?:(?=(%o -.rows) (~(get by p.rows) id) ~)
          ;<  ~  bind:m
            ?~  row  (pure:(fiber:fiber:nexus ,~) ~)
            ;<  *  bind:(fiber:fiber:nexus ,~)
              ?-  kind
                %google  (google-pull '../' id u.row)
                %caldav  (caldav-pull '../' id u.row)
                %ship    (ship-pull '../' id u.row)
              ==
            (pure:(fiber:fiber:nexus ,~) ~)
          ::  2. the sync row goes: nothing pulls or pushes it again (a
          ::  fresh read: the pull above may have moved other rows)
          ;<  rows=json  bind:m  (read-json-grub '../' rows-name)
          ;<  ~  bind:m
            (write-json-grub '../' rows-name [%o (~(del by ?:(?=(%o -.rows) p.rows ~)) id)])
          ::  3. the calendar is local now; the remote ids come off
          ;<  cal-view=view:nexus  bind:m  (peek:io (grub-road '../' 'calendar.calendar') ~)
          =/  c=calendar:cal  (cal-of cal-view)
          =/  k=cal:cal  (fall (~(get by cals.c) id) fresh-cal:cal)
          =.  props.k  props.k(kind %local, remote ~)
          =.  k
            %+  roll  ~(tap by entries.k)
            |=  [[u=uid:cal e=entry:cal] acc=_k]
            =/  props=(list [@t @t])
              %+  skip  props.e
              |=([key=@t *] |(=('X-GOOGLE-ID' key) =('X-GOOGLE-UPDATED' key)))
            ?:  =(props props.e)  acc
            (put-entry:cal acc e(props props))
          ;<  ~  bind:m  (dav-write '../' c(cals (~(put by cals.c) id k)))
          %+  send-json  eyre-id
          %-  pairs:enjs:format
          :~  ['ok' b+&]
              ['id' s+id]
              ['events' (numb:enjs:format ~(wyt by entries.k))]
          ==
        ?:  ?=([%'google.json' ~] suffix)
          ;<  cfg=json  bind:m  (google-config '../')
          ;<  auth=json  bind:m  (google-auth '../')
          ;<  sync=json  bind:m  (google-sync '../')
          =/  masked=json
            ?.  ?=(%o -.cfg)  cfg
            =/  sec=@t  (gs cfg 'client_secret')
            :-  %o
            %-  ~(put by p.cfg)
            ['client_secret' s+?:(=('' sec) '' '••••••••')]
          %+  send-json  eyre-id
          ?.  ?=(%o -.masked)  masked
          :-  %o
          %-  ~(gas by p.masked)
          :~  ['connected' b+!=('' (gs auth 'refresh_token'))]
              ['linked' sync]
          ==
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
                %todo    ~
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
          =/  want=(unit @t)  (get-key:kv:html-utils 'tag' args)
          =/  rows=json
            :-  %a
            %+  murn  refs
            |=  r=ref:cal
            ^-  (unit json)
            =/  ev=(unit event:cal)  (~(get by (events-all:cal c)) eid.r)
            ?~  ev  ~
            ?.  ?~(want & ?=(^ (find ~[u.want] (meta-tags:cal (get-meta u.ev)))))  ~
            :-  ~
            %-  pairs:enjs:format
            :~  ['id' s+eid.r]
                ['cal' s+(fall (~(get by owner) eid.r) %default)]
                ['idx' (numb:enjs:format idx.r)]
                ['meta' [%o (get-meta u.ev)]]
                ['cat' s+-.u.ev]
                ['kind' s+(ev-kind u.ev)]
                ['all' b+(all-day:cal u.ev)]
                ['done' b+?:(?=(%todo -.u.ev) ?=(^ done.u.ev) |)]
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
        ::  /tags.json: every tag in use, with how many events carry it
        ?:  ?=([%'tags.json' ~] suffix)
          ;<  cal-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
          =/  c=calendar:cal  (cal-of cal-view)
          =/  counts=(map @t @ud)
            %+  roll  ~(tap by (events-all:cal c))
            |=  [[* e=event:cal] acc=(map @t @ud)]
            %+  roll  (meta-tags:cal (get-meta e))
            |=([t=@t a=_acc] (~(put by a) t +((fall (~(get by a) t) 0))))
          %+  send-json  eyre-id
          :-  %a
          %+  turn  (sort ~(tap by counts) |=([a=[@t @ud] b=[@t @ud]] (aor -.a -.b)))
          |=([t=@t n=@ud] (pairs:enjs:format ~[['tag' s+t] ['count' (numb:enjs:format n)]]))
        ?:  ?=([%'events.json' ~] suffix)
          ;<  cal-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
          =/  c=calendar:cal  (cal-of cal-view)
          =/  rows=json
            :-  %a
            =/  owner=(map uid:cal @ta)  (owners c)
            =/  want=(unit @t)  (get-key:kv:html-utils 'tag' args)
            %+  turn
              %+  skim  ~(tap by (entries-all:cal c))
              |=  [* e=entry:cal]
              ?~(want & ?=(^ (find ~[u.want] (meta-tags:cal (get-meta event.e)))))
            |=  [id=@ta e=entry:cal]
            ^-  json
            %-  pairs:enjs:format
            %+  weld
              ^-  (list [@t json])
              :~  ['id' s+id]
                  ['cal' s+(fall (~(get by owner) id) %default)]
                  ['etag' s+etag.e]
                  ['meta' [%o (get-meta event.e)]]
                  ['cat' s+-.event.e]
              ==
            ^-  (list [@t json])
            ?.  ?=(%todo -.event.e)  ~
            :~  ['due_ms' ?~(due.event.e ~ (numb:enjs:format (da-to-ms u.due.event.e)))]
                ['done' b+?=(^ done.event.e)]
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
            |=([id=@ta k=cal:cal] (export-objects k now))
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
          ?:  (ship-read-only c target)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'calendar: this calendar is shared with you read-only')])
            (pure:m ~)
          =/  k=cal:cal  (fall (~(get by cals.c) target) fresh-cal:cal)
          =/  ves=(list vevent:ics)  ?:(=('' body) ~ (events:ics body))
          =/  res=[k=cal:cal imported=@ud skipped=@ud]
            ::  one object per UID: a parent and its overrides together
            =/  groups=(map @t (list vevent:ics))
              %+  roll  ves
              |=  [ve=vevent:ics acc=(map @t (list vevent:ics))]
              ?:  =('' uid.ve)  acc
              (~(put by acc) uid.ve (snoc (fall (~(get by acc) uid.ve) ~) ve))
            %+  roll  ~(tap by groups)
            |=  [[u=@t group=(list vevent:ics)] acc=_[k=k imported=0 skipped=0]]
            =/  put=(unit [k=cal:cal =uid:cal])  (put-object k.acc group zone.c u ~)
            ?~  put  acc(skipped +(skipped.acc))
            acc(k k.u.put, imported +(imported.acc))
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
  ::  an override child goes with its parent
  =.  k
    %+  roll  (dav-children k id)
    |=([ch=entry:cal acc=_k] (del-entry:cal acc uid.ch))
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
  ?:  ?=(?(%date %todo) -.ev)  ~
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
  ?:  ?=(?(%date %todo) -.ev)  e
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
  ?:  =('PUT' verb)
    (dav-put eyre-id req c res body)
  ?:  =('DELETE' verb)
    (dav-delete eyre-id c res)
  ?:  =('MKCALENDAR' verb)
    (dav-mkcalendar eyre-id c res body)
  ?:  =('PROPPATCH' verb)
    (dav-proppatch eyre-id c res body)
  ;<  ~  bind:m  (send-simple:srv eyre-id [[501 ~] `(as-octs:mimes:html 'calendar: not yet')])
  (pure:m ~)
::  +dav-write: the calendar back to its grub
++  dav-write
  |=  [pre=@t c=calendar:cal]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (over:io (grub-road pre 'calendar.calendar') [[/ %calendar] c])
::  +dav-rid: an override's RECURRENCE-ID prop, if it has one
++  dav-rid
  |=  ve=vevent:ics
  ^-  (unit [key=@t val=@t])
  =/  hit=(list [key=@t val=@t])
    %+  skim  extra.ve
    |=  [key=@t *]
    =/  t=tape  (trip key)
    &((gte (lent t) 13) =("RECURRENCE-ID" (scag 13 t)))
  ?~(hit ~ `i.hit)
::  +dav-put: create or replace one object. The VEVENT without a
::  RECURRENCE-ID is the parent; each other becomes an override child
::  (uid <parent>#<recurrence-id>, once, at its own time) and the parent
::  skips that occurrence. A PUT replaces the whole override set.
++  dav-put
  |=  [eyre-id=@ta req=inbound-request:eyre c=calendar:cal res=dav-res body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  fail
    |=  [code=@ud why=@t]
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    ;<  ~  bind:m  (send-simple:srv eyre-id [[code ~] `(as-octs:mimes:html why)])
    (pure:m ~)
  ?.  ?=(%object -.res)  (fail 405 'calendar: PUT an object')
  =/  k=(unit cal:cal)  (~(get by cals.c) id.res)
  ?~  k  (fail 404 'calendar: no such calendar')
  ?:  (ship-read-only c id.res)  (fail 403 'calendar: this calendar is shared with you read-only')
  =/  ves=(list vevent:ics)  (events:ics body)
  ?~  ves  (fail 400 'calendar: no VEVENT or VTODO in the body')
  =/  parent=(unit vevent:ics)
    =/  ps=(list vevent:ics)  (skip `(list vevent:ics)`ves |=(v=vevent:ics ?=(^ (dav-rid v))))
    ?~(ps ~ `i.ps)
  ?~  parent  (fail 400 'calendar: no VEVENT without a RECURRENCE-ID')
  =/  got=(unit [e=entry:cal exdates=(list @da)])  (to-entry:ics u.parent zone.c)
  ?~  got  (fail 400 'calendar: could not read the VEVENT')
  =/  e=entry:cal  e.u.got
  =?  uid.e  =('' uid.e)  uid.res
  =/  existing=(unit entry:cal)  (~(get by entries.u.k) uid.e)
  =/  hs  header-list.request.req
  =/  if-none=(unit @t)  (get-header:http 'if-none-match' hs)
  =/  if-match=(unit @t)  (get-header:http 'if-match' hs)
  ?:  &(?=(^ if-none) =('*' u.if-none) ?=(^ existing))
    (fail 412 'calendar: an object with this UID exists')
  ?:  ?&  ?=(^ if-match)
          ?|  ?=(~ existing)
              !=(etag.u.existing (dav-unquote u.if-match))
          ==
      ==
    (fail 412 'calendar: the object changed; fetch it again')
  =/  put=(unit [k=cal:cal =uid:cal])  (put-object u.k ves zone.c uid.res ~)
  ?~  put  (fail 400 'calendar: could not read the VEVENT')
  =/  kk=cal:cal  k.u.put
  ;<  ~  bind:m  (dav-write '../' c(cals (~(put by cals.c) id.res kk)))
  =/  new-etag=@t
    =/  ne=(unit entry:cal)  (~(get by entries.kk) uid.e)
    ?~(ne '' etag.u.ne)
  ;<  ~  bind:m
    %+  send-simple:srv  eyre-id
    :_  ~
    :~  ?~(existing 201 204)
        ['etag' (crip "\"{(trip new-etag)}\"")]
    ==
  (pure:m ~)
::  +put-object: one iCalendar object's VEVENTs into a calendar: the one
::  without a RECURRENCE-ID is the parent, the others its overrides, and
::  the old override set goes. ~ when there is no parent or it cannot
::  be read. Import, DAV PUT and the follower all come through here.
++  put-object
  |=  [k=cal:cal ves=(list vevent:ics) zone=(unit @t) uid-hint=@t extra=(list [@t @t])]
  ^-  (unit [k=cal:cal =uid:cal])
  =/  parents=(list vevent:ics)  (skip `(list vevent:ics)`ves |=(v=vevent:ics ?=(^ (dav-rid v))))
  ?~  parents  ~
  ::  ponytail: a recurring task's instance overrides are dropped (a
  ::  task is one item here); keep them when tasks get a series view
  =/  overrides=(list vevent:ics)
    (skim `(list vevent:ics)`ves |=(v=vevent:ics &(?=(^ (dav-rid v)) !=('todo' cat.v))))
  =/  u=@t  ?:(=('' uid.i.parents) uid-hint uid.i.parents)
  ::  children the new set no longer carries go; the rest are re-put
  ::  in place (an identical one is left alone)
  =/  keep=(set @t)
    %-  ~(gas in *(set @t))
    %+  murn  overrides
    |=  v=vevent:ics
    =/  rid=(unit [key=@t val=@t])  (dav-rid v)
    ?~(rid ~ `(crip "{(trip u)}#{(trip val.u.rid)}"))
  =.  k
    %+  roll  (dav-children k u)
    |=([ch=entry:cal acc=_k] ?:((~(has in keep) uid.ch) acc (del-entry:cal acc uid.ch)))
  =/  put=(unit [k=cal:cal =uid:cal])  (put-parent-keep k i.parents zone u extra |)
  ?~  put  ~
  :-  ~
  :_  uid.u.put
  %+  roll  overrides
  |=([v=vevent:ics acc=_k.u.put] (put-override acc uid.u.put v zone extra))
::  +put-parent: a parent VEVENT into a calendar. An existing entry
::  keeps its identity (seq); the file's EXDATEs become skips. Extra
::  props (a Google id, say) ride along. ~ when the VEVENT cannot be read.
++  put-parent
  |=  [k=cal:cal ve=vevent:ics zone=(unit @t) uid-hint=@t extra=(list [@t @t])]
  ^-  (unit [k=cal:cal =uid:cal])
  (put-parent-keep k ve zone uid-hint extra &)
::  +put-parent-keep: keep=& carries the stored parent's skips forward
::  (an incremental update of the parent alone); keep=| rebuilds them
::  from the object (the overrides that follow re-add their own)
++  put-parent-keep
  |=  [k=cal:cal ve=vevent:ics zone=(unit @t) uid-hint=@t extra=(list [@t @t]) keep=?]
  ^-  (unit [k=cal:cal =uid:cal])
  =/  got=(unit [e=entry:cal exdates=(list @da)])  (to-entry:ics ve zone)
  ?~  got  ~
  =/  e=entry:cal  e.u.got
  =?  uid.e  =('' uid.e)  uid-hint
  =/  existing=(unit entry:cal)  (~(get by entries.k) uid.e)
  =?  e  ?=(^ existing)  e(seq seq.u.existing)
  =.  props.e  (weld extra (skip props.e |=([key=@t *] (lien extra |=([x=@t *] =(x key))))))
  =.  e  (with-exdates e exdates.u.got)
  ::  the parent's existing skips survive a re-put (an override's moment
  ::  stays skipped when only the parent changed)
  =?  e  &(keep ?=(^ existing))
    =/  old=event:cal  event.u.existing
    =/  ex=(set @ud)  ?-(-.old ?(%date %todo) ~, %timed except.bound.old, %allday except.bound.old)
    ?-  -.event.e
      ?(%date %todo)  e
      %timed   e(event event.e(except.bound (~(uni in except.bound.event.e) ex)))
      %allday  e(event event.e(except.bound (~(uni in except.bound.event.e) ex)))
    ==
  ::  an identical re-put is not a change: no log row, no seq, no etag
  ?:  &(?=(^ existing) =(etag.u.existing (make-etag:cal e)))  `[k uid.e]
  `[(put-entry:cal k e) uid.e]
::  +rid-moment: an override VEVENT's RECURRENCE-ID as a naive moment
++  rid-moment
  |=  ve=vevent:ics
  ^-  (unit @da)
  =/  rid=(unit [key=@t val=@t])  (dav-rid ve)
  ?~  rid  ~
  =/  w=(unit when:ics)  (when-of:ics key.u.rid val.u.rid)
  ?~  w  ~
  `?-(-.u.w %utc d.u.w, %local d.u.w, %day d.u.w)
::  +put-override: an exception instance as a child of its parent: the
::  parent skips that occurrence, the child (a once event at its own
::  time, tagged) replaces any older child with the same RECURRENCE-ID.
++  put-override
  |=  [k=cal:cal parent=uid:cal ve=vevent:ics zone=(unit @t) extra=(list [@t @t])]
  ^-  cal:cal
  =/  rid=(unit [key=@t val=@t])  (dav-rid ve)
  ?~  rid  k
  =/  cg=(unit [e=entry:cal exdates=(list @da)])  (to-entry:ics ve zone)
  ?~  cg  k
  =/  ch=entry:cal  e.u.cg
  =.  uid.ch  (crip "{(trip parent)}#{(trip val.u.rid)}")
  =.  props.ch  (weld extra [['X-GRUBBERY-PARENT' parent] (skip props.ch |=([key=@t *] (lien extra |=([x=@t *] =(x key)))))])
  =.  k  (skip-instance k parent (rid-moment ve))
  =/  old=(unit entry:cal)  (~(get by entries.k) uid.ch)
  ?:  &(?=(^ old) =(etag.u.old (make-etag:cal ch)))  k
  (put-entry:cal k ch)
::  +skip-instance: the parent skips one occurrence (a cancelled or
::  overridden instance)
++  skip-instance
  |=  [k=cal:cal parent=uid:cal moment=(unit @da)]
  ^-  cal:cal
  ?~  moment  k
  =/  pe=(unit entry:cal)  (~(get by entries.k) parent)
  ?~  pe  k
  =/  ne=entry:cal  (with-exdates u.pe ~[u.moment])
  ?:  =(event.ne event.u.pe)  k
  (put-entry:cal k ne)
++  dav-unquote
  |=  t=@t
  ^-  @t
  =/  s=tape  (trip t)
  =.  s  ?:(=("W/" (scag 2 s)) (slag 2 s) s)
  =.  s  ?:(&(!=(0 (lent s)) =('"' (snag 0 s))) (slag 1 s) s)
  =.  s  ?:(&(!=(0 (lent s)) =('"' (rear s))) (snip s) s)
  (crip s)
::  +dav-delete: an object (with its override children), or a calendar
++  dav-delete
  |=  [eyre-id=@ta c=calendar:cal res=dav-res]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?:  ?=(%calendar -.res)
    ?:  =(%default id.res)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'calendar: the default calendar stays')])
      (pure:m ~)
    ?.  (~(has by cals.c) id.res)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'calendar: no such calendar')])
      (pure:m ~)
    ;<  ~  bind:m  (dav-write '../' c(cals (~(del by cals.c) id.res)))
    ;<  ~  bind:m  (send-simple:srv eyre-id [[204 ~] ~])
    (pure:m ~)
  ?:  &(?=(%object -.res) (ship-read-only c id.res))
    ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'calendar: this calendar is shared with you read-only')])
    (pure:m ~)
  ?.  ?=(%object -.res)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[405 ~] `(as-octs:mimes:html 'calendar: DELETE an object or a calendar')])
    (pure:m ~)
  =/  k=(unit cal:cal)  (~(get by cals.c) id.res)
  ?:  |(?=(~ k) !(~(has by entries.u.k) uid.res))
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'calendar: no such object')])
    (pure:m ~)
  =/  kk=cal:cal
    %+  roll  (dav-children u.k uid.res)
    |=([ch=entry:cal acc=_u.k] (del-entry:cal acc uid.ch))
  =.  kk  (del-entry:cal kk uid.res)
  ;<  ~  bind:m  (dav-write '../' c(cals (~(put by cals.c) id.res kk)))
  ;<  ~  bind:m  (send-simple:srv eyre-id [[204 ~] ~])
  (pure:m ~)
::  +dav-mkcalendar: a new local calendar from the body's displayname
::  and calendar-color
++  dav-mkcalendar
  |=  [eyre-id=@ta c=calendar:cal res=dav-res body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=(%calendar -.res)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[405 ~] `(as-octs:mimes:html 'calendar: MKCALENDAR under cal/')])
    (pure:m ~)
  ?:  (~(has by cals.c) id.res)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[405 ~] `(as-octs:mimes:html 'calendar: that calendar exists')])
    (pure:m ~)
  =/  root=(unit manx)  (parse:dav body)
  =/  name=@t
    ?~  root  id.res
    =/  el=(unit manx)  (find-el:dav u.root %displayname)
    ?~(el id.res (crip (text:dav u.el)))
  =/  color=@t
    ?~  root  '#1e3a5f'
    =/  el=(unit manx)  (find-el:dav u.root %'calendar-color')
    ?~(el '#1e3a5f' (crip (scag 7 (text:dav u.el))))
  =/  k=cal:cal  fresh-cal:cal
  =.  props.k  [?:(=('' name) id.res name) ?:(=('' color) '#1e3a5f' color) %local ~]
  ;<  ~  bind:m  (dav-write '../' c(cals (~(put by cals.c) id.res k)))
  ;<  ~  bind:m  (send-simple:srv eyre-id [[201 ~] ~])
  (pure:m ~)
::  +dav-proppatch: displayname and calendar-color on a calendar
++  dav-proppatch
  |=  [eyre-id=@ta c=calendar:cal res=dav-res body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=(%calendar -.res)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[405 ~] `(as-octs:mimes:html 'calendar: PROPPATCH a calendar')])
    (pure:m ~)
  =/  k=(unit cal:cal)  (~(get by cals.c) id.res)
  ?~  k
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'calendar: no such calendar')])
    (pure:m ~)
  =/  root=(unit manx)  (parse:dav body)
  =/  set-el=(unit manx)  ?~(root ~ (find-el:dav u.root %set))
  =/  asked=marl
    ?~  set-el  ~
    =/  pr=(unit manx)  (kid:dav u.set-el %prop)
    ?~(pr ~ c.u.pr)
  =/  kk=cal:cal  u.k
  =/  done=(list prop:dav)  ~
  =/  refused=(list @tas)  ~
  =/  todo=marl  asked
  |-
  ?^  todo
    =/  n=@tas  (local:dav n.g.i.todo)
    ?:  =(%displayname n)
      =.  name.props.kk  (crip (text:dav i.todo))
      $(todo t.todo, done [(d-el:dav %displayname ~) done])
    ?:  =(%'calendar-color' n)
      =.  color.props.kk  (crip (scag 7 (text:dav i.todo)))
      $(todo t.todo, done [(el:dav [%'A' %'calendar-color'] ~) done])
    $(todo t.todo, refused [n refused])
  ;<  ~  bind:m  (dav-write '../' c(cals (~(put by cals.c) id.res kk)))
  =/  h=tape  (dav-cal-href id.res)
  =/  stats=marl
    :-  (propstat:dav 200 done)
    ?~  refused  ~
    ~[(propstat:dav 403 (turn refused |=(n=@tas (d-el:dav n ~))))]
  =/  resp=manx  (d-el:dav %response [(href:dav h) stats])
  (dav-send-xml eyre-id 207 (multistatus:dav ~[resp] ~))
::  +export-objects: a calendar as VEVENT bodies, one object per parent:
::  it and then its override children; a child is never on its own
++  export-objects
  |=  [k=cal:cal now=@da]
  ^-  (list tape)
  =/  ents=(list [uid:cal entry:cal])  ~(tap by entries.k)
  =|  out=(list tape)
  |-
  ?~  ents  (flop out)
  =/  u=uid:cal  -.i.ents
  =/  e=entry:cal  +.i.ents
  ?:  (dav-is-child e)  $(ents t.ents)
  =/  objs=(list entry:cal)  [e (dav-children k u)]
  =/  lines=(list tape)  (turn objs |=(x=entry:cal (write-entry:ics x (exdates-of x) now)))
  $(ents t.ents, out (weld (flop lines) out))
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
      =/  undated=(list uid:cal)
        %+  murn  ~(tap by entries.u.k)
        |=([u=uid:cal e=entry:cal] ?:(&(?=(%todo -.event.e) ?=(~ due.event.e)) `u ~))
      (pure:(fiber:fiber:nexus ,(list uid:cal)) ~(tap in (~(gas in seen) undated)))
    ::  a comp-filter naming only VTODO (or only VEVENT) narrows to
    ::  tasks (or events); anything else answers both
    =/  comps=(list tape)
      =/  walk
        |=  m=manx
        ^-  (list tape)
        %-  zing
        %+  turn  c.m
        |=  k=manx
        ^-  (list tape)
        =/  nm=(unit tape)  ?.(=(%'comp-filter' (local:dav n.g.k)) ~ (attr:dav k %name))
        (weld ?~(nm ~ ~[u.nm]) ^$(m k))
      (walk u.root)
    =/  want-todo=?  ?=(^ (find ~["VTODO"] comps))
    =/  want-event=?  ?=(^ (find ~["VEVENT"] comps))
    =.  uids
      ?:  =(want-todo want-event)  uids
      %+  skim  uids
      |=  u=uid:cal
      =/  e=(unit entry:cal)  (~(get by entries.u.k) u)
      ?~  e  |
      =(want-todo ?=(%todo -.event.u.e))
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
::  ---- Google ----
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
::  +grub-road: a grub at the instance root, from any fiber depth (the
::  request fibers live one dir down, at /requests/<id>)
++  grub-road
  |=  [pre=@t name=@t]
  ^-  road:tarball
  (cord-to-road:tarball (cat 3 pre name))
++  read-json-grub
  |=  [pre=@t name=@t]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io (grub-road pre name) ~)
  ?.  ?=([%file *] vw)  (pure:m [%o ~])
  (pure:m (fall (mole |.(!<(json (need-vase:tarball sang.vw)))) [%o ~]))
++  write-json-grub
  |=  [pre=@t name=@t jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (over:io (grub-road pre name) [[/ %json] jon])
++  google-config  |=(pre=@t (read-json-grub pre 'google.json'))
++  google-auth    |=(pre=@t (read-json-grub pre 'google-auth.json'))
++  google-sync    |=(pre=@t (read-json-grub pre 'google-sync.json'))
::  +fetch-full: an HTTP request with its status. A dropped connection
::  is status 0 rather than a crash.
++  fetch-full
  |=  =request:http
  =/  m  (fiber:fiber:nexus ,[status=@ud body=@t])
  ^-  form:m
  ;<  [status=@ud * body=@t]  bind:m  (fetch-hdr request)
  (pure:m [status body])
++  fetch-hdr
  |=  =request:http
  =/  m  (fiber:fiber:nexus ,[status=@ud headers=(list [@t @t]) body=@t])
  ^-  form:m
  ;<  ~  bind:m  (send-request:io request)
  ;<  res=client-response:iris  bind:m  take-client-response:io
  ?.  ?=(%finished -.res)  (pure:m [0 ~ ''])
  =/  body=@t  ?~(full-file.res '' q.data.u.full-file.res)
  (pure:m [status-code.response-header.res headers.response-header.res body])
++  form-body
  |=  kvs=(list [k=tape v=tape])
  ^-  octs
  %-  as-octs:mimes:html
  %-  crip
  %-  sep-join:rr
  :-  "&"
  (turn kvs |=([k=tape v=tape] "{k}={(enc-seg:dav v)}"))
::  +google-token: a valid access token, refreshed when near expiry.
::  ~ when the account is not connected or the refresh fails.
++  google-token
  |=  pre=@t
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ;<  cfg=json  bind:m  (google-config pre)
  ;<  auth=json  bind:m  (google-auth pre)
  =/  refresh=@t  (gs auth 'refresh_token')
  ?:  =('' refresh)  (pure:m ~)
  ;<  now=@da  bind:m  get-time:io
  =/  expires=@ud  (fall (gn auth 'expires_ms') 0)
  =/  access=@t  (gs auth 'access_token')
  ?:  &(!=('' access) (gth expires (add (da-to-ms now) 60.000)))
    (pure:m `access)
  ;<  [status=@ud body=@t]  bind:m
    %-  fetch-full
    :^  %'POST'  (gs cfg 'token_url')
      ~[['content-type' 'application/x-www-form-urlencoded']]
    :-  ~
    %-  form-body
    :~  ["grant_type" "refresh_token"]
        ["refresh_token" (trip refresh)]
        ["client_id" (trip (gs cfg 'client_id'))]
        ["client_secret" (trip (gs cfg 'client_secret'))]
    ==
  =/  tok=json  (fall (de:json:html body) *json)
  =/  access=@t  (gs tok 'access_token')
  ?:  |(!=(200 status) =('' access))
    ~&  >>>  [%calendar-google-refresh-failed status]
    (pure:m ~)
  =/  ttl=@ud  (fall (gn tok 'expires_in') 3.600)
  ;<  ~  bind:m
    %^  write-json-grub  pre  'google-auth.json'
    ?.  ?=(%o -.auth)  auth
    :-  %o
    %-  ~(gas by p.auth)
    :~  ['access_token' s+access]
        ['expires_ms' (numb:enjs:format (add (da-to-ms now) (mul 1.000 ttl)))]
    ==
  (pure:m `access)
::  +google-api: a call against api_base with the bearer token. status
::  401 when not connected.
++  google-api
  |=  [pre=@t method=method:http path=tape body=(unit json)]
  =/  m  (fiber:fiber:nexus ,[status=@ud =json])
  ^-  form:m
  ;<  cfg=json  bind:m  (google-config pre)
  ;<  tok=(unit @t)  bind:m  (google-token pre)
  ?~  tok  (pure:m [401 [%o ~]])
  =/  headers=(list [@t @t])
    :-  ['authorization' (cat 3 'Bearer ' u.tok)]
    ?~(body ~ ~[['content-type' 'application/json']])
  ;<  [status=@ud res=@t]  bind:m
    %-  fetch-full
    :^  method  (crip (weld (trip (gs cfg 'api_base')) path))
      headers
    ?~(body ~ `(as-octs:mimes:html (en:json:html u.body)))
  (pure:m [status (fall (de:json:html res) [%o ~])])
::  +google-request: the owner's Google routes under /apps/calendar/google/
++  google-request
  |=  [eyre-id=@ta req=inbound-request:eyre our=@p rest=path args=quay:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  jon=json
    (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
  =/  post=?  =('POST' method.request.req)
  =/  origin=tape
    =/  host=@t  (fall (get-header:http 'host' header-list.request.req) 'localhost')
    "{?:(secure.req "https" "http")}://{(trip host)}"
  =/  redirect=tape  "{origin}/apps/calendar/google/callback"
  =/  send-err
    |=  [code=@ud why=@t]
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    ;<  ~  bind:m  (send-simple:srv eyre-id [[code ~] `(as-octs:mimes:html why)])
    (pure:m ~)
  =/  redirect-to
    |=  where=tape
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    ;<  ~  bind:m  (send-simple:srv eyre-id [[302 ['location' (crip where)] ~] ~])
    (pure:m ~)
  ::  config: the user's client, and the endpoints (the gate swaps them)
  ?:  &(post ?=([%config ~] rest))
    ;<  cfg=json  bind:m  (google-config '../')
    =/  cur=(map @t json)  ?:(?=(%o -.cfg) p.cfg ~)
    =/  new=(map @t json)
      %+  roll  `(list @t)`~['client_id' 'client_secret' 'auth_url' 'token_url' 'api_base']
      |=  [k=@t acc=_cur]
      =/  v=@t  (gs jon k)
      ?:(=('' v) acc (~(put by acc) k s+v))
    =/  tick=(unit @ud)  (gn jon 'tick_min')
    =?  new  ?=(^ tick)  (~(put by new) 'tick_min' (numb:enjs:format (max 1 u.tick)))
    ;<  ~  bind:m  (write-json-grub '../' 'google.json' [%o new])
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  ::  connect: off to the consent screen
  ?:  ?=([%connect ~] rest)
    ;<  cfg=json  bind:m  (google-config '../')
    =/  cid=@t  (gs cfg 'client_id')
    ?:  =('' cid)  (send-err 400 'calendar: set the OAuth client first')
    ;<  eny=@uvJ  bind:m  get-entropy:io
    =/  state=@t  (scot %uv (end [3 12] eny))
    ;<  auth=json  bind:m  (google-auth '../')
    ;<  ~  bind:m
      %^  write-json-grub  '../'  'google-auth.json'
      [%o (~(put by ?:(?=(%o -.auth) p.auth ~)) 'state' s+state)]
    =/  q=(list [tape tape])
      :~  ["client_id" (trip cid)]
          ["redirect_uri" redirect]
          ["response_type" "code"]
          ["scope" "https://www.googleapis.com/auth/calendar"]
          ["access_type" "offline"]
          ["prompt" "consent"]
          ["state" (trip state)]
      ==
    =/  qs=tape  (sep-join:rr "&" (turn q |=([k=tape v=tape] "{k}={(enc-seg:dav v)}")))
    (redirect-to "{(trip (gs cfg 'auth_url'))}?{qs}")
  ::  callback: the code for the tokens
  ?:  ?=([%callback ~] rest)
    =/  code=@t  (fall (get-key:kv:html-utils 'code' args) '')
    ;<  auth0=json  bind:m  (google-auth '../')
    =/  want-state=@t  (gs auth0 'state')
    ?:  |(=('' want-state) !=(want-state (fall (get-key:kv:html-utils 'state' args) '')))
      (send-err 400 'calendar: the callback did not carry the state this ship issued')
    ?:  =('' code)
      (send-err 400 (crip "calendar: google answered without a code: {(trip (fall (get-key:kv:html-utils 'error' args) ''))}"))
    ;<  cfg=json  bind:m  (google-config '../')
    ;<  [status=@ud body=@t]  bind:m
      %-  fetch-full
      :^  %'POST'  (gs cfg 'token_url')
        ~[['content-type' 'application/x-www-form-urlencoded']]
      :-  ~
      %-  form-body
      :~  ["grant_type" "authorization_code"]
          ["code" (trip code)]
          ["client_id" (trip (gs cfg 'client_id'))]
          ["client_secret" (trip (gs cfg 'client_secret'))]
          ["redirect_uri" redirect]
      ==
    =/  tok=json  (fall (de:json:html body) *json)
    =/  refresh=@t  (gs tok 'refresh_token')
    =/  access=@t  (gs tok 'access_token')
    ?:  |(!=(200 status) =('' refresh))
      (send-err 502 (crip "calendar: token exchange failed ({(a-co:co status)}): {(trip (gs tok 'error_description'))}"))
    ;<  now=@da  bind:m  get-time:io
    ;<  ~  bind:m
      %^  write-json-grub  '../'  'google-auth.json'
      %-  pairs:enjs:format
      :~  ['refresh_token' s+refresh]
          ['access_token' s+access]
          ['expires_ms' (numb:enjs:format (add (da-to-ms now) (mul 1.000 (fall (gn tok 'expires_in') 3.600))))]
      ==
    (redirect-to "/apps/calendar?google=connected")
  ?:  &(post ?=([%disconnect ~] rest))
    ;<  ~  bind:m  (write-json-grub '../' 'google-auth.json' [%o ~])
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  ::  calendars.json: the account's calendars, with which are linked
  ?:  ?=([%'calendars.json' ~] rest)
    ;<  [status=@ud res=json]  bind:m
      (google-api '../' %'GET' "/calendar/v3/users/me/calendarList" ~)
    ?.  =(200 status)  (send-err status (crip "calendar: google answered {(a-co:co status)}"))
    ;<  sync=json  bind:m  (google-sync '../')
    =/  linked=(map @t @t)
      %-  ~(gas by *(map @t @t))
      %+  turn  ?:(?=(%o -.sync) ~(tap by p.sync) ~)
      |=([id=@t v=json] [(gs v 'google_id') id])
    =/  items=(list json)
      =/  it=(unit json)  ?:(?=(%o -.res) (~(get by p.res) 'items') ~)
      ?:(?=([~ %a *] it) p.u.it ~)
    %+  send-json  eyre-id
    :-  %a
    %+  turn  items
    |=  it=json
    ^-  json
    =/  gid=@t  (gs it 'id')
    %-  pairs:enjs:format
    :~  ['id' s+gid]
        ['name' s+(gs it 'summary')]
        ['color' s+(gs it 'backgroundColor')]
        ['primary' b+?=([~ %b %.y] (~(get by ?:(?=(%o -.it) p.it ~)) 'primary'))]
        ['linked' ?~(l=(~(get by linked) gid) ~ s+u.l)]
    ==
  ::  link: a ship calendar of kind google for one of them
  ?:  &(post ?=([%link ~] rest))
    =/  gid=@t  (gs jon 'google_id')
    ?:  =('' gid)  (send-err 400 'calendar: need google_id')
    ;<  cal-view=view:nexus  bind:m
      (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
    =/  c=calendar:cal  (cal-of cal-view)
    =/  id=@ta  (crip "g-{(trip (scot %uw (mug gid)))}")
    ?:  (~(has by cals.c) id)  (send-err 409 'calendar: already linked')
    =/  nm=@t  (gs jon 'name')
    =/  color=@t  (gs jon 'color')
    =/  k=cal:cal  fresh-cal:cal
    =.  props.k  [?:(=('' nm) gid nm) ?:(=('' color) '#1e3a5f' color) %google `gid]
    ;<  ~  bind:m  (dav-write '../' c(cals (~(put by cals.c) id k)))
    ;<  sync=json  bind:m  (google-sync '../')
    =/  row=json
      %-  pairs:enjs:format
      :~  ['google_id' s+gid]
          ['sync_token' s+'']
          ['last_ms' (numb:enjs:format 0)]
          ['pushed_seq' (numb:enjs:format 0)]
          ['ids' [%o ~]]
      ==
    ;<  ~  bind:m
      (write-json-grub '../' 'google-sync.json' [%o (~(put by ?:(?=(%o -.sync) p.sync ~)) id row)])
    ;<  ~  bind:m  (google-prod '../')
    (send-json eyre-id (pairs:enjs:format ~[['id' s+id]]))
  ?:  &(post ?=([%unlink ~] rest))
    =/  id=@ta  (crip (trip (gs jon 'id')))
    ;<  cal-view=view:nexus  bind:m
      (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
    =/  c=calendar:cal  (cal-of cal-view)
    ?.  (~(has by cals.c) id)  (send-err 404 'calendar: not linked')
    ;<  ~  bind:m  (dav-write '../' c(cals (~(del by cals.c) id)))
    ;<  sync=json  bind:m  (google-sync '../')
    ;<  ~  bind:m
      (write-json-grub '../' 'google-sync.json' [%o (~(del by ?:(?=(%o -.sync) p.sync ~)) id)])
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  ?:  &(post ?=([%sync ~] rest))
    ;<  ~  bind:m  (google-prod '../')
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  ?:  ?=([%'conflicts.json' ~] rest)
    ;<  cs=json  bind:m  (read-json-grub '../' 'google-conflicts.json')
    (send-json eyre-id ?:(?=(%a -.cs) cs [%a ~]))
  ?:  &(post ?=([%conflicts %clear ~] rest))
    ;<  ~  bind:m  (write-json-grub '../' 'google-conflicts.json' [%a ~])
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  (send-err 404 'calendar: no such google route')
::  +google-conflict: both versions kept, so nothing is lost silently.
::  Google's copy has already won; the local one rides along as ICS.
++  google-conflict
  |=  [pre=@t id=@ta =uid:cal local=(unit entry:cal) remote-updated=@t why=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cs=json  bind:m  (read-json-grub pre 'google-conflicts.json')
  ;<  now=@da  bind:m  get-time:io
  =/  ics=@t
    ?~  local  ''
    (write-calendar:ics 'conflict' ~[(write-entry:ics u.local (exdates-of u.local) now)])
  =/  row=json
    %-  pairs:enjs:format
    :~  ['uid' s+uid]
        ['cal' s+id]
        ['at_ms' (numb:enjs:format (da-to-ms now))]
        ['why' s+why]
        ['local' s+ics]
        ['remote_updated' s+remote-updated]
    ==
  ~&  >>  [%calendar-google-conflict uid why]
  =/  rest=(list json)  (skip ?:(?=(%a -.cs) p.cs ~) |=(c=json =(uid (gs c 'uid'))))
  (write-json-grub pre 'google-conflicts.json' [%a (snoc rest row)])
::  +suppressed: the log rows a sync pass itself wrote, as [uid key],
::  from the row. The push skips exactly those; nothing else.
++  suppressed
  |=  row=json
  ^-  (set [@t @ud])
  %-  ~(gas in *(set [@t @ud]))
  %+  murn  (arr:gcal row 'suppressed')
  |=  j=json
  ^-  (unit [@t @ud])
  ?.  ?=(%a -.j)  ~
  ?.  ?=([* * ~] p.j)  ~
  =/  u=json  i.p.j
  =/  k=json  i.t.p.j
  ?.  &(?=(%s -.u) ?=(%n -.k))  ~
  `[p.u (fall (rush p.k dem) 0)]
::  +suppress-json: the set back to the row, pruned of rows the
::  watermark has passed
++  suppress-json
  |=  [sup=(set [@t @ud]) floor=@ud]
  ^-  json
  :-  %a
  %+  turn  (skip ~(tap in sup) |=([* key=@ud] (lte key floor)))
  |=([u=@t key=@ud] `json`[%a ~[s+u (numb:enjs:format key)]])
::  +wrote-between: the log rows in (from, to], as [uid key]
++  wrote-between
  |=  [k=cal:cal from=@ud to=@ud]
  ^-  (set [@t @ud])
  %-  ~(gas in *(set [@t @ud]))
  %+  murn  (tap:on-log:cal log.k)
  |=  [key=@ud val=logent:cal]
  ?.(&((gth key from) (lte key to)) ~ `[uid.val key])
::  +pending-uids: the uids with a local change the push has not sent
::  yet — log rows above the watermark that no pass wrote itself
++  pending-uids
  |=  [k=cal:cal since=@ud sup=(set [@t @ud])]
  ^-  (set uid:cal)
  %-  ~(gas in *(set uid:cal))
  %+  murn  (tap:on-log:cal log.k)
  |=  [key=@ud val=logent:cal]
  ?.  (gth key since)  ~
  ?:  (~(has in sup) [uid.val key])  ~
  `uid.val
::  +take-any: the next news on a wire, or any poke (a timer wake is one)
++  take-any
  |=  =wire
  =/  m  (fiber:fiber:nexus ,?(%news %poke))
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    ?.(=(wire wire.u.in) [%skip ~] [%done %news])
      [~ %poke * *]
    [%done %poke]
  ==
::  +google-pass: pull each linked calendar (when asked), then push
++  google-pass
  |=  pull=?
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  pre=@t  './'
  ;<  sync=json  bind:m  (google-sync pre)
  =/  rows=(list [id=@t row=json])  ?:(?=(%o -.sync) ~(tap by p.sync) ~)
  ;<  tok=(unit @t)  bind:m  (google-token pre)
  ?~  tok  (pure:m ~)
  =|  done=(map @t json)
  |-
  ?~  rows
    ::  merge onto a fresh read: a link or unlink may have changed the
    ::  file while this pass waited on the network
    ?:  =(~ done)  (pure:m ~)
    ;<  fresh=json  bind:m  (google-sync pre)
    =/  cur=(map @t json)  ?:(?=(%o -.fresh) p.fresh ~)
    =/  merged=(map @t json)
      %+  roll  ~(tap by done)
      |=  [[id=@t row=json] acc=_cur]
      ?.((~(has by acc) id) acc (~(put by acc) id row))
    (write-json-grub pre 'google-sync.json' [%o merged])
  ;<  row=json  bind:m
    ?.  pull  (pure:(fiber:fiber:nexus ,json) row.i.rows)
    (google-pull pre (crip (trip id.i.rows)) row.i.rows)
  ;<  row=json  bind:m  (google-push pre (crip (trip id.i.rows)) row)
  ?:  =(row row.i.rows)  $(rows t.rows)
  $(rows t.rows, done (~(put by done) id.i.rows row))
::  +google-pull: one calendar, all pages, applied; the row comes back
::  with the new token, time, id map and watermark
++  google-pull
  |=  [pre=@t id=@ta row=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  gid=@t  (gs row 'google_id')
  =/  tok=@t  (gs row 'sync_token')
  =/  full=?  =('' tok)
  =/  base=tape  "/calendar/v3/calendars/{(enc-seg:dav (trip gid))}/events?maxResults=250"
  =/  ids=(map @t json)  =/(i (obj:gcal row 'ids') ?:(?=(%o -.i) p.i ~))
  =/  page=@t  ''
  =/  seen=(set uid:cal)  ~
  =/  retried=?  |
  |-
  =/  q=tape
    ;:  weld
      base
      ?:(full "&showDeleted=true&singleEvents=false" "&syncToken={(enc-seg:dav (trip tok))}")
      ?:(=('' page) "" "&pageToken={(enc-seg:dav (trip page))}")
    ==
  ;<  [status=@ud res=json]  bind:m  (google-api pre %'GET' q ~)
  ?:  &(=(410 status) !retried)
    ~&  >  [%calendar-google-resync id]
    $(full &, tok '', page '', retried &)
  ?.  =(200 status)
    ~&  >>>  [%calendar-google-pull-failed id status]
    (pure:m row)
  ;<  cal-view=view:nexus  bind:m  (peek:io (grub-road pre 'calendar.calendar') ~)
  =/  c=calendar:cal  (cal-of cal-view)
  =/  k=cal:cal  (fall (~(get by cals.c) id) fresh-cal:cal)
  ?.  ?=(%google kind.props.k)  (pure:m row)
  =/  k=cal:cal  k
  =/  items=(list gitem:gcal)  (murn (arr:gcal res 'items') item-of:gcal)
  ::  an item whose uid also changed here since the last push is a
  ::  conflict: Google wins, the local copy is logged
  =/  sup=(set [@t @ud])  (suppressed row)
  =/  pending=(set uid:cal)  (pending-uids k (fall (gn row 'pushed_seq') 0) sup)
  =/  seq-at-peek=@ud  seq.k
  =/  clashes=(list gitem:gcal)
    (skim items |=(g=gitem:gcal &(?=(~ rid.g) (~(has in pending) uid.ve.g))))
  ;<  ~  bind:m
    =/  m  (fiber:fiber:nexus ,~)
    |-  ^-  form:m
    ?~  clashes  (pure:m ~)
    ;<  ~  bind:m
      (google-conflict pre id uid.ve.i.clashes (~(get by entries.k) uid.ve.i.clashes) updated.i.clashes 'changed on both sides; google kept')
    $(clashes t.clashes)
  ::  parents first, so an instance finds its parent
  =/  parents=(list gitem:gcal)  (skip items |=(g=gitem:gcal ?=(^ rid.g)))
  =/  insts=(list gitem:gcal)  (skim items |=(g=gitem:gcal ?=(^ rid.g)))
  =/  res2=[k=cal:cal ids=(map @t json) seen=(set uid:cal)]
    %+  roll  (weld parents insts)
    |=  [g=gitem:gcal acc=_[k=k ids=ids seen=seen]]
    =/  u=uid:cal  uid.ve.g
    =/  extra=(list [@t @t])  ~[['X-GOOGLE-ID' gid.g] ['X-GOOGLE-UPDATED' updated.g]]
    ?^  rid.g
      =.  seen.acc  (~(put in seen.acc) u)
      ?:  cancelled.g
        acc(k (skip-instance k.acc u (rid-moment ve.g)))
      acc(k (put-override k.acc u ve.g zone.c extra))
    ?:  cancelled.g
      =.  k.acc  (del-entry:cal k.acc u)
      =.  k.acc
        %+  roll  (dav-children k.acc u)
        |=([ch=entry:cal a=_k.acc] (del-entry:cal a uid.ch))
      acc(ids (~(del by ids.acc) u))
    =/  put=(unit [k=cal:cal =uid:cal])  (put-parent k.acc ve.g zone.c u extra)
    ?~  put  acc
    acc(k k.u.put, ids (~(put by ids.acc) u s+gid.g), seen (~(put in seen.acc) u))
  =.  k  k.res2
  =.  ids  ids.res2
  =.  seen  (~(uni in seen) seen.res2)
  =/  next-page=@t  (gs res 'nextPageToken')
  =/  next-tok=@t  (gs res 'nextSyncToken')
  ::  a full listing is the whole truth: what it did not name is gone
  =?  k  &(full =('' next-page))
    %+  roll  ~(tap by entries.k)
    |=  [[u=uid:cal e=entry:cal] acc=_k]
    ?:  (dav-is-child e)  acc
    ?:  (~(has in seen) u)  acc
    ?:  (lien props.e |=([key=@t *] =('X-GOOGLE-ID' key)))
      (del-entry:cal acc u)
    acc
  ;<  ~  bind:m  (dav-write pre c(cals (~(put by cals.c) id k)))
  ;<  now=@da  bind:m  get-time:io
  ::  what this pull wrote is not for pushing back: the push skips these
  ::  uids up to this seq, and moves the watermark itself
  =/  row2=json
    ?.  ?=(%o -.row)  row
    :-  %o
    %-  ~(gas by p.row)
    :~  ['sync_token' s+?:(=('' next-tok) tok next-tok)]
        ['last_ms' (numb:enjs:format (da-to-ms now))]
        ['ids' [%o ids]]
        ['suppressed' (suppress-json (~(uni in sup) (wrote-between k seq-at-peek seq.k)) (fall (gn row 'pushed_seq') 0))]
    ==
  ?.  =('' next-page)  $(page next-page, row row2)
  (pure:m row2)
::  +google-push: the calendar's log past the watermark, out. A parent
::  with a known Google id is updated, without one inserted; a delete
::  goes by the id map. Children (overrides) are not pushed. A 5xx, 429
::  or dropped connection stops the pass and keeps the watermark.
++  google-push
  |=  [pre=@t id=@ta row=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  gid=@t  (gs row 'google_id')
  =/  since=@ud  (fall (gn row 'pushed_seq') 0)
  =/  ids=(map @t json)  =/(i (obj:gcal row 'ids') ?:(?=(%o -.i) p.i ~))
  ;<  cal-view=view:nexus  bind:m  (peek:io (grub-road pre 'calendar.calendar') ~)
  =/  c=calendar:cal  (cal-of cal-view)
  =/  k=(unit cal:cal)  (~(get by cals.c) id)
  ?~  k  (pure:m row)
  ::  a calendar made local (migrated) is never pushed, whatever row a
  ::  pass already in flight still holds
  ?.  ?=(%google kind.props.u.k)  (pure:m row)
  ?.  (gth seq.u.k since)  (pure:m row)
  =/  sup=(set [@t @ud])  (suppressed row)
  =/  changes=(list [uid:cal ?(%put %del)])
    =/  latest=(map uid:cal ?(%put %del))
      %+  roll  (tap:on-log:cal log.u.k)
      |=  [[key=@ud val=logent:cal] acc=(map uid:cal ?(%put %del))]
      ?.  (gth key since)  acc
      ?^  (find "#" (trip uid.val))  acc
      ?:  (~(has in sup) [uid.val key])  acc
      (~(put by acc) uid.val kind.val)
    ~(tap by latest)
  =/  base=tape  "/calendar/v3/calendars/{(enc-seg:dav (trip gid))}/events"
  =|  results=(list [=uid:cal gid=@t updated=@t])
  =/  stopped=?  |
  |-
  ?^  changes
    =/  [u=uid:cal what=?(%put %del)]  i.changes
    =/  known=@t  =/(v (~(get by ids) u) ?:(?=([~ %s *] v) p.u.v ''))
    ?:  =(%del what)
      ?:  =('' known)  $(changes t.changes)
      ;<  [status=@ud *]  bind:m
        (google-api pre %'DELETE' "{base}/{(enc-seg:dav (trip known))}" ~)
      ?:  |(=(0 status) (gte status 500) =(429 status))
        ~&  >>>  [%calendar-google-push-stopped u status]
        $(changes ~, stopped &)
      $(changes t.changes, ids (~(del by ids) u))
    =/  e=(unit entry:cal)  (~(get by entries.u.k) u)
    ?~  e  $(changes t.changes)
    ::  ponytail: Google Calendar has no tasks (they live in Google
    ::  Tasks, another API); a task stays on this side
    ?:  ?=(%todo -.event.u.e)  $(changes t.changes)
    =/  body=json  (json-of:gcal u.e (exdates-of u.e))
    =/  have=@t
      ?.  =('' known)  known
      =/  hit=(list [@t @t])  (skim props.u.e |=([key=@t *] =('X-GOOGLE-ID' key)))
      ?~(hit '' +.i.hit)
    ;<  [status=@ud res=json]  bind:m
      ?:  =('' have)  (google-api pre %'POST' base `body)
      (google-api pre %'PUT' "{base}/{(enc-seg:dav (trip have))}" `body)
    ;<  [status=@ud res=json]  bind:m
      ?.  &(=(404 status) !=('' have))  (pure:(fiber:fiber:nexus ,[@ud json]) [status res])
      (google-api pre %'POST' base `body)
    ?:  |(=(0 status) (gte status 500) =(429 status) =(401 status) =(403 status))
      ~&  >>>  [%calendar-google-push-stopped u status]
      $(changes ~, stopped &)
    ?.  =(200 status)
      ;<  ~  bind:m
        (google-conflict pre id u e (gs res 'updated') (crip "google refused the push ({(a-co:co status)})"))
      $(changes t.changes)
    =/  new-gid=@t  (gs res 'id')
    %=  $
      changes  t.changes
      ids      (~(put by ids) u s+new-gid)
      results  [[u new-gid (gs res 'updated')] results]
    ==
  ::  the ids and stamps Google handed back, onto a fresh read of the
  ::  calendar (a poke may have landed while we waited on the network).
  ::  The watermark is the seq read BEFORE the network, so such a poke
  ::  stays above it; the prop writes below are suppressed like a pull's.
  =/  seq-before=@ud  seq.u.k
  ;<  cal-view=view:nexus  bind:m  (peek:io (grub-road pre 'calendar.calendar') ~)
  =/  c=calendar:cal  (cal-of cal-view)
  =/  kk=cal:cal  (fall (~(get by cals.c) id) fresh-cal:cal)
  =?  results  !?=(%google kind.props.kk)  ~
  =/  seq-mid=@ud  seq.kk
  =.  kk
    %+  roll  results
    |=  [[u=uid:cal g=@t up=@t] acc=_kk]
    =/  e=(unit entry:cal)  (~(get by entries.acc) u)
    ?~  e  acc
    =/  props=(list [@t @t])
      :-  ['X-GOOGLE-ID' g]
      :-  ['X-GOOGLE-UPDATED' up]
      (skip props.u.e |=([key=@t *] |(=('X-GOOGLE-ID' key) =('X-GOOGLE-UPDATED' key))))
    (put-entry:cal acc u.e(props props))
  ;<  ~  bind:m
    ?~  results  (pure:(fiber:fiber:nexus ,~) ~)
    (dav-write pre c(cals (~(put by cals.c) id kk)))
  =/  row2=json
    ?.  ?=(%o -.row)  row
    :-  %o
    %-  ~(gas by p.row)
    :~  ['ids' [%o ids]]
        ['pushed_seq' (numb:enjs:format ?:(stopped since seq-before))]
        ['suppressed' (suppress-json (~(uni in sup) (wrote-between kk seq-mid seq.kk)) ?:(stopped since seq-before))]
    ==
  (pure:m row2)
::  ---- CalDAV client: following a remote calendar ----
++  caldav-remotes  |=(pre=@t (read-json-grub pre 'caldav-remotes.json'))
::  +dav-fetch: a request to the remote with Basic auth. iris has the same
::  closed verb set the server side has, so REPORT and PROPFIND go as
::  POST with X-HTTP-Method-Override; our calendars and SabreDAV honour it.
++  dav-fetch
  |=  [row=json verb=@t url=@t body=(unit @t) extra=(list [@t @t])]
  =/  m  (fiber:fiber:nexus ,[status=@ud headers=(list [@t @t]) body=@t])
  ^-  form:m
  =/  cred=@t  (en:base64:mimes:html (as-octs:mimes:html (rap 3 ~[(gs row 'user') ':' (gs row 'password')])))
  =/  native=?  ?=(?(%'GET' %'PUT' %'POST' %'DELETE' %'HEAD' %'OPTIONS') verb)
  =/  method=method:http  ?:(native ;;(method:http verb) %'POST')
  =/  headers=(list [@t @t])
    %+  weld  extra
    :-  ['authorization' (cat 3 'Basic ' cred)]
    ?:(native ~ ~[['x-http-method-override' verb]])
  (fetch-hdr [method url headers ?~(body ~ `(as-octs:mimes:html u.body))])
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
::  +caldav-request: the owner's routes under /apps/calendar/caldav/
++  caldav-request
  |=  [eyre-id=@ta req=inbound-request:eyre rest=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  jon=json
    (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
  =/  post=?  =('POST' method.request.req)
  =/  send-err
    |=  [code=@ud why=@t]
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    ;<  ~  bind:m  (send-simple:srv eyre-id [[code ~] `(as-octs:mimes:html why)])
    (pure:m ~)
  ?:  ?=([%'subscriptions.json' ~] rest)
    ;<  rows=json  bind:m  (caldav-remotes '../')
    %+  send-json  eyre-id
    :-  %a
    %+  turn  ?:(?=(%o -.rows) ~(tap by p.rows) ~)
    |=  [id=@t row=json]
    ^-  json
    %-  pairs:enjs:format
    :~  ['id' s+id]
        ['url' s+(gs row 'url')]
        ['user' s+(gs row 'user')]
        ['last_ms' (numb:enjs:format (fall (gn row 'last_ms') 0))]
        ['error' s+(gs row 'error')]
    ==
  ?:  &(post ?=([%subscribe ~] rest))
    =/  url=@t  (gs jon 'url')
    ?:  =('' url)  (send-err 400 'calendar: need url')
    ;<  cal-view=view:nexus  bind:m  (peek:io (grub-road '../' 'calendar.calendar') ~)
    =/  c=calendar:cal  (cal-of cal-view)
    =/  id=@ta  (crip "c-{(trip (scot %uw (mug url)))}")
    ?:  (~(has by cals.c) id)  (send-err 409 'calendar: already followed')
    =/  nm=@t  (gs jon 'name')
    =/  color=@t  (gs jon 'color')
    =/  k=cal:cal  fresh-cal:cal
    =.  props.k  [?:(=('' nm) url nm) ?:(=('' color) '#101541' color) %caldav `url]
    ;<  ~  bind:m  (dav-write '../' c(cals (~(put by cals.c) id k)))
    ;<  rows=json  bind:m  (caldav-remotes '../')
    =/  row=json
      %-  pairs:enjs:format
      :~  ['url' s+url]
          ['user' s+(gs jon 'user')]
          ['password' s+(gs jon 'password')]
          ['sync_token' s+'']
          ['last_ms' (numb:enjs:format 0)]
          ['pushed_seq' (numb:enjs:format 0)]
          ['ids' [%o ~]]
      ==
    ;<  ~  bind:m
      (write-json-grub '../' 'caldav-remotes.json' [%o (~(put by ?:(?=(%o -.rows) p.rows ~)) id row)])
    ;<  ~  bind:m  (google-prod '../')
    (send-json eyre-id (pairs:enjs:format ~[['id' s+id]]))
  ?:  &(post ?=([%unsubscribe ~] rest))
    =/  id=@ta  (crip (trip (gs jon 'id')))
    ;<  cal-view=view:nexus  bind:m  (peek:io (grub-road '../' 'calendar.calendar') ~)
    =/  c=calendar:cal  (cal-of cal-view)
    ?.  (~(has by cals.c) id)  (send-err 404 'calendar: not followed')
    ;<  ~  bind:m  (dav-write '../' c(cals (~(del by cals.c) id)))
    ;<  rows=json  bind:m  (caldav-remotes '../')
    ;<  ~  bind:m
      (write-json-grub '../' 'caldav-remotes.json' [%o (~(del by ?:(?=(%o -.rows) p.rows ~)) id)])
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  ?:  &(post ?=([%sync ~] rest))
    ;<  ~  bind:m  (google-prod '../')
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  (send-err 404 'calendar: no such caldav route')
::  +caldav-pass: every followed calendar: pull (when asked), then push
++  caldav-pass
  |=  pull=?
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  pre=@t  './'
  ;<  rows-j=json  bind:m  (caldav-remotes pre)
  =/  rows=(list [id=@t row=json])  ?:(?=(%o -.rows-j) ~(tap by p.rows-j) ~)
  =|  done=(map @t json)
  |-
  ?~  rows
    ?:  =(~ done)  (pure:m ~)
    ;<  fresh=json  bind:m  (caldav-remotes pre)
    =/  cur=(map @t json)  ?:(?=(%o -.fresh) p.fresh ~)
    =/  merged=(map @t json)
      %+  roll  ~(tap by done)
      |=  [[id=@t row=json] acc=_cur]
      ?.((~(has by acc) id) acc (~(put by acc) id row))
    (write-json-grub pre 'caldav-remotes.json' [%o merged])
  ;<  row=json  bind:m
    ?.  pull  (pure:(fiber:fiber:nexus ,json) row.i.rows)
    (caldav-pull pre (crip (trip id.i.rows)) row.i.rows)
  ;<  row=json  bind:m  (caldav-push pre (crip (trip id.i.rows)) row)
  ?:  =(row row.i.rows)  $(rows t.rows)
  $(rows t.rows, done (~(put by done) id.i.rows row))
::  +caldav-changes: what changed on the remote since the token:
::  [href etag gone] per object, and the new token. sync-collection
::  first; a server that refuses it gets a PROPFIND and an etag diff.
++  caldav-changes
  |=  row=json
  =/  m  (fiber:fiber:nexus ,(unit [changes=(list [href=tape etag=@t gone=?]) token=@t]))
  ^-  form:m
  =/  url=@t  (gs row 'url')
  =/  tok=@t  (gs row 'sync_token')
  =/  ids=(map @t json)  =/(i (obj:gcal row 'ids') ?:(?=(%o -.i) p.i ~))
  =/  known=(map tape @t)
    %-  ~(gas by *(map tape @t))
    %+  turn  ~(tap by ids)
    |=([u=@t v=json] [(trip (gs v 'href')) (gs v 'etag')])
  =/  body=@t
    %-  crip
    ;:  weld
      "<?xml version=\"1.0\" encoding=\"utf-8\"?><D:sync-collection xmlns:D=\"DAV:\"><D:sync-token>"
      (trip tok)
      "</D:sync-token><D:sync-level>1</D:sync-level><D:prop><D:getetag/></D:prop></D:sync-collection>"
    ==
  ;<  [status=@ud * res=@t]  bind:m
    (dav-fetch row %'REPORT' url `body ~[['content-type' 'application/xml; charset=utf-8'] ['depth' '1']])
  ?:  =(207 status)
    =/  root=(unit manx)  (parse:dav res)
    ?~  root  (pure:m ~)
    =/  token=@t
      =/  el=(unit manx)  (kid:dav u.root %'sync-token')
      ?~(el tok (crip (text:dav u.el)))
    =/  changes=(list [href=tape etag=@t gone=?])
      %+  murn  (kids:dav u.root %response)
      |=  r=manx
      ^-  (unit [tape @t ?])
      =/  h=(unit manx)  (kid:dav r %href)
      ?~  h  ~
      =/  hp=(unit tape)  (dav-href-path (text:dav u.h))
      ?~  hp  ~
      =/  href=tape  u.hp
      ?.  =(".ics" (slag (sub (lent href) (min 4 (lent href))) href))  ~
      =/  st=(unit manx)  (kid:dav r %status)
      ?:  &(?=(^ st) ?=(^ (find "404" (text:dav u.st))))  `[href '' &]
      =/  et=(unit manx)  (find-el:dav r %getetag)
      `[href ?~(et '' (dav-unquote (crip (text:dav u.et)))) |]
    (pure:m `[changes token])
  ::  fallback: list with PROPFIND and diff the etags
  ;<  [status2=@ud * res2=@t]  bind:m
    %-  dav-fetch
    :*  row  %'PROPFIND'  url
        `'<?xml version="1.0"?><D:propfind xmlns:D="DAV:"><D:prop><D:getetag/></D:prop></D:propfind>'
        ~[['content-type' 'application/xml; charset=utf-8'] ['depth' '1']]
    ==
  ?.  =(207 status2)
    ~&  >>>  [%calendar-caldav-list-failed status status2]
    (pure:m ~)
  =/  root=(unit manx)  (parse:dav res2)
  ?~  root  (pure:m ~)
  =/  listed=(list [href=tape etag=@t])
    %+  murn  (kids:dav u.root %response)
    |=  r=manx
    ^-  (unit [tape @t])
    =/  h=(unit manx)  (kid:dav r %href)
    ?~  h  ~
    =/  hp=(unit tape)  (dav-href-path (text:dav u.h))
    ?~  hp  ~
    =/  href=tape  u.hp
    ?.  =(".ics" (slag (sub (lent href) (min 4 (lent href))) href))  ~
    =/  et=(unit manx)  (find-el:dav r %getetag)
    `[href ?~(et '' (dav-unquote (crip (text:dav u.et))))]
  ::  the collection's own <response> must be there before its member
  ::  list is believed — an empty or truncated answer is a failure, and
  ::  an emptied calendar (the collection present, no members) is real
  =/  coll=tape  (fall (dav-href-path (trip url)) "")
  =/  coll-here=?
    %+  lien  (kids:dav u.root %response)
    |=  r=manx
    =/  h=(unit manx)  (kid:dav r %href)
    ?~  h  |
    =/  hp=(unit tape)  (dav-href-path (text:dav u.h))
    ?~  hp  |
    =(?:(=('/' (rear coll)) coll (snoc coll '/')) ?:(=('/' (rear u.hp)) u.hp (snoc u.hp '/')))
  ?.  coll-here
    ~&  >>>  [%calendar-caldav-listing-incomplete url]
    (pure:m ~)
  =/  seen=(set tape)  (~(gas in *(set tape)) (turn listed |=([h=tape *] h)))
  =/  changed=(list [href=tape etag=@t gone=?])
    %+  murn  listed
    |=  [h=tape e=@t]
    ^-  (unit [tape @t ?])
    =/  old=(unit @t)  (~(get by known) h)
    ?:  &(?=(^ old) =(u.old e) !=('' e))  ~
    `[h e |]
  =/  gone=(list [href=tape etag=@t gone=?])
    %+  murn  ~(tap by known)
    |=  [h=tape *]
    ^-  (unit [tape @t ?])
    ?:((~(has in seen) h) ~ `[h '' &])
  (pure:m `[(weld changed gone) tok])
::  +caldav-pull: fetch every changed object, then apply them all onto
::  one read of the calendar
++  caldav-pull
  |=  [pre=@t id=@ta row=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  url=@t  (gs row 'url')
  =/  origin=tape  (dav-origin url)
  ;<  got=(unit [changes=(list [href=tape etag=@t gone=?]) token=@t])  bind:m  (caldav-changes row)
  ?~  got
    ::  the row remembers that the remote could not be listed, for the UI
    %-  pure:m
    ?.  ?=(%o -.row)  row
    [%o (~(put by p.row) 'error' s+'could not list the remote calendar (a server that refuses X-HTTP-Method-Override, or an incomplete answer)')]
  =/  ids=(map @t json)  =/(i (obj:gcal row 'ids') ?:(?=(%o -.i) p.i ~))
  =/  by-href=(map tape @t)
    %-  ~(gas by *(map tape @t))
    (turn ~(tap by ids) |=([u=@t v=json] [(fall (dav-href-path (trip (gs v 'href'))) (trip (gs v 'href'))) u]))
  ::  1. the network: every changed object's text
  =|  fetched=(list [href=tape etag=@t gone=? body=@t])
  =/  failed=?  |
  =/  todo=(list [href=tape etag=@t gone=?])  changes.u.got
  |-
  ?^  todo
    ?:  gone.i.todo  $(todo t.todo, fetched [[href.i.todo '' & ''] fetched])
    ;<  [status=@ud hs=(list [@t @t]) body=@t]  bind:m
      (dav-fetch row %'GET' (crip (weld origin href.i.todo)) ~ ~)
    ?.  =(200 status)
      ::  a miss keeps the old token, so the next pass asks again
      ~&  >>>  [%calendar-caldav-get-failed href.i.todo status]
      $(todo t.todo, failed &)
    =/  et=@t  ?:(=('' etag.i.todo) (dav-unquote (hdr-of hs 'etag')) etag.i.todo)
    $(todo t.todo, fetched [[href.i.todo et | body] fetched])
  ::  2. the calendar, once
  ;<  cal-view=view:nexus  bind:m  (peek:io (grub-road pre 'calendar.calendar') ~)
  =/  c=calendar:cal  (cal-of cal-view)
  =/  k=cal:cal  (fall (~(get by cals.c) id) fresh-cal:cal)
  ?.  ?=(%caldav kind.props.k)  (pure:m row)
  =/  k=cal:cal  k
  ::  a fetched object (or a remote delete) whose uid also changed here
  ::  since the last push, when the apply really replaces the local
  ::  copy, is a conflict: the remote wins, the local copy is logged
  =/  sup=(set [@t @ud])  (suppressed row)
  =/  pending=(set uid:cal)  (pending-uids k (fall (gn row 'pushed_seq') 0) sup)
  =/  seq-at-peek=@ud  seq.k
  =/  res=[k=cal:cal ids=(map @t json) clashes=(list [uid:cal (unit entry:cal)])]
    %+  roll  (flop fetched)
    |=  [[href=tape etag=@t gone=? body=@t] acc=_[k=k ids=ids clashes=*(list [uid:cal (unit entry:cal)])]]
    ?:  gone
      =/  u=(unit @t)  (~(get by by-href) href)
      ?~  u  acc
      =/  old=(unit entry:cal)  (~(get by entries.k.acc) u.u)
      =?  clashes.acc  &(?=(^ old) (~(has in pending) u.u))  [[u.u old] clashes.acc]
      =.  k.acc
        %+  roll  (dav-children k.acc u.u)
        |=([ch=entry:cal a=_k.acc] (del-entry:cal a uid.ch))
      acc(k (del-entry:cal k.acc u.u), ids (~(del by ids.acc) u.u))
    =/  put=(unit [k=cal:cal =uid:cal])  (put-object k.acc (events:ics body) zone.c '' ~)
    ?~  put  acc
    =/  old=(unit entry:cal)  (~(get by entries.k.acc) uid.u.put)
    =?  clashes.acc  &(?=(^ old) (~(has in pending) uid.u.put) !=(k.acc k.u.put))  [[uid.u.put old] clashes.acc]
    =.  k.acc  k.u.put
    acc(ids (~(put by ids.acc) uid.u.put (pairs:enjs:format ~[['href' s+(crip href)] ['etag' s+etag]])))
  ;<  ~  bind:m
    =/  m  (fiber:fiber:nexus ,~)
    =/  todo=(list [uid:cal (unit entry:cal)])  clashes.res
    |-  ^-  form:m
    ?~  todo  (pure:m ~)
    ;<  ~  bind:m
      (google-conflict pre id -.i.todo +.i.todo '' 'changed on both sides; the remote kept')
    $(todo t.todo)
  ;<  ~  bind:m
    ?:  =(k.res k)  (pure:(fiber:fiber:nexus ,~) ~)
    (dav-write pre c(cals (~(put by cals.c) id k.res)))
  ;<  now=@da  bind:m  get-time:io
  %-  pure:m
  ?.  ?=(%o -.row)  row
  :-  %o
  %-  ~(gas by p.row)
  :~  ['sync_token' s+?:(failed (gs row 'sync_token') token.u.got)]
      ['last_ms' (numb:enjs:format (da-to-ms now))]
      ['error' s+'']
      ['ids' [%o ids.res]]
      ['suppressed' (suppress-json (~(uni in sup) (wrote-between k.res seq-at-peek seq.k.res)) (fall (gn row 'pushed_seq') 0))]
  ==
::  +caldav-push: the log past the watermark, out as PUT and DELETE
++  caldav-push
  |=  [pre=@t id=@ta row=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  url=@t  (gs row 'url')
  =/  origin=tape  (dav-origin url)
  =/  since=@ud  (fall (gn row 'pushed_seq') 0)
  =/  ids=(map @t json)  =/(i (obj:gcal row 'ids') ?:(?=(%o -.i) p.i ~))
  ;<  cal-view=view:nexus  bind:m  (peek:io (grub-road pre 'calendar.calendar') ~)
  =/  c=calendar:cal  (cal-of cal-view)
  =/  k=(unit cal:cal)  (~(get by cals.c) id)
  ?~  k  (pure:m row)
  ?.  ?=(%caldav kind.props.u.k)  (pure:m row)
  ?.  (gth seq.u.k since)  (pure:m row)
  =/  sup=(set [@t @ud])  (suppressed row)
  =/  changes=(list [uid:cal ?(%put %del)])
    =/  latest=(map uid:cal ?(%put %del))
      %+  roll  (tap:on-log:cal log.u.k)
      |=  [[key=@ud val=logent:cal] acc=(map uid:cal ?(%put %del))]
      ?.  (gth key since)  acc
      ?^  (find "#" (trip uid.val))  acc
      ?:  (~(has in sup) [uid.val key])  acc
      (~(put by acc) uid.val kind.val)
    ~(tap by latest)
  ;<  now=@da  bind:m  get-time:io
  =/  stopped=?  |
  |-
  ?^  changes
    =/  [u=uid:cal what=?(%put %del)]  i.changes
    =/  known=json  (fall (~(get by ids) u) [%o ~])
    =/  href=tape
      =/  h=@t  (gs known 'href')
      ?.  =('' h)  (fall (dav-href-path (trip h)) (trip h))
      =/  base=tape  (trip url)
      =?  base  !=('/' (rear base))  (snoc base '/')
      =/  at=(unit @ud)  (find "//" base)
      =/  path=tape  ?~(at base (slag (add (add 2 u.at) (fall (find "/" (slag (add 2 u.at) base)) 0)) base))
      :(weld path (enc-seg:dav (trip u)) ".ics")
    =/  etag=@t  (gs known 'etag')
    ?:  =(%del what)
      ?:  =('' (gs known 'href'))  $(changes t.changes)
      ;<  [status=@ud * *]  bind:m  (dav-fetch row %'DELETE' (crip (weld origin href)) ~ ~)
      ?:  |(=(0 status) (gte status 500) =(401 status) =(403 status))
        ~&  >>>  [%calendar-caldav-push-stopped u status]
        $(changes ~, stopped &)
      $(changes t.changes, ids (~(del by ids) u))
    =/  body=(unit @t)  (dav-object-ics c id u now)
    ?~  body  $(changes t.changes)
    ;<  [status=@ud hs=(list [@t @t]) res=@t]  bind:m
      %-  dav-fetch
      :*  row  %'PUT'  (crip (weld origin href))  body
          :-  ['content-type' 'text/calendar; charset=utf-8']
          ?:(=('' etag) ~ ~[['if-match' (crip "\"{(trip etag)}\"")]])
      ==
    ::  a remote without VTODO in its component set answers a task with
    ::  403 (RFC 4791 5.3.2.1): that task's refusal, not a stop
    =/  task=?  =/(e (~(get by entries.u.k) u) &(?=(^ e) ?=(%todo -.event.u.e)))
    ?:  |(=(0 status) (gte status 500) =(401 status) &(=(403 status) !task))
      ~&  >>>  [%calendar-caldav-push-stopped u status]
      $(changes ~, stopped &)
    ?:  (gte status 400)
      ;<  ~  bind:m
        (google-conflict pre id u (~(get by entries.u.k) u) '' (crip "remote refused the push ({(a-co:co status)})"))
      $(changes t.changes)
    =/  new-etag=@t  (dav-unquote (hdr-of hs 'etag'))
    %=  $
      changes  t.changes
      ids      (~(put by ids) u (pairs:enjs:format ~[['href' s+(crip href)] ['etag' s+new-etag]]))
    ==
  %-  pure:m
  ?.  ?=(%o -.row)  row
  :-  %o
  %-  ~(gas by p.row)
  :~  ['ids' [%o ids]]
      ['pushed_seq' (numb:enjs:format ?:(stopped since seq.u.k))]
      ['suppressed' (suppress-json sup ?:(stopped since seq.u.k))]
  ==
::  ---- sharing a calendar with a ship ----
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
::  +ug-read-weir / +ug-read-ships: a group's how and who
++  ug-read-weir
  |=  gdir=path
  =/  m  (fiber:fiber:nexus ,weir:nexus)
  ^-  form:m
  ;<  hv=(unit view:nexus)  bind:m  (peek-soft:io [%& %& gdir %'how.weir'] ~)
  ?~  hv  (pure:m *weir:nexus)
  ?.  ?=([%file *] u.hv)  (pure:m *weir:nexus)
  (pure:m (fall (mole |.(;;(weir:nexus (sang-noun:tarball sang.u.hv)))) *weir:nexus))
++  ug-read-ships
  |=  gdir=path
  =/  m  (fiber:fiber:nexus ,(set @p))
  ^-  form:m
  ;<  wv=(unit view:nexus)  bind:m  (peek-soft:io [%& %& gdir %'who.ships'] ~)
  ?~  wv  (pure:m ~)
  ?.  ?=([%file *] u.wv)  (pure:m ~)
  (pure:m (fall (mole |.(;;((set @p) (sang-noun:tarball sang.u.wv)))) ~))
::  +ug-set: a group's members and its weir, written whole
++  ug-set
  |=  [gname=@t ships=(set @p) pk=(set road:tarball) pok=(set road:tarball)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  gdir=path  (snoc ug-base (crip (weld (trip gname) ".grp")))
  ;<  old=weir:nexus  bind:m  (ug-read-weir gdir)
  =/  =weir:nexus  [make.old pok pk]
  ;<  ~  bind:m  (over:io [%& %& gdir %'who.ships'] [[/ %ships] ships])
  ;<  ~  bind:m  (over:io [%& %& gdir %'how.weir'] [[/ %weir] weir])
  (pure:m ~)
::  +lay-inbox-road: our shares.sig takes pokes from any ship, through
::  the /public group's weir — the same shape lattice uses for share
::  notices. Quiet when the roads are refused: sharing is optional.
++  lay-inbox-road
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  base=(unit path)  bind:m  self-base
  ?~  base  (pure:m ~)
  ;<  old=weir:nexus  bind:m  (ug-read-weir public-grp)
  =/  road=road:tarball  [%& %& u.base %'shares.sig']
  ?:  (~(has in poke.old) road)  (pure:m ~)
  ;<  reg=(unit tang)  bind:m  (reg-register-at-soft:io [u.base %'shares.sig'])
  ?^  reg  ~&(>> %calendar-no-registry-road (pure:m ~))
  ::  the registry names a group by its short name and takes only OUR
  ::  roads: a %how replaces every road under our prefix in that group
  ::  and leaves the other apps' roads alone
  ;<  err=(unit tang)  bind:m  (reg-how-soft:io /public [~ (sy road ~) ~])
  ~?  >>  ?=(^ err)  %calendar-inbox-road-not-laid
  (pure:m ~)
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
::  +build-share-json: what a peer sees of one calendar
++  build-share-json
  |=  [c=calendar:cal id=@ta now=@da]
  ^-  json
  =/  k=cal:cal  (fall (~(get by cals.c) id) fresh-cal:cal)
  %-  pairs:enjs:format
  :~  ['seq' (numb:enjs:format seq.k)]
      ['name' s+name.props.k]
      ['color' s+color.props.k]
      :-  'objects'
      :-  %o
      %-  ~(gas by *(map @t json))
      %+  murn  ~(tap by entries.k)
      |=  [u=uid:cal e=entry:cal]
      ^-  (unit [@t json])
      ?:  (dav-is-child e)  ~
      =/  ics=(unit @t)  (dav-object-ics c id u now)
      ?~  ics  ~
      `[u (pairs:enjs:format ~[['etag' s+etag.e] ['ics' s+u.ics]])]
  ==
::  +share-pass: the host side — every shared calendar's file is brought
::  up to its seq
++  share-pass
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  shares=json  bind:m  (read-json-grub './' 'shares.json')
  =/  ids=(list @t)  ?:(?=(%o -.shares) (turn ~(tap by p.shares) |=([id=@t *] id)) ~)
  ?:  =(~ ids)  (pure:m ~)
  ;<  cal-view=view:nexus  bind:m  (peek:io (grub-road './' 'calendar.calendar') ~)
  =/  c=calendar:cal  (cal-of cal-view)
  ;<  now=@da  bind:m  get-time:io
  |-
  ?~  ids  (pure:m ~)
  =/  id=@ta  (crip (trip i.ids))
  =/  k=(unit cal:cal)  (~(get by cals.c) id)
  ?~  k  $(ids t.ids)
  =/  road=road:tarball  (cord-to-road:tarball (crip "./shares/{(trip id)}.json"))
  ;<  cur=(unit view:nexus)  bind:m  (peek-soft:io road ~)
  =/  have-seq=@ud
    ?~  cur  0
    ?.  ?=([%file *] u.cur)  0
    (fall (gn (fall (mole |.(!<(json (need-vase:tarball sang.u.cur)))) *json) 'seq') 0)
  ?:  &(?=(^ cur) ?=([%file *] u.cur) =(have-seq seq.u.k))  $(ids t.ids)
  =/  jon=json  (build-share-json c id now)
  ;<  ~  bind:m
    ?:  &(?=(^ cur) ?=([%file *] u.cur))  (over:io road [[/ %json] jon])
    (make:io road |+[[[/ %json] jon] ~])
  $(ids t.ids)
::  +share-request: the owner's routes under /apps/calendar/share/
++  share-request
  |=  [eyre-id=@ta req=inbound-request:eyre our=@p rest=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  jon=json
    (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
  =/  post=?  =('POST' method.request.req)
  =/  send-err
    |=  [code=@ud why=@t]
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    ;<  ~  bind:m  (send-simple:srv eyre-id [[code ~] `(as-octs:mimes:html why)])
    (pure:m ~)
  ?:  ?=([%'shares.json' ~] rest)
    ;<  shares=json  bind:m  (read-json-grub '../' 'shares.json')
    ;<  offers=json  bind:m  (read-json-grub '../' 'share-offers.json')
    ;<  rows=json  bind:m  (read-json-grub '../' 'ship-remotes.json')
    =/  accepted=json
      :-  %o
      %-  ~(gas by *(map @t json))
      %+  turn  ?:(?=(%o -.rows) ~(tap by p.rows) ~)
      |=  [id=@t r=json]
      :-  id
      %-  pairs:enjs:format
      :~  ['key' s+(gs r 'key')]
          ['mode' s+(gs r 'mode')]
          ['last_ms' (numb:enjs:format (fall (gn r 'last_ms') 0))]
          ['error' s+(gs r 'error')]
      ==
    (send-json eyre-id (pairs:enjs:format ~[['shares' shares] ['offers' offers] ['accepted' accepted]]))
  ::  share {id, ship, mode}: the ship joins the calendar's group and is
  ::  told. read: peek on the share file. edit: that and poke on the
  ::  calendar, which the handler limits to this calendar.
  ?:  &(post ?=([%share ~] rest))
    =/  id=@ta  (crip (trip (gs jon 'id')))
    =/  shp=(unit @p)  (slaw %p (gs jon 'ship'))
    =/  mode=@t  ?:(=('edit' (gs jon 'mode')) 'edit' 'read')
    ?~  shp  (send-err 400 'calendar: bad ship name')
    ?:  =(u.shp our)  (send-err 400 'calendar: that is this ship')
    ;<  base=(unit path)  bind:m  self-base
    ?~  base  (send-err 500 'calendar: cannot find where this app is installed')
    ;<  cal-view=view:nexus  bind:m  (peek:io (grub-road '../' 'calendar.calendar') ~)
    =/  c=calendar:cal  (cal-of cal-view)
    =/  k=(unit cal:cal)  (~(get by cals.c) id)
    ?~  k  (send-err 404 'calendar: no such calendar')
    ?.  ?=(%local kind.props.u.k)  (send-err 400 'calendar: only a local calendar can be shared')
    ::  1. the record
    ;<  shares=json  bind:m  (read-json-grub '../' 'shares.json')
    =/  all=(map @t json)  ?:(?=(%o -.shares) p.shares ~)
    =/  mine=(map @t json)  =/(j (~(get by all) id) ?:(?=([~ %o *] j) p.u.j ~))
    =.  mine  (~(put by mine) (scot %p u.shp) s+mode)
    ;<  ~  bind:m  (write-json-grub '../' 'shares.json' [%o (~(put by all) id [%o mine])])
    ::  2. the share file, now
    ;<  now=@da  bind:m  get-time:io
    =/  froad=road:tarball  (cord-to-road:tarball (crip "../shares/{(trip id)}.json"))
    ;<  cur=(unit view:nexus)  bind:m  (peek-soft:io froad ~)
    =/  fj=json  (build-share-json c id now)
    ;<  ~  bind:m
      ?:  &(?=(^ cur) ?=([%file *] u.cur))  (over:io froad [[/ %json] fj])
      (make:io froad |+[[[/ %json] fj] ~])
    ::  3. the groups: read-only ships and editing ships
    ;<  ~  bind:m  (set-share-groups u.base id mine)
    ::  4. the offer, to the peer's inbox
    ;<  told=?  bind:m
      %^  remote-poke-wait  u.shp
        [%& cal-instance %'shares.sig']
      %-  pairs:enjs:format
      :~  ['action' s+'offer']
          ['cal' s+id]
          ['name' s+name.props.u.k]
          ['color' s+color.props.u.k]
          ['mode' s+mode]
          ['base' s+(spat u.base)]
      ==
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&] ['notified' b+told]]))
  ?:  &(post ?=([%revoke ~] rest))
    =/  id=@ta  (crip (trip (gs jon 'id')))
    =/  shp=(unit @p)  (slaw %p (gs jon 'ship'))
    ?~  shp  (send-err 400 'calendar: bad ship name')
    ;<  base=(unit path)  bind:m  self-base
    ?~  base  (send-err 500 'calendar: cannot find where this app is installed')
    ;<  shares=json  bind:m  (read-json-grub '../' 'shares.json')
    =/  all=(map @t json)  ?:(?=(%o -.shares) p.shares ~)
    =/  mine=(map @t json)  =/(j (~(get by all) id) ?:(?=([~ %o *] j) p.u.j ~))
    =.  mine  (~(del by mine) (scot %p u.shp))
    ;<  ~  bind:m
      (write-json-grub '../' 'shares.json' [%o ?:(=(~ mine) (~(del by all) id) (~(put by all) id [%o mine]))])
    ;<  ~  bind:m  (set-share-groups u.base id mine)
    ;<  *  bind:m
      %^  remote-poke-wait  u.shp
        [%& cal-instance %'shares.sig']
      (pairs:enjs:format ~[['action' s+'revoke'] ['cal' s+id]])
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  ::  accept {key}: the offered calendar becomes ours to read (or edit)
  ?:  &(post ?=([%accept ~] rest))
    =/  key=@t  (gs jon 'key')
    ;<  offers=json  bind:m  (read-json-grub '../' 'share-offers.json')
    =/  cur=(map @t json)  ?:(?=(%o -.offers) p.offers ~)
    =/  offer=(unit json)  (~(get by cur) key)
    ?~  offer  (send-err 404 'calendar: no such offer')
    ;<  cal-view=view:nexus  bind:m  (peek:io (grub-road '../' 'calendar.calendar') ~)
    =/  c=calendar:cal  (cal-of cal-view)
    ;<  now=@da  bind:m  get-time:io
    =/  id=@ta
      =/  first=@ta  (crip "s-{(trip (scot %uw (mug key)))}")
      ::  a copy from an earlier share of the same calendar (revoked, now
      ::  local) keeps its id; the new one gets its own
      ?.  (~(has by cals.c) first)  first
      (crip "s-{(trip (scot %uw (mug [key now])))}")
    =/  mode=@t  (gs u.offer 'mode')
    =/  k=cal:cal  fresh-cal:cal
    =/  nm=@t  (gs u.offer 'name')
    =.  props.k  [?:(=('' nm) key nm) ?:(=('' (gs u.offer 'color')) '#101541' (gs u.offer 'color')) %ship `(crip "{(trip key)}#{(trip mode)}")]
    ;<  ~  bind:m  (dav-write '../' c(cals (~(put by cals.c) id k)))
    ;<  rows=json  bind:m  (read-json-grub '../' 'ship-remotes.json')
    =/  row=json
      %-  pairs:enjs:format
      :~  ['key' s+key]
          ['host' s+(gs u.offer 'host')]
          ['cal' s+(gs u.offer 'cal')]
          ['base' s+(gs u.offer 'base')]
          ['mode' s+mode]
          ['etags' [%o ~]]
          ['seq' (numb:enjs:format 0)]
          ['pushed_seq' (numb:enjs:format 0)]
          ['last_ms' (numb:enjs:format 0)]
      ==
    ;<  ~  bind:m  (write-json-grub '../' 'ship-remotes.json' [%o (~(put by ?:(?=(%o -.rows) p.rows ~)) id row)])
    ;<  ~  bind:m  (write-json-grub '../' 'share-offers.json' [%o (~(del by cur) key)])
    ;<  ~  bind:m  (google-prod '../')
    (send-json eyre-id (pairs:enjs:format ~[['id' s+id]]))
  ?:  &(post ?=([%decline ~] rest))
    =/  key=@t  (gs jon 'key')
    ;<  offers=json  bind:m  (read-json-grub '../' 'share-offers.json')
    ;<  ~  bind:m  (write-json-grub '../' 'share-offers.json' [%o (~(del by ?:(?=(%o -.offers) p.offers ~)) key)])
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  ?:  &(post ?=([%sync ~] rest))
    ;<  ~  bind:m  (google-prod '../')
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  (send-err 404 'calendar: no such share route')
::  +set-share-groups: the two groups of one calendar, from its record
++  set-share-groups
  |=  [base=path id=@ta mine=(map @t json)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  file=road:tarball  [%& %& (snoc base %shares) (crip "{(trip id)}.json")]
  =/  cal-road=road:tarball  [%& %& base %'calendar.calendar']
  =/  readers=(set @p)
    %-  ~(gas in *(set @p))
    %+  murn  ~(tap by mine)
    |=([s=@t v=json] ?:(?=(%s -.v) (slaw %p s) ~))
  =/  editors=(set @p)
    %-  ~(gas in *(set @p))
    %+  murn  ~(tap by mine)
    |=([s=@t v=json] ?:(&(?=(%s -.v) =('edit' p.v)) (slaw %p s) ~))
  ;<  ~  bind:m  (ug-set (group-name id 'read') readers (sy ~[file]) ~)
  (ug-set (group-name id 'edit') editors (sy ~[file]) (sy ~[cal-road]))
::  +remote-poke-wait: a poke to another ship's grubbery, answered or
::  timed out (a peer that is down must not park the fiber)
++  remote-poke-wait
  |=  [target=@p =lane:tarball jon=json]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  req=load:remo:nexus  [[/share-poke lane] %poke [[/ %json] jon]]
  ;<  w=wire  bind:m  (nonce:io /share-poke)
  ::  the /sys/gall grub consumes the request first (%pack on our wire);
  ::  the far ship's ack comes back later as a [/ %poke-ack] poke keyed
  ::  by the same wire. A veto or our timer ends the wait with %.n.
  ;<  ~  bind:m
    %-  send-dart:io
    [%node w &+&+[/sys/gall %'main.sig'] %poke [[/ %gall-poke] [[target %grubbery] grubbery-load+req]]]
  ;<  ~  bind:m  (set-timer:io /remote (add now ~s30))
  ;<  ok=?  bind:m
    |=  input:fiber:nexus
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %veto %node * * *]
      ?.(=(w wire.dart.u.in) [%skip ~] [%done %.n])
        [~ %pack * *]
      ?.  =(w wire.u.in)  [%skip ~]
      ?~(err.u.in [%wait ~] [%done %.n])
        [~ %poke * *]
      ?:  =([/ %timer-wake] p.sage.u.in)
        ?.(?=([%remote *] !<(path q.sage.u.in)) [%skip ~] [%done %.n])
      ?.  =([/ %poke-ack] p.sage.u.in)  [%skip ~]
      =/  [aw=wire err=(unit tang)]  !<([wire (unit tang)] q.sage.u.in)
      ?.  =(w aw)  [%skip ~]
      ~?  >>>  ?=(^ err)  [%calendar-remote-nack u.err]
      [%done ?=(~ err)]
    ==
  ;<  ~  bind:m  (cancel-timer:io /remote)
  (pure:m ok)
::  +peek-remote-wait: a peek of another ship's file, ~ on veto, miss or
::  timeout
++  peek-remote-wait
  |=  [target=@p road=road:tarball]
  =/  m  (fiber:fiber:nexus ,(unit view:nexus))
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  until=@da  (add now ~s30)
  ;<  pw=wire  bind:m  (nonce:io /peek)
  =/  rr=road:tarball
    ?-  -.road
      %|  road
      %&
        =/  prefix=path  /sys/ames/ships/[(scot %p target)]/root
        ?-  -.p.road
          %&  [%& %& (weld prefix path.p.p.road) name.p.p.road]
          %|  [%& %| (weld prefix p.p.road)]
        ==
    ==
  ;<  ~  bind:m  (send-dart:io %node pw rr %peek ~ ~ %.y)
  ;<  ~  bind:m  (set-timer:io /remote until)
  ;<  got=(unit view:nexus)  bind:m
    |=  input:fiber:nexus
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %veto %node * * *]
      ?.(=(pw wire.dart.u.in) [%skip ~] [%done ~])
        [~ %peek * *]
      ?.(=(pw wire.u.in) [%skip ~] [%done `view.u.in])
        [~ %poke * *]
      ?.  =([/ %timer-wake] p.sage.u.in)  [%skip ~]
      ?.(?=([%remote *] !<(path q.sage.u.in)) [%skip ~] [%done ~])
    ==
  ;<  ~  bind:m  (cancel-timer:io /remote)
  (pure:m got)
::  +ship-pass: the peer side — every accepted calendar: pull (when
::  asked), then push
++  ship-pass
  |=  pull=?
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  pre=@t  './'
  ;<  rows-j=json  bind:m  (read-json-grub pre 'ship-remotes.json')
  =/  rows=(list [id=@t row=json])  ?:(?=(%o -.rows-j) ~(tap by p.rows-j) ~)
  =|  done=(map @t json)
  |-
  ?~  rows
    ?:  =(~ done)  (pure:m ~)
    ;<  fresh=json  bind:m  (read-json-grub pre 'ship-remotes.json')
    =/  cur=(map @t json)  ?:(?=(%o -.fresh) p.fresh ~)
    =/  merged=(map @t json)
      %+  roll  ~(tap by done)
      |=  [[id=@t row=json] acc=_cur]
      ?.((~(has by acc) id) acc (~(put by acc) id row))
    (write-json-grub pre 'ship-remotes.json' [%o merged])
  ;<  row=json  bind:m
    ?.  pull  (pure:(fiber:fiber:nexus ,json) row.i.rows)
    (ship-pull pre (crip (trip id.i.rows)) row.i.rows)
  ;<  row=json  bind:m  (ship-push pre (crip (trip id.i.rows)) row)
  ?:  =(row row.i.rows)  $(rows t.rows)
  $(rows t.rows, done (~(put by done) id.i.rows row))
::  +ship-pull: the host's share file, diffed by etag against what we
::  hold; changed objects are applied, missing ones deleted
++  ship-pull
  |=  [pre=@t id=@ta row=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  host=(unit @p)  (slaw %p (gs row 'host'))
  ?~  host  (pure:m row)
  =/  base=path  (fall (mole |.((stab (gs row 'base')))) cal-instance)
  =/  hcal=@t  (gs row 'cal')
  ;<  vw=(unit view:nexus)  bind:m
    (peek-remote-wait u.host [%& %& (snoc base %shares) (crip "{(trip hcal)}.json")])
  ?~  vw
    %-  pure:m
    ?.(?=(%o -.row) row [%o (~(put by p.row) 'error' s+'the host did not answer (down, or the share was revoked)')])
  ?.  ?=([%file *] u.vw)
    %-  pure:m
    ?.(?=(%o -.row) row [%o (~(put by p.row) 'error' s+'the host has no such shared calendar any more')])
  =/  share=json  (fall (mole |.(!<(json (need-vase:tarball sang.u.vw)))) *json)
  =/  rseq=@ud  (fall (gn share 'seq') 0)
  ?:  =(rseq (fall (gn row 'seq') 0))
    (pure:m ?.(?=(%o -.row) row [%o (~(put by p.row) 'error' s+'')]))
  =/  objects=(map @t json)  =/(o (obj:gcal share 'objects') ?:(?=(%o -.o) p.o ~))
  =/  etags=(map @t json)  =/(e (obj:gcal row 'etags') ?:(?=(%o -.e) p.e ~))
  ;<  cal-view=view:nexus  bind:m  (peek:io (grub-road pre 'calendar.calendar') ~)
  =/  c=calendar:cal  (cal-of cal-view)
  =/  k=cal:cal  (fall (~(get by cals.c) id) fresh-cal:cal)
  ?.  ?=(%ship kind.props.k)  (pure:m row)
  =/  k=cal:cal  k
  =/  sup=(set [@t @ud])  (suppressed row)
  =/  pending=(set uid:cal)  (pending-uids k (fall (gn row 'pushed_seq') 0) sup)
  =/  seq-at-peek=@ud  seq.k
  =/  res=[k=cal:cal etags=(map @t json) clashes=(list [uid:cal (unit entry:cal)])]
    %+  roll  ~(tap by objects)
    |=  [[u=@t o=json] acc=_[k=k etags=*(map @t json) clashes=*(list [uid:cal (unit entry:cal)])]]
    =/  et=@t  (gs o 'etag')
    =.  etags.acc  (~(put by etags.acc) u s+et)
    ?:  =(et (gs [%o etags] u))  acc
    =/  put=(unit [k=cal:cal =uid:cal])  (put-object k.acc (events:ics (gs o 'ics')) zone.c u ~)
    ?~  put  acc
    =/  old=(unit entry:cal)  (~(get by entries.k.acc) uid.u.put)
    =?  clashes.acc  &(?=(^ old) (~(has in pending) uid.u.put) !=(k.acc k.u.put))  [[uid.u.put old] clashes.acc]
    acc(k k.u.put)
  ::  what the host no longer has, goes
  =/  res2=[k=cal:cal clashes=(list [uid:cal (unit entry:cal)])]
    %+  roll  ~(tap by etags)
    |=  [[u=@t *] acc=_[k=k.res clashes=clashes.res]]
    ?:  (~(has by objects) u)  acc
    =/  old=(unit entry:cal)  (~(get by entries.k.acc) u)
    ?~  old  acc
    =?  clashes.acc  (~(has in pending) u)  [[u old] clashes.acc]
    =.  k.acc
      %+  roll  (dav-children k.acc u)
      |=([ch=entry:cal a=_k.acc] (del-entry:cal a uid.ch))
    acc(k (del-entry:cal k.acc u))
  ;<  ~  bind:m
    =/  m  (fiber:fiber:nexus ,~)
    =/  todo=(list [uid:cal (unit entry:cal)])  clashes.res2
    |-  ^-  form:m
    ?~  todo  (pure:m ~)
    ;<  ~  bind:m
      (google-conflict pre id -.i.todo +.i.todo '' 'changed on both sides; the host kept')
    $(todo t.todo)
  ;<  ~  bind:m
    ?:  =(k.res2 k)  (pure:(fiber:fiber:nexus ,~) ~)
    (dav-write pre c(cals (~(put by cals.c) id k.res2)))
  ;<  now=@da  bind:m  get-time:io
  %-  pure:m
  ?.  ?=(%o -.row)  row
  :-  %o
  %-  ~(gas by p.row)
  :~  ['seq' (numb:enjs:format rseq)]
      ['etags' [%o etags.res]]
      ['last_ms' (numb:enjs:format (da-to-ms now))]
      ['error' s+'']
      ['suppressed' (suppress-json (~(uni in sup) (wrote-between k.res2 seq-at-peek seq.k.res2)) (fall (gn row 'pushed_seq') 0))]
  ==
::  +ship-push: our changes to an edit-mode shared calendar, as pokes to
::  the host
++  ship-push
  |=  [pre=@t id=@ta row=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  host=(unit @p)  (slaw %p (gs row 'host'))
  ?~  host  (pure:m row)
  =/  base=path  (fall (mole |.((stab (gs row 'base')))) cal-instance)
  =/  hcal=@t  (gs row 'cal')
  =/  since=@ud  (fall (gn row 'pushed_seq') 0)
  ;<  cal-view=view:nexus  bind:m  (peek:io (grub-road pre 'calendar.calendar') ~)
  =/  c=calendar:cal  (cal-of cal-view)
  =/  k=(unit cal:cal)  (~(get by cals.c) id)
  ?~  k  (pure:m row)
  ?.  ?=(%ship kind.props.u.k)  (pure:m row)
  ?.  (gth seq.u.k since)  (pure:m row)
  =/  sup=(set [@t @ud])  (suppressed row)
  ::  read-only (the calendar's remote string is the truth; the row's
  ::  mode is for display): nothing to push, so the watermark just
  ::  follows the local seq and the pull's suppressed rows are pruned
  ?:  (ship-read-only c id)
    %-  pure:m
    ?.  ?=(%o -.row)  row
    [%o (~(gas by p.row) ~[['pushed_seq' (numb:enjs:format seq.u.k)] ['suppressed' (suppress-json sup seq.u.k)]])]
  =/  changes=(list [uid:cal ?(%put %del)])
    =/  latest=(map uid:cal ?(%put %del))
      %+  roll  (tap:on-log:cal log.u.k)
      |=  [[key=@ud val=logent:cal] acc=(map uid:cal ?(%put %del))]
      ?.  (gth key since)  acc
      ?^  (find "#" (trip uid.val))  acc
      ?:  (~(has in sup) [uid.val key])  acc
      (~(put by acc) uid.val kind.val)
    ~(tap by latest)
  ;<  now=@da  bind:m  get-time:io
  =/  cal-lane=lane:tarball  [%& base %'calendar.calendar']
  =/  stopped=?  |
  ::  the row's etags follow what we push: etags are content hashes,
  ::  so a host that later puts the old content back would otherwise
  ::  look unchanged against the etag of our last pull and be skipped
  =/  etags=(map @t json)  =/(e (obj:gcal row 'etags') ?:(?=(%o -.e) p.e ~))
  |-
  ?^  changes
    =/  [u=uid:cal what=?(%put %del)]  i.changes
    =/  body=json
      ?:  =(%del what)
        (pairs:enjs:format ~[['action' s+'share-del'] ['cal' s+hcal] ['uid' s+u]])
      =/  ics=(unit @t)  (dav-object-ics c id u now)
      ?~  ics  [%o ~]
      (pairs:enjs:format ~[['action' s+'share-put'] ['cal' s+hcal] ['ics' s+u.ics]])
    ?:  =([%o ~] body)  $(changes t.changes)
    ;<  ok=?  bind:m  (remote-poke-wait u.host cal-lane body)
    ?.  ok
      ~&  >>>  [%calendar-share-push-stopped u]
      $(changes ~, stopped &)
    =.  etags
      ?:  =(%del what)  (~(del by etags) u)
      =/  e=(unit entry:cal)  (~(get by entries.u.k) u)
      ?~(e etags (~(put by etags) u s+etag.u.e))
    $(changes t.changes)
  %-  pure:m
  ?.  ?=(%o -.row)  row
  :-  %o
  %-  ~(gas by p.row)
  :~  ['pushed_seq' (numb:enjs:format ?:(stopped since seq.u.k))]
      ['suppressed' (suppress-json sup ?:(stopped since seq.u.k))]
      ['etags' [%o etags]]
  ==
::  +google-prod: wake the sync fiber now
++  google-prod
  |=  pre=@t
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (poke-soft-unit (grub-road pre 'google.sig'))
++  poke-soft-unit
  |=  =road:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  *  bind:m  (poke-soft:io road [[/ %json] `json`[%o ~]])
  (pure:m ~)
++  get-meta
  |=  e=event:cal
  ^-  meta:cal
  ?-(-.e %timed meta.e, %allday meta.e, %date meta.e, %todo meta.e)
::  +ev-kind: the recurrence kind name, or 'date'
::
++  ev-kind
  |=  e=event:cal
  ^-  @t
  ?-(-.e %date 'date', %todo 'todo', %timed name.kind.recur.e, %allday name.kind.recur.e)
::  +carry-except: preserve the old event's skipped indices onto the
::  freshly-parsed replacement (only where both have a bound)
::
++  carry-except
  |=  [old=event:cal new=event:cal]
  ^-  event:cal
  =/  ex=(set @ud)
    ?-(-.old ?(%date %todo) ~, %timed except.bound.old, %allday except.bound.old)
  ?~  ex  new
  ?-  -.new
    ?(%date %todo)  new
    %timed   new(except.bound ex)
    %allday  new(except.bound ex)
  ==
::
++  gs
  |=  [jon=json k=@t]
  ^-  @t
  ?.  ?=(%o -.jon)  ''
  =/  j=(unit json)  (~(get by p.jon) k)
  ?:(?=([~ %s *] j) p.u.j '')
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
++  da-to-ms  |=(d=@da `@ud`?:((lth d ~1970.1.1) 0 (div (mul (sub d ~1970.1.1) 1.000) ~s1)))
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
    ::  a task's relative alarm counts from its due moment (RFC 5545
    ::  3.8.6.3), not from the day it sits on
    =/  at=@da  ?:(?=(%todo -.event.u.en) (fall due.event.u.en l.span.r) l.span.r)
    =/  mins=@ud  (div ?:((gth at now) (sub at now) 0) ~m1)
    =/  body=@t  (crip ?:(=(0 mins) "starting now" "in {(scow %ud mins)} min"))
    =/  als=(list alarm:cal)  alarms.u.en
    =/  n=@ud  0
    |-  ^-  (list [name=@t body=@t tag=@t])
    ?~  als  ~
    =/  rest  $(als t.als, n +(n))
    ?.  ?=(%rel -.trigger.i.als)  rest
    ?.  (gte at before.trigger.i.als)  rest
    ?.  (in-win (sub at before.trigger.i.als))  rest
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
          (line '/sys/gall/' 'tell another ship you shared a calendar with it, and send it your edits to a calendar it shared with you. Refuse this and sharing with ships is unavailable; everything else works')
          (line '/sys/ames/registry' 'let the ships you share a calendar with read it. Refuse this and sharing with ships is unavailable')
          (line '/sys/ames/usergroups/' 'keep one group per shared calendar: the ships that may read it, and whether they may edit it')
      ==
      :-  'peek'
      :-  %a
      :~  (line '/sys/link/' 'look up where this app is installed, so the page can address its own writer. Refuse this and the page cannot save events')
          (line '/apps/calendar.calendar/' 'copy your existing events, reminders and feeds across from where the calendar used to live. Read-only, once, and the old copy is left untouched. Refuse it and this install starts empty')
          (line '/sys/ames/usergroups/' 'see which ships a calendar is shared with')
          (line '/sys/ames/ships/' 'read a calendar another ship shared with you, and keep it current. Refuse this and calendars shared with you are unavailable')
      ==
      :-  'make'
      :-  %a
      :~  (line '/sys/ames/usergroups/' 'make the group for a calendar the first time it is shared')
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
      ?(%date %todo)  ~
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
    ?(%date %todo)  e
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
  =/  kn=(unit @tas)  (slaw %tas kind)
  ?~  kn  ~
  `[[/lib/rules u.kn] args u.start]
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
    ?:  =('' z)  dz
    ?:((known-zone:rules z) `z dz)
  =/  =fin:cal
    =/  f=@t  (gs jon 'fin')
    ?:  =('to' f)  [%to (fall (bind (gn jon 'end_ms') ms-to-da) *@da)]
    [%dur (mul (fall (gn jon 'dur_min') 0) ~m1)]
  `[%timed u.rec zone fin bound meta]
--
