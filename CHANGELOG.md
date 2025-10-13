# 0.24.8

2025-10-13

Another bugfix release, hopefully the last one in the '24 series. This
releases includes a couple of bugfixes, and a bunch of improvements to
the standard library definitions.

This release features commits by Morgan Bartlett, Corey Williamson and
Hisham Muhammad.

### Language

* `__len` metamethod can now override `#` at compile-time with a `macroexp`
* Lots of improved type definitions for the standard library:
  * `io`: better error returns
  * `FILE` type now has a `where` clause so you can do `if x is FILE`
  * `utf8`: return values are integers
  * `debug`: improved definitions for `getupvalue`, `getuservalue`,
    and `getinfo`
  * `loadfile`: use `{any:any}` instead of `table`
  * `pairs`, `ipairs`: improved return types for the returned iterators
  * `xpcall` now can handle `debug.traceback` as an argument

### Fixes

* Fixed array inheritance: an interface that inherits another interface
  that inherits an array type can be used as that array type corectly
  (#1023)
* Fixed inference of tuple table declarations mixing non-aggregate
  and aggregate types. (#1035)

# 0.24.7

2025-07-22

Not a lot of changes in this release, but a few important ones! This release
publishes some useful additions contributed to improve the tooling around
the language. In the meantime, some major changes are being prepared for the
next release series -- namely the implementation is being split from one big
`tl.tl` file into modules, and a new API is in the works. But for now,
the 0.24.7 keeps things progressing in the '24 series.

This release features commits by Morgan Bartlett, @wu4, Miłosz Koczorowski
and Hisham Muhammad.

### API/Tooling

* Collect and preserve comments in the AST for use by third-party tooling
  * Lexer can now preserve comments (#1002)
  * Parser can now attach comments to AST nodes (#1005)
    * Parser can also preserve "unattached" top-level comments (#1007)
* Better type information produced by TypeReporter:
  * Metatable fields are included in TypeInfo
  * Generic type arguments are included (#1020)

### Fixes

* Fix code generation by not propagating "needs compat code" marker across
  module boundaries
* Adjusted flow check behavior on multiple `if` branches: do not widen
  back a type if it remains the same on scope exit (#904).
* Better checks when long strings are used as table indices

# 0.24.6

2025-05-23

Another good bugfix release, with a bunch of fixes reported and fixed by the
community! I'm especially happy to welcome Morgan Bartlett as a committer;
it's really good to be able to discuss the internals of the compiler in
matters that affect both the implementation and the language behavior. The
fixes and improvements for the `or` operator inference were a truly
collaborative piece of work!

This release features commits by @0komo, @wu4, Morgan Bartlett
and Hisham Muhammad.

### Language

* Improved type inference for the `or` operator. Various subtle changes
  to its behavior, but the end result is that the behavior should match
  more closely what is intuitively desired. See the test cases in #983
  for details.

### Tooling

* `-` can be used as an argument for reading from standard input
  or writing into standard output
* `tl completion`: new command for generating shell completions for
  bash, zsh and fish.
* `--wdisable` and `--werror` now reject invalid values

### API

* `tl.symbols_in_scope` now returns the inferred type at the requested
  cursor position.

### Fixes

* API fixes:
  * Type collection report fixes so that `tl.symbols_in_scope`
    behaves correctly, returning types for the correct scope.

* Fix "never read" warnings on specialized variables (#967).
* Avoid accidentally matching interfaces to records structurally.
* Do not crash when traversing an invalid type.
* Fix handling of string escapes for Lua 5.1 targets (#977).
* Fix a type leak in table literals (#965).

# 0.24.5

2025-05-05

This is a big bugfix release! Almost all known bugs since 0.24.0 are now
closed. It feels good to improve on the stability of Teal 0.24 before we start
focusing on language changes for Teal 2025. At the same time, this release
does include some new features, though mainly to make Teal 0.24 closer to what
one would consider an ideal vision for Teal 2024, rather than introducing new
concepts.

This release features commits by Morgan Bartlett, François Perrad
and Hisham Muhammad.

## What's New

### Language

* Special-case type inference for various `string` functions:
  `string.format`, `string.pack`, `string.unpack`, `string.find`,
  `string.match`, `string.gsub`, `string.gmatch` (#946).
* String metatable is resolved using the `string` module, which makes
  it resilient to shadowing via `local string`.
* Improved flow inference
  * Preserve type narrowing/widening on all branches of an `if` statement,
    including with constrained generics.
  * `not` operator propagates a boolean context.
* Disallow mixing `?` and `...` in argument declarations, making error
  checks more consistent.
* Improved standard library definitions
  * `file:close` signature

### API

* if `tl.path` is set, this overrides `package.path` for Teal.

### Tooling

* Avoid confusing error messages like `got Foo, expected Foo` when
  names refer to incompatible types with the same local names.

### Fixes

* Fix regression in support for macro expressions with generics (#941).
* Avoid leakage of constrained type variables, by resolving constraints
  when freshening type variables (#
* Fixed inheritance order for covariant behavior of specialized
  fields (#944).
* Fixed syntax check for empty argument list in nested entries
  such as `Foo<Bar<>>` (#958).
* Generate code correctly when using pragma (#929).
* Correct behavior of `...` in macro expressions (#940).
* Correct behavior of optional arguments in macro expressions (#956).
* Fixed escaping in error messages.
* Let Lua sort the `package.loaded` table on its own (#922).
* Do not try to resolve validity of unions too early (#903).
* Ensure that union specialization with interface subtype produces
  a valid type.
* Do not infer type variables as boolean contexts.

# 0.24.4

2025-01-23

Writing this changelog from the train, as the ICE approaches Berlin
Südkreuz. More fixes to the generics system, tightening the type system
in the presence of interfaces. I'd like to especially thank Steve
Vermeulen, Michael Dowling and Corey Williamson for their bug reports,
test cases and feedback on these issues, helping to get Teal 0.24 to a
more stable shape.

This release features commits by Pierre Chapuis, André L. Alvares and
Hisham Muhammad.

## What's New

### Fixes

* Fixed the resolution of type arguments in generics, especially
  for function calls (#905, #908, #909, #910)
* Fixed the resolution of the `__call` metamethod for generics.
  (#904)
* Fixed the subtype checking of generic records against generic
  interfaces. (#859)
* Fixed an error when matching against an undefined type.
* Bumped the pinned compat53 dependency, which had a build issue
  on Windows. (#916)

# 0.24.3

2025-01-12

A minor bugfix release, thanks to feedback received upon the release
of 0.24.2.

This release features commits by Hisham Muhammad.

## What's New

### Fixes

* Fixes code generation of nested generics that should not be elided (#902).
* Fixes a regression in generic records with a __call metamethod (#901).
* Record fields declared with self type were not being properly type checked
  in table literals (#846).

# 0.24.2

2025-01-10

Another bugfix release for Teal 0.24. We got more feedback, bug report,
test cases.

The good news is that the arity changes went very smoothly: no bug reports or
complaints about that big change, really. The lack of feedback means that
people must have adapted well to the new behavior, and that the pragma support
and documentation on how to migrate was sufficient. A big win!

The bad news is that the added complexity to the type system caused by the
introduction of interfaces and the `self` type, have produced various bugs.
Those came up especially due to the interactions between interfaces, the
`self` type and generics. Most bugs were fixed for this release, but not all.

This release features commits by Pierre Chapuis, JR Mitchell, Corey Williamson,
@FourierTransformer, @FractalU and Hisham Muhammad.

## What's New

### Language

* `record` declarations nested inside `interface` declarations are no
  longer allowed; allowing a concrete object inside an abstract object
  was an oversight.
* Relational operators on aliases to comparable types now correctly return
  boolean
* Nominal function types can now be used as type variable constraints.
* Improved standard library definitions
  * `io.input` and `io.output` types
  * `string.find`

### Tooling

* Compiler now produces warnings for unread variables.

### Fixes

* Record fields inherited from interfaces now resolve `self` on declaration
  (#877).
* Fixes parsing of `.lua` files, respecting Lua heuristics for function calls
  across multiple lines.
* Fixes a syntax error with `return;` is not the last statement of a
  block (#893).
* Eager resolution of unused type arguments (#881).
  * Nested generic type aliases work with eager resolution (#888).
* Fixes support for generics on array types (#880).
* Fixes support for generic unions (#787).
* Check if number of types in declaration exceeds number of variables (#868).
* API fixes:
  * `tl.get_types` reports all inherited interface fields
  * reports `self` symbol in methods
* Internal Compiler Error when declaring an invalid union in a function arg
  in a field (#856)
* Crash on a `for` loop that explicitly uses `next` and an unknown variable.
* Stack overflow when a nested interface extends its parent interface.
* Error messages for `>` no longer have its operands flipped
* Fix: do not get file names and locations out-of-sync when compiling multiple
  files.
* CLI: compatibility fix for Windows.

# 0.24.1

2024-10-25

A bugfix release for Teal 0.24. Several fixes that bring the implementation
closer to the vision of what the 2024 edition is intended to be, thanks to
the invaluable feedback of the user community!

This release features commits by François Perrad, Steve Vermeulen and
Hisham Muhammad.

## What's New

### Language

* Standard library
  * Improved signatures for `math.frexp` and `math.ldexp`

### Fixes

As expected, fixes are mainly related to the new features introduced in Teal
0.24:

* Better handling of abstract vs. concrete types
  * Fixed subtyping and casting checks for records vs. interfaces (#830).
  * Disallow passing non-record types as arguments (#813).
  * Allow interface instances to be required concretely
  * Always elide abstract types from generated code
* Fixes for improved type inference
  * Fixed type inference for `is x == nil or ...` (#823).
  * Resolve type parameter in `setmetatable` using nested records (#772).
  * Ignore non-literal booleans in table key declarations (#816).
  * Type variables from function results also resolve arguments (#838).
  * Do not mistake missing optional argument for a vararg.
* Improved code generation
  * Generate `__is`-aware code for `is` on unions (#742).
  * Handles metamethod for `__eq` (#814).
* Fixes for `self` type
  * Fixed a nil reference exception (#824).
  * Corrected resolution of `self` in methods (#812).

# 0.24.0 - Teal Spring '24

2024-10-07

This a big release! Teal 0.24.0, codenamed "Teal Spring '24" as a nod to
the coolest language release name ever ("Clipper Summer '87"), is a
culmination of work that has spanned multiple years, and it would not be
possible without the amazing feedback given by the community on the `next`
branch, where this was developed. This release does include that "lot of
new code" that I wanted to merge in the "near future", which I referred
to in the changelog entry for the previous release. It is nice to see it
all coming together!

The main feature is the addition of interfaces, which introduces a model for
subtyping table types in the language. That should allow for representing the
various kinds of object models that are used across the Lua ecosystem, without
promoting any particular class/object system over the others. Most of the
other changes, such as macro expressions, came along as related features built
to support this. The support for optional argument markers is a stop towards
stricter type safety, and the addition of pragma markers to control this
feature is a statement of intent for allowing gradual transitions as the
language evolves. All in all, the goal is to make the 2024 edition of Teal
a safer and more pleasant language to use.

And yes, an October release is called Spring because it is now spring in
the southern hemisphere. :)

This release features commits by François Perrad, Victor Ilchev and Hisham
Muhammad.

## What's New

### Language

* **Interfaces**: you can now declare abstract interfaces, and record types
  can implement them. This allows you to declare subtyping relations, and
  better support inheritance models (e.g. `local record Circle is Shape`).
  * Records and interfaces may declare a `where` clause with an expression
    over `self`, which allows the `is` operator to discriminate the type.
  * With discriminated record types, it is now possible to declare unions
    over multiple record types.
  * "Arrayrecords" are no longer a distinct type: they are just records
    that implement an array interface (e.g. `local record R is {T}`)
  * Type variables in functions can now have constraints on interfaces
    (e.g. `function my_func<F is MyInterface>(...)`)
  * `self` is now a valid type that can be used when declaring arguments
    in functions declared in interfaces and records
    * When a record is declared to be a subtype of an interface using `is`,
      any function arguments using `self` in the parent interface type will
      then resolve to the child record's type.
* **Optional/required arguments in function calls** - functions may declare
  arguments as optional, affecting the required arity of function calls.
  The rightmost arguments of a function can have their variable names
  annotated with a `?` sign, indicating that the argument does not need
  to be passed in a function call. This refers only to the presence of the
  argument in a call, and not to its type or nullability: a required
  argument may still be called with an explicit `null`, but an optional
  argument may be elided.
  * In previous versions of Teal, all function arguments were effectively
    optional. This means that Teal is now stricter which checking for
    function calls. You can use `--feat-arity=off` in the command line
    or `feat_arity = "off"` in `tlconfig.lua` to obtain the previous
    behavior.
  * To convert code that uses the old arity checking rules to the new
    behavior, you can also use compiler pragmas in the code,
    `--#pragma arity off` and `--#pragma arity off` to disable or enable
    stricter arity checks.
* **Macro expressions**: you can declare a restricted form of function called
  a `macroexp`, which is always expanded inline. These can also be used
  to declare compile-time metamethods, which expand without requiring
  a metatable at runtime. The `where` clauses used in interfaces and
  records are syntax sugar for macro expressions that implement a
  pseudo-metamethod `__is`.
* Dynamic `require` calls that do not take a module name as a literal
  string are now allowed, and return `any`; you can load a static type
  definition using `local type MyType = require("...")` and then cast
  your dynamic require like so: `local my_mod = require(var) as MyType`
* The type system is more nominal: all named types are now treated nominally,
  except for unions, which are always type aliases. Previously record types
  were nominal, but a named typed that resolved to a primitive such as
  `integer` was structural. There are still subleties on the rules for when
  a `local type` produces a new distinct type or an alias; they are
  [explained in the docs](docs/aliasing.md).
* The `<total>` attribute for variables can now only be applied when
  initializing variables with literal tables. This is a minor breaking change,
  but the usefulness of this attribute in other cases was very limited,
  and it also produced misleading results.
* Improved type signatures in the standard library
  * `select` produces variadic returns

### API

* Simplified API in the `tl` module.
  * The 0.15 API is still supported for backwards compatibility.

### Tooling

* `tl build` was removed. [Cyan](https://github.com/teal-language/cyan)
  should be used instead as the build tool for Teal projects.

### Fixes

* Fix commits included in this release refer both to bugs present
  in the `master` branch as well as fixes specific to the 0.24 series,
  reported by the community during the beta testing of this release.
  The Git history and the GitHub issues list contain a more detailed
  accounting of the bugfixes that went into this release.
  Some of the fixes include:
  * `tl check` now reports if the input file does not exist.
  * Reporting location of the end of an `if` block correctly.
  * No longer crash if a `require()` epression fails to resolve (#778).
  * `tl types` now reports the types of variables in `for` loops.
  * Improved error message when calling functions with insufficient
    arguments.
  * Disallowing using a base type as a type variable name.
  * Type arguments resolving correctly in recursive functions.
  * Type arguments resolving correctly in nested records (#754).
  * `or` type inference between types with a subtyping relation
    resolves to whichever is the larger type.
  * Reporting an error if an iterator used in a generic `for` does not
    declare a return value type (#736).
  * When checking `<total>` values, no longer reporting record
    function and metamethods as missing fields (#749).
  * Localizing a record no longer makes the local a type (#759).
  * Bad assignments of record tables are reported (#752).
  * Nominal type alias declarations work as expected (#238).
  * Nominals with generics can be resolved correcty (#777).
  * Nested types are not closed too early (#775).
  * Not failing when resolving nested empty tables.
  * Exporting generics and type aliases from modules correctly
    using `return` at the toplevel (#804).

# 0.15.3

2023-11-05

It's been a long time since the last release! Lots of fixes got merged in, and
there's a lot of new code that I want to merge in the near future. So, let's
get a more fix-oriented release out before more significant changes.

This release features commits by @JLPLabs, François Perrad, JR Mitchell and
Hisham Muhammad.

## What's New

### Language

* Accept return-like syntax for vararg inputs in function type signatures
  (e.g. `function(string...): string...`)
* Parser no longer accepts annotations (e.g. `<const>`) in `for-in` variables.
  It used to accept but ignore them before.
* New warning for `or` between incompatible types in a context where no
  union is expected.
* Record functions now implicitly inherit type variables from its parent
  record's definition. (#669)
* Standard library improvements:
  * improved return values for `debug.getlocal`
  * improvements to `utf8.codes` signature
  * `io.write` and `file:write` signatures also accept numbers
  * `file:close` signature now produces Lua 5.2+ returns (and matches Lua 5.2+
    behavior thanks to update in Compat-5.3 library)
  * file reader functions (`io.read`, `io.lines`, `FILE:read`, `FILE:lines`)
    now support the `"n"`/`"*n"` pattern

### Fixes

* No longer produces spurious warnings when using methods with `pcall`. (#668)
* Better acceptance of `record` and `enum` as soft keywords.
* `is` inference now takes into account that unions also imply nil,
  therefore accepting an `else` case even if all cases of an union are
  tested in `if`/`else if` branches. (#699)
* `:`-style function calls also check for the `__index` metamethod.
  Also avoids mistaking `__index` for an incorrect method use.
* Resolves type arguments when both types in an `or` expression match the
  expected type. (#709)
* Checks records nominally when resolving metamethods for operators. (#710)
* Avoids confusing a localized global for an automatic type narrowing
  when reporting unused variables.
* When generating compatibility bit32 code, always do it, even for invalid
  variables, instead of emitting incompatible operators.
* Compiler no longer crashes if type variable resolution fails when setting an
  inference location.
* Compiler no longer crashes when checking for a reassigned const global.

### Code generation

* Unused local types no longer emit dummy variables.

### Tooling

* `tl` for many files is much faster as it avoids running the GC on every file.
* Package loader now populates the `...` tuple

# 0.15.2

2023-04-27

This is primarily a bugfix release, but it does include
some significant quality-of-life improvements when using
record methods.

This release features commits by JR Mitchell, @IcyLava
and Hisham Muhammad.

## What's New

### Language

* Improved checks over uses of `self` in forward-declared
  methods:
  * In a `record` declaration, when fields of type `function`
    are declared within a and they have a matching `self`
    first argument, those are now treated as methods
    (similar to explicit `function R:method` declarations
    using colon-notation), so misuses of `:` versus `.`
    can be detected in those as well.
* Warn when invoking a method as a function, even if the type
  of the first non-self argument matches.
* Standard library improvements:
  * Add optional third argument for `string.rep`

### API

* Public signature of `tl.gen` features second return value of
  type `Result`

### Fixes

* Acept record method declaration for nested records. (#648)
* Do not consider an inner type to be a missing key when declaring
  a total table. (#647)
* Change inference order in function calls to better match programmer
  intent: infer `self` (which is usually explicitly given)
  before return values (which are implied by context).
* Preserve narrowed union in a loop if the variable is not assigned. (#617)
* Don't miss a "unused variable" warning when it is a narrowed union.
* Fixes the detection of record method redeclaration. (#620)
* Fixes the error message when number of return arguments is
  mismatched. (#618)

# 0.15.1

2023-01-23

A minor bugfix release, thanks to feedback received upon the release
of 0.15.0.

This release features commits by Hisham Muhammad.

## What's New

### Fixes

* Fixes resolution of nominals across scope levels.
* Fixes a crash when resolving nested records in a record function. (#615)
* Avoid spurious inference warnings in local declarations.

# 0.15.0

2023-01-20

Two new language features, a bunch of inference improvements, some more
stricter checks for correctness, and a bunch of fixes! There's a lot to unpack
in this release, but all changes should be backwards-compatible for correct
code, so migration should be smooth for end-users of the compiler.

However, if you're using `tl` module API directly, please note that there are
some API changes, listed below.

This release features commits by Li Jin, Carl Lei, Yang Li,
Pierre Chapuis, @lenscas, Stéphane Veyret, and Hisham Muhammad.

## What's New

### Language

* Type-only `require`:
  * Adds new syntax for requiring a module's exported type
    without generating a `require()` call in the output Lua:
    `local type MyType = require("mytype")` -- circular
    definitions of `local type`-required types are allowed,
    as long as the type is only referenced but its contents
    are not dereferenced.
* New variable attribute `<total>`:
  * It declares a const variable with a table where the
    domain of its keys are totally declared.
  * This check can only be applied when a literal table is given
    at the time of variable initialization, and only for table types
    with well-known finite domains: maps with enum keys, maps with
    boolean keys, records.
  * Note that the requirement is that keys are declared: they may
    still be explicitly declared to be nil.
* Type inference improvements:
  * Improved flow-typing in `if` blocks - if a block ends
    with `return`, then the remainder of the function can
    infer the negation of its condition.
  * In contexts where the expected type of an expression
    is known (e.g. assignments, declarations with explicit
    type signatures), the return type a function call can
    now determine the type argument of a function.
    * In particular, `local x: T = setmetatable({}, mt)`
      can now infer that `{}` is `T` without a cast.
  * When initializing a union with a value, that value
    is now used by the flow-typing engine to narrow the
    variable's concrete known type.
* Local functions can be forward-declared with a `local`
  variable declaration and then implemented with bare
  `function` notation, more similarly to how record functions
  (and Lua functions) work.
* Handling of `.` and index notations is now more consistent
  for both maps and records:
  * Map keys can now use `.`-notation like records, and
    get the same checks (e.g. if a key type is a valid enum)
  * `__index` metamethod works for `.`-notation as well.
* Some stricter checks:
  * Unused type arguments in function signatures are now
    flagged as an error.
  * Using the `#` operator on a numeric-keyed map now produces a
    warning, and on a non-numeric-keyed map it produces an error.
  * Redeclaration of boolean keys in a map literal are
    now an error.
  * Cannot declare a union between multiple tuple types
    as these can't be discriminated.
  * Cannot redeclare a record method with different type
    signatures; produces a warning when redeclaring with
    the same type signature.
* Standard library improvements:
  * `pcall` and `xpcall` have vararg return types

### Fixes

* Fixed check between `or` expression and nominal unions.
* Fixed function call return values when returning
  unions with type arguments. (#604)
* Fixed an error when exporting type aliases. (#586)
* `__call` metamethods that are declared using a type alias
  now resolve correctly. (#605)
* Generic return types are more consistenly checked,
  potentially reporting errors that went undetected before.
* Fixed type variable name conflicts in record functions,
  ensuring nested uses of generic record functions using
  type variables don't cause conflicts. (#560)
* Fixed the inference of type arguments in return values. (#512)
* Fixed the error message for redefined functions. (#566)
* Fixed a case where a userdata record type is not
  resolved properly. (#585)
* Fixed some issues with the `<close>` attribute.
* `tl warnings` no longer misses some warning types.

### Code generation

* Report error on unterminated long comments instead of
  generating invalid code.
* Cleaner code is produced for `is nil` checks.

### API

API changes for more consistent processing of syntax errors:

* `tl.lex` changed: it now returns an `{Error}` array instead
  of a list of error Tokens.
  * from `function tl.lex(input: string): {Token}, {Token}`
  * to `function tl.lex(input: string, filename: string): {Token}, {Error}`
* `tl.parse_program` changed: it no longer returns the first
  integer argument, which as always ignored by every caller.
  * from `function tl.parse_program(tokens: {Token}, errs: {Error}, filename: string): integer, Node, {string}`
  * to `function tl.parse_program(tokens: {Token}, errs: {Error}, filename: string): Node, {string}`
* `tl.parse` is a new function that combines
  `tl.lex` and `tl.parse_program` the right way, avoiding previous
  mistakes; this is the preferred function to use moving forward.
  * signature: `function tl.parse(input: string, filename: string): Node, {Error}, {string}`

### Tooling

* Better handling of newlines on Windows.
* `tl types`: in function calls of polymorphic functions, now
  the return type of the resolved function is reported.
* More informative pretty-print of polymorphic function signatures
  in error messages.
* More informative error message for field assignment failures.
* Improved error message for inconsistent fields (#576)
* The parser now does some lookahead heuristics to provide nicer
  error messages.
* The compiler now detects mis-aligned `end` keywords when reporting
  about unmatched blocks, which helps pointing to the place where a
  mistake actually occurred, instead of the end of the file.
* For debugging the compiler itself:
  * new environment variable mode `TL_DEBUG=1` inspects AST nodes
    and types as program is compiled.
  * `TL_DEBUG` with a negative value `-x` will run like `TL_DEBUG=1`
    but halt the compiler after processing input line `x`.

# 0.14.1

2022-08-23

And a week after 0.14.0, here's 0.14.1, with bugfixes to a few regressions
identified by users. This is essentially a bugfix release, with a few
improvements triggered via regressions or confusing error messages.

This release features commits by Hisham Muhammad.

## What's New

### Fixes

* Improved error reporting on declarations with missing `local`/`global`
* Ensured `exp or {}` with empty tables continues to work as it used to
  in 0.13.x, skipped more advanced flow-typing as simply returning the
  type of the left-hand side `exp`.
* Improved propagation of invalid types in unions
  * Avoids weird messages such as `got X | Y, expected X | Y`
    when "Y" is invalid in the scope, but was valid on declaration
    of a function argument, for example.
* Fix missing bidirectional flow of expected types in `return` expressions
  and expand it on string constants. (#553)
  * This is almost a feature as flow-checking was made smarter for
    string constants, but it takes the shape of a regression test because
    `return` expression checks were incomplete and caused some correct
    code to pass type checking before which stopped passing on 0.14.0
    when some checks were extended. We further extend them here to make
    more valid code pass.
* Fixes a crash when resolving a "flattened" union. (#551)

# 0.14.0

2022-08-16

It's been a year! It was good to let the language sit for a while and
see what kind of feedback we get from real world usage. This has also been
an opportunity to get bug reports and fixes in, to help further stabilize
the compiler.

This release features commits by Li Jin, Enrique García Cota, Patrick
Desaulniers, Mark Tulley, Corey Williamson, @Koeng101 and Hisham Muhammad.

## What's New

### Language

* Global functions now require `global function`, you can no longer
  declare them with a bare `function`; this makes it more consistent
  with other global variables. (#500)
* Forward references for global types:
  * `global type Name` can be used to forward-declare a type and
    use it, for example, in record fields, even if it is declared
    in another file. (#534)
* Polymorphic functions (as declared in record methods) can be used
  as iterators for a generic `for`. (#525)
* You can no longer define a global with the same name as a local which
  is already in scope. (#545)
* Initial support for the `__index` metamethod: you can declare it
  as a function. (#541)
* Dropped support for the old backtick syntax for type variables.
* Type checker checks validity of Lua 5.4 `<close>` annotations:
  * the output target must be set to "5.4"
  * there can be only one `<close>` variable per declaration (to ensure
    correct order of `__close` metamethods being called)
  * the type of the variable is closable
  * globals can't be `<close>`
  * `<close>` variables can't be assigned to
* Nested type arguments are now valid syntax without requiring a
  disambiguating space. The parser used to reject constructs of the
  type `X<Y<T>>` due to ambiguity with `>>`; it is now accepted
  (old time C++ coders will recall this same issue with C++98!)
* Standard library improvements:
  * `math.maxinteger` and `max.mininteger` are always available
    (in any Lua version, with or without lua-compat-5.3 installed)

### Code generation

* Local types are now elided from generated code if they are never
  used in a concrete value context: if you declare a `local type T`
  such as a function alias, it no longer produces a `local T = {}`
  in the Lua output.

### API

* `tl.pretty_print_ast` now takes a `TargetMode` argument to specify
  flavor of Lua to produce in output:
  * new `TargetMode` for outputting Lua 5.4-specific code including
    `<const>` and `<close>` annotations.
* `tl.load` now always runs the type checker, which is needed to produce
  type information required to output correct code in some cases.
  The default behavior, however, remains backwards compatible and
  allows code to run in the presence of type checking errors.
  You can override this behavior and make `tl.load` return `nil, err`
  in case of type checking errors by using a "c" prefix in the mode flag
  (e.g. "ct", "cb", "cbt").
* `tl.type_check` returns two values.

### Tooling

* Project CI now runs on GitHub Actions
* Windows portability improvements
  * Windows and Mac now get tested regularly in the GitHub Actions CI!
* New hint warning when the value of a function with multiple return values
  is being returned as part of an expression, causing the additional returns
  to be lost.
* Improved error messages for map errors.
* `tl check` avoids re-checking files already loaded in the environment:
  this allows you to check your `global_env_def` module without getting
  redeclaration errors.
* Build script for stand-alone binary is now included in the repository.

### Fixes

* Fixed resolution of type variables to avoid clashes when nested uses
  of generic functions used the same type variable name. (#442)
* Map index keys are checked nominally, not structurally. (#533)
* Fixed flow checking of enums in `or`. (#487)
* Properly return type errors for fields when comparing records. (#456)
* Fixed a stack overflow when comparing unions with type variables. (#507)
* Fixed a stack overflow in record comparisons. (#501)
* It now reports the location of a redeclared record correctly. (#542)
* Fixed resolution of nested type aliases (#527) and nested nominals (#499).
* Fixed check of inconsistent record function declarations. (#517)
* `tl.loader` reports correct filename in debug information. (#508)
* Fixed error message when `tlconfig.lua` contains errors.
* Tables can't be assigned to record types declared to be `userdata`. (#460)
* Fix check of arrays of enums in overloaded record functions.
* Fixed crash when attempting to declare a record method on an
  unknown variable. (#470)

# 0.13.2

2021-07-30

A long while since the last release! This one contains a bunch of fixes,
but no significant language changes. Trying to keep the language stable for
a while so that we better understand what's needed and what the priorities
should be, as more people use it.

This release features commits by Corey Williamson, Patrick Desaulniers,
Enrique García Cota, Francisco Castro, Jason Dogariu, @factubsio
@JLPLabs, @sovietKitsune, @DragonDePlatino and Hisham Muhammad.

## What's New

### Language

* Generic `for` now accepts records that implement a `__call` metamethod
* Allows `#` to be used on tuple tables
* Metamethods for `__tostring`, `__pairs`, `__gc` can be declared
* Standard library definition improvements:
  * `collectgarbage` has smarter arguments
  * `error`: first argument can be anything
  * `os.time`: accepts a table as input
  * `table.concat` accepts numbers in the array argument

### API

* `tl.load` now behaves more like Lua's `load`, using the default
  environment if the fourth argument is not given.

### Tooling

* Report warning for excess lvalues correctly
* `tl` finds `?/init.lua` in its `include_dir` entries as well
* Updates to make test suite run on Windows
* `tl --quiet` silences configuration warnings
* Documentation: various fixes and improvements
  * New guide on `.d.tl` declaration files

### Fixes

* Fixes for compat code when using `--gen-target=5.1`
* Various crash fixes for record method declarations:
  * Fixed crash when inferring type for self
  * Fixed crash when declaring methods on an untyped self
  * Fixed crash when redeclaring a method already declared
    in the record definition
* Fixed a crash when traversing a `.` on something that's not a record
* Error messages now report `...` in variadic function types

# 0.13.1

2021-03-19

A quick bugfix release, to correct the behavior of `global_env_def`, which
wasn't being properly loaded from tlconfig.lua. Getting a quick release out
of the door so that people who were using `preload_modules` don't stay on
an old version just because of that!

This release features commits by Kim Alvefur.

## What's New

### Tooling

* Fixed loading `global_env_def` from tlconfig.lua.

# 0.13.0

2021-03-18

A long awaited feature arrives: integers!

Teal now has a separate type `integer` for integers, and `number` continues to
be the general floating-point value.

The integer type works for any Lua version, but from Teal's point of view it
has unknown precision. The actual precision depends on your Lua VM: if
you're running on Lua 5.3 or above, you get 64-bit integers; if you're running
Lua 5.2 or below or LuaJIT, the implementation still generates regular
numbers, but it checks that operations declared to work on integers will only use
values declared as integers, which is useful even if the VM does not have a native
integer value type.

See more details about the behavior below, as well as a quick guide to help you
in the conversion process!

Apart from integers, this release features your usual assortment of tooling tweaks
and bugfixes!

This release features commits by Kim Alvefur and Hisham Muhammad.

## What's New

### Language

* Integer type!
  * `integer` is a new type of undefined precision, deferring to the Lua VM
    * integer constants without a dot (e.g. 123) are of type integer
    * operations preserve the integer type according to Lua 5.4 semantics
      (e.g. `integer + integer = integer`, `integer + number = number`, etc.)
    * `integer` is a subtype of `number`
      * this generally means that an `integer` is accepted everywhere a `number` is expected
      * note that this does not extend to type variables in generics,
        which are invariant: `Foo<integer>` is not the same as `Foo<number>`
      * if a variable is of type `integer`, then an arbitrary `number` is not accepted
        * `local x: integer = 1.0` doesn't work, even though the floating-point number
          has a valid integer representation
    * variables (and type variables) are inferred as integer when initialized with integers
      * this can happen directly (`local x = 1`) or indirectly (`local x = math.min(i, j)`)
      * to infer an integral value as a `number`, use .0: `local x = 1.0` infers a `number`
  * the standard library was annotated for integers
    * it only returns integers, but it always accepts floats in arguments that
      must be integral — this matches the behavior of the Lua standard library
      implementation: wherever you need to pass an integral value, you can pass
      an equivalent float with an integer representation, e.g.
      `table.insert(t, 1.0, "hello")` — therefore, this is also valid in Teal,
      but note that the validity of the float is not checked at compile time,
      this is a Lua standard library API check.
* Redeclared keys in table literals are now an error.
* More improvements thanks to bidirectional inference:
  * You can now make an `or` between values of two different types
    if the context expects a union.

**Quick guide for existing converting code to use integers** - I tried to be as careful
as possible in making the transition easier, but this will undoubtedly break
some of your code — don't worry, fixing it is easy. Any new error may fall
into one of two categories:

1. Your value is meant to be an integer, but it is being detected as a `number`
  * if your variables are meant to be integers (indices in an array, counters,
    line-column coordinates, etc.), most likely your code will already be using
    them as `integer` because `local x = 0` now infers to `integer`.
  * If you explictly declared it as `local x: number`,
    just change it to `local x: integer`.
  * Your functions will often feature arguments and return types declared
    as `number` where they should now be `integer`,
    if they take or produce integer values.
    * This will cause, especially for return types, a line like
      `my_integer = func()` to produce an error `got number, expected integer`;
      `func` needs to be changed from `function func(): number`
      to `function func(): integer`.
  * To convert floating-point numbers to integers you can use `math` library
    functions such as `math.floor()`.
2. Your value is meant to be a floating-point number, but it is being detected as an `integer`
  * if your variables are meant to be floating-point and Teal is inferring them
    as integer because of their initialization value, the easiest thing is to
    change them to floating-point constants, changing from `local dx = 0` to
    `local dx = 0.0`
  * Due to subtyping, integers generally work wherever numbers are required,
    but if you need to convert an integer to a number in an invariant context such
    as a type variable in a generic, you can force it with a cast (`i as number`).

### API

* new API function `tl.version()`, which returns the version of the compiler.
* make unknowns a kind of warning, not a separate array
* only ever return Result values, do not take them as inputs
* each Result only contains errors for the given file
  * use `env.loaded` (and `env.loaded_order`) to traverse all results
    and get all errors

### Tooling

* renamed `preload_modules` (an array) to `global_env_def` (a single entry).
  This option caused some confusion before, so we reworked the documentation
  to better [explain its intent](https://github.com/teal-language/tl/blob/v0.13.0/docs/compiler_options.md#global-environment-definition).
  * For example, to load global definitions for Love2D from a file `love.d.tl`,
    use `global_env_def = "love"` in your tlconfig.lua file.
* `tl run -l <module> <script>` (long form `--require <module>`)
  * works like `lua -l`; type checks the module and requires it
    prior to running the script.
* `tl gen --check` now reports warnings
* When processing `.lua` files, unknown variables are now a type of
  warning, so you can enable and disable them using the usual warning
  features from the CLI and tlconfig.lua
* Some performance improvements in the compiler itself, thanks to some
  profile-directed optimization (in other words, putting the most-used
  branches first in long `if`/`elseif` chains).
* `tl types` now produces its JSON output in a stable order
* `tl types` now returns more information
  * types in function names, `for` variables

### Fixes

* Nested type alias now work as expected
* Fix a crash when doing flow inference on inexistant variables (#409)
* Fix partial resolution of type arguments
* Some fixes related to arrayrecords
  * Nested types now work correctly with arrayrecords
  * Fixed use of self in functions declared in arrayrecords

# 0.12.0

2021-02-27

Time for a new release, with some significant updates to make the behavior
of the language more smooth.

Language-wise, the big change is bidirectional inference for table literals,
meaning that the types of literal tables (that is, the ones you write with `{
... }` in your code) now get more precise types when they are defined in
contexts that have type declarations, such as variables with explicit types,
or function arguments where the types are known.

There have been also various improvements in the API and tooling departments,
all aiming to produce better development experience -- do keep an eye for
exciting things thet are in the works in this area!

This release features commits by Patrick Desaulniers, Corey Williamson, and
Hisham Muhammad.

## What's New

### Language

* Bidirectional inference for table literals
  * Type information propagates outside-in when a table literal is declared
    as the rhs value of a variable declaration, assignment
    or as a function argument.
  * This fixed various outstanding bugs where unintuitive behavior was
    observed.
* `local type T1 = T2` now makes nominal `T1` an alias for nominal type `T2`,
  and not a separate type (same applies to `global type`).

### API

* `preload_modules` functionality was moved from `tl.process` into `tl.init_env`,
  so that API clients that use the lower-level operations can preload modules.
* `tl.get_token_at` can return the token given a token list and a position.

### Tooling

* `tl gen` now has a `--check` flag, which makes it reject code that does not
  typecheck and not generate the output.
* Warnings output is now presented in a stable order.
* `tl types` has had various improvements generating better data for editor
  integration:
  * The symbols list is much shorter as empty or redundant scopes are eliminated.
  * Incomplete expressions now output type information for the fragment
    that could be parsed.
  * Function types look nicer in error messages and tooling.

### Fixes

* Unions of nominal types now reduce considering aliasing.
* Various fixes for the behavior of `tl types`.
  * The top level scope is now correctly closed at the end of file.
  * Symbols list is now properly sorted.
  * Function types point to the correct filenames.

# 0.11.2

2021-02-14

More bugfixes! This includes some behavior fixes in the flow inference, so
some code that wasn't accepted before may be accepted now and vice-versa, but
the overall behavior is more correct now. Apart from this, no language changes
other than fixes.

This release features commits by Corey Williamson, @JLPLabs and Hisham Muhammad.

## What's New

### Language

* Some more propagation of "truthiness" when flow-typing expressions:
  * `assert` is now known by the compiler to be truthy when performing flow
    propagation of type information. This means that, for example,
    given `x` of type `A | B`, in an expression of the form
    `x is A and assert(exp1(x)) or exp2(x)`, `x` will be known to be of
    type `B` in `exp2(x)`.
* `t or {}` is now only valid for table types
* Standard library improvements
  * `math.randomseed` accepts Lua 5.4 second argument

### API

* `get_types` now returns numeric type codes, and more complete type data
  for IDE integration consumption
* The parser collects the list of required modules, for use by later use
  by build tooling
* The type checker now collects the list of filenames resolved by `require`,
  for use by build tooling

### Tooling

* Performance improvements for the lexer
* Performance improvements for the JSON encoder used by `tl types`

### Fixes

* `tl types`: proper escaping of JSON strings
* some parser fixes to avoid crashes on incorrect input

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

This release features commits by Corey Williamson, @lenscas, Patrick
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
