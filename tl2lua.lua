
local tl = require("tl")

local fd = io.open(arg[1], "r")
local input = fd:read("*a")
local tokens = tl.lex(input)
local errs = {}
local i, program = tl.parse_program(tokens, errs)
local tokens2 = tl.lex(tl.pretty_print_ast(program))

print(tl.pretty_print_tokens(tokens2))
