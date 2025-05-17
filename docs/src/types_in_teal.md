## Types in Teal

Teal is a dialect of Lua. This tutorial will assume you already know Lua, so
we'll focus on the things that Teal adds to Lua, and those are primarily type
declarations.

Types in Teal are more specific than in Lua, because Lua tables are so general.
These are the basic types in Teal:

* `any`
* `nil`
* `boolean`
* `integer`
* `number`
* `string`
* `thread` (coroutine)

Note: An `integer` is a sub-type of number; it is of undefined precision,
deferring to the Lua VM.

You can also declare more types using type constructors. This is the summary
list with a few examples of each; we'll discuss them in more detail below:

* arrays - `{number}`, `{{number}}`
* tuples - `{number, integer, string}`
* maps - `{string:boolean}`
* functions - `function(number, string): {number}, string`

Finally, there are types that must be declared and referred to using names:

* enums
* records
* interfaces

Here is an example declaration of each. Again, we'll go into more detail below,
but this should give you an overview:

```lua
-- an enum: a set of accepted strings
local enum State
   "open"
   "closed"
end

-- a record: a table with a known set of fields
local record Point
   x: number
   y: number
end

-- an interface: an abstract record type
local interface Character
   sprite: Image
   position: Point
   kind: string
end

-- records can implement interfaces, using a type-identifying `where` clause
local record Spaceship
   is Character
   where self.kind == "spaceship"

   weapon: Weapons
end

-- a record can also declare an array interface, making it double as a record and an array
local record TreeNode<T>
   is {TreeNode<T>}

   item: T
end

-- a userdata record: a record which is implemented as a userdata
local record File
   is userdata

   status: function(): State
   close: function(File): boolean, string
end
```
