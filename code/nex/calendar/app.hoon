::  calendar: events over the rules library
::
::  /calendar.calendar   portable intent: config + events (poke CRUD)
::  /order.calendar-cache     derived index by uid, reinflated on news
::  /index.calendar-cache     the same keyed <calendar>/<uid>, ours
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
/<  core   /lib/calendar-core.hoon
::  the rule kinds, compiled in: a single moment, a fixed period, and an
::  RFC 5545 RRULE for everything else. Events name a kind by rail
::  ([/lib/rules %rrule]); the name is the lookup key. The preset kinds
::  (daily, weekly, monthly, monthly-nth, yearly, cron) are retired into
::  rrule: +as-rrule:ics, on every way in and once at rise.
/<  k-every        /lib/rules/every.hoon
/<  k-once         /lib/rules/once.hoon
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
            color+s+'#1E1B4B'
            image+s+'/grubbery/tiles/icon/calendar'
            href+s+'/apps/calendar'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'calendar'] ['description' s+'Calendar events']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'calendar.calendar'] [[/ %calendar] fresh-calendar:cal]]
          ::  order.calendar-cache: the occurrence index by uid, the shape
          ::  and keys other apps read (orrery clams it with its own copy
          ::  of the type and finds an event's occurrences by its uid).
          ::  index.calendar-cache: the same keyed <calendar>/<uid>, so the
          ::  same UID in two calendars is two events; this app reads that
          ::  one. order-ver.json: the calendar both were built from
          ::  (+cache-ver).
          [%fall %& [/ %'order.calendar-cache'] [[/ %calendar-cache] *cache:cal]]
          [%fall %& [/ %'index.calendar-cache'] [[/ %calendar-cache] *cache:cal]]
          [%fall %& [/ %'order-ver.json'] [[/ %json] [%o ~]]]
          ::  rise.json: per fiber, its crashes in a row and when it tries
          ::  again (+rise-later)
          [%fall %& [/ %'rise.json'] [[/ %json] [%o ~]]]
          ::  outcomes.json: what a poke was refused for, and the faults
          ::  that stand (docs/logging.md)
          [%fall %& [/ %'outcomes.json'] [[/ %json] [%o ~]]]
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
          ::  refusals.json: refused share edits the sync fiber still has
          ::  to tell their peers about (+send-refusals)
          [%fall %& [/ %'refusals.json'] [[/ %json] [%a ~]]]
          ::  share-writes.json: per shared calendar and uid, the version each
          ::  peer's last accepted write left (+share-base-ok)
          [%fall %& [/ %'share-writes.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'share-offers.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'ship-remotes.json'] [[/ %json] [%o ~]]]
          ::  invitations to one event. invites-sent.json: per event of ours
          ::  (<cal>/<uid>), what each guest ship was last sent; invites.json:
          ::  the ones other ships sent us (<host>/<uid>), with our answer
          ::  and the calendar the copy is on; invite-routes.json: per host,
          ::  the calendar its last accepted invite went on
          [%fall %& [/ %'invites-sent.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'invites.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'invite-routes.json'] [[/ %json] [%o ~]]]
          ::  talon-rooms.json: each event's call room on trunk, by room:
          ::  its calendar and uid, its link once trunk made one, and when
          ::  a refused one was last asked
          [%fall %& [/ %'talon-rooms.json'] [[/ %json] [%o ~]]]
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
        ;<  ~  bind:m  (rise-later prod "calendar: the main fiber")
        ::  the roads the main fiber asks softly: the timer, the clock, and
        ::  the web binding, which it makes here. A refusal is recorded
        ;<  ~  bind:m  check-roads
        ::  any ship may poke our share inbox: the road rides on /public
        ;<  ~  bind:m  lay-inbox-road
        (http-dispatch:io %cal)
          ::
          ::  /calendar.calendar: poke CRUD on events
          ::
          [~ %'calendar.calendar']
        ;<  ~  bind:m  (rise-later prod "calendar: the events fiber")
        ::  events of a retired preset kind become the rrules they phrase,
        ::  once: after the first rise this changes nothing
        ;<  raw0=*  bind:m  (get-state-as:io ,*)
        =/  c0=calendar:cal  (lift:cal raw0)
        =/  c1=calendar:cal  (migrate-rules (migrate-kinds c0))
        ;<  ~  bind:m  ?:(=(c0 c1) (pure:m ~) (replace:io c1))
        ;<  our=@p  bind:m  get-our:io
        |-
        ::  a poke is acknowledged when it is taken, so a reload between
        ::  taking and writing loses it: what a poke needs is fetched before
        ::  (entropy, drawn while idle) or not at all, and a branch that must
        ::  wait (the clock) reads the state after. The state is read after
        ::  every wait: a write from another fiber (a sync pass, a CalDAV
        ::  client) that landed meanwhile would be undone by writing back a
        ::  copy read before it.
        ;<  eny=@uvJ  bind:m  get-entropy:io
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?.  ?=([%o *] jon)  $
        =/  act=@t  (gs jon 'action')
        =/  src=(unit @p)  (get-poke-src:io from)
        ;<  shares=json  bind:m
          ?~(src (pure:(fiber:fiber:nexus ,json) *json) (read-json-grub './' 'shares.json'))
        ;<  writes=json  bind:m
          ?~(src (pure:(fiber:fiber:nexus ,json) *json) (read-json-grub './' 'share-writes.json'))
        ::  the clock, only for what stamps a time
        ;<  now=@da  bind:m
          ?.  ?=(?(%'add-calendar' %'done-event') act)  (pure:(fiber:fiber:nexus ,@da) *@da)
          get-time:io
        ;<  raw=*  bind:m  (get-state-as:io ,*)
        =/  c=calendar:cal  (lift:cal raw)
        ::  a foreign ship: only an edit to a calendar shared with it
        ?^  src
          =/  cid=@ta  (crip (trip (gs jon 'cal')))
          =/  mode=@t  (gs (obj:gcal shares cid) (scot %p u.src))
          ::  a refused edit is said back to the peer (the poke's ack only
          ::  says it arrived), so it is not lost silently: the peer keeps
          ::  its copy as a conflict and, told the calendar is read-only,
          ::  stops offering edits. A ship we share nothing with hears nothing.
          =/  tell
            |=  [u=@t why=@t ics=@t]
            =/  m  (fiber:fiber:nexus ,~)
            ^-  form:m
            ;<  ~  bind:m  (refuse './' act u (scot %p u.src) (trip why))
            ?:  =('' mode)  (pure:m ~)
            ::  queued for the sync fiber to send (+send-refusals): waiting
            ::  on the peer here would hold every poke to the calendar, and
            ::  a peer could keep it waiting
            (queue-refusal u.src cid u why mode ics)
          ?.  =('edit' mode)
            ;<  ~  bind:m  (tell (gs jon 'uid') 'the calendar is shared with you read-only' (gs jon 'ics'))
            $
          =/  k=(unit cal:cal)  (~(get by cals.c) cid)
          ?~  k
            ;<  ~  bind:m  (tell (gs jon 'uid') 'the host has no such calendar' (gs jon 'ics'))
            $
          ?:  =('share-put' act)
            =/  ves0=(list vevent:ics)  (fall (mole |.((events:ics (gs jon 'ics')))) ~)
            =/  real=@t  (fall (bind (lead-of ves0) |=(v=vevent:ics uid.v)) '')
            ::  the key the peer holds it under (an older peer names none)
            =/  u=@t  =/(n (gs jon 'uid') ?:(=('' n) real n))
            =/  al=[ves=(list vevent:ics) extra=(list [@t @t])]  (alias-object ves0 u)
            ::  an object needs its UID, and a UID that lives in another of
            ::  our calendars is not the peer's to write
            =/  home=(unit [id=@ta e=entry:cal])  (find-entry:cal c u)
            ?:  |(!(key-ok u) &(?=(^ home) !=(cid id.u.home) !(~(has by entries.u.k) u)))
              ;<  ~  bind:m  (tell u 'another calendar of the host holds this UID' (gs jon 'ics'))
              $
            ::  base: the host's version the peer last pulled. An edit made
            ::  here (or by another peer) since is not the peer's to write
            ::  over; its own last write through here is (+share-base-ok)
            ?.  (share-base-ok writes cid u u.src (gs jon 'base') (~(get by entries.u.k) u))
              ;<  ~  bind:m  (tell u 'it changed on the host since you last pulled it' (gs jon 'ics'))
              $
            =/  put=(unit [k=cal:cal =uid:cal])  (fall (mole |.((put-object u.k ves.al zone.c u extra.al))) ~)
            ?~  put
              ;<  ~  bind:m  (tell u 'the host could not read the event' (gs jon 'ics'))
              $
            ::  Google mails whoever an event names, from our account: on a
            ::  calendar linked to it the guests stay ours
            =/  kk=cal:cal
              ?.  ?=(%google kind.props.u.k)  k.u.put
              (own-guests u.k k.u.put uid.u.put)
            ;<  ~  bind:m  (replace:io c(cals (~(put by cals.c) cid kk)))
            ;<  ~  bind:m  (note-share-write writes cid kk u u.src)
            $
          ?:  =('share-del' act)
            =/  u=@t  (gs jon 'uid')
            ?.  (share-base-ok writes cid u u.src (gs jon 'base') (~(get by entries.u.k) u))
              ;<  ~  bind:m  (tell u 'it changed on the host since you last pulled it; the delete was not made' '')
              $
            =/  k2=cal:cal  (del-object u.k u)
            ;<  ~  bind:m  (replace:io c(cals (~(put by cals.c) cid k2)))
            ;<  ~  bind:m  (note-share-write writes cid k2 u u.src)
            $
          $
        ::  a read-only shared calendar takes no local edits; an action
        ::  that names only an id is judged by the calendar that owns it.
        ::  home names that calendar when the same UID lives in two.
        =/  named=@ta  (crip (trip (gs jon 'cal')))
        =/  home=@ta  (crip (trip (gs jon 'home')))
        =/  owner=@ta  (fall (bind (locate c home (gs jon 'id')) head) '')
        ?:  |(&(!=('' named) (ship-read-only c named)) &(!=('' owner) (ship-read-only c owner)))
          ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' "the calendar is shared with you read-only")
          $
        ?:  =('del-event' act)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          ?:  =('' id)  $
          ;<  ~  bind:m  (replace:io (del-ev c home id))
          $
        ::  skip-event names the occurrence by index; skip-at by the
        ::  moment it starts, for a client that holds a time and not an
        ::  index (the page, orrery's ship-side executor). Only the
        ::  expansion of the recurrence knows the index, so skip-at does
        ::  that counting here.
        ::  unskip-at puts back an occurrence skip-at took out (the page's
        ::  undo): its index is counted as if nothing were skipped
        ?:  |(=('skip-event' act) =('skip-at' act) =('unskip-at' act))
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  ev=(unit event:cal)  (event-of c home id)
          ?~  ev  $
          =/  un=?  =('unskip-at' act)
          =/  idx=(unit @ud)
            ?:  =('skip-event' act)  (gn jon 'idx')
            =/  walk=event:cal  ?:(un (set-skips u.ev ~) u.ev)
            (biff (gn jon 'start_ms') |=(ms=@ud (occurrence-index walk (ms-to-da ms))))
          ::  no occurrence starts there, so there is nothing to skip
          ?~  idx  $
          ::  one moved elsewhere (a child) stays skipped: put back, it
          ::  would show twice
          ?:  &(un (moved-at c home id u.idx))  $
          ::  a date or a task has none to skip; add-skips leaves it be
          =/  new=event:cal
            ?.  un  (add-skips u.ev (sy u.idx ~))
            (set-skips u.ev (~(del in (skips-of u.ev)) u.idx))
          ;<  ~  bind:m  (replace:io (put-ev c home id new))
          $
        ::  edit-at: "only this one". The occurrence that starts at at_ms
        ::  (as skip-at names it) takes the poke's own shape (a single
        ::  event, add-event's fields) as an override child of the series
        ?:  =('edit-at' act)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  at=(unit @ud)  (gn jon 'at_ms')
          =/  ev=(unit event:cal)  (parse-event jon zone.c)
          =/  als=alarms-arg:core  (parse-alarms jon)
          ?:  ?=(%bad -.als)
            ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' why.als)
            $
          =/  new=(unit calendar:cal)
            ?.  &(?=(^ at) ?=(^ ev))  ~
            (put-child c home id (ms-to-da u.at) u.ev ?:(?=(%set -.als) `l.als ~))
          ?~  new
            ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' "no repeating event has an occurrence there, or the new one could not be read")
            $
          ;<  ~  bind:m  (replace:io u.new)
          $
        ::  split-event: "this and following" as one step. The series ends
        ::  before occurrence idx and a new one (the poke's own fields, in
        ::  the calendar it names) starts there, keeping the old one's skips
        ::  that fall on its days. Two pokes could leave half of it done.
        ?:  =('split-event' act)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  old=(unit event:cal)  (event-of c home id)
          =/  cap=(unit @ud)  (gn jon 'idx')
          ?:  |(?=(~ old) ?=(~ cap))  $
          ?.  ?=(?(%timed %allday) -.u.old)  $
          =/  ev=(unit event:cal)  (parse-event jon zone.c)
          ?~  ev
            ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' "the event could not be read: its name, kind, start or rule")
            $
          =/  als=alarms-arg:core  (parse-alarms jon)
          ?:  ?=(%bad -.als)
            ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' why.als)
            $
          ::  the new series takes the alarms the poke names, else the old one's
          =/  old-als=(list alarm:cal)  (fall (bind (locate c home id) |=([* e=entry:cal] alarms.e)) ~)
          ;<  new=event:cal  bind:m  (apply-until (carry-skips u.old u.ev) (gn jon 'until_ms'))
          =/  nid=@ta  (crip "{(scow %uv (end [3 8] eny))}@{(scow %p our)}")
          ::  a cap only shortens: one past the series' own end (its COUNT)
          ::  would make it longer
          =/  capped=event:cal
            ?-  -.u.old
              %timed   u.old(dom.bound `(min u.cap (fall dom.bound.u.old u.cap)))
              %allday  u.old(dom.bound `(min u.cap (fall dom.bound.u.old u.cap)))
            ==
          =.  c  (put-ev-in (put-ev c home id capped) (cal-arg jon) '' nid new)
          =.  c  (set-alarms c '' nid ?:(?=(%set -.als) l.als old-als))
          ;<  ~  bind:m  (replace:io c)
          $
        ?:  =('add-calendar' act)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  nm=@t  (gs jon 'name')
          ::  an id goes into hrefs and index keys: a knot, no slash
          ?:  |(=('' id) =('' nm) !((sane %ta) id) (~(has by cals.c) id))
            ;<  ~  bind:m  (refuse './' act id '' "a calendar needs a name and a new id of lowercase letters, digits and - . ~ _")
            $
          =/  color=@t  (gs jon 'color')
          =/  k=cal:cal  (born now)
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
          =/  lm=(unit @ud)  (gn jon 'lead_min')
          =.  title.c  ?:(=('' ti) title.c ti)
          ::  a zone pytz does not know is not taken (every timed event
          ::  with none of its own would be placed in it)
          =.  zone.c
            ?:  =('' zo)  zone.c
            ?:  =('none' zo)  ~
            ?:((known-zone:rules zo) `zo zone.c)
          ::  ponytail: ten years is as far as the index is walked ahead
          =.  horizon.c  ?~(hd horizon.c (mul (max 1 (min 3.650 u.hd)) ~d1))
          ;<  ~  bind:m  (replace:io c)
          ;<  ~  bind:m
            ?:  |(=('' zo) =('none' zo) (known-zone:rules zo))  (pure:(fiber:fiber:nexus ,~) ~)
            (refuse './' act zo '' "the zone is not one this ship knows; the calendar's stays")
          ::  lead_min: the heads-up before every timed event; 0 turns it
          ::  off and leaves the alarms events carry
          ;<  ~  bind:m  ?~(lm (pure:(fiber:fiber:nexus ,~) ~) (set-lead-min u.lm))
          $
        ?:  =('add-feed' act)
          =/  nm=@t   (gs jon 'name')
          =/  url=@t  (gs jon 'url')
          ?:  |(=('' nm) =('' url))  $
          ;<  fj=json  bind:m  (read-json-grub './' 'gcal-feeds.json')
          =/  feeds=(map @t json)  ?.(?=([%o *] fj) ~ p.fj)
          ;<  ~  bind:m  (write-json-grub './' 'gcal-feeds.json' [%o (~(put by feeds) nm s+url)])
          $
        ?:  =('del-feed' act)
          =/  nm=@t  (gs jon 'name')
          ?:  =('' nm)  $
          ;<  fj=json  bind:m  (read-json-grub './' 'gcal-feeds.json')
          =/  feeds=(map @t json)  ?.(?=([%o *] fj) ~ p.fj)
          ;<  ~  bind:m  (write-json-grub './' 'gcal-feeds.json' [%o (~(del by feeds) nm)])
          $
        ::  sync-feeds is an HTTP route now (POST sync-feeds): its fetches
        ::  held every poke here while they ran
        ?:  =('edit-event' act)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  old=(unit event:cal)  (event-of c home id)
          ?~  old
            ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' "no such event")
            $
          =/  ev=(unit event:cal)  (parse-event jon zone.c)
          ?~  ev
            ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' "the event could not be read: its name, kind, start or rule")
            $
          ::  alarms: absent keeps the entry's, a list replaces them, and
          ::  one that cannot be read refuses the whole edit
          =/  als=alarms-arg:core  (parse-alarms jon)
          ?:  ?=(%bad -.als)
            ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' why.als)
            $
          =/  pri=priority-arg:core  (parse-priority jon)
          ?:  ?=(%bad -.pri)
            ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' why.pri)
            $
          ::  the shape is replaced but exceptions survive the edit
          =/  merged=event:cal  (carry-skips u.old u.ev)
          ::  a task's priority: named sets or clears it; absent keeps it
          =.  merged  (set-pri merged ?:(?=(%set -.pri) n.pri (meta-priority:cal (meta-of:cal u.old))))
          ;<  new=event:cal  bind:m  (apply-until merged (gn jon 'until_ms'))
          ::  the calendar it lands in, and the alarms with it there: a move
          ::  onto a UID that calendar holds is refused, not dropped
          =/  to=(unit @ta)  (target-of c (cal-arg jon) home id)
          ?~  to
            ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' "the calendar it would move to already has an event with this UID")
            $
          =.  c  (put-ev-in c (cal-arg jon) home id new)
          =?  c  ?=(%set -.als)  (set-alarms c u.to id l.als)
          ;<  ~  bind:m  (replace:io c)
          $
        ?:  =('rsvp' act)
          ::  the owner's answer to an invitation: the guest marked self
          ::  takes the status, and the calendar's sync tells the organizer
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  st=@t  (gs jon 'status')
          =/  old=(unit event:cal)  (event-of c home id)
          ?~  old
            ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' "no such event")
            $
          ?.  ?=(?(%accepted %declined %tentative) st)
            ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' "the answer is accepted, declined or tentative")
            $
          =/  mt=meta:cal  (meta-of:cal u.old)
          =/  gl=(unit json)  (~(get by mt) 'guests')
          =/  guests=(list json)  ?.(?=([~ %a *] gl) ~ p.u.gl)
          =/  me  |=(g=json &(?=([%o *] g) =([~ %b %.y] (~(get by p.g) 'self'))))
          ?.  (lien guests me)
            ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' "the event names no guest who is this calendar's owner")
            $
          =/  new=(list json)
            %+  turn  guests
            |=  g=json
            ?.  &((me g) ?=([%o *] g))  g
            [%o (~(put by p.g) 'status' s+st)]
          ;<  ~  bind:m  (replace:io (put-ev c home id (put-meta:cal u.old (~(put by mt) 'guests' [%a new]))))
          $
        ?:  =('done-event' act)
          ::  tick or untick a task
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  old=(unit event:cal)  (event-of c home id)
          ?~  old
            ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' "no such event")
            $
          ?.  ?=(%todo -.u.old)  $
          =/  done=(unit @da)
            =/  j=(unit json)  (~(get by p.jon) 'done')
            ?:(?=([~ %b %.n] j) ~ `now)
          ;<  ~  bind:m  (replace:io (put-ev c home id u.old(done done)))
          $
        ?:  =('cap-event' act)
          ::  end the series before index dom (this-and-following edits)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  cap=(unit @ud)  (gn jon 'dom')
          ?:  |(=('' id) ?=(~ cap))  $
          =/  old=(unit event:cal)  (event-of c home id)
          ?~  old
            ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' "no such event")
            $
          =/  new=(unit event:cal)
            ::  a cap only shortens, as split-event's
            ?-  -.u.old
              %date   ~
              %todo   ~
              %timed   `u.old(dom.bound `(min u.cap (fall dom.bound.u.old u.cap)))
              %allday  `u.old(dom.bound `(min u.cap (fall dom.bound.u.old u.cap)))
            ==
          ?~  new  $
          ;<  ~  bind:m  (replace:io (put-ev c home id u.new))
          $
        ?.  =('add-event' act)  $
        =/  ev=(unit event:cal)  (parse-event jon zone.c)
        ?~  ev
          ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' "the event could not be read: its name, kind, start or rule")
          $
        =/  als=alarms-arg:core  (parse-alarms jon)
        ?:  ?=(%bad -.als)
          ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' why.als)
          $
        =/  pri=priority-arg:core  (parse-priority jon)
        ?:  ?=(%bad -.pri)
          ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' why.pri)
          $
        =/  ev1=event:cal  ?:(?=(%set -.pri) (set-pri u.ev n.pri) u.ev)
        ;<  ev2=event:cal  bind:m  (apply-until ev1 (gn jon 'until_ms'))
        ::  a poke answers nothing but its ack, so a client that needs the
        ::  new event's id names it: an id taken or unusable refuses the add
        =/  want=@t  (gs jon 'id')
        ?:  &(!=('' want) !(new-id-ok c want))
          ;<  ~  bind:m  (refuse './' act (gs jon 'id') '' "the id is taken, or holds a slash, a hash or a control character")
          $
        =/  id=@ta
          ?.  =('' want)  (crip (trip want))
          (crip "{(scow %uv (end [3 8] eny))}@{(scow %p our)}")
        =.  c  (put-ev-in c (cal-arg jon) '' id ev2)
        =?  c  ?=(%set -.als)  (set-alarms c '' id l.als)
        ;<  ~  bind:m  (replace:io c)
        $
          ::
          ::  /order.calendar-cache: reinflate on calendar news
          ::
          [~ %'order.calendar-cache']
        ;<  ~  bind:m  (rise-later prod "calendar: the cache fiber")
        =/  road  (cord-to-road:tarball './calendar.calendar')
        ;<  *  bind:m  (keep:io /cal road ~)
        ::  news that leaves the events and the horizon as they were (a
        ::  rename, a sync stamping remote ids) inflates nothing: the
        ::  cache is only marked current. One window.json already built
        ::  for this calendar is left as it is.
        ::  the spans index (+spans-index:core) is kept here, in memory:
        ::  a grub of it would cost a write per change, and after a
        ::  restart one build whole brings it back
        =|  last=(unit [(map eid:cal event:cal) @dr (unit @t)])
        =|  ix=spans-index:core
        |-
        ;<  =view:nexus  bind:m  (peek:io road ~)
        ?.  ?=([%file *] view)
          ;<  *  bind:m  (take-news:io /cal)
          $
        =/  c=calendar:cal  (cal-of view)
        =/  ver=@uv  (cache-ver:cal c)
        ;<  have=@uv  bind:m  (read-cache-ver './')
        ::  current already (a request built it): nothing to key, and last
        ::  is forgotten, so the next change at worst refreshes
        ?:  =(ver have)
          ;<  *  bind:m  (take-news:io /cal)
          $(last ~)
        =/  key=(unit [(map eid:cal event:cal) @dr (unit @t)])  `[(keyed-events c) horizon.c zone.c]
        ?:  =(last key)
          ;<  ~  bind:m  (write-cache-ver './' ver)
          ;<  *  bind:m  (take-news:io /cal)
          $
        ;<  now=@da  bind:m  get-time:io
        ;<  ca=cache:cal  bind:m  (read-cache './')
        ::  the reach moves on, and everything is built again, when under
        ::  half the horizon is left; else only the events that changed
        =/  reach=@dr  (min horizon.c max-reach)
        =/  thru=@da  ?:((lth thru.ca (add now (div reach 2))) (add now reach) thru.ca)
        =/  [new=cache:cal nix=spans-index:core]  (refresh-cache:core ca ix c kind-for thru)
        ::  each write of a noun this size costs the kernel most of a
        ::  second, so the copy other apps read moves only when the
        ::  occurrences did (a rename leaves them)
        ;<  ~  bind:m
          ?:  =(order.new order.ca)  (pure:(fiber:fiber:nexus ,~) ~)
          (replace:io (by-uid new))
        ;<  ~  bind:m
          ?:  =(new ca)  (pure:(fiber:fiber:nexus ,~) ~)
          (over:io (grub-road './' 'index.calendar-cache') [[/ %calendar-cache] new])
        ;<  ~  bind:m  (write-cache-ver './' ver)
        ;<  *  bind:m  (take-news:io /cal)
        $(last key, ix nix)
          ::
          ::  /google.sig: the sync fiber, every backend (Google, followed
          ::  CalDAV calendars, sharing both ways)
          ::
          [~ %'google.sig']
        ;<  ~  bind:m  (rise-later prod "calendar: the sync fiber")
        ::  a pass on every tick and prod (pull then push); on calendar
        ::  news, push only: a pass's own writes wake it, and a push-only
        ::  pass with nothing past the watermark does nothing. The tick is
        ::  due a period after the last pull, not after the last news, so a
        ::  calendar that keeps changing still gets pulled.
        =/  cal-road  (cord-to-road:tarball './calendar.calendar')
        ;<  *  bind:m  (keep:io /cal cal-road ~)
        ::  a refusal queued in the calendar's fiber wakes a pass at once
        ;<  *  bind:m  (keep:io /refusals (cord-to-road:tarball './refusals.json') ~)
        =|  pulled=@da
        ::  the calendar as the last pass began: news of a write that
        ::  pass already saw (a pull writes once a page, and each write is
        ::  news of its own) is no reason for another
        =|  seen=@uv
        |-
        ;<  cfg=json  bind:m  (google-config './')
        =/  tick=@dr  (mul ~m1 (max 1 (fall (gn cfg 'tick_min') 5)))
        ;<  now=@da  bind:m  get-time:io
        ;<  ~  bind:m  (set-timer:io /tick (max now (add pulled tick)))
        ;<  what=$@(%poke [%news =wire])  bind:m  (take-any ~[/cal /refusals])
        ;<  ~  bind:m  (cancel-timer:io /tick)
        =/  pull=?  =(%poke what)
        ;<  c0=calendar:cal  bind:m  (read-cal './')
        ::  the events (cache-ver) and each calendar's props (a rename, a
        ::  share's mode, which change no seq)
        =/  ver=@uv  (sham [(cache-ver:cal c0) (~(run by cals.c0) |=(k=cal:cal props.k))])
        ?:  &(?=([%news [%cal *]] what) =(ver seen))  $
        ::  refusal news when none is queued is send-refusals' own write
        ;<  rq=json  bind:m  ?.(?=([%news [%refusals *]] what) (pure:(fiber:fiber:nexus ,json) [%a [~ ~]]) (read-json-grub './' 'refusals.json'))
        ?:  &(?=([%news [%refusals *]] what) |(?=(~ rq) =([%a ~] rq)))  $
        =.  seen  ver
        ;<  ~  bind:m  (sync-pass %google pull)
        ;<  ~  bind:m  (sync-pass %caldav pull)
        ;<  ~  bind:m  share-pass
        ;<  ~  bind:m  invite-pass
        ;<  ~  bind:m  reply-pass
        ;<  ~  bind:m  talon-pass
        ;<  ~  bind:m  send-refusals
        ;<  ~  bind:m  (sync-pass %ship pull)
        ::  a grant approved after the rise: the inbox road lands here
        ;<  ~  bind:m  lay-inbox-road
        ?.  pull  $
        ;<  now=@da  bind:m  get-time:io
        $(pulled now)
          ::
          ::  /shares.sig: other ships poke offers (and revocations) of
          ::  calendars they share with us. The sender is the transport's;
          ::  the payload is data. An offer waits until the owner accepts.
          ::
          [~ %'shares.sig']
        ;<  ~  bind:m  (rise-later prod "calendar: the shares fiber")
        ::  when a refusal last woke the sync fiber: once a minute at most
        =|  prodded=@da
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        =/  src=(unit @p)  (get-poke-src:io from)
        ?~  src  $
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?.  ?=([%o *] jon)  $
        =/  act=@t  (gs jon 'action')
        ::  an invitation to one event (+invite-pass on the host): kept until
        ::  the owner answers; one already accepted moves its copy with it
        ?:  =('invite' act)
          =/  u=@t  (gs jon 'uid')
          =/  txt=@t  (gs jon 'ics')
          =/  nm=@t  (gs jon 'name')
          ?:  |(!(key-ok u) =('' txt) (gth (met 3 txt) invite-max) (gth (met 3 nm) 1.024))  $
          =/  raw=(unit json)  (~(get by p.jon) 'ships')
          ?:  &(?=([~ %a *] raw) (gth (lent p.u.raw) 100))  $
          =/  ships=json  (clean-ships raw)
          ::  every VEVENT in it is the invitation's own: one naming another
          ::  UID could land on an event of ours
          =/  ves=(list vevent:ics)  (fall (mole |.((events:ics txt))) ~)
          ?~  ves  $
          ?:  (lien `(list vevent:ics)`ves |=(v=vevent:ics !=(u uid.v)))  $
          =/  ikey=@t  (crip "{(scow %p u.src)}/{(trip u)}")
          ::  the clock first: from the read to the write nothing waits
          ;<  now=@da  bind:m  get-time:io
          ;<  rj=json  bind:m  (read-json-grub './' 'invite-routes.json')
          ;<  ij=json  bind:m  (read-json-grub './' 'invites.json')
          =/  cur=(map @t json)  (omap ij)
          =/  old=json  (fall (~(get by cur) ikey) (pairs:enjs:format ~[['status' s+''] ['cal' s+'']]))
          ::  the same invitation again changes nothing, and writes nothing
          ::  (its DTSTAMP, the moment it was sent, always differs)
          ?:  &(=((sans-stamp txt) (sans-stamp (gs old 'ics'))) =(nm (gs old 'name')) =(`ships (~(get by (omap old)) 'ships')))  $
          ::  any ship can send them. A host accepted from before at ten
          ::  unanswered gives up its own oldest for the new one (its ignored
          ::  invitations do not stop its next), a stranger at ten has the
          ::  new one dropped, and a full inbox gives up a declined
          ::  one, else the oldest unanswered from a ship never accepted
          ::  from (invite-routes.json), else the oldest unanswered: a run of
          ::  strangers churns strangers. One whose copy is placed is never
          ::  given up (nor counted): its host's changes and cancel must
          ::  find it.
          =/  new=?  !(~(has by cur) ikey)
          =/  open  |=(r=json =('' (gs r 'status')))
          =/  oldest
            |=  l=(list [@t json])
            ^-  (unit @t)
            ?~  l  ~
            `-:(snag 0 (sort l |=([a=[@t json] b=[@t json]] (lth (fall (gn +.a 'at_ms') 0) (fall (gn +.b 'at_ms') 0)))))
          =/  theirs=(list [@t json])  (skim ~(tap by cur) |=([* r=json] &((open r) =((gs r 'host') (scot %p u.src)))))
          =/  known=?  (~(has by (omap rj)) (scot %p u.src))
          ::  (a stranger at ten is dropped: churning would let one ship
          ::  rewrite the inbox on every poke)
          ?:  &(new !known (gte (lent theirs) 10))  $
          =?  cur  &(new (gte (lent theirs) 10))  (~(del by cur) (need (oldest theirs)))
          =/  loose=(list [@t json])  (skip ~(tap by cur) |=([* r=json] &(!(open r) !=('' (gs r 'cal')))))
          =/  full=?  &(new (gte (lent loose) invite-cap))
          =/  victim=(unit @t)
            =/  gone=(list [@t json])  (skip loose |=([* r=json] (open r)))
            ?^  gone  (oldest gone)
            =/  strange=(list [@t json])  (skip loose |=([* r=json] (~(has by (omap rj)) (gs r 'host'))))
            ?^  strange  (oldest strange)
            (oldest loose)
          ?:  &(full ?=(~ victim))  $
          =?  cur  full  (~(del by cur) (need victim))
          =/  row=json
            %+  row-put  old
            :~  ['host' s+(scot %p u.src)]
                ['uid' s+u]
                ['ics' s+txt]
                ['name' s+nm]
                ['start_ms' (numb:enjs:format (fall (gn jon 'start_ms') 0))]
                ['ships' ships]
                ['at_ms' (numb:enjs:format (da-to-ms now))]
            ==
          ;<  ~  bind:m  (write-json-grub './' 'invites.json' [%o (~(put by cur) ikey row)])
          ?:  |(=('' (gs row 'cal')) =('declined' (gs row 'status')))  $
          ;<  *  bind:m  (place-invite './' row)
          $
        ::  the host took the event back, or us off it: its copy goes
        ?:  =('invite-cancel' act)
          =/  ikey=@t  (crip "{(scow %p u.src)}/{(trip (gs jon 'uid'))}")
          ;<  ij=json  bind:m  (read-json-grub './' 'invites.json')
          =/  cur=(map @t json)  (omap ij)
          =/  row=(unit json)  (~(get by cur) ikey)
          ?~  row  $
          ;<  ~  bind:m  (write-json-grub './' 'invites.json' [%o (~(del by cur) ikey)])
          ?:  =('' (gs u.row 'cal'))  $
          ;<  c=calendar:cal  bind:m  (read-cal './')
          ::  where the row put it, or where the owner moved it since; only
          ::  the host's own copy goes
          =/  hit=(unit [cid=@ta e=entry:cal])  (host-copy c (gs u.row 'cal') (gs u.row 'uid') u.src)
          ?~  hit  $
          =/  k=cal:cal  (~(got by cals.c) cid.u.hit)
          ;<  ~  bind:m  (dav-write './' c(cals (~(put by cals.c) cid.u.hit (del-object k (gs u.row 'uid')))))
          $
        ::  a guest's answer to an invitation of ours: only a ship the event
        ::  names may answer for itself
        ?:  =('invite-reply' act)
          =/  st=@t  (gs jon 'status')
          ?.  ?=(?(%accepted %declined %tentative) st)  $
          ;<  c=calendar:cal  bind:m  (read-cal './')
          =/  me  |=(g=json =([~ %s (scot %p u.src)] ?.(?=([%o *] g) ~ (~(get by p.g) 'ship'))))
          =/  guests
            |=  e=entry:cal
            ^-  (list json)
            =/  sl=(unit json)  (~(get by (meta-of:cal event.e)) 'ships')
            ?.(?=([~ %a *] sl) ~ p.u.sl)
          ::  our event that names it: the same UID may be in two calendars
          =/  hit=(unit [cid=@ta e=entry:cal])
            =/  all=(list [cid=@ta e=entry:cal])
              %+  murn  ~(tap by cals.c)
              |=  [cid=@ta k=cal:cal]
              ^-  (unit [cid=@ta e=entry:cal])
              =/  e=(unit entry:cal)  (~(get by entries.k) (gs jon 'uid'))
              ?~  e  ~
              ?:  (~(has by (meta-of:cal event.u.e)) 'host')  ~
              ?.  (lien (guests u.e) me)  ~
              `[cid u.e]
            ?~(all ~ `i.all)
          ?~  hit  $
          =/  mt=meta:cal  (meta-of:cal event.e.u.hit)
          =/  ss=(list json)  (guests e.u.hit)
          =/  new=(list json)  (turn ss |=(g=json ?.(&((me g) ?=([%o *] g)) g [%o (~(put by p.g) 'status' s+st)])))
          ?:  =(new ss)  $
          =/  k=cal:cal  (~(got by cals.c) cid.u.hit)
          =/  e2=entry:cal  e.u.hit(event (put-meta:cal event.e.u.hit (~(put by mt) 'ships' [%a new])))
          ;<  ~  bind:m  (dav-write './' c(cals (~(put by cals.c) cid.u.hit (put-entry:cal k e2))))
          $
        =/  cal-id=@t  (gs jon 'cal')
        ?:  |(=('' cal-id) (gth (met 3 cal-id) 256))  $
        =/  key=@t  (crip "{(scow %p u.src)}/{(trip cal-id)}")
        ::  the clock first: from the read to the write nothing waits
        ;<  now=@da  bind:m  get-time:io
        ;<  offers=json  bind:m  (read-json-grub './' 'share-offers.json')
        =/  cur=(map @t json)  ?:(?=([%o *] offers) p.offers ~)
        ?:  =('offer' act)
          =/  mode=@t  ?:(=('edit' (gs jon 'mode')) 'edit' 'read')
          ::  already accepted: the host changed the mode; the row and the
          ::  calendar follow, no second offer
          ;<  rows=json  bind:m  (read-json-grub './' 'ship-remotes.json')
          =/  rm=(map @t json)  ?:(?=([%o *] rows) p.rows ~)
          =/  hit=(list [id=@t row=json])  (skim ~(tap by rm) |=([* r=json] =(key (gs r 'key'))))
          ;<  c=calendar:cal  bind:m  (read-cal './')
          =/  live=(unit [id=@t row=json k=cal:cal])
            ?~  hit  ~
            =/  k=(unit cal:cal)  (~(get by cals.c) id.i.hit)
            ?~(k ~ `[id.i.hit row.i.hit u.k])
          ::  a row whose calendar was deleted here is stale: it goes, and
          ::  the offer is a fresh one
          ;<  ~  bind:m
            ?:  |(?=(~ hit) ?=(^ live))  (pure:(fiber:fiber:nexus ,~) ~)
            ;<  fresh=json  bind:(fiber:fiber:nexus ,~)  (read-json-grub './' 'ship-remotes.json')
            (write-json-grub './' 'ship-remotes.json' [%o (~(del by (omap fresh)) id.i.hit)])
          ?^  live
            ;<  ~  bind:m  (set-row './' 'ship-remotes.json' id.u.live ~[['mode' s+mode]])
            ;<  ~  bind:m  (set-remote './' (crip (trip id.u.live)) `(crip "{(trip key)}#{(trip mode)}"))
            $
          ::  ponytail: a full inbox drops new offers; 200 is far past
          ::  anything a person gets. Any ship can send one, so one host
          ::  has 20 of them at most, and nothing in one is long.
          ?:  &((gte ~(wyt by cur) 200) !(~(has by cur) key))  $
          ?:  &(!(~(has by cur) key) (gte (lent (skim ~(val by cur) |=(r=json =((gs r 'host') (scot %p u.src))))) 20))  $
          ?:  |((gth (met 3 (gs jon 'name')) 256) (gth (met 3 (gs jon 'color')) 32) (gth (met 3 (gs jon 'base')) 256))  $
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
          $
        ::  refused: the host would not take an edit of ours. Our copy is kept
        ::  as a conflict (the next pull brings the host's back), and a
        ::  calendar the host says is read-only becomes read-only here.
        ?:  =('refused' act)
          ;<  rows=json  bind:m  (read-json-grub './' 'ship-remotes.json')
          =/  rm=(map @t json)  (omap rows)
          =/  hit=(list [id=@t row=json])  (skim ~(tap by rm) |=([* r=json] =(key (gs r 'key'))))
          ?~  hit  $
          ;<  c=calendar:cal  bind:m  (read-cal './')
          =/  id=@ta  (crip (trip id.i.hit))
          =/  u=@t  (gs jon 'uid')
          =/  local=(unit entry:cal)  (biff (~(get by cals.c) id) |=(k=cal:cal (~(get by entries.k) u)))
          ::  about an object we hold or the host had, or it is no edit of
          ::  ours: a host naming made-up UIDs would push real conflicts
          ::  out of the log
          =/  held  |=(f=@t !=('' (gs (obj:gcal row.i.hit f) u)))
          ?.  |(?=(^ local) (held 'pulled') (held 'etags') (~(has by (omap (obj:gcal row.i.hit 'sent'))) u))  $
          =/  why=@t  (crip "the host refused this edit: {(trip (end [3 512] (gs jon 'why')))}")
          ::  the object as we sent it, when the host says it: a pull may
          ::  have put the host's copy over ours before this notice came
          =/  sent=@t  =/(s (gs jon 'ics') ?:((gth (met 3 s) invite-max) '' s))
          ;<  ~  bind:m
            ?:  =('' sent)  (google-conflict './' id u local '' why)
            (conflict-row './' id u sent '' why)
          =/  k=(unit cal:cal)  (~(get by cals.c) id)
          ;<  ~  bind:m
            ?.  &(=('read' (gs jon 'mode')) ?=(^ k))  (pure:(fiber:fiber:nexus ,~) ~)
            ;<  ~  bind:(fiber:fiber:nexus ,~)
              (set-row './' 'ship-remotes.json' id.i.hit ~[['mode' s+'read']])
            (set-remote './' id `(crip "{(trip key)}#read"))
          ::  a pull now, so the host's copy replaces ours at once; a pull
          ::  is every backend's, so once a minute at most
          ?:  (lth now (add prodded ~m1))  $
          ;<  ~  bind:m  (google-prod './')
          $(prodded now)
        ?:  =('revoke' act)
          ;<  ~  bind:m  (write-json-grub './' 'share-offers.json' [%o (~(del by cur) key)])
          ::  an accepted calendar stays, with its data: it becomes a
          ::  local calendar of ours, the same flip migrate does
          ;<  rows=json  bind:m  (read-json-grub './' 'ship-remotes.json')
          =/  rm=(map @t json)  ?:(?=([%o *] rows) p.rows ~)
          =/  hit=(list [id=@t row=json])  (skim ~(tap by rm) |=([* r=json] =(key (gs r 'key'))))
          ?~  hit  $
          ;<  ~  bind:m  (write-json-grub './' 'ship-remotes.json' [%o (~(del by rm) id.i.hit)])
          ;<  c=calendar:cal  bind:m  (read-cal './')
          =/  k=(unit cal:cal)  (~(get by cals.c) id.i.hit)
          ?~  k  $
          =.  props.u.k  props.u.k(kind %local, remote ~)
          ;<  ~  bind:m  (dav-write './' c(cals (~(put by cals.c) id.i.hit u.k)))
          $
        $
          ::
          ::  /reminders.json: tick on utc 5-minute marks, push-notify
          ::  timed events starting lead_min ahead. fired_ms is the
          ::  watermark: everything due in (fired, now] goes out once.
          ::
          [~ %'reminders.json']
        ;<  ~  bind:m  (rise-later prod "calendar: the reminders fiber")
        |-
        ;<  now=@da  bind:m  get-time:io
        =/  tick=@da  (add (sub now (mod now ~m5)) ~m5)
        ;<  ~  bind:m  (wait:io tick)
        ;<  now=@da  bind:m  get-time:io
        ;<  st=json  bind:m  (get-state-as:io ,json)
        ::  lead_min 0: no heads-up, only the alarms events carry
        =/  lead-min=@ud  (fall (gn st 'lead_min') 30)
        =/  lead=@dr  (mul (max 1 lead-min) ~m1)
        =/  fired=@da
          =/  ms=(unit @ud)  (gn st 'fired_ms')
          ?~(ms *@da (ms-to-da u.ms))
        ::  cap lookback so a ship that slept doesn't spam stale
        ::  reminders on wake
        =/  floor=@da  (sub now ~m15)
        =/  from=@da  ?:((gth fired floor) fired floor)
        ;<  c=calendar:cal  bind:m  (read-cal './')
        ;<  ca=cache:cal  bind:m  (fresh-cache './' c (add now (add lead ~d31)))
        ::  the lead window goes on from where the last one ended
        ::  (thru_ms), so a longer lead skips no starts and a shorter
        ::  one sends none twice. Never more than a tick back: a start
        ::  missed while the ship slept has begun, and is past a heads-up,
        ::  while one on this tick's mark with a lead under a tick still
        ::  gets its "starting now"
        =/  hi=@da  (add now lead)
        =/  lo=@da
          =/  t=(unit @ud)  (gn st 'thru_ms')
          ?~(t (add from lead) :(max (ms-to-da u.t) from (sub now (min now ~m5))))
        ::  a lead just shortened leaves lo past hi: nothing is due yet
        =/  due=(list ref:cal)
          ?:  (gte lo hi)  ~
          %+  skim  ~(tap in (window:cal order.ca lo hi))
          |=  r=ref:cal
          &((gth l.span.r lo) (lte l.span.r hi))
        ;<  ~  bind:m  (send-pushes ?:(=(0 lead-min) ~ (lead-pushes due (keyed-events c) now)))
        ::  alarms: a relative one fires when its occurrence minus the
        ::  lead falls in (from, now]; an absolute one when its moment
        ::  does. Occurrences up to 31 days out are considered, the
        ::  ceiling for a relative lead, and back as far as the longest
        ::  alarm set after a start or an end: its occurrence is over
        ::  by the time it fires.
        ::  (a day more: an all-day event's alarm counts from local
        ::  midnight, hours past its naive end west of UTC)
        =/  back=@dr  (add ~d1 (late-reach c))
        =/  ahead=(list ref:cal)
          ~(tap in (window:cal order.ca (sub from (min back (sub from *@da))) (add now ~d31)))
        ;<  ~  bind:m  (send-pushes (alarm-pushes ahead (keyed c) from now zone.c))
        ::  read again: a send may have waited, and a lead set meanwhile
        ::  (+set-lead-min) stays
        ;<  st=json  bind:m  (get-state-as:io ,json)
        =/  new-st=json
          :-  %o
          %-  ~(gas by ?:(?=([%o *] st) p.st ~))
          :~  ['fired_ms' (numb:enjs:format (da-to-ms now))]
              ['thru_ms' (numb:enjs:format (da-to-ms (max hi lo)))]
          ==
        ;<  ~  bind:m  (replace:io new-st)
        $
          ::
          ::  /requests: window.json, events.json
          ::
          [[%requests ~] @]
        ::  a request that crashed is answered, not held: the kernel has
        ::  printed the trace, and a fiber waiting on a poke no one sends
        ::  would leave the browser hanging
        ?^  prod  (send-text name.rail 500 'calendar: the request failed')
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
          (send-text eyre-id 403 'Forbidden')
        ::  a change must come from this origin: the owner's cookie rides
        ::  along on a form any other site submits (eyre sets no
        ::  SameSite), and no route here wants one
        ?:  &(=('POST' method.request.req) (cross-site req))
          (send-text eyre-id 403 'calendar: cross-site request refused')
        ?:  ?=([%google *] suffix)
          (google-request eyre-id req our t.suffix args)
        ?:  ?=([%caldav *] suffix)
          (caldav-request eyre-id req t.suffix)
        ?:  ?=([%share *] suffix)
          (share-request eyre-id req our t.suffix)
        ?:  |(?=([%'invites.json' ~] suffix) ?=([%invites *] suffix))
          (invite-request eyre-id req suffix)
        ::  POST /migrate {id}: a followed, Google or shared calendar
        ::  becomes a local one: its sync row goes, one last pull, and the
        ::  remote ids come off the events. The source is never touched;
        ::  deleting it there is the user's own act.
        ?:  &(=('POST' method.request.req) ?=([%migrate ~] suffix))
          =/  jon=json
            (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          ;<  c=calendar:cal  bind:m  (read-cal '../')
          =/  k=(unit cal:cal)  (~(get by cals.c) id)
          ?~  k
            (send-text eyre-id 404 'calendar: no such calendar')
          =/  kind=?(%local %google %caldav %ship)  kind.props.u.k
          ?:  ?=(%local kind)
            (send-text eyre-id 400 'calendar: already local')
          ::  1. the sync row goes first, so no pass pulls or pushes it
          ::  again, not even one woken by the last pull's own write
          =/  file=@t  (sync-file kind)
          ;<  rows=json  bind:m  (read-json-grub '../' file)
          =/  row=(unit json)  (~(get by (omap rows)) id)
          ;<  ~  bind:m  (write-json-grub '../' file [%o (~(del by (omap rows)) id)])
          ::  2. one last pull, so nothing on the remote is missed
          ;<  ~  bind:m
            ?~  row  (pure:(fiber:fiber:nexus ,~) ~)
            ;<  *  bind:(fiber:fiber:nexus ,~)  (sync-pull kind '../' id u.row)
            (pure:(fiber:fiber:nexus ,~) ~)
          ::  3. the calendar is local now; the remote ids come off
          ;<  c=calendar:cal  bind:m  (read-cal '../')
          =/  k=cal:cal  (fall (~(get by cals.c) id) fresh-cal:cal)
          =.  props.k  props.k(kind %local, remote ~)
          =.  k  (roll ~(val by entries.k) |=([e=entry:cal acc=_k] (put-entry:cal acc (unhome e))))
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
            ?.  ?=([%o *] cfg)  cfg
            =/  sec=@t  (gs cfg 'client_secret')
            :-  %o
            %-  ~(put by p.cfg)
            ['client_secret' s+?:(=('' sec) '' '••••••••')]
          %+  send-json  eyre-id
          ?.  ?=([%o *] masked)  masked
          :-  %o
          %-  ~(gas by p.masked)
          ::  each link's Google id, last sync and error: the rest of a
          ::  row (its id map, its sync token) is no business of the page
          :~  ['connected' b+!=('' (gs auth 'refresh_token'))]
              :-  'linked'
              :-  %o
              %-  ~(run by (omap sync))
              |=  r=json
              %-  pairs:enjs:format
              :~  ['google_id' s+(gs r 'google_id')]
                  ['last_ms' (numb:enjs:format (fall (gn r 'last_ms') 0))]
                  ['error' s+(gs r 'error')]
              ==
          ==
        ::  /dav-clients.json, /dav-clients, /dav-clients/revoke: the owner
        ::  mints and revokes CalDAV client passwords. The password is
        ::  answered once and stored only as a salted hash.
        ?:  ?=([%'dav-clients.json' ~] suffix)
          ;<  clients=json  bind:m  dav-clients
          =/  rows=json
            :-  %a
            %+  turn  ?:(?=([%a *] clients) p.clients ~)
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
            (send-text eyre-id 400 'need a name')
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
          =/  new=json  [%a (snoc ?:(?=([%a *] clients) p.clients ~) row)]
          ;<  ~  bind:m  (write-json-grub '../' 'dav-clients.json' new)
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
            %+  skip  ?:(?=([%a *] clients) p.clients ~)
            |=(c=json =(id (gs c 'id')))
          ;<  ~  bind:m  (write-json-grub '../' 'dav-clients.json' new)
          (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
        ?:  ?=([%'window.json' ~] suffix)
          =/  from=(unit @da)  (ms-arg args 'from')
          =/  to=(unit @da)    (ms-arg args 'to')
          ?:  |(?=(~ from) ?=(~ to))
            (send-text eyre-id 400 'need from/to (unix ms)')
          ::  ponytail: a window is at most two years (the widest view is
          ::  a month); a wider one would walk every event that far
          ?:  (gth u.to (add u.from (mul 800 ~d1)))
            (send-text eyre-id 400 'calendar: a window is at most 800 days')
          ;<  c=calendar:cal  bind:m  (read-cal '../')
          ;<  ca=cache:cal  bind:m  (fresh-cache '../' c u.to)
          =/  refs=(list ref:cal)
            ~(tap in (window:cal order.ca u.from u.to))
          =/  ens=(map eid:cal entry:cal)  (keyed c)
          =/  evs=(map eid:cal event:cal)  (~(run by ens) |=(e=entry:cal event.e))
          =/  want=(unit @t)  (get-key:kv:html-utils 'tag' args)
          =/  rows=json
            :-  %a
            %+  murn  refs
            |=  r=ref:cal
            ^-  (unit json)
            =/  ev=(unit event:cal)  (~(get by evs) eid.r)
            ?~  ev  ~
            =/  en=(unit entry:cal)  (~(get by ens) eid.r)
            =/  als=(list alarm:cal)  ?~(en ~ alarms.u.en)
            ?.  ?~(want & ?=(^ (find ~[u.want] (meta-tags:cal (meta-of:cal u.ev)))))  ~
            =/  [cid=@ta u=uid:cal]  (unkey eid.r)
            :-  ~
            %-  pairs:enjs:format
            %+  weld
              ^-  (list [@t json])
              :~  ['id' s+u]
                  ['cal' s+cid]
                  ['idx' (numb:enjs:format idx.r)]
                  ['meta' [%o (meta-of:cal u.ev)]]
                  ['cat' s+-.u.ev]
                  ['kind' s+(ev-kind u.ev)]
                  ['all' b+(all-day:cal u.ev)]
                  ['done' b+?:(?=(%todo -.u.ev) ?=(^ done.u.ev) |)]
                  ['l' (numb:enjs:format (da-to-ms l.span.r))]
                  ['r' (numb:enjs:format (da-to-ms r.span.r))]
                  ['alarms' (alarms-json:cal als)]
              ==
            ^-  (list [@t json])
            ?.  ?=(%todo -.u.ev)  ~
            ~[['priority' (numb:enjs:format (meta-priority:cal (meta-of:cal u.ev)))]]
          =/  caps=json
            :-  %a
            %+  murn  ~(tap by stops.ca)
            |=  [id=@ta stop=@da]
            ^-  (unit json)
            =/  ev=(unit event:cal)  (~(get by evs) id)
            ?~  ev  ~
            :-  ~
            %-  pairs:enjs:format
            :~  ['id' s+uid:(unkey id)]
                ['meta' [%o (meta-of:cal u.ev)]]
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
          =/  home=@ta  (crip (trip (fall (get-key:kv:html-utils 'cal' args) '')))
          ;<  c=calendar:cal  bind:m  (read-cal '../')
          =/  got=(unit [cid=@ta e=entry:cal])  (locate c home id)
          ?~  got
            (send-text eyre-id 404 'No such event')
          =/  ev=event:cal  event.e.u.got
          =/  ej=json  (event-json:cal id ev)
          ?.  ?=([%o *] ej)  (send-json eyre-id ej)
          ::  count is how many occurrences, not index slots (+count-of);
          ::  before, with ?idx=, how many lie below that index, for a
          ::  "this and following" split to count the rest
          =/  rc=(unit [=recur:cal dom=(unit @ud)])
            ?+(-.ev ~ %timed `[recur.ev dom.bound.ev], %allday `[recur.ev dom.bound.ev])
          =/  idx=(unit @ud)  (biff (get-key:kv:html-utils 'idx' args) |=(t=@t (rush t dem)))
          =/  extra=(list [@t json])
            ?~  rc  ~
            ;:  weld
              ?~(dom.u.rc ~ ~[['count' (numb:enjs:format (fall (mole |.((count-of:ics recur.u.rc u.dom.u.rc))) u.dom.u.rc))]])
              ?~(idx ~ ~[['before' (numb:enjs:format (fall (mole |.((count-of:ics recur.u.rc u.idx))) u.idx))]])
            ==
          =/  more=(list [@t json])  ~[['cal' s+cid.u.got] ['alarms' (alarms-json:cal alarms.e.u.got)]]
          (send-json eyre-id [%o (~(gas by (~(gas by p.ej) more)) extra)])
        ::  /tags.json: every tag in use, with how many events carry it
        ?:  ?=([%'tags.json' ~] suffix)
          ;<  c=calendar:cal  bind:m  (read-cal '../')
          =/  counts=(map @t @ud)
            %+  roll  ~(tap by (keyed-events c))
            |=  [[* e=event:cal] acc=(map @t @ud)]
            %+  roll  (meta-tags:cal (meta-of:cal e))
            |=([t=@t a=_acc] (~(put by a) t +((fall (~(get by a) t) 0))))
          %+  send-json  eyre-id
          :-  %a
          %+  turn  (sort ~(tap by counts) |=([a=[@t @ud] b=[@t @ud]] (aor -.a -.b)))
          |=([t=@t n=@ud] (pairs:enjs:format ~[['tag' s+t] ['count' (numb:enjs:format n)]]))
        ::  /events.json: every entry, or only some: ?tag=, ?cat= (timed,
        ::  allday, date, todo) and ?from=&to= (unix ms; the entries with an
        ::  occurrence in that window, found through the index window.json
        ::  reads, so a client need not pull every event to show a month or
        ::  every task to show the tasks). An undated task is in no window.
        ?:  ?=([%'events.json' ~] suffix)
          =/  from=(unit @da)  (ms-arg args 'from')
          =/  to=(unit @da)    (ms-arg args 'to')
          ?:  ?|  !=(?=(~ from) ?=(~ to))
                  &(?=(^ from) ?=(^ to) (gth u.to (add u.from (mul 800 ~d1))))
              ==
            (send-text eyre-id 400 'calendar: from and to (unix ms) go together, at most 800 days apart')
          ;<  c=calendar:cal  bind:m  (read-cal '../')
          ;<  inside=(unit (set eid:cal))  bind:m
            =/  m  (fiber:fiber:nexus ,(unit (set eid:cal)))
            ?:  |(?=(~ from) ?=(~ to))  (pure:m ~)
            ;<  ca=cache:cal  bind:m  (fresh-cache '../' c u.to)
            (pure:m `(~(gas in *(set eid:cal)) (turn ~(tap in (window:cal order.ca u.from u.to)) |=(r=ref:cal eid.r))))
          =/  want=(unit @t)  (get-key:kv:html-utils 'tag' args)
          =/  kind=(unit @t)  (get-key:kv:html-utils 'cat' args)
          =/  rows=json
            :-  %a
            %+  turn
              %+  skim  ~(tap by (keyed c))
              |=  [key=eid:cal e=entry:cal]
              ?&  ?~(want & ?=(^ (find ~[u.want] (meta-tags:cal (meta-of:cal event.e)))))
                  ?~(kind & =(u.kind `@t`-.event.e))
                  ?~(inside & (~(has in u.inside) key))
              ==
            |=  [key=eid:cal e=entry:cal]
            ^-  json
            =/  [cid=@ta u=uid:cal]  (unkey key)
            %-  pairs:enjs:format
            %+  weld
              ^-  (list [@t json])
              :~  ['id' s+u]
                  ['cal' s+cid]
                  ['etag' s+etag.e]
                  ['meta' [%o (meta-of:cal event.e)]]
                  ['cat' s+-.event.e]
                  ['alarms' (alarms-json:cal alarms.e)]
              ==
            ^-  (list [@t json])
            ?.  ?=(%todo -.event.e)  ~
            :~  ['due_ms' ?~(due.event.e ~ (numb:enjs:format (da-to-ms u.due.event.e)))]
                ['done_ms' ?~(done.event.e ~ (numb:enjs:format (da-to-ms u.done.event.e)))]
                ['done' b+?=(^ done.event.e)]
                ['priority' (numb:enjs:format (meta-priority:cal (meta-of:cal event.e)))]
            ==
          (send-json eyre-id rows)
        ::  /outcomes.json: the last refused pokes with their reasons, and
        ::  the faults that stand with what clears them (docs/logging.md)
        ?:  ?=([%'outcomes.json' ~] suffix)
          ;<  out=json  bind:m  (read-json-grub '../' 'outcomes.json')
          =/  o=(map @t json)  ?:(?=([%o *] out) p.out ~)
          %+  send-json  eyre-id
          %-  pairs:enjs:format
          :~  ['refusals' (fall (~(get by o) 'refusals') [%a ~])]
              ['faults' (fall (~(get by o) 'faults') [%o ~])]
          ==
        ::  /feeds.json: the named external ICS feeds
        ?:  ?=([%'feeds.json' ~] suffix)
          ;<  feeds=json  bind:m  (read-json-grub '../' 'gcal-feeds.json')
          (send-json eyre-id ?:(?=([%o *] feeds) feeds [%o ~]))
        ::  /calendars.json: every calendar: id, props, seq, entry count,
        ::  and whether it takes edits here (a calendar shared with us
        ::  read-only does not; the page offers none)
        ?:  ?=([%'calendars.json' ~] suffix)
          ;<  c=calendar:cal  bind:m  (read-cal '../')
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
                ['readonly' b+(ship-read-only c id)]
            ==
          (send-json eyre-id rows)
        ::  export.ics[?cal=id]: every calendar, or one, as iCalendar.
        ?:  ?=([%'export.ics' ~] suffix)
          ;<  c=calendar:cal  bind:m  (read-cal '../')
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
        ::  sync-feeds: fetch the named ICS feeds and put their events in.
        ::  Here, in a request fiber, and not in the calendar's own: the
        ::  fetches take up to two minutes a feed. A feed that did not
        ::  answer or could not be read leaves its events as they were.
        ?:  &(=('POST' method.request.req) ?=([%'sync-feeds' ~] suffix))
          ;<  fj=json  bind:m  (read-json-grub '../' 'gcal-feeds.json')
          =/  feeds=(list [nm=@t url=@t])
            %+  murn  ~(tap by (omap fj))
            |=([k=@t v=json] ?.(?=([%s *] v) ~ `[k p.v]))
          ;<  now=@da  bind:m  get-time:io
          ;<  c0=calendar:cal  bind:m  (read-cal '../')
          ;<  res=feed-sync  bind:m
            (do-sync feeds (sub now (mul 90 ~d1)) (add now (mul 2 ~d365)) zone.c0)
          ;<  ~  bind:m  (edit-cals '../' (apply-feeds res))
          =/  failed=(list @t)  (murn feeds |=([nm=@t *] ?:((~(has in ok.res) nm) ~ `nm)))
          %+  send-json  eyre-id
          %-  pairs:enjs:format
          :~  ['synced' (numb:enjs:format ~(wyt by got.res))]
              ['skipped' (numb:enjs:format skipped.res)]
              ['failed' a+(turn failed |=(n=@t s+n))]
          ==
        ::  import?cal=id: an iCalendar body; each VEVENT becomes an entry
        ::  in that calendar (%default when unnamed), replacing one with the
        ::  same UID. Answers {imported, skipped}.
        ?:  ?=([%import ~] suffix)
          ?.  =('POST' method.request.req)
            (send-text eyre-id 405 'POST an .ics body')
          =/  body=@t  ?~(body.request.req '' q.u.body.request.req)
          =/  target=@ta  (fall (get-key:kv:html-utils 'cal' args) %default)
          ;<  now=@da  bind:m  get-time:io
          ;<  c=calendar:cal  bind:m  (read-cal '../')
          ::  a calendar this makes has a knot for its id, as add-calendar's
          ::  does: a / in it would split its keys and its share file's path
          ?:  &(!(~(has by cals.c) target) !((sane %ta) target))
            (send-text eyre-id 400 'calendar: a new calendar id is lowercase letters, digits, - . ~ _')
          ?:  (ship-read-only c target)
            (send-text eyre-id 403 'calendar: this calendar is shared with you read-only')
          =/  k=cal:cal  (fall (~(get by cals.c) target) (born now))
          =/  ves=(list vevent:ics)  ?:(=('' body) ~ (events:ics body))
          =/  res=[k=cal:cal imported=@ud skipped=@ud]
            ::  one object per UID: a parent and its overrides together,
            ::  gathered newest first and turned once (a snoc per VEVENT
            ::  was quadratic, and froze a ship on a big file)
            =/  groups=(map @t (list vevent:ics))
              %-  ~(run by (roll ves |=([ve=vevent:ics acc=(map @t (list vevent:ics))] ?:(=('' uid.ve) acc (~(put by acc) uid.ve [ve (fall (~(get by acc) uid.ve) ~)])))))
              flop
            %+  roll  ~(tap by groups)
            |=  [[u=@t group=(list vevent:ics)] acc=_[k=k imported=0 skipped=0]]
            ::  an object this side cannot read is skipped, not a crash
            =/  put=(unit [k=cal:cal =uid:cal])  (fall (mole |.((put-object k.acc group zone.c u ~))) ~)
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
        ::  /zones.json: every pytz zone name, for dropdowns
        ?:  ?=([%'zones.json' ~] suffix)
          %+  send-json  eyre-id
          [%a (turn zone-names:pytz |=(n=@t `json`s+n))]
        ::  /config.json: title, display zone, poke target for the client
        ?:  ?=([%'config.json' ~] suffix)
          ::  our own address, for the UI's poke url. grant.json is not a
          ::  stable source (the loader prunes it on a reload); the shell's
          ::  link registry is, and it is read through a granted road.
          ;<  base=(unit path)  bind:m  self-base
          =/  ball=tape
            ?~  base  ""
            =/  bt=tape  (spud u.base)
            ?:(?&(?=(^ bt) =('/' i.bt)) t.bt bt)
          ;<  c=calendar:cal  bind:m  (read-cal '../')
          ;<  rem=json  bind:m  (read-json-grub '../' 'reminders.json')
          =/  =json
            %-  pairs:enjs:format
            :~  ['title' s+title.c]
                ['zone' ?~(zone.c ~ s+u.zone.c)]
                ['horizon_days' (numb:enjs:format (div horizon.c ~d1))]
                ['ball' s+(crip ball)]
                ['ship' s+(scot %p our)]
                ['lead_min' (numb:enjs:format (fall (gn rem 'lead_min') 30))]
            ==
          (send-json eyre-id json)
        ::  static files, only these: the shell is the default, and the
        ::  other grubs here (the Google tokens, followed calendars'
        ::  passwords) are never answered to a browser
        =/  filename=@ta
          ?~  suffix  'calendar.html'
          i.suffix
        ?.  ?=(?(%'calendar.html' %'calendar.css' %'calendar.js' %'icon.svg') filename)
          (send-text eyre-id 404 'Not found')
        ;<  file-view=view:nexus  bind:m
          (peek:io (nex-road:io rail [%& / filename]) `[/ %mime])
        ?.  ?=([%file *] file-view)
          (send-text eyre-id 404 'Not found')
        =/  =mime  !<(mime (need-vase:tarball sang.file-view))
        (send-simple:srv eyre-id (mime-response:http-utils mime))
      ==
    --
|%
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::  +rise-later: a fiber that crashed goes on after a while by itself (a
::  %sig poke no one sends used to be the only way back). A crash that
::  comes again waits longer each time, 1, 2, 4 and up to 60 minutes (the
::  count starts over two quiet hours after the last), and only the first two
::  print their whole trace, so a fiber that crashes on the same data every
::  time neither floods the console nor keeps the ship busy. A poke that
::  comes while it waits is refused at once (a nack) rather than held:
::  held pokes hang whoever sent them, and grubbery offers every held one
::  again on each step, which is what locked a ship up.
::
::  rise-later itself never fails. grubbery restarts a failed fiber at
::  once, within the same event, so a failure in here would come straight
::  back to it: a weir that refuses /sys/behn (or /sys/bowl.sig) made every
::  fiber spin that way and locked ~feb on 2026-09-25. Its clock and timer
::  are soft, on fixed wires (a nonce is itself a bowl.sig poke); with
::  either refused it parks until a poke comes instead of setting a timer.
++  rise-later
  |=  [=prod:fiber:nexus msg=tape]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  the first step takes the start's own kick (~). A real input queued
  ::  ahead of it (a timer, news, a late answer, across a reload) used to
  ::  reach a step that only sends, which asserts it was kicked: a crash
  ::  on every reload, each one lengthening the wait below.
  ;<  ~  bind:m  take-kick
  ::  a clean start takes down any wait an earlier run left set: its wake
  ::  would come to a fiber no longer waiting for it
  ?~  prod
    ;<  *  bind:m  (soft-behn /rise/rest [[/ %timer-rest] `wire`/rise])
    (pure:m ~)
  =/  key=@t  (crip msg)
  ::  what a refused poke fails with; the restart that follows is not a crash
  =/  note=tang  ~[leaf+"{msg}: waiting after a crash; the poke was refused"]
  =/  crash=?  !=(note u.prod)
  ;<  clock=(unit @da)  bind:m  soft-now
  ::  no clock to time a retry by: /sys/bowl.sig is refused, and every
  ::  file read asks it for a nonce, so nothing can be counted either.
  ::  It parks until a poke comes; the kernel has printed the crash, and
  ::  its permits page shows the road
  ?~  clock  (rise-park note)
  =/  now=@da  u.clock
  ;<  log=json  bind:m  (read-json-grub './' 'rise.json')
  =/  row=json  (fall (~(get by (omap log)) key) [%o ~])
  ::  the count starts over only after a quiet spell longer than the
  ::  longest wait, so the waits stay at an hour, not back to a minute
  =/  n=@ud
    =/  was=@ud  (fall (gn row 'n') 0)
    ?.  crash  was
    ?:((gth now (add (ms-to-da (fall (gn row 'last_ms') 0)) ~h2)) 1 +(was))
  =/  until=@da
    ?.  crash  (ms-to-da (fall (gn row 'until_ms') 0))
    (add now (min ~h1 (mul ~m1 (bex (dec (min n 7))))))
  ?.  (gth until now)  (pure:m ~)
  ;<  ~  bind:m
    =/  m  (fiber:fiber:nexus ,~)
    ?.  crash  (pure:m ~)
    ::  counted here, not printed: the kernel prints every fiber crash
    ::  with its trace (%fiber-crash), and a second line would be one
    ::  cause said twice (docs/logging.md)
    ;<  *  bind:m
      %^  over-as-soft:io  (grub-road './' 'rise.json')
        :-  [/ %json]
        :-  %o
        %+  ~(put by (omap log))  key
        %-  pairs:enjs:format
        :~  ['n' (numb:enjs:format n)]
            ['last_ms' (numb:enjs:format (da-to-ms now))]
            ['until_ms' (numb:enjs:format (da-to-ms until))]
        ==
      [/ %json]
    (pure:m ~)
  ;<  set=?  bind:m
    (soft-behn /rise/set [[/ %timer-set] `[wire @da]`[/rise until]])
  (rise-park note)
::  +take-kick: wait for the null input that starts a fiber; anything
::  real before it is held for the steps that follow
++  take-kick
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?~(in [%done ~] [%skip ~])
::  +rise-park: wait for the /rise wake; a poke meanwhile is refused with
::  note (the restart it brings is not a crash, see +rise-later)
++  rise-park
  |=  note=tang
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%wait ~]
      [~ %poke * *]
    ?.  =([/ %timer-wake] p.sage.u.in)  [%fail note]
    ?.  ?=([%rise *] !<(path q.sage.u.in))  [%wait ~]
    [%done ~]
  ==
::  +soft-behn: a poke to the timer service, & when it landed. A refusal
::  (a weir without /sys/behn) is | rather than a failure. The wire is
::  fixed: a nonce would ask /sys/bowl.sig for entropy, refusable too.
++  soft-behn
  |=  [=wire =bask:tarball]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ~  bind:m
    (send-dart:io %node wire &+&+[/sys/behn %'main.behn-state'] %poke bask)
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]  [%done |]
      [~ %pack * *]
    ?.  =(wire wire.u.in)  [%skip ~]
    [%done =(~ err.u.in)]
  ==
::  +soft-now: the time, or ~ when /sys/bowl.sig refuses (+get-time:io
::  fails instead). The answer and its ack come in either order.
++  soft-now
  =/  m  (fiber:fiber:nexus ,(unit @da))
  ^-  form:m
  ;<  ~  bind:m
    (send-dart:io %node /rise/now &+&+[/sys %'bowl.sig'] %poke [[/ %bowl-req] %now])
  ;<  first=(unit (each @da ~))  bind:m
    =/  mi  (fiber:fiber:nexus ,(unit (each @da ~)))
    ^-  form:mi
    |=  input:fiber:nexus
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %veto *]  [%done ~]
        [~ %pack * *]  ?^(err.u.in [%done ~] [%done `[%| ~]])
        [~ %poke * *]
      ?.  =([/ %time] p.sage.u.in)  [%skip ~]
      [%done `[%& !<(@da q.sage.u.in)]]
    ==
  ?~  first  (pure:m ~)
  ?:  ?=(%| -.u.first)
    ::  acked: now the answer
    |=  input:fiber:nexus
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %poke * *]
      ?.  =([/ %time] p.sage.u.in)  [%skip ~]
      [%done `!<(@da q.sage.u.in)]
    ==
  ::  the answer first: take its ack
  ;<  ~  bind:m
    =/  md  (fiber:fiber:nexus ,~)
    ^-  form:md
    |=  input:fiber:nexus
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %pack *]  [%done ~]
    ==
  (pure:m `p.u.first)
::  +cal-of: a stored calendar view, or a fresh one when there is none.
::  The typed vase is taken as it is (cheap); an older shape is lifted.
::  One that is there but reads as neither is a crash, not an empty
::  calendar: the next write would put the empty one over it.
++  cal-of
  |=  vw=view:nexus
  ^-  calendar:cal
  ?.  ?=([%file *] vw)  fresh-calendar:cal
  %+  fall  (mole |.(!<(calendar:cal (need-vase:tarball sang.vw))))
  (lift:cal (sang-noun:tarball sang.vw))
++  born  born:core
++  kind-is  kind-is:core
::  +drop-synced: unlink or unfollow: the calendar and its sync row go.
::  Only a calendar of that kind; never %default, never a local one.
++  drop-synced
  |=  [eyre-id=@ta id=@ta kind=?(%google %caldav) why=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  c=calendar:cal  bind:m  (read-cal '../')
  ?.  (kind-is c id kind)  (send-text eyre-id 404 why)
  ;<  ~  bind:m  (dav-write '../' c(cals (~(del by cals.c) id)))
  ;<  rows=json  bind:m  (read-json-grub '../' (sync-file kind))
  ;<  ~  bind:m  (write-json-grub '../' (sync-file kind) [%o (~(del by (omap rows)) id)])
  (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
::  +read-cache: the derived occurrence index, or an empty one
++  read-cache
  |=  pre=@t
  =/  m  (fiber:fiber:nexus ,cache:cal)
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io (grub-road pre 'index.calendar-cache') ~)
  ?.  ?=([%file *] vw)  (pure:m *cache:cal)
  (pure:m (fall (mole |.(!<(cache:cal (need-vase:tarball sang.vw)))) *cache:cal))
::  +inflate-all: every event's occurrences through thru, as the cache
++  inflate-all
  |=  [c=calendar:cal thru=@da]
  ^-  cache:cal
  (inflate-all:core c kind-for thru)
::  +fresh-cache: the cache, rebuilt and kept first when it is behind: built
::  from an older calendar (a write its fiber has not caught up with),
::  short of to, or with under half the horizon left
++  fresh-cache
  |=  [pre=@t c=calendar:cal to=@da]
  =/  m  (fiber:fiber:nexus ,cache:cal)
  ^-  form:m
  ;<  ca=cache:cal  bind:m  (read-cache pre)
  ;<  have=@uv  bind:m  (read-cache-ver pre)
  ;<  now=@da  bind:m  get-time:io
  ::  no further than max-reach: a far to (a client's bad from, a stored
  ::  horizon from before it was capped) would walk every event that far
  =.  to  (min to (add now max-reach))
  =.  horizon.c  (min horizon.c max-reach)
  ?.  ?|  !=(have (cache-ver:cal c))
          (gth to thru.ca)
          (lth thru.ca (add now (div horizon.c 2)))
      ==
    (pure:m ca)
  ::  built whole: the fiber keeps the per-event index that would let
  ::  this move only the changed events, and it is almost always ahead
  ::  of a request (its refresh runs in the write's own event)
  ::  past to by a week: a caller asking a little further each time (the
  ::  reminders fiber, every tick) would otherwise rebuild every time
  =/  new=cache:cal  (inflate-all c (max (add now horizon.c) (add to ~d7)))
  ::  the cache first, then what it is current for: a reload between the
  ::  two leaves a version that says stale, never one that says current
  ;<  ~  bind:m  (over:io (grub-road pre 'index.calendar-cache') [[/ %calendar-cache] new])
  ;<  ~  bind:m  (over:io (grub-road pre 'order.calendar-cache') [[/ %calendar-cache] (by-uid new)])
  ;<  ~  bind:m  (write-cache-ver pre (cache-ver:cal c))
  (pure:m new)
++  max-reach  max-reach:core
++  by-uid  by-uid:core
::  +read-cache-ver, +write-cache-ver: order-ver.json, the calendar the
::  cache was built from (0 when unknown, which is never current)
++  read-cache-ver
  |=  pre=@t
  =/  m  (fiber:fiber:nexus ,@uv)
  ^-  form:m
  ;<  j=json  bind:m  (read-json-grub pre 'order-ver.json')
  (pure:m (fall (slaw %uv (gs j 'ver')) 0v0))
++  write-cache-ver
  |=  [pre=@t ver=@uv]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (write-json-grub pre 'order-ver.json' (pairs:enjs:format ~[['ver' s+(scot %uv ver)]]))
::  +read-cal: the calendar grub, from any fiber depth
++  read-cal
  |=  pre=@t
  =/  m  (fiber:fiber:nexus ,calendar:cal)
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io (grub-road pre 'calendar.calendar') ~)
  (pure:m (cal-of vw))
++  put-ev  put-ev:core
++  put-ev-in  put-ev-in:core
++  target-of  target-of:core
++  late-reach  late-reach:core
++  unhome  unhome:core
++  cal-arg  cal-arg:core
++  del-ev  del-ev:core
++  del-object  del-object:core
::  +self-base: where this instance lives, from the shell's link registry
::  (/sys/link/calendar/dest.lanes: every instance claiming the name,
::  ours among them). ~ when the road is refused or the
::  registry has no row yet.
++  self-base
  =/  m  (fiber:fiber:nexus ,(unit path))
  ^-  form:m
  ;<  vw=(unit view:nexus)  bind:m
    (peek-soft:io [%& %& /sys/link/calendar %'dest.lanes'] ~)
  ?.  ?=([~ %file *] vw)  (pure:m ~)
  ::  an ordered list (earliest claimant first) on a kernel from
  ::  develop's line, a set on the older one: read either, so this
  ::  instance finds itself on both
  =/  ls=(unit (list lane:tarball))
    =/  l  (mole |.(!<((list lane:tarball) (need-vase:tarball sang.u.vw))))
    ?^  l  l
    %+  bind  (mole |.(!<((set lane:tarball) (need-vase:tarball sang.u.vw))))
    |=(s=(set lane:tarball) ~(tap in s))
  ?~  ls  (pure:m ~)
  =/  dirs=(list path)
    %+  murn  u.ls
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
  (moments-of ev ?-(-.ev %timed except.bound.ev, %allday except.bound.ev))
::  +moments-of: occurrence indices of an event as naive moments
++  moments-of
  |=  [ev=event:cal ex=(set @ud)]
  ^-  (list @da)
  ?:  ?=(?(%date %todo) -.ev)  ~
  =/  rc=recur:cal  recur.ev
  =/  k=(unit kind:rules)  (kind-for kind.rc)
  ?~  k  ~
  %+  murn  (sort ~(tap in ex) lth)
  |=(idx=@ud (fall (mole |.((u.k args.rc start.rc idx))) ~))
::  +object-exdates: the skips an export writes as EXDATE: not the ones an
::  override child stands in for, whose RECURRENCE-ID says it already (an
::  EXDATE too would cancel the instance a client moved)
++  object-exdates
  |=  [e=entry:cal kids=(list entry:cal)]
  ^-  (list @da)
  =/  moved=(set @da)
    %-  ~(gas in *(set @da))
    (murn kids |=(ch=entry:cal (props-rid-moment props.ch event.e)))
  (skip (exdates-of e) |=(d=@da (~(has in moved) d)))
::  +anchored: an entry as it goes out. A rule whose start is not an
::  occurrence (a monthly one counted from the first of its month, say)
::  starts at its first occurrence instead, so DTSTART is a real instance
::  and a client adds no stray one. The bound is the one that holds as
::  many occurrences from the new start as the old one held, so it ends
::  where it did (counting down by the indices skipped is wrong when a
::  dead slot comes first and the start does not move).
++  anchored
  |=  e=entry:cal
  ^-  entry:cal
  =/  ev=event:cal  event.e
  ?:  ?=(?(%date %todo) -.ev)  e
  ?.  =(%rrule name.kind.recur.ev)  e
  =/  k=(unit kind:rules)  (kind-for kind.recur.ev)
  ?~  k  e
  =/  first=(unit [idx=@ud at=@da])
    =/  idx=@ud  0
    |-  ^-  (unit [@ud @da])
    ?:  (gth idx max-dead:cal)  ~
    =/  at=(unit @da)  (fall (mole |.((u.k args.recur.ev start.recur.ev idx))) ~)
    ?^  at  `[idx u.at]
    $(idx +(idx))
  ?~  first  e
  =/  rc2=recur:cal  recur.ev(start at.u.first)
  ::  the first index live: the indices line up, and the bound stands
  =/  down
    |=  d=@ud
    ^-  @ud
    ?:  =(0 idx.u.first)  d
    (dom-of:ics rc2 (count-of:ics recur.ev d))
  ?-  -.ev
    %timed   e(event ev(start.recur at.u.first, dom.bound (bind dom.bound.ev down)))
    %allday  e(event ev(start.recur at.u.first, dom.bound (bind dom.bound.ev down)))
  ==
::  +match-indices: the indices of an event's rule whose moments, keyed,
::  are wanted. Walks forward, bounded, and stops once past the last
::  wanted key; a key the rule never produces is dropped.
++  match-indices
  |=  [ev=event:cal want=(set @da) key=$-(@da @da)]
  ^-  (set @ud)
  ?:  ?=(?(%date %todo) -.ev)  ~
  =/  rc=recur:cal  recur.ev
  =/  k=(unit kind:rules)  (kind-for kind.rc)
  ?~  k  ~
  =/  hi=@da  (roll ~(tap in want) max)
  =|  got=(set @ud)
  =/  idx=@ud  0
  =/  dead=@ud  0
  |-
  ?:  |(=(~ want) (gth dead max-dead:cal) (gth idx max-live:cal))  got
  =/  m=(unit @da)  (fall (mole |.((u.k args.rc start.rc idx))) ~)
  ?~  m  $(idx +(idx), dead +(dead))
  =/  at=@da  (key u.m)
  ?:  (gth at hi)  got
  ?.  (~(has in want) at)  $(idx +(idx), dead 0)
  $(idx +(idx), dead 0, got (~(put in got) idx), want (~(del in want) at))
++  skips-of  skips-of:core
++  set-skips  set-skips:core
++  add-skips  add-skips:core
::  +with-exdates: EXDATE moments back to indices of the entry's kind
++  with-exdates
  |=  [e=entry:cal exdates=(list @da)]
  ^-  entry:cal
  ?~  exdates  e
  e(event (add-skips event.e (match-indices event.e (sy exdates) |=(d=@da d))))
::  +carry-skips: an edited event keeps its skipped occurrences. The same
::  clock keeps the same indices; a changed one (a day added, the start
::  moved, the time changed) finds each skip again by the day it fell
::  on, so the edit hides the same days, not whatever the old indices
::  would name now.
++  carry-skips
  |=  [old=event:cal new=event:cal]
  ^-  event:cal
  ?:  |(?=(?(%date %todo) -.old) ?=(?(%date %todo) -.new))  new
  =/  ex=(set @ud)  ?-(-.old %timed except.bound.old, %allday except.bound.old)
  ?:  =(~ ex)  new
  ?:  =(recur.old recur.new)  (add-skips new ex)
  =/  day  |=(d=@da ^-(@da (day-floor:rules d)))
  =/  days=(set @da)  (~(gas in *(set @da)) (turn (moments-of old ex) day))
  (add-skips new (match-indices new days day))
::  ---- CalDAV ----
::  +dav-clients: the minted client passwords, hashed
++  dav-clients  (read-json-grub '../' 'dav-clients.json')
++  dav-password  dav-password:core
++  dav-hash  dav-hash:core
++  dav-verb  dav-verb:core
++  dav-authed  dav-authed:core
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
    (send-text eyre-id 405 'calendar: unknown DAV verb')
  ::  the resource: principal, home, a calendar, or an object
  =/  body=@t  ?~(body.request.req '' q.u.body.request.req)
  =/  res=dav-res  (dav-resolve rest)
  ;<  c=calendar:cal  bind:m  (read-cal '../')
  ?:  =('PROPFIND' verb)
    (dav-propfind eyre-id req our c res body)
  ?:  ?=(?(%'GET' %'HEAD') verb)
    (dav-get eyre-id c res)
  ?:  =('REPORT' verb)
    (dav-report eyre-id req our c res body)
  ?:  =('PUT' verb)
    (dav-put eyre-id req c res body)
  ?:  =('DELETE' verb)
    (dav-delete eyre-id req c res)
  ?:  =('MKCALENDAR' verb)
    (dav-mkcalendar eyre-id c res body)
  ?:  =('PROPPATCH' verb)
    (dav-proppatch eyre-id c res body)
  (send-text eyre-id 501 'calendar: not yet')
::  +edit-cals: the calendar changed by f, read and written with no wait
::  between. Every writer that is not the calendar's own fiber keeps that
::  shape (its waits before the read, or after the write): one that read
::  the calendar, waited on the network, the clock or another file, and
::  wrote back what it read would undo whatever was written meanwhile,
::  an event poked into any calendar included.
++  edit-cals
  |=  [pre=@t f=$-(calendar:cal calendar:cal)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  c=calendar:cal  bind:m  (read-cal pre)
  =/  new=calendar:cal  (f c)
  ?:  =(new c)  (pure:m ~)
  (dav-write pre new)
::  +set-remote: one calendar's remote string (+edit-cals)
++  set-remote
  |=  [pre=@t id=@ta r=(unit @t)]
  %+  edit-cals  pre
  |=  c=calendar:cal
  =/  k=(unit cal:cal)  (~(get by cals.c) id)
  ?~(k c c(cals (~(put by cals.c) id u.k(remote.props r))))
::  +dav-write: the calendar back to its grub
++  dav-write
  |=  [pre=@t c=calendar:cal]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (over:io (grub-road pre 'calendar.calendar') [[/ %calendar] c])
++  dav-rid  dav-rid:core
::  +dav-put: create or replace one object. The VEVENT without a
::  RECURRENCE-ID is the parent; each other becomes an override child
::  (uid <parent>#<recurrence-id>, once, at its own time) and the parent
::  skips that occurrence. A PUT replaces the whole override set.
++  dav-put
  |=  [eyre-id=@ta req=inbound-request:eyre c=calendar:cal res=dav-res body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=(%object -.res)  (send-text eyre-id 405 'calendar: PUT an object')
  =/  k=(unit cal:cal)  (~(get by cals.c) id.res)
  ?~  k  (send-text eyre-id 404 'calendar: no such calendar')
  ?:  (ship-read-only c id.res)  (send-text eyre-id 403 'calendar: this calendar is shared with you read-only')
  ::  a body that cannot be read is a 400, never a crash (a crashed
  ::  request fiber leaves the client hanging)
  =/  ves=(list vevent:ics)  (fall (mole |.((events:ics body))) ~)
  ?~  ves  (send-text eyre-id 400 'calendar: no VEVENT or VTODO in the body')
  =/  parent=(unit vevent:ics)  (lead-of ves)
  ?~  parent  (send-text eyre-id 400 'calendar: no VEVENT or VTODO in the body')
  ::  the object lives at the name the client PUT it to (+alias-object);
  ::  its own UID must not be another object's here
  =/  u=uid:cal  uid.res
  =/  aliased=[ves=(list vevent:ics) extra=(list [@t @t])]  (alias-object ves u)
  ::  (under its own name, or kept aside under another's, X-GRUBBERY-UID),
  ::  and an object keeps its UID (RFC 4791 5.3.2.1)
  =/  new-uid=@t  ?:(=('' uid.u.parent) u uid.u.parent)
  =/  own-uid
    |=  [key=@t e=entry:cal]
    ^-  @t
    =/  p=(unit prop:ics)  (get-prop:ics props.e 'X-GRUBBERY-UID')
    ?~(p key v.u.p)
  =/  existing=(unit entry:cal)  (~(get by entries.u.k) u)
  =/  hs  header-list.request.req
  =/  if-none=(unit @t)  (get-header:http 'if-none-match' hs)
  =/  if-match=(unit @t)  (get-header:http 'if-match' hs)
  ?:  &(?=(^ if-none) =('*' u.if-none) ?=(^ existing))
    (send-text eyre-id 412 'calendar: an object with this UID exists')
  ::  If-Match: * asks only that the object exist
  ?:  ?&  ?=(^ if-match)
          ?|  ?=(~ existing)
              &(!=('*' u.if-match) !=(etag.u.existing (dav-unquote u.if-match)))
          ==
      ==
    (send-text eyre-id 412 'calendar: the object changed; fetch it again')
  ::  after the preconditions: a client editing a stale copy hears 412,
  ::  and fetches again
  ?:  (lien ~(tap by entries.u.k) |=([key=@t e=entry:cal] &(!=(key u) !(dav-is-child e) =(new-uid (own-uid key e)))))
    (send-text eyre-id 403 'calendar: another object here has this UID (no-uid-conflict)')
  ?:  &(?=(^ existing) !(dav-is-child u.existing) !=(new-uid (own-uid u u.existing)))
    (send-text eyre-id 403 'calendar: a PUT cannot change an object\'s UID (no-uid-conflict)')
  =/  put=(unit [k=cal:cal =uid:cal])
    (fall (mole |.((put-object u.k ves.aliased zone.c u extra.aliased))) ~)
  ?~  put  (send-text eyre-id 400 'calendar: could not read the VEVENT')
  =/  kk=cal:cal  k.u.put
  ;<  ~  bind:m  (dav-write '../' c(cals (~(put by cals.c) id.res kk)))
  =/  new-etag=@t
    =/  ne=(unit entry:cal)  (~(get by entries.kk) u)
    ?~(ne '' etag.u.ne)
  ;<  ~  bind:m
    %+  send-simple:srv  eyre-id
    :_  ~
    :~  ?~(existing 201 204)
        ['etag' (crip "\"{(trip new-etag)}\"")]
    ==
  (pure:m ~)
++  lead-of  lead-of:core
++  alias-object  alias-object:core
::  +put-object: one iCalendar object's VEVENTs into a calendar: the one
::  without a RECURRENCE-ID is the parent, the others its overrides, and
::  the old override set goes. ~ when there is no parent or it cannot
::  be read. Import, DAV PUT and the follower all come through here.
++  put-object
  |=  [k=cal:cal ves=(list vevent:ics) zone=(unit @t) uid-hint=@t extra=(list [@t @t])]
  ^-  (unit [k=cal:cal =uid:cal])
  ::  an object of overrides alone is kept by its first (+lead-of): a
  ::  single event, its RECURRENCE-ID riding in props so it goes back out
  ::  as it came
  =/  lead=(unit vevent:ics)  (lead-of ves)
  ?~  lead  ~
  ::  ponytail: a recurring task's instance overrides are dropped (a
  ::  task is one item here); keep them when tasks get a series view
  =/  overrides=(list vevent:ics)
    %+  skim  `(list vevent:ics)`ves
    |=(v=vevent:ics &(?=(^ (dav-rid v)) !=('todo' cat.v) !=(v u.lead)))
  =/  u=@t  ?:(=('' uid.u.lead) uid-hint uid.u.lead)
  =/  par=(unit entry:cal)  (~(get by entries.k) u)
  ::  the children are a walk of the whole calendar, so it is taken once
  ::  per object, and not at all for a new one: a parent goes with its
  ::  children (+del-object), so one not here has none. A Google pull
  ::  puts an instance before its series may have come, so a Google
  ::  calendar is walked anyway (once per object made an import
  ::  quadratic: 1,400 objects cost 5 s)
  =/  kids=(list entry:cal)
    ?:  &(?=(~ par) !?=(%google kind.props.k))  ~
    (kids-of:cal k u)
  =/  before=(map uid:cal etag:cal)
    ?~  par  ~
    (~(gas by *(map uid:cal etag:cal)) (turn [u.par kids] |=(x=entry:cal [uid.x etag.x])))
  ::  children the new set no longer carries go; the rest are re-put
  ::  in place (an identical one is left alone)
  =/  keep=(set @t)
    %-  ~(gas in *(set @t))
    %+  murn  overrides
    |=  v=vevent:ics
    =/  rid=(unit [key=@t val=@t])  (dav-rid v)
    ?~(rid ~ `(crip "{(trip u)}#{(trip val.u.rid)}"))
  =.  k
    %+  roll  kids
    |=([ch=entry:cal acc=_k] ?:((~(has in keep) uid.ch) acc (del-entry:cal acc uid.ch)))
  =/  put=(unit [k=cal:cal =uid:cal])  (put-parent k u.lead zone u extra |)
  ?~  put  ~
  =/  kk=cal:cal  (put-overrides k.u.put uid.u.put overrides zone extra)
  ::  the same object again is no change: the parent's skips come off and
  ::  back on along the way, and those writes are not a change to log.
  ::  A new one always is; one with no overrides now has no children
  ?~  before  `[kk uid.u.put]
  =/  after=(map uid:cal etag:cal)
    ?^  overrides  (object-etags kk uid.u.put)
    =/  p=(unit entry:cal)  (~(get by entries.kk) uid.u.put)
    ?~(p ~ (malt ~[[uid.u.put etag.u.p]]))
  ?:  =(before after)  `[k uid.u.put]
  `[kk uid.u.put]
++  object-etags  object-etags:core
::  +put-parent: a parent VEVENT into a calendar. An existing entry
::  keeps its identity (seq); the file's EXDATEs become skips. Extra
::  props (a Google id, say) ride along. ~ when the VEVENT cannot be read.
::  keep=& carries the stored parent's skips forward (an incremental
::  update of the parent alone); keep=| rebuilds them from the object
::  (the overrides that follow re-add their own).
++  put-parent
  |=  [k=cal:cal ve=vevent:ics zone=(unit @t) uid-hint=@t extra=(list [@t @t]) keep=?]
  ^-  (unit [k=cal:cal =uid:cal])
  =/  got=(unit [e=entry:cal exdates=(list @da)])  (to-entry:ics ve zone)
  ?~  got  ~
  =/  e=entry:cal  e.u.got
  =?  uid.e  =('' uid.e)  uid-hint
  =/  existing=(unit entry:cal)  (~(get by entries.k) uid.e)
  =?  e  ?=(^ existing)  e(seq seq.u.existing, event (keep-meta event.u.existing event.e))
  ::  an object kept under another name than its UID stays so on a
  ::  Google pull of it (keep), which names no alias
  =/  alias=(unit [@t @t])
    ?~  existing  ~
    ?.  keep  ~
    ?:  (lien extra |=([k=@t *] =('X-GRUBBERY-UID' k)))  ~
    (get-prop:ics props.u.existing 'X-GRUBBERY-UID')
  =?  extra  ?=(^ alias)  [u.alias extra]
  =.  props.e  (with-extra props.e (google-carry k existing extra))
  =.  e  (with-exdates e exdates.u.got)
  ::  a Google pull reads only the reminders Google holds (minutes
  ::  before): an alarm Google cannot hold (at a moment, after the
  ::  start, from the end) was set here, and stays
  =?  alarms.e  &(keep ?=(^ existing))
    (weld alarms.e (skip alarms.u.existing |=(a=alarm:cal ?=(%rel -.trigger.a))))
  ::  the parent's existing skips survive a re-put (an override's moment
  ::  stays skipped when only the parent changed), found again by day if
  ::  its rule changed
  =?  event.e  &(keep ?=(^ existing))  (carry-skips event.u.existing event.e)
  `[(put-entry:cal k e) uid.e]
++  with-extra  with-extra:core
++  google-carry  google-carry:core
++  keep-meta  keep-meta:core
++  props-rid-moment  props-rid-moment:core
::  +put-override: an exception instance as a child of its parent: the
::  parent skips that occurrence, the child (a once event at its own
::  time, tagged) replaces any older child with the same RECURRENCE-ID.
++  put-override
  |=  [k=cal:cal parent=uid:cal ve=vevent:ics zone=(unit @t) extra=(list [@t @t])]
  ^-  cal:cal
  (put-overrides k parent ~[ve] zone extra)
::  +put-overrides: many exception instances of one parent at once. The
::  parent's skips are found in one walk of its rule and its kids stamp
::  taken once, at the end: per override, both were a walk and a scan of
::  every entry, and a series with 2000 overrides held a ship for minutes.
++  put-overrides
  |=  [k=cal:cal parent=uid:cal ves=(list vevent:ics) zone=(unit @t) extra=(list [@t @t])]
  ^-  cal:cal
  ::  a child keeps what the file has no word for, as its parent does
  ::  (+keep-meta), and an invitation's copy (meta host) is the host's in
  ::  every instance: none sends guests to Google
  =/  host=(unit json)
    (biff (~(get by entries.k) parent) |=(p=entry:cal (~(get by (meta-of:cal event.p)) 'host')))
  =/  chs=(list [ve=vevent:ics ch=entry:cal])
    %+  murn  ves
    |=  ve=vevent:ics
    ^-  (unit [ve=vevent:ics ch=entry:cal])
    =/  rid=(unit [key=@t val=@t])  (dav-rid ve)
    ?~  rid  ~
    =/  cg=(unit [e=entry:cal exdates=(list @da)])  (to-entry:ics ve zone)
    ?~  cg  ~
    =/  ch=entry:cal  e.u.cg
    =.  uid.ch  (crip "{(trip parent)}#{(trip val.u.rid)}")
    =/  was=(unit entry:cal)  (~(get by entries.k) uid.ch)
    =.  props.ch  [['X-GRUBBERY-PARENT' parent] (with-extra props.ch (google-carry k was extra))]
    =?  event.ch  ?=(^ was)  (keep-meta event.u.was event.ch)
    =?  event.ch  ?=(^ host)  (put-meta:cal event.ch (~(put by (meta-of:cal event.ch)) 'host' u.host))
    `[ve ch]
  ?~  chs  k
  ::  a child for the same moment under another RECURRENCE-ID form (Z
  ::  against TZID=UTC, one zone against another) is the same instance:
  ::  it goes, so the moved one is not there twice. Moments compare as
  ::  instants in the series' zone: in a spring-forward gap one side
  ::  names the rule's 02:30 and the other the clock's 03:30
  =/  pe=(unit entry:cal)  (~(get by entries.k) parent)
  =.  k
    ?~  pe  k
    =/  z=(unit @t)  ?.(?=(%timed -.event.u.pe) ~ zone.event.u.pe)
    =/  instant
      |=  m=(unit @da)
      ^-  (unit @da)
      ?~  m  ~
      ?~  z  m
      `(fall (place:rules z u.m) u.m)
    ::  each old child's instant once, not once per new child
    =/  olds=(list [=uid:cal at=(unit @da)])
      %+  turn  (kids-of:cal k parent)
      |=(o=entry:cal [uid.o (instant (props-rid-moment props.o event.u.pe))])
    %+  roll  `(list [ve=vevent:ics ch=entry:cal])`chs
    |=  [[* ch=entry:cal] acc=_k]
    =/  mo=(unit @da)  (instant (props-rid-moment props.ch event.u.pe))
    ?~  mo  acc
    %+  roll  olds
    |=  [o=[=uid:cal at=(unit @da)] a2=_acc]
    ?:  =(uid.o uid.ch)  a2
    ?.  =(mo at.o)  a2
    (del-entry:cal a2 uid.o)
  =.  k  (skip-instances k parent (turn chs |=([ve=vevent:ics *] extra.ve)))
  ::  a cancelled instance (STATUS:CANCELLED) is the skip alone
  =.  k
    ::  cast back: ?~ narrowed chs, and roll is wet
    %+  roll  `(list [ve=vevent:ics ch=entry:cal])`chs
    |=  [[* ch=entry:cal] acc=_k]
    ?:((cancelled ch) (del-entry:cal acc uid.ch) (put-one:cal acc ch))
  (restamp:cal k `parent)
::  +put-child: "only this one" from a poke: the occurrence of series id
::  that starts at `at` (the instant, as skip-at and the window name it)
::  becomes an override child with the shape ev, and the series skips
::  it, as a client's RECURRENCE-ID would have it. So it stays the
::  series' instance everywhere: in CalDAV objects, and on Google as an
::  edit of that instance, guests and all. Alarms absent are the
::  series'. ~ when the series is not found, does not repeat, or has no
::  occurrence at `at` (one already moved has none: its child is edited
::  as itself).
++  put-child
  |=  [c=calendar:cal home=@ta id=@ta at=@da ev=event:cal als=(unit (list alarm:cal))]
  ^-  (unit calendar:cal)
  =/  got=(unit [cid=@ta e=entry:cal])  (locate c home id)
  ?~  got  ~
  =/  pe=entry:cal  e.u.got
  ?.  ?=(?(%timed %allday) -.event.pe)  ~
  =/  idx=(unit @ud)  (occurrence-index event.pe at)
  ?~  idx  ~
  ::  its RECURRENCE-ID: the series' own wall clock in its zone, as the
  ::  rule makes it (in a spring-forward gap the clock reads an hour on,
  ::  and the skip would not match)
  =/  kd=(unit kind:rules)  (kind-for kind.recur.event.pe)
  =/  naive=(unit @da)
    ?~  kd  ~
    (fall (mole |.((u.kd args.recur.event.pe start.recur.event.pe u.idx))) ~)
  =/  w=when:ics
    ?:  ?=(%allday -.event.pe)  [%day at]
    ?~  zone.event.pe  [%utc at]
    [%local u.zone.event.pe (fall naive (wall:rules zone.event.pe at))]
  =/  [ps=tape v=tape]  (when-text:ics w)
  =/  rid=[@t @t]  [(crip (weld "RECURRENCE-ID" ps)) (crip v)]
  =/  k=cal:cal  (~(got by cals.c) cid.u.got)
  =/  cu=uid:cal  (crip "{(trip uid.pe)}#{v}")
  ::  no child is here for it: an occurrence already moved is skipped, and
  ::  occurrence-index above names none (the child is edited as itself)
  =/  ch=entry:cal
    :*  ev  cu  ''  0
        (fall als alarms.pe)
        ~[['X-GRUBBERY-PARENT' uid.pe] rid]
    ==
  =.  k  (skip-instances k uid.pe ~[~[rid]])
  =.  k  (restamp:cal (put-one:cal k ch) `uid.pe)
  `c(cals (~(put by cals.c) cid.u.got k))
::  +skip-instance: the parent skips one occurrence (a cancelled or
::  overridden instance), the one the RECURRENCE-ID in props names
++  skip-instance
  |=  [k=cal:cal parent=uid:cal props=(list [k=@t v=@t])]
  ^-  cal:cal
  (skip-instances k parent ~[props])
::  +skip-instances: the parent skips every occurrence these RECURRENCE-IDs
::  name, found in one walk of its rule
++  skip-instances
  |=  [k=cal:cal parent=uid:cal rids=(list (list [k=@t v=@t]))]
  ^-  cal:cal
  =/  pe=(unit entry:cal)  (~(get by entries.k) parent)
  ?~  pe  k
  =/  moments=(list @da)  (murn rids |=(p=(list [k=@t v=@t]) (props-rid-moment p event.u.pe)))
  ?~  moments  k
  (put-entry:cal k (with-exdates u.pe moments))
::  +reskip: every override's parent skips its instance, the moment read
::  from the child's RECURRENCE-ID. A child that arrived before its
::  parent (on a later page) left no skip; this places it.
++  reskip
  |=  k=cal:cal
  ^-  cal:cal
  ::  each parent once, with all its children's instances
  =/  kids=(map uid:cal (list (list [k=@t v=@t])))
    %+  roll  ~(tap by entries.k)
    |=  [[* e=entry:cal] acc=(map uid:cal (list (list [k=@t v=@t])))]
    =/  par=(unit uid:cal)  (parent-of:cal e)
    ?~  par  acc
    (~(put by acc) u.par [props.e (fall (~(get by acc) u.par) ~)])
  %+  roll  ~(tap by kids)
  |=  [[p=uid:cal rs=(list (list [k=@t v=@t]))] acc=_k]
  (skip-instances acc p rs)
++  dav-unquote  dav-unquote:core
::  +soft-xml: a body's XML, ~ when it cannot be read (deep nesting a
::  client or a remote sends must not crash the fiber)
++  soft-xml
  |=  body=@t
  ^-  (unit manx)
  (fall (mole |.((parse:dav body))) ~)
::  +dav-delete: an object (with its override children), or a calendar
++  dav-delete
  |=  [eyre-id=@ta req=inbound-request:eyre c=calendar:cal res=dav-res]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?:  ?=(%calendar -.res)
    ?:  =(%default id.res)
      (send-text eyre-id 403 'calendar: the default calendar stays')
    ?.  (~(has by cals.c) id.res)
      (send-text eyre-id 404 'calendar: no such calendar')
    ;<  ~  bind:m  (dav-write '../' c(cals (~(del by cals.c) id.res)))
    (send-simple:srv eyre-id [[204 ~] ~])
  ?:  &(?=(%object -.res) (ship-read-only c id.res))
    (send-text eyre-id 403 'calendar: this calendar is shared with you read-only')
  ?.  ?=(%object -.res)
    (send-text eyre-id 405 'calendar: DELETE an object or a calendar')
  =/  k=(unit cal:cal)  (~(get by cals.c) id.res)
  =/  e=(unit entry:cal)  ?~(k ~ (~(get by entries.u.k) uid.res))
  ?:  |(?=(~ k) ?=(~ e))
    (send-text eyre-id 404 'calendar: no such object')
  ::  If-Match: only the version the client last saw goes
  =/  if-match=(unit @t)  (get-header:http 'if-match' header-list.request.req)
  ?:  &(?=(^ if-match) !=('*' u.if-match) !=(etag.u.e (dav-unquote u.if-match)))
    (send-text eyre-id 412 'calendar: the object changed; fetch it again')
  ;<  ~  bind:m  (dav-write '../' c(cals (~(put by cals.c) id.res (del-object u.k uid.res))))
  (send-simple:srv eyre-id [[204 ~] ~])
::  +dav-mkcalendar: a new local calendar from the body's displayname
::  and calendar-color
++  dav-mkcalendar
  |=  [eyre-id=@ta c=calendar:cal res=dav-res body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=(%calendar -.res)
    (send-text eyre-id 405 'calendar: MKCALENDAR under cal/')
  ?:  (~(has by cals.c) id.res)
    (send-text eyre-id 405 'calendar: that calendar exists')
  ::  an id goes into hrefs and index keys: a knot, no slash
  ?.  ((sane %ta) id.res)
    (send-text eyre-id 403 'calendar: a calendar id is lowercase letters, digits, - . ~ _')
  =/  root=(unit manx)  (soft-xml body)
  =/  name=@t
    ?~  root  id.res
    =/  el=(unit manx)  (find-el:dav u.root %displayname)
    ?~(el id.res (crip (text:dav u.el)))
  =/  color=@t
    ?~  root  '#1e3a5f'
    =/  el=(unit manx)  (find-el:dav u.root %'calendar-color')
    ?~(el '#1e3a5f' (crip (scag 7 (text:dav u.el))))
  ;<  now=@da  bind:m  get-time:io
  =/  k=cal:cal  (born now)
  =.  props.k  [?:(=('' name) id.res name) ?:(=('' color) '#1e3a5f' color) %local ~]
  ::  onto the calendar as it is now, not as the request first read it
  ;<  ~  bind:m
    %+  edit-cals  '../'
    |=(c=calendar:cal ?:((~(has by cals.c) id.res) c c(cals (~(put by cals.c) id.res k))))
  (send-simple:srv eyre-id [[201 ~] ~])
::  +dav-proppatch: displayname and calendar-color on a calendar
++  dav-proppatch
  |=  [eyre-id=@ta c=calendar:cal res=dav-res body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=(%calendar -.res)
    (send-text eyre-id 405 'calendar: PROPPATCH a calendar')
  =/  k=(unit cal:cal)  (~(get by cals.c) id.res)
  ?~  k
    (send-text eyre-id 404 'calendar: no such calendar')
  =/  root=(unit manx)  (soft-xml body)
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
  %-  zing
  %+  murn  ~(val by entries.k)
  |=  e=entry:cal
  ?:  (dav-is-child e)  ~
  `(object-tapes k e now)
::  +object-tapes: one object as VEVENT text: the parent as it goes out
::  (+anchored, its EXDATEs less the moved instances), then its override
::  children, each carrying its RECURRENCE-ID in props
++  object-tapes
  |=  [k=cal:cal e=entry:cal now=@da]
  ^-  (list tape)
  =/  kids=(list entry:cal)  (kids-of:cal k uid.e)
  :-  (write-entry:ics (anchored e) (object-exdates e kids) now)
  (turn kids |=(x=entry:cal (write-entry:ics x ~ now)))
::  +dav-object-ics: one object as iCalendar text
++  dav-object-ics
  |=  [c=calendar:cal id=@ta =uid:cal now=@da]
  ^-  (unit @t)
  =/  k=(unit cal:cal)  (~(get by cals.c) id)
  ?~  k  ~
  =/  e=(unit entry:cal)  (~(get by entries.u.k) uid)
  ?~  e  ~
  `(write-calendar:ics title.c (object-tapes u.k u.e now))
::  +dav-get: an object's .ics with its ETag
++  dav-get
  |=  [eyre-id=@ta c=calendar:cal res=dav-res]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=(%object -.res)
    (send-text eyre-id 405 'calendar: GET an object')
  ;<  now=@da  bind:m  get-time:io
  =/  body=(unit @t)  (dav-object-ics c id.res uid.res now)
  =/  e=(unit entry:cal)
    =/  k=(unit cal:cal)  (~(get by cals.c) id.res)
    ?~(k ~ (~(get by entries.u.k) uid.res))
  ?:  |(?=(~ body) ?=(~ e))
    (send-text eyre-id 404 'calendar: no such object')
  ;<  ~  bind:m
    %+  send-simple:srv  eyre-id
    :_  `(as-octs:mimes:html u.body)
    :~  200
        ['content-type' 'text/calendar; charset=utf-8']
        ['etag' (crip "\"{(trip etag.u.e)}\"")]
    ==
  (pure:m ~)
++  dav-href-res  dav-href-res:core
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
    (send-text eyre-id 403 'calendar: REPORT on a calendar')
  =/  k=(unit cal:cal)  (~(get by cals.c) id.res)
  ?~  k
    (send-text eyre-id 404 'calendar: no such calendar')
  =/  root=(unit manx)  (soft-xml body)
  ?~  root
    (send-text eyre-id 400 'calendar: REPORT needs an XML body')
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
      ;<  ca=cache:cal  bind:(fiber:fiber:nexus ,(list uid:cal))  (fresh-cache '../' c now)
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
        ::  the index is keyed <calendar>/<uid>: only this calendar's
        =/  [cid=@ta u=uid:cal]  (unkey eid.r)
        ?.  =(id cid)  ~
        =/  e=(unit entry:cal)  (~(get by entries.u.k) u)
        ?~  e  ~
        `(fall (parent-of:cal u.e) u)
      ::  and one whose rule this side cannot walk (BYSETPOS, HOURLY):
      ::  the index never places it, so every range names it and the
      ::  client filters, as PROPFIND and sync already list it
      =/  undated=(list uid:cal)
        %+  murn  ~(tap by entries.u.k)
        |=  [u=uid:cal e=entry:cal]
        ^-  (unit uid:cal)
        ?:  &(?=(%todo -.event.e) ?=(~ due.event.e))  `u
        ?.  ?=(?(%timed %allday) -.event.e)  ~
        ?.  =(%rrule name.kind.recur.event.e)  ~
        ?:  (dav-is-child e)  ~
        ?~((of-args-memo:rr args.recur.event.e) `u ~)
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
      =/  segs=(list @t)  (skip (split:rr '/' (crip tok)) |=(t=@t =('' t)))
      (fall (rush ?~(segs '' (rear segs)) dem) 0)
    ::  a token past this calendar's seq, or from before it was made (one
    ::  deleted and made again under this id), is not one of ours: RFC
    ::  6578 says so with valid-sync-token, and the client starts over
    =/  first=@ud  =/(f (pry:on-log:cal log.u.k) ?~(f seq.u.k (dec key.u.f)))
    ?:  &(!=(0 since) |((gth since seq.u.k) (lth since first)))
      %^  dav-send-xml  eyre-id  403
      '<?xml version="1.0" encoding="utf-8"?><D:error xmlns:D="DAV:"><D:valid-sync-token/></D:error>'
    ::  the latest change per object after the token
    =/  changes=(list [uid:cal ?(%put %del)])  (changes-since u.k since ~)
    =/  responses=marl
      %+  turn  changes
      |=  [u=uid:cal what=?(%put %del)]
      ?:  =(%del what)  (status-response:dav (dav-obj-href id u) 404)
      (dav-obj-response c id u now |)
    =/  token=manx  (d-el:dav %'sync-token' ~[(tx:dav "{dav-root}sync/{(a-co:co seq.u.k)}")])
    (dav-send-xml eyre-id 207 (multistatus:dav responses ~[token]))
  (send-text eyre-id 403 'calendar: unsupported report')
+$  dav-res  dav-res:core
++  dav-resolve  dav-resolve:core
++  dav-root  dav-root:core
++  dav-cal-href  dav-cal-href:core
++  dav-obj-href  dav-obj-href:core
++  dav-props-for  dav-props-for:core
++  dav-response  dav-response:core
++  dav-is-child  dav-is-child:core
::  +dav-propfind
++  dav-propfind
  |=  [eyre-id=@ta req=inbound-request:eyre our=@p c=calendar:cal res=dav-res body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?:  ?=(%none -.res)
    (send-text eyre-id 404 'calendar: no such resource')
  ::  no Depth is infinity (RFC 4918 9.1), answered as 1: the tree is
  ::  no deeper
  =/  depth=@ud
    =/  d=(unit @t)  (get-header:http 'depth' header-list.request.req)
    ?:(&(?=(^ d) =('0' u.d)) 0 1)
  =/  asked=(list @tas)  (prop-names:dav (soft-xml body))
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
    (send-text eyre-id 404 'calendar: no such resource')
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
++  google-defaults  google-defaults:core
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
::  +set-lead-min: the reminders fiber's heads-up, in minutes before a
::  timed event's start (its other keys, the watermarks, stay). A week
::  is the most, as its cache is built that far ahead
++  set-lead-min
  |=  n=@ud
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  rem=json  bind:m  (read-json-grub './' 'reminders.json')
  =/  cur=(map @t json)  ?:(?=([%o *] rem) p.rem ~)
  (write-json-grub './' 'reminders.json' [%o (~(put by cur) 'lead_min' (numb:enjs:format (min 10.080 n)))])
::  outcomes.json (docs/logging.md): the app's own record of what a poke
::  was refused for and of the faults that stand. A write that is refused
::  is let go: the record must not be able to take a fiber down.
++  write-outcomes
  |=  [pre=@t out=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  *  bind:m  (over-as-soft:io (grub-road pre 'outcomes.json') [[/ %json] out] [/ %json])
  (pure:m ~)
::  +refuse: a poke's refusal, with its reason, into the ring. A poke is
::  acknowledged before it is read, so the reason has no other way back.
::  Nothing waits between the read and the write.
++  refuse
  |=  [pre=@t action=@t id=@t from=@t why=tape]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  clock=(unit @da)  bind:m  soft-now
  ;<  out=json  bind:m  (read-json-grub pre 'outcomes.json')
  (write-outcomes pre (refusal-put:core out (fall clock *@da) action id from (crip why)))
::  +acts: a status a person can act on: the remote answered and refused.
::  None (0) or a 5xx is the remote's trouble, and a 429 is a rate limit
::  that passes by itself: recorded and not said.
++  acts  |=(status=@ud &((gte status 400) (lth status 500) !=(429 status)))
::  +fault: a condition that stands is recorded under its key. The console
::  hears of it once, when it begins or first becomes a person's to act
::  on (say), with what to do; never per pass.
++  fault
  |=  [pre=@t key=@t level=?(%error %warning) say=? what=tape remedy=tape]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  clock=(unit @da)  bind:m  soft-now
  ;<  out=json  bind:m  (read-json-grub pre 'outcomes.json')
  =/  [tell=? nxt=json]  (fault-put:core out (fall clock *@da) key level say (crip what) (crip remedy))
  ;<  ~  bind:m  (write-outcomes pre nxt)
  ?.  tell  (pure:m ~)
  =/  line=tape  "calendar: {what}; {remedy} ({(trip key)} in outcomes.json)"
  ?:  ?=(%error level)
    ~&  >>>  line
    (pure:m ~)
  ~&  >>  line
  (pure:m ~)
::  +unfault: the condition under key has cleared. One notice, if the
::  console had heard of the fault.
++  unfault
  |=  [pre=@t key=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  out=json  bind:m  (read-json-grub pre 'outcomes.json')
  =/  [said=? had=? nxt=json]  (fault-clear:core out key)
  ?.  had  (pure:m ~)
  ;<  ~  bind:m  (write-outcomes pre nxt)
  ?.  said  (pure:m ~)
  ~&  >  "calendar: {(trip key)} cleared"
  (pure:m ~)
::  +check-roads: the timer, the clock and the web binding, asked softly
::  from the main fiber, which is never parked and so is here to say what
::  stopped. The timer and the clock are recorded, not printed: a fiber
::  that waits on one is parked by the kernel, and the kernel's one line
::  for the app is the console's. The web binding is the calendar's to
::  say: the kernel's bind swallows a refusal in silence and parks
::  nothing, so with that road alone refused nothing else would speak.
::  When the timer or the clock is refused too (a fresh install is
::  refused everything), the kernel's line covers the app and this one
::  is recorded only.
++  check-roads
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  the clock first: with /sys/bowl.sig refused every record here (a
  ::  file read asks it for a nonce) would park this fiber, so only the
  ::  web binding is tried, and nothing is written. The kernel's permits
  ::  page shows that road; there is no road/bowl key
  ;<  clock=(unit @da)  bind:m  soft-now
  ?~  clock
    ;<  *  bind:m  (soft-bind [~ /apps/calendar])
    (pure:m ~)
  ;<  timer=?  bind:m  (soft-behn /rise/rest [[/ %timer-rest] `wire`/rise])
  ;<  ~  bind:m
    ?:  timer  (unfault './' 'road/behn')
    %:  fault  './'  'road/behn'  %error  |
      "the timer road /sys/behn/ is refused, so reminders and syncing are stopped"
      "grant it at /apps/grubbery/permits, then reload the calendar"
    ==
  ::  a key an older version wrote
  ;<  ~  bind:m  (unfault './' 'road/bowl')
  ;<  web=?  bind:m  (soft-bind [~ /apps/calendar])
  ?:  web  (unfault './' 'road/eyre')
  %:  fault  './'  'road/eyre'  %error  timer
    "the web road /sys/eyre/ is refused, so the calendar's page and CalDAV do not answer"
    "grant it at /apps/grubbery/permits, then reload the calendar"
  ==
::  +soft-bind: bind our route to this grub, & when eyre took it. The
::  kernel's +bind-http-self is this poke with the refusal swallowed.
::  The wire is fixed: a nonce would ask /sys/bowl.sig, refusable too.
++  soft-bind
  |=  =binding:eyre
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ~  bind:m
    (send-dart:io %node /bind-self &+&+[/sys/eyre %'main.server-state'] %poke [[/ %eyre-action] [%bind-self binding]])
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]  [%done |]
      [~ %pack * *]
    ?.  =(/bind-self wire.u.in)  [%skip ~]
    [%done &]
  ==
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
  ::  a response that never comes (iris forgot the request across a
  ::  reload; seen on ricsul 2026-09-14, where it wedged the sync fiber
  ::  and every sync route with it) is status 0 after two minutes. iris
  ::  answers carry no request id, so a late one is waited out for two
  ::  minutes more and dropped: left, it would be taken for the answer to
  ::  the next request (one Google calendar's page applied to another). A
  ::  request iris forgot costs the four minutes once.
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m  (set-timer:io /fetch (add now ~m2))
  ;<  res=$@(?(%none %late) client-response:iris)  bind:m  (take-fetch %fetch)
  ;<  ~  bind:m  (cancel-timer:io /fetch)
  ;<  ~  bind:m
    =/  m  (fiber:fiber:nexus ,~)
    ?.  ?=(%late res)  (pure:m ~)
    ;<  now=@da  bind:m  get-time:io
    ;<  ~  bind:m  (set-timer:io /fetch-drain (add now ~m2))
    ;<  *  bind:m  (take-fetch %fetch-drain)
    (cancel-timer:io /fetch-drain)
  =/  res=(unit client-response:iris)  ?@(res ~ `res)
  ?~  res  (pure:m [0 ~ ''])
  ?.  ?=(%finished -.u.res)  (pure:m [0 ~ ''])
  =/  body=@t  ?~(full-file.u.res '' q.data.u.full-file.u.res)
  (pure:m [status-code.response-header.u.res headers.response-header.u.res body])
::  +take-fetch: iris's answer; %late when the timer on wire /tag fires
::  first; %none when the request was refused or cancelled (no answer
::  will follow)
++  take-fetch
  |=  tag=@ta
  =/  m  (fiber:fiber:nexus ,$@(?(%none %late) client-response:iris))
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]  [%done %none]
      [~ %poke * *]
    ?:  =([/ %timer-wake] p.sage.u.in)
      ?.(=(/[tag] !<(path q.sage.u.in)) [%skip ~] [%done %late])
    ?.  =([/ %http-response] p.sage.u.in)  [%skip ~]
    =/  resp=client-response:iris  !<(client-response:iris q.sage.u.in)
    ::  a long body comes in parts: %progress, then %finished whole
    ?:  ?=(%progress -.resp)  [%wait ~]
    ?:  ?=(%cancel -.resp)  [%done %none]
    [%done resp]
  ==
++  form-body  form-body:core
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
    ;<  ~  bind:m
      ?:  =(0 status)
        %:  fault  pre  'google-auth'  %warning  |
          "Google could not be reached to renew the sign-in, so Google calendars are not syncing"
          "nothing to do: it is tried again on the next pass"
        ==
      %:  fault  pre  'google-auth'  %error  |((acts status) =(200 status))
        "Google gave no new sign-in token (status {(a-co:co status)}), so Google calendars are not syncing"
        "reconnect Google under Settings"
      ==
    (pure:m ~)
  =/  ttl=@ud  (fall (gn tok 'expires_in') 3.600)
  ::  onto a fresh read, and only for the account we refreshed: a
  ::  disconnect or a reconnect while we waited must not be undone
  ;<  auth=json  bind:m  (google-auth pre)
  ?.  =(refresh (gs auth 'refresh_token'))  (pure:m ~)
  ;<  ~  bind:m
    %^  write-json-grub  pre  'google-auth.json'
    %+  row-put  auth
    :~  ['access_token' s+access]
        ['expires_ms' (numb:enjs:format (add (da-to-ms now) (mul 1.000 ttl)))]
    ==
  ;<  ~  bind:m  (unfault pre 'google-auth')
  (pure:m `access)
::  +google-api: a call against api_base with the bearer token. status
::  401 when not connected.
++  google-api
  |=  [pre=@t method=method:http path=tape body=(unit json)]
  (google-api-hdr pre method path body ~)
::  +google-api-hdr: the same, with headers of the caller's (If-Match)
++  google-api-hdr
  |=  [pre=@t method=method:http path=tape body=(unit json) extra=(list [@t @t])]
  =/  m  (fiber:fiber:nexus ,[status=@ud =json])
  ^-  form:m
  ;<  cfg=json  bind:m  (google-config pre)
  ;<  tok=(unit @t)  bind:m  (google-token pre)
  ::  no token: 401 when not connected; connected, the refresh failed
  ::  (google-auth says why), and a network that did not answer is no
  ::  reason to tell the owner to reconnect: status 0, asked again
  ?~  tok
    ;<  auth=json  bind:m  (google-auth pre)
    (pure:m [?:(=('' (gs auth 'refresh_token')) 401 0) [%o ~]])
  =/  headers=(list [@t @t])
    :-  ['authorization' (cat 3 'Bearer ' u.tok)]
    %+  weld  extra
    ?~(body ~ ~[['content-type' 'application/json']])
  ;<  [status=@ud res=@t]  bind:m
    %-  fetch-full
    :^  method  (crip (weld (trip (gs cfg 'api_base')) path))
      headers
    ?~(body ~ `(as-octs:mimes:html (en:json:html u.body)))
  ::  a body that is not JSON is no answer (status 0), never an empty
  ::  one: an empty listing would read as every event deleted
  =/  jon=(unit json)  (de:json:html res)
  ?~  jon  (pure:m ?:(=('' res) [status [%o ~]] [0 [%o ~]]))
  (pure:m [status u.jon])
::  +google-request: the owner's Google routes under /apps/calendar/google/
++  google-request
  |=  [eyre-id=@ta req=inbound-request:eyre our=@p rest=path args=quay:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  jon=json
    (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
  =/  post=?  =('POST' method.request.req)
  ::  the origin as the ship sees it; behind a TLS proxy that is http
  ::  unless the proxy says otherwise, so the page records the origin it
  ::  was opened at when the client is saved (redirect_uri in google.json)
  ::  and that is what Google is told, at sign-in and at the token exchange
  =/  origin=tape
    =/  host=@t  (fall (get-header:http 'host' header-list.request.req) 'localhost')
    =/  proto=@t
      %+  fall  (get-header:http 'x-forwarded-proto' header-list.request.req)
      ?:(secure.req 'https' 'http')
    "{(trip proto)}://{(trip host)}"
  =/  redirect-of
    |=  cfg=json
    ^-  tape
    =/  r=@t  (gs cfg 'redirect_uri')
    ?:(=('' r) "{origin}/apps/calendar/google/callback" (trip r))
  =/  redirect-to
    |=  where=tape
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    (send-simple:srv eyre-id [[302 ['location' (crip where)] ~] ~])
  ::  config: the user's client, and the endpoints (the gate swaps them)
  ?:  &(post ?=([%config ~] rest))
    ?:  (lien `(list @t)`~['auth_url' 'token_url' 'api_base'] |=(k=@t =/(v (gs jon k) &(!=('' v) !(endpoint-ok v)))))
      (send-text eyre-id 400 'calendar: the endpoints must be Google\'s (or this machine\'s, to test)')
    ;<  cfg=json  bind:m  (google-config '../')
    =/  cur=(map @t json)  ?:(?=([%o *] cfg) p.cfg ~)
    =/  new=(map @t json)
      %+  roll  `(list @t)`~['client_id' 'client_secret' 'auth_url' 'token_url' 'api_base']
      |=  [k=@t acc=_cur]
      =/  v=@t  (gs jon k)
      ?:(=('' v) acc (~(put by acc) k s+v))
    =/  tick=(unit @ud)  (gn jon 'tick_min')
    =?  new  ?=(^ tick)  (~(put by new) 'tick_min' (numb:enjs:format (max 1 u.tick)))
    ::  the page's origin, as the browser has it: the redirect URI is the
    ::  one the panel showed and the one registered with Google
    =/  o=@t  (gs jon 'origin')
    =?  new  &(!=('' o) |(=('https://' (end [3 8] o)) =('http://' (end [3 7] o))))
      (~(put by new) 'redirect_uri' s+(crip "{(trip o)}/apps/calendar/google/callback"))
    ;<  ~  bind:m  (write-json-grub '../' 'google.json' [%o new])
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  ::  connect: off to the consent screen
  ?:  ?=([%connect ~] rest)
    ;<  cfg=json  bind:m  (google-config '../')
    =/  cid=@t  (gs cfg 'client_id')
    ?:  =('' cid)  (send-text eyre-id 400 'calendar: set the OAuth client first')
    ;<  eny=@uvJ  bind:m  get-entropy:io
    =/  state=@t  (scot %uv (end [3 12] eny))
    ;<  auth=json  bind:m  (google-auth '../')
    ;<  ~  bind:m
      %^  write-json-grub  '../'  'google-auth.json'
      [%o (~(put by ?:(?=([%o *] auth) p.auth ~)) 'state' s+state)]
    =/  q=(list [tape tape])
      :~  ["client_id" (trip cid)]
          ["redirect_uri" (redirect-of cfg)]
          ["response_type" "code"]
          ["scope" "https://www.googleapis.com/auth/calendar"]
          ["access_type" "offline"]
          ["prompt" "consent select_account"]
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
      (send-text eyre-id 400 'calendar: the callback did not carry the state this ship issued')
    ?:  =('' code)
      (send-text eyre-id 400 (crip "calendar: google answered without a code: {(trip (fall (get-key:kv:html-utils 'error' args) ''))}"))
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
          ["redirect_uri" (redirect-of cfg)]
      ==
    =/  tok=json  (fall (de:json:html body) *json)
    =/  refresh=@t  (gs tok 'refresh_token')
    =/  access=@t  (gs tok 'access_token')
    ?:  |(!=(200 status) =('' refresh))
      (send-text eyre-id 502 (crip "calendar: token exchange failed ({(a-co:co status)}): {(trip (gs tok 'error_description'))}"))
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
    ::  the grant is revoked at Google too, so it does not outlive the
    ::  link (best effort: this side disconnects whatever Google says).
    ::  The revoke endpoint sits beside the token one
    ;<  auth=json  bind:m  (google-auth '../')
    ;<  cfg=json  bind:m  (google-config '../')
    =/  tok=@t  =/(r (gs auth 'refresh_token') ?.(=('' r) r (gs auth 'access_token')))
    =/  tu=tape  (trip (gs cfg 'token_url'))
    =/  cut=@ud  (sub (lent tu) (min 6 (lent tu)))
    ;<  ~  bind:m
      ?:  |(=('' tok) !=("/token" (slag cut tu)))  (pure:(fiber:fiber:nexus ,~) ~)
      ;<  *  bind:(fiber:fiber:nexus ,~)
        %-  fetch-full
        :^  %'POST'  (crip (weld (scag cut tu) "/revoke"))
          ~[['content-type' 'application/x-www-form-urlencoded']]
        `(form-body ~[["token" (trip tok)]])
      (pure:(fiber:fiber:nexus ,~) ~)
    ;<  ~  bind:m  (write-json-grub '../' 'google-auth.json' [%o ~])
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  ::  calendars.json: the account's calendars, with which are linked
  ?:  ?=([%'calendars.json' ~] rest)
    ::  every page (Google's is 100), ten at most
    ;<  got=(each (list json) @ud)  bind:m
      =/  n  (fiber:fiber:nexus ,(each (list json) @ud))
      =|  acc=(list json)
      =/  page=@t  ''
      =/  pages=@ud  0
      |-
      ;<  [status=@ud res=json]  bind:n
        %:  google-api  '../'  %'GET'
          (weld "/calendar/v3/users/me/calendarList" ?:(=('' page) "" "?pageToken={(enc-seg:dav (trip page))}"))
          ~
        ==
      ?.  =(200 status)  (pure:n |+status)
      =.  acc  (weld acc (arr:gcal res 'items'))
      =/  next=@t  (gs res 'nextPageToken')
      ?:  |(=('' next) (gte pages 9))  (pure:n &+acc)
      $(page next, pages +(pages))
    ::  status 0 (no answer, or no token to send) is no HTTP status
    ?:  ?=(%| -.got)  (send-text eyre-id ?:(=(0 p.got) 502 p.got) (crip "calendar: google answered {(a-co:co p.got)}"))
    ;<  sync=json  bind:m  (google-sync '../')
    =/  linked=(map @t @t)
      %-  ~(gas by *(map @t @t))
      %+  turn  ?:(?=([%o *] sync) ~(tap by p.sync) ~)
      |=([id=@t v=json] [(gs v 'google_id') id])
    =/  items=(list json)  p.got
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
        ['primary' b+?=([~ %b %.y] (~(get by ?:(?=([%o *] it) p.it ~)) 'primary'))]
        ['linked' ?~(l=(~(get by linked) gid) ~ s+u.l)]
    ==
  ::  link: a ship calendar of kind google for one of them
  ?:  &(post ?=([%link ~] rest))
    =/  gid=@t  (gs jon 'google_id')
    ?:  =('' gid)  (send-text eyre-id 400 'calendar: need google_id')
    ;<  now=@da  bind:m  get-time:io
    ;<  c=calendar:cal  bind:m  (read-cal '../')
    =/  id=@ta  (crip "g-{(trip (scot %uw (mug gid)))}")
    ?:  (~(has by cals.c) id)  (send-text eyre-id 409 'calendar: already linked')
    =/  nm=@t  (gs jon 'name')
    =/  color=@t  (gs jon 'color')
    =/  k=cal:cal  (born now)
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
      (write-json-grub '../' 'google-sync.json' [%o (~(put by ?:(?=([%o *] sync) p.sync ~)) id row)])
    ;<  ~  bind:m  (google-prod '../')
    (send-json eyre-id (pairs:enjs:format ~[['id' s+id]]))
  ?:  &(post ?=([%unlink ~] rest))
    (drop-synced eyre-id (crip (trip (gs jon 'id'))) %google 'calendar: not linked')
  ?:  &(post ?=([%sync ~] rest))
    ;<  ~  bind:m  (google-prod '../')
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  ?:  ?=([%'conflicts.json' ~] rest)
    ;<  cs=json  bind:m  (read-json-grub '../' 'google-conflicts.json')
    (send-json eyre-id ?:(?=([%a *] cs) cs [%a ~]))
  ?:  &(post ?=([%conflicts %clear ~] rest))
    ;<  ~  bind:m  (write-json-grub '../' 'google-conflicts.json' [%a ~])
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  (send-text eyre-id 404 'calendar: no such google route')
::  +google-conflict: both versions kept, so nothing is lost silently.
::  The remote's copy has already won; the local one rides along as ICS.
::  Every backend logs here (Google was the first).
++  google-conflict
  |=  [pre=@t id=@ta =uid:cal local=(unit entry:cal) remote-updated=@t why=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  the clock before the read: nothing waits between reading the log
  ::  and writing it back
  ;<  now=@da  bind:m  get-time:io
  ;<  cs=json  bind:m  (read-json-grub pre 'google-conflicts.json')
  ::  the local copy is the point of the row, so it is phrased softly: a
  ::  crash here would leave the remote's overwrite with no row at all
  =/  ics=@t
    ?~  local  ''
    %+  fall
      (mole |.((write-calendar:ics 'conflict' ~[(write-entry:ics u.local (exdates-of u.local) now)])))
    ''
  (conflict-row-at pre id uid ics remote-updated why now cs)
::  +conflict-row: a conflict row from an object already in ICS
++  conflict-row
  |=  [pre=@t id=@ta =uid:cal ics=@t remote-updated=@t why=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  cs=json  bind:m  (read-json-grub pre 'google-conflicts.json')
  (conflict-row-at pre id uid ics remote-updated why now cs)
++  conflict-row-at
  |=  [pre=@t id=@ta =uid:cal ics=@t remote-updated=@t why=@t now=@da cs=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  all=(list json)  ?:(?=([%a *] cs) p.cs ~)
  =/  same  |=(c=json &(=(uid (gs c 'uid')) =(id (gs c 'cal'))))
  ::  a later row with no copy (a refused delete) never drops a saved one
  ?:  &(=('' ics) (lien all |=(c=json &((same c) !=('' (gs c 'local'))))))
    (pure:m ~)
  =/  row=json
    %-  pairs:enjs:format
    :~  ['uid' s+uid]
        ['cal' s+id]
        ['at_ms' (numb:enjs:format (da-to-ms now))]
        ['why' s+why]
        ['local' s+ics]
        ['remote_updated' s+remote-updated]
    ==
  ::  three rows per calendar and uid (a second conflict keeps the copy
  ::  the first saved), the newest 500: a host or remote that makes up
  ::  refusals cannot grow the log without end. Rows run oldest first.
  =/  mine=(list json)  (skim all same)
  =/  rest=(list json)
    ?.  (gte (lent mine) 3)  all
    =/  at=(unit @ud)  (find ~[(snag 0 mine)] all)
    ?~(at all (oust [u.at 1] all))
  =/  keep=(list json)  (slag (sub (max 500 +((lent rest))) 500) (snoc rest row))
  (write-json-grub pre 'google-conflicts.json' [%a keep])
::  +log-clashes: a conflict row for each uid a pull let the remote win
::  over a local change: [uid, the local copy it replaced, the remote's
::  updated stamp when it has one]
++  log-clashes
  |=  [pre=@t id=@ta clashes=(list [uid:cal (unit entry:cal) @t]) why=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  clashes  (pure:m ~)
  =/  [u=uid:cal local=(unit entry:cal) up=@t]  i.clashes
  ;<  ~  bind:m  (google-conflict pre id u local up why)
  $(clashes t.clashes)
++  suppressed  suppressed:core
++  suppress-json  suppress-json:core
++  since-log  since-log:core
++  wrote-between  wrote-between:core
++  pending-uids  pending-uids:core
++  rows-of  rows-of:core
++  child-row  child-row:core
++  changes-since  changes-since:core
::  +take-any: the next news on one of these wires (which), or a poke
::  asking for a pull. A remote peek's answer that came after its timeout
::  is taken and dropped here; left, it would sit in the queue for good.
++  take-any
  |=  wires=(list wire)
  =/  m  (fiber:fiber:nexus ,$@(%poke [%news =wire]))
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    ?~((find ~[wire.u.in] wires) [%skip ~] [%done %news wire.u.in])
  ::  a pull is the tick's timer or a prod (+google-prod). Any other poke
  ::  (an ack or a timer come after its wait timed out) is taken and
  ::  dropped: it is no reason to pull every backend
      [~ %poke * *]
    ?:  =([/ %json] p.sage.u.in)  [%done %poke]
    ?.  =([/ %timer-wake] p.sage.u.in)  [%wait ~]
    ?:(?=([%tick *] !<(path q.sage.u.in)) [%done %poke] [%wait ~])
      [~ %peek * *]
    [%wait ~]
  ==
++  omap  omap:core
++  row-put  row-put:core
::  +save-row: one sync row back to its file, onto a fresh read, field
::  by field (+row-merge: bases are the rows this pass knew the file to
::  hold). A row whose calendar went away meanwhile is not brought back.
++  save-row
  |=  [pre=@t file=@t id=@t bases=(list json) row=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=json  bind:m  (read-json-grub pre file)
  =/  rows=(map @t json)  (omap cur)
  =/  now=(unit json)  (~(get by rows) id)
  ?~  now  (pure:m ~)
  =/  new=json  (row-merge:core bases row u.now)
  ?:  =(new u.now)  (pure:m ~)
  (write-json-grub pre file [%o (~(put by rows) id new)])
::  +set-row: fields onto one row of a rows file, read fresh, so what
::  another fiber wrote to the row meanwhile stays. A row gone stays gone
++  set-row
  |=  [pre=@t file=@t id=@t kvs=(list [@t json])]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=json  bind:m  (read-json-grub pre file)
  =/  rows=(map @t json)  (omap cur)
  =/  row=(unit json)  (~(get by rows) id)
  ?~  row  (pure:m ~)
  (write-json-grub pre file [%o (~(put by rows) id (row-put u.row kvs))])
::  +sync-file, +sync-pull, +sync-push: the three backends, by kind
++  sync-file
  |=  kind=?(%google %caldav %ship)
  ^-  @t
  ?-  kind
    %google  'google-sync.json'
    %caldav  'caldav-remotes.json'
    %ship    'ship-remotes.json'
  ==
++  sync-pull
  |=  [kind=?(%google %caldav %ship) pre=@t id=@ta row=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ?-  kind
    %google  (google-pull pre id row)
    %caldav  (caldav-pull pre id row)
    %ship    (ship-pull pre id row)
  ==
++  sync-push
  |=  [kind=?(%google %caldav %ship) pre=@t id=@ta row=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ?-  kind
    %google  (google-push pre id row)
    %caldav  (caldav-push pre id row)
    %ship    (ship-push pre id row)
  ==
::  +sync-pass: every row of one backend: pull (when asked), then push,
::  each row saved as it goes. A row whose calendar is gone or is no
::  longer that kind (deleted, made local) goes first, before anything
::  reaches the network for it.
++  sync-pass
  |=  [kind=?(%google %caldav %ship) pull=?]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  pre=@t  './'
  =/  file=@t  (sync-file kind)
  ;<  rows-j=json  bind:m  (read-json-grub pre file)
  =/  all=(list [id=@t row=json])  ~(tap by (omap rows-j))
  ?:  =(~ all)  (pure:m ~)
  ;<  c=calendar:cal  bind:m  (read-cal pre)
  =/  dead=(list @t)  (murn `(list [id=@t row=json])`all |=([id=@t *] ?:((kind-is c id kind) ~ `id)))
  ;<  ~  bind:m
    ?~  dead  (pure:(fiber:fiber:nexus ,~) ~)
    ;<  cur=json  bind:(fiber:fiber:nexus ,~)  (read-json-grub pre file)
    %^  write-json-grub  pre  file
    [%o (roll `(list @t)`dead |=([id=@t acc=_(omap cur)] (~(del by acc) id)))]
  =/  rows=(list [id=@t row=json])  (skim `(list [id=@t row=json])`all |=([id=@t *] (kind-is c id kind)))
  ?:  =(~ rows)  (pure:m ~)
  ::  Google: nothing to do without a token
  ;<  ok=?  bind:m
    ?.  ?=(%google kind)  (pure:(fiber:fiber:nexus ,?) &)
    ;<  tok=(unit @t)  bind:(fiber:fiber:nexus ,?)  (google-token pre)
    (pure:(fiber:fiber:nexus ,?) ?=(^ tok))
  ?.  ok  (pure:m ~)
  ;<  now=@da  bind:m  get-time:io
  |-
  ?~  rows  (pure:m ~)
  =/  id=@ta  (crip (trip id.i.rows))
  ::  a host that did not answer costs a pass 30 s: it is asked again
  ::  after a wait that doubles from 5 minutes to an hour
  ?:  &(?=(%ship kind) (gth (fall (gn row.i.rows 'retry_ms') 0) (da-to-ms now)))
    $(rows t.rows)
  ;<  row=json  bind:m
    ?.  pull  (pure:(fiber:fiber:nexus ,json) row.i.rows)
    (sync-pull kind pre id row.i.rows)
  ::  the file holds the row as the pass began, or as its pull saved it
  =/  pulled=json  row
  =?  row  &(?=(%ship kind) pull)  (back-off row now)
  ;<  row=json  bind:m  (sync-push kind pre id row)
  ;<  ~  bind:m  (save-row pre file id.i.rows ~[row.i.rows pulled] row)
  $(rows t.rows)
::  +back-off: a shared calendar's row after a pull: its host not heard
::  (an error), asked again later each time; heard, at once
++  back-off
  |=  [row=json now=@da]
  ^-  json
  ?:  =('' (gs row 'error'))  (row-put row ~[['fails' (numb:enjs:format 0)] ['retry_ms' (numb:enjs:format 0)]])
  =/  n=@ud  (fall (gn row 'fails') 0)
  =/  wait=@ud  (min 3.600.000 (mul 300.000 (bex (min n 4))))
  (row-put row ~[['fails' (numb:enjs:format +(n))] ['retry_ms' (numb:enjs:format (add (da-to-ms now) wait))]])
::  +google-pull: one calendar, all pages, applied. The row comes back
::  with the new token, time, id map and watermark, and is saved with
::  each page's write: a reload mid-pass never leaves the calendar ahead
::  of its row (the next push would send the pull's own writes back).
++  google-pull
  |=  [pre=@t id=@ta row=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  gid=@t  (gs row 'google_id')
  =/  tok=@t  (gs row 'sync_token')
  =/  full=?  =('' tok)
  =/  base=tape  "/calendar/v3/calendars/{(enc-seg:dav (trip gid))}/events?maxResults=250"
  =/  ids=(map @t json)  (omap (obj:gcal row 'ids'))
  ::  each uid's last Google stamp, pushed or pulled: an item with it is
  ::  nothing new, even when the entry is gone here (a delete not yet
  ::  pushed)
  =/  stamps=(map @t json)  (omap (obj:gcal row 'stamps'))
  =/  since=@ud  (fall (gn row 'pushed_seq') 0)
  =/  page=@t  ''
  =/  pages=@ud  0
  =/  seen=(set uid:cal)  ~
  =/  retried=?  |
  =/  had-insts=?  |
  |-
  =/  q=tape
    ;:  weld
      base
      ?:(full "&showDeleted=true&singleEvents=false" "&syncToken={(enc-seg:dav (trip tok))}")
      ?:(=('' page) "" "&pageToken={(enc-seg:dav (trip page))}")
    ==
  ;<  [status=@ud res=json]  bind:m  (google-api pre %'GET' q ~)
  ?:  &(=(410 status) !retried)
    $(full &, tok '', page '', retried &)
  ?.  =(200 status)
    ;<  ~  bind:m
      %:  fault  pre  (cat 3 'google-pull/' id)  %error  (acts status)
        "Google would not list calendar {(trip id)} (status {(a-co:co status)})"
        ?:  |(=(0 status) (gte status 500) =(429 status))
          "nothing to do unless it stays: it is asked again on the next pass"
        "reconnect Google under Settings, or unlink the calendar"
      ==
    (pure:m row)
  ::  every page names the next page or the sync token: one with neither
  ::  (an empty body) is no answer, and must not read as a listing of
  ::  nothing, which would delete every event
  ?:  &(=('' (gs res 'nextPageToken')) =('' (gs res 'nextSyncToken')))
    ;<  ~  bind:m
      %:  fault  pre  (cat 3 'google-pull/' id)  %error  |
        "Google's listing of calendar {(trip id)} came back empty, with no page or sync token"
        "nothing was changed; it is asked again on the next pass"
      ==
    (pure:m row)
  ::  from the read to the write nothing waits (+edit-cals); the clock is
  ::  read first and the conflicts are logged after
  ;<  now=@da  bind:m  get-time:io
  ;<  c=calendar:cal  bind:m  (read-cal pre)
  =/  k=cal:cal  (fall (~(get by cals.c) id) fresh-cal:cal)
  ?.  ?=(%google kind.props.k)  (pure:m row)
  =/  k=cal:cal  k
  ::  a deleted item may carry only its id: its uid is the one the id
  ::  map knows, and a deleted instance's series is its recurringEventId.
  ::  The same map places every item.
  =/  by-gid=(map @t uid:cal)
    %-  ~(gas by *(map @t uid:cal))
    (murn ~(tap by ids) |=([u=@t v=json] ?.(?=([%s *] v) ~ `[p.v u])))
  =/  items=(list gitem:gcal)
    %+  turn  (murn (arr:gcal res 'items') item-of:gcal)
    |=  g=gitem:gcal
    ::  every item under the uid this side keeps it by, when the id map
    ::  knows it: its own, or a series' for an instance (an object kept
    ::  under a name that is not its UID stays there)
    =/  u=(unit uid:cal)  (~(get by by-gid) ?~(rid.g gid.g recur.g))
    ?~(u g g(uid.ve u.u))
  ::  the entry an item is: its uid, or an instance's child under it
  =/  item-uid
    |=  g=gitem:gcal
    ^-  uid:cal
    ?~(rid.g uid.ve.g (crip "{(trip uid.ve.g)}#{(trip u.rid.g)}"))
  ::  our own push coming back, or what the last pull read: Google's
  ::  stamp is the one kept (the row's, or X-GOOGLE-UPDATED), so it is
  ::  nothing new, and a local edit made since is not a clash with it.
  ::  It is still seen.
  =/  echo=(list gitem:gcal)
    %+  skim  items
    |=  g=gitem:gcal
    ?:  =('' updated.g)  |
    =/  u=uid:cal  (item-uid g)
    ?:  =(`s+updated.g (~(get by stamps) u))  &
    =/  e=(unit entry:cal)  (~(get by entries.k) u)
    ?~  e  |
    =/  up=(unit prop:ics)  (get-prop:ics props.u.e 'X-GOOGLE-UPDATED')
    &(?=(^ up) =(v.u.up updated.g))
  ::  every live item Google named is seen, read or not: one this side
  ::  cannot read must not count as deleted by a full listing
  =.  seen  (~(gas in seen) (murn items |=(g=gitem:gcal ?:(cancelled.g ~ `uid.ve.g))))
  =.  items  (skip items |=(g=gitem:gcal ?=(^ (find ~[g] echo))))
  ::  an item whose uid also changed here since the last push is a
  ::  conflict: Google wins, the local copy is logged
  =/  sup=(set [@t @ud])  (suppressed row)
  =/  pending=(set uid:cal)  (pending-uids k since sup)
  =/  seq-at-peek=@ud  seq.k
  =/  clashes=(list gitem:gcal)
    (skim items |=(g=gitem:gcal (~(has in pending) (item-uid g))))
  =/  clash-rows=(list [uid:cal (unit entry:cal) @t])
    (turn clashes |=(g=gitem:gcal [(item-uid g) (~(get by entries.k) (item-uid g)) updated.g]))
  ::  parents first, so an instance finds its parent
  =/  parents=(list gitem:gcal)  (skip items |=(g=gitem:gcal ?=(^ rid.g)))
  =/  insts=(list gitem:gcal)  (skim items |=(g=gitem:gcal ?=(^ rid.g)))
  =/  res2=[k=cal:cal ids=(map @t json) seen=(set uid:cal)]
    %+  roll  (weld parents insts)
    |=  [g=gitem:gcal acc=_[k=k ids=ids seen=seen]]
    ::  an item this side cannot read is skipped, as the other pulls skip
    ::  one: a crash here would come back at every pull
    %+  fall
      %-  mole  |.
      ^+  acc
    =/  u=uid:cal  uid.ve.g
    ::  what Google says of it (id, stamp, etag, default reminders)
    =/  extra=(list [@t @t])
      (skim extra.ve.g |=([key=@t *] =("X-GOOGLE-" (scag 9 (trip key)))))
    ?^  rid.g
      =.  seen.acc  (~(put in seen.acc) u)
      ?.  cancelled.g
        acc(k (put-override k.acc u ve.g zone.c extra))
      ::  a cancelled instance goes, and a moved copy of it with it
      =.  k.acc  (del-entry:cal k.acc (crip "{(trip u)}#{(trip u.rid.g)}"))
      acc(k (skip-instance k.acc u extra.ve.g))
    ?:  cancelled.g
      ::  a cancelled copy under another Google id (the same iCalUID
      ::  put again under a new one in this listing) leaves the live one
      =/  was=(unit json)  (~(get by ids.acc) u)
      ?:  &(?=(^ was) !=(u.was s+gid.g))  acc
      ::  an event made a task here was taken off Google (+google-push):
      ::  that delete coming back leaves the task
      ?:  =/(e (~(get by entries.k.acc) u) &(?=(^ e) ?=(%todo -.event.u.e)))  acc
      acc(k (del-object k.acc u), ids (~(del by ids.acc) u))
    =/  put=(unit [k=cal:cal =uid:cal])  (put-parent k.acc ve.g zone.c u extra &)
    ?~  put  acc
    acc(k k.u.put, ids (~(put by ids.acc) u s+gid.g), seen (~(put in seen.acc) u))
    acc
  =.  k  k.res2
  =.  ids  ids.res2
  =.  seen  (~(uni in seen) seen.res2)
  =.  had-insts  |(had-insts ?=(^ insts))
  ::  only for what was applied: one this side could not read is read
    ::  again by a later full listing, not taken for seen
  =.  stamps
    %+  roll  items
    |=  [g=gitem:gcal acc=_stamps]
    ?:  cancelled.g
      ?^(rid.g (~(del by acc) (item-uid g)) (drop-stamps acc (item-uid g)))
    ?:  =('' updated.g)  acc
    =/  e=(unit entry:cal)  (~(get by entries.k) (item-uid g))
    ?.  &(?=(^ e) =(`updated.g (bind (get-prop:ics props.u.e 'X-GOOGLE-UPDATED') tail)))  acc
    (~(put by acc) (item-uid g) s+updated.g)
  =/  next-page=@t  (gs res 'nextPageToken')
  =/  next-tok=@t  (gs res 'nextSyncToken')
  =/  last=?  =('' next-page)
  ::  a full listing is the whole truth: what it did not name is gone (a
  ::  local change to one is kept in the conflict log)
  =/  gone=(list uid:cal)
    ?.  &(full last)  ~
    %+  murn  ~(tap by entries.k)
    |=  [u=uid:cal e=entry:cal]
    ?:  |((dav-is-child e) (~(has in seen) u))  ~
    ::  a task is never on Google (one that was an event there was taken
    ::  off by +google-push), so a listing without it says nothing of it
    ?:  ?=(%todo -.event.e)  ~
    ?.  (lien props.e |=([key=@t *] =('X-GOOGLE-ID' key)))  ~
    `u
  =/  gone-rows=(list [uid:cal (unit entry:cal) @t])
    (murn gone |=(u=uid:cal ?.((~(has in pending) u) ~ `[u (~(get by entries.k) u) ''])))
  =.  k  (roll gone |=([u=uid:cal acc=_k] (del-object acc u)))
  =.  stamps  (roll gone |=([u=uid:cal acc=_stamps] (drop-stamps acc u)))
  ::  an instance that came before its parent (on an earlier page) skips
  ::  it now
  =?  k  &(last |(full had-insts))  (reskip k)
  ::  what this pull wrote is not for pushing back, nor is the local
  ::  change a clash replaced
  =/  won=(set uid:cal)
    (~(gas in (~(gas in *(set uid:cal)) (turn clashes item-uid))) gone)
  =/  sup2=(set [@t @ud])
    (~(uni in (~(uni in sup) (wrote-between k seq-at-peek seq.k))) (rows-of k since won))
  =/  row2=json
    %+  row-put  row
    :~  ['sync_token' s+?:(=('' next-tok) tok next-tok)]
        ['last_ms' (numb:enjs:format (da-to-ms now))]
        ['ids' [%o ids]]
        ['stamps' [%o stamps]]
        ['suppressed' (suppress-json sup2 since)]
    ==
  ;<  ~  bind:m  (dav-write pre c(cals (~(put by cals.c) id k)))
  ;<  ~  bind:m  (log-clashes pre id clash-rows 'changed on both sides; google kept')
  ;<  ~  bind:m  (log-clashes pre id gone-rows 'deleted on google; changed here')
  ;<  ~  bind:m  (save-row pre 'google-sync.json' id ~[row] row2)
  ::  ponytail: 500 pages (125k events) and no more; a listing cut off
  ::  there is not last, so it deletes nothing
  ?.  last
    ?:  (gte pages 500)
      ;<  ~  bind:m
        %:  fault  pre  (cat 3 'google-pages/' id)  %warning  &
          "the Google listing of calendar {(trip id)} was cut at 500 pages, so nothing was deleted"
          "make the calendar smaller on Google, or unlink it"
        ==
      (pure:m row2)
    $(page next-page, row row2, pages +(pages))
  ;<  ~  bind:m  (unfault pre (cat 3 'google-pull/' id))
  ;<  ~  bind:m  (unfault pre (cat 3 'google-pages/' id))
  (pure:m row2)
++  google-stop  google-stop:core
::  +drop-stamps: a uid's Google stamp gone, and its instances' (u#...)
++  drop-stamps
  |=  [s=(map @t json) u=@t]
  ^-  (map @t json)
  =/  pre=tape  (weld (trip u) "#")
  =/  n=@ud  (lent pre)
  =/  kept=(map @t json)
    (malt (skip ~(tap by s) |=([key=@t *] =(pre (scag n (trip key))))))
  (~(del by kept) u)
::  +push-kids: a series' instances changed since the watermark, out as
::  edits of their Google instances: a pulled one's own id, else Google's
::  <series id>_<original start in UTC>. pgid is the series' Google id.
::  The body is the instance's own (no iCalUID: it is the series'), and
::  one the same as last sent is not sent. A refusal is logged like a
::  parent's.
++  push-kids
  |=  [pre=@t id=@ta base=tape q=tape pgid=@t since=@ud sup=(set [@t @ud]) kids=(list entry:cal)]
  =/  m  (fiber:fiber:nexus ,[(list [uid:cal @t @t @t @t @t (unit json)]) ?])
  ^-  form:m
  =|  out=(list [uid:cal @t @t @t @t @t (unit json)])
  |-
  ?~  kids  (pure:m [out |])
  =/  ch=entry:cal  i.kids
  ?:  |((lte seq.ch since) (~(has in sup) [uid.ch seq.ch]) ?=(%todo -.event.ch))  $(kids t.kids)
  =/  own=@t  =/(p (get-prop:ics props.ch 'X-GOOGLE-ID') ?~(p '' v.u.p))
  =/  iid=@t
    ?.  =('' own)  own
    =/  w=(unit when:ics)  (parse-when:ics props.ch 'RECURRENCE-ID')
    ?~  w  ''
    %-  crip
    %+  weld  "{(trip pgid)}_"
    ?-  -.u.w
      %day    (date-text:ics d.u.w)
      %utc    (weld (dt-text:ics d.u.w) "Z")
      %local  (weld (dt-text:ics (fall (place:rules `zone.u.w d.u.w) d.u.w)) "Z")
    ==
  ?:  =('' iid)  $(kids t.kids)
  ::  an instance's own private properties and reminders go without
  ::  nulls: a null there would clear what it shares with its series
  =/  body=json
    =/  b=json  (json-of:gcal ch ~)
    ?.  ?=([%o *] b)  b
    =/  o=(map @t json)  (~(del by (~(del by p.b) 'iCalUID')) 'recurrence')
    =/  clean  |=([m=(map @t json) k=@t] ?.((~(has by m) k) m (~(put by m) k (sans-nulls:gcal (~(got by m) k)))))
    [%o (clean (clean o 'extendedProperties') 'reminders')]
  =/  sent=@t  (scot %uv (sham body))
  ?:  =(`sent (bind (get-prop:ics props.ch 'X-GOOGLE-SENT') tail))  $(kids t.kids)
  =/  gtag=@t  =/(p (get-prop:ics props.ch 'X-GOOGLE-ETAG') ?~(p '' v.u.p))
  ;<  [status=@ud res=json]  bind:m
    %:  google-api-hdr  pre  %'PATCH'  "{base}/{(enc-seg:dav (trip iid))}{q}"  `body
      ?:(=('' gtag) ~ ~[['if-match' gtag]])
    ==
  ::  a stop (sign-in, quota, a server down) ends the pass with the
  ::  watermark kept, so this edit goes again
  ?:  (google-stop status res)
    ;<  ~  bind:m
      %:  fault  pre  (cat 3 'google-push/' id)  %error  (acts status)
        "Google stopped taking changes for calendar {(trip id)} (status {(a-co:co status)})"
        "check the Google sign-in and quota under Settings; the changes stay queued"
      ==
    (pure:m [out &])
  ?.  =(200 status)
    ;<  ~  bind:m
      %:  google-conflict  pre  id  uid.ch  `ch  (gs res 'updated')
        ?:  =(412 status)  'changed on both sides; google kept'
        (crip "google refused the instance edit ({(a-co:co status)})")
      ==
    $(kids t.kids)
  $(kids t.kids, out [[uid.ch (gs res 'id') (gs res 'updated') (gs res 'etag') (join-link:gcal res) sent ~] out])
::  +google-push: the calendar's log past the watermark, out. A parent
::  with a known Google id is patched, without one inserted; a delete
::  goes by the id map. Its children (overrides) changed since go out as
::  edits of their Google instances (+push-kids). A body the same as the
::  one last sent (X-GOOGLE-SENT) is not sent again, so moving one
::  instance does not mail the guests a change of the series. A
::  +google-stop status stops the pass and keeps the watermark.
++  google-push
  |=  [pre=@t id=@ta row=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  gid=@t  (gs row 'google_id')
  =/  since=@ud  (fall (gn row 'pushed_seq') 0)
  =/  ids=(map @t json)  (omap (obj:gcal row 'ids'))
  =/  stamps=(map @t json)  (omap (obj:gcal row 'stamps'))
  ;<  c=calendar:cal  bind:m  (read-cal pre)
  =/  k=(unit cal:cal)  (~(get by cals.c) id)
  ?~  k  (pure:m row)
  ::  a calendar made local (migrated) is never pushed, whatever row a
  ::  pass already in flight still holds
  ?.  ?=(%google kind.props.u.k)  (pure:m row)
  ?.  (gth seq.u.k since)  (pure:m row)
  =/  sup=(set [@t @ud])  (suppressed row)
  =/  changes=(list [uid:cal ?(%put %del)])  (changes-since u.k since sup)
  =/  base=tape  "/calendar/v3/calendars/{(enc-seg:dav (trip gid))}/events"
  =|  results=(list [=uid:cal gid=@t updated=@t etag=@t join=@t sent=@t guests=(unit json)])
  ::  conferenceDataVersion=1: a Meet asked for is made, and one there is
  ::  kept on a patch that does not name it. sendUpdates=all: Google mails
  ::  the guests an invite, a change or a cancellation, as its own page
  ::  does when told to. ponytail: every change of an event with guests
  ::  mails them; a per-edit choice if that is too chatty
  =/  q=tape  "?conferenceDataVersion=1&sendUpdates=all"
  =/  stopped=?  |
  =|  untie=(list uid:cal)
  |-
  ?^  changes
    =/  [u=uid:cal what=?(%put %del)]  i.changes
    =/  known=@t  =/(v (~(get by ids) u) ?:(?=([~ %s *] v) p.u.v ''))
    ::  Google Calendar has no tasks (they live in Google Tasks, another
    ::  API): an event made a task here goes from Google as if deleted
    =?  what  =/(e (~(get by entries.u.k) u) &(?=(^ e) ?=(%todo -.event.u.e)))  %del
    ?:  =(%del what)
      ?:  =('' known)  $(changes t.changes)
      ;<  [status=@ud res=json]  bind:m
        (google-api pre %'DELETE' "{base}/{(enc-seg:dav (trip known))}?sendUpdates=all" ~)
      ?:  (google-stop status res)
        ;<  ~  bind:m
          %:  fault  pre  (cat 3 'google-push/' id)  %error  (acts status)
            "Google stopped taking changes for calendar {(trip id)} (status {(a-co:co status)})"
            "check the Google sign-in and quota under Settings; the changes stay queued"
          ==
        $(changes ~, stopped &)
      ::  already gone (404, 410) is done; a refusal is logged, not retried
      ;<  ~  bind:m
        ?:  |((lth status 300) =(404 status) =(410 status))  (pure:(fiber:fiber:nexus ,~) ~)
        (google-conflict pre id u ~ '' (crip "google refused the delete ({(a-co:co status)})"))
      %=  $
        changes  t.changes
        ids      (~(del by ids) u)
        stamps   (drop-stamps stamps u)
        ::  a task that was an event there loses its Google ids, so a later
        ::  turn back into an event goes up anew, and a listing leaves it
        untie
          =/  e=(unit entry:cal)  (~(get by entries.u.k) u)
          ?.  &(?=(^ e) ?=(%todo -.event.u.e) |((lth status 300) =(404 status) =(410 status)))  untie
          [u untie]
      ==
    =/  e=(unit entry:cal)  (~(get by entries.u.k) u)
    ?~  e  $(changes t.changes)
    ?:  ?=(%todo -.event.u.e)  $(changes t.changes)
    =/  body=json  (json-of:gcal (anchored u.e) (object-exdates u.e (kids-of:cal u.k u)))
    =/  have=@t
      ?.  =('' known)  known
      =/  hit=(unit prop:ics)  (get-prop:ics props.u.e 'X-GOOGLE-ID')
      ?~(hit '' v.u.hit)
    ::  PATCH, not PUT: what Google holds that this side does not model
    ::  (guests, visibility, colors, other apps' properties) stays. If-Match
    ::  names the version last pulled: an edit made on Google since is a
    ::  412, logged below, and the next pull brings it
    =/  sent=@t  (scot %uv (sham body))
    ?:  &(!=('' have) =(`sent (bind (get-prop:ics props.u.e 'X-GOOGLE-SENT') tail)))
      ;<  [kres=(list [uid:cal @t @t @t @t @t (unit json)]) kstop=?]  bind:m
        (push-kids pre id base q have since sup (kids-of:cal u.k u))
      ?:  kstop  $(changes ~, stopped &, results (weld kres results))
      $(changes t.changes, results (weld kres results))
    =/  gtag=@t  =/(p (get-prop:ics props.u.e 'X-GOOGLE-ETAG') ?~(p '' v.u.p))
    ::  guests named for an event pulled before guests were read: Google's
    ::  list is fetched and merged in, or the patch would drop the guests
    ::  this side never saw. A fetch that fails sends no guests at all
    ;<  [body=json merged=?]  bind:m
      =/  n  (fiber:fiber:nexus ,[json ?])
      ?.  ?&  !=('' have)
              ?=(~ (get-prop:ics props.u.e 'X-GOOGLE-GUESTS'))
              ?=([%o *] body)
              (~(has by p.body) 'attendees')
          ==
        (pure:n [body |])
      ?>  ?=([%o *] body)
      ;<  [st=@ud cur=json]  bind:n  (google-api pre %'GET' "{base}/{(enc-seg:dav (trip have))}" ~)
      ?.  =(200 st)  (pure:n [[%o (~(del by p.body) 'attendees')] &])
      (pure:n [(merge-attendees:gcal body cur) &])
    ::  a merged body is not the one meta makes: not kept as sent
    =?  sent  merged  ''
    ;<  [status=@ud res=json]  bind:m
      ?:  =('' have)  (google-api pre %'POST' "{base}{q}" `(sans-nulls:gcal body))
      %:  google-api-hdr  pre  %'PATCH'  "{base}/{(enc-seg:dav (trip have))}{q}"  `body
        ?:(=('' gtag) ~ ~[['if-match' gtag]])
      ==
    ::  a 404 for an id only the entry's props named (the id map never
    ::  had it: an event that was a task, say) is put anew. One the map
    ::  had was deleted or moved on Google: logged below, and the pull
    ::  settles it (Google wins)
    ;<  [status=@ud res=json]  bind:m
      ?.  &(=(404 status) !=('' have) =('' known))  (pure:(fiber:fiber:nexus ,[@ud json]) [status res])
      (google-api pre %'POST' "{base}{q}" `(sans-nulls:gcal body))
    ?:  (google-stop status res)
      ;<  ~  bind:m
        %:  fault  pre  (cat 3 'google-push/' id)  %error  (acts status)
          "Google stopped taking changes for calendar {(trip id)} (status {(a-co:co status)})"
          "check the Google sign-in and quota under Settings; the changes stay queued"
        ==
      $(changes ~, stopped &)
    ?.  =(200 status)
      ;<  ~  bind:m
        %:  google-conflict  pre  id  u  e  (gs res 'updated')
          ?:  =(412 status)  'changed on both sides; google kept'
          ?:  =(404 status)  'google no longer has this event (deleted or moved there); the next full pull settles it'
          (crip "google refused the push ({(a-co:co status)})")
        ==
      $(changes t.changes)
    =/  new-gid=@t  (gs res 'id')
    ::  attendees sent: Google's list as it answers is meta's from now
    ::  on, and the event's guests are current (no merge next time)
    =/  guests=(unit json)
      ?.  &(?=([%o *] body) (~(has by p.body) 'attendees'))  ~
      =/  g=(unit gitem:gcal)  (item-of:gcal res)
      ?~  g  ~
      `(fall (~(get by (read-meta:ics ve.u.g)) 'guests') [%a ~])
    ;<  [kres=(list [uid:cal @t @t @t @t @t (unit json)]) kstop=?]  bind:m
      (push-kids pre id base q new-gid since sup (kids-of:cal u.k u))
    %=  $
      changes  ?:(kstop ~ t.changes)
      stopped  |(stopped kstop)
      ids      (~(put by ids) u s+new-gid)
      results  (weld kres [[u new-gid (gs res 'updated') (gs res 'etag') (join-link:gcal res) sent guests] results])
    ==
  ::  the ids and stamps Google handed back, onto a fresh read of the
  ::  calendar (a poke may have landed while we waited on the network).
  ::  The watermark is the seq read BEFORE the network, so such a poke
  ::  stays above it; the prop writes below are suppressed like a pull's.
  =/  seq-before=@ud  seq.u.k
  ;<  c=calendar:cal  bind:m  (read-cal pre)
  =/  kk=cal:cal  (fall (~(get by cals.c) id) fresh-cal:cal)
  =?  results  !?=(%google kind.props.kk)  ~
  =?  untie  !?=(%google kind.props.kk)  ~
  =/  seq-mid=@ud  seq.kk
  =.  kk
    %+  roll  results
    |=  [[u=uid:cal g=@t up=@t et=@t join=@t sent=@t guests=(unit json)] acc=_kk]
    =/  e=(unit entry:cal)  (~(get by entries.acc) u)
    ?~  e  acc
    ::  guests edited here while the push waited are the newer: Google's
    ::  answer does not replace them
    ::  (the event, not the seq: a kid's stamp moves its parent's seq)
    =?  guests  !=(`event.u.e (bind (~(get by entries.u.k) u) |=(b=entry:cal event.b)))  ~
    ::  the Meet Google made is the event's join link now; a request it
    ::  left pending comes back with a later pull
    =?  u.e  !=('' join)
      =/  m=meta:cal  (meta-of:cal event.u.e)
      u.e(event (put-meta:cal event.u.e (~(del by (~(put by m) 'conference' s+join)) 'call')))
    =?  u.e  ?=(^ guests)
      =/  m=meta:cal  (meta-of:cal event.u.e)
      u.e(event (put-meta:cal event.u.e (~(put by m) 'guests' u.guests)))
    =/  props=(list [@t @t])
      :-  ['X-GOOGLE-ID' g]
      :-  ['X-GOOGLE-UPDATED' up]
      :-  ['X-GOOGLE-ETAG' et]
      :-  ['X-GOOGLE-SENT' sent]
      =/  rest=(list [@t @t])
        (skip props.u.e |=([key=@t *] ?=(^ (find ~[key] `(list @t)`~['X-GOOGLE-ID' 'X-GOOGLE-UPDATED' 'X-GOOGLE-ETAG' 'X-GOOGLE-SENT']))))
      ?~(guests rest [['X-GOOGLE-GUESTS' '1'] (skip rest |=([key=@t *] =('X-GOOGLE-GUESTS' key)))])
    =.  u.e  u.e(props props)
    ::  a merged body is not the one meta makes, but meta now holds the
    ::  guests it sent: the body meta makes now is the one sent, so the
    ::  next push of nothing new (an instance's move) skips the series
    =?  props.u.e  &(=('' sent) ?=(^ guests) ?=(~ (parent-of:cal u.e)))
      =/  now-sent=@t  (scot %uv (sham (json-of:gcal (anchored u.e) (object-exdates u.e (kids-of:cal acc u)))))
      [['X-GOOGLE-SENT' now-sent] (skip props.u.e |=([key=@t *] =('X-GOOGLE-SENT' key)))]
    (put-entry:cal acc u.e)
  =.  kk
    %+  roll  untie
    |=  [u=uid:cal acc=_kk]
    =/  e=(unit entry:cal)  (~(get by entries.acc) u)
    ?~  e  acc
    (put-entry:cal acc u.e(props (skip props.u.e |=([key=@t *] =("X-GOOGLE-" (scag 9 (trip key)))))))
  ;<  ~  bind:m
    ?:  &(?=(~ results) ?=(~ untie))  (pure:(fiber:fiber:nexus ,~) ~)
    (dav-write pre c(cals (~(put by cals.c) id kk)))
  ;<  ~  bind:m  ?:(stopped (pure:(fiber:fiber:nexus ,~) ~) (unfault pre (cat 3 'google-push/' id)))
  =/  mark=@ud  ?:(stopped since seq-before)
  =.  stamps
    (roll results |=([[u=uid:cal * up=@t *] acc=_stamps] ?:(=('' up) acc (~(put by acc) u s+up))))
  %-  pure:m
  %+  row-put  row
  :~  ['ids' [%o ids]]
      ['stamps' [%o stamps]]
      ['pushed_seq' (numb:enjs:format mark)]
      ['suppressed' (suppress-json (~(uni in sup) (wrote-between kk seq-mid seq.kk)) mark)]
  ==
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
++  dav-origin  dav-origin:core
++  dav-href-path  dav-href-path:core
++  hdr-of  hdr-of:core
::  +caldav-request: the owner's routes under /apps/calendar/caldav/
++  caldav-request
  |=  [eyre-id=@ta req=inbound-request:eyre rest=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  jon=json
    (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
  =/  post=?  =('POST' method.request.req)
  ?:  ?=([%'subscriptions.json' ~] rest)
    ;<  rows=json  bind:m  (caldav-remotes '../')
    %+  send-json  eyre-id
    :-  %a
    %+  turn  ?:(?=([%o *] rows) ~(tap by p.rows) ~)
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
    ?:  =('' url)  (send-text eyre-id 400 'calendar: need url')
    ;<  now=@da  bind:m  get-time:io
    ;<  c=calendar:cal  bind:m  (read-cal '../')
    =/  id=@ta  (crip "c-{(trip (scot %uw (mug url)))}")
    ?:  (~(has by cals.c) id)  (send-text eyre-id 409 'calendar: already followed')
    =/  nm=@t  (gs jon 'name')
    =/  color=@t  (gs jon 'color')
    =/  k=cal:cal  (born now)
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
      (write-json-grub '../' 'caldav-remotes.json' [%o (~(put by ?:(?=([%o *] rows) p.rows ~)) id row)])
    ;<  ~  bind:m  (google-prod '../')
    (send-json eyre-id (pairs:enjs:format ~[['id' s+id]]))
  ?:  &(post ?=([%unsubscribe ~] rest))
    (drop-synced eyre-id (crip (trip (gs jon 'id'))) %caldav 'calendar: not followed')
  ?:  &(post ?=([%sync ~] rest))
    ;<  ~  bind:m  (google-prod '../')
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  (send-text eyre-id 404 'calendar: no such caldav route')
::  +caldav-changes: what changed on the remote since the token:
::  [href etag gone] per object, and the new token. sync-collection
::  first; a server that refuses it gets a PROPFIND and an etag diff.
::  No answer at all is a failure, not a reason to ask again: a late
::  answer would be taken for the next request's.
++  caldav-changes
  |=  [pre=@t id=@ta row=json]
  =/  m  (fiber:fiber:nexus ,(unit [changes=(list [href=tape etag=@t gone=?]) token=@t]))
  ^-  form:m
  =/  url=@t  (gs row 'url')
  =/  tok=@t  (gs row 'sync_token')
  =/  known=(map tape @t)
    %-  ~(gas by *(map tape @t))
    %+  turn  ~(tap by (omap (obj:gcal row 'ids')))
    |=([u=@t v=json] [(norm-href (trip (gs v 'href'))) (gs v 'etag')])
  =/  body=@t
    %-  crip
    ;:  weld
      "<?xml version=\"1.0\" encoding=\"utf-8\"?><D:sync-collection xmlns:D=\"DAV:\"><D:sync-token>"
      (trip tok)
      "</D:sync-token><D:sync-level>1</D:sync-level><D:prop><D:getetag/></D:prop></D:sync-collection>"
    ==
  ;<  [status=@ud * res=@t]  bind:m
    ::  Depth 0: RFC 6578 3.2 defines the report for no other
    (dav-fetch row %'REPORT' url `body ~[['content-type' 'application/xml; charset=utf-8'] ['depth' '0']])
  ?:  =(0 status)  (pure:m ~)
  ?:  =(207 status)
    =/  root=(unit manx)  (soft-xml res)
    ?~  root  (pure:m ~)
    =/  token=@t
      =/  el=(unit manx)  (kid:dav u.root %'sync-token')
      ?~(el tok (crip (text:dav u.el)))
    =/  changes=(list [href=tape etag=@t gone=?])
      %+  murn  (kids:dav u.root %response)
      |=  r=manx
      ^-  (unit [tape @t ?])
      =/  href=(unit tape)  (response-href r)
      ?~  href  ~
      =/  st=(unit manx)  (kid:dav r %status)
      ?:  &(?=(^ st) ?=(^ (find "404" (text:dav u.st))))  `[u.href '' &]
      =/  et=(unit manx)  (find-el:dav r %getetag)
      =/  e=@t  ?~(et '' (dav-unquote (crip (text:dav u.et))))
      ::  the etag our own push got back is our change, not the remote's
      ?:  &(!=('' e) =(`e (~(get by known) (norm-href u.href))))  ~
      `[u.href e |]
    (pure:m `[changes token])
  ::  fallback: list with PROPFIND and diff the etags
  ;<  [status2=@ud * res2=@t]  bind:m
    %-  dav-fetch
    :*  row  %'PROPFIND'  url
        `'<?xml version="1.0"?><D:propfind xmlns:D="DAV:"><D:prop><D:getetag/></D:prop></D:propfind>'
        ~[['content-type' 'application/xml; charset=utf-8'] ['depth' '1']]
    ==
  ?.  =(207 status2)
    ;<  ~  bind:m
      %:  fault  pre  (cat 3 'caldav-list/' id)  %error  |((acts status) (acts status2))
        "the remote would not list calendar {(trip id)} (status {(a-co:co status2)})"
        "check its address, username and password under Settings, Following"
      ==
    (pure:m ~)
  =/  root=(unit manx)  (soft-xml res2)
  ?~  root  (pure:m ~)
  =/  listed=(list [href=tape etag=@t])
    %+  murn  (kids:dav u.root %response)
    |=  r=manx
    ^-  (unit [tape @t])
    =/  href=(unit tape)  (response-href r)
    ?~  href  ~
    =/  et=(unit manx)  (find-el:dav r %getetag)
    `[u.href ?~(et '' (dav-unquote (crip (text:dav u.et))))]
  ::  the collection's own <response> must be there before its member
  ::  list is believed: an empty or truncated answer is a failure, and
  ::  an emptied calendar (the collection present, no members) is real
  =/  coll=tape  (with-slash (fall (dav-href-path (trip url)) ""))
  =/  coll-here=?
    %+  lien  (kids:dav u.root %response)
    |=  r=manx
    =/  h=(unit manx)  (kid:dav r %href)
    ?~  h  |
    =/  hp=(unit tape)  (dav-href-path (text:dav u.h))
    ?~  hp  |
    =(coll (with-slash u.hp))
  ?.  coll-here
    ;<  ~  bind:m
      %:  fault  pre  (cat 3 'caldav-list/' id)  %warning  &
        "the remote's listing of calendar {(trip id)} left out the calendar itself, so nothing was deleted"
        "check its address under Settings, Following"
      ==
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
  ::  no token from a listing: the next pass asks sync-collection afresh
  ::  (a server that refused an old token answers a new one)
  (pure:m `[(weld changed gone) ''])
++  response-href  response-href:core
++  with-slash  with-slash:core
++  norm-href  norm-href:core
::  +caldav-pull: fetch every changed object, then apply them all onto
::  one read of the calendar
++  caldav-pull
  |=  [pre=@t id=@ta row=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ::  a calendar gone or made local asks nothing of the remote
  ;<  c0=calendar:cal  bind:m  (read-cal pre)
  ?.  (kind-is c0 id %caldav)  (pure:m row)
  =/  url=@t  (gs row 'url')
  =/  origin=tape  (dav-origin url)
  ;<  got=(unit [changes=(list [href=tape etag=@t gone=?]) token=@t])  bind:m  (caldav-changes pre id row)
  ?~  got
    ::  the row remembers that the remote could not be listed, for the UI
    %-  pure:m
    (row-put row ~[['error' s+'could not list the remote calendar (no answer, a server that refuses X-HTTP-Method-Override, or an incomplete answer)']])
  =/  ids=(map @t json)  (omap (obj:gcal row 'ids'))
  =/  by-href=(map tape @t)
    %-  ~(gas by *(map tape @t))
    (turn ~(tap by ids) |=([u=@t v=json] [(norm-href (trip (gs v 'href'))) u]))
  ::  1. the network: every changed object's text. No answer ends the
  ::  loop: a late answer would be taken for the next GET's.
  =|  fetched=(list [href=tape etag=@t gone=? body=@t])
  =/  failed=?  |
  =/  todo=(list [href=tape etag=@t gone=?])  changes.u.got
  |-
  ?^  todo
    ?:  gone.i.todo  $(todo t.todo, fetched [[href.i.todo '' & ''] fetched])
    ;<  [status=@ud hs=(list [@t @t]) body=@t]  bind:m
      (dav-fetch row %'GET' (crip (weld origin href.i.todo)) ~ ~)
    ?:  =(0 status)
      $(todo ~, failed &)
    ?.  =(200 status)
      ::  a miss keeps the old token, so the next pass asks again
      $(todo t.todo, failed &)
    =/  et=@t  ?:(=('' etag.i.todo) (dav-unquote (hdr-of hs 'etag')) etag.i.todo)
    $(todo t.todo, fetched [[href.i.todo et | body] fetched])
  ::  2. the calendar, once, read and written with nothing waiting between
  ::  (+edit-cals): the clock first, the conflicts after
  ;<  now=@da  bind:m  get-time:io
  ;<  c=calendar:cal  bind:m  (read-cal pre)
  =/  k=cal:cal  (fall (~(get by cals.c) id) fresh-cal:cal)
  ?.  ?=(%caldav kind.props.k)  (pure:m row)
  =/  k=cal:cal  k
  ::  a fetched object (or a remote delete) whose uid also changed here
  ::  since the last push, when the apply really replaces the local
  ::  copy, is a conflict: the remote wins, the local copy is logged
  =/  since=@ud  (fall (gn row 'pushed_seq') 0)
  =/  sup=(set [@t @ud])  (suppressed row)
  =/  pending=(set uid:cal)  (pending-uids k since sup)
  =/  seq-at-peek=@ud  seq.k
  =/  res=[k=cal:cal ids=(map @t json) clashes=(list [uid:cal (unit entry:cal) @t])]
    %+  roll  (flop fetched)
    |=  [[href=tape etag=@t gone=? body=@t] acc=_[k=k ids=ids clashes=*(list [uid:cal (unit entry:cal) @t])]]
    ?:  gone
      =/  u=(unit @t)  (~(get by by-href) href)
      ?~  u  acc
      ::  the uid moved to another href in this same listing (put before
      ::  this): the old name is gone, the event is not
      =/  now-at=tape  (norm-href (trip (gs (fall (~(get by ids.acc) u.u) ~) 'href')))
      ?.  =(now-at href)  acc
      =/  old=(unit entry:cal)  (~(get by entries.k.acc) u.u)
      =?  clashes.acc  &(?=(^ old) (~(has in pending) u.u))  [[u.u old ''] clashes.acc]
      acc(k (del-object k.acc u.u), ids (~(del by ids.acc) u.u))
    ::  a remote's object is read softly: one it cannot phrase is skipped
    =/  put=(unit [k=cal:cal =uid:cal])
      (fall (mole |.((put-object k.acc (events:ics body) zone.c '' ~))) ~)
    ?~  put  acc
    =/  old=(unit entry:cal)  (~(get by entries.k.acc) uid.u.put)
    =?  clashes.acc  &(?=(^ old) (~(has in pending) uid.u.put) !=(k.acc k.u.put))  [[uid.u.put old ''] clashes.acc]
    =.  k.acc  k.u.put
    acc(ids (~(put by ids.acc) uid.u.put (pairs:enjs:format ~[['href' s+(crip href)] ['etag' s+etag]])))
  =/  won=(set uid:cal)  (~(gas in *(set uid:cal)) (turn clashes.res |=([u=uid:cal *] u)))
  =/  sup2=(set [@t @ud])
    (~(uni in (~(uni in sup) (wrote-between k.res seq-at-peek seq.k.res))) (rows-of k.res since won))
  =/  row2=json
    %+  row-put  row
    :~  ['sync_token' s+?:(failed (gs row 'sync_token') token.u.got)]
        ['last_ms' (numb:enjs:format (da-to-ms now))]
        ['error' s+'']
        ['ids' [%o ids.res]]
        ['suppressed' (suppress-json sup2 since)]
    ==
  ;<  ~  bind:m
    ?:  =(k.res k)  (pure:(fiber:fiber:nexus ,~) ~)
    (dav-write pre c(cals (~(put by cals.c) id k.res)))
  ;<  ~  bind:m  (log-clashes pre id clashes.res 'changed on both sides; the remote kept')
  ;<  ~  bind:m  (save-row pre 'caldav-remotes.json' id ~[row] row2)
  ::  the listing answered; objects it could not fetch stand as a fault,
  ::  counted, never one line each
  ;<  ~  bind:m  (unfault pre (cat 3 'caldav-list/' id))
  ;<  ~  bind:m
    ?.  failed  (unfault pre (cat 3 'caldav-get/' id))
    %:  fault  pre  (cat 3 'caldav-get/' id)  %warning  |
      "some objects of calendar {(trip id)} could not be fetched"
      "the next pass asks for them again"
    ==
  (pure:m row2)
::  +caldav-push: the log past the watermark, out as PUT and DELETE. No
::  answer, a server error or refused credentials stop the pass and keep
::  the watermark; a remote that refuses one object (a read-only
::  calendar's 403, a remote without VTODO refusing a task, RFC 4791
::  5.3.2.1) is that object's refusal, logged.
++  caldav-push
  |=  [pre=@t id=@ta row=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  url=@t  (gs row 'url')
  =/  origin=tape  (dav-origin url)
  =/  since=@ud  (fall (gn row 'pushed_seq') 0)
  =/  ids=(map @t json)  (omap (obj:gcal row 'ids'))
  ;<  c=calendar:cal  bind:m  (read-cal pre)
  =/  k=(unit cal:cal)  (~(get by cals.c) id)
  ?~  k  (pure:m row)
  ?.  ?=(%caldav kind.props.u.k)  (pure:m row)
  ?.  (gth seq.u.k since)  (pure:m row)
  =/  sup=(set [@t @ud])  (suppressed row)
  =/  changes=(list [uid:cal ?(%put %del)])  (changes-since u.k since sup)
  ;<  now=@da  bind:m  get-time:io
  =/  stopped=?  |
  =/  coll=tape  (with-slash (norm-href (trip url)))
  |-
  ?^  changes
    =/  [u=uid:cal what=?(%put %del)]  i.changes
    =/  known=json  (fall (~(get by ids) u) [%o ~])
    =/  href=tape
      =/  h=@t  (gs known 'href')
      ?.  =('' h)  (norm-href (trip h))
      (weld coll (weld (enc-seg:dav (trip u)) ".ics"))
    =/  etag=@t  (gs known 'etag')
    ?:  =(%del what)
      ?:  =('' (gs known 'href'))  $(changes t.changes)
      ;<  [status=@ud * *]  bind:m  (dav-fetch row %'DELETE' (crip (weld origin href)) ~ ~)
      ?:  |(=(0 status) (gte status 500) =(401 status))
        ;<  ~  bind:m
          %:  fault  pre  (cat 3 'caldav-push/' id)  %error  =(401 status)
            "the remote did not take changes for calendar {(trip id)} (status {(a-co:co status)})"
            "check its username and password under Settings, Following; the changes stay queued"
          ==
        $(changes ~, stopped &)
      ;<  ~  bind:m
        ?:  |((lth status 300) =(404 status) =(410 status))  (pure:(fiber:fiber:nexus ,~) ~)
        (google-conflict pre id u ~ '' (crip "remote refused the delete ({(a-co:co status)})"))
      $(changes t.changes, ids (~(del by ids) u))
    =/  body=(unit @t)  (dav-object-ics c id u now)
    ?~  body  $(changes t.changes)
    ;<  [status=@ud hs=(list [@t @t]) res=@t]  bind:m
      %-  dav-fetch
      :*  row  %'PUT'  (crip (weld origin href))  body
          :-  ['content-type' 'text/calendar; charset=utf-8']
          ?:(=('' etag) ~ ~[['if-match' (crip "\"{(trip etag)}\"")]])
      ==
    ?:  |(=(0 status) (gte status 500) =(401 status))
      ;<  ~  bind:m
        %:  fault  pre  (cat 3 'caldav-push/' id)  %error  =(401 status)
          "the remote did not take changes for calendar {(trip id)} (status {(a-co:co status)})"
          "check its username and password under Settings, Following; the changes stay queued"
        ==
      $(changes ~, stopped &)
    ::  anything but a 2xx did not store it: a redirect (a server moved
    ::  to https, say) is no success
    ?:  |((lth status 200) (gte status 300))
      ;<  ~  bind:m
        (google-conflict pre id u (~(get by entries.u.k) u) '' (crip "remote refused the push ({(a-co:co status)})"))
      $(changes t.changes)
    =/  new-etag=@t  (dav-unquote (hdr-of hs 'etag'))
    %=  $
      changes  t.changes
      ids      (~(put by ids) u (pairs:enjs:format ~[['href' s+(crip href)] ['etag' s+new-etag]]))
    ==
  ;<  ~  bind:m  ?:(stopped (pure:(fiber:fiber:nexus ,~) ~) (unfault pre (cat 3 'caldav-push/' id)))
  =/  mark=@ud  ?:(stopped since seq.u.k)
  %-  pure:m
  %+  row-put  row
  :~  ['ids' [%o ids]]
      ['pushed_seq' (numb:enjs:format mark)]
      ['suppressed' (suppress-json sup mark)]
  ==
::  ---- sharing a calendar with a ship ----
++  cal-instance  cal-instance:core
++  ug-base  ug-base:core
++  public-grp  public-grp:core
++  group-name  group-name:core
::  +ug-read-weir: a group's how
++  ug-read-weir
  |=  gdir=path
  =/  m  (fiber:fiber:nexus ,weir:nexus)
  ^-  form:m
  ;<  hv=(unit view:nexus)  bind:m  (peek-soft:io [%& %& gdir %'how.weir'] ~)
  ?~  hv  (pure:m *weir:nexus)
  ?.  ?=([%file *] u.hv)  (pure:m *weir:nexus)
  (pure:m (fall (mole |.(;;(weir:nexus (sang-noun:tarball sang.u.hv)))) *weir:nexus))
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
  ?:  (~(has in poke.old) road)  (unfault './' 'road/inbox')
  ;<  reg=(unit tang)  bind:m  (reg-register-at-soft:io [u.base %'shares.sig'])
  ?^  reg
    %:  fault  './'  'road/inbox'  %warning  &
      "the registry road is refused, so other ships cannot send edits to calendars shared with them"
      "grant /sys/ames/registry at /apps/grubbery/permits, then reload the calendar"
    ==
  ::  the registry names a group by its short name and takes only OUR
  ::  roads: a %how replaces every road under our prefix in that group
  ::  and leaves the other apps' roads alone
  ;<  err=(unit tang)  bind:m  (reg-how-soft:io /public [~ (sy road ~) ~])
  ?^  err
    %:  fault  './'  'road/inbox'  %warning  &
      "the share inbox road could not be laid in the public group, so other ships cannot send edits"
      "grant /sys/ames/usergroups at /apps/grubbery/permits, then reload the calendar"
    ==
  (unfault './' 'road/inbox')
++  ship-read-only  ship-read-only:core
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
::  +share-pass: the host side. Every shared calendar's file follows its
::  calendar, rebuilt when its seq, name or color moved. A shared
::  calendar that is gone (deleted, unlinked, unfollowed) is unshared:
::  its record, its groups and its file go, so a calendar that later
::  gets the same id is not published to the old peers.
::  +invite-max: the largest invitation a ship sends or takes (an object
::  with thousands of moved instances is not an invitation)
++  invite-max  131.072
::  +invite-cap: the most unplaced invitations an inbox keeps
++  invite-cap  100
::  +clean-ships: a host's guest list as a guest keeps it: a ship and its
::  status each, nothing else and nothing long (any ship can send one)
++  clean-ships
  |=  s=(unit json)
  ^-  json
  :-  %a
  ?.  ?=([~ %a *] s)  ~
  %+  murn  p.u.s
  |=  g=json
  ^-  (unit json)
  ?.  ?=([%o *] g)  ~
  =/  who=(unit @p)  (biff (~(get by p.g) 'ship') |=(j=json ?.(?=([%s *] j) ~ (slaw %p p.j))))
  ?~  who  ~
  =/  st=@t  (gs g 'status')
  `(pairs:enjs:format ~[['ship' s+(scot %p u.who)] ['status' s+?:((gth (met 3 st) 32) '' st)]])
::  +sans-stamp: an object's text less its DTSTAMP lines, the moment it
::  was written, which differs each time the same object is sent
++  sans-stamp
  |=  t=@t
  ^-  @t
  (of-wain:format (skip (to-wain:format t) |=(l=@t =("DTSTAMP" (scag 7 (trip l))))))
::  +host-copy: the copy of host's invitation u, on the calendar named
::  if it is there, else wherever the owner moved it. ~ when there is
::  none, or the entry under that UID is not the host's
++  host-copy
  |=  [c=calendar:cal named=@t u=@t host=@p]
  ^-  (unit [cid=@ta e=entry:cal])
  =/  theirs  |=(e=entry:cal =(`s+(scot %p host) (~(get by (meta-of:cal event.e)) 'host')))
  =/  nid=@ta  (crip (trip named))
  =/  here=(unit entry:cal)  (biff (~(get by cals.c) nid) |=(k=cal:cal (~(get by entries.k) u)))
  ?:  &(?=(^ here) (theirs u.here))  `[nid u.here]
  =/  all=(list [cid=@ta e=entry:cal])
    %+  murn  ~(tap by cals.c)
    |=  [cid=@ta k=cal:cal]
    ^-  (unit [cid=@ta e=entry:cal])
    =/  e=(unit entry:cal)  (~(get by entries.k) u)
    ?.  &(?=(^ e) (theirs u.e))  ~
    `[cid u.e]
  ?~(all ~ `i.all)
::  +own-guests: an object a peer wrote into a calendar linked to Google,
::  with our guests and organizer (none for a new one) in it and its
::  instances: Google mails whoever an event names, from our account
++  own-guests
  |=  [old=cal:cal new=cal:cal u=uid:cal]
  ^-  cal:cal
  =/  es=(list entry:cal)
    =/  p=(unit entry:cal)  (~(get by entries.new) u)
    (weld ?~(p ~ ~[u.p]) (kids-of:cal new u))
  %+  roll  es
  |=  [e=entry:cal acc=_new]
  =/  was=meta:cal  (fall (bind (~(get by entries.old) uid.e) |=(o=entry:cal (meta-of:cal event.o))) ~)
  =/  keys=(list @t)  ~['guests' 'organizer']
  =/  mt=meta:cal  (roll keys |=([key=@t a=_(meta-of:cal event.e)] (~(del by a) key)))
  =.  mt  (~(gas by mt) (murn keys |=(key=@t (bind (~(get by was) key) |=(v=json [key v])))))
  ?:  =(mt (meta-of:cal event.e))  acc
  (put-entry:cal acc e(event (put-meta:cal event.e mt)))
++  key-ok  key-ok:core
++  endpoint-ok  endpoint-ok:core
::  +invite-ships: the guest ships an event's meta names (meta ships, each
::  {ship, status}). They are not meta guests, which are the file's and
::  Google's: a pull or a client's PUT would wipe ships out of those
++  invite-ships
  |=  mt=meta:cal
  ^-  (list @p)
  =/  sl=(unit json)  (~(get by mt) 'ships')
  ?.  ?=([~ %a *] sl)  ~
  %+  murn  p.u.sl
  |=(g=json ?.(?=([%o *] g) ~ =/(s (~(get by p.g) 'ship') ?.(?=([~ %s *] s) ~ (slaw %p p.u.s)))))
::  +invite-pass: the host side of invitations to one event. Each event of
::  ours whose meta names guest ships goes to each of them when it changed
::  (its etag) since it was sent; a ship no longer named, or an event gone,
::  gets a cancel. A copy of someone else's invitation (meta host) is not
::  ours to send. Sent is not delivered: a ship that is down is tried
::  again an hour on, and one on an older calendar takes the poke and
::  drops it. Changed means its +invite-tag: a guest's answer is not
::  news to the rest, nor is our own Google push's stamp.
++  invite-pass
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  c=calendar:cal  bind:m  (read-cal './')
  ;<  sj=json  bind:m  (read-json-grub './' 'invites-sent.json')
  ;<  now=@da  bind:m  get-time:io
  ;<  our=@p  bind:m  get-our:io
  =/  sent=(map @t json)  (omap sj)
  =/  now-ms=@ud  (da-to-ms now)
  ::  tried within the hour and not heard: not yet again
  =/  waiting
    |=  row=json
    ?&  ?=([~ %b %.n] (~(get by (omap row)) 'ok'))
        (lth (sub now-ms (min now-ms (fall (gn row 'at_ms') 0))) 3.600.000)
    ==
  ::  a moved instance rides in its series' object, and our own ship is
  ::  not a guest to send to
  ::  nor is a calendar another ship shares with us ours to invite from
  =/  want=(map @t [cid=@ta e=entry:cal ships=(list @p) tag=@t])
    %-  malt
    ^-  (list [@t [@ta entry:cal (list @p) @t]])
    %-  zing
    %+  turn  ~(tap by cals.c)
    |=  [cid=@ta k=cal:cal]
    ?:  ?=(%ship kind.props.k)  ~
    %+  murn  ~(val by entries.k)
    |=  e=entry:cal
    ?:  (dav-is-child e)  ~
    =/  mt=meta:cal  (meta-of:cal event.e)
    ?:  (~(has by mt) 'host')  ~
    =/  ss=(list @p)  (skip (invite-ships mt) |=(s=@p =(our s)))
    ?~  ss  ~
    `[(crip "{(trip cid)}/{(trip uid.e)}") cid e ss (invite-tag k e)]
  ::  the guest keeps an invitation by uid alone: one sent under another
  ::  key (the event moved to another of our calendars) is forgotten,
  ::  not cancelled
  =/  uid-of  |=(key=@t `@t`(crip (slag +((fall (find "/" (trip key)) 0)) (trip key))))
  =/  wanted=(set [@t @p])
    %-  silt
    ^-  (list [@t @p])
    %-  zing
    %+  turn  ~(tap by want)
    |=  [key=@t cid=@ta e=entry:cal ss=(list @p) tag=@t]
    ^-  (list [@t @p])
    (turn ss |=(s=@p [(uid-of key) s]))
  =.  sent
    %-  malt
    %+  murn  ~(tap by sent)
    |=  [key=@t v=json]
    ^-  (unit [@t json])
    =/  keep=(map @t json)
      %-  malt
      %+  skip  ~(tap by (omap v))
      |=  [t=@t *]
      =/  s=(unit @p)  (slaw %p t)
      ?~  s  |
      &(!(~(has by want) key) (~(has in wanted) [(uid-of key) u.s]))
    ?:(=(~ keep) ~ `[key [%o keep]])
  ::  a row from before the tag holds the entry's etag then: what it
  ::  names is what the guest has, so it takes the tag without a resend
  =.  sent
    %-  ~(urn by sent)
    |=  [key=@t v=json]
    =/  w  (~(get by want) key)
    ?~  w  v
    ?.  ?=([%o *] v)  v
    :-  %o
    %-  ~(run by p.v)
    |=  row=json
    ?.  =(etag.e.u.w (gs row 'etag'))  row
    (row-put row ~[['etag' s+tag.u.w]])
  ::  every (event, ship) to tell: an invite, or a cancel
  =/  jobs=(list [key=@t to=@p cancel=?])
    %+  weld
      ^-  (list [@t @p ?])
      %-  zing
      %+  turn  ~(tap by want)
      |=  [key=@t cid=@ta e=entry:cal ss=(list @p) tag=@t]
      ^-  (list [@t @p ?])
      %+  murn  ss
      |=  s=@p
      ^-  (unit [@t @p ?])
      =/  row=json  (obj:gcal (fall (~(get by sent) key) [%o ~]) (scot %p s))
      ?:  &(=(tag (gs row 'etag')) |(=([~ %b %.y] (~(get by (omap row)) 'ok')) (waiting row)))  ~
      `[key s |]
    ^-  (list [@t @p ?])
    %-  zing
    %+  turn  ~(tap by sent)
    |=  [key=@t v=json]
    ^-  (list [@t @p ?])
    =/  w  (~(get by want) key)
    =/  have=(list @p)  ?~(w ~ ships.u.w)
    %+  murn  ~(tap by (omap v))
    |=  [t=@t row=json]
    ^-  (unit [@t @p ?])
    =/  s=(unit @p)  (slaw %p t)
    ?~  s  ~
    ?^  (find ~[u.s] have)  ~
    ?:  (waiting row)  ~
    `[key u.s &]
  =/  left=(list [key=@t to=@p cancel=?])  jobs
  ::  a guest that did not answer is not tried again this pass: each
  ::  try would wait 30 s
  =|  down=(set @p)
  |-
  ?~  left
    ?:  =(sent (omap sj))  (pure:m ~)
    (write-json-grub './' 'invites-sent.json' [%o sent])
  =/  j  i.left
  =/  uid=@t  (uid-of key.j)
  =/  w=(unit [cid=@ta e=entry:cal ships=(list @p) tag=@t])  (~(get by want) key.j)
  =/  body=json
    ?:  |(cancel.j ?=(~ w))
      (pairs:enjs:format ~[['action' s+'invite-cancel'] ['uid' s+uid]])
    =/  mt=meta:cal  (meta-of:cal event.e.u.w)
    %-  pairs:enjs:format
    :~  ['action' s+'invite']
        ['uid' s+uid]
        ['ics' s+(fall (dav-object-ics c cid.u.w uid now) '')]
        ['name' s+(meta-str:cal mt 'name')]
        :-  'start_ms'
        %-  numb:enjs:format
        %-  da-to-ms
        =/  ev=event:cal  event.e.u.w
        ?-(-.ev %timed start.recur.ev, %allday start.recur.ev, %date *@da, %todo (fall due.ev *@da))
        ::  a guest takes 100 at most (+clean-ships keeps them short)
        ['ships' (scag-json 100 (clean-ships (~(get by mt) 'ships')))]
    ==
  ::  an event too big to send is not sent, nor tried again until it
  ::  changes; the owner is told
  =/  too-big=?  (gth (met 3 (gs body 'ics')) invite-max)
  ;<  ~  bind:m
    ?.  too-big  (pure:(fiber:fiber:nexus ,~) ~)
    %:  fault  './'  (cat 3 'invite/' uid)  %warning  &
      "the event {(trip (gs body 'name'))} is too big to send as an invitation"
      "take some of its moved occurrences or its note out; it is sent when it changes"
    ==
  ::  the too-big fault clears on a send that fits, or with the event
  ::  gone (a cancel while it stands is another guest taken off)
  ;<  ~  bind:m
    ?:  |(too-big &(cancel.j ?=(^ w)))  (pure:(fiber:fiber:nexus ,~) ~)
    (unfault './' (cat 3 'invite/' uid))
  ;<  ok=?  bind:m
    ?:  too-big  (pure:(fiber:fiber:nexus ,?) &)
    ?:  (~(has in down) to.j)  (pure:(fiber:fiber:nexus ,?) |)
    (remote-poke-wait to.j [%& cal-instance %'shares.sig'] body)
  =?  down  !ok  (~(put in down) to.j)
  =/  rows=(map @t json)  (omap (fall (~(get by sent) key.j) [%o ~]))
  =/  stamp  |=(et=@t (pairs:enjs:format ~[['etag' s+et] ['ok' b+ok] ['at_ms' (numb:enjs:format now-ms)]]))
  =.  rows
    ?:  cancel.j
      ::  a cancel not heard stays, to be sent again within the hour
      ?:(ok (~(del by rows) (scot %p to.j)) (~(put by rows) (scot %p to.j) (stamp '')))
    (~(put by rows) (scot %p to.j) (stamp ?~(w '' tag.u.w)))
  =.  sent  ?:(=(~ rows) (~(del by sent) key.j) (~(put by sent) key.j [%o rows]))
  $(left t.left)
::  +invite-tag: what a guest is sent again on: the event and its moved
::  instances, less the guests' answers and the Google stamps a push
::  writes
++  invite-tag
  |=  [k=cal:cal e=entry:cal]
  ^-  @t
  =/  bare
    |=  x=entry:cal
    =/  mt=meta:cal  (meta-of:cal event.x)
    =?  mt  (~(has by mt) 'ships')
      (~(put by mt) 'ships' [%a (turn (invite-ships mt) |=(s=@p s+(scot %p s)))])
    ::  less the Google stamps, and the kids' hash (their props and
    ::  alarms move with every push): the kids are hashed themselves
    :-  (put-meta:cal event.x mt)
    (skip props.x |=([key=@t *] |(=("X-GOOGLE-" (scag 9 (trip key))) =('X-GRUBBERY-KIDS' key))))
  (scot %uv (sham [(bare e) (turn (kids-of:cal k uid.e) bare)]))
::  +scag-json: the first n of a json array
++  scag-json
  |=  [n=@ud j=json]
  ^-  json
  ?.(?=([%a *] j) j [%a (scag n p.j)])
::  +talon-room: an event's call room on trunk, a @tas from its calendar
::  and uid: the same every time, so asking again finds the same link
++  talon-room
  |=  [cid=@ta =uid:cal]
  ^-  @t
  (crip "e-{((x-co:co 16) (end [3 8] (sham cid uid)))}")
::  +talon-pass: Talon calls (trunk wire 19). An event of ours whose meta
::  asks for one (call 'talon') and has no join link yet gets a link from
::  trunk: it becomes the join link (meta conference), goes into the note
::  for guests who read only that, and its room is kept (meta talon_room,
::  talon-rooms.json). A room whose event is gone, or no longer names it
::  (the call was taken off), is closed, which ends its link. A refusal
::  is a fault saying what to do, asked again when the event changes or
::  an hour on. A copy of another ship's invitation, a moved instance and
::  a calendar another ship shares with us are not ours to give a room
++  talon-pass
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  c=calendar:cal  bind:m  (read-cal './')
  ;<  rj=json  bind:m  (read-json-grub './' 'talon-rooms.json')
  ;<  now=@da  bind:m  get-time:io
  =/  rooms=(map @t json)  (omap rj)
  =/  now-ms=@ud  (da-to-ms now)
  =/  want=(list [room=@t cid=@ta e=entry:cal])
    %-  zing
    %+  turn  ~(tap by cals.c)
    |=  [cid=@ta k=cal:cal]
    ^-  (list [@t @ta entry:cal])
    ?:  ?=(%ship kind.props.k)  ~
    %+  murn  ~(val by entries.k)
    |=  e=entry:cal
    ^-  (unit [@t @ta entry:cal])
    ?:  (dav-is-child e)  ~
    =/  mt=meta:cal  (meta-of:cal event.e)
    ?:  (~(has by mt) 'host')  ~
    ?.  =('talon' (meta-str:cal mt 'call'))  ~
    ?.  =('' (meta-str:cal mt 'conference'))  ~
    =/  r=@t  (talon-room cid uid.e)
    =/  row=json  (fall (~(get by rooms) r) [%o ~])
    ?:  ?&  =(etag.e (gs row 'etag'))
            (lth (sub now-ms (min now-ms (fall (gn row 'at_ms') 0))) 3.600.000)
        ==
      ~
    `[r cid e]
  =/  ends=(list @t)
    %+  murn  ~(tap by rooms)
    |=  [r=@t row=json]
    ^-  (unit @t)
    ::  on the calendar it was made on, or the one the event moved to
    =/  k=(unit cal:cal)  (~(get by cals.c) (crip (trip (gs row 'cal'))))
    =/  e=(unit entry:cal)
      =/  here=(unit entry:cal)  ?~(k ~ (~(get by entries.u.k) (gs row 'uid')))
      ?^  here  here
      (bind (find-entry:cal c (gs row 'uid')) |=([* e=entry:cal] e))
    ?~  e  `r
    =/  mt=meta:cal  (meta-of:cal event.u.e)
    ::  still asking for one, or holding this one: kept
    ?:  =(`s+r (~(get by mt) 'talon_room'))  ~
    ?:  &(=('' (gs row 'url')) =('talon' (meta-str:cal mt 'call')))  ~
    `r
  ?:  &(?=(~ want) ?=(~ ends))  (pure:m ~)
  ;<  wire=@ud  bind:m  trunk-wire
  ?:  (lth wire 19)
    ;<  ~  bind:m
      ?~  want  (pure:(fiber:fiber:nexus ,~) ~)
      %:  fault  './'  'talon'  %warning  &
        "a Talon call needs trunk wire 19 and a grubbery whose trunk mark carries app links; this ship has not got both yet"
        "update trunk and grubbery; the call is made once they are"
      ==
    (write-json-grub './' 'talon-rooms.json' [%o (stamp-rooms rooms want now-ms '' '')])
  ;<  our=@p  bind:m  get-our:io
  =/  dir=path  /sys/gall/subs/(scot %p our)/trunk/app/grubbery/calendar
  ::  rooms to close first: one poke ends the room and its link. One
  ::  trunk did not take stays, to be closed on the next pass
  ::  A nack is final (trunk will not take it); one not answered stops
  ::  the closing for this pass (trunk is suspended: each would wait 30 s)
  =/  close=(list @t)  ends
  ::  trunk silent once (suspended): nothing more asked of it this pass
  =/  late=?  |
  |-
  ?^  close
    ;<  done=trunk-res  bind:m  (trunk-poke [%app-room-close-as 'calendar' i.close])
    =?  rooms  ?=(?(%sent %nacked) done)  (~(del by rooms) i.close)
    $(close ?:(?=(%late done) ~ t.close), late |(late ?=(%late done)))
  ?:  late
    (write-json-grub './' 'talon-rooms.json' [%o rooms])
  ?~  want
    (write-json-grub './' 'talon-rooms.json' [%o rooms])
  ::  trunk's answers come as facts kept under /sys/gall/subs: the road
  ::  to read them names this ship, so the owner grants it by hand
  ;<  watch=?(%live %refused %failed)  bind:m  (talon-watch dir)
  ?:  ?=(%refused watch)
    ;<  ~  bind:m
      %:  fault  './'  'road/talon'  %warning  &
        "the peek road {(spud dir)}/ is refused, so Talon calls cannot be made"
        "grant that road (this one only, not /sys/gall/subs/) at /apps/grubbery/permits"
      ==
    (write-json-grub './' 'talon-rooms.json' [%o (stamp-rooms rooms want now-ms '' '')])
  ;<  ~  bind:m  (unfault './' 'road/talon')
  =/  w  i.want
  =/  title=@t  (end [3 128] (meta-str:cal (meta-of:cal event.e.w) 'name'))
  ::  the request's own id: the last fact kept may be an older answer for
  ::  the same room
  ;<  now=@da  bind:m  get-time:io
  =/  req=@t  (crip "{(trip room.w)}.{(a-co:co (da-to-ms now))}")
  ;<  sent=trunk-res  bind:m
    (trunk-poke [%app-guest-link-as 'calendar' room.w title & req])
  =?  late  ?=(%late sent)  &
  ;<  got=(unit [url=@t why=@t])  bind:m
    =/  n  (fiber:fiber:nexus ,(unit [@t @t]))
    ?:  ?=(%refused sent)  (pure:n `['' 'the gall road /sys/gall/ is refused'])
    ?:  ?=(%nacked sent)  (pure:n `['' 'this grubbery cannot hand trunk an app link'])
    ?:  ?=(%late sent)  (pure:n ~)
    (talon-answer dir req)
  =/  url=@t  ?~(got '' url.u.got)
  =/  why=@t  ?~(got 'trunk did not answer' why.u.got)
  =.  rooms  (stamp-rooms rooms ~[w] now-ms url ?:(=('' url) why ''))
  ;<  ~  bind:m
    ?.  =('' url)
      ;<  ~  bind:(fiber:fiber:nexus ,~)  (unfault './' 'talon')
      (talon-link-into cid.w uid.e.w room.w url)
    %:  fault  './'  'talon'  %warning  &
      "trunk gave no call link: {(trip why)}"
      (trip (talon-remedy why))
    ==
  $(want t.want)
::  +stamp-rooms: rows for rooms asked for now, with their link or none
++  stamp-rooms
  |=  [rooms=(map @t json) asked=(list [room=@t cid=@ta e=entry:cal]) now-ms=@ud url=@t why=@t]
  ^-  (map @t json)
  %+  roll  asked
  |=  [[r=@t cid=@ta e=entry:cal] acc=_rooms]
  %+  ~(put by acc)  r
  %-  pairs:enjs:format
  :~  ['cal' s+cid]  ['uid' s+uid.e]  ['etag' s+etag.e]  ['at_ms' (numb:enjs:format now-ms)]
      ['url' s+url]  ['why' s+why]
  ==
::  +talon-remedy: what the owner does about a refusal trunk names
++  talon-remedy
  |=  why=@t
  ^-  @t
  ?:  =('apps may not host calls on this ship' why)  'switch "calendar (through grubbery)" on at /apps/trunk'
  ?:  =('no sfu configured' why)  'set up a call server at /apps/trunk'
  ?:  =('no public address set' why)  'open /apps/trunk once from the ship\'s public https address'
  ?:  =('the gall road /sys/gall/ is refused' why)  'grant it at /apps/grubbery/permits'
  ?:  =('this grubbery cannot hand trunk an app link' why)  'update grubbery: its trunk mark is older than trunk wire 19'
  'look at /apps/trunk'
::  +talon-watch: the subscription to trunk's answers, made once. %refused
::  when the road to read them is not granted
++  talon-watch
  |=  dir=path
  =/  m  (fiber:fiber:nexus ,?(%live %refused %failed))
  ^-  form:m
  ;<  live=(unit view:nexus)  bind:m  (peek-soft:io [%& %& dir %live] ~)
  ?~  live  (pure:m %refused)
  ?:  &(?=([%file *] u.live) =([~ %.y] (mole |.(!<(? (need-vase:tarball sang.u.live))))))
    (pure:m %live)
  ;<  our=@p  bind:m  get-our:io
  ;<  now=@da  bind:m  get-time:io
  =/  w=wire  /talon-watch
  ::  30 s at most, the timer set first, as +trunk-poke
  ;<  ~  bind:m  (set-timer:io /trunk (add now ~s30))
  ;<  ~  bind:m
    %-  send-dart:io
    :*  %node  w  &+&+[/sys/gall %'main.sig']  %poke
        [/ %gall-poke]  [[our %grubbery] gall-watch+[our %trunk /app/grubbery/calendar]]
    ==
  ;<  ok=?  bind:m
    |=  input:fiber:nexus
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %veto %node * * *]  ?.(=(w wire.dart.u.in) [%skip ~] [%done %.n])
        [~ %pack * *]
      ?.  =(w wire.u.in)  [%skip ~]
      ?~(err.u.in [%wait ~] [%done %.n])
        [~ %poke * *]
      ?:  =([/ %timer-wake] p.sage.u.in)
        ?.(?=([%trunk *] !<(path q.sage.u.in)) [%skip ~] [%done %.n])
      ?.  =([/ %poke-ack] p.sage.u.in)  [%skip ~]
      =/  [aw=wire err=(unit tang)]  !<([wire (unit tang)] q.sage.u.in)
      ?.  =(w aw)  [%skip ~]
      [%done ?=(~ err)]
    ==
  ;<  ~  bind:m  (cancel-timer:io /trunk)
  ?.  ok  (pure:m %failed)
  ::  trunk's answer to a request made before the subscription is up is
  ::  lost: wait for its ack (live), 10 s at most
  =/  tries=@ud  10
  |-
  ;<  ~  bind:m  (sleep:io ~s1)
  ;<  lv=(unit view:nexus)  bind:m  (peek-soft:io [%& %& dir %live] ~)
  ?:  &(?=([~ %file *] lv) =([~ %.y] (mole |.(!<(? (need-vase:tarball sang.u.lv))))))
    (pure:m %live)
  ?:  =(0 tries)  (pure:m %failed)
  $(tries (dec tries))
::  +talon-answer: trunk's answer to one request, read from the last fact
::  on the subscription: [url ''] or ['' why]. ~ when none came in 15 s
++  talon-answer
  |=  [dir=path req=@t]
  =/  m  (fiber:fiber:nexus ,(unit [url=@t why=@t]))
  ^-  form:m
  =/  tries=@ud  15
  |-
  ;<  v=(unit view:nexus)  bind:m  (peek-soft:io [%& %& dir %data] ~)
  =/  j=json
    ?.  ?=([~ %file *] v)  [%o ~]
    (fall (mole |.(!<(json (need-vase:tarball sang.u.v)))) [%o ~])
  =/  ok=json  (obj:gcal j 'guest-link')
  =/  no=json  (obj:gcal j 'guest-denied')
  ?:  &(=(req (gs ok 'req')) !=('' (gs ok 'url')))  (pure:m `[(gs ok 'url') ''])
  ?:  =(req (gs no 'req'))  (pure:m `['' (gs no 'why')])
  ?:  =(0 tries)  (pure:m ~)
  ;<  ~  bind:m  (sleep:io ~s1)
  $(tries (dec tries))
::  +talon-link-into: a link trunk made, onto its event: the join link,
::  the room, and a line in the note, the call asked for no more
++  talon-link-into
  |=  [cid=@ta =uid:cal room=@t url=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  c=calendar:cal  bind:m  (read-cal './')
  =/  k=(unit cal:cal)  (~(get by cals.c) cid)
  ?~  k  (pure:m ~)
  =/  e=(unit entry:cal)  (~(get by entries.u.k) uid)
  ?~  e  (pure:m ~)
  =/  mt=meta:cal  (meta-of:cal event.u.e)
  =/  note=@t  (meta-str:cal mt 'note')
  =/  join=@t  (cat 3 'Join the call in any browser: ' url)
  =.  mt
    %-  ~(gas by (~(del by mt) 'call'))
    :~  ['conference' s+url]
        ['talon_room' s+room]
        :-  'note'
        s+?:(?=(^ (find (trip url) (trip note))) note ?:(=('' note) join (rap 3 ~[note '\0a\0a' join])))
    ==
  (dav-write './' c(cals (~(put by cals.c) cid (put-entry:cal u.k u.e(event (put-meta:cal event.u.e mt))))))
::  +reply-pass: the guest side's answers a host did not hear, sent again
::  an hour on
::  +reply-tries: how many hourly passes ask a silent host again
++  reply-tries  24
++  reply-pass
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ij=json  bind:m  (read-json-grub './' 'invites.json')
  ;<  now=@da  bind:m  get-time:io
  =/  now-ms=@ud  (da-to-ms now)
  =/  due=(list [key=@t row=json])
    %+  skim  ~(tap by (omap ij))
    |=  [* r=json]
    ?&  !=('' (gs r 'status'))
        ?=([~ %b %.n] (~(get by (omap r)) 'told'))
        (gte (sub now-ms (min now-ms (fall (gn r 'told_ms') 0))) 3.600.000)
        ::  a day of hourly tries, as a refusal gets; a new answer starts
        ::  them again
        (lth (fall (gn r 'tries') 0) reply-tries)
    ==
  ?~  due  (pure:m ~)
  =/  left=(list [key=@t row=json])  due
  =|  heard=(list [@t ? @t])
  ::  a host that did not answer is not tried again this pass
  =|  down=(set @p)
  |-
  ?~  left
    ;<  cur=json  bind:m  (read-json-grub './' 'invites.json')
    =/  rows=(map @t json)  (omap cur)
    =.  rows
      %+  roll  heard
      |=  [[k=@t t=? st=@t] acc=_rows]
      =/  r=(unit json)  (~(get by acc) k)
      ?~  r  acc
      ::  an answer changed while this one was out is not the one heard
      ?.  =(st (gs u.r 'status'))  acc
      =/  n=@ud  ?:(t 0 +((fall (gn u.r 'tries') 0)))
      (~(put by acc) k (row-put u.r ~[['told' b+t] ['told_ms' (numb:enjs:format now-ms)] ['tries' (numb:enjs:format n)]]))
    (write-json-grub './' 'invites.json' [%o rows])
  =/  host=(unit @p)  (slaw %p (gs row.i.left 'host'))
  ;<  told=?  bind:m
    ?~  host  (pure:(fiber:fiber:nexus ,?) &)
    ?:  (~(has in down) u.host)  (pure:(fiber:fiber:nexus ,?) |)
    %^  remote-poke-wait  u.host  [%& cal-instance %'shares.sig']
    (pairs:enjs:format ~[['action' s+'invite-reply'] ['uid' s+(gs row.i.left 'uid')] ['status' s+(gs row.i.left 'status')]])
  =?  down  &(!told ?=(^ host))  (~(put in down) (need host))
  $(left t.left, heard [[key.i.left told (gs row.i.left 'status')] heard])
::  +place-invite: an invitation's copy onto the calendar its row names:
::  the object as the host sent it, marked as the host's (meta host), its
::  guest ships with this ship's own answer. A copy never sends guests to
::  Google (+attendees-of:gcal) nor invites of its own (+invite-pass)
++  place-invite
  |=  [pre=@t row=json]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  c=calendar:cal  bind:m  (read-cal pre)
  ;<  our=@p  bind:m  get-our:io
  =/  u=@t  (gs row 'uid')
  =/  host=(unit @p)  (slaw %p (gs row 'host'))
  ?~  host  (pure:m |)
  ::  the copy goes where the owner moved it, if they did
  =/  moved=(unit [cid=@ta e=entry:cal])  (host-copy c (gs row 'cal') u u.host)
  =/  cid=@ta  ?^(moved cid.u.moved (crip (trip (gs row 'cal'))))
  =/  k=(unit cal:cal)  (~(get by cals.c) cid)
  ?~  k  (pure:m |)
  ::  a calendar another ship shares with us would carry the copy on to
  ::  that ship, as its own event
  ?:  ?=(%ship kind.props.u.k)  (pure:m |)
  ::  a UID another calendar of ours holds is not the host's to write,
  ::  nor one of ours here that is not its copy
  =/  else=(unit [id=@ta e=entry:cal])  (find-entry:cal c u)
  ?:  &(?=(^ else) !=(cid id.u.else) !(~(has by entries.u.k) u))  (pure:m |)
  =/  here=(unit entry:cal)  (~(get by entries.u.k) u)
  ?:  &(?=(^ here) !=(`s+(gs row 'host') (~(get by (meta-of:cal event.u.here)) 'host')))  (pure:m |)
  ::  only the invitation's own UID, and none of this ship's bookkeeping
  ::  (a parent named, an alias), which would hang it on another event
  =/  ves=(list vevent:ics)
    %+  turn  (fall (mole |.((events:ics (gs row 'ics')))) ~)
    |=(v=vevent:ics v(extra (skip extra.v |=(p=prop:ics =("X-GRUBBERY-" (scag 11 (trip k.p)))))))
  ?~  ves  (pure:m |)
  ?:  (lien `(list vevent:ics)`ves |=(v=vevent:ics !=(u uid.v)))  (pure:m |)
  =/  put=(unit [k=cal:cal =uid:cal])  (fall (mole |.((put-object u.k ves zone.c u ~))) ~)
  ?~  put  (pure:m |)
  =/  e=(unit entry:cal)  (~(get by entries.k.u.put) uid.u.put)
  ?~  e  (pure:m |)
  =/  st=@t  (gs row 'status')
  =/  ships=(list json)
    =/  sl=json  (fall (~(get by (omap row)) 'ships') [%a ~])
    %+  turn  ?.(?=([%a *] sl) ~ p.sl)
    |=  g=json
    ?.  &(?=([%o *] g) =([~ %s (scot %p our)] (~(get by p.g) 'ship')))  g
    [%o (~(gas by p.g) ~[['self' b+&] ['status' s+?:(=('' st) 'needs-action' st)]])]
  =/  mt=meta:cal  (meta-of:cal event.u.e)
  =.  mt  (~(gas by mt) ~[['host' s+(gs row 'host')] ['ships' [%a ships]]])
  =/  kk=cal:cal  (put-entry:cal k.u.put u.e(event (put-meta:cal event.u.e mt)))
  ::  its moved instances are the host's too: none sends guests to Google
  =.  kk
    %+  roll  (kids-of:cal kk uid.u.e)
    |=  [ch=entry:cal acc=_kk]
    =/  cm=meta:cal  (meta-of:cal event.ch)
    (put-entry:cal acc ch(event (put-meta:cal event.ch (~(put by cm) 'host' s+(gs row 'host')))))
  ;<  ~  bind:m  (dav-write pre c(cals (~(put by cals.c) cid kk)))
  (pure:m &)
++  share-pass
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  shares=json  bind:m  (read-json-grub './' 'shares.json')
  =/  ids=(list @t)  ~(tap in ~(key by (omap shares)))
  ?:  =(~ ids)  (pure:m ~)
  ;<  c=calendar:cal  bind:m  (read-cal './')
  ;<  now=@da  bind:m  get-time:io
  |-
  ?~  ids  (pure:m ~)
  =/  id=@ta  (crip (trip i.ids))
  =/  road=road:tarball  (cord-to-road:tarball (crip "./shares/{(trip id)}.json"))
  =/  k=(unit cal:cal)  (~(get by cals.c) id)
  ?~  k
    ;<  base=(unit path)  bind:m  self-base
    ;<  ~  bind:m
      ?~  base  (pure:(fiber:fiber:nexus ,~) ~)
      (set-share-groups u.base id ~)
    ;<  *  bind:m  (cull-soft:io road)
    ;<  *  bind:m  (cull-soft:io (cord-to-road:tarball (crip "./shares/{(trip id)}/")))
    ;<  cur=json  bind:m  (read-json-grub './' 'shares.json')
    ;<  ~  bind:m  (write-json-grub './' 'shares.json' [%o (~(del by (omap cur)) i.ids)])
    ;<  wj=json  bind:m  (read-json-grub './' 'share-writes.json')
    ;<  ~  bind:m  (write-json-grub './' 'share-writes.json' [%o (~(del by (omap wj)) i.ids)])
    $(ids t.ids)
  ;<  cur=(unit view:nexus)  bind:m  (peek-soft:io road ~)
  =/  have=json
    ?.  ?=([~ %file *] cur)  *json
    (fall (mole |.(!<(json (need-vase:tarball sang.u.cur)))) *json)
  ::  a share made before the folder was published gets it, and its
  ::  groups the road to it, once
  ;<  idx=(unit view:nexus)  bind:m  (peek-soft:io (cord-to-road:tarball (crip "./shares/{(trip id)}/index.json")) ~)
  =/  folded=?  ?=([~ %file *] idx)
  ?:  ?&  folded
          ?=([~ %file *] cur)
          =(`seq.u.k (gn have 'seq'))
          =(name.props.u.k (gs have 'name'))
          =(color.props.u.k (gs have 'color'))
      ==
    $(ids t.ids)
  ;<  ~  bind:m  (publish-share './' c id now)
  ;<  ~  bind:m
    ?:  folded  (pure:(fiber:fiber:nexus ,~) ~)
    ;<  base=(unit path)  bind:(fiber:fiber:nexus ,~)  self-base
    ?~  base  (pure:(fiber:fiber:nexus ,~) ~)
    (set-share-groups u.base id (omap (obj:gcal shares i.ids)))
  $(ids t.ids)
::  +publish-share: a shared calendar as its peers read it. The whole file,
::  <id>.json (every object's text: a first pull, a big change, a peer on
::  older code), and the folder a peer reads a change from: <id>/index.json
::  (each object's etag and its file) and one file per object, the folder
::  written whole in one event.
::  ponytail: every object's text is rendered on each publish; keep the
::  text of an unchanged etag from the last one if a big calendar makes
::  that slow
++  publish-share
  |=  [pre=@t c=calendar:cal id=@ta now=@da]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  froad=road:tarball  (cord-to-road:tarball (crip "{(trip pre)}shares/{(trip id)}.json"))
  =/  fj=json  (build-share-json c id now)
  ;<  cur=(unit view:nexus)  bind:m  (peek-soft:io froad ~)
  ;<  ~  bind:m
    ?:  ?=([~ %file *] cur)  (over:io froad [[/ %json] fj])
    (make:io froad |+[[[/ %json] fj] ~])
  =/  objects=(list [u=@t o=json])  ~(tap by (omap (obj:gcal fj 'objects')))
  =/  index=json
    %-  pairs:enjs:format
    :~  ['seq' (fall (bind (gn fj 'seq') numb:enjs:format) ~)]
        :-  'objects'
        :-  %o
        %-  ~(gas by *(map @t json))
        %+  turn  objects
        |=  [u=@t o=json]
        [u (pairs:enjs:format ~[['etag' s+(gs o 'etag')] ['file' s+(share-object-name u)]])]
    ==
  =/  bol=bole:tarball
    %+  roll  objects
    |=  [[u=@t o=json] acc=bole:tarball]
    %+  ~(put bo:tarball acc)  [/ (share-object-name u)]
    [[/ %json] (pairs:enjs:format ~[['uid' s+u] ['etag' s+(gs o 'etag')] ['ics' s+(gs o 'ics')]])]
  =.  bol  (~(put bo:tarball bol) [/ %'index.json'] [[/ %json] index])
  (over-fold:io (cord-to-road:tarball (crip "{(trip pre)}shares/{(trip id)}/")) bol)
++  share-object-name  share-object-name:core
::  +share-request: the owner's routes under /apps/calendar/share/
::  +invite-request: the owner's invitations. GET /invites.json lists
::  them (without their ICS), each with the calendar its host's last
::  accepted one went on. POST /invites/answer {key, status, cal}:
::  accepted or tentative puts the copy on cal (else that calendar, else
::  default) and remembers it for the host; declined takes a copy off.
::  Either way the host is told, and the answer says whether it heard.
++  invite-request
  |=  [eyre-id=@ta req=inbound-request:eyre suffix=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  jon=json
    (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
  ;<  ij=json  bind:m  (read-json-grub '../' 'invites.json')
  ;<  rj=json  bind:m  (read-json-grub '../' 'invite-routes.json')
  =/  cur=(map @t json)  (omap ij)
  =/  routes=(map @t json)  (omap rj)
  ?:  ?=([%'invites.json' ~] suffix)
    %+  send-json  eyre-id
    :-  %a
    %+  turn  ~(tap by cur)
    |=  [key=@t r=json]
    ?.  ?=([%o *] r)  r
    =/  route=(unit json)  (~(get by routes) (gs r 'host'))
    [%o (~(gas by (~(del by p.r) 'ics')) ~[['key' s+key] ['route' (fall route s+'')]])]
  ?.  &(=('POST' method.request.req) ?=([%invites %answer ~] suffix))
    (send-text eyre-id 404 'calendar: no such route')
  =/  key=@t  (gs jon 'key')
  =/  st=@t  (gs jon 'status')
  =/  row=(unit json)  (~(get by cur) key)
  ?~  row  (send-text eyre-id 404 'calendar: no such invitation')
  ?.  ?=(?(%accepted %declined %tentative) st)
    (send-text eyre-id 400 'calendar: the answer is accepted, declined or tentative')
  =/  host=(unit @p)  (slaw %p (gs u.row 'host'))
  ?~  host  (send-text eyre-id 400 'calendar: bad host')
  ;<  c=calendar:cal  bind:m  (read-cal '../')
  ?:  (kind-is c (crip (trip (gs jon 'cal'))) %ship)
    (send-text eyre-id 400 'calendar: an invitation cannot go on a calendar another ship shares with you')
  =/  was=@ta  (crip (trip (gs u.row 'cal')))
  =/  want=@ta
    =/  named=@ta  (crip (trip (gs jon 'cal')))
    =/  last=@ta  (crip (trip (gs (fall (~(get by routes) (gs u.row 'host')) s+'') '')))
    =/  pick=@ta  ?.(=('' named) named ?.(=('' was) was last))
    ::  not one another ship shares with us: the copy would go on to it
    ?:(&((~(has by cals.c) pick) !(kind-is c pick %ship)) pick %default)
  ::  declined, or moved to another calendar: the old copy goes
  ::  (the host's copy only, wherever the owner moved it)
  ;<  ~  bind:m
    ?:  |(=('' was) &(!=('declined' st) =(was want)))  (pure:(fiber:fiber:nexus ,~) ~)
    =/  hit=(unit [cid=@ta e=entry:cal])  (host-copy c was (gs u.row 'uid') u.host)
    ?~  hit  (pure:(fiber:fiber:nexus ,~) ~)
    ?:  &(!=('declined' st) =(cid.u.hit want))  (pure:(fiber:fiber:nexus ,~) ~)
    =/  k=cal:cal  (~(got by cals.c) cid.u.hit)
    (dav-write '../' c(cals (~(put by cals.c) cid.u.hit (del-object k (gs u.row 'uid')))))
  ::  read again: the copy's removal waited, and a cancel the host sent
  ::  meanwhile is not undone. The answer is not told until the host
  ::  hears it, whatever an answer before it was
  ;<  ij1=json  bind:m  (read-json-grub '../' 'invites.json')
  =/  cur1=(map @t json)  (omap ij1)
  =/  fresh=(unit json)  (~(get by cur1) key)
  ?~  fresh  (send-text eyre-id 404 'calendar: the host cancelled this invitation')
  =/  new=json
    %+  row-put  u.fresh
    :~  ['status' s+st]  ['cal' s+?:(=('declined' st) '' want)]
        ['told' b+|]  ['tries' (numb:enjs:format 0)]
    ==
  ;<  ~  bind:m  (write-json-grub '../' 'invites.json' [%o (~(put by cur1) key new)])
  ;<  placed=?  bind:m
    ?:  =('declined' st)  (pure:(fiber:fiber:nexus ,?) &)
    (place-invite '../' new)
  ::  a copy that could not be placed is not claimed
  ;<  ~  bind:m
    ?:  placed  (pure:(fiber:fiber:nexus ,~) ~)
    (set-row '../' 'invites.json' key ~[['cal' s+'']])
  ;<  ~  bind:m
    ?:  =('declined' st)  (pure:(fiber:fiber:nexus ,~) ~)
    (write-json-grub '../' 'invite-routes.json' [%o (~(put by routes) (gs u.row 'host') s+want)])
  ;<  told=?  bind:m
    %^  remote-poke-wait  u.host  [%& cal-instance %'shares.sig']
    (pairs:enjs:format ~[['action' s+'invite-reply'] ['uid' s+(gs u.row 'uid')] ['status' s+st]])
  ::  an answer the host did not hear is sent again (+reply-pass)
  ;<  now=@da  bind:m  get-time:io
  ;<  ij2=json  bind:m  (read-json-grub '../' 'invites.json')
  =/  cur2=(map @t json)  (omap ij2)
  ;<  ~  bind:m
    ?.  (~(has by cur2) key)  (pure:(fiber:fiber:nexus ,~) ~)
    ::  an answer changed while this one was out is not the one heard
    ?.  =(st (gs (~(got by cur2) key) 'status'))  (pure:(fiber:fiber:nexus ,~) ~)
    =/  r2=json  (row-put (~(got by cur2) key) ~[['told' b+told] ['told_ms' (numb:enjs:format (da-to-ms now))]])
    (write-json-grub '../' 'invites.json' [%o (~(put by cur2) key r2)])
  (send-json eyre-id (pairs:enjs:format ~[['ok' b+placed] ['cal' s+?:(&(placed !=('declined' st)) want '')] ['told' b+told]]))
++  share-request
  |=  [eyre-id=@ta req=inbound-request:eyre our=@p rest=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  jon=json
    (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
  =/  post=?  =('POST' method.request.req)
  ?:  ?=([%'shares.json' ~] rest)
    ;<  shares=json  bind:m  (read-json-grub '../' 'shares.json')
    ;<  offers=json  bind:m  (read-json-grub '../' 'share-offers.json')
    ;<  rows=json  bind:m  (read-json-grub '../' 'ship-remotes.json')
    =/  accepted=json
      :-  %o
      %-  ~(gas by *(map @t json))
      %+  turn  ?:(?=([%o *] rows) ~(tap by p.rows) ~)
      |=  [id=@t r=json]
      :-  id
      %-  pairs:enjs:format
      :~  ['key' s+(gs r 'key')]
          ['mode' s+(gs r 'mode')]
          ['last_ms' (numb:enjs:format (fall (gn r 'last_ms') 0))]
          ['error' s+(gs r 'error')]
          ['via' s+(gs r 'via')]
          ['fetched' (numb:enjs:format (fall (gn r 'fetched') 0))]
      ==
    (send-json eyre-id (pairs:enjs:format ~[['shares' shares] ['offers' offers] ['accepted' accepted]]))
  ::  share {id, ship, mode}: the ship joins the calendar's group and is
  ::  told. read: peek on the share file. edit: that and poke on the
  ::  calendar, which the handler limits to this calendar.
  ?:  &(post ?=([%share ~] rest))
    =/  id=@ta  (crip (trip (gs jon 'id')))
    =/  shp=(unit @p)  (slaw %p (gs jon 'ship'))
    =/  mode=@t  ?:(=('edit' (gs jon 'mode')) 'edit' 'read')
    ?~  shp  (send-text eyre-id 400 'calendar: bad ship name')
    ?:  =(u.shp our)  (send-text eyre-id 400 'calendar: that is this ship')
    ;<  base=(unit path)  bind:m  self-base
    ?~  base  (send-text eyre-id 500 'calendar: cannot find where this app is installed')
    ;<  c=calendar:cal  bind:m  (read-cal '../')
    =/  k=(unit cal:cal)  (~(get by cals.c) id)
    ?~  k  (send-text eyre-id 404 'calendar: no such calendar')
    ::  a Google or followed calendar can be shared onward: the peer's
    ::  edits land here and the sync carries them up to the source, as if
    ::  made here. A calendar another ship shared with us is not ours to
    ::  share again.
    ?:  ?=(%ship kind.props.u.k)  (send-text eyre-id 400 'calendar: a calendar shared with you cannot be shared onward')
    ::  1. the record
    ;<  shares=json  bind:m  (read-json-grub '../' 'shares.json')
    =/  all=(map @t json)  ?:(?=([%o *] shares) p.shares ~)
    ::  ponytail: a group is named from the id with . ~ _ made -, so two
    ::  ids can name one group, and sharing the second would take the
    ::  first's peers off it; refused. Hash the id into the name (and
    ::  move the old groups) if that ever bites.
    ?:  (lien ~(tap in ~(key by all)) |=(o=@t &(!=(o id) =((group-name o 'read') (group-name id 'read')))))
      (send-text eyre-id 400 'calendar: another shared calendar has an id too like this one; share a copy under another id')
    =/  mine=(map @t json)  =/(j (~(get by all) id) ?:(?=([~ %o *] j) p.u.j ~))
    =.  mine  (~(put by mine) (scot %p u.shp) s+mode)
    ;<  ~  bind:m  (write-json-grub '../' 'shares.json' [%o (~(put by all) id [%o mine])])
    ::  2. the share file and folder, now
    ;<  now=@da  bind:m  get-time:io
    ;<  ~  bind:m  (publish-share '../' c id now)
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
    ?~  shp  (send-text eyre-id 400 'calendar: bad ship name')
    ;<  base=(unit path)  bind:m  self-base
    ?~  base  (send-text eyre-id 500 'calendar: cannot find where this app is installed')
    ;<  shares=json  bind:m  (read-json-grub '../' 'shares.json')
    =/  all=(map @t json)  ?:(?=([%o *] shares) p.shares ~)
    =/  mine=(map @t json)  =/(j (~(get by all) id) ?:(?=([~ %o *] j) p.u.j ~))
    =.  mine  (~(del by mine) (scot %p u.shp))
    ;<  ~  bind:m
      (write-json-grub '../' 'shares.json' [%o ?:(=(~ mine) (~(del by all) id) (~(put by all) id [%o mine]))])
    ;<  ~  bind:m  (set-share-groups u.base id mine)
    ::  the last peer gone, what was published for peers goes too
    ;<  ~  bind:m
      ?.  =(~ mine)  (pure:(fiber:fiber:nexus ,~) ~)
      ;<  *  bind:(fiber:fiber:nexus ,~)  (cull-soft:io (cord-to-road:tarball (crip "../shares/{(trip id)}.json")))
      ;<  *  bind:(fiber:fiber:nexus ,~)  (cull-soft:io (cord-to-road:tarball (crip "../shares/{(trip id)}/")))
      ;<  wj=json  bind:(fiber:fiber:nexus ,~)  (read-json-grub '../' 'share-writes.json')
      (write-json-grub '../' 'share-writes.json' [%o (~(del by (omap wj)) id)])
    ;<  *  bind:m
      %^  remote-poke-wait  u.shp
        [%& cal-instance %'shares.sig']
      (pairs:enjs:format ~[['action' s+'revoke'] ['cal' s+id]])
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  ::  accept {key}: the offered calendar becomes ours to read (or edit)
  ?:  &(post ?=([%accept ~] rest))
    =/  key=@t  (gs jon 'key')
    ;<  offers=json  bind:m  (read-json-grub '../' 'share-offers.json')
    =/  cur=(map @t json)  ?:(?=([%o *] offers) p.offers ~)
    =/  offer=(unit json)  (~(get by cur) key)
    ?~  offer  (send-text eyre-id 404 'calendar: no such offer')
    ;<  now=@da  bind:m  get-time:io
    ;<  c=calendar:cal  bind:m  (read-cal '../')
    =/  id=@ta
      =/  first=@ta  (crip "s-{(trip (scot %uw (mug key)))}")
      ::  a copy from an earlier share of the same calendar (revoked, now
      ::  local) keeps its id; the new one gets its own
      ?.  (~(has by cals.c) first)  first
      (crip "s-{(trip (scot %uw (mug [key now])))}")
    =/  mode=@t  (gs u.offer 'mode')
    =/  k=cal:cal  (born now)
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
    ;<  ~  bind:m  (write-json-grub '../' 'ship-remotes.json' [%o (~(put by ?:(?=([%o *] rows) p.rows ~)) id row)])
    ::  read again: an offer another host sent meanwhile stays
    ;<  offers2=json  bind:m  (read-json-grub '../' 'share-offers.json')
    ;<  ~  bind:m  (write-json-grub '../' 'share-offers.json' [%o (~(del by (omap offers2)) key)])
    ;<  ~  bind:m  (google-prod '../')
    (send-json eyre-id (pairs:enjs:format ~[['id' s+id]]))
  ?:  &(post ?=([%decline ~] rest))
    =/  key=@t  (gs jon 'key')
    ;<  offers=json  bind:m  (read-json-grub '../' 'share-offers.json')
    ;<  ~  bind:m  (write-json-grub '../' 'share-offers.json' [%o (~(del by ?:(?=([%o *] offers) p.offers ~)) key)])
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  ::  the owner asking is reason to ask every host again now, a host
  ::  backed off (+back-off) included
  ?:  &(post ?=([%sync ~] rest))
    ;<  rows=json  bind:m  (read-json-grub '../' 'ship-remotes.json')
    ;<  ~  bind:m
      ?:  =(~ (skim ~(val by (omap rows)) |=(r=json !=(0 (fall (gn r 'retry_ms') 0)))))
        (pure:(fiber:fiber:nexus ,~) ~)
      %^  write-json-grub  '../'  'ship-remotes.json'
      [%o (~(run by (omap rows)) |=(r=json (row-put r ~[['retry_ms' (numb:enjs:format 0)]])))]
    ;<  ~  bind:m  (google-prod '../')
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  (send-text eyre-id 404 'calendar: no such share route')
::  +set-share-groups: the two groups of one calendar, from its record
++  set-share-groups
  |=  [base=path id=@ta mine=(map @t json)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  file=road:tarball  [%& %& (snoc base %shares) (crip "{(trip id)}.json")]
  ::  and the folder a peer reads a change from (+publish-share)
  =/  folder=road:tarball  [%& %| (snoc (snoc base %shares) id)]
  =/  cal-road=road:tarball  [%& %& base %'calendar.calendar']
  =/  readers=(set @p)
    %-  ~(gas in *(set @p))
    %+  murn  ~(tap by mine)
    |=([s=@t v=json] ?:(?=([%s *] v) (slaw %p s) ~))
  =/  editors=(set @p)
    %-  ~(gas in *(set @p))
    %+  murn  ~(tap by mine)
    |=([s=@t v=json] ?:(&(?=([%s *] v) =('edit' p.v)) (slaw %p s) ~))
  ;<  ~  bind:m  (ug-set (group-name id 'read') readers (sy ~[file folder]) ~)
  (ug-set (group-name id 'edit') editors (sy ~[file folder]) (sy ~[cal-road]))
++  share-base-ok  share-base-ok:core
::  +note-share-write: what a peer's accepted write left here, for its
::  next edit's +share-base-ok. share-writes.json holds cal -> uid ->
::  peer -> etag, only for uids the calendar still has.
++  note-share-write
  |=  [writes=json cid=@ta k=cal:cal u=@t peer=@p]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  rows=(map @t json)
    %-  malt
    %+  skim  ~(tap by (omap (obj:gcal writes cid)))
    |=([v=@t *] (~(has by entries.k) v))
  =?  rows  (~(has by entries.k) u)
    =/  e=entry:cal  (~(got by entries.k) u)
    (~(put by rows) u [%o (~(put by (omap (obj:gcal [%o rows] u))) (scot %p peer) s+etag.e)])
  (write-json-grub './' 'share-writes.json' [%o (~(put by (omap writes)) cid [%o rows])])
::  +queue-refusal: a refused share edit, to be said back to the peer
::  with the object it sent (the peer logs that, whatever its own copy is
::  by the time the notice comes). One row per peer, calendar and uid, the
::  newest; at most 100, fifty to a peer, the object only when it is no
::  bigger than an invitation: a flood of refusals stays small.
++  queue-refusal
  |=  [to=@p cid=@ta u=@t why=@t mode=@t ics=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  q=json  bind:m  (read-json-grub './' 'refusals.json')
  =/  same  |=(r=json &(=((gs r 'to') (scot %p to)) =((gs r 'cal') cid) =((gs r 'uid') u)))
  =/  rows=(list json)  (skip ?:(?=([%a *] q) p.q ~) same)
  =/  theirs=@ud  (lent (skim rows |=(r=json =((gs r 'to') (scot %p to)))))
  =?  rows  (gte theirs 50)
    ::  the peer's oldest goes (rows run newest first)
    =/  last=(unit json)  (rear-of (skim rows |=(r=json =((gs r 'to') (scot %p to)))))
    ?~(last rows (skip rows |=(r=json =(r u.last))))
  =/  row=json
    %-  pairs:enjs:format
    :~  ['to' s+(scot %p to)]  ['cal' s+cid]  ['uid' s+u]
        ['why' s+why]  ['mode' s+mode]
        ['ics' s+?:((gth (met 3 ics) invite-max) '' ics)]
    ==
  (write-json-grub './' 'refusals.json' [%a (scag 100 `(list json)`[row rows])])
++  rear-of
  |=  l=(list json)
  ^-  (unit json)
  ?~(l ~ `(rear l))
::  +send-refusals: tell each queued peer its edit was refused, then take
::  the row off the queue. A peer that does not answer keeps its rows,
::  tried again an hour on (a day of tries at most), and the rest of its
::  rows are not tried this pass (each would wait 30 s). The file is
::  read again and written once at the end, so a row queued meanwhile
::  stays.
++  send-refusals
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  q=json  bind:m  (read-json-grub './' 'refusals.json')
  ;<  now=@da  bind:m  get-time:io
  =/  now-ms=@ud  (da-to-ms now)
  =/  rows=(list json)
    (skim ?:(?=([%a *] q) p.q ~) |=(r=json (lte (fall (gn r 'retry_ms') 0) now-ms)))
  =|  down=(set @p)
  =|  done=(list json)
  =|  later=(list json)
  |-
  ?~  rows
    ?:  &(?=(~ done) ?=(~ later))  (pure:m ~)
    ;<  cur=json  bind:m  (read-json-grub './' 'refusals.json')
    =/  left=(list json)
      %+  murn  ?:(?=([%a *] cur) p.cur ~)
      |=  r=json
      ^-  (unit json)
      ?:  ?=(^ (find ~[r] done))  ~
      ?~  (find ~[r] later)  `r
      =/  n=@ud  +((fall (gn r 'tries') 0))
      ?:  (gth n 24)  ~
      `(row-put r ~[['tries' (numb:enjs:format n)] ['retry_ms' (numb:enjs:format (add now-ms 3.600.000))]])
    (write-json-grub './' 'refusals.json' [%a left])
  =/  to=(unit @p)  (slaw %p (gs i.rows 'to'))
  ?~  to  $(rows t.rows, done [i.rows done])
  ?:  (~(has in down) u.to)  $(rows t.rows, later [i.rows later])
  ;<  heard=?  bind:m
    %^  remote-poke-wait  u.to  [%& cal-instance %'shares.sig']
    %-  pairs:enjs:format
    :~  ['action' s+'refused']
        ['cal' s+(gs i.rows 'cal')]
        ['uid' s+(gs i.rows 'uid')]
        ['why' s+(gs i.rows 'why')]
        ['mode' s+(gs i.rows 'mode')]
        ['ics' s+(gs i.rows 'ics')]
    ==
  ?:  heard  $(rows t.rows, done [i.rows done])
  $(rows t.rows, down (~(put in down) u.to), later [i.rows later])
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
  ::  by the same wire. A veto or our timer ends the wait with %.n. The
  ::  timer is set before the poke goes (+trunk-poke says why)
  ;<  ~  bind:m  (set-timer:io /remote (add now ~s30))
  ;<  ~  bind:m
    %-  send-dart:io
    [%node w &+&+[/sys/gall %'main.sig'] %poke [[/ %gall-poke] [[target %grubbery] grubbery-load+req]]]
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
      [%done ?=(~ err)]
    ==
  ;<  ~  bind:m  (cancel-timer:io /remote)
  (pure:m ok)
::  +peek-remote-wait: a peek of another ship's file: ~ when no answer came
::  (timeout), [~ ~] when it was refused, else the view
++  peek-remote-wait
  |=  [target=@p road=road:tarball]
  =/  m  (fiber:fiber:nexus ,(unit (unit view:nexus)))
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
  ::  the timer first (+trunk-poke says why): a refused peek is a veto
  ::  that setting it would take, and crash on
  ;<  ~  bind:m  (set-timer:io /remote until)
  ;<  ~  bind:m  (send-dart:io %node pw rr %peek ~ ~ %.y)
  ;<  got=(unit (unit view:nexus))  bind:m
    |=  input:fiber:nexus
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %veto %node * * *]
      ?.(=(pw wire.dart.u.in) [%skip ~] [%done `~])
        [~ %peek * *]
      ?.(=(pw wire.u.in) [%skip ~] [%done ``view.u.in])
        [~ %poke * *]
      ?.  =([/ %timer-wake] p.sage.u.in)  [%skip ~]
      ?.(?=([%remote *] !<(path q.sage.u.in)) [%skip ~] [%done ~])
    ==
  ;<  ~  bind:m  (cancel-timer:io /remote)
  (pure:m got)
::  +share-fetch: what a host shares of one calendar, {seq, objects},
::  with the text of every object that moved. The index first, then only
::  the objects whose etag differs from ours; the whole file when there
::  is no index to read (a host on older code, or groups that do not
::  reach the folder yet) or when many moved (a first pull). An error
::  text when the host did not answer.
::  ponytail: 40 objects fetched one by one; batch them if the peeks
::  are slow over a real network
++  share-fetch
  |=  [host=@p base=path hcal=@t etags=(map @t json)]
  =/  m  (fiber:fiber:nexus ,(each json @t))
  ^-  form:m
  =/  dir=path  (snoc (snoc base %shares) (crip (trip hcal)))
  =/  quiet=@t  'the host did not answer (down, or the share was revoked)'
  ;<  ix=(unit (unit view:nexus))  bind:m  (peek-remote-wait host [%& %& dir %'index.json'])
  ?~  ix  (pure:m |+quiet)
  ?.  ?=([~ %file *] u.ix)  (share-whole host base hcal)
  ::  an index that cannot be read is an error, never an empty listing:
  ::  that would delete every event the host shared
  =/  index=json  (fall (mole |.(!<(json (need-vase:tarball sang.u.u.ix)))) ~)
  ?.  (has-objects index)  (pure:m |+'the host\'s index could not be read')
  =/  listed=(map @t json)  (omap (obj:gcal index 'objects'))
  =/  moved=(list [u=@t o=json])
    (skim ~(tap by listed) |=([u=@t o=json] !=((gs o 'etag') (gs [%o etags] u))))
  ?:  (gth (lent moved) 40)  (share-whole host base hcal)
  =|  got=(map @t json)
  |-
  ?~  moved
    %-  pure:m
    :-  %&
    %-  pairs:enjs:format
    :~  ['seq' (fall (bind (gn index 'seq') numb:enjs:format) ~)]
        ['objects' [%o (~(uni by listed) got)]]
        ['via' s+'index']
        ['fetched' (numb:enjs:format ~(wyt by got))]
    ==
  ;<  ov=(unit (unit view:nexus))  bind:m
    (peek-remote-wait host [%& %& dir (crip (trip (gs o.i.moved 'file')))])
  ?.  ?=([~ ~ %file *] ov)  (pure:m |+'the host did not answer for an event; the next pass asks again')
  =/  oj=json  (fall (mole |.(!<(json (need-vase:tarball sang.u.u.ov)))) ~)
  ?.  ?=([%o *] oj)  (pure:m |+'an event the host shared could not be read; the next pass asks again')
  $(moved t.moved, got (~(put by got) u.i.moved oj))
::  +share-whole: a host's whole share file, every object's text
++  share-whole
  |=  [host=@p base=path hcal=@t]
  =/  m  (fiber:fiber:nexus ,(each json @t))
  ^-  form:m
  ;<  vw=(unit (unit view:nexus))  bind:m
    (peek-remote-wait host [%& %& (snoc base %shares) (crip "{(trip hcal)}.json")])
  ?~  vw  (pure:m |+'the host did not answer (down, or the share was revoked)')
  ?.  ?=([~ %file *] u.vw)  (pure:m |+'the host has no such shared calendar any more')
  =/  share=json  (fall (mole |.(!<(json (need-vase:tarball sang.u.u.vw)))) ~)
  ?.  (has-objects share)  (pure:m |+'the host\'s share file could not be read')
  (pure:m &+(row-put share ~[['via' s+'whole']]))
++  has-objects  has-objects:core
++  new-id-ok  new-id-ok:core
::  +ship-pull: the host's share file, diffed by etag against what we
::  hold; changed objects are applied, missing ones deleted
++  ship-pull
  |=  [pre=@t id=@ta row=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  host=(unit @p)  (slaw %p (gs row 'host'))
  ?~  host  (pure:m row)
  ::  a calendar gone or made local asks nothing of the host
  ;<  c0=calendar:cal  bind:m  (read-cal pre)
  ?.  (kind-is c0 id %ship)  (pure:m row)
  =/  base=path  (fall (mole |.((stab (gs row 'base')))) cal-instance)
  =/  hcal=@t  (gs row 'cal')
  ;<  got=(each json @t)  bind:m  (share-fetch u.host base hcal (omap (obj:gcal row 'etags')))
  ?:  ?=(%| -.got)  (pure:m (row-put row ~[['error' s+p.got]]))
  =/  share=json  p.got
  ::  every pull diffs, even when the host's seq has not moved: an edit
  ::  the host refused changed nothing there, and our copy of it must
  ::  still give way to the host's (an unchanged object costs a compare)
  =/  rseq=@ud  (fall (gn share 'seq') 0)
  =/  objects=(map @t json)  (omap (obj:gcal share 'objects'))
  =/  etags=(map @t json)  (omap (obj:gcal row 'etags'))
  ::  read and written with nothing waiting between (+edit-cals): the
  ::  clock first, the conflicts after
  ;<  now=@da  bind:m  get-time:io
  ;<  c=calendar:cal  bind:m  (read-cal pre)
  =/  k=cal:cal  (fall (~(get by cals.c) id) fresh-cal:cal)
  ?.  ?=(%ship kind.props.k)  (pure:m row)
  =/  k=cal:cal  k
  =/  since=@ud  (fall (gn row 'pushed_seq') 0)
  =/  sup=(set [@t @ud])  (suppressed row)
  =/  pending=(set uid:cal)  (pending-uids k since sup)
  =/  seq-at-peek=@ud  seq.k
  =/  res=[k=cal:cal etags=(map @t json) clashes=(list [uid:cal (unit entry:cal) @t])]
    %+  roll  ~(tap by objects)
    |=  [[u=@t o=json] acc=_[k=k etags=*(map @t json) clashes=*(list [uid:cal (unit entry:cal) @t])]]
    ::  a key no client could have made (a #, a control character) is
    ::  not taken
    ?.  (key-ok u)  acc
    =/  et=@t  (gs o 'etag')
    =.  etags.acc  (~(put by etags.acc) u s+et)
    ?:  =(et (gs [%o etags] u))  acc
    ::  the host's object is read softly: one it cannot phrase is skipped;
    ::  it is kept under the host's key, whatever its own UID
    =/  put=(unit [k=cal:cal =uid:cal])
      %-  fall  :_  ~
      %-  mole  |.
      =/  al  (alias-object (events:ics (gs o 'ics')) u)
      (put-object k.acc ves.al zone.c u extra.al)
    ?~  put  acc
    =/  old=(unit entry:cal)  (~(get by entries.k.acc) uid.u.put)
    =?  clashes.acc  &(?=(^ old) (~(has in pending) uid.u.put) !=(k.acc k.u.put))  [[uid.u.put old ''] clashes.acc]
    acc(k k.u.put)
  ::  what the host no longer has, goes
  =/  res2=[k=cal:cal clashes=(list [uid:cal (unit entry:cal) @t])]
    %+  roll  ~(tap by etags)
    |=  [[u=@t *] acc=_[k=k.res clashes=clashes.res]]
    ?:  (~(has by objects) u)  acc
    =/  old=(unit entry:cal)  (~(get by entries.k.acc) u)
    ?~  old  acc
    =?  clashes.acc  (~(has in pending) u)  [[u old ''] clashes.acc]
    acc(k (del-object k.acc u))
  =/  won=(set uid:cal)  (~(gas in *(set uid:cal)) (turn clashes.res2 |=([u=uid:cal *] u)))
  =/  sup2=(set [@t @ud])
    (~(uni in (~(uni in sup) (wrote-between k.res2 seq-at-peek seq.k.res2))) (rows-of k.res2 since won))
  =/  row2=json
    %+  row-put
      ::  how the last pull that changed something read the host: its
      ::  index and the objects that moved, or its whole file
      ?:  =(k.res2 k)  row
      (row-put row ~[['via' s+(gs share 'via')] ['fetched' (fall (bind (gn share 'fetched') numb:enjs:format) (numb:enjs:format 0))]])
    :~  ['seq' (numb:enjs:format rseq)]
        ['etags' [%o etags.res]]
        ::  the host's versions as pulled, which a push names as its base
        ::  (etags follows our pushes; this does not)
        ['pulled' [%o etags.res]]
        ['last_ms' (numb:enjs:format (da-to-ms now))]
        ['error' s+'']
        ['suppressed' (suppress-json sup2 since)]
    ==
  ;<  ~  bind:m
    ?:  =(k.res2 k)  (pure:(fiber:fiber:nexus ,~) ~)
    (dav-write pre c(cals (~(put by cals.c) id k.res2)))
  ;<  ~  bind:m  (log-clashes pre id clashes.res2 'changed on both sides; the host kept')
  ;<  ~  bind:m  (save-row pre 'ship-remotes.json' id ~[row] row2)
  (pure:m row2)
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
  ;<  c=calendar:cal  bind:m  (read-cal pre)
  =/  k=(unit cal:cal)  (~(get by cals.c) id)
  ?~  k  (pure:m row)
  ?.  ?=(%ship kind.props.u.k)  (pure:m row)
  ?.  (gth seq.u.k since)  (pure:m row)
  =/  sup=(set [@t @ud])  (suppressed row)
  ::  read-only (the calendar's remote string is the truth; the row's
  ::  mode is for display): nothing to push, so the watermark just
  ::  follows the local seq and the pull's suppressed rows are pruned
  ?:  (ship-read-only c id)
    ::  edits made while it was editable that never reached the host are
    ::  kept in the conflict log: the next pull puts the host's copy back
    =/  lost=(list [uid:cal ?(%put %del)])  (changes-since u.k since sup)
    ;<  ~  bind:m
      %^  log-clashes  pre  id
      :_  'the calendar became read-only before this edit reached the host'
      (turn lost |=([u=uid:cal *] [u (~(get by entries.u.k) u) '']))
    (pure:m (row-put row ~[['pushed_seq' (numb:enjs:format seq.u.k)] ['suppressed' (suppress-json sup seq.u.k)]]))
  =/  changes=(list [uid:cal ?(%put %del)])  (changes-since u.k since sup)
  ;<  now=@da  bind:m  get-time:io
  =/  cal-lane=lane:tarball  [%& base %'calendar.calendar']
  =/  stopped=?  |
  ::  the row's etags follow what we push: etags are content hashes,
  ::  so a host that later puts the old content back would otherwise
  ::  look unchanged against the etag of our last pull and be skipped
  =/  etags=(map @t json)  (omap (obj:gcal row 'etags'))
  =/  pulled=json  (obj:gcal row 'pulled')
  ::  what went to the host in the last day: a refusal of one is ours to
  ::  log even when a pull has taken our copy away since
  =/  sent=(map @t json)
    %-  malt
    %+  skim  ~(tap by (omap (obj:gcal row 'sent')))
    |=([* v=json] (gth (add (fall (ni:dejs-soft:format v) 0) 86.400.000) (da-to-ms now)))
  |-
  ?^  changes
    =/  [u=uid:cal what=?(%put %del)]  i.changes
    ::  base: the host's version our copy came from ('' for one the host
    ::  never had); the host refuses an edit over a newer one
    =/  base=@t  (gs pulled u)
    =/  body=json
      ?:  =(%del what)
        (pairs:enjs:format ~[['action' s+'share-del'] ['cal' s+hcal] ['uid' s+u] ['base' s+base]])
      =/  ics=(unit @t)  (dav-object-ics c id u now)
      ?~  ics  [%o ~]
      (pairs:enjs:format ~[['action' s+'share-put'] ['cal' s+hcal] ['uid' s+u] ['ics' s+u.ics] ['base' s+base]])
    ?:  =([%o ~] body)  $(changes t.changes)
    ;<  ok=?  bind:m  (remote-poke-wait u.host cal-lane body)
    ?.  ok
      ;<  ~  bind:m
        %:  fault  pre  (cat 3 'share-push/' id)  %warning  |
          "the host ship did not take changes for calendar {(trip id)}"
          "they are sent again on the next pass"
        ==
      $(changes ~, stopped &)
    =.  etags
      ?:  =(%del what)  (~(del by etags) u)
      =/  e=(unit entry:cal)  (~(get by entries.u.k) u)
      ?~(e etags (~(put by etags) u s+etag.u.e))
    $(changes t.changes, sent (~(put by sent) u (numb:enjs:format (da-to-ms now))))
  ;<  ~  bind:m  ?:(stopped (pure:(fiber:fiber:nexus ,~) ~) (unfault pre (cat 3 'share-push/' id)))
  =/  mark=@ud  ?:(stopped since seq.u.k)
  %-  pure:m
  %+  row-put  row
  :~  ['pushed_seq' (numb:enjs:format mark)]
      ['suppressed' (suppress-json sup mark)]
      ['etags' [%o etags]]
      ['sent' [%o sent]]
  ==
::  +google-prod: wake the sync fiber (every backend) now
++  google-prod
  |=  pre=@t
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  *  bind:m  (poke-soft:io (grub-road pre 'google.sig') [[/ %json] `json`[%o ~]])
  (pure:m ~)
++  locate  locate:core
++  event-of  event-of:core
++  keyed  keyed:core
++  keyed-events  keyed-events:core
++  unkey  unkey:core
++  cancelled  cancelled:core
++  ev-kind  ev-kind:core
++  gs  gs:core
++  gn  gn:core
++  ms-to-da  ms-to-da:core
++  da-to-ms  da-to-ms:core
++  ms-arg  ms-arg:core
++  cross-site  cross-site:core
::  +send-text: a plain-text answer, an error mostly
++  send-text
  |=  [eyre-id=@ta code=@ud why=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-simple:srv eyre-id [[code ~] `(as-octs:mimes:html why)])
++  send-json
  |=  [eyre-id=@ta =json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bod=octs  (as-octs:mimes:html (en:json:html json))
  (send-simple:srv eyre-id [[200 ['content-type' 'application/json'] ~] `bod])
++  lead-pushes  lead-pushes:core
++  alarm-pushes  alarm-pushes:core
::  +send-pushes: each reminder to the browsers subscribed through the
::  kernel (web push) and, when %trunk here takes notices, to the owner's
::  phones. Both carry the same tag, so a phone that gets both shows one.
++  send-pushes
  |=  pushes=(list [name=@t body=@t tag=@t])
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  pushes  (pure:m ~)
  ;<  wire=@ud  bind:m  trunk-wire
  =/  todo=(list [name=@t body=@t tag=@t])  pushes
  |-  ^-  form:m
  ?~  todo  (pure:m ~)
  ;<  ~  bind:m
    (send-push:io [~ ~ ~ [name.i.todo body.i.todo `'/apps/calendar/icon.svg' `'/apps/calendar' `tag.i.todo]])
  ;<  ~  bind:m
    ?:  =(0 wire)  (pure:m ~)
    (trunk-notice wire tag.i.todo name.i.todo body.i.todo)
  $(todo t.todo)
::  +soft-scry: a typed scry through the kernel's /sys/scry service, as
::  +typed-scry:io, with the refusal swallowed: ~ when the weir refuses
::  /sys/scry/. The wire is fixed: a nonce would ask /sys/bowl.sig.
++  soft-scry
  |*  [=mold mark=@tas =path]
  =/  m  (fiber:fiber:nexus ,(unit mold))
  ^-  form:m
  ;<  ~  bind:m
    (send-dart:io %node /trunk-scry &+&+[/sys/scry %'main.sig'] %poke [[/ %scry-request] [mark `^path`path]])
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]  [%done ~]
      [~ %pack * *]
    ?.  =(/trunk-scry wire.u.in)  [%skip ~]
    ?~(err.u.in [%wait ~] [%done ~])
      [~ %poke * *]
    ?.  =([/ mark] p.sage.u.in)  [%skip ~]
    [%done `!<(mold q.sage.u.in)]
  ==
::  +trunk-wire: the wire %trunk here speaks, when reminders can reach the
::  owner's phones through it: it runs, speaks wire 12 (push-notice) or
::  later, and the kernel carries the marc that types the poke. 0 when
::  not. Each asked softly, so a refused road is a recorded fault and not
::  a parked fiber. %gu first, with gall's own trailing $: in the kernel's
::  event a scry of an agent that is not running fails past mole, and an
::  empty path blocks.
++  trunk-wire
  =/  m  (fiber:fiber:nexus ,@ud)
  ^-  form:m
  ;<  up=(unit ?)  bind:m  (soft-scry ? %loob /gu/trunk/$)
  ?~  up
    ;<  ~  bind:m
      %:  fault  './'  'road/scry'  %warning  &
        "the scry road /sys/scry/ is refused, so reminders reach browsers only, not phones"
        "grant it at /apps/grubbery/permits"
      ==
    (pure:m 0)
  ;<  ~  bind:m  (unfault './' 'road/scry')
  ?.  u.up  (pure:m 0)
  ;<  ver=(unit json)  bind:m  (soft-scry json %json /gx/trunk/version/json)
  ?~  ver  (pure:m 0)
  =/  wire=@ud  (fall (gn u.ver 'wire') 0)
  ?.  (gte wire 12)  (pure:m 0)
  ::  the marc, in either of the kernel's spellings
  ;<  a=(unit view:nexus)  bind:m
    (peek-soft:io [%& %& /code/mar/clay/trunk/trunk %'action.hoon'] ~)
  ;<  b=(unit view:nexus)  bind:m
    (peek-soft:io [%& %& /code/mar/clay/trunk %'trunk-action.hoon'] ~)
  ?:  &(?=(~ a) ?=(~ b))
    ;<  ~  bind:m
      %:  fault  './'  'road/code'  %warning  &
        "the peek road /code/mar/clay/trunk/ is refused, so reminders reach browsers only, not phones"
        "grant it at /apps/grubbery/permits"
      ==
    (pure:m 0)
  ;<  ~  bind:m  (unfault './' 'road/code')
  ?.  |(?=([~ %file *] a) ?=([~ %file *] b))
    ;<  ~  bind:m
      %:  fault  './'  'trunk-marc'  %warning  &
        "this ship's grubbery has no mark for poking trunk, so reminders reach browsers only, not phones"
        "update grubbery"
      ==
    (pure:m 0)
  ;<  ~  bind:m  (unfault './' 'trunk-marc')
  (pure:m wire)
::  +trunk-poke: one trunk-action poke to %trunk on this ship through the
::  kernel's /sys/gall service, as +remote-poke-wait. The service takes
::  the request (%pack on our wire) and trunk's ack comes back as a
::  [/ %poke-ack] poke on the same wire, which names the moment (a nonce
::  would ask /sys/bowl.sig), so an ack that comes after a wait gave up is
::  no answer to the next. A local agent answers at once, but gall holds a
::  poke to a suspended one, so 30 s at most: %late. The timer is set
::  before the poke goes: setting one asks /sys/behn and takes the first
::  %pack or veto that comes, which would be the poke's.
+$  trunk-res  ?(%sent %refused %nacked %late)
++  trunk-poke
  |=  act=*
  =/  m  (fiber:fiber:nexus ,trunk-res)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  ;<  now=@da  bind:m  get-time:io
  =/  w=wire  /trunk-notice/(scot %da now)
  ;<  ~  bind:m  (set-timer:io /trunk (add now ~s30))
  ;<  ~  bind:m
    %-  send-dart:io
    [%node w &+&+[/sys/gall %'main.sig'] %poke [[/ %gall-poke] [[our %trunk] trunk-action+act]]]
  ;<  res=trunk-res  bind:m
    |=  input:fiber:nexus
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %veto %node * * *]
      ?.(=(w wire.dart.u.in) [%skip ~] [%done %refused])
        [~ %pack * *]
      ?:  &(!=(w wire.u.in) ?=([%trunk-notice *] wire.u.in))  [%wait ~]
      ?.  =(w wire.u.in)  [%skip ~]
      ?~(err.u.in [%wait ~] [%done %nacked])
        [~ %poke * *]
      ?:  =([/ %timer-wake] p.sage.u.in)
        ?.(?=([%trunk *] !<(path q.sage.u.in)) [%skip ~] [%done %late])
      ?.  =([/ %poke-ack] p.sage.u.in)  [%skip ~]
      =/  [aw=wire err=(unit tang)]  !<([wire (unit tang)] q.sage.u.in)
      ::  an earlier poke's, come after its wait gave up: taken and
      ::  dropped, or it would sit in the queue for good
      ?:  &(!=(w aw) ?=([%trunk-notice *] aw))  [%wait ~]
      ?.  =(w aw)  [%skip ~]
      [%done ?~(err %sent %nacked)]
    ==
  ;<  ~  bind:m  (cancel-timer:io /trunk)
  (pure:m res)
::  +trunk-notice: one reminder to the phones. A refusal or a nack of the
::  poke trunk should take is a recorded fault.
++  trunk-notice
  |=  [wire=@ud tag=@t title=@t body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  trunk takes tag, title, body and open together up to 4 KiB.
  ::  ponytail: a name that long is skipped, not cut
  ?:  (gth :(add (met 3 tag) (met 3 title) (met 3 body)) 3.800)  (pure:m ~)
  ::  trunk refuses an empty title; the phone still gets the reminder
  =/  title=@t  ?:(=('' title) 'Reminder' title)
  ::  wire 14 names the sender, so the calendar is its own app on the
  ::  phone and the trunk page, with its own switch and its own pace,
  ::  rather than one "grubbery" with every other grubbery app. A kernel
  ::  whose marc knows only the plain poke nacks the named one: send the
  ::  plain one then, as wire 12 and 13 take.
  ;<  res=trunk-res  bind:m
    ?.  (gte wire 14)  (trunk-poke [%push-notice tag title body ~])
    ;<  named=trunk-res  bind:(fiber:fiber:nexus ,trunk-res)
      (trunk-poke [%push-notice-as 'calendar' tag title body ~])
    ?.  ?=(%nacked named)  (pure:(fiber:fiber:nexus ,trunk-res) named)
    (trunk-poke [%push-notice tag title body ~])
  ?-    res
      %sent
    ;<  ~  bind:m  (unfault './' 'road/gall')
    (unfault './' 'trunk-notice')
      %refused
    %:  fault  './'  'road/gall'  %warning  &
      "the gall road /sys/gall/ is refused, so reminders reach browsers only, not phones"
      "grant it at /apps/grubbery/permits"
    ==
      %nacked
    %:  fault  './'  'trunk-notice'  %warning  &
      "trunk refused a reminder notice, so it did not reach your phones"
      "look at trunk's log at /apps/trunk"
    ==
      %late
    %:  fault  './'  'trunk-notice'  %warning  &
      "trunk did not answer a reminder notice in 30 s, so it may not have reached your phones"
      "check that trunk is running (|suspend may have stopped it)"
    ==
  ==
+$  feed-sync  feed-sync:core
++  feed-id  feed-id:core
++  do-sync
  |=  [feeds=(list [nm=@t url=@t]) lo=@da hi=@da dz=(unit @t)]
  =/  m  (fiber:fiber:nexus ,feed-sync)
  ^-  form:m
  =|  out=feed-sync
  |-
  ?~  feeds  (pure:m out)
  ;<  [status=@ud body=@t]  bind:m  (fetch-full [%'GET' url.i.feeds ~ ~])
  =/  evs=(unit (list vevent:ics))
    ?.  &(=(200 status) !=('' body))  ~
    (mole |.((events:ics body)))
  ?~  evs
    $(feeds t.feeds)
  =.  ok.out  (~(put in ok.out) nm.i.feeds)
  =.  out
    %+  roll  u.evs
    |=  [ve=vevent:ics acc=_out]
    ?:  =('' uid.ve)  acc
    =/  id=@ta  (feed-id nm.i.feeds uid.ve)
    =.  seen.acc  (~(put in seen.acc) id)
    ?.  =('' rrule.ve)  acc(skipped +(skipped.acc))
    =/  ev=(unit event:cal)  (ics-event ve nm.i.feeds lo hi dz)
    ?~  ev  acc
    acc(got (~(put by got.acc) id u.ev))
  $(feeds t.feeds)
++  apply-feeds  apply-feeds:core
++  ics-event  ics-event:core
::  +weir-json: the roads calendar actually reaches (declared for the shell)
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
          (line '/sys/scry/' 'ask whether trunk on this ship takes reminders for your phones. Refuse this and reminders reach browsers only')
          (line '/sys/iris/' 'fetch the Google calendar feeds you add, by their secret address. Refuse this and feeds are unavailable; your own events are unaffected')
          (line '/sys/gall/' 'send a reminder to your phones through trunk, tell another ship you shared a calendar with it, and send it your edits to a calendar it shared with you. Refuse this and sharing with ships is unavailable; everything else works')
          (line '/sys/ames/registry' 'let the ships you share a calendar with read it. Refuse this and sharing with ships is unavailable')
          (line '/sys/ames/usergroups/' 'keep one group per shared calendar: the ships that may read it, and whether they may edit it')
      ==
      :-  'peek'
      :-  %a
      :~  (line '/sys/link/' 'look up where this app is installed, so the page can address its own writer. Refuse this and the page cannot save events')
          (line '/code/mar/clay/trunk/' 'see whether this ship can hand trunk a reminder for your phones. Refuse this and reminders reach browsers only')
          (line '/sys/ames/usergroups/' 'see which ships a calendar is shared with')
          (line '/sys/ames/ships/' 'read a calendar another ship shared with you, and keep it current. Refuse this and calendars shared with you are unavailable')
      ==
      :-  'make'
      :-  %a
      :~  (line '/sys/ames/usergroups/' 'make the group for a calendar the first time it is shared')
      ==
  ==
++  migrate-kinds  migrate-kinds:core
++  migrate-rules  migrate-rules:core
++  kind-table  kind-table:core
++  kind-for
  |=  =rail:tarball
  ^-  (unit kind:rules)
  (~(get by kind-table) name.rail)
::  +occurrence-index: which occurrence of an event starts at a moment
::
::  except.bound counts occurrences by index, and only the expansion of
::  the recurrence knows that count, so a client that holds a start time
::  must ask the calendar to do the counting. This walks +inflate:cal,
::  the same expansion the month and list views read, so the index it
::  answers is the one the page would skip. It inflates a day past when
::  because the walk's horizon is the naive wall moment, and a zone ahead
::  of UTC realizes a wall moment to an earlier instant. An occurrence
::  already skipped is absent from the index, so asking twice answers ~
::  rather than an index that has moved.
::
::  +moved-at: whether occurrence idx of series id has a moved copy (a
::  child whose RECURRENCE-ID names that occurrence)
++  moved-at
  |=  [c=calendar:cal home=@ta id=@ta idx=@ud]
  ^-  ?
  =/  got=(unit [cid=@ta e=entry:cal])  (locate c home id)
  ?~  got  |
  =/  k=(unit cal:cal)  (~(get by cals.c) cid.u.got)
  ?~  k  |
  =/  walk=event:cal  (set-skips event.e.u.got ~)
  ::  a RECURRENCE-ID names the series' wall clock; the walk, instants
  =/  z=(unit @t)  ?.(?=(%timed -.event.e.u.got) ~ zone.event.e.u.got)
  %+  lien  (kids-of:cal u.k uid.e.u.got)
  |=  ch=entry:cal
  =/  at=(unit @da)  (props-rid-moment props.ch event.e.u.got)
  ?~  at  |
  =(`idx (occurrence-index walk ?~(z u.at (fall (place:rules z u.at) u.at))))
++  occurrence-index
  |=  [ev=event:cal when=@da]
  ^-  (unit @ud)
  ::  a date or a task has no recurrence to walk
  ?:  ?=(?(%date %todo) -.ev)  ~
  =/  events=(map eid:cal event:cal)
    (~(put by *(map eid:cal event:cal)) 'it' ev)
  =/  [stops=(map eid:cal @da) o=order:cal]
    (inflate:cal events kind-for (add when ~d1) ~)
  ::  both edges of a span are indexed, so only a left edge is a start
  =/  hits=(list ref:cal)  ~(tap in (fall (get:on-order:cal o when) ~))
  |-  ^-  (unit @ud)
  ?~  hits  ~
  ?:  =(when l.span.i.hits)  `idx.i.hits
  $(hits t.hits)
::  +apply-until: compile an until-date into the index cap (dom) by
::  walking the kind's moments. An explicit count wins; only for shapes
::  with a recur. Sugar: the stored event keeps only dom.
++  apply-until
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
++  parse-recur  parse-recur:core
++  parse-event  parse-event:core
++  parse-alarms  parse-alarms:core
++  set-alarms  set-alarms:core
++  parse-priority  parse-priority:core
++  set-pri  set-pri:core
--
