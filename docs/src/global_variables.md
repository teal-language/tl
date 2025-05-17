## Global variables

Unlike in Lua, global variables in Teal need to be declared, because the
compiler needs to know its type. It also allows the compiler to catch typos in
variable names, because an invalid name will not be assumed to be some unknown
global that happens to be nil.

You declare global variables in Teal using `global`, like this, doing
declaration and/or assignment:

```lua
global n: number

global m: {string:boolean} = {}

global hi = function(): string
   return "hi"
end

global function my_function()
   print("I am a global function")
end
```

You can also declare global types, which are visible across modules, as long
as their definition has been previously required:

```lua
-- mymod.tl
local mymod = {}

global type MyPoint = record
   x: number
   y: number
end

return mymod
```

```lua
-- main.tl
local mymod = require("mymod")

local function do_something(p: MyPoint)
   -- ...
end
```

If you have circular type dependencies that span multiple files, you can
forward-declare a global type by specifying its name but not its implementation:

```lua
-- person.tl
local person = {}

global type Building

global record Person
   residence: Building
end

return person
```

```lua
-- building.tl
local building = {}

global type Person

global record Building
   owner: Person
end

return building
```

```lua
-- main.tl
local person = require("person")
local building = require("building")

local b: Building = {}
local p: Person = { residence = b }

b.owner = p
```
