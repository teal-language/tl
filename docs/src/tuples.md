## Tuples

Another common usage of tables in Lua are tuples: tables containing an ordered set
of elements of known types assigned to its integer keys.

```lua
-- Tuples of type {string, integer} containing names and ages
local p1 = { "Anna", 15 }
local p2 = { "Bob", 37 }
local p3 = { "Chris", 65 }
```

When indexing into tuples with number constants, their type is correctly
inferred, and trying to go out of range will produce an error.

```lua
local age_of_p1: number = p1[2] -- no type errors here
local nonsense = p1[3] -- error! index 3 out of range for tuple {1: string, 2: integer}
```

When indexing with a `number` variable, Teal will do its best by making a
[union](#union-types) of all the types in the tuple (following the
restrictions on unions detailed below)

```lua
local my_number = math.random(1, 2)
local x = p1[my_number] -- => x is a string | number union
if x is string then
   print("Name is " .. x .. "!")
else
   print("Age is " .. x)
end
```

Tuples will additionally help you keep track of accidentally adding more
elements than they expect (as long as their length is explicitly annotated and not
inferred).

```lua
local p4: {string, integer} = { "Delilah", 32, false } -- error! expected maximum length of 2, got 3
```

One thing to keep in mind when using tuples versus arrays is type inference,
and when you should or shouldn't need it. A table will be inferred as an array
if all of its elements are the same type, and as a tuple if any of its types
aren't the same. So if you want an array of a union type instead of a tuple,
explicitly annotate it as such:

```lua
local array_of_union: {string | number} = {1, 2, "hello", "hi"}
```

And if you want a tuple where all elements have the same type, annotate that
as well:

```lua
local tuple_of_nums: {number, number} = {1, 2}
```
