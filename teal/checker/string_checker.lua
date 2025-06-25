local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local table = _tl_compat and _tl_compat.table or table; local type_checker = require("teal.checker.type_checker")

local types = require("teal.types")
local a_type = types.a_type

local parser = require("teal.parser")



local environment = require("teal.environment")



local string_checker = {}


function string_checker.check(env, input, filename, parse_lang)
   parse_lang = parse_lang or parser.lang_heuristic(filename, input)

   if env.loaded and env.loaded[filename] then
      return env.loaded[filename]
   end
   filename = filename or ""

   local program, syntax_errors = parser.parse(input, filename, parse_lang)

   if (not env.keep_going) and #syntax_errors > 0 then
      local result = {
         ok = false,
         filename = filename,
         type = a_type({ f = filename, y = 1, x = 1 }, "boolean", {}),
         type_errors = {},
         syntax_errors = syntax_errors,
         env = env,
      }
      env.loaded[filename] = result
      table.insert(env.loaded_order, filename)
      return result
   end

   local result = type_checker.check(program, filename, env.defaults, env)

   result.syntax_errors = syntax_errors

   return result
end

return string_checker
