#!/usr/bin/env ./lua

local ignore_list   = { ["yend"] = true, ["xend"] = true }
local pretty        = require "pl.pretty"
local reader        = require "teal.reader"
local block_parser  = require "teal.block-parser"
local old_parser    = require "teal.parser"
local tabular       = require "tabular"

local function load_source(fname)
    local fh = (fname == "-" and io.stdin) or assert(io.open(fname, "rb"))
    local code = fh:read("*a")
    fh:close()
    return code
end

local function fatal(msg)
    io.stderr:write(msg .. "\n")
    os.exit(1)
end

local function parse_new(code)
    local blocks, err1 = reader.read(code, "input", "tl")
    if #err1 > 0 then fatal("new parser (reader) errors:\n" .. pretty.write(err1)) end
    local ast, err2 = block_parser.parse(blocks, "input", "tl")
    if #err2 > 0 then fatal("new parser (block-parser) errors:\n" .. pretty.write(err2)) end
    return ast
end

local function parse_old(code)
    local ast, err = old_parser.parse(code, "input", "tl")
    if #err > 0 then fatal("old parser errors:\n" .. pretty.write(err)) end
    return ast
end

local function fmt_path(path)
    return (#path == 0) and "<root>" or path
end

local diffs, seen = {}, {}
local function diff(a, b, path)
    if a == b then return end
    local ta, tb = type(a), type(b)
    local p = fmt_path(path)
    if ta ~= tb and tb ~= "nil" then
        table.insert(diffs, { path = p, reason = "type mismatch", old = ta, new = tb })
        return
    end
    if ta ~= "table" then
        table.insert(diffs, { path = p, reason = "value mismatch", old = tostring(a), new = tostring(b) })
        return
    end
    local id = tostring(a) .. "|" .. tostring(b)
    if seen[id] then return end
    seen[id] = true

    local keys, mark = {}, {}
    for k in pairs(a) do keys[#keys+1], mark[k] = k, true end
    for k in pairs(b) do if not mark[k] then keys[#keys+1] = k end end
    for _, k in ipairs(keys) do
        if not ignore_list[k] then
            diff(a[k], b[k], path .. (path == "" and "" or ".") .. tostring(k))
        end
    end
end

local file = assert(arg[1], "Usage: diff-ast.lua <file | ->")
local src      = load_source(file)
local new_ast  = parse_new(src)
local old_ast  = parse_old(src)

diff(new_ast, old_ast, "")

if #diffs == 0 then
    print("ASTs are identical")
else
    print(tabular(diffs, { "path", "reason", "old", "new" }))
end
