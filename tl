#!/usr/bin/env lua_no_tailcalls

local function script_path()
   local str = debug.getinfo(2, "S").source:sub(2)
   return str:match("(.*[/\\])") or "."
end

package.path = script_path() .. "/?.lua;" .. package.path

local tl = require("tl")

local filename = arg[1]

if not filename then
   io.stderr:write("usage: tl <file>\n")
   os.exit(1)
end

local result, err = tl.process(filename)
if err then
   io.stderr:write(err .. "\n")
   os.exit(1)
end

for _, err in ipairs(result.syntax_errors) do
   print(err.y, err.x, err.msg)
end

--print(pretty_print_ast(program))

--local tokens2 = lex(pretty_print_ast(program))
--print(pretty_print_tokens(tokens2))


print("========================================")
print(#result.type_errors .. " error" .. (#result.type_errors ~= 1 and "s" or "") .. ":")
for _, err in ipairs(result.type_errors) do
   print(filename .. ":" .. err.y .. ":" .. err.x .. ": " .. err.err)
end

if #result.unknowns > 0 then
   print("----------------------------------------")
   print(#result.unknowns .. " unknown variable" .. (#result.unknowns ~= 1 and "s" or "") .. ":")
   for _, var in ipairs(result.unknowns) do
      print(filename .. ":" .. var.y .. ":" .. var.x .. ": " .. var.name)
   end
end

if #result.syntax_errors == 0 and #result.type_errors == 0 then
   os.exit(0)
else
   os.exit(1)
end
