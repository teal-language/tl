# Examples

The user new to Teal may find a few examples helpful.  In that light these
examples are provided; where each example has:

1. Explanatory text, and
2. Working source code.

The examples use the [Cyan](https://github.com/teal-language/cyan) build tool,
as it is expected to be the common tool used for initializing and building
projects. You can install Cyan with `luarocks install cyan`.

In all of these examples it is assumed that the root directory is `examples`.

## Files

This example demonstrates using `cyan` to create and build a Teal project, as
well as the Teal language construct of `record`, the type `FILE` for file
handles, and basic IO.

### Create the Project

The `docs/examples/files` folder contains an example of the finished project.
But let's follow the steps to replicate it from scratch.

Go to your home folder (so that you're not within a Teal project, such as the
Teal repository itself), and create your `myproject` project with `cyan init
myproject`.

```
> cd
~> cyan init myproject
    Info Created directory myproject
    Info Created directory myproject/src
    Info Created directory myproject/build
    Info Wrote myproject/tlconfig.lua
```

Cyan has created a configuration file (`tlconfig`) and two directories. This
is the standard project layout.

```
~> cd myproject
~/myproject> find .
.
./build
./src
./tlconfig.lua
```

### Create main.tl

In this example `main.tl` will be the program that gets run. More complex
projects will have modules that are called from main.

Create [src/main.tl](files/src/main.tl) in your project.

### Build the Project

Use Cyan to build the project.

```
~/myproject> cyan build
    Info Type checked src/main.tl
    Info Wrote build/main.lua
```

And now the project directories look like...

```
~/myproject> find .
.
./build
./build/main.lua
./src
./src/main.tl
./tlconfig.lua
```

### Run the Project

This simple program takes in input, converts it to uppercase, and produces an
output.

The program reads input arguments `-i <filename>` and `-o <filename>` from the
command line to select input and output filenames. If those are not given, it
uses standard input and standard output as fallback defaults.

In this example the program reads data from the `ls` command piped via
standard input, and writes to a file:

```
~/myproject> ls -R1 | lua build/main.lua -o tmp.out
~/myproject> cat tmp.out
BUILD
SRC
TLCONFIG.LUA

./BUILD:
MAIN.LUA

./SRC:
MAIN.TL
```

You can delete the temporary file.

```
~/myproject> rm tmp.out
```
