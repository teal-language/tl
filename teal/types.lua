local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG











local types = { GenericType = {}, StringType = {}, IntegerType = {}, BooleanType = {}, BooleanContextType = {}, TypeDeclType = {}, LiteralTableItemType = {}, NominalType = {}, SelfType = {}, ArrayType = {}, RecordType = {}, InterfaceType = {}, InvalidType = {}, UnknownType = {}, TupleType = {}, UnresolvedTypeArgType = {}, UnresolvableTypeArgType = {}, TypeVarType = {}, MapType = {}, NilType = {}, EmptyTableType = {}, UnresolvedEmptyTableValueType = {}, FunctionType = {}, UnionType = {}, TupleTableType = {}, PolyType = {}, EnumType = {} }


























































































































































































































































































































































































function is_numeric_type(t)
   return t.typename == "number" or t.typename == "integer"
end

types.lua_primitives = {
   ["function"] = "function",
   ["enum"] = "string",
   ["boolean"] = "boolean",
   ["string"] = "string",
   ["nil"] = "nil",
   ["number"] = "number",
   ["integer"] = "number",
   ["thread"] = "thread",
}

local simple_types = {
   ["nil"] = true,
   ["any"] = true,
   ["number"] = true,
   ["string"] = true,
   ["thread"] = true,
   ["boolean"] = true,
   ["integer"] = true,
   ["self"] = true,
}


local no_nested_types = {
   ["string"] = true,
   ["number"] = true,
   ["integer"] = true,
   ["boolean"] = true,
   ["thread"] = true,
   ["any"] = true,
   ["enum"] = true,
   ["nil"] = true,
   ["unknown"] = true,
}

local table_types = {
   ["array"] = true,
   ["map"] = true,
   ["record"] = true,
   ["interface"] = true,
   ["self"] = true,
   ["emptytable"] = true,
   ["tupletable"] = true,

   ["generic"] = false,
   ["typedecl"] = false,
   ["typevar"] = false,
   ["typearg"] = false,
   ["function"] = false,
   ["enum"] = false,
   ["boolean"] = false,
   ["string"] = false,
   ["nil"] = false,
   ["thread"] = false,
   ["userdata"] = false,
   ["number"] = false,
   ["integer"] = false,
   ["union"] = false,
   ["nominal"] = false,
   ["literal_table_item"] = false,
   ["unresolved_emptytable_value"] = false,
   ["unresolved_typearg"] = false,
   ["unresolvable_typearg"] = false,
   ["circular_require"] = false,
   ["boolean_context"] = false,
   ["tuple"] = false,
   ["poly"] = false,
   ["any"] = false,
   ["unknown"] = false,
   ["invalid"] = false,
   ["none"] = false,
   ["*"] = false,
}

local show_type

local function is_unknown(t)
   return t.typename == "unknown" or
   t.typename == "unresolved_emptytable_value"
end

local function show_typevar(typevar, what)
   return TL_DEBUG and
   (what .. " " .. typevar) or
   typevar:gsub("@.*", "")
end

local function show_fields(t, show)
   if t.declname then
      return " " .. t.declname
   end

   local out = {}
   table.insert(out, " (")
   if t.elements then
      table.insert(out, "{" .. show(t.elements) .. "}")
   end
   local fs = {}
   for _, k in ipairs(t.field_order) do
      local v = t.fields[k]
      table.insert(fs, k .. ": " .. show(v))
   end
   table.insert(out, table.concat(fs, "; "))
   table.insert(out, ")")
   return table.concat(out)
end

