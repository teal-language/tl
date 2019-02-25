#!/usr/bin/env lua_no_tailcalls

local tl = require("tl")

local fd = io.open(arg[1], "r")
local input = fd:read("*a")
local tokens = tl.lex(input)

local errs = {}
local i, program = tl.parse_program(tokens, errs)

for _, err in ipairs(errs) do
   print(err.y, err.x, err.msg)
end

--print(pretty_print_ast(program))

--local tokens2 = lex(pretty_print_ast(program))
--print(pretty_print_tokens(tokens2))

print("================================")
local errors = tl.type_check(program)

print(#errors .. " error" .. (#errors ~= 1 and "s" or "") .. ":")
for _, err in ipairs(errors) do
   print(arg[1] .. ":" .. err.y .. ":" .. err.x .. ": " .. err.err)
end
