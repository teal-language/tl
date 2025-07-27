local check = require("teal.check.check")

local parser = require("teal.parser")


local environment = require("teal.environment")



local input = {}


function input.check(env, filename, code)
   if env.loaded and env.loaded[filename] then
      return env.loaded[filename]
   end

   local program, syntax_errors = parser.parse(code, filename)

   if (not env.keep_going) and #syntax_errors > 0 then
      return environment.register_failed(env, filename, syntax_errors)
   end

   local result = check.check(program, env, filename)

   result.syntax_errors = syntax_errors

   return result
end

return input
