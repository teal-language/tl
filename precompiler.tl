#!/usr/bin/env -S tl run

package.path = "./?.lua;" .. package.path

local tl = require("tl")
local types = require("teal.types")
local env = tl.new_env()

local put = table.insert
local format = string.format

local record PersistState
   ctr: integer
   seen: {any: string}
   out: {string}
   dot: {string: boolean}
end

local keywords: {string:boolean} = {
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

local function default_sort(a: any, b: any): boolean
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

local function sortedpairs<K, V>(tbl: {K: V}): function(): K, V
   local keys = {}
   for k,_ in pairs(tbl) do
      table.insert(keys, k)
   end
   table.sort(keys, default_sort)
   local i = 1
   return function(): K, V
      local key = keys[i]
      i = i + 1
      return key, tbl[key]
   end
end

local persist: function(tbl: {any:any}): {string}
do
   local function is_dot(k: string, ps: PersistState): boolean
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

   local function recurse(tbl: {any:any}, ps: PersistState): string
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
         if v is table then
            any_subtable = true
         else
            local val: string
            if v is string then
               val = format("%q", v)
            else
               val = tostring(v)
            end
            if k is string and is_dot(k, ps) then
               put(out, k)
            else
               put(out, "[")
               if k is string then
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
            if v is table then
               local val = recurse(v, ps)
               put(out, name)
               if k is string and is_dot(k, ps) then
                  put(out, ".")
                  put(out, k)
               else
                  put(out, "[")
                  if k is string then
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

   persist = function(tbl: {any:any}): {string}
      local ps: PersistState = {
         ctr = 0,
         seen = {},
         out = {},
         dot = {},
      }
      recurse(tbl, ps)
      return ps.out
   end
end

local out = persist(env.globals as {any:any})
local typeid_ctr, typevar_ctr = types.internal_get_state()

put(out, "\nreturn { globals = T1, typeid_ctr = ")
put(out, tostring(typeid_ctr))
put(out, ", typevar_ctr = ")
put(out, tostring(typevar_ctr))
put(out, "}\n")

print(table.concat(out))
