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
   MyPointType = record
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
global MyPointType = record
   x: number
   y: number
end

global MyCompositeType = record
   center: MyPointType
end
```

These can now be used unqualified in any file that requires them.

#### Global environment definition

If the third party library is "globally available" in your execution environment,
i.e., if you do not need to explicitly `require` it in your code, you can tell the compiler
to predefine it into its own type checking environment using a `tlconfig.lua` file:

```
return {
   global_env_def = "love"
}
```

You can find more information about global environment definition in the [compiler options](compiler_options.md#global-environment-definition) page.

