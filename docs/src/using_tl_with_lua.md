## Using tl with Lua

You can use tl to type-check not only Teal programs, but Lua programs too! When
type-checking Lua files (with the .lua extension or a Lua `#!` identifier in
the first line), the type-checker adds support for an extra type:

* unknown

which is the type of all non-type-annotated variables. This means that in a
Lua file you can declare untyped variables as usual:

```lua
local x -- invalid in .tl, valid but unknown in .lua
```

When processing .lua files, tl will report no errors involving unknown
variables. Anything pertaining unknown variables is, well, unknown. Think of .tl
files as the safer, "strict mode", and .lua files as the looser "lax mode".
However, even a Lua file with no annotations whatsoever will still have a bunch
of types: every literal value (numbers, strings, arrays, etc.) has a type.
Variables initialized on declaration are also assumed to keep consistent types
like in Teal. The types of the Lua standard library are also known to tl: for
example, the compiler knows that if you run `table.concat` on a table, the only
valid output is a string.

Plus, requiring type-annotated modules from your untyped Lua program will also
help tl catch errors: tl can check the types of calls from Lua to functions
declared as Teal modules, and will report errors as long as the input arguments
are not of type unknown.

Having unknown variables in a Lua program is not an error, but it may hide
errors. Running `tl check` on a Lua file will report every unknown variable in
a separate list from errors. This allows you to see which parts of your program
tl is helpless about and help you incrementally add type annotations to your
code.

Note that even though adding type annotations to .lua files makes it invalid
Lua, you can still do so and load them from the Lua VM once the Teal package
loader is installed by calling `tl.loader()`.

You can also create declaration files to annotate the types of third-party Lua
modules, including C Lua modules.
For more information, see the [declaration files](declaration_files.md) page.
