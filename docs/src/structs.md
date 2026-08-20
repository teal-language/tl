# Structs

`struct` is a thin layer over `record` that adds the few things typically
needed for object-oriented programming in Lua, without the metatable
boilerplate. It is intentionally minimal:

- an auto-generated `.new` constructor with a typed opts record
- an optional `:init()` hook; child constructors run every `init` in the
  hierarchy, root parent first, each exactly once
- an auto-set `__index` metatable so method syntax (`x:method()`) works
- single inheritance via `:Parent` (methods are flattened and defaults
  are merged at compile time; there is no runtime dispatch)
- field default values and a `static ... end` block for type-level fields

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

## How it works: the generated code

This section spells out exactly what `tl gen` emits for a struct, because
the design leans on it heavily: **all inheritance is resolved at compile
time, so instances never pay for it at runtime**. No lookup chains, no
metatable walks, no dispatch.

### What `.new` does

For a struct with fields, defaults and an `init`, the constructor is
generated as a plain function with four fixed steps:

```lua
local struct Point
   x: number
   y: number = 0
   distance: number
end

function Point:init()
   self.distance = math.sqrt(self.x ^ 2 + self.y ^ 2)
end
```

compiles to:

```lua
local Point = {}
Point.__index = Point                       -- (1) instance wiring
Point.new = function(opts)
   local self = setmetatable({}, Point)     -- (2) fresh instance
   for k, v in pairs(opts) do               -- (3) copy caller's fields
      self[k] = v
   end
   if opts.y == nil then self.y = 0 end     -- (4) apply defaults
   Point.init(self)                         -- (5) run init, direct call
   return self
end
```

Step by step:

1. **`X.__index = X`** is set once at declaration. It is the *only*
   metatable in the entire scheme, and it exists for one reason: when
   `opts` (step 3) or `init` (step 5) does not set a field, reading it
   from the instance falls back to the struct table — which is where
   methods and statics live.
2. **Allocation** — a plain table with that metatable.
3. **Field copy** — everything the caller passed in `opts` is copied
   as-is. Passing an unknown key is a *type error* (the `opts` parameter
   is typed as a record of exactly the struct's instance fields; static
   fields and methods are excluded from it).
4. **Defaults** — one explicit `if` per field that declared a default.
   The check is `== nil`, not falsiness, so `false` and `0` work
   correctly as overridden values. Defaults are emitted in field
   declaration order; child structs override parent defaults, and the
   merge happens at check time, so each constructor contains *one* `if`
   per defaulted field — never a duplicated parent assignment.
5. **`init`** — a direct call `X.init(self)`, see below.

If the struct declares no `init`, step 5 is omitted entirely — there is
no `if X.init then ...` guard, the checker knows the answer at compile
time. The same applies to defaults: a struct without defaults emits no
`if`s at all.

### What `init` does, and how inheritance chains run

`init` is a lifecycle hook, not a method. It is never flattened, never
inherited as a field, and never found through `__index` — `.new` calls
it by explicit name. That is what makes multiple inits composable:

```lua
local struct A
   log: {string}
end

function A:init()
   table.insert(self.log, "A")
end

local struct B:A
end

function B:init()
   table.insert(self.log, "B")
end

local struct C:B
end

function C:init()
   table.insert(self.log, "C")
end

local c = C.new { log = {} }
print(table.concat(c.log, ","))   --> A,B,C
```

The generated `C.new` contains the *chain*, root parent first:

```lua
C.new = function(opts)
   local self = setmetatable({}, C)
   for k, v in pairs(opts) do self[k] = v end
   A.init(self)                    -- unconditional: A declares init
   B.init(self)                    -- NOT emitted: B declares none
   C.init(self)
   return self
end
```

(Shown with `B.init` commented for illustration; in reality the call is
simply absent from the output.) The chain is computed at check time and
contains only ancestors that declare their own `init`, so:

- every `init` in the hierarchy runs **exactly once**,
- order is always **parent to child**,
- an ancestor without `init` is skipped with zero runtime cost,
- there are no guards and no lookups — just direct calls.

To call a parent `init` (or any parent method) from *inside* your own
code, refer to the parent by name: `A.init(self)`.

### Methods are flattened, not dispatched

Method calls on struct instances are a **single table lookup**. There is
no metatable chain between structs and no method resolution at call
time. Instead, at the point a child struct is declared, every method
known on its parent is copied into the child:

```lua
local struct Shape
   name: string
end

function Shape:describe(): string
   return "shape:" .. self.name
end

local struct Circle:Shape
   r: number
end
```

