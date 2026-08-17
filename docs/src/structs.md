# Structs

`struct` is a thin layer over `record` that adds the few things typically
needed for object-oriented programming in Lua, without the metatable
boilerplate. It is intentionally minimal:

- an auto-generated `.new` constructor
- an optional `:init()` hook called by the constructor
- an auto-set `__index` metatable so method syntax (`x:method()`) works
- single inheritance via `from`

Anything you can do with a `record` you can do with a `struct` — the only
difference is the ergonomics. Use `record` for plain data; use `struct` when
you would otherwise reach for `setmetatable` by hand.

## Declaring a struct

```lua
local struct Point
   x: number
   y: number
end
```

## Constructing instances

Every `struct` gets a `.new` constructor automatically. It takes a table
of fields, copies them into a fresh instance, calls `:init()` if present,
and returns the instance:

```lua
local p = Point.new { x = 3, y = 4 }
print(p.x, p.y)
```

There is no need (and no way) to define `Point.new` yourself — it is
always generated. To customise construction, define `:init()`:

```lua
local struct Point
   x: number
   y: number
   distance: number    -- computed in init
end

function Point:init()
   assert(self.x >= 0, "x must be non-negative")
   self.distance = math.sqrt(self.x ^ 2 + self.y ^ 2)
end

local p = Point.new { x = 3, y = 4 }
print(p.distance)   --> 5.0
```

`init` takes no arguments besides `self` (declare it with colon syntax).
`self` is already populated with whatever the caller passed to `.new`;
`init` is the place to validate, compute derived fields, or perform side
effects. The generated `.new` calls `init` explicitly as `X.init(self)`,
without going through the metatable — so `init` resolution is direct and
free of dispatch magic.

## Methods

Methods are declared with the usual Lua colon syntax. They work because
`struct` automatically wires up `X.__index = X`:

```lua
local struct Point
   x: number
   y: number
end

function Point:move(dx: number, dy: number)
   self.x = self.x + dx
   self.y = self.y + dy
end

local p = Point.new { x = 1, y = 2 }
p:move(10, 20)
```

Static methods use dot syntax, exactly like Lua:

```lua
function Point.origin(): Point
   return Point.new { x = 0, y = 0 }
end

local zero = Point.origin()
```

## Inheritance (single)

Use `from` to declare a single parent struct. The child inherits all of
the parent's fields and methods:

```lua
local struct Animal
   name: string
   sound: string
end

function Animal:init()
   self.sound = self.sound or "<silence>"
end

function Animal:speak(): string
   return self.name .. " says " .. self.sound
end

local struct Dog from Animal
   breed: string
end

function Dog:init()
   self.sound = "Woof"     -- override parent's init
end

local d = Dog.new { name = "Rex", breed = "Labrador" }
print(d:speak())           --> Rex says Woof
print(d.breed)             --> Labrador
```

At runtime, `Dog` chains to `Animal` via `setmetatable(Dog, { __index = Animal })`,
so any method resolved on a `Dog` instance falls back to `Animal` if not
defined on `Dog`.

There is intentionally **no multiple inheritance** and no `super` keyword.
If you need to call a parent method explicitly, refer to the parent by
name (e.g. `Animal.speak(self)`).

A parent may be referenced through a same-file type alias (`local type P = Point;
struct T from P` works and resolves to `Point` at runtime). Parents declared
in other modules are currently rejected with a clear error.

### Subtyping

A child struct is accepted anywhere its parent (or any ancestor) is
expected:

```lua
local function greet(a: Animal): string
   return a:speak()
end

local d = Dog.new { name = "Rex", breed = "Lab" }
print(greet(d))   -- ok: Dog is an Animal
```

## Nominal construction

Struct instances can only be created via `.new`. Assigning a table
literal (or a plain record) to a struct-typed variable is a type error:

```lua
local p: Point = { x = 1, y = 2 }   -- type error
local p = Point.new { x = 1, y = 2 } -- ok
```

