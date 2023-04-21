Examples
========

The user new to Teal may find a few examples helpful.  In that light these
examples are provided.::

  NOTE  The examples use the 'cyan' build tool, as it is expected to be the
        common tool used for initializing and building projects.

Files
-----

This example demonstrates ``records``, the type 'FILE' for file handles, and basic
IO.

Say you are in the directory 'examples', creating your 'files' project looks
like this.::

examples> cyan init files
      Info Created directory files
      Info Created directory files/src
      Info Created directory files/build
      Info Wrote files/tlconfig.lua


The 'files' example shows:

* use of record
* use of FILE type
* basic form for reading from STDIN or a file
* basic form for writing to STDOUT or a file

Here is it in use. In this example the program reads from STDIN and writes to a
file.::

  examples> tl gen files.tl
  Wrote: files.lua
  examples> cat -n files.tl | lua files.lua -o tmp.out
  examples> cat tmp.out
      1	-- files.tl
      2	-- Read content from STDIN or file; write content to STDOUT or file.
      3	--
      4	-- build: tl gen files.tl
      5	-- usage: lua files.lua [-i <file>] [-o <file>]
      6	-------------------------------------------------------------------------------
      7
      8	-- record to hold file handles
      9	local type Files = record
      10	  i: FILE
      11	  o: FILE
      12	end
      13
      14
      15	-- main -----------------------------------------------------------------------
      16	local function main(f: Files): integer
      17	  local lines = f.i:read("a")
      18	  -- do work on input, then write it out --
      19	  f.o:write(lines)
      20	  return 0
      21	end
      22
      23
      24	-- command line ---------------------------------------------------------------
      25	local fin, fout = "", ""      -- input and output file names
      26	local errstr = ""
      27	local i = 1
      28	while i <= #arg do
      29	  local a, b = arg[i], arg[i+1]
      30	  if a     == "-i" then if not b then errstr = "-i filename?" else fin=b;i=i+2 end
      31	  elseif a == "-o" then if not b then errstr = "-o filename?" else fout=b;i=i+2 end
      32	  else                                errstr = "unknown arg: " .. a
      33	  end
      34	  if errstr ~= "" then error(errstr) end  -- exit, giving a hint on the way out
      35	end
      36
      37	-- create file handles, as needed
      38	local files: Files = {}
      39	if fin  == "" then files.i = io.stdin  else files.i = assert(io.open(fin, "r")) end
      40	if fout == "" then files.o = io.stdout else files.o = assert(io.open(fout, "w")) end
      41
      42	-- launch the main function
      43	return main(files)
      44


