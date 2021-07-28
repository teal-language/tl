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

If the third party library is "globally available" in your execution environment,
i.e., if you do not need to explicitly `require` it in your code, you can tell the compiler
to predefine it into its own type checking environment.

For instance, assuming you have the following declaration file, called `love-example.d.tl`:

```
-- love-example.d.tl

global record love
   record graphics
      print: function(text: string, x: number, y: number)
   end
end
```

You can predefine the `love` module by creating a `tlconfig.lua` file at the root of your project:

```
-- tlconfig.lua

return {
   global_env_def = "love-example"
}
```

This makes the compiler aware of the `love` global record.
You may then freely refer to this variable in your code:

```
-- main.tl

love.graphics.print("hello!", 0, 0)
```

You can find more information about global environment definition in the [compiler options](compiler_options.md#global-environment-definition) page.
