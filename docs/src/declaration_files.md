# Type definitions for third party libraries

You can create declaration files to annotate the types of third-party Lua
modules, including C Lua modules. To do so, create a file with the .d.tl
extension and require it as normal, i.e. `local lfs = require("lfs")`.

Types defined in this module will will be used as a source of type information 
checking with `tl check`, even though the real Lua module will be loaded
instead when requiring the module from Lua or `tl run`.

## Visibility

There are two ways to define these types:

### Composite Types

```
local record MyCompositeType
   record MyPointType
      x: number
      y: number
   end

   center: MyPointType
    -- insert more stuff here
end

return MyCompositeType
```

This will mean that references to `MyPointType` must be qualified (or locally declared) as
`MyCompositeType.MyPointType`.

### Global Types

```
global record MyPointType
   x: number
   y: number
end

global record MyCompositeType
   center: MyPointType
end
```

These can now be used unqualified in any file that requires them.

#### Global environment definition

Some customized Lua environments predefine some values into the Lua VM
space as global variables. An example of an environment
which presents this behavior is [LÖVE](https://love2d.org),
which predefines a `love` global table containing its API. This global is
just "there", and code written for that environment assumes it is available,
even if you don't load it with `require`.

To make the Teal compiler aware of such globals, you can define them
inside a declaration file, and tell the compiler to load the declaration module into its own type
checking environment, using the `--global-env-def` flag in the CLI or the
`global_env_def` string in `tlconfig.lua`.

For example, if you have a file called `love-example.d.tl` containing the
definitions for LÖVE:

```
-- love-example.d.tl

global record love
   record graphics
      print: function(text: string, x: number, y: number)
   end
end
```

You can put `global_env_def = "love-example"` in a `tlconfig.lua` file at
the root of your project, and `tl` will now assume that any globals declared
in `love-example.d.tl` are available to other modules being compiled:

```
-- tlconfig.lua

return {
   global_env_def = "love-example"
}
```

Example usage:

```
-- main.tl

love.graphics.print("hello!", 0, 0)
```

```
$ tl check main.tl
========================================
Type checked main.tl
0 errors detected
```

Note that when using `tl gen`, this option does not generate code for the
global environment module, and when using `tl run` it does not execute the
module either. This option is only meant to make the compiler aware of any
global definitions that were already loaded into a customized Lua VM.

## Reusing existing declaration files (and contributing new ones!)

The [Teal Types](https://github.com/teal-language/teal-types) repo contains
declaration files for some commonly-used Lua libraries.

Feel free to check it out and make your contribution!
