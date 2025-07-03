#!/usr/bin/env -S tl run

package.path = "./?.lua;" .. package.path

local environment = require("teal.environment")
environment.set_require_module_fn(require("teal.check.require_file").require_module)
local env = environment.construct()
local types = require("teal.types")
local typeid_ctr, typevar_ctr = types.internal_get_state()

local put = table.insert
local format = string.format

local SHORT_NAME <const> = 5
local N_LOCAL_STRINGS <const> = 50
local STRING_RC_LIMIT <const> = 3

local record PersistState
   table_ctr: integer
   table_map: {any: integer}
   table_inits: {{string}}
   table_subtables: {{string}}
   table_rc: {any: integer}
   string_ctr: integer
   string_map: {string: integer}
   string_arr: {string}
   string_rc: {string: integer}
   string_ks: integer
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
   -- Can a string key be used in a table with dot notation?
   local function is_dot(ps: PersistState, k: string): boolean
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

   -- Calculate reference counts for strings and tables
   local function calc_rc(ps: PersistState, obj: any)
      if obj is table then
         if ps.table_rc[obj] then
            ps.table_rc[obj] = ps.table_rc[obj] + 1
            return
         end
         ps.table_rc[obj] = 1

         for k, v in pairs(obj) do
            if k is string then
               calc_rc(ps, k)
            end
            if v is table or v is string then
               calc_rc(ps, v)
            end
         end
      elseif obj is string then
         if ps.string_rc[obj] then
            ps.string_rc[obj] = ps.string_rc[obj] + 1
            return
         end
         ps.string_rc[obj] = 1
      end
   end

   -- Determine if string should be used inline:
   -- if it is too short or not reused enough.
   local function should_inline_string(ps: PersistState, k: string): boolean
      return #k < SHORT_NAME or ps.string_rc[k] < STRING_RC_LIMIT
   end

   -- Pre-load the top `N_LOCAL_STRINGS` most used strings
   -- to be referenced as local variables.
   local function load_top_strings(ps: PersistState): integer
      local strings = {}
      for k, _ in pairs(ps.string_rc) do
         if not should_inline_string(ps, k) then
            table.insert(strings, k)
         end
      end
      table.sort(strings, function(a: string, b: string): boolean
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

   -- Get the proper representation for a string: inlined,
   -- as a local variable or as a table key.
   local function get_string(ps: PersistState, k: string): string
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

   local recurse: function(ps: PersistState, tbl: {any:any}): string

   -- Emit a key-value assignment.
   local function put_k_v(ps: PersistState, out: {string}, k: any, v: any, do_dot: boolean)
      local val: string
      if v is table then
         val = recurse(ps, v)
      elseif v is string then
         val = get_string(ps, v)
      else
         val = tostring(v)
      end
      if k is string and #k < SHORT_NAME and is_dot(ps, k) then
         if do_dot then
            put(out, ".")
         end
         put(out, k)
      else
         put(out, "[")
         if k is string then
            put(out, get_string(ps, k))
         else
            put(out, tostring(k))
         end
         put(out, "]")
      end
      put(out, "=")
      put(out, val)
   end

   local function print_table_to(out: {string}, tbl: {any:any}, ps: PersistState, do_subtables: boolean): boolean
      put(out, "{")
      local any_subtable = false
      for k, v in sortedpairs(tbl) do
         if (v is table) and (not do_subtables) then
            any_subtable = true
         else
            put_k_v(ps, out, k, v, false)
            put(out, ",")
         end
      end
      put(out, "}")
      return any_subtable
   end

   recurse = function(ps: PersistState, tbl: {any:any}): string
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
            if v is table then
               put(subtables, name)
               put_k_v(ps, subtables, k, v, true)
               put(subtables, "\n")
            end
         end
         ps.table_subtables[n] = subtables
      end

      return name
   end

   local function flush_vars_vals(out: {string}, vars: {string}, vals: {string}, top: boolean)
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

   persist = function(tbl: {any:any}): {string}
      local ps: PersistState = {
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

local out = persist(env.globals as {any:any})

put(out, "\nreturn { globals = T0, typeid_ctr = ")
put(out, tostring(typeid_ctr))
put(out, ", typevar_ctr = ")
put(out, tostring(typevar_ctr))
put(out, "}\n")

print(table.concat(out))
