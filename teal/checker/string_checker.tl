local type_checker = require("teal.checker.type_checker")

local types = require("teal.types")
local a_type = types.a_type

local parser = require("teal.parser")
local type Node = parser.Node
local type ParseLang = parser.ParseLang

local environment = require("teal.environment")
local type Env = environment.Env
local type Result = environment.Result

local record string_checker
end

function string_checker.check(input: string, env?: Env, filename?: string, parse_lang?: ParseLang): Result
   parse_lang = parse_lang or parser.lang_heuristic(filename, input)
   env = env or environment.default(parse_lang)

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

   local result = type_checker.check(program as Node, filename, env.defaults, env)

   result.syntax_errors = syntax_errors

   return result
end

return string_checker

