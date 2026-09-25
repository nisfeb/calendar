::  rrule: an RFC 5545 RRULE as a kind. args: {"rrule": "<text>"}, and
::  "until_naive" (unix ms) when its UTC UNTIL was read into a zone.
::  See /lib/rrule for what is read and what is not.
/<  rules  /lib/rules.hoon
/<  rr     /lib/rrule.hoon
^-  kind:rules
|=  [args=(map @t json) start=@da idx=@ud]
^-  (unit @da)
=/  r=(unit rule:rr)  (of-args-memo:rr args)
?~  r  ~
(occurrence:rr u.r start idx)