compiles to:

```lua
local Shape = {}
Shape.__index = Shape
-- ... Shape.new ...

function Shape:describe() ... end

local Circle = {}
Circle.__index = Circle
Circle.describe = Shape.describe          -- flattened at declaration
Circle.new = function(opts) ... end       -- init chain: none here
```

So `c:describe()` resolves as: instance table → (miss) → `__index` →
`Circle.describe` → hit. One hop, always.

**Overrides are just later assignments.** A method defined on the child
*after* its declaration overwrites the flattened copy:

```lua
function Circle:describe(): string
   return "circle:" .. self.name
end
-- now Circle.describe is the override; Shape.describe is untouched
```

The last definition wins, and parent implementations remain available by
name (`Shape.describe(self)`) for explicit delegation.

One consequence to be aware of: methods added to a parent *after* the
child declaration do not reach the child (neither for the type checker
nor at runtime) — flattening happens once, at declaration. Declare
parent methods before child structs; the checker enforces this order.

### Instance wiring, summarized

| What | When | Cost at call time |
|---|---|---|
| `__index = X` | once, at declaration | one metatable hop on instance field miss |
| method flattening (`X.m = P.m`) | once, at declaration | none — direct table entry |
| init chain | fixed call list inside `.new` | none — unconditional direct calls |
| defaults | one `if` per defaulted field in `.new` | `== nil` check only |

Everything inheritance-related is paid once per struct at load time,
never per instance, and never per method call.

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

Use `:Parent` after the struct name to declare a single parent struct.
The child inherits all of the parent's fields and methods:

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

local struct Dog:Animal
   breed: string
end

function Dog:init()
   self.sound = "Woof"     -- override parent's init
end

local d = Dog.new { name = "Rex", breed = "Labrador" }
print(d:speak())           --> Rex says Woof
print(d.breed)             --> Labrador
```

At runtime, inheritance is fully resolved at compile time — methods are
flattened into the child at declaration, and `init`s run as a fixed
chain of direct calls inside `.new`. See *How it works: the generated
code* above for the exact output and the reasoning.

There is intentionally **no multiple inheritance** and no `super` keyword.
If you need to call a parent method explicitly, refer to the parent by
name (e.g. `Animal.speak(self)`).

A parent may be referenced through a same-file type alias (`local type P = Point;
struct T:P` works and resolves to `Point` at runtime). Parents from other
modules are supported through top-level require locals — see
*Cross-module inheritance* below.

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
print(c1.PI)                      -- 3.14 (instance lookup falls back to the type)
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
  field lives on the type itself, shared by every instance.

### Inheritance

Static fields are inherited by child structs automatically:

```lua
local struct Base
   x: number
   static
      klass: string = "Base"
   end
end

local struct Derived:Base
   y: number
end

print(Derived.klass)              -- "Base" (inherited)
```

Initialized statics are re-emitted per child (an independent copy of the
initializer); a static declared without an initializer on a parent is not
readable through a child — assign it on the child explicitly if needed.

## Cross-module inheritance

A struct can extend a struct from another module when the module
returns the struct directly and you assign it to a top-level local:

```lua
-- animal.tl
local struct Animal
   name: string
   legs: number = 4
end

function Animal:speak(): string
   return self.name .. " speaks"
end

return Animal
```

```lua
-- dog.tl
local Animal = require("animal")

local struct Dog:Animal
   breed: string
end
```

The local holds the struct's runtime table (module files run to
completion before `require` returns), so the flattened method copies
(`Dog.speak = Animal.speak`) and the init chain (`Animal.init(self)`)
emitted into `dog.tl` are sound.

Cross-module parents come with restrictions, each rejected with a clear
error:

- the parent must be referenced by a single top-level `require` local —
  field paths (`mod.Shape`) and bare globals have no guaranteed runtime
  presence at the child's declaration site;
- the parent must not inherit `init` from its own ancestors (those
  ancestor tables are not visible outside the parent's module);
- the parent's default values must be literals — computed defaults may
  reference the parent module's locals, which don't exist in the
  inheriting module;
- structs described by declaration files (`.d.tl`) cannot be extended:
  their runtime shape is by contract and may not follow struct
  semantics.

## Current limitations

- Methods (including `init`) cannot be declared on a struct *after* its
  child structs: methods are flattened and inits chained into children at
  the children's declaration time, so anything added later would silently
  not reach them — the checker rejects such declarations with a clear
  error. Declare parent methods before child structs.
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
