# Macro expressions

Teal supports a restricted form of macro expansion via the `macroexp`
construct, which declares a macro expression. This was added to the
language as the support mechanism for implementing the `where` clauses
in records and interfaces, which power the type resolution performed
by the `is` operator.

Macro expressions are always expanded inline in the generated Lua code.
The declaration itself produces no Lua code.

A macro expression is declared similarly to a function, only using
`macroexp` instead of `function`:

```lua
local macroexp add(a: number, b: number)
   return a + b
end
```

There are two important restrictions:

* the body of the macro expression can only contain a single `return`
  statement with a single expression;
* each argument can only be used once in the macroexp body.

The latter restriction allows for macroexp calls to be expanded inline in any
expression context, without the risk for producing double evaluation of
side-effecting expressions. This avoids the pitfalls commonly produced by C
macros in a simple way.

Because macroexps do not generate code on declaration, you can also
declare a macroexp inline in a record definition:

```lua
local record R
   x: number

   get_x: function(self): number = macroexp(self: R): number
      return self.x
   end
end

local r: R = { x = 10 }
print(r:get_x())
```

This generates the following code:

```lua
local r: R = { x = 10 }
print(r.x)
```

You can also use them for metamethods: this will cause the metamethod to
be expanded at compile-time, without requiring a metatable:

```lua
local record R
   x: number

   metamethod __lt: function(a: R, b: R) = macroexp(a: R, b: R)
      return a.x < b.x
   end
end

local r: R = { x = 10 }
local s: R = { x = 20 }
if r > s then
   print("yes")
end
```

This generates the following code:

```lua
local r = { x = 10 }
local s = { x = 20 }
if s.x < r.x then
   print("yes")
end
```

This is used to implement the pseudo-metamethod `__is`, which is used to
resolve the `is` operator. The `where` construct is syntax sugar to an
`__is` declaration, meaning the following two constructs are equivalent:

```lua
local record MyRecord is MyInterface
   where self.my_field == "my_record"
end

-- ...is the same as:

local record MyRecord is MyInterface
   metamethod __is: function(self: MyRecord): boolean = macroexp(self: MyRecord): boolean
      return self.my_field == "my_record"
   end
end
```

At this time, macroexp declarations within records do not allow inference,
so the `function` type needs to be explicitly declared when implementing a
a field or metamethod as a `macroexp`. This requirement may be dropped in
the future.
