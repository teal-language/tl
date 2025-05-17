## Generics

Teal supports a simple form of generics that is useful enough for dealing
collections and algorithms that operate over abstract data types.

You can use type variables wherever a type is used, and you can declare them
in both functions and records. Here's an example of a generic function:

```lua
local function keys<K,V>(xs: {K:V}):{K}
   local ks = {}
   for k, v in pairs(xs) do
      table.insert(ks, k)
   end
   return ks
end

local s = keys({ a = 1, b = 2 }) -- s is {string}
```

we declare the type variables in angle brackets and use them as types. Generic
records are declared and used like this:

```lua
local type Tree = record<X>
   {Tree<X>}
   item: X
end

local t: Tree<number> = {
   item = 1,
   { item = 2 },
   { item = 3, { item = 4 } },
}
```

A type variable can be constrained by an interface, using `is`:

```lua
local function largest_shape<S is Shape>(shapes: {S}): S
   local max = 0
   local largest: S
   for _, s in ipairs(shapes) do
      if s.area >= max then
         max = s.area
         largest = s
      end
   end
   return largest
end
```

The benefit of doing this instead of `largest_shape(shapes: {Shape}): Shape`
is that, if you call this function passing, say, an array `{Circle}`
(assuming that `record Circle is Shape`, Teal will infer `S` to `Circle`,
and that will be the type of the return value, while still allowing you
to use the specifics of the `Shape` interface within the implementation of
`largest_shape`.

Keep in mind though, the type variables are inferred upon their first match,
so, especially when using constraints, that might demand [additional
care](type_variables.md).
