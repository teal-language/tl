# Compiler options

`tl` supports some compiler options. These can either be specified on the command line or inside a `tlconfig.lua` file.

## Project configuration

When running `tl`, the compiler will try to read the compilation options from a file called `tlconfig.lua` inside the current working directory.

Here is an example of a `tlconfig.lua` file:
```lua
return {
    include = {
        "folder1/",
        "folder2/"
    },
    preload_modules = {
        "my.other.module"
    }
}
```

## List of compiler options

| Command line option | Config key | Type | Description |
| --- | --- | --- | --- |
| `-l --preload` | `preload_modules` | `{string}` | Execute the equivalent of `require('modulename')` before executing the tl script(s). |
| `-I --include` | `include` | `{string}` | Prepend this directory to the module search path.
