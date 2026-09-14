::  rrule: an RFC 5545 RRULE as a kind. args: {"rrule": "<text>"}.
::  See /lib/rrule for what is read and what is not.
/<  rules  /lib/rules.hoon
/<  rr     /lib/rrule.hoon
^-  kind:rules
|=  [args=(map @t json) start=@da idx=@ud]
^-  (unit @da)
=/  a  ~(. ja:rules args)
=/  r=(unit rule:rr)  (parse:rr (str:a 'rrule'))
?~  r  ~
(occurrence:rr u.r start idx)