local function show_type_base(t, short, seen)

   if seen[t] then
      return seen[t]
   end
   seen[t] = "..."

   local function show(typ)
      return show_type(typ, short, seen)
   end

   if t.typename == "nominal" then
      local ret
      if t.typevals then
         local out = { table.concat(t.names, "."), "<" }
         local vals = {}
         for _, v in ipairs(t.typevals) do
            table.insert(vals, show(v))
         end
         table.insert(out, table.concat(vals, ", "))
         table.insert(out, ">")
         ret = table.concat(out)
      else
         ret = table.concat(t.names, ".")
      end
      if TL_DEBUG then
         ret = "nominal " .. ret
      end
      return ret
   elseif t.typename == "self" then
      if t.display_type then
         local ret = show_type_base(t.display_type, short, seen)
         if TL_DEBUG then
            ret = "self " .. ret
         end
         return ret
      end
      return "self"
   elseif t.typename == "tuple" then
      local out = {}
      for _, v in ipairs(t.tuple) do
         table.insert(out, show(v))
      end
      local list = table.concat(out, ", ")
      if t.is_va then
         list = list .. "..."
      end
      if short then
         return list
      end
      return "(" .. list .. ")"
   elseif t.typename == "tupletable" then
      local out = {}
      for _, v in ipairs(t.types) do
         table.insert(out, show(v))
      end
      return "{" .. table.concat(out, ", ") .. "}"
   elseif t.typename == "poly" then
      local out = {}
      for _, v in ipairs(t.types) do
         table.insert(out, show(v))
      end
      return "polymorphic function (with types " .. table.concat(out, " and ") .. ")"
   elseif t.typename == "union" then
      local out = {}
      for _, v in ipairs(t.types) do
         table.insert(out, show(v))
      end
      return table.concat(out, " | ")
   elseif t.typename == "emptytable" then
      return "{}"
   elseif t.typename == "map" then
      return "{" .. show(t.keys) .. " : " .. show(t.values) .. "}"
   elseif t.typename == "array" then
      return "{" .. show(t.elements) .. "}"
   elseif t.typename == "enum" then
      return t.declname or "enum"
   elseif t.fields then
      return short and (t.declname or t.typename) or t.typename .. show_fields(t, show)
   elseif t.typename == "function" then
      local out = { "function(" }
      local args = {}
      for i, v in ipairs(t.args.tuple) do
         table.insert(args, ((i == #t.args.tuple and t.args.is_va) and "...: " or
         (i > t.min_arity) and "? " or
         "") .. show(v))
      end
      table.insert(out, table.concat(args, ", "))
      table.insert(out, ")")
      if t.rets.tuple and #t.rets.tuple > 0 then
         table.insert(out, ": ")
         local rets = {}
         if #t.rets.tuple > 1 then
            table.insert(out, "(")
         end
         for i, v in ipairs(t.rets.tuple) do
            table.insert(rets, show(v) .. (i == #t.rets.tuple and t.rets.is_va and "..." or ""))
         end
         table.insert(out, table.concat(rets, ", "))
         if #t.rets.tuple > 1 then
            table.insert(out, ")")
         end
      end
      return table.concat(out)
   elseif t.typename == "generic" then
      local out = {}
      local name, rest
      local tt = t.t
      if tt.typename == "record" or tt.typename == "interface" or tt.typename == "function" then
         name, rest = show(tt):match("^(%a+)(.*)")
         table.insert(out, name)
      else
         rest = " " .. show(tt)
         table.insert(out, "generic")
      end
      table.insert(out, "<")
      local typeargs = {}
      for _, v in ipairs(t.typeargs) do
         table.insert(typeargs, show(v))
      end
      table.insert(out, table.concat(typeargs, ", "))
      table.insert(out, ">")
      table.insert(out, rest)
      return table.concat(out)
   elseif t.typename == "number" or
      t.typename == "integer" or
      t.typename == "boolean" or
      t.typename == "thread" then
      return t.typename
   elseif t.typename == "string" then
      if short then
         return "string"
      else
         return t.typename ..
         (t.literal and string.format(" %q", t.literal) or "")
      end
   elseif t.typename == "typevar" then
      return show_typevar(t.typevar, "typevar")
   elseif t.typename == "typearg" then
      local out = show_typevar(t.typearg, "typearg")
      if t.constraint then
         out = out .. " is " .. show(t.constraint)
      end
      return out
   elseif t.typename == "unresolvable_typearg" then
      return show_typevar(t.typearg, "typearg") .. " (unresolved generic)"
   elseif is_unknown(t) then
      return "<unknown type>"
   elseif t.typename == "invalid" then
      return "<invalid type>"
   elseif t.typename == "any" then
      return "<any type>"
   elseif t.typename == "nil" then
      return "nil"
   elseif t.typename == "boolean_context" then
      return "boolean"
   elseif t.typename == "none" then
      return ""
   elseif t.typename == "typedecl" then
      return (t.is_alias and "type alias to " or "type ") .. show(t.def)
   else
      return "<" .. t.typename .. ">"
   end
end

local function inferred_msg(t, prefix)
   return " (" .. (prefix or "") .. "inferred at " .. t.inferred_at.f .. ":" .. t.inferred_at.y .. ":" .. t.inferred_at.x .. ")"
end

show_type = function(t, short, seen)
   seen = seen or {}
   if seen[t] then
      return seen[t]
   end
   local ret = show_type_base(t, short, seen)
   if t.inferred_at then
      ret = ret .. inferred_msg(t)
   end
   seen[t] = ret
   return ret
end

local type_mt = {
   __tostring = function(t)
      return show_type(t)
   end,
}


local fresh_typevar_ctr = 1
local fresh_typeid_ctr = 0

local function new_typeid()
   fresh_typeid_ctr = fresh_typeid_ctr + 1
   return fresh_typeid_ctr
end

local function a_type(w, typename, t)
   t.typeid = new_typeid()
   t.f = w.f
   t.x = w.x
   t.y = w.y
   t.typename = typename
   do
      local ty = t
      setmetatable(ty, type_mt)
   end
   return t
end

local function a_function(w, t)
   assert(t.min_arity)
   return a_type(w, "function", t)
end





local function a_vararg(w, t)
   local typ = a_type(w, "tuple", { tuple = t })
   typ.is_va = true
   return typ
end

local function raw_type(f, y, x, typename)
   local t = setmetatable({}, type_mt)
   t.typeid = new_typeid()
   t.f = f
   t.x = x
   t.y = y
   t.typename = typename
   return t
end

local function shallow_copy_new_type(t)
   local copy = {}
   for k, v in pairs(t) do
      copy[k] = v
   end
   copy.typeid = new_typeid()
   do
      local ty = copy
      setmetatable(ty, type_mt)
   end
   return copy
end

local function edit_type(w, t, typename)
   t.typeid = new_typeid()
   t.f = w.f
   t.x = w.x
   t.y = w.y
   t.typename = typename
   setmetatable(t, type_mt)
   return t
end

local function type_for_union(t)
   if t.typename == "typedecl" then
      return type_for_union(t.def)
   elseif t.typename == "tuple" then
      return type_for_union(t.tuple[1]), t.tuple[1]
   elseif t.typename == "nominal" then
      local typedecl = t.found
      if not typedecl then
         return "invalid"
      end
      return type_for_union(typedecl)
   elseif t.fields then
      if t.is_userdata then
         return "userdata", t
      end
      return "table", t
   elseif t.typename == "generic" then
      return type_for_union(t.t)
   elseif table_types[t.typename] then
      return "table", t
   else
      return t.typename, t
   end
end

function types.is_valid_union(typ)


   local n_table_types = 0
   local n_table_is_types = 0
   local n_function_types = 0
   local n_userdata_types = 0
   local n_userdata_is_types = 0
   local n_string_enum = 0
   local has_primitive_string_type = false
   for _, t in ipairs(typ.types) do
      local ut, rt = type_for_union(t)
      if ut == "userdata" then
         assert(rt.fields)
         if rt.meta_fields and rt.meta_fields["__is"] then
            n_userdata_is_types = n_userdata_is_types + 1
            if n_userdata_types > 0 then
               return false, "cannot mix userdata types with and without __is metamethod: %s"
            end
         else
            n_userdata_types = n_userdata_types + 1
            if n_userdata_types > 1 then
               return false, "cannot discriminate a union between multiple userdata types: %s"
            end
            if n_userdata_is_types > 0 then
               return false, "cannot mix userdata types with and without __is metamethod: %s"
            end
         end
      elseif ut == "table" then
         if rt.fields and rt.meta_fields and rt.meta_fields["__is"] then
            n_table_is_types = n_table_is_types + 1
            if n_table_types > 0 then
               return false, "cannot mix table types with and without __is metamethod: %s"
            end
         else
            n_table_types = n_table_types + 1
            if n_table_types > 1 then
               return false, "cannot discriminate a union between multiple table types: %s"
            end
            if n_table_is_types > 0 then
               return false, "cannot mix table types with and without __is metamethod: %s"
            end
         end
      elseif ut == "function" then
         n_function_types = n_function_types + 1
         if n_function_types > 1 then
            return false, "cannot discriminate a union between multiple function types: %s"
         end
      elseif ut == "enum" or (ut == "string" and not has_primitive_string_type) then
         n_string_enum = n_string_enum + 1
         if n_string_enum > 1 then
            return false, "cannot discriminate a union between multiple string/enum types: %s"
         end
         if ut == "string" then
            has_primitive_string_type = true
         end
      elseif ut == "invalid" then
         return false, nil
      end
   end
   return true
end

function types.error(msg, t1, t2, t3)
   local s1, s2, s3
   if t1.typename == "invalid" then
      return nil
   end
   s1 = show_type(t1)
   if t2 then
      if t2.typename == "invalid" then
         return nil
      end
      s2 = show_type(t2)
   end
   if t3 then
      if t3.typename == "invalid" then
         return nil
      end
      s3 = show_type(t3)
   end
   msg = msg:format(s1, s2, s3)
   return {
      msg = msg,
      x = t1.x,
      y = t1.y,
      filename = t1.f,
   }
end

types.map = function(self, ty, fns)
   local errs
   local seen = {}
   local resolve

   resolve = function(t, all_same)
      local same = true


      if no_nested_types[t.typename] or (t.typename == "nominal" and not t.typevals) then
         return t, all_same
      end

      if seen[t] then
         return seen[t], all_same
      end

      local orig_t = t
      local fn = fns[t.typename]
      if fn then
         local rt, is_resolved = fn(self, t, resolve)
         if rt ~= t then
            if is_resolved then
               seen[t] = rt
               return rt, false
            end
            return resolve(rt, false)
         end
      end

      local copy = {}
      seen[orig_t] = copy

      setmetatable(copy, type_mt)
      copy.typename = t.typename
      copy.f = t.f
      copy.x = t.x
      copy.y = t.y

      if t.typename == "generic" then
         assert(copy.typename == "generic")

         local ct = {}
         for i, tf in ipairs(t.typeargs) do
            ct[i], same = resolve(tf, same)
         end
         copy.typeargs = ct
         copy.t, same = resolve(t.t, same)
      elseif t.typename == "array" then
         assert(copy.typename == "array")

         copy.elements, same = resolve(t.elements, same)

      elseif t.typename == "typearg" then
         assert(copy.typename == "typearg")
         copy.typearg = t.typearg
         if t.constraint then
            copy.constraint, same = resolve(t.constraint, same)
         end
      elseif t.typename == "unresolvable_typearg" then
         assert(copy.typename == "unresolvable_typearg")
         copy.typearg = t.typearg
      elseif t.typename == "unresolved_emptytable_value" then
         assert(copy.typename == "unresolved_emptytable_value")
         copy.emptytable_type = t.emptytable_type
      elseif t.typename == "typevar" then
         assert(copy.typename == "typevar")
         copy.typevar = t.typevar
         if t.constraint then
            copy.constraint, same = resolve(t.constraint, same)
         end
      elseif t.typename == "typedecl" then
         assert(copy.typename == "typedecl")
         copy.def, same = resolve(t.def, same)
         copy.is_alias = t.is_alias
         copy.is_nested_alias = t.is_nested_alias
      elseif t.typename == "nominal" then
         assert(copy.typename == "nominal")
         copy.names = t.names
         copy.typevals = {}
         for i, tf in ipairs(t.typevals) do
            copy.typevals[i], same = resolve(tf, same)
         end
         copy.found = t.found
      elseif t.typename == "function" then
         assert(copy.typename == "function")
         copy.macroexp = t.macroexp
         copy.min_arity = t.min_arity
         copy.is_method = t.is_method
         copy.is_record_function = t.is_record_function
         copy.args, same = resolve(t.args, same)
         copy.rets, same = resolve(t.rets, same)
         copy.special_function_handler = t.special_function_handler
      elseif t.fields then
         assert(copy.typename == "record" or copy.typename == "interface")
         copy.declname = t.declname


         if t.elements then
            copy.elements, same = resolve(t.elements, same)
         end

         if t.interface_list then
            copy.interface_list = {}
            for i, v in ipairs(t.interface_list) do
               copy.interface_list[i], same = resolve(v, same)
            end
         end

         copy.is_userdata = t.is_userdata

         copy.fields = {}
         copy.field_order = {}
         for i, k in ipairs(t.field_order) do
            copy.field_order[i] = k
            copy.fields[k], same = resolve(t.fields[k], same)
         end

         if t.meta_fields then
            copy.meta_fields = {}
            copy.meta_field_order = {}
            for i, k in ipairs(t.meta_field_order) do
               copy.meta_field_order[i] = k
               copy.meta_fields[k], same = resolve(t.meta_fields[k], same)
            end
         end
      elseif t.typename == "map" then
         assert(copy.typename == "map")
         copy.keys, same = resolve(t.keys, same)
         copy.values, same = resolve(t.values, same)
      elseif t.typename == "union" then
         assert(copy.typename == "union")
         copy.types = {}
         for i, tf in ipairs(t.types) do
            copy.types[i], same = resolve(tf, same)
         end

         local _, err = types.is_valid_union(copy)
         if err then
            errs = errs or {}
            table.insert(errs, types.error(err, copy))
         end
      elseif t.typename == "poly" then
         assert(copy.typename == "poly")
         copy.types = {}
         for i, tf in ipairs(t.types) do
            copy.types[i], same = resolve(tf, same)
         end
      elseif t.typename == "tupletable" then
         assert(copy.typename == "tupletable")
         copy.inferred_at = t.inferred_at
         copy.types = {}
         for i, tf in ipairs(t.types) do
            copy.types[i], same = resolve(tf, same)
         end
      elseif t.typename == "tuple" then
         assert(copy.typename == "tuple")
         copy.is_va = t.is_va
         copy.tuple = {}
         for i, tf in ipairs(t.tuple) do
            copy.tuple[i], same = resolve(tf, same)
         end
      elseif t.typename == "self" then
         assert(copy.typename == "self")
         if t.display_type ~= nil then
            copy.display_type, same = resolve(t.display_type, same)
         end
      end

      copy.typeid = same and t.typeid or new_typeid()
      return copy, same and all_same
   end

   local copy = resolve(ty, true)
   if errs then
      return a_type(ty, "invalid", {}), errs
   end

   return copy
end

do
   function types.internal_typevar_ctr()
      return fresh_typevar_ctr
   end


   local fresh_typevar_fns = {
      ["typevar"] = function(typeargs, t, resolve)
         for _, ta in ipairs(typeargs) do
            if ta.typearg == t.typevar then
               return a_type(t, "typevar", {
                  typevar = (t.typevar:gsub("@.*", "")) .. "@" .. fresh_typevar_ctr,
                  constraint = t.constraint and resolve(t.constraint, false),
               }), true
            end
         end
         return t, false
      end,
      ["typearg"] = function(typeargs, t, resolve)
         for _, ta in ipairs(typeargs) do
            if ta.typearg == t.typearg then
               return a_type(t, "typearg", {
                  typearg = (t.typearg:gsub("@.*", "")) .. "@" .. fresh_typevar_ctr,
                  constraint = t.constraint and resolve(t.constraint, false),
               }), true
            end
         end
         return t, false
      end,
   }

   function types.fresh_typeargs(g)
      fresh_typevar_ctr = fresh_typevar_ctr + 1

      local newg, errs = types.map(g.typeargs, g, fresh_typevar_fns)
      if newg.typename == "invalid" then
         return newg, errs
      end

      assert(newg.typename == "generic", "Internal Compiler Error: error creating fresh type variables")
      assert(newg ~= g)
      newg.fresh = true

      return newg
   end
end







function types.untuple(t)
   local rt = t
   if rt.typename == "tuple" then
      rt = rt.tuple[1]
   end
   if rt == nil then
      return a_type(t, "nil", {})
   end
   return rt
end

function types.unite(w, typs, flatten_constants)
   if #typs == 1 then
      return typs[1]
   end

   local ts = {}
   local stack = {}


   local types_seen = {}

   types_seen["nil"] = true

   local i = 1
   while typs[i] or stack[1] do
      local t
      if stack[1] then
         t = table.remove(stack)
      else
         t = typs[i]
         i = i + 1
      end
      t = types.untuple(t)
      if t.typename == "union" then
         for _, s in ipairs(t.types) do
            table.insert(stack, s)
         end
      else
         if types.lua_primitives[t.typename] and (flatten_constants or (t.typename == "string" and not t.literal)) then
            if not types_seen[t.typename] then
               types_seen[t.typename] = true
               table.insert(ts, t)
            end
         else
            local typeid = t.typeid
            if t.typename == "nominal" and t.found then
               typeid = t.found.typeid
            end
            if not types_seen[typeid] then
               types_seen[typeid] = true
               table.insert(ts, t)
            end
         end
      end
   end

   if types_seen["invalid"] then
      return a_type(w, "invalid", {})
   end

   if #ts == 1 then
      return ts[1]
   else
      return a_type(w, "union", { types = ts })
   end
end

function types.resolve_for_special_function(t)
   if t.typename == "poly" then
      t = t.types[1]
   end
   if t.typename == "generic" then
      t = t.t
   end
   if t.typename == "function" then
      return t
   end
end

function types.drop_constant_value(t)
   if t.typename == "string" and t.literal then
      local ret = shallow_copy_new_type(t)
      ret.literal = nil
      return ret
   elseif t.needs_compat then
      local ret = shallow_copy_new_type(t)
      ret.needs_compat = nil
      return ret
   end
   return t
end

function types.type_at(w, t)
   t.x = w.x
   t.y = w.y
   return t
end

function types.wrap_generic_if_typeargs(typeargs, t)
   if not typeargs then
      return t
   end

   assert(not (t.typename == "typedecl"))

   local gt = a_type(t, "generic", { t = t })
   gt.typeargs = typeargs
   return gt
end

function types.show_arity(f)
   local nfargs = #f.args.tuple
   if f.min_arity < nfargs then
      if f.min_arity > 0 then
         return "at least " .. f.min_arity .. (f.args.is_va and "" or " and at most " .. nfargs)
      else
         return (f.args.is_va and "any number" or "at most " .. nfargs)
      end
   else
      return tostring(nfargs or 0)
   end
end

function types.typedecl_to_nominal(w, name, t, resolved)
   local typevals
   local def = t.def
   if def.typename == "generic" then
      typevals = {}
      for _, a in ipairs(def.typeargs) do
         table.insert(typevals, a_type(a, "typevar", {
            typevar = a.typearg,
            constraint = a.constraint,
         }))
      end
   end
   local nom = a_type(w, "nominal", { names = { name } })
   nom.typevals = typevals
   nom.found = t
   nom.resolved = resolved
   return nom
end

local function ensure_not_method(t)
   if t.typename == "generic" then
      local tt = ensure_not_method(t.t)
      if tt ~= t.t then
         local gg = shallow_copy_new_type(t)
         gg.t = tt
         return gg
      end
   end

   if t.typename == "function" and t.is_method then
      t = shallow_copy_new_type(t);
      (t).is_method = false
   end
   return t
end

function types.internal_get_state()
   return fresh_typeid_ctr, fresh_typevar_ctr
end

function types.internal_force_state(typeid_ctr, typevar_ctr)
   fresh_typeid_ctr = typeid_ctr
   fresh_typevar_ctr = typevar_ctr
end

types.globals_typeid = new_typeid()
types.simple_types = simple_types
types.table_types = table_types
types.a_type = a_type
types.a_function = a_function
types.a_vararg = a_vararg
types.edit_type = edit_type
types.ensure_not_method = ensure_not_method
types.is_unknown = is_unknown
types.inferred_msg = inferred_msg
types.raw_type = raw_type
types.shallow_copy_new_type = shallow_copy_new_type
types.show_type = show_type
types.show_typevar = show_typevar
types.show_type_base = show_type_base

return types
