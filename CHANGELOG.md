# 0.11.1

2021-02-07

Having great users means having great feedback! Here's a  quick bugfix release
addressing a few issues that were reported by the community right after the
release of Teal 0.11.0.

This release features commits by Hisham Muhammad.

## What's New

### Fixes

* Fixed inference in cases that combine `is` and `==` (#382)
* Fixed tuple resolution in literal tables
* Fixed incorrect `<const>` in table inference (#383)

# 0.11.0

2021-02-07

The FOSDEM 2021 edition!

This new release does not include big language changes, but includes a lot of
new stuff! The new `tl types` infrastructure for IDE tooling, `build.tl`
support in `tl build`, code generation options, and tons of bugfixes.

This release features commits by Corey Williamson, lenscas, Patrick
Desaulniers and Hisham Muhammad.

## What's New

### Language

* The module return type can be inferred anywhere at the top-level,
  not only at the outermost scope (#334)
* Records are compared nominally and all other types are compared
  structurally
* Flow inference added to the `==` operator
  * Testing for a value in an `if` test propagates it into the block,
    which is especially useful for constraining a string into an
    enum, for example
* Standard library improvements
  * `debug` library

### Tooling

* New experimental command: `tl types`,
  * It produces a JSON report designed to be consumed by IDE tooling:
    for each input file, it lists all types used in the source code by
    line and column location, all symbols declared by scope, all types
    and globals
  * Also includes experimental a Teal API, which is used to implement
    `tl types`:
    * `tl.get_types`, which produces the above report as a record
    * `tl.symbols_in_scope`, which given a report, a line and column,
      reports all symbols visible at that location.
  * This feature is still experimental because the compiler was extended
    to perform type checking on syntactically-incorrect inputs (because
    IDEs want to perform analysis on unfinished programs). Some incorrect
    inputs may cause the type checker it to stumble!
* Support for `build.tl` file in `tl build`, which allows you to run a
  build script written in Teal before your files are compiled (for example,
  to produce generated code)
* `tl build` now looks for `tlconfig.lua` in parent directories, so you
  can call it from anywhere in your project tree
* Improved error messages and reduced the number of cascading syntax errors
* The compat53 dependency is now optional (pcall-loaded) in generated Lua
  code. You can make it required or disable it completely using `gen_compat`
  in `tlconfig.lua` and `--gen-compat={required|optional|off}`
* You can now target the Lua version of the generated code with `gen_target`
  and `--gen-target`. Supported modes are `5.1` (for LuaJIT, Lua 5.1 and 5.2)
  and `5.3` for (Lua 5.3 and Lua 5.4).
* Friendly warnings on misuse of `pairs`/`ipairs`
* Type checker now runs in the package loader

### Fixes

* Preserves explicit semicolons in the input, to deal correctly with
  Lua grammar ambiguity
* New inference engine for `is` operator
  * Does negation correctly implementing DeMorgan's laws
* Fixed `is` for type arguments
* Fixed resolution of metamethod fields in nested types (#326)
* Fixed type comparison for tuple elements
* Fixed invariant comparison between empty tables and nominals (#332)
* Fixed precedence of `+` relative to `..`
* A _large_ number of parser fixes on bad input corner cases,
  thanks to fuzz testing and user feedback, prompted by the `tl types` work!

# 0.10.1

2021-01-07

Fixes, lots of fixes! We shipped a bunch of stuff in 0.10, so it's time
to clean some rough edges, thanks to the great feedback we've received
in that release. No big changes in the language this time (other than some
things that should have worked but didn't now do!). In the tooling
department, we now have configurable warnings, so you can enable or
disable them by category.
Also, stay tuned for the next Teal meetup later this month!

This release features commits by Darren Jennings, Corey Williamson and Hisham
Muhammad.

## What's New

### Language

* Allow using metamethods such as `__call` and operators on the `record`
  prototype itself (#313)
* Maps are now invariant on key and value types (#318)
* It is now an error to declare too many iteration variables in a `for-in`
  construct
* Some standard library definitions were changed from using polymorphic
  function to using union types (#317)

### Tooling

* Warning categories
  * You can disable specific warning categories such as redeclared
    variables with the `--wdisable` flag or with the `disable_warnings`
    entry in `tlconfig.lua`
  * You can list existing warning categories with `tl warnings`
* You can turn warnings into errors with `--werror`
* Nicer error message when `type` is declared without a `local` or `global`
  qualifier

### Fixes

* Fixed a parser crash on incomplete expressions
* Nested record prototypes can be used everywhere record prototypes can
* Fixed a leak of type variables when defining generic functions (#322)
* Fixed resolution of type arguments in recursive type definitions
  to avoid crashing the compiler
* Ensured that n-ary function returns don't leak into variable
  declaration types (#309)
* Fix `is` code generation for userdata

# 0.10.0

2020-12-31

We've had a lot of activity in Teal this month, so let's wrap it with a
new release! We had our very first Teal meetup
([recording](https://www.youtube.com/watch?v=cY9wANsoVx0&list=PL0NqP86GtfLF-7NKGzNeRcUtN-XqE0ej_)),
a [Twitch stream](https://twitch.tv/HishamHM) session,
lots of activity in our [Gitter chat](https://gitter.im/teal-language/community)
with folks from the community building various projects, and providing
great feedback which helped us prioritize and shape the evolution of
the language. So let's celebrate with Teal 0.10.0, which packs a lot of
new stuff! Happy New Year! :tada:

This release features commits by Enrique García Cota, Darren Jennings,
Corey Williamson and Hisham Muhammad.

## What's New

### Language

* Metamethods!
  * Records can now declare metamethods as part of their definitions, which
    informs the Teal type checker about supported operations for that record
    type. (#299)
  * Metatables are not automatically attached, you still need to use
    `setmetatable`: check the [documentation](https://github.com/teal-language/tl/blob/master/docs/tutorial.md#metamethods)
    for an example on using records with metamethods and metatables.
  * Operator metamethods for `//` and bitwise ops are supported even when
    running Teal on top of Lua 5.1.
* Userdata records
  * The practical difference, as far as type checking goes, is that
    they no longer count as a "table" type in unions.
* `or` expressions now accept subtypes: for example, an `or` between a union
  and one of its elements is now accepted.
* Some breaking changes for cleaning things up:
  * The language now rejects unknown variable annotations. That includes
    `<close>`, which is not currently supported. Note that Teal does support
    the `<const>` annotation (for all Lua versions) and performs the check
    at compile time.
  * Dropped. support for record and enum definitions inside table literals.
    This was a remnant from when variable and type definitions were mixed. Now
    all record and enum definitions need to happen inside a `local type` or
    `global type` definition (and may be nested).
* Standard library definition improvements:
  * `math.log` accepts a second argument

### Tooling

* Compiler warnings!
  * The Teal compiler now features a warning system, and reports on unused
    variables.
* Teal Playground integration in the Teal repository
  * Now, every PR triggers a Github Action that produces a link to
    a [Teal Playground](https://teal-playground.netlify.app/)
    which allows you to test the compiler changes
    introduced by the PR right from your browser!
* `tl build` now returns a non-zero error code on type errors

### Fixes

* Detects a bad use of `:` without a proper `()` call (#282)
* Fixed type inference for variadic return in `for` loops (#293)
* Always check for union validity after type arguments are resolved
  when declaring a record (#290)
* No longer suggest "consider using an enum" when indexing non-records
* Fixes for control-flow based inference
  * Fix expression inference in `elseif`
  * Propagate facts across parentheses
* Standard library definition fixes:
  * `os.date` second argument was fixed

# 0.9.0

2020-12-16

Three months after 0.8, it's time to release Teal 0.9! It features
language improvements, bugfixes, new contributors.

This release features commits by Domingo Alvarez Duarte, Corey Williamson,
Pierre Chapuis and Hisham Muhammad.

## What's New

### Language

* New tuple type!
  * You can declare a type such as `local t: {string, number} = {"hi", 1}`
    and then `t[1]` gets correctly resolved as `string` and `t[2]` as number.
    `t[x]` with an unknown `x` gets resolved as `string | number`.
  * Inference between arrays and tuples allows for some automatic conversions.
* `record` declarations now accept arbitrary strings as field names, using
  square brackets and string notations, similar to Lua tables:
  `[ "end" ] : string`
* Support for the `//` integer division operator
  * This is also supported for target VMs that do not support it natively!
    For those environments, it outputs `math.floor(x / y)` in the Lua code.
* Additions and tweaks to the standard library definitions:
  * `string.gsub` function argument return values

### Tooling

* Error messages of the type `X is not a X` (when two different nominal types
  happen to have the same name) are now disambiguated by presenting the
  filenames and locations of the two different declarations, as in
  `X (declared in foo.tl:9:2) is not a X (declared in bar.tl:8:2)`
* The `tl` compiler module now exposes some of its external types for use by
  tooling (such as the `tl` CLI script)
* Compiler now generates compatibility code using `bit32` library
  (part of `compat53`) for target VMs that do not support bitwise
  operators natively.
* Performance improvements in the compiler!
  * `./tl check tl.tl` went from avg 612ms in 0.8.2 to 315ms
* CI now tests Teal with Lua 5.4 as well.

### Fixes

* Fixed the support for bitwise xor operator `~`
* Fixed the support for escapes in string literals, including Unicode
  escapes.
* Various fixes to the inference of unions.
  * Fixed invariant type comparisons for union types.
  * It now skips `nil` correctly when expanding union types:
    For example, `{ 5, nil }` is now correctly inferred as `{ number }`
    instead of `{ number | nil }`, because nil is valid for all types.
* Cleaned up shadowed variable declarations in the compiler.
* Cleaned up and added more extensive test cases for subtyping rules
  for `nil`, `any`, union and intersection types, and caught some edge
  cases in the process.

# 0.8.2

2020-11-06

This is another bugfix release.

This release features commits by Hisham Muhammad, Corey Williamson and fang.

## What's New

### Fixes

* `tl` now caches required modules to not load code more than once (#245)
* fixed a compiler crash using `math.atan`
* `tl` now uses `loadstring` instead of `require` to load config,
  to avoid issues with LUA_PATH
* do not shadow argument types with function arguments
* expand tuples but not nominals in return types (#249)
* fix `is` inference on `else` block when using nominal types (#250)
* `for` accepts a function call that returns a nominal
  which resolves to an iterator. (#183)
* fix invariant type checking of records
* various fixes for the lexer pretty-printer

# 0.8.1

2020-10-24

This is a small bugfix release, to get some of the recent fixes out in the
default package.

This release features commits by Hisham Muhammad, Corey Williamson and Casper.

## What's New

### Language

* Standard library definition improvements: `debug.traceback` 3-argument
  form and `__name` metatable field

### Tooling

* Added a simple type checking for config entries in `tlconfig.lua`

### Fixes

* Fixed a crash when detecting wrong use of `self` on a method with no
  arguments. (#228)
* Fixed the declaration of type aliases for nominals, which was causing
  a stack overflow. (#238)
* Only infer an array if we can infer its elements: When resolving the
  type of a table literal, a function with no returns produces an empty
  tuple, and that does not give us enough data to resolve a type. (#234)
* Improved cleanup for the test suite.

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
