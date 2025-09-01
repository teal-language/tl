local check = require("teal.check.check")

local types = require("teal.types")
local a_type = types.a_type

local parser = require("teal.parser")
local type Node = parser.Node
local type ParseLang = parser.ParseLang
local reader = require("teal.reader")

local type environment = require("teal.environment")
local type Env = environment.Env
local type Result = environment.Result

local record string_checker
end

function string_checker.check(env: Env, input: string, filename?: string, parse_lang?: ParseLang): Result
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

   local result = check.check(program as Node, filename, env.defaults, env)

   result.syntax_errors = {}
   for _, e in ipairs(read_errs or {}) do table.insert(result.syntax_errors, e) end
   for _, e in ipairs(parse_errs or {}) do table.insert(result.syntax_errors, e) end

   return result
end

return string_checker
