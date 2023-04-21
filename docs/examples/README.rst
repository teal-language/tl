Examples
========

The user new to Teal may find a few examples helpful.  In that light these
examples are provided.

::

  NOTE  The examples use the 'cyan' build tool, as it is expected to be the
        common tool used for initializing and building projects.

In all of these examples it is assumed that the initial directory is 'examples'.

Files
-----

This example demonstrates ``cyan init`` to create a Teal project, as well as the
Teal language construct of ``record``, the type ``FILE`` for file handles, and
basic IO.

Create the Project
..................
Creating your 'files' project looks like this.::

  examples> cyan init files
        Info Created directory files
        Info Created directory files/src
        Info Created directory files/build
        Info Wrote files/tlconfig.lua


Cyan has created a configuration file (tlconfig) and two directories.

::

  examples> cd files
  files> tree .
  .
  ├── build
  ├── src
  └── tlconfig.lua

  3 directories, 1 file

Create main.tl
..............

In these examples ``main.tl`` will be the program that gets run. In other
examples you will have modules that are called from main.

src/main.tl

::

  -- files/src/main.tl
  -- Read content from STDIN or file; write content to STDOUT or file.
  --
  -- build: cyan build
  --
  -- usage: lua files.lua [-i <file>] [-o <file>]
  --
  -------------------------------------------------------------------------------

  -- record to hold file handles
  local type Handles = record
    i: FILE       -- input
    o: FILE       -- output
  end


  -- main -----------------------------------------------------------------------
  local function main(f: Handles): integer
    local lines = f.i:read("a")
    -- do work on input, then write it out --
    f.o:write(lines)
    return 0
  end


  -- command line ---------------------------------------------------------------
  local fin, fout = "", ""      -- input and output file names
  local errstr = ""
  local i = 1
  while i <= #arg do
    local a, b = arg[i], arg[i+1]
    if a     == "-i" then if not b then errstr = "-i filename?" else fin=b;i=i+2 end
    elseif a == "-o" then if not b then errstr = "-o filename?" else fout=b;i=i+2 end
    else                                errstr = "unknown arg: " .. a
    end
    if errstr ~= "" then error(errstr) end  -- exit, giving a hint on the way out
  end

  -- create file handles, as needed
  local handle: Handles = {}
  if fin  == "" then handle.i = io.stdin  else handle.i = assert(io.open(fin, "r")) end
  if fout == "" then handle.o = io.stdout else handle.o = assert(io.open(fout, "w")) end

  -- launch the main function
  return main(handle)


Build the Project
.................

Use Cyan to build the project.

::

  files> cyan build
        Info Type checked src/main.tl
        Info Wrote build/main.lua

And now the project directories look like...

::

files> tree .
.
├── build
│   └── main.lua
├── src
│   └── main.tl
└── tlconfig.lua


Run the Project
...............

In this example the program reads from STDIN and writes to a
file.

::

  files> ls -R1 | lua build/main.lua -o tmp.out
  files> cat tmp.out
  build
  src
  tlconfig.lua

  ./build:
  main.lua

  ./src:
  main.tl

You can delete the temporary file.

::

  files> rm tmp.out
