local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local package = _tl_compat and _tl_compat.package or package; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type

package.path = "./?.lua;" .. package.path

local tl = require("tl")
local types = require("teal.types")
local env = tl.new_env()

local put = table.insert
local format = string.format








local keywords = {
   ["and"] = true,
   ["break"] = true,
   ["do"] = true,
   ["else"] = true,
   ["elseif"] = true,
   ["end"] = true,
   ["false"] = true,
   ["for"] = true,
   ["function"] = true,
   ["goto"] = true,
   ["if"] = true,
   ["in"] = true,
   ["local"] = true,
   ["nil"] = true,
   ["not"] = true,
   ["or"] = true,
   ["repeat"] = true,
   ["return"] = true,
   ["then"] = true,
   ["true"] = true,
   ["until"] = true,
   ["while"] = true,
}

local function default_sort(a, b)
   local ta = type(a)
   local tb = type(b)
   if ta == "number" and tb == "number" then
      return tonumber(a) < tonumber(b)
   elseif ta == "number" then
      return true
   elseif tb == "number" then
      return false
   else
      return tostring(a) < tostring(b)
   end
end

local function sortedpairs(tbl)
   local keys = {}
   for k, _ in pairs(tbl) do
      table.insert(keys, k)
   end
   table.sort(keys, default_sort)
   local i = 1
   return function()
      local key = keys[i]
      i = i + 1
      return key, tbl[key]
   end
end

local persist
do
   local function is_dot(k, ps)
      if ps.dot[k] then
         return true
      end
      if keywords[k] then
         return false
      end
      if not k:match("^[a-zA-Z][a-zA-Z0-9_]*$") then
         return false
      end
      ps.dot[k] = true
      return true
   end

   local function recurse(tbl, ps)
      if ps.seen[tbl] then
         return ps.seen[tbl]
      end
      ps.ctr = ps.ctr + 1
      local name = "T" .. tostring(ps.ctr)
      ps.seen[tbl] = name

      local any_subtable = false
      local out = ps.out
      put(out, name)
      put(out, "={")
      for k, v in sortedpairs(tbl) do
         if type(v) == "table" then
            any_subtable = true
         else
            local val
            if type(v) == "string" then
               val = format("%q", v)
            else
               val = tostring(v)
            end
            if type(k) == "string" and is_dot(k, ps) then
               put(out, k)
            else
               put(out, "[")
               if type(k) == "string" then
                  put(out, format("%q", k))
               else
                  put(out, tostring(k))
               end
               put(out, "]")
            end
            put(out, "=")
            put(out, val)
            put(out, ",")
         end
      end
      put(out, "}\n")

      if any_subtable then
         for k, v in sortedpairs(tbl) do
            if type(v) == "table" then
               local val = recurse(v, ps)
               put(out, name)
               if type(k) == "string" and is_dot(k, ps) then
                  put(out, ".")
                  put(out, k)
               else
                  put(out, "[")
                  if type(k) == "string" then
                     put(out, format("%q", k))
                  else
                     put(out, tostring(k))
                  end
                  put(out, "]")
               end
               put(out, "=")
               put(out, val)
               put(out, "\n")
            end
         end
      end

      return name
   end

   persist = function(tbl)
      local ps = {
         ctr = 0,
         seen = {},
         out = {},
         dot = {},
      }
      recurse(tbl, ps)
      return ps.out
   end
end

local out = persist(env.globals)
local next_type = types.a_type({ x = 0, y = 0 }, "any", {})
local typevar_ctr = tl.internal_typevar_ctr()

put(out, "\nreturn { globals = T1, next_typeid = ")
put(out, tostring(next_type.typeid))
put(out, ", typevar_ctr = ")
put(out, tostring(typevar_ctr))
put(out, "}\n")

print(table.concat(out))
