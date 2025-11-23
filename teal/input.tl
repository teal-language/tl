local check = require("teal.check.check")

local parser = require("teal.parser")
local reader = require("teal.reader")
local type Node = parser.Node

local type environment = require("teal.environment")
local type Env = environment.Env
local type Result = environment.Result

local record input
end

function input.check(env: Env, filename: string, code: string): Result
   if env.loaded and env.loaded[filename] then
      return env.loaded[filename]
   end

   local block_ast, read_errors = reader.read(code, filename)
   local program, parse_errors = parser.parse(block_ast, filename)
   local syntax_errors = {}
   for _, e in ipairs(read_errors) do
      table.insert(syntax_errors, e)
   end
   for _, e in ipairs(parse_errors) do
      table.insert(syntax_errors, e)
   end

   if (not env.keep_going) and #syntax_errors > 0 then
      return environment.register_failed(env, filename, syntax_errors)
   end

   local result = check.check(program as Node, env, filename)

   result.syntax_errors = syntax_errors

   return result
end

return input
