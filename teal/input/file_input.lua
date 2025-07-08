local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local string = _tl_compat and _tl_compat.string or string; local string_input = require("teal.input.string_input")





local file_input = {}


local function read_file_skipping_bom(fd)
   local bom = "\239\187\191"
   local content, err = fd:read("*a")
   if not content then
      return nil, err
   end

   if content:sub(1, bom:len()) == bom then
      content = content:sub(bom:len() + 1)
   end
   return content, err
end

function file_input.check(env, filename, fd)
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

   return string_input.check(env, filename, input)
end

return file_input
