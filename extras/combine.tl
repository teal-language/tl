#!/usr/bin/env -S tl run

local module_to_file: {string:string} = {}
local module_to_content: {string:string} = {}

local function scan_deps(k: string)
   if not module_to_content[k] then
      local fn = k:gsub("%.", "/") .. ".lua"
      module_to_file[k] = fn

      local f = assert(io.open(fn, "rb"))
      local modcontent = assert(f:read("*a"))
      assert(f:close())
      module_to_content[k] = modcontent

      -- all the requires in teal.* are this syntax
      for requirement in modcontent:gmatch([[require%("([^"]+)"%)]]) do
         scan_deps(requirement)
      end
   end
end

scan_deps("teal.api.v2")

local keys = {}
for k in pairs(module_to_content) do table.insert(keys, k) end
table.sort(keys)

-- populate the preload field so that we leave worrying about dependency order
-- to Lua
local content = {}
for _, k in ipairs(keys) do
   local fn = module_to_file[k]
   local modcontent = module_to_content[k]
   table.insert(content,
string.format([[
-- module %s from %s
package.preload[%q] = function(...)
%s
end

]], k, fn, k, modcontent)
   )
end

table.insert(content,[[
return require("teal.api.v2")
]])

local f = assert(io.open('tl.lua', 'wb'))
assert(f:write(table.concat(content)))
assert(f:close())
