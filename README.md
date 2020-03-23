
Teal
====

[![Build Status](https://travis-ci.org/hishamhm/tl.svg?branch=master)](https://travis-ci.org/hishamhm/tl)

This is the repository of **tl**, the compiler for Teal, a typed dialect of Lua.

## Introduction

Here are videos of talks given at FOSDEM 2019 and 2020 which discuss the
history of Lua and types, outline the motivations behind Teal and talk about
the project's progress:

* [Minimalism versus types (2019)](https://www.youtube.com/watch?v=OPyBQRndLUk)
* [Minimalistic typed Lua is here (2020)](https://www.youtube.com/watch?v=HfnjUCRzRKU)

## Installing

Install Lua and LuaRocks, then run:

```
luarocks install tl
```

This should put a `tl` command in your `$PATH` (run `eval $(luarocks path)` if
the LuaRocks-installed binaries are not in your `$PATH`)

## Running

Once `tl` is in your path, there are a few subcommands:

* `tl run script.tl` will run a Teal script.
* `tl check module.tl` will type check a Teal module, report any errors and
  quit.
* `tl gen module.tl` will type check a Teal module, and if there's no errors,
  generate a `module.lua` file in plain Lua with all type annotations
  stripped.

## Documentation

You can learn more about programming with Teal in the [tutorial](docs/tutorial.md).

## Credits and license

Teal is a project started by [Hisham Muhammad](https://hisham.hm)
and is written using Teal itself!

License is MIT, the same as Lua.
