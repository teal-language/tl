## Your first Teal program

Let's start with a simple example, which declares a type-safe function. Let's
call this example `add.tl`:

```lua
local function add(a: number, b: number): number
   return a + b
end

local s = add(1,2)
print(s)
```

You can type-check it with

```
tl check add.tl
```

You can convert it to Lua with

```
tl gen add.tl
```

This will produce `add.lua`. But you can also run it directly with

```
tl run add.tl
```

We can also write modules in Teal which we can load from Lua. Let's create our
first module:

```lua
local addsub = {}

function addsub.add(a: number, b: number): number
   return a + b
end

function addsub.sub(a: number, b: number): number
   return a - b
end

return addsub
```

We can generate `addsub.lua` with

```
tl gen addsub.tl
```

and then require the addsub module from Lua normally. Or we can load the Teal
package loader, which will allow require to load .tl files directly, without
having to run `tl gen` first:

```sh
$ rm addsub.lua
$ lua
> tl = require("tl")
> tl.loader()
> addsub = require("addsub")
> print (addsub.add(10, 20))
```

When loading and running the Teal module from Lua, there is no type checking!
Type checking will only happen when you run `tl check` or load a program with
`tl run`.
