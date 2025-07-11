local check = require("teal.check.check")

local types = require("teal.types")
local a_type = types.a_type

local reader = require("teal.reader")
local parser = require("teal.block-parser")
local type Node = parser.Node
local type PNode = require("teal.parser").Node
local type ParseLang = parser.ParseLang

local type environment = require("teal.environment")
local type Env = environment.Env
local type Result = environment.Result

local record string_checker
end

function string_checker.check(env: Env, input: string, filename?: string, parse_lang?: ParseLang): Result
   -- parse_lang = parse_lang or parser.lang_heuristic(filename, input)
   parse_lang = parse_lang or "tl"

   if env.loaded and env.loaded[filename] then
      return env.loaded[filename]
   end
   filename = filename or ""

   local input, syntax_errors = reader.read(input, filename, parse_lang as reader.BlockLang)
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

   local result = check.check(program as PNode, filename, env.defaults, env)

   result.syntax_errors = syntax_errors

   return result
end

return string_checker

