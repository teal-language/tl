## Variable attributes

Teal supports variable annotations, with similar syntax and behavior to those
from Lua 5.4. They are:

### Const variables

The `<const>` annotation works in Teal like it does in Lua 5.4 (it works at
compile time, even if you're running a different version of Lua). Do note
however that this is annotation for variables, and not values: the contents of a
value set to a const variable are not constant.

```lua
local xs <const> = {1,2,3}
xs[1] = 999 -- ok! the array is not frozen
xs = {} -- Error! can't replace the array in variable xs
```

### To-be-closed variables

The `<close>` annotation from Lua 5.4 is only supported in Teal if your code
generation target is Lua 5.4 (see the [compiler options](compiler_options.md)
documentation for details on code generation targets). These work just
[like they do in Lua 5.4](https://www.lua.org/manual/5.4/manual.html#3.3.8).

```lua
local contents = {}
for _, name in ipairs(filenames) do
   local f <close> = assert(io.open(name, "r"))
   contents[name] = f:read("*a")
   -- no need to call f:close() because files have a __close metamethod
end
```

### Total variables

The `<total>` annotation is specific to Teal. It declares a const variable
assigned to a table value in which all possible keys need to be explicitly
declared. Note that you can only use `<total>` when assigning to a literal
table value, that is, when you are spelling out a table using a `{}` block.

Of course, not all types allow you to enumerate all possible keys: there is an
infinite number (well, not infinite because we're talking about computers, but
an impractically large number!) of possible strings and numbers, so maps keyed
by these types can't ever be total. Examples of valid key types for a total map
are booleans (for which there are only two possible values) and, most usefully,
enums.

Enums are the prime case for total variables: it is common to declare a number
of cases in an enum and then to have a map of values that handle each of these
cases. By declaring that map `<total>` you can be sure that you won't forget to
add handlers for the new cases as you add new entries to the enum.

```lua
local degrees <total>: {Direction:number} = {
   ["north"] = 0,
   ["west"] = 90,
   ["south"] = 180,
   ["east"] = 270,
}

-- if you later update the `Direction` enum to add new directions
-- such as "northeast" and "southwest", the above declaration of
-- `degrees` will issue a compile-time error, because the table
-- above is no longer total!
```

Another example of types that have a finite set of valid keys are records. By
marking a record variable as `<total>`, you make it so it becomes mandatory to
declare all its fields in the given initialization table.

```lua
local record Color
   red: integer
   green: integer
   blue: integer
end

local teal_color <total>: Color = {
   red = 0,
   green = 128,
   blue = 128,
}

-- if you later update the `Color` record to add a new component
-- such as `alpha`, the above declaration of `teal_color`
-- will issue a compile-time error, because the table above
-- is no longer total!
```

Note however that the totality check refers only to the presence of explicit
declarations: it will still accept an assignment to `nil` as a valid
declaration. The rationale is that an explicit `nil` entry means that the
programmer did consider that case, and chose to keep it empty. Therefore,
something like this works:

```lua
local vertical_only <total>: {Direction:MotionCallback} = {
   ["north"] = move_up,
   ["west"] = nil,
   ["south"] = move_down,
   ["east"] = nil,
}

-- This declaration is fine: the map is still total, as we are
-- explicitly mentioning which cases are left empty in it.
```

*(Side note: the name "total" comes from the concept of a "total relation" in
mathematics, which is a relation where, given a set of "keys" mapping to a set
of "values", the keys fully cover the domain of their type).*
