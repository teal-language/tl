## Functions

Functions in Teal should work like you expect, and we have already showed
various examples.

You can declare nominal function types, like we do for records, to avoid
long-winded type declarations, especially when declaring functions that take
callbacks. This is done with using `function` types, and they can be generic as
well:

```lua
local type Comparator = function<T>(T, T): boolean

local function mysort<A>(arr: {A}, cmp?: Comparator<A>)
   -- ...
end
```

Note that functions can have optional arguments, as in the `cmp?` example above.
This only affects the _arity_ of the functions (that is, the number of arguments
passed to a function), not their types. Note that the question mark is assigned
to the argument name, not its type. If an argument is not optional, it may still
be given explicitly as `nil`.

Another thing to know about function declarations is that you can parenthesize
the declaration of return types, to avoid ambiguities when using nested
declarations and multiple returns:

```lua
f: function(function(? string):(number, number), number)
```

Note also that in this example the string argument of the return function type
is optional. When declaring optional arguments in function type declarations
which do not use argument names, The question mark is placed ahead of the
type. Again, this is an attribute of the argument position, not of the
argument type itself.

You can declare functions that generate iterators which can be used in
`for` statements: the function needs to produce another function that iterates.
This is an example [taken the book "Programming in Lua"](https://www.lua.org/pil/7.1.html):

```lua
local function allwords(): (function(): string)
   local line = io.read()
   local pos = 1
   return function(): string
      while line do
         local s, e = line:find("%w+", pos)
         if s then
            pos = e + 1
            return line:sub(s, e)
         else
            line = io.read()
            pos = 1
         end
      end
      return nil
   end
end

for word in allwords() do
   print(word)
end
```

The only changes made to the code above were the addition of type signatures
in both function declarations.

Teal also supports [macro expressions](macroexp.md), which are a restricted
form of function whose contents are expanded inline when generating Lua code.

### Function declaration syntax

Unlike Lua, bare `function` declarations are not global by default.
Like other variables, Teal requires functions to be declared as `local` or `global`.


```lua
local function a_local_function()
end

global function a_global_function()
end
```

One exception to the need of a `local` or `global` discriminator is when using
the "record function syntax", which is used to declare and assign a function
element to a record, because the visibility is already defined by the record
itself. You can use this syntax within the same scope where a
record is declared:

```lua
local record MyRecord
end

function MyRecord.a_record_function()
end
```

That supports both `.` and `:` notation, for an implied first argument `self`:

```lua
local record MyRecord
   x: integer
end

function MyRecord:print_x()
   print(self.x)
end
```

Note that this syntax is only supported for records. It cannot be used with
interfaces, because they are abstract. It also cannot be used with maps, emphasizing
that records and maps are distinct types with distinct uses in Teal. Even though
both are implemented as Lua tables, they are not interchangeable. If you have
a map with function values, you can use the assignment syntax. As a matter of style,
you may want to use the array index syntax, to emphasize to readers of your code
that this is a map, as the declaration and assignment might be far apart in the
source:

```lua
local funcs = {string : function(string):(integer)}

funcs["count_a"] = function(input: string)
   local n = 0
   for _ in input:gmatch("a") do
      n = n + 1
   end
   return n
end
```

The example above also showcases using a `function` as a value -- in this case,
being assigned to a map. Like in Lua, you can pass functions as argument to
functions, assign them to variables, maps, record fields, and so on, as long
as their types as compatible.

### Variadic functions

Just like in Lua, some functions in Teal may receive a variable amount of
arguments. Variadic functions can be declared by specifying `...` as the last
argument of the function:

```lua
local function test(...: number)
   print(...)
end

test(1, 2, 3)
```

In case your function returns a variable amount of values, you may also declare
variadic return types by using the `type...` syntax:

```lua
local function test(...: number): number...
   return ...
end

local a, b, c = test(1, 2, 3)
```

If your function is very dynamic by nature (for example, you are typing a
Lua function that can return anything), a typical return type will be `any...`.
When using these functions, often one knows at the call site what are the
types of the expected returns, given the arguments that were passed. To set
the types of these dynamic returns, you can use the `as` operator over
multiple values, using a parenthesized list of types:

```lua
local s = { 1234, "ola" }
local a, b = table.unpack(s) as (number, string)

print(a + 1)      -- `a` has type number
print(b:upper())  -- `b` has type string
```

