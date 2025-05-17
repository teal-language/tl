## Enums

Enums are a restricted type of string value, which represent a common practice
in Lua code: using a limited set of string constants to describe an
enumeration of possible values.

You describe an enum like this:

```lua
local type Direction = enum
   "north"
   "south"
   "east"
   "west"
end
```

or like this:

```lua
local enum Direction
   "north"
   "south"
   "east"
   "west"
end
```

Variables and arguments of this type will only accept values from the declared
list. Enums are freely convertible to strings, but not the other way around.
You can of course promote an arbitrary string to an enum with a cast.
