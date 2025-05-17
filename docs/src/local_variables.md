## Local variables

Variables in Teal have types. So, when you declare a variable with the `local`
keyword, you need to provide enough information so that the type can be determined.
For this reason, it is not valid in Teal to declare a variable with no type at all
like this:

```lua
local x -- Error! What is this?
```

There are two ways, however, to give a variable a type:

* through declaration
* through initialization

Declaration is done writing a colon and a type. When declaring multiple
variables at once, each variable should have its own type:

```lua
local s: string
local r, g, b: number, number, number
local ok: boolean
```

You don't need to write the type if you are initializing the variable on
creation:

```lua
local s = "hello"
local r, g, b = 0, 128, 128
local ok = true
```

If you initialize a variable with nil and don't give it any type, this doesn't
give any useful information to work with (you don't want your variable to
be always nil throughout the lifetime of your program, right?) so you will
have to declare the type explicitly:

```
local n: number = nil
```

This is the same as omitting the ` = nil`, like in plain Lua, but it gives the
information the Teal program needs. Every type in Teal accepts nil as a valid
value, even if, like in Lua, attempting to use it with some operations would
cause a runtime error, so be aware!
