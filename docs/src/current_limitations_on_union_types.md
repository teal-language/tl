### Current limitations of union types

In the current version, there are two main limitations regarding support
for union types in Teal.

The first one is that the `is` operator always matches a variable, not arbitrary
expressions. This limitation is there to avoid aliasing.

The second one is that Teal only accepts unions over a set of types that
it can discriminate at runtime, so that it can generate code for the
`is` operator properly. That means we can either only use one table
type in a union, or, if we want to use multiple table types in a union,
they need to be records or interfaces that were declared with a `where`
annotation to discriminate them.

This means that these unions not accepted:

```lua
local invalid1: {string} | {number}
local invalid2: {string} | {string:string}
local invalid3: {string} | MyRecord
```

However, the following union can be accepted, if we declare the record
types with `where` annotations:

```
local interface Named
   name: string
end

local record MyRecord is Named
   where self.name == "MyRecord"
end

local record AnotherRecord is Named
   where self.name == "AnotherRecord"
end

local valid: MyRecord | AnotherRecord
```

A `where` clause is any Teal expression that uses the identifier `self`
at most once (if you need to use it multiple times, you can always write
a function that implements the discriminator expression and call that
in the `where` clause passing `self` as an argument).

Note that Teal has no way of proving at compile time that the set of `where`
clauses in the union is actually disjoint and can discriminate the values
correctly at runtime. Like the other aspects of setting up a Lua-based
object model, that is up to you.

Another limitation on `is` checks comes up with enums, since these also
translate into `type()` checks. This means they are indistinguishable from
strings at runtime. So, for now these are also not accepted:

```lua
local invalid4: string | MyEnum
local invalid5: MyEnum | AnotherEnum
```

This restriction on enums may be removed in the future.
