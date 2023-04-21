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
