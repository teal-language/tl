#!/usr/bin/env lua_no_tailcalls

local function script_path()
   local str = debug.getinfo(2, "S").source:sub(2)
   return str:match("(.*[/\\])") or "."
end

package.path = script_path() .. "/?.lua;" .. package.path

local tl = require("tl")

local filename = arg[1]

if not filename then
   io.stderr:write("error: no input files\n")
   os.exit(1)
end

local fd, err = io.open(filename, "r")
if not fd then
   io.stderr:write("could not open " .. filename .. ": " .. err .. "\n")
   os.exit(1)
end

local input, err = fd:read("*a")
if not input then
   io.stderr:write("could not read " .. filename .. ": " .. err .. "\n")
   os.exit(1)
end

local tokens = tl.lex(input)

local errs = {}
local i, program = tl.parse_program(tokens, errs)

for _, err in ipairs(errs) do
   print(err.y, err.x, err.msg)
end

--print(pretty_print_ast(program))

--local tokens2 = lex(pretty_print_ast(program))
--print(pretty_print_tokens(tokens2))

local is_lua = filename:match("%.lua$") ~= nil

print("========================================")
local errors, unknowns = tl.type_check(program, is_lua)

print(#errors .. " error" .. (#errors ~= 1 and "s" or "") .. ":")
for _, err in ipairs(errors) do
   print(filename .. ":" .. err.y .. ":" .. err.x .. ": " .. err.err)
end

if is_lua and #unknowns > 0 then
   print("----------------------------------------")
   print(#unknowns .. " unknown variable" .. (#unknowns ~= 1 and "s" or "") .. ":")
   for _, var in ipairs(unknowns) do
      print(filename .. ":" .. var.y .. ":" .. var.x .. ": " .. var.name)
   end
end

if #errors == 0 then
   os.exit(0)
else
   os.exit(1)
end
