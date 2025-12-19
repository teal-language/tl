local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table; local check = require("teal.check.check")

local parser = require("teal.parser")
local reader = require("teal.reader")


local environment = require("teal.environment")



local input = {}


function input.check(env, filename, code)
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

   local result = check.check(program, env, filename)

   result.syntax_errors = syntax_errors

   return result
end

return input
