local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local string_checker = require("teal.check.block_string_checker")





local util = require("teal.util")
local read_file_skipping_bom = util.read_file_skipping_bom

local file_checker = {}


function file_checker.check(env, filename, fd)
   if env.loaded and env.loaded[filename] then
      return env.loaded[filename]
   end

   local input, err

   if not fd then
      fd, err = io.open(filename, "rb")
      if not fd then
         return nil, "could not open " .. filename .. ": " .. err
      end
   end

   input, err = read_file_skipping_bom(fd)
   fd:close()
   if not input then
      return nil, "could not read " .. filename .. ": " .. err
   end

   return string_checker.check(env, input, filename)
end

return file_checker
