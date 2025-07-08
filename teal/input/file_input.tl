local string_input = require("teal.input.string_input")

local type environment = require("teal.environment")
local type Env = environment.Env
local type Result = environment.Result

local record file_input
end

local function read_file_skipping_bom(fd: FILE): string, string
   local bom <const> = "\239\187\191" -- "\xEF\xBB\xBF"
   local content, err = fd:read("*a")
   if not content then
      return nil, err
   end

   if content:sub(1, bom:len()) == bom then
      content = content:sub(bom:len() + 1)
   end
   return content, err
end

function file_input.check(env: Env, filename: string, fd?: FILE): Result, string
   if env.loaded and env.loaded[filename] then
      return env.loaded[filename]
   end

   local input, err: string, string

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
