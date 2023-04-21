-- files.tl
-- Read content from STDIN or file; write content to STDOUT or file.
--
-- build: tl gen files.tl
-- usage: lua files.lua [-i <file>] [-o <file>]
-------------------------------------------------------------------------------

-- record to hold file handles
local type Files = record
  i: FILE
  o: FILE
end


-- main -----------------------------------------------------------------------
local function main(f: Files): integer
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
local files: Files = {}
if fin  == "" then files.i = io.stdin  else files.i = assert(io.open(fin, "r")) end
if fout == "" then files.o = io.stdout else files.o = assert(io.open(fout, "w")) end

-- launch the main function
return main(files)

