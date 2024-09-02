# Type aliasing rules in Teal

## The general rule

In Teal we can declare new types with user-defined names. These are called
_nominal types_. These nominal types may be unique, or aliases.

The `local type` syntax produces a new _nominal type_. Whenever you assign to
it another user-defined nominal type, it becomes a _type alias_. Whenever you
assign to it a type constructor, it becomes a new unique type. Type
constructors are syntax constructs such as: block constructors for records,
interfaces and enums (e.g. `record` ... `end`); function signature
declarations with `function()`; applications of generics with `<>`-notation;
declarations of array, tuple or map types with `{}`-notation; or a primitive
type name such as `number`.

Syntax such as `local record R` is a shorthand to `local type R = record`, so
the same rules apply: it declares a new unique type.

Nominal types are compared against each other _by name_, but type aliases are
considered to be equivalent.

```lua
local record Point3D
   x: number
   y: number
   z: number
end

local record Vector3D
   x: number
   y: number
   z: number
end

local p: Point3D = { x = 1.0, y = 0.3, z = 2.5 }

local v: Vector3D = p -- Teal compile error: Point3D is not a Vector3D

local type P3D = Point3D

local p2: P3D

p2 = p  -- ok! P3D is a type alias type Point3D
p = p2  -- ok! aliasing works both ways: they are effectively the same type
```

Nominal types are compared against non-nominal types _by structure_, so that
you can manipulate concrete values, which have inferred types. For example,
you can assign a plain function to a nominal function type, as long as the
signatures are compatible, and you can assign a number literal to a nominal
number type.

```lua
local type MyFunction = function(number): string

-- f has a nominal type
local f: MyFunction

-- g is inferred a structural type: function(number): string
local g = function(n: number): string
   return tostring(n)
end

f = g  -- ok! structural matched against nominal
g = f  -- ok! nominal matched against structural
```

You can declare structural types for functions explicitly:

```lua
local type MyFunction = function(number): string

-- f has a nominal type
local f: MyFunction

-- h was explicitly given a structural function type
local h: function(n: number): string

f = h  -- ok!
h = f  -- ok!
```

By design, there is no syntax in Teal for declaring structural record types.

## Some examples

Type aliasing only happens when declaring a new user-defined nominal type
using an existing user-defined nominal type.

```lua
local type Record1 = record
   x: integer
   y: integer
end

local type Record2 = Record1

local r1: Record1
assert(r1 is Record2) -- ok!
```

This does not apply to primitive types. Declaring a type name with the same
primitive type as a previous declaration is not an aliasing operation. This
allows you to create types based on primitive types which are distinct from
each other.

```lua
local type Temperature = number

local type TemperatureAlias = Temperature

local type Width = number

local temp: Temperature

assert(temp is TemperatureAlias)  -- ok!
assert(temp is Width)             -- Teal compile error: temp (of type Temperature) can never be a Width
```

Like records, each declaration of a function type in the program source code
represents a distinct type. The `function(...):...` syntax for type
declaration is a type constructor.

```lua
local type Function1 = function(number): string

local type Function2 = function(number): string

local f1: Function1

assert(f1 is Function2) -- Teal compile error: f1 (of type Function2) can never be a Function1
```

However, user-defined nominal names referencing those function types can be
aliased.

```lua
local type Function1 = function(number): string

local type Function3 = Function1

local f1: Function1
assert(f1 is Function3) -- ok!
```
