## Records

Records are the third major type of table supported in Teal. They represent
another super common pattern in Lua code, so much that Lua includes special
syntax for it (the dot and colon notations for indexing): tables with a set of
string keys known in advance, each of them corresponding to a possibly
different value type. Records (named as such in honor of the Algol/Pascal
tradition from which Lua gets much of the feel of its syntax) can be used
to represent objects, "structs", etc.

To declare a record variable, you need to create a record type first.
The type describes the set of valid fields (keys of type string and their values
of specific types) this record can take. You can declare types using `local
type` and global types using `global type`.

```lua
local type Point = record
   x: number
   y: number
end
```

Types are constant: you cannot reassign them, and they must be initialized with
a type on declaration.

Just like with functions in Lua, which can be declared either with `local f =
function()` or with `local function f()`, there is also a shorthand syntax
available for the declaration of record types:

```lua
local record Point
   x: number
   y: number
end
```

Tables that match the shape of the record type will be accepted as an
initializer of variables declared with the record type:

```lua
local p: Point = { x = 100, y = 100 }
```

This, however, won't work:

```lua
local record Vector
   x: number
   y: number
end

local v1: Vector = { x = 100, y = 100 }
local p2: Point = v1 -- Error!
```

Just because a table has fields with the same names and types, it doesn't mean
that it is a Point. This is because records in Teal are [nominal
types](aliasing.md).

You can always force a type, though, using the `as` operator:

```lua
local p2 = v1 as Point -- Teal goes "ok, I'll trust you..."
```

Note we didn't even have to declare the type of p2. The `as` expression resolves
as a Point, so p2 picks up that type.

You can also declare record functions after the record definition using the
regular Lua colon or dot syntax, as long as you do it in the same scope block
where the record type is defined:

```lua
function Point.new(x: number, y: number): Point
   local self: Point = setmetatable({}, { __index = Point })
   self.x = x or 0
   self.y = y or 0
   return self
end

function Point:move(dx: number, dy: number)
   self.x = self.x + dx
   self.y = self.y + dy
end
```

When using the function, don't worry: if you get the colon or dot mixed up, tl
will detect and tell you about it!

If you want to define the function in a later scope (for example, if it is a
callback to be defined by users of a module you are creating), you can declare
the type of the function field in the record and fill it later from anywhere:

```lua
local record Obj
   location: Point
   draw: function(Obj)
end
```

A record can also store array data, by declaring an array interface. You can
use it both as a record, accessing its fields by name, and as an array,
accessing its entries by number. A record can have only one array interface.

```lua
local record Node is {Node}
   weight: number
   name: string
end
```

Note the recursive definition in the above example: records of type Node can
be organized as a tree using its array part.

Finally, records can contain nested record type definitions. This is useful
when exporting a module as a record, so that the types created in the module
can be used by the client code which requires the module.

```lua
local record http

   record Response
      status_code: number
   end

   get: function(string): Response
end

return http
```

You can then refer to nested types with the normal dot notation, and use
it across required modules as well:

```lua
local http = require("http")

local x: http.Response = http.get("http://example.com")
print(x.status_code)
```
