#!/usr/bin/env ./lua

if arg[1] == nil then
    print("Usage: dump-blocks.lua <file or - for stdin>")
    os.exit(1)
end

local pretty = require("pl.pretty")
local reader = require("teal.reader")
local file = arg[1] == "-" and io.stdin or assert(io.open(arg[1], "rb"))
local code do
    local content = file:read("*a")
    file:close()
    code = content
end


local blocks, err = reader.read(code, "input", "tl")
if #err > 0 then
    print("Errors found:")
    for _, e in ipairs(err) do
        print(pretty(e))
    end
    os.exit(1)
end

print(pretty(blocks))

-- local function dump_blocks(blocks, indent)
--     indent = indent or ""
--     for i , block in ipairs(blocks) do
--         print(indent..i..": "..block.kind)
--         print(indent.."  - Token: "..block.tk)
--         dump_blocks(block, indent.."  ")
--     end
-- end

-- dump_blocks(blocks)
