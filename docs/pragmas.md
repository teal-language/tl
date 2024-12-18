# Pragmas

Teal is evolving as a language. Sometimes we need to add incompatible changes
to the language, but we don't want to break everybody's code at once. The way
to deal with this is by adding _pragmatic annotations_ (typically known in
compiler lingo as "pragmas") that tell the compiler about how to interpret
various minutiae of the language, in practice picking which "dialect" of the
language to use. This lets the programmer pedal back on certain language
changes and adopt them gradually as the existing codebase is converted to the
new version.

Let's look at a concrete example where pragmas can help us: function arity
checks.

## Function arity checks

If you're coming from an older version of Teal, it is possible that you will
start getting lots of errors related to numbers of arguments, such as:

```
wrong number of arguments (given 2, expects 4)
```

This is because, up to Teal 0.15.x, the language was lenient on the _arity_ of
function calls (the number of expressions passed as arguments in the call). It
would just assume that any missing arguments were intended to be `nil` on
purpose. More often than not, this is not the case, and a missing argument
does not mean that the argument was optional, but rather that the programmer
forgot about it (this is common when adding new arguments during a code
refactor).

Teal now features _optional function arguments_. if an argument can be
optionally elided, you now can, or rather, have to, annotate it explicitly
adding a `?` to its name:

```lua
local function greet(greeting: string, name?: string)
   if name then
      print(string.format("%s, %s!", greeting, name))
   else
      print(greeting .. "!")
   end
end

greet("Hello", "Teal") --> Hello, Teal!
greet("Hello")         --> Hello!
greet() --> compile error: wrong number of arguments (given 0, expects at least 1 and at most 2)
```

However, there are many Teal libraries out there (and Lua libraries for which
[.d.tl type declaration files](declaration_files.md) were written), which were
prepared for earlier versions of Teal.

The good news is that you don't have to convert all of them at once, neither
you have to make an all-or-nothing choice whether to have or not those
function arity checks.

You can enable or disable arity checks using the `arity` pragma. Let's first
assume we have an old library written for older versions of Teal:

```lua
-- old_library.tl
local record old_library
end

-- no `?` annotations here, but `name` is an optional argument
function old_library.greet(greeting: string, name: string)
   if name then
      print(string.format("%s, %s!", greeting, name))
   else
      print(greeting .. "!")
   end
end

return old_library
```

Now we want to use this library with the current version of Teal, but we don't
want to lose arity checks in our own code. We can temporarily disable arity
checks, require the library, then re-enable them:

```lua
--#pragma arity off
local old_library = require("old_library")
--#pragma arity on

local function add(a: number, b: number): number
   return a + b
end

print(add(1)) -- compile error: wrong number of arguments (given 1, expects 2)

old_library.greet("Hello", "Teal") --> Hello, Teal!

-- no compile error here, because in code loaded with `arity off`,
-- every argument is optional:
old_library.greet("Hello")         --> Hello!

-- no compile error here as well,
-- even though this call will crash at runtime:
old_library.greet() --> runtime error: attempt to concatenate a nil value (local 'greeting')
```

The `arity` pragma was introduced as a way to gradually convert codebases, as
opposed to the wholesale approach of passing `--feat-arity=off` to the
compiler command-line or setting `feat_arity = "off"` in `tlconfig.lua`, the
[compiler options](compiler_options.md) file.

### Optional arities versus optional values

Note that arity checks are about the number of _expressions_ used as arguments
in function calls: it does not check whether the _values_ are `nil` or not.
In the above example, even with arity check enabled, you could still write
`greet(nil, nil)` and that would be accepted by the compiler as valid,
even though it would crash at runtime.

Explicit checking for `nil` is a separate feature, which may be added in a
future version of Teal. When that happens, we will definitely need a `pragma`
to allow for gradual adoption of it!

## What pragmas are not

One final word about pragmas: there is no well-established definition for a
"compiler pragma" in the literature, even though this is a common term.

It's important to clarify here that Teal pragmas are not intended as
general-purpose annotations (the kind of things you usually see with `@-`
syntax in various other languages such as C#, Java or `#[]` in Rust). Pragmas
here are intended as compiler directives, more akin to compiler flags (e.g.
the `#pragma` use in C compilers).

In short, our practical goal for pragmas is to allow for handling
compatibility issues when dealing with the language evolution. That is, in a
Teal codebase with no legacy concerns, there should be no pragmas.
