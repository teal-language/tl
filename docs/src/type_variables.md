# Type variable matching

When Teal type-checks a generic function call, it infers any type variables
based on context. Type variables can appear in function arguments and return
types, so these are matched with the information available at the call site:

* the place where the function call is made is used to infer
  type variables in return types;
* the values passed as arguments are used to infer type variables
  appearing in function arguments.

For example, given a generic function with the following type:

```lua
local my_f: function<T, U>(T): U
```

...the following call will infer `T` to `boolean` and `U`
to `string`.

```
local s: string = my_f(true)
```

Note that each type variable is inferred upon its first match, and return
types are inferred first, then argument types. This means that if the type
signature was instead this:

```lua
local my_f: function<T>(T): T
```

then the call above would fail with an error like `argument 1: got boolean,
expected string`.

Matching multiple type variables to types requires particular care when
type variables with `is`-constraints are used multiple types. Consider
the following example, which probably does not do what you want:

```lua
local interface Shape
   area: number
end

local function largest_shape<S is Shape>(a: S, b: S): S
   if a.area > b.area then
      return a
   else
      return b
   end
end
```

When attempting to use this with different kinds of shapes at the same time,
we will get an error:

```lua
local record Circle is Shape
end

local record Square is Shape
end

local c: Circle = { area = 10 }
local s: Square = { area = 20 }

local l = largest_shape(c, s) -- error! argument 2: Square is not a Circle
```

The type variable `S` was matched to `c` first. We can instead do this:

```lua
local function largest_shape<S is Shape, T is Shape>(a: S, b: T): S | T
   if a.area > b.area then
      return a
   else
      return b
   end
end
```

But then we have to make records that can be discriminated in a union,
by giving their definitions `where` clauses. This is a possible solution:

```lua
-- we add a `name` to the interface
local interface Shape
   name: string
   area: number
end

local function largest_shape<S is Shape, T is Shape>(a: S, b: T): S | T
   if a.area > b.area then
      return a
   else
      return b
   end
end

-- we add `where` clauses to Circle and Square
local record Circle
   is Shape
   where self.name == "circle"
end

local record Square
   is Shape
   where self.name == "square"
end

-- we add the `name` fields so that the tables conform to their types;
-- in larger programs this would be typically done in constructor functions
local c: Circle = { area = 10, name = "circle" }
local s: Square = { area = 20, name = "square" }

local l = largest(c, s)
```

...which results in `l` having type `Circle | Square`.
