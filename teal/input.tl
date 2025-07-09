local check = require("teal.check.check")

local parser = require("teal.parser")
local type Node = parser.Node

local type environment = require("teal.environment")
local type Env = environment.Env
local type Result = environment.Result

local record input
end

local function skip_bom(content: string): string
   local bom <const> = "\239\187\191" -- "\xEF\xBB\xBF"
   local len = bom:len()
   if content:sub(1, len) == bom then
      return content:sub(len + 1)
   end
   return content
end

function input.check(env: Env, filename: string, code: string): Result
   if env.loaded and env.loaded[filename] then
      return env.loaded[filename]
   end

   local program, syntax_errors = parser.parse(skip_bom(code), filename)

   if (not env.keep_going) and #syntax_errors > 0 then
      return environment.register_failed(env, filename, syntax_errors)
   end

   local result = check.check(program as Node, env, filename)

   result.syntax_errors = syntax_errors

   return result
end

return input

