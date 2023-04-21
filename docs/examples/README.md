# Examples

The user new to Teal may find a few examples helpful.  In that light these
examples are provided; where each example has:

1. Explanatory text, and
2. Working source code.

>  NOTE  The examples use the 'cyan' build tool, as it is expected to be the
>        common tool used for initializing and building projects.

In all of these examples it is assumed that the root directory is 'examples'.

The use of 'tree' command is only for illustration in these notes. The user does
*not* need to use the 'tree' command.

## Files

This example demonstrates `cyan init` to create a Teal project, as well as the
Teal language construct of `record`, the type `FILE` for file handles, and
basic IO.

### Create the Project

Create your 'files' project with `cyan init files`.

```
examples> cyan init files
    Info Created directory files
    Info Created directory files/src
    Info Created directory files/build
    Info Wrote files/tlconfig.lua
```

Cyan has created a configuration file (`tlconfig`) and two directories. This
is the standard project layout.

```
examples> cd files
files> tree .
.
├── build
├── src
└── tlconfig.lua
```

### Create main.tl

In these examples `main.tl` will be the program that gets run. In other
examples you will have modules that are called from main.

Create [src/main.tl](files/src/main.tl)

The file handles appear like this in main.tl

```
-- record to hold file handles
local type Handles = record
  i: FILE       -- input
  o: FILE       -- output
end
```

And are used like this:
```
local function main(f: Handles): integer
  local lines = f.i:read("a")
  -- do work on input, then write it out --
  f.o:write(lines)
  return 0
end
```

### Build the Project

Use Cyan to build the project.

```
files> cyan build
    Info Type checked src/main.tl
    Info Wrote build/main.lua
```

And now the project directories look like...

```
files> tree .
.
├── build
│   └── main.lua
├── src
│   └── main.tl
└── tlconfig.lua
```

### Run the Project

In this example the program reads from STDIN and writes to a file.

```
files> ls -R1 | lua build/main.lua -o tmp.out
files> cat tmp.out
build
src
tlconfig.lua

./build:
main.lua

./src:
main.tl
```

You can delete the temporary file.

```
files> rm tmp.out
```
