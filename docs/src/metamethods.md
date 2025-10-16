## Metamethods

Lua supports metamethods to provide some advanced features such as operator
overloading. Like Lua tables, records support metamethods. To use metamethods
in records you need to do two things:

* declare the metamethods in the record type using the `metamethod` word to
  benefit from static type checking;
* and assign the metatable with `setmetatable` as you would normally do in Lua
  to get the dynamic metatable behavior.

Here is a complete example, showing the `metamethod` declarations in the
`record` block and the `setmetatable` declarations attaching the metatable.

```lua
local type Rec = record
   x: number
   metamethod __call: function(Rec, string, number): string
   metamethod __add: function(Rec, Rec): Rec
end

local rec_mt: metatable<Rec>
rec_mt = {
   __call = function(self: Rec, s: string, n: number): string
      return tostring(self.x * n) .. s
   end,
   __add = function(a: Rec, b: Rec): Rec
      local res: Rec = setmetatable({}, rec_mt)
      res.x = a.x + b.x
      return res
   end,
}

local r: Rec = setmetatable({ x = 10 }, rec_mt)
local s: Rec = setmetatable({ x = 20 }, rec_mt)

r.x = 12
print(r("!!!", 1000)) -- prints 12000!!!
print((r + s).x)      -- prints 32
```

Note that we explicitly declare variables as `Rec` when initializing the
declaration with `setmetatable`. The Teal standard library definition of
`setmetatable` is `function<T>(T, metatable<T>): T`, so declaring the correct
record type in the declaration assigns the record type to the type variable
`T` in the return value of the function call, causing it to propagate to the
argument types, matching the correct table and metatable types.

Operator metamethods for integer division `//` and bitwise operators are
supported even when Teal runs on top of Lua versions that do not support them
natively, such as Lua 5.1.