This is deliberate: a bare table lacks the metatable wiring that
methods and `init` rely on, so accepting it would produce crashes at
runtime. Use `.new` (or an explicit `as` cast if you know better).

## When to use `struct` vs `record`

| Need... | Use |
|---|---|
| Plain data with named fields, no behaviour | `record` |
| Methods, construction, validation, inheritance | `struct` |

Both produce regular Lua tables at runtime — `struct` is just `record`
with the metatable plumbing automated.

## Default values

Instance fields may declare a default value with `= expr`:

```lua
local struct Point
   x: number
   y: number = 0
   label: string = "<unnamed>"
end

local p = Point.new { x = 3 }    -- y=0, label="<unnamed>" applied automatically
local q = Point.new { x = 1, y = 2, label = "origin" }  -- all overridden
```

The codegen emits an explicit `if opts.<field> == nil then self.<field> = <expr> end`
per defaulted field, so defaults work correctly even for falsy values
(e.g. `false`, `0`).

Default expressions are **typechecked** against the declared field type,
at the point of declaration:

```lua
local struct Point
   x: number = "oops"   -- type error: invalid default value for field 'x'
end
```

The expression is evaluated where the struct is declared, so it may
reference anything declared earlier in the module (locals, functions,
globals), but **not** names declared later:

```lua
local D: number = 42

local struct Point
   d: number = D        -- ok
end

local struct Bad
   v: number = later()  -- type error: unknown variable 'later'
end

local function later(): number
   return 7
end
```

## Static fields

Type-level (shared) fields go in a `static ... end` block. They are set
once on the type itself, not copied into instances:

```lua
local struct Counter
   count: number                  -- instance field, in .new opts

   static
      total_created: number = 0   -- shared, mutated across all instances
      PI: number = 3.14           -- constant
      version: string             -- no initializer; assigned later
   end
end

Counter.version = "1.0"           -- ok, assign later

local c1 = Counter.new { count = 10 }
local c2 = Counter.new { count = 20 }

print(Counter.total_created)      -- 0 (unless init mutated it)
print(Counter.PI)                 -- 3.14
print(c1.PI)                      -- 3.14 (via __index fallback)
```

A struct may have **at most one** `static` block, placed anywhere in
the body (before or after instance fields).

### What static fields are *not*

- They are **not** accepted by `.new` — passing a static field name in
  the opts table is a type error:
  ```lua
  Counter.new { count = 1, total_created = 99 }  -- type error
  ```
- They are **not** the same as a default-value instance field:
  `count: number = 0` is an instance default (per-instance); a static
  field is shared by every instance via the `__index` chain.

### Inheritance

Static fields are inherited by child structs automatically:

```lua
local struct Base
   x: number
   static
      klass: string = "Base"
   end
end

local struct Derived from Base
   y: number
end

print(Derived.klass)              -- "Base" (inherited)
```

## Current limitations

- Methods added to a parent *after* a child struct is declared are not
  visible to the type checker in the child (they do work at runtime via
  the `__index` chain). Declare parent methods before child structs.
- A struct can only extend a struct declared in the same module (a
  same-file type alias for the parent is fine). Cross-module parents
  are rejected with a clear error for now.
- Generic structs (`struct X<T>`) are not supported yet and produce a
  clear error.
- Default value expressions are checked in the scope of the struct
  declaration: forward references to names declared later in the module
  are rejected (see *Default values* above).
- No abstract methods, interfaces, or multiple inheritance.
- `init` takes no arguments besides `self`; pass any data via the `.new`
  opts table.
- `static` blocks may contain only field declarations (no nested
  `static function` syntax — static methods stay as regular
  `function X.method()` outside the struct body, distinguished by
  dot vs colon syntax).
- Declaring your own `X.new` for a struct is an error — `.new` is
  reserved and always generated; use `init` for construction logic.
