::  dav: the XML side of CalDAV — reading a request body, building a
::  multistatus. Element names are matched by local name; the prefix a
::  client chose is not our business. Our own output declares D, C, CS
::  and A on the root and uses those prefixes.
::
|%
::  +local: an element's local name
++  local
  |=  n=mane
  ^-  @tas
  ?@(n n +.n)
::  +kids: the child elements with this local name
++  kids
  |=  [x=manx name=@tas]
  ^-  marl
  (skim c.x |=(k=manx =(name (local n.g.k))))
::  +kid: the first child element with this local name
++  kid
  |=  [x=manx name=@tas]
  ^-  (unit manx)
  =/  ks=marl  (kids x name)
  ?~(ks ~ `i.ks)
::  +find-el: depth-first, the first element with this local name
++  find-el
  |=  [x=manx name=@tas]
  ^-  (unit manx)
  ?:  =(name (local n.g.x))  `x
  =/  cs=marl  c.x
  |-
  ?~  cs  ~
  =/  got=(unit manx)  ^$(x i.cs)
  ?^  got  got
  $(cs t.cs)
::  +text: an element's text content (the text nodes, concatenated)
++  text
  |=  x=manx
  ^-  tape
  %-  zing
  %+  turn  c.x
  |=  k=manx
  ^-  tape
  ?.  =(%$ n.g.k)  (text k)
  =/  a=mart  a.g.k
  ?~  a  ""
  v.i.a
::  +parse: a request body to an element, ~ when empty or malformed
++  parse
  |=  body=@t
  ^-  (unit manx)
  ?:  =('' body)  ~
  (de-xml:html body)
::  +prop-names: the local names asked for in <prop>; ~ means allprop
++  prop-names
  |=  x=(unit manx)
  ^-  (list @tas)
  ?~  x  ~
  =/  p=(unit manx)  (find-el u.x %prop)
  ?~  p  ~
  (turn c.u.p |=(k=manx (local n.g.k)))
::  ---- building ----
::  a property we answer: its element, ready to sit inside <D:prop>
+$  prop  manx
++  el
  |*  [n=mane c=marl]
  ^-  manx
  [[n ~] c]
++  tx
  |=  t=tape
  ^-  manx
  [[%$ [%$ t] ~] ~]
++  d-el   |=([n=@tas c=marl] ^-(manx (el [%'D' n] c)))
++  c-el   |=([n=@tas c=marl] ^-(manx (el [%'C' n] c)))
++  href   |=(h=tape ^-(manx (d-el %href ~[(tx h)])))
++  status
  |=  code=@ud
  ^-  manx
  (d-el %status ~[(tx "HTTP/1.1 {(a-co:co code)} {(reason code)}")])
++  reason
  |=  code=@ud
  ^-  tape
  =/  table=(map @ud tape)
    %-  my
    :~  [200 "OK"]
        [201 "Created"]
        [204 "No Content"]
        [207 "Multi-Status"]
        [403 "Forbidden"]
        [404 "Not Found"]
        [412 "Precondition Failed"]
    ==
  (fall (~(get by table) code) "OK")
::  +propstat: one status for a set of props
++  propstat
  |=  [code=@ud props=(list prop)]
  ^-  manx
  (d-el %propstat ~[(d-el %prop props) (status code)])
::  +response: an href with its found props and the ones we do not have
++  response
  |=  [h=tape found=(list prop) missing=(list @tas)]
  ^-  manx
  %+  d-el  %response
  :-  (href h)
  :-  (propstat 200 found)
  ?~  missing  ~
  ~[(propstat 404 (turn missing |=(n=@tas (d-el n ~))))]
::  +status-response: an href with a status only (sync-collection deletes,
::  multiget misses)
++  status-response
  |=  [h=tape code=@ud]
  ^-  manx
  (d-el %response ~[(href h) (status code)])
::  +multistatus: the document, as text
++  multistatus
  |=  [responses=marl extra=marl]
  ^-  @t
  =/  root=manx
    :_  (weld responses extra)
    :-  [%'D' %multistatus]
    :~  [[%xmlns %'D'] "DAV:"]
        [[%xmlns %'C'] "urn:ietf:params:xml:ns:caldav"]
        [[%xmlns %'CS'] "http://calendarserver.org/ns/"]
        [[%xmlns %'A'] "http://apple.com/ns/ical/"]
    ==
  (crip (weld "<?xml version=\"1.0\" encoding=\"utf-8\"?>" (en-xml:html root)))
::  +enc-seg: a path segment, percent-encoded but for the unreserved set
++  enc-seg
  |=  t=tape
  ^-  tape
  %-  zing
  %+  turn  t
  |=  c=@t
  ^-  tape
  ?:  ?|  &((gte c 'a') (lte c 'z'))
          &((gte c 'A') (lte c 'Z'))
          &((gte c '0') (lte c '9'))
          =('-' c)  =('.' c)  =('_' c)
      ==
    [c ~]
  =/  hex=tape  (trip (crip ((x-co:co 2) c)))
  ['%' (cuss hex)]
::  +dec-seg: the reverse
++  dec-seg
  |=  t=tape
  ^-  tape
  |-
  ?~  t  ~
  ?:  &(=('%' i.t) ?=([@ @ *] t.t))
    =/  hx=(unit @)  (rush (crip [i.t.t i.t.t.t ~]) hex)
    ?~  hx  [i.t $(t t.t)]
    [u.hx $(t t.t.t)]
  [i.t $(t t.t)]
--
