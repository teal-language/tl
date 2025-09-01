local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table; local check = require("teal.check.check")

local types = require("teal.types")
local a_type = types.a_type

local parser = require("teal.parser")


local reader = require("teal.reader")





local string_checker = {}


function string_checker.check(env, input, filename, parse_lang)
   parse_lang = parse_lang or parser.lang_heuristic(filename, input)

   if env.loaded and env.loaded[filename] then
      return env.loaded[filename]
   end
   filename = filename or ""

   local blocks, read_errs = reader.read(input, filename, parse_lang)
   if (not env.keep_going) and #read_errs > 0 then
      local result = {
         ok = false,
         filename = filename,
         type = a_type({ f = filename, y = 1, x = 1 }, "boolean", {}),
         type_errors = {},
         syntax_errors = read_errs,
         env = env,
      }
      env.loaded[filename] = result
      table.insert(env.loaded_order, filename)
      return result
   end


   local program, parse_errs = parser.parse(blocks, filename, parse_lang)
   if (not env.keep_going) and #parse_errs > 0 then
      local result = {
         ok = false,
         filename = filename,
         type = a_type({ f = filename, y = 1, x = 1 }, "boolean", {}),
         type_errors = {},
         syntax_errors = parse_errs,
         env = env,
      }
      env.loaded[filename] = result
      table.insert(env.loaded_order, filename)
      return result
   end

   local result = check.check(program, filename, env.defaults, env)

   result.syntax_errors = {}
   for _, e in ipairs(read_errs or {}) do table.insert(result.syntax_errors, e) end
   for _, e in ipairs(parse_errs or {}) do table.insert(result.syntax_errors, e) end

   return result
end

return string_checker
