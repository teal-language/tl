## Union types

The language supports a basic form of union types. You can register a type that
is a logical "or" of multiple types: it will accept values from multiple types,
and you can discriminate them at runtime.

You can declare union types like this:

```lua
local a: string | number | MyRecord
local b: {boolean} | MyEnum
local c: number | {string:number}
```

To use a value of this type, you need to discriminate the variable, using the
`is` operator, which takes a variable of a union type and one of its types:

```lua
local a: string | number | MyRecord

if a is string then
   print("Hello, " .. a)
elseif a is number then
   print(a + 10)
else
   print(a.my_record_field)
end
```

As you can see in the example above, each use of the `is` operator causes the
type of the variable to be properly narrowed to the type tested in its
respective block.

The flow analysis of `is` also takes effect within expressions:

```lua
local a: string | number

local x: number = a is number and a + 1 or 0
```
