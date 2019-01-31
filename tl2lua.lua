
local tl = require("tl")

local fd = io.open(arg[1], "r")
local input = fd:read("*a")
local tokens = tl.lex(input)
local errs = {}
local i, program = tl.parse_program(tokens, errs)
if #errs > 0 then
   for _, err in ipairs(errs) do
      io.stderr:write(arg[1]..":"..err.y..":"..err.x..": "..err.msg.."\n") 
   end
   os.exit(1)
end
local tokens2 = tl.lex(tl.pretty_print_ast(program))

print(tl.pretty_print_tokens(tokens2))
