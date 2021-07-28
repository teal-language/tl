
Teal
====

[![Build Status](https://travis-ci.org/teal-language/tl.svg?branch=master)](https://travis-ci.org/teal-language/tl)
[![Join the chat at https://gitter.im/dotnet/coreclr](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/teal-language/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

This is the repository of **tl**, the compiler for Teal, a typed dialect of Lua.

The core compiler has no dependencies and is implemented as a single `tl.lua`
file which you can load into your projects. Running `tl.loader()` will add
Teal support to your package loader, meaning that `require()` will be able to
run `.tl` files.

## Introduction

Here are videos of talks given at FOSDEM 2019, 2020 and 2021 which discuss the
history of Lua and types, outline the motivations behind Teal and talk about
the project's progress:

* [Minimalism versus types (2019)](https://www.youtube.com/watch?v=OPyBQRndLUk)
* [Minimalistic typed Lua is here (2020)](https://www.youtube.com/watch?v=HfnjUCRzRKU)
* [What's Next for Teal (2021)](https://www.youtube.com/watch?v=OqXbnaDR8QY)

## Installing

### Via LuaRocks

Install Lua and LuaRocks, then run:

```
luarocks install tl
```

This should put a `tl` command in your `$PATH` (run `eval $(luarocks path)` if
the LuaRocks-installed binaries are not in your `$PATH`).

Teal works with Lua 5.1-5.4, including LuaJIT.

### Binaries

Alternatively, you can find pre-compiled binaries for Linux x86_64 and Windows
x86_64 at the [releases](https://github.com/teal-language/tl/releases) page.
The packages contain a stand-alone executable that can run Teal programs
(without the need of a separate Lua installation) and also compile them to Lua.

### Try it from your browser

You can give Teal a try directly from your browser with the [Teal
Playground](https://teal-playground.netlify.app/)! It compiles Teal into Lua using
[Fengari](https://github.com/fengari-lua/fengari), a Lua VM implemented in
JavaScript, so everything runs on the client.

## Running

Once `tl` is in your path, there are a few subcommands:

* `tl run script.tl` will run a Teal script.
* `tl check module.tl` will type check a Teal module, report any errors and
  quit.
* `tl gen module.tl` will check for syntax errors and
  generate a `module.lua` file in plain Lua with all type annotations
  stripped.
* `tl build` will compile your project via the rules defined in `tlconfig.lua`.
* `tl warnings` will list all warnings the compiler can generate.

`tl` also supports some [compiler options](docs/compiler_options.md).
These can either be specified on the command line or inside a tlconfig.lua file at the root of your project.

## Loading Teal code from Lua

You can either pre-compile your `.tl` files into `.lua`, or you can add
the `tl.lua` module into your project and activate the Teal package loader:

```lua
local tl = require("tl")
tl.loader()
```

Once the package loader is activated, your `require()` calls can load and
compile `.tl` files on-the-fly.

## Documentation

You can learn more about programming with Teal in the [tutorial](docs/tutorial.md).

## Type definitions

`tl` supports [declaration files](docs/declaration_files.md), which can be used to annotate the types
of third-party Lua libraries.

We have a collaborative repository for declaration files at
https://github.com/teal-language/teal-types — check it out and make your contribution!

## Text editor support

Teal language support is currently available for [Vim](https://github.com/teal-language/vim-teal), [Visual Studio Code](https://github.com/teal-language/vscode-teal) and [lite](https://github.com/rxi/lite-plugins/blob/master/plugins/language_teal.lua) with [linter](https://github.com/drmargarido/linters/blob/master/linter_teal.lua) support.

## Community

* Join the chat on [Gitter](https://gitter.im/teal-language/community)!
  * You can also join via Matrix at [#teal-language_community:gitter.im](https://matrix.to/#/#teal-language_community:gitter.im)

Teal is a project started by [Hisham Muhammad](https://hisham.hm),
developed by a [growing number of contributors](https://github.com/teal-language/tl/graphs/contributors)
and is written using Teal itself!

## License

License is MIT, the same as Lua.
