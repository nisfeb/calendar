::  html-utils, as much of grubbery's as calendar-core names: +get-key:kv,
::  as grubbery desk/lib/html-utils.hoon has it. Only the test desk has
::  this; on a ship grubbery supplies the real one.
|%
++  kv
  |%
  +$  key-value-list  (list [key=@t value=@t])
  ++  get-key
    |=  [key=@t =key-value-list]
    ^-  (unit @t)
    (get-header:http key key-value-list)
  --
--
