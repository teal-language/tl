# Examples

The user new to Teal may find a few examples helpful.  In that light these
examples are provided; where each example has:

1. Explanatory text, and
2. Working source code.

>  NOTE  The examples use the 'cyan' build tool, as it is expected to be the
>        common tool used for initializing and building projects.

In all of these examples it is assumed that the root directory is 'examples'.

## Files

This example demonstrates using `cyan` to create and build a Teal project, as
well as the Teal language construct of `record`, the type `FILE` for file
handles, and basic IO.

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
files> find .
.
./build
./src
./tlconfig.lua
```

### Create main.tl

In this example `main.tl` will be the program that gets run. More complex
projects will have modules that are called from main.

Create [src/main.tl](files/src/main.tl).

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
./build
./build/main.lua
./src
./src/main.tl
./tlconfig.lua
```

### Run the Project

The program reads input arguments `-i <filename>` and `-o <filename>` from
the command line to select input and output filenames. If those are not
given, it uses standard input and standard output as fallback defaults.

In this example the program reads data from the `ls` command piped via
standard input, and writes to a file:

```
files> ls -R1 | lua build/main.lua -o tmp.out
files> cat tmp.out
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
files> rm tmp.out
```
