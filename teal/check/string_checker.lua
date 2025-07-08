local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local check = require("teal.check.check")

local parser = require("teal.parser")


local environment = require("teal.environment")



local string_checker = {}


function string_checker.check(env, input, filename)
   assert(env)
   if env.loaded and env.loaded[filename] then
      return env.loaded[filename]
   end
   filename = filename or "<input>.tl"

   local program, syntax_errors = parser.parse(input, filename)

   if (not env.keep_going) and #syntax_errors > 0 then
      return environment.register_failed(env, filename, syntax_errors)
   end

   local result = check.check(program, env, filename)

   result.syntax_errors = syntax_errors

   return result
end

return string_checker
