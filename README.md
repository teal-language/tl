
tl
==

[![Build Status](https://travis-ci.org/hishamhm/tl.svg?branch=master)](https://travis-ci.org/hishamhm/tl)

This is the repository of **tl**, an ongoing project to develop a minimalistic typed dialect of Lua.

## Introduction

Here's a video of a talk given at FOSDEM 2019 which discusses the history of Lua and types,
and outlines the motivations behind tl:

* [Minimalism versus types](https://www.youtube.com/watch?v=OPyBQRndLUk)

## Installing

Since there is no published release yet, you need to install it straight
from this repository. Install Lua and LuaRocks, then run:

```
git clone https://github.com/hishamhm/tl
cd tl
luarocks make
```

This should put a `tl` command in your `$PATH` (run `eval $(luarocks path)` if
the LuaRocks-installed binaries are not in your `$PATH`)

## Running

Once `tl` is in your path, there are a few subcommands:

* `tl run script.tl` will run a tl script.
* `tl check module.tl` will type check a tl module, report any errors and
  quit.
* `tl gen module.tl` will type check a tl module, and if there's no errors,
  generate a `module.lua` file in plain Lua with all type annotations
  stripped.

## Credits and license

`tl` is a project started by [Hisham Muhammad](https://hisham.hm)
and is written using `tl` itself!

License is MIT, the same as Lua.
