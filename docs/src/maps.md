## Maps

Another very common type of table is the map: a table where all keys of one
given type, and all values are of another given type, which may or may not be
the same as that of the keys. Maps are notated with curly brackets and a
colon:

```lua
local populations: {string:number}
local complicated: {Object:{string:{Point}}} = {}
local modes = { -- this is {boolean:number}
   [false] = 127,
   [true] = 230,
}
```

In case you're wondering, yes, an array is functionally equivalent to a map
with keys of type number.

When creating a map with string keys you may want to declare its type
explicitly, so it doesn't get mistaken for a record. Records are freely usable
as maps with string keys when all its fields are of the same type, so you
wouldn't have to annotate the type to get a correct program, but the
annotation will help the compiler produce better error messages if any errors
occur involving this variable:

```lua
local is_vowel: {string:boolean} = {
   a = true,
   e = true,
   i = true,
   o = true,
   u = true,
}
```

For now, if you have to deal with heterogeneous maps (that is, Lua tables with
a mix of types in their keys or values), you'll have to use casts.
