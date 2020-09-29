# 0.8.0

2020-09-18

Some big language changes in this release! Type declarations were made more
consistent, with the introduction of `local type T = D` for declaring a type
`T` given a definition `D` (likewise for `global type`), instead of pretending
that type declarations were assignments. This allowed us to remove the kludgy
`functiontype` word (the definition for function types is the same as used for
function arguments: `local type F = function()···`

This release also includes major tooling improvements! The `tl` CLI received
major attention, with a new command `tl build` and many new options in
`tlconfig.lua`, making `tl` more comfortable to use for building projects. The
`tl` module also received some API improvements for programmatic use of the
compiler.

This release features commits by Darren Jennings, Patrick Desaulniers,
Corey Williamson, Chris West and Hisham Muhammad.

## What's New

### Language changes

* `local type` and `global type` syntax for type declarations
* Dropped support for `functiontype`: use `function` instead
* Shorthand syntax forms for declarations, similar to `local function` in Lua:
  * `local record R` as a synonym for `local type R = record` (same for `global`)
  * `local enum E` as a synonym for `local type E = enum` (same for `global`)
  * Shorthand forms are also accepted nested inside records
* Extended flow-based inference for empty tables: now when declaring a
  variable with an empty table (`local V = {}`), if its first use (lexically)
  is as an argument to a function, the compiler will infer the argument type to
  the variable
* Enums can be indexed with string methods
* Lots of additions and tweaks to the standard library definitions:
  * `collectgarbage`
  * `coroutine.close`
  * `math.atan` overload
  * the many metamethods in metatable definitions
  * Fixed declaration of `select()`

### Tooling

* New command `tl build`, which is able to compile multiple files at once,
  following configuration in `tlconfig.lua`
* `tl run` passes arguments to script, populating `...`
* `tl gen`: new flag `-o, --output`
* Many newly supported options in `tlconfig.lua`:
  * `build_dir`
  * `source_dir`
  * `files`
  * `include`
  * `exclude`
  * `include_dir` (new name of the previous `include`)
  * `skip_compat53`
* New functions in the `tl` module API:
  * `tl.gen`, a high-level function for generating Lua code from Teal code,
    akin to `tl gen` on the CLI
  * `tl.process_string`, a lower-level driver function which produces the
    result data structure including the AST for later processing

### Fixes

* Fixed a file handle leak in `tl.process`
* Initial newlines from input file are preserved in the generated output file,
  so that line numbers match in stack traces produced at runtime
* It now reports error when `...` is used in non-vararg
  functions
* Stricter type checks:
  * no longer accepts indexing a record with an arbitrary string
  * no longer accepts matching a map as a record
* Fixed resolution of multiple labels
* Better handling of varargs for `for in` iterators
* Parser fixes:
  * Accept `()` as a return type in a function declaration
  * Require separators in key/value table constructors
  * Fix acceptance of a stray separator in table constructors
    (accepted) and function calls (not accepted)

# 0.7.1

2020-06-14

A lot of important bugfixes driven by community reports!

Starting with this release, version numbers in the 0.x series
will indicate the presence of breaking changes when bumping
the second number (0.x.0), and both bugfixes and compatible
additions when bumping the third number (0.x.y). This should
make it easier to see when a release breaks something.

This release adds new features but introduces no breaking
changes, so we're calling it 0.7.1.

## What's New

### Language changes

* support tuples in `as` operator for casting vararg returns:
  you can now cast the return of variadic functions with
  a parenthesized list of types
* semantics of scope of `until` now matches that of Lua
* Standard library:
  * Fixed return type of `load`

### Tooling

* `tl` CLI:
  * New flag `--version`
  * New flag `-q`, `--quiet`
* `tl` module:
  * New function `tl.load` which is like Lua's `load()`
    but enables loading Teal code

### Documentation

* Various fixes in the grammar definition

### Fixes

* Fixes the resolution of generic types by delaying the resolution
  of type arguments
* Fixes parsing of paranthesized function return with varargs
* Does not stop parsing the input toplevel when a stray `end` is found
* Avoids a compiler crash when type checking call returns in
  a `return` statement
* Fixes an error when parsing invalid function arguments
* Fixes a crash in flow analysis when a variable does not exist

# 0.7.0

2020-06-08

This release had a bunch of community contributions!

## What's New

### Language changes

* `thread` is a new primitive type for representing coroutines
* Disallow unions of multiple function types, applying a similar
  restriction that was already in place for table types.
  These can't be efficiently destructured at runtime with `is`.
* Lots of additions to the standard library:
  * more overloads for the `load` function
  * `loadfile` and `dofile` functions
  * `coroutine` library
  * More math functions: `tointeger`, `type` and `ult`
  * math variables: `maxinteger` and `mininteger`
  * improvement the type definition of `pcall`
  * `xpcall`

### Tooling

* `tl` now reports when there is a syntax error loading `tlconfig.lua`

### Fixes

* A functiontype declaration can now refer to itself.
* Nominals declared in nested types now resolve correctly.

# 0.6.0

2020-06-03

## What's New

### Language changes

* Completed definitions of the `math` table to the standard
  library

### Fixes

* Resolve arrays of unions, and flatten unions of unions

# 0.5.2

2020-05-31

More bugfixes!

### Fixes

* An important fix for the code generation of table literals:
  it was causing incorrect Lua output for arrays with expanded
  contents, such as `{...}`
* Resolution of pcall now recurses: the compiler can now handle a
  pcalled `require` correctly
* Better error messages for errors using `require`: do not
  report "module not found" when a module _was found_ but does
  not report type information.

# 0.5.1

2020-05-29

Since I was on a roll doing bugfixes, here's a quick version bump!

### Fixes

* Detect and report unresolved nested nominal types
* Fix scope restriction for record functions
* Standard library tables can now be required with `require()`

# 0.5.0

2020-05-29

This release does not include a lot of changes, but it does change
the rules for exporting types across modules, so it is worth the
middle-number bump.

## What's new

### Language changes

* Types declared as `local` can be exported in modules
* Types that are `local` to a module and which are used in
  function signatures (e.g. as return types) can be destructured
  from requiring modules. This already partially worked before,
  but it required the variable to be used in the original
  module to force a type resolution.
  * Generics still require more work, but non-generic types
    should be propagating as described above. Generic types
    export correctly if made part of the module record definition.

### Fixes

* Fixed a parsing error when a colon in a variable declaration
  was not followed by a type list

# 0.4.2

2020-05-18

Another collection of bugfixes!

### Fixes

* Report error when a required module is not found
* Detects unresolved nominal types
* Fixes when using record type object as a record instance itself
* Fixes in the expansion of the type of a table literal
* Fixes the indentation in generated code
* More standard library additions
* Improved/fixed error messages

# 0.4.1

2020-05-05

Fixes a regression in record functions.

# 0.4.0

2020-05-03

## What's new

### Language changes

* Record definitions can be nested: this should make
  declarations of types in modules more natural

### Tooling

* Improvement in the position of error messages

# 0.3.0

2020-04-27

This is the first release with the simplified syntax
for generics, without requiring backticks!

## What's new

Besides the usual bugfixes (see the Git history for
details), here are the main changes:

### Language changes

* Type variables no longer need backticks: you can
  declare `function<T, U>(x: T): U` and use `T` and
  `U` as types inside the function
* Base type declarations can contain parentheses for
  clarity, e.g. `{string: (string|number)}`
* More standard library typing improvements

### Tooling

* `--include`/`-I` flag for including directories
  to the module search path
* `tl run` now auto-invokes the Teal package loader,
  so `.tl` files running with it can `require()`
  other `.tl` files without needing to use `tl gen`
  to generate `.lua` files first.
* `tl run` can also pass arguments to the running
  program again

# 0.2.0

2020-04-08

This is the first release where the language is
officially named Teal!

## What's new

Lots of bugfixes, as well as language changes, tooling
improvements and beginnings of documentation!

### Language changes

* Union types, still restricted (can only union between
  at most one table type and a non-table type -- in other
  words, type resolution at runtime happens using the
  Lua `type()`)
  * `is` operator for specializing union types with a test
* `goto` and labels
* Type variables need to be declared in functions with
  angle brackets: `function<...>` (this fixes scoping rules)
* `global function` is now valid syntax
* Accepts any element type on a table typed `{any:any}`.
* Booleans are stricter
* Disallow extending records with functions outside of
  original scope
* Standard library typing improvements

### Tooling

* New command-line parser using argparse,
  typecheck using `tl check`
* `-l` command line option for requiring libraries
* `--skip-compat53` flag
* Detects `lua` hashbang to enter lax mode

# 0.1.0

2020-02-02

First tagged release! Announced at FOSDEM 2020.

## What's new

* Everything!
