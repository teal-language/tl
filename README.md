
Teal
====
[![Build Status](https://github.com/teal-language/tl/actions/workflows/ci.yml/badge.svg)](https://github.com/teal-language/tl/actions/workflows/ci.yml)
[![Join the chat at https://gitter.im/teal-language/community](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/teal-language/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

This is the repository of **tl**, the compiler for Teal, a typed dialect of Lua.

The core compiler has no dependencies and is implemented as a single `tl.lua`
file which you can load into your projects. Running `tl.loader()` will add
Teal support to your package loader, meaning that `require()` will be able to
run `.tl` files.

## Introduction

You can read the [tutorial chapter](https://teal-language.org/book/tutorial.html)
of the Teal documentation to get started with an overview of the language.

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

### Using the compiler directly

Once `tl` is in your path, there are a few subcommands:

* `tl run script.tl` will run a Teal script.
* `tl check module.tl` will type check a Teal module, report any errors and
  quit.
* `tl gen module.tl` will check for syntax errors and
  generate a `module.lua` file in plain Lua with all type annotations
  stripped.
* `tl warnings` will list all warnings the compiler can generate.

`tl` also supports some [compiler options](https://teal-language.org/book/compiler_options.html).
These can either be specified on the command line or inside a tlconfig.lua file at the root of your project.

### Building projects with Cyan

To build whole projects, you probably won't want to run `tl` on each
file individually. We recommend using [Cyan](https://github.com/teal-language/cyan),
the build tool designed for Teal.

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

You can read the [rendered documentation](https://teal-language.org/book/) online;
it can also be generated locally from the files in the [docs/](docs/) folder
of this repository.

## Type definitions

`tl` supports [declaration files](https://teal-language.org/book/declaration_files.html), which can be used to annotate the types
of third-party Lua libraries.

We have a collaborative repository for declaration files at
https://github.com/teal-language/teal-types — check it out and make your contribution!

## Text editor support

Teal language support is currently available for [Vim](https://github.com/teal-language/vim-teal), [Visual Studio Code](https://github.com/teal-language/vscode-teal), [lite](https://github.com/rxi/lite-plugins/blob/master/plugins/language_teal.lua) with [linter](https://github.com/drmargarido/linters/blob/master/linter_teal.lua) support and [Helix](https://docs.helix-editor.com/lang-support.html#:~:text=teal&text=teal-language-server) with LSP support.

## Community

* Join the chat on [Gitter](https://gitter.im/teal-language/community)!
  * You can also join via Matrix at [#teal-language_community:gitter.im](https://matrix.to/#/#teal-language_community:gitter.im)

Teal is a project started by [Hisham Muhammad](https://hisham.hm),
developed by a [growing number of contributors](https://github.com/teal-language/tl/graphs/contributors)
and is written using Teal itself!

## License

License is MIT, the same as Lua.
