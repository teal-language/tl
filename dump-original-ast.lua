#!/usr/bin/env ./lua

if arg[1] == nil then
    print("Usage: dump-original-ast.lua <file (or - for stdin)>")
    os.exit(1)
end

local pretty = require("pl.pretty")
local block_parser = require("teal.parser")
local file = arg[1] == "-" and io.stdin or assert(io.open(arg[1], "rb"))
local code do
    local content = file:read("*a")
    file:close()
    code = content
end

local ast, err = block_parser.parse(code, "input", "tl")

if #err > 0 then
    print("Errors found:")
    for _, e in ipairs(err) do
        print(pretty(e))
    end
    os.exit(1)
end

print(pretty(ast))
