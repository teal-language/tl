## Interfaces

Interfaces are, in essence, abstract records.

A concrete record is a type declared with `record`, which can be used
both as a Lua table and as a type. In object-oriented terms, the record
itself works as class whose fields work as class attributes,
while other tables declared with the record type are objects whose
fields are object attributes. For example:

```lua
local record MyConcreteRecord
   a: string
   x: integer
   y: integer
end

MyConcreteRecord.a = "this works"

local obj: MyConcreteRecord = { x = 10, y = 20 } -- this works too
```

An interface is abstract. It can declare fields, including those of
`function` type, but they cannot hold concrete values on their own.
Instances of an interface can hold values.

```lua
local interface MyAbstractInterface
   a: string
   x: integer
   y: integer
   my_func: function(self, integer)
   another_func: function(self, integer, self)
end

MyAbstractInterface.a = "this doesn't work" -- error!

local obj: MyAbstractInterface = { x = 10, y = 20 } -- this works

-- error! this doesn't work
function MyAbstractInterface:my_func(n: integer)
end

-- however, this works
obj.my_func = function(self: MyAbstractInterface, n: integer)
end
```

What is most useful about interfaces is that records can inherit
interfaces, using `is`:

```lua
local record MyRecord is MyAbstractInterface
   b: string
end

local r: MyRecord = {}
r.b = "this works"
r.a = "this works too because 'a' comes from MyAbstractInterface"
```

Note that the definition of `my_func` used `self` as a type name. `self`
is a valid type that can be used when declaring arguments in functions
declared in interfaces and records. When a record is declared to be a subtype
of an interface using `is`, any function arguments using `self` in the parent
interface type will then resolve to the child record's type. The type signature
of `another_func` makes it even more evident:

```lua
-- the following function complies to the type declared for `another_func`
-- in MyAbstractInterface, because MyRecord is the `self` type in this context
function MyRecord:another_func(n: integer, another: MyRecord)
   print(n + self.x, another.b)
end
```

Records and interfaces can inherit from multiple interfaces,
as long as their component parts are compatible (that is, as long
as the parent interfaces don't declare fields with the same name
but different types). Here is an example showing how incompatible
fields need to be stated explicitly, but compatible fields can be
inherited:

```lua
local interface Shape
   x: number
   y: number
end

local interface Colorful
   r: integer
   g: integer
   b: integer
end

local interface SecondPoint
   x2: number
   y2: number
   get_distance: function(self): number
end

local record Line is Shape, SecondPoint
end

local record Square is Shape, SecondPoint, Colorful
   get_area: function(self): number
end

--[[
-- this produces a record with these fields,
-- but Square also satisfies `Square is Shape`,
-- `Square is SecondPoint`, `Square is Colorful`
local record Square
   x: number
   y: number
   x2: number
   y2: number
   get_distance: function(self): number
   r: integer
   g: integer
   b: integer
   get_area: function(self): number
end
]]
```

Keep in mind that this refers strictly to subtyping of interfaces, not
inheritance of implementations. For that reason, records cannot inherit from
other records; that is, you cannot use `is` to do `local record MyRecord is
AnotherRecord`. You can define function fields in your interfaces and those
definitions will be inherited (as in the `get_distance` and `get_area`
examples above), but you need to ensure that the actual implementations of
these functions are resolved at runtime the same way as they would do in Lua,
most likely using metatables to perform implementation inheritance. Teal
does not implement a class/object model of its own, as it aims to be compatible
with the multiple class/object models that exist in the Lua ecosystem.
