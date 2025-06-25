local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local package = _tl_compat and _tl_compat.package or package; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type

package.path = "./?.lua;" .. package.path

local tl = require("tl")
local environment = require("teal.environment")
local env = environment.construct()
local types = require("teal.types")
local typeid_ctr, typevar_ctr = types.internal_get_state()

local put = table.insert
local format = string.format

local SHORT_NAME = 5
local N_LOCAL_STRINGS = 50
local STRING_RC_LIMIT = 3















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

   local function is_dot(ps, k)
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


   local function calc_rc(ps, obj)
      if type(obj) == "table" then
         if ps.table_rc[obj] then
            ps.table_rc[obj] = ps.table_rc[obj] + 1
            return
         end
         ps.table_rc[obj] = 1

         for k, v in pairs(obj) do
            if type(k) == "string" then
               calc_rc(ps, k)
            end
            if type(v) == "table" or type(v) == "string" then
               calc_rc(ps, v)
            end
         end
      elseif type(obj) == "string" then
         if ps.string_rc[obj] then
            ps.string_rc[obj] = ps.string_rc[obj] + 1
            return
         end
         ps.string_rc[obj] = 1
      end
   end



   local function should_inline_string(ps, k)
      return #k < SHORT_NAME or ps.string_rc[k] < STRING_RC_LIMIT
   end



   local function load_top_strings(ps)
      local strings = {}
      for k, _ in pairs(ps.string_rc) do
         if not should_inline_string(ps, k) then
            table.insert(strings, k)
         end
      end
      table.sort(strings, function(a, b)
         if ps.string_rc[a] == ps.string_rc[b] then
            return a > b
         end
         return ps.string_rc[a] > ps.string_rc[b]
      end)
      for i = #strings, N_LOCAL_STRINGS + 1, -1 do
         table.remove(strings, i)
      end
      for i, s in ipairs(strings) do
         ps.string_map[s] = i
      end
      ps.string_arr = strings
      ps.string_ctr = #strings
   end



   local function get_string(ps, k)
      if should_inline_string(ps, k) then
         return string.format("%q", k)
      end

      local n = ps.string_map[k]
      if not n then
         n = ps.string_ctr + 1
         ps.string_arr[n] = k
         ps.string_map[k] = n
         ps.string_ctr = n
      end
      if n <= N_LOCAL_STRINGS then
         return "K" .. tostring(n)
      else
         return "K[" .. tostring(n - N_LOCAL_STRINGS) .. "]"
      end
   end

   local recurse


   local function put_k_v(ps, out, k, v, do_dot)
      local val
      if type(v) == "table" then
         val = recurse(ps, v)
      elseif type(v) == "string" then
         val = get_string(ps, v)
      else
         val = tostring(v)
      end
      if type(k) == "string" and #k < SHORT_NAME and is_dot(ps, k) then
         if do_dot then
            put(out, ".")
         end
         put(out, k)
      else
         put(out, "[")
         if type(k) == "string" then
            put(out, get_string(ps, k))
         else
            put(out, tostring(k))
         end
         put(out, "]")
      end
      put(out, "=")
      put(out, val)
   end

   local function print_table_to(out, tbl, ps, do_subtables)
      put(out, "{")
      local any_subtable = false
      for k, v in sortedpairs(tbl) do
         if (type(v) == "table") and (not do_subtables) then
            any_subtable = true
         else
            put_k_v(ps, out, k, v, false)
            put(out, ",")
         end
      end
      put(out, "}")
      return any_subtable
   end

   recurse = function(ps, tbl)
      if ps.table_map[tbl] then
         return "T" .. tostring(ps.table_map[tbl])
      end

      if ps.table_rc[tbl] == 1 then
         local imm = {}
         print_table_to(imm, tbl, ps, true)
         return table.concat(imm)
      end

      ps.table_ctr = ps.table_ctr + 1
      local n = ps.table_ctr
      local name = "T" .. tostring(n)
      ps.table_map[tbl] = n

      local inits = {}
      local any_subtable = false
      put(inits, "local ")
      put(inits, name)
      put(inits, " = ")
      any_subtable = print_table_to(inits, tbl, ps, false)
      put(inits, "\n")
      ps.table_inits[n] = inits

      if any_subtable then
         local subtables = {}
         for k, v in sortedpairs(tbl) do
            if type(v) == "table" then
               put(subtables, name)
               put_k_v(ps, subtables, k, v, true)
               put(subtables, "\n")
            end
         end
         ps.table_subtables[n] = subtables
      end

      return name
   end

   local function flush_vars_vals(out, vars, vals, top)
      if #vals == 0 then
         return
      end
      if top then
         put(out, "local ")
         put(out, table.concat(vars, ","))
         put(out, "=")
         put(out, table.concat(vals, ","))
         put(out, "\n")
      else
         put(out, "local K={")
         put(out, table.concat(vals, ","))
         put(out, "}\n")
      end
   end

   persist = function(tbl)
      local ps = {
         table_ctr = 0,
         table_map = {},
         table_inits = {},
         table_subtables = {},
         table_rc = {},
         dot = {},
         string_ctr = 0,
         string_map = {},
         string_arr = {},
         string_rc = {},
      }
      calc_rc(ps, tbl)
      load_top_strings(ps)

      local t = recurse(ps, tbl)

      local out = {}
      local vars, vals = {}, {}
      local top = true
      for i, k in ipairs(ps.string_arr) do
         if top and i > N_LOCAL_STRINGS then
            flush_vars_vals(out, vars, vals, top)
            vars, vals = {}, {}
            top = false
         end
         table.insert(vals, format("%q", k))
         if top then
            table.insert(vars, "K" .. tostring(i))
            if i % 10 == 0 then
               flush_vars_vals(out, vars, vals, top)
               vars, vals = {}, {}
            end
         end
      end
      flush_vars_vals(out, vars, vals, top)

      for _, cs in ipairs(ps.table_inits) do
         for _, c in ipairs(cs) do
            table.insert(out, c)
         end
      end
      table.insert(out, "local T0 = ")
      table.insert(out, t)
      table.insert(out, "\n")
      for i = 1, #ps.table_inits do
         local cs = ps.table_subtables[i]
         if cs then
            for _, c in ipairs(cs) do
               table.insert(out, c)
            end
         end
      end
      return out
   end
end

local out = persist(env.globals)

put(out, "\nreturn { globals = T0, typeid_ctr = ")
put(out, tostring(typeid_ctr))
put(out, ", typevar_ctr = ")
put(out, tostring(typevar_ctr))
put(out, "}\n")

print(table.concat(out))
