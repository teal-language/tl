## Arrays

The simplest structured type in Teal is the array. An array is a Lua table where
all keys are numbers and all values are of the same type. It is in fact a Lua
sequence, and as such it has the same semantics as Lua sequences for things
like the # operator and the use of the `table` standard library.

Arrays are described with curly brace notation, and can be denoted via
declaration or initialization:

```lua
local values: {number}
local names = {"John", "Paul", "George", "Ringo"}
```

Note that values was initialized to nil. To initialize it with an empty table,
you have to do so explicitly:

```lua
local prices: {number} = {}
```

Creating empty tables to fill an array is so common that Teal includes a naive
inference logic to support determining the type of empty tables with no
declaration. The first array assignment to an empty table, reading the code
top-to-bottom, determines its type. So this works:

```lua
local lengths = {}
for i, n in ipairs(names) do
   table.insert(lengths, #n) -- this makes the  lengths table a {number}
end
```

Note that this works even with library calls. If you make assignments of
conflicting types, the tl compiler will tell you in its error message from
which point in the program it originally got the idea that the empty table was
an array of that incompatible type.

Note also that we didn't need to declare the types of i and n in the above
example: the for statement can infer those from the return type of the
iterator function produced by the ipairs call. Feeding ipairs with a {string}
means that the iteration variables of the `ipairs` loop will be number and
string. For an example of a custom user-written iterator, see the [Functions](#functions)
section below.

Note that all items of the array are expected to be of the same type. If you
need to deal with heterogeneous arrays, you will have to use the cast operator
`as` to force the elements to their desired types. Keep in mind that when you
use `as`, Teal will accept whatever type you use, meaning that it can also hide
incorrect usage of data:

```lua
local sizes: {number} = {34, 36, 38}
sizes[#sizes + 1] = true as number -- this does not perform a conversion! it will just stop tl from complaining!
local sum = 0
for i = 1, #sizes do
   sum = sum + sizes[i] -- will crash at runtime!
end
```
