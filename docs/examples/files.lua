local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io














local function main(f)
   local lines = f.i:read("a")

   f.o:write(lines)
   return 0
end



local fin, fout = "", ""
local errstr = ""
local i = 1
while i <= #arg do
   local a, b = arg[i], arg[i + 1]
   if a == "-i" then if not b then errstr = "-i filename?" else fin = b; i = i + 2 end
   elseif a == "-o" then if not b then errstr = "-o filename?" else fout = b; i = i + 2 end
   else errstr = "unknown arg: " .. a
   end
   if errstr ~= "" then error(errstr) end
end


local files = {}
if fin == "" then files.i = io.stdin else files.i = assert(io.open(fin, "r")) end
if fout == "" then files.o = io.stdout else files.o = assert(io.open(fout, "w")) end


return main(files)
