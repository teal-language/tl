# 0.7.0

2020-06-03

This release had a bunch of community contributions!

## What's New

### Language changes

* Disallow unions of multiple function types, applying a similar
  restriction that was already in place for table types.
  These can't be efficiently destructured at runtime with `is`.
* Lots of additions to the standard library:
  * more overloads for the `load` function
  * `loadfile` and `dofile` functions
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
