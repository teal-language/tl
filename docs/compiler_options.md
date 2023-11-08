# Compiler options

`tl` supports some compiler options. These can either be specified on the command line or inside a `tlconfig.lua` file.

## Project configuration

When running `tl`, the compiler will try to read the compilation options from a file called `tlconfig.lua` inside the current working directory.

Here is an example of a `tlconfig.lua` file:
```lua
return {
    include_dir = {
        "folder1/",
        "folder2/"
    },
}
```

## List of compiler options

| Command line option  | Config key                 | Type       | Relevant Commands           | Description |
| -------------------- | -------------------------- | ---------- | --------------------------- | ----------- |
| `-l --require`       |                            | `{string}` | `run`                       | Require a module prior to executing the script. This is similar in behavior to the `-l` flag in the Lua interpreter. |
| `-I --include-dir`   | `include_dir`              | `{string}` | `build` `check` `gen` `run` | Prepend this directory to the module search path.
| `--gen-compat`       | `gen_compat`               | `string`   | `build` `gen` `run`         | Generate compatibility code for targeting different Lua VM versions. See [below](#generated-code) for details.
| `--gen-target`       | `gen_target`               | `string`   | `build` `gen` `run`         | Minimum targeted Lua version for generated code. Options are `5.1`, `5.3` and `5.4`. See [below](#generated-code) for details.
|                      | `include`                  | `{string}` | `build`                     | The set of files to compile/check. See below for details on patterns.
|                      | `exclude`                  | `{string}` | `build`                     | The set of files to exclude. See below for details on patterns.
| `--keep-hashbang`    |                            |            | `gen`                       | Preserve hashbang line (`#!`) at the top of file if present.
| `-s --source-dir`    | `source_dir`               | `string`   | `build`                     | Set the directory to be searched for files. `build` will compile every .tl file in every subdirectory by default.
| `-b --build-dir`     | `build_dir`                | `string`   | `build`                     | Set the directory for generated files, mimicking the file structure of the source files.
|                      | `files`                    | `{string}` | `build`                     | The names of files to be compiled. Does not accept patterns like `include`.
| `-p --pretend`       |                            |            | `build` `gen`               | Don't compile/write to any files, but type check and log what files would be written to.
| `--wdisable`         | `disable_warnings`         | `{string}` | `build` `check` `run`       | Disable the given warnings.
| `--werror`           | `warning_error`            | `{string}` | `build` `check` `run`       | Promote the given warnings to errors.
| `--run-build-script` | `run_build_script`         | `boolean`  | `run` `check` `gen`         | Runs the build script as if `tl build` was being run
|                      | `build_file_output_dir`    | `string`   | `run` `check` `gen` `build` | Folder where the generated files from the build script will be accessible in
|                      | `internal_compiler_output` | `string`   | `run` `check` `gen` `build` | Folder to store cache files for use by the compiler
| `--global-env-def`   | `global_env_def`           | `string`   | `build` `check` `gen` `run` | Specify a definition module declaring any custom globals predefined in your Lua environment. See the [declaration files](declaration_files.md#global-environment-definition) page for details. |

### Generated code

Teal is a Lua dialect that most closely resembles Lua 5.3-5.4, but it is able
to target Lua 5.1 (including LuaJIT) and Lua 5.2 as well. The compiler attempts
to produce code that, given an input `.tl` file, generates the same behavior
on various Lua versions.

However, there are limitations in the portability across Lua versions, and the
options `--gen-target` and `--gen-compat` give you some control over the generated
code.

#### Target version

The configuration option `gen_target` (`--gen-target` in the CLI) allow you to
choose what is the minimum Lua version you want to target. Valid options are
`5.1` (for Lua 5.1 and above, including LuaJIT) and `5.3` for Lua 5.3 and above.

Using `5.1`, Teal will generate compatibility code for the integer division operator,
a compatibility forward declaration for `table.unpack` and will use the `bit32`
library for bitwise operators.

Using `5.3`, Teal will generate code using the native `//` and bitwise operators.

The option `5.4` is equivalent to `5.3`, but it also allows using the `<close>`
variable annotation. Since that is incompatible with other Lua versions, using
this option requires using `--gen-compat=off`.

Code generated with `--gen-target=5.1` will still run on Lua 5.3+, but not
optimally: the native Lua 5.3+ operators have better performance and better
precision. For example, if you are targeting Lua 5.1, the Teal code `x // y`
will generate `math.floor(x / y)` instead.

If you do not use these options, the Teal compiler will infer a default
target implicitly.

#### Which Lua version does the Teal compiler target by default?

If set explicitly via the `--gen-target` flag of the `tl` CLI (or the equivalent
options in the programmatic API), the generated code will target the Lua
version requested: 5.1, 5.3 or 5.4.

If the code generation target is not set explicitly via `--gen-target`, Teal
will target the Lua version most compatible with the version of the Lua VM
under which the compiler itself is running. For example, if running under
something that reports `_VERSION` as `"Lua 5.1"` or `"Lua 5.2"` (such as LuaJIT),
it will generate 5.1-compatible code. If running under Lua 5.3 or greater, it
will output code that uses 5.3 extensions.

The stand-alone `tl` binaries are built using Lua 5.4, so they default to
generating 5.3-compatible code. If you install `tl` using LuaRocks, the CLI
will use the Lua version you use with LuaRocks, so it will default to that
Lua's version.

If you require the `tl` Lua module and use the `tl.loader()`, it will do the
implicit version selection, picking the right choice based on the Lua version
you're running it on.

#### Compatibility wrappers

Another source of incompatibility across Lua versions is the standard library.
This is mostly fixable via compatibility wrappers, implemented by the
[compat53](https://github.com/keplerproject/lua-compat-5.3) Lua library.

Teal's own standard library definition as used by its type checker most
closely resembles that of Lua 5.3+, and the compiler's code generator can
generate code that uses compat53 in order to produce consistent behavior
across Lua versions, at the cost of adding a dependency when running on older
Lua versions. For Lua 5.3 and above, compat53 is never needed.

To avoid forcing a dependency on Teal users running Lua 5.1, 5.2 or LuaJIT,
especially those who take care to avoid incompatibilities in the Lua standard
library and hence wouldn't need compat53 in their code, Teal offers three
modes of operation for compatibility wrapper generation via the `gen_compat`
flag (and `--gen-compat` CLI option):

* `off` - you can choose to disable generating compatibility code entirely.
  When type checking, Teal will still assume the standard library is 5.3-compatible.
  If you run the Teal module on an older Lua version and use any functionality
  from the standard library that is not available on that version, you will
  get a runtime error, similar to trying to run Lua 5.3 code on an older version.
* `optional` (*default*) - Teal will generate compatibility code which
  initializes the the compat53 library wrapping `require` with a `pcall`,
  so that it doesn't produce a failure if the library is missing. This means
  that, if compat53 is installed, you'll get the compliant standard library
  behavior when running on Lua 5.2 and below, but if compat53 is missing,
  you'll get the same behavior as described for `off` above.
* `required` - Teal will generate compatibility code which initializes compat53
  with a plain `require`, meaning that you'll get a runtime error when loading
  the generated module from Lua if compat53 is missing. You can use this option
  if you are distributing the generated Lua code for users running different
  Lua versions and you want to ensure that your Teal code behaves the same
  way on all Lua versions, even if at the cost of an additional dependency.

### Global environment definition

To make the Teal compiler aware of global variables in your execution environment,
you may pass a declaration module to the compiler using the `--global-env-def` flag
in the CLI or the `global_env_def` string in `tlconfig.lua`.

For more information, see the [declaration files](declaration_files.md#global-environment-definition) page.

### Include/Exclude patterns

The `include` and `exclude` fields can have glob-like patterns in them:
- `*`: Matches any number of characters (excluding directory separators)
- `**/`: Matches any number subdirectories

In addition
- setting the `source_dir` has the effect of prepending `source_dir` to all patterns.
- currently, `include` will only include `.tl` files even if the extension isn't specified

For example:
If our project was laid out as such:
```
tlconfig.lua
src/
| foo/
| | bar.tl
| | baz.tl
| bar/
| | a/
| | | foo.tl
| | b/
| | | foo.tl
```

and our tlconfig.lua contained the following:
```lua
return {
   source_dir = "src",
   build_dir = "build",
   include = {
      "foo/*.tl",
      "bar/**/*.tl"
   },
   exclude = {
      "foo/bar.tl"
   }
}
```

Running `tl build -p` will type check the `include`d files and show what would be written to.
Running `tl build` will produce the following files.
```
tlconfig.lua
src/
| foo/
| | bar.tl
| | baz.tl
| bar/
| | a/
| | | foo.tl
| | b/
| | | foo.tl
build/
| foo/
| | baz.lua
| bar/
| | a/
| | | foo.lua
| | b/
| | | foo.lua
```

Additionally, complex patterns can be used for whatever convoluted file structure we need.
```lua
return {
   include = {
      "foo/**/bar/**/baz/**/*.tl"
   }
}
```
This will compile any `.tl` file with a sequential `foo`, `bar`, and `baz` directory in its path.
