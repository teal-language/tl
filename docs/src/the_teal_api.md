# The Teal API

If you have Lua application, you can load the Teal compiler API and use it to convert
Teal source code into Lua source code on the fly. This is useful, for example, for
adding Teal support to a Lua-based plugin system.

## Before we begin: getting the API

Before we `require` any code, let's consider how to integrate the Teal compiler
in your application. As it is typical in the Lua ecosystem, there are a few
ways to do it.

### An application which embeds Lua sources

If you have an application (let's say, written in C, C++ or Rust), which embeds Lua
sources, the simplest way to do it is to embed the amalgamated Teal
sources, `teal.lua`, into your application's Lua sources the same way you embed
any other Lua modules. `teal.lua` is included in the Teal source distribution,
and it is a single file which encapsulates all `teal.*` modules that comprise
the Lua compiler.

### Using the `teal` modules directly

You might want to go this route if you are building a pure-Lua application,
and you want to integrate dependencies using a package manager ecosystem such
as LuaRocks or Lux. You can register a dependency on the `tl` package using
your package manager of choice and require `teal` like you require any other
module.

## The entry point

Now we can start by requiring the `teal` module, and getting a compiler instance:

```lua
local teal = require("teal")

local compiler = teal.compiler()
```

We then need to give the compiler some input, which can be a filename, or some
Teal code as a string. This will produce an input handle.

To read from a file, you can use `open`:

```lua
-- Let's create a simple .tl file:
local fd = io.open("my_file.tl", "w")
fd:write("print('hello')")
fd:close()

-- We can load the file using the `open` method of the API:
local handle1 = compiler:open("my_file.tl")

-- We don't need the file anymore
os.remove("my_file.tl")
```

To read from a string, use `input`. The optional second argument is
a filename to be used in error messages.

```
-- We can read Teal code directly as a string using `input`:
local handle2 = compiler:input([[
   local x = 1
   local y = "oh-oh"
   print(x + y)
]])
```

We can use those handles to request either one or all steps of the compilation
pipeline to be performed. Here is an example generating code all at once:


```lua
local lua_code = handle1:gen()
assert(type(lua_code) == "string")
```

And here we can see the use of the API generating it step by step, using
the `handle2` example above, which contains a type error:

```lua
-- Lexing the tokens should be fine
local tokens, lex_errs = handle2:lex()
assert(type(tokens) == "table")
assert(#lex_errs == 0)

-- Parsing should be fine as well
local ast, parse_errs = tokens:parse()
assert(type(ast) == "table")
assert(parse_errs == nil)

-- Checking should catch the type error from our example!
local module, check_errs = ast:check()
assert(type(module) == "table")
assert(#check_errs.type_errors == 1)
```

Of course, if the code contains no errors, you can also call `gen`
and generate the Lua output. Both methods will produce the same result:

```
local handle3 = compiler:input([[
   local x: integer = 1
   local y: integer = 2
   print(x + y)
]])

-- Showcasing all steps
local lua_code = handle3:lex():parse():check():gen()
assert(lua_code == "local x = 1\nlocal y = 2\nprint(x + y)")

-- Or going straight to gen
local lua_code2 = handle3:gen()
assert(lua_code == lua_code2)
```
