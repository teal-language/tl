local string_checker = require("teal.check.block_string_checker")

local type environment = require("teal.environment")
local type Env = environment.Env
local type Result = environment.Result

local util = require("teal.util")
local read_file_skipping_bom = util.read_file_skipping_bom

local record file_checker
end

function file_checker.check(env: Env, filename: string, fd?: FILE): Result, string
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

   return string_checker.check(env, input, filename)
end

return file_checker
