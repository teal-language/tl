#!/usr/bin/env -S tl run

local function find_all(dirname: string, pattern: string): function(): string
   local pd = io.popen("find '" .. dirname .. "' -name '" .. pattern .. "'")
   return pd:lines()
end

local module_to_files = {}

for luafile in find_all("teal", "*.lua") do
   local modname = luafile:gsub("%.lua$", ""):gsub("/", ".")
   module_to_files[modname] = luafile
end

local keys = {}
for k in pairs(module_to_files) do table.insert(keys, k) end
table.sort(keys)

-- populate the preload field so that we leave worrying about dependency order
-- to Lua
local content = {}
for _, k in ipairs(keys) do
   local fn = module_to_files[k]
   local f = assert(io.open(fn, 'rb'))
   local modcontent = assert(f:read'a')
   assert(f:close())

   table.insert(content,
string.format([[
-- module %s from %s
package.preload[%q] = function(...)
%s
end

]], k, fn, k, modcontent)
   )
end

do
   local f = assert(io.open('tl.lua', 'rb'))
   local modcontent = assert(f:read'a')
   assert(f:close())
   table.insert(content, modcontent)
end

local f = assert(io.open('tl_combined.lua', 'wb'))
assert(f:write(table.concat(content)))
assert(f:close())
