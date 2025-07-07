local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type











local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG





local errors = require("teal.errors")




local facts = require("teal.facts")

local FactDatabase = facts.FactDatabase
local eval_fact = facts.eval_fact
local facts_and = facts.facts_and
local facts_not = facts.facts_not

local macroexps = require("teal.macroexps")

local types = require("teal.types")


































local a_type = types.a_type
local a_function = types.a_function
local a_vararg = types.a_vararg
local drop_constant_value = types.drop_constant_value
local ensure_not_method = types.ensure_not_method
local is_unknown = types.is_unknown
local is_valid_union = types.is_valid_union
local shallow_copy_new_type = types.shallow_copy_new_type
local show_type_base = types.show_type_base
local simple_types = types.simple_types
local unite = types.unite
local untuple = types.untuple
local type_at = types.type_at
local typedecl_to_nominal = types.typedecl_to_nominal
local wrap_generic_if_typeargs = types.wrap_generic_if_typeargs

local parser = require("teal.parser")


local node_is_funcall = parser.node_is_funcall

local relations = require("teal.check.relations")

local special_functions = require("teal.check.special_functions")

local traversal = require("teal.traversal")


local traverse_nodes = traversal.traverse_nodes
local fields_of = traversal.fields_of

local type_reporter = require("teal.type_reporter")


local type_errors = require("teal.type_errors")
local Errors = type_errors.Errors
local ensure_not_abstract = type_errors.ensure_not_abstract

local util = require("teal.util")
local sorted_keys = util.sorted_keys
local shallow_copy_table = util.shallow_copy_table

local variables = require("teal.variables")



local has_var_been_used = variables.has_var_been_used

























local context = { Context = {} }

































local Context = context.Context



function Context:add_error(w, msg, t, ...)
   self.errs:add(w, msg, t, ...)
end

function Context:invalid_at(w, msg, ...)
   return self.errs:invalid_at(w, msg, ...)
end

function Context:add_errors_prefixing(w, src, prefix, dst)
   self.errs:add_prefixing(w, src, prefix, dst)
end

function Context:add_warning(tag, w, fmt, ...)
   self.errs:add_warning(tag, w, fmt, ...)
end

do
   local function get_real_var_from_lower_scope(st, i, name)
      for j = i - 1, 1, -1 do
         local scope = st[j]
         local sv = scope.vars[name]
         if sv and ((not sv.is_specialized) or (sv.specialized_from)) then
            return sv
         end
      end
   end

   function Context:find_var(name, use)
      for i = #self.st, 1, -1 do
         local scope = self.st[i]
         local var = scope.vars[name]
         if var then
            if use == "lvalue" and var.is_specialized and var.is_specialized ~= "localizing" then
               if var.specialized_from then
                  var.has_been_written_to = true
                  return { t = var.specialized_from, attribute = var.attribute }, i, var.attribute
               end
            else
               if i == 1 and var.needs_compat then
                  self.needs_compat[name] = true
               end

               local real_var = var
               if var.is_specialized and var.is_specialized ~= "localizing" then
                  real_var = get_real_var_from_lower_scope(self.st, i, name) or real_var
               end
               if use == "use_type" then

                  real_var.used_as_type = true
               elseif use ~= "check_only" then
                  if use == "lvalue" then

                     real_var.has_been_written_to = true
                  else

                     real_var.has_been_read_from = true
                  end
               end

               return var, i, var.attribute
            end
         end
      end
   end
end

function Context:simulate_g()

   local globals = {}
   for k, v in pairs(self.st[1].vars) do
      if k:sub(1, 1) ~= "@" then
         globals[k] = v.t
      end
   end
   return {
      typeid = types.globals_typeid,
      typename = "record",
      field_order = sorted_keys(globals),
      fields = globals,
   }, nil
end

do
   local function unwrap_for_find_type(typ)
      if typ.typename == "nominal" and typ.found then
         return unwrap_for_find_type(typ.found)
      elseif typ.typename == "typedecl" then
         return unwrap_for_find_type(typ.def)
      elseif typ.typename == "generic" then
         return unwrap_for_find_type(typ.t)
      end
      return typ
   end

   function Context:find_type(names)
      local typ = self:find_var_type(names[1], "use_type")
      if not typ then
         if #names == 1 and names[1] == "metatable" then
            return self:find_type({ "_metatable" })
         end
         return nil
      end
      for i = 2, #names do
         typ = unwrap_for_find_type(typ)
         if typ == nil then
            return nil
         end

         local fields = typ.fields and typ.fields
         if not fields then
            return nil
         end

         typ = fields[names[i]]
         if typ == nil then
            return nil
         end
      end


      if typ and typ.typename == "nominal" then
         typ = typ.found
      end
      if typ == nil then
         return nil
      end

      if typ.typename == "typedecl" then
         return typ
      elseif typ.typename == "typearg" then
         return nil, typ
      end
   end
end

function Context:assert_resolved_typevars_at(w, t)
   local ret, errs = self:resolve_typevars(t)
   if errs then
      assert(w.y)
      self.errs:add_prefixing(w, errs, "")
   end


   if ret.typeid ~= t.typeid then
      return self:assert_resolved_typevars_at(w, ret)
   end

   if ret == t or t.typename == "typevar" then
      ret = shallow_copy_new_type(ret)
   end
   return type_at(w, ret)
end

function Context:infer_at(w, t)
   local ret = self:assert_resolved_typevars_at(w, t)
   if ret.typename == "invalid" then
      ret = t
   end

   if ret == t or t.typename == "typevar" then
      ret = shallow_copy_new_type(ret)
   end
   assert(w.f)
   ret.inferred_at = w
   return ret
end

function Context:infer_emptytable(emptytable, fresh_t)
   local nst = emptytable.is_global and 1 or #self.st
   for i = nst, 1, -1 do
      local scope = self.st[i]
      if scope.vars[emptytable.assigned_to] then
         scope.vars[emptytable.assigned_to] = { t = fresh_t }
      end
   end
end

function Context:infer_emptytable_from_unresolved_value(w, u, values)
   local et = u.emptytable_type
   assert(et.typename == "emptytable", u.typename)
   local keys = et.keys
   if not (values.typename == "emptytable" or values.typename == "unresolved_emptytable_value") then
      local infer_to = is_numeric_type(keys) and
      a_type(w, "array", { elements = values }) or
      a_type(w, "map", { keys = keys, values = values })
      self:infer_emptytable(et, self:infer_at(w, infer_to))
   end
end

function Context:check_if_redeclaration(new_name, node, t)
   local old
   if simple_types[new_name] then
      if t.typename ~= "typedecl" then
         return
      end
   else
      old = self:find_var(new_name, "check_only")
      if not old then
         return
      end
   end
   local var_name = node.tk
   local var_kind = "variable"
   if node.kind == "local_function" or node.kind == "record_function" then
      var_kind = "function"
      var_name = node.name.tk
   end
   self.errs:redeclaration_warning(node, var_name, var_kind, old)
end

do





   local resolve_typevar_fns = {
      ["typevar"] = function(s, t)
         local rt = s.ctx:find_var_type(t.typevar)
         if not rt then
            return t, false
         end

         rt = drop_constant_value(rt)
         s.resolved[t.typevar] = rt

         return rt, true
      end,
   }

   local function clear_resolved_typeargs(copy, resolved)
      for i = #copy.typeargs, 1, -1 do
         local r = resolved[copy.typeargs[i].typearg]
         if r then
            table.remove(copy.typeargs, i)
         end
      end
      if not copy.typeargs[1] then
         return copy.t
      end
      return copy
   end

   function Context:resolve_typevars(t)
      local state = {
         ctx = self,
         resolved = {},
      }
      local rt, errs = types.map(state, t, resolve_typevar_fns)
      if errs then
         return rt, errs
      end

      if rt.typename == "generic" then
         rt = clear_resolved_typeargs(rt, state.resolved)
      end

      return rt
   end
end

do
   local function specialize_var(scope, node, name, t, attribute, specialization)
      local var = scope.vars[name]
      if var then
         if var.is_specialized then
            var.t = t
            return var
         end

         var.is_specialized = specialization
         var.specialized_from = var.t
         var.t = t
      else
         var = { t = t, attribute = attribute, is_specialized = specialization, declared_at = node }
         scope.vars[name] = var
      end

      if specialization == "widen" then
         scope.widens = scope.widens or {}
         scope.widens[name] = true
      else
         scope.narrows = scope.narrows or {}
         scope.narrows[name] = true
      end

      return var
   end

   function Context:add_var(node, name, t, attribute, specialization)
      if self.feat_lax and node and is_unknown(t) and (name ~= "self" and name ~= "...") and not specialization then
         self.errs:add_unknown(node, name)
      end
      if not attribute then
         t = drop_constant_value(t)
      end

      if self.collector and node then
         self.collector.add_to_symbol_list(node, name, t)
      end

      local scope = self.st[#self.st]
      if specialization then
         return specialize_var(scope, node, name, t, attribute, specialization)
      end

      if node then
         if name ~= "self" and name ~= "..." and name:sub(1, 1) ~= "@" then
            self:check_if_redeclaration(name, node, t)
         end
         if not ensure_not_abstract(t) then
            node.elide_type = true
         end
      end

      local var = scope.vars[name]
      if var and not has_var_been_used(var) then


         self.errs:unused_warning(name, var)
      end

      var = { t = t, attribute = attribute, declared_at = node }
      scope.vars[name] = var

      return var
   end

   function Context:add_implied_var(name, t)
      self:add_var(nil, name, t)
   end
end

function Context:fresh_typeargs(g)
   local newg, errs = types.fresh_typeargs(g)
   if newg.typename == "invalid" then
      self.errs:collect(errs)
      return g
   end
   return newg
end

function Context:find_var_type(name, use)
   local var = self:find_var(name, use)
   if var then
      local t = var.t
      if t.typename == "unresolved_typearg" then
         return nil, nil, t.constraint
      end

      if t.typename == "generic" then
         t = self:fresh_typeargs(t)
      end

      return t, var.attribute
   end
end

do
   local function unresolved_typeargs_for(g)
      local ts = {}
      for _, ta in ipairs(g.typeargs) do
         table.insert(ts, a_type(ta, "unresolved_typearg", {
            constraint = ta.constraint,
         }))
      end
      return ts
   end

   function Context:apply_generic(w, g, typeargs)
      if not g.fresh then
         g = self:fresh_typeargs(g)
      end

      if not typeargs then
         typeargs = unresolved_typeargs_for(g)
      end

      assert(#g.typeargs == #typeargs)

      for i, ta in ipairs(g.typeargs) do
         self:add_var(nil, ta.typearg, typeargs[i])
      end
      local applied, errs = self:resolve_typevars(g)
      if errs then
         self.errs:add_prefixing(w, errs, "")
         return nil
      end

      if applied.typename == "generic" then
         return applied.t, g.typeargs
      else
         return applied, g.typeargs
      end
   end
end

function Context:add_self_type(w, def)
   self:add_var(nil, "@self", a_type(w, "typedecl", { def = def }))
end

function Context:widen_in_scope(n, var)
   local scope = self.st[n]
   local v = scope.vars[var]
   assert(v, "no " .. var .. " in scope")
   local specialization = scope.vars[var].is_specialized
   if (not specialization) or
      not (specialization == "narrow" or
      specialization == "narrowed_declaration") then

      return false
   end

   local top = #self.st
   if n ~= top then
      local t = v.specialized_from
      if not t then
         local old
         for i = n - 1, 1, -1 do
            old = self.st[i].vars[var]
            if old then
               if old.specialized_from then
                  t = old.specialized_from
                  break
               elseif old.is_specialized == "localizing" or not old.is_specialized then
                  t = old.t
                  break
               end
            end
         end


         if not t then
            return false
         end
      end
      self:add_var(nil, var, t, nil, "widen")
      return true
   end

   if v.specialized_from then
      v.t = v.specialized_from
      v.specialized_from = nil
      v.is_specialized = nil
   else
      scope.vars[var] = nil
   end

   if scope.narrows then
      scope.narrows[var] = nil
   end

   return true
end


function Context:widen_back_var(name)
   local widened = false
   for i = #self.st, 1, -1 do
      local scope = self.st[i]
      if scope.vars[name] then
         if self:widen_in_scope(i, name) then
            widened = true
         else
            break
         end
      end
   end
   return widened
end

function Context:collect_if_widens(widens)
   local st = self.st
   local scope = st[#st]
   if scope.widens then
      widens = widens or {}
      for k, _ in pairs(scope.widens) do
         widens[k] = true
      end
      scope.widens = nil
   end
   return widens
end

function Context:widen_all(widens, widen_types)
   for name, _ in pairs(widens) do
      local curr = self:find_var(name, "check_only")
      local prev = widen_types[name]
      if (not prev) or (curr and not self:same_type(curr.t, prev)) then
         self:widen_back_var(name)
      end
   end
end

function Context:begin_scope(node)
   table.insert(self.st, { vars = {} })

   if self.collector and node then
      self.collector.begin_symbol_list_scope(node)
   end
end

function Context:begin_implied_scope()
   self:begin_scope(nil)
end

function Context:end_scope(node)
   local st = self.st
   local scope = st[#st]

   local widen_types
   if scope.widens then
      widen_types = {}
      for name, _ in pairs(scope.widens) do
         local var = self:find_var(name, "check_only")
         widen_types[name] = var.t
      end
   end

   table.remove(st)
   local next_scope = st[#st]

   assert(not scope.is_transaction)

   variables.close_types(scope)
   self.errs:check_var_usage(scope)

   if scope.widens then
      self:widen_all(scope.widens, widen_types)
   end

   if self.collector and node then
      self.collector.end_symbol_list_scope(node)
   end

   if not next_scope then
      return
   end

   if scope.pending_labels then
      if next_scope.pending_labels then
         for name, nodes in pairs(scope.pending_labels) do
            for _, n in ipairs(nodes) do
               next_scope.pending_labels[name] = next_scope.pending_labels[name] or {}
               table.insert(next_scope.pending_labels[name], n)
            end
         end
      else
         next_scope.pending_labels = scope.pending_labels
      end
   end

   if scope.pending_nominals then
      if next_scope.pending_nominals then
         for name, typs in pairs(scope.pending_nominals) do
            for _, typ in ipairs(typs) do
               next_scope.pending_nominals[name] = next_scope.pending_nominals[name] or {}
               table.insert(next_scope.pending_nominals[name], typ)
            end
         end
      else
         next_scope.pending_nominals = scope.pending_nominals
      end
   end
end

function Context:end_implied_scope()
   self:end_scope(nil)
end

function Context:begin_scope_transaction(node)
   self:begin_scope(node)
   local st = self.st
   st[#st].is_transaction = true
end

function Context:rollback_scope_transaction()
   local st = self.st
   local scope = st[#st]
   assert(scope.is_transaction)

   local vars = scope.vars
   for k, _ in pairs(vars) do
      vars[k] = nil
   end

   if self.collector then
      self.collector.rollback_symbol_list_scope()
   end
end

function Context:commit_scope_transaction(node)
   local st = self.st
   local scope = st[#st]
   local next_scope = st[#st - 1]

   assert(scope.is_transaction)
   assert(not scope.pending_labels)
   assert(not scope.pending_nominals)

   for name, var in pairs(scope.vars) do
      local t = var.t
      next_scope.vars[name] = var
      assert(t)
   end

   table.remove(st)

   if self.collector and node then
      self.collector.end_symbol_list_scope(node)
   end
end

do
   local function find_nominal_type_decl(self, t)
      if t.resolved then
         return t.resolved
      end

      local found = t.found or self:find_type(t.names)
      if not found then
         return self.errs:invalid_at(t, "unknown type %s", t)
      end

      if found.typename == "typedecl" and found.is_alias then
         local def = found.def
         if def.typename == "nominal" then
            found = def.found
         end

      end

      if not found then
         return self.errs:invalid_at(t, table.concat(t.names, ".") .. " is not a resolved type")
      end

      if not (found.typename == "typedecl") then
         return self.errs:invalid_at(t, table.concat(t.names, ".") .. " is not a type")
      end

      local def = found.def
      if def.typename == "circular_require" then

         return def
      end

      assert(not (def.typename == "nominal"))

      t.found = found

      if self.collector then
         self.env.reporter:set_ref(t, found)
      end

      return nil, found
   end

   local resolve_decl_in_nominal
   do
      local function check_metatable_contract(self, tv, ret)
         if not ret or not (tv.typename == "nominal") then
            return
         end
         local found = tv.found
         if not found then
            return
         end
         local rec = found.def
         if not (rec.fields and rec.meta_fields and ret.fields) then
            return
         end
         for fname, ftype in pairs(rec.meta_fields) do
            if ret.fields[fname] then
               if not self:is_a(ftype, ret.fields[fname]) then
                  self.errs:add(ftype, fname .. " does not follow metatable contract: got %s, expected %s", ftype, ret.fields[fname])
               end
            end
            ret.fields[fname] = ftype
         end
      end

      local function match_typevals(self, t, def)
         if not t.typevals then

            local deft = def.t
            if (not (deft.typename == "function")) and (not (deft.typename == "poly")) then
               self.errs:add(t, "missing type arguments in %s", def)
               return nil
            end
         elseif #t.typevals ~= #def.typeargs then
            self.errs:add(t, "mismatch in number of type arguments")
            return nil
         end

         self:begin_implied_scope()

         local ret = self:apply_generic(t, def, t.typevals)
         if def == self.cache_std_metatable_type then
            check_metatable_contract(self, t.typevals[1], ret)
         end

         self:end_implied_scope()

         return ret
      end

      resolve_decl_in_nominal = function(self, t, found)
         local def = found.def
         local resolved
         if def.typename == "generic" then
            resolved = match_typevals(self, t, def)
            if not resolved then
               resolved = a_type(t, "invalid", {})
            end
         elseif t.typevals then
            resolved = self.errs:invalid_at(t, "unexpected type argument")
         else
            resolved = def
         end

         t.resolved = resolved

         return resolved
      end
   end

   function Context:resolve_nominal(t)
      local immediate, found = find_nominal_type_decl(self, t)
      if immediate then
         return immediate
      end

      return resolve_decl_in_nominal(self, t, found)
   end

   function Context:resolve_typealias(ta)
      local def = ta.def

      local nom = def
      if def.typename == "generic" then
         nom = def.t
      end

      if not (nom.typename == "nominal") then
         return ta
      end


      local immediate, found = find_nominal_type_decl(self, nom)

      if immediate and (immediate.typename == "invalid" or immediate.typename == "typedecl") then
         return immediate
      end


      if not nom.typevals then
         nom.resolved = found
         return found
      end




      local struc = resolve_decl_in_nominal(self, nom, found or nom.found)

      if def.typename == "generic" then
         struc = wrap_generic_if_typeargs(def.typeargs, struc)
      end


      local td = a_type(ta, "typedecl", { def = struc })
      nom.resolved = td


      return td
   end
end

function Context:arg_check(w, all_errs, a, b, v, mode, n)
   local ok, err, errs

   if v == "covariant" then
      ok, errs = self:is_a(a, b)
   elseif v == "contravariant" then
      ok, errs = self:is_a(b, a)
   elseif v == "bivariant" then
      ok, errs = self:is_a(a, b)
      if ok then
         return true
      end
      ok = self:is_a(b, a)
      if ok then
         return true
      end
   elseif v == "invariant" then
      ok, errs = self:same_type(a, b)
   end

   if ok and b.typename == "nominal" then
      local rb = self:resolve_nominal(b)
      ok, err = ensure_not_abstract(rb)
      if not ok then
         errs = { errors.at(w, err) }
      end
   end

   if not ok then
      self.errs:add_prefixing(w, errs, mode .. (n and " " .. n or "") .. ": ", all_errs)
      return false
   end
   return true
end

function Context:to_structural(t)
   assert(not (t.typename == "tuple"))
   if t.typename == "typevar" and t.constraint then
      t = t.constraint
   end
   if t.typename == "nominal" then
      t = self:resolve_nominal(t)
   end
   return t
end

function Context:arraytype_from_tuple(w, tupletype)

   local element_type = unite(w, tupletype.types, true)
   local valid = (not (element_type.typename == "union")) and true or is_valid_union(element_type)
   if valid then
      return a_type(w, "array", { elements = element_type })
   end


   local arr_type = a_type(w, "array", { elements = tupletype.types[1] })
   for i = 2, #tupletype.types do
      local expanded = self:expand_type(w, arr_type, a_type(w, "array", { elements = tupletype.types[i] }))
      if not (expanded.typename == "array") then
         return nil, { types.error("unable to convert tuple %s to array", tupletype) }
      end
      arr_type = expanded
   end
   return arr_type
end

function Context:type_of_self(w)
   local t = self:find_var_type("@self")
   if not t then
      return a_type(w, "invalid", {}), nil
   end
   assert(t.typename == "typedecl")
   return t.def, t
end


function Context:is_a(t1, t2)
   return relations.compare_types(self, self.type_priorities, self.subtype_relations, t1, t2)
end


function Context:same_type(t1, t2)


   return relations.compare_types(self, self.type_priorities, self.eqtype_relations, t1, t2)
end

if TL_DEBUG then
   local orig_is_a = Context.is_a
   Context.is_a = function(self, t1, t2)
      assert(type(t1) == "table")
      assert(type(t2) == "table")

      if t1.typeid == t2.typeid then
         local st1, st2 = show_type_base(t1, false, {}), show_type_base(t2, false, {})
         assert(st1 == st2, st1 .. " ~= " .. st2)
         return true
      end

      return orig_is_a(self, t1, t2)
   end
end

function Context:same_in_all_union_entries(u, check)
   assert(#u.types > 0)

   local t1, f = check(u.types[1])
   if not t1 then
      return nil
   end
   for i = 2, #u.types do
      local t2 = check(u.types[i])
      if not t2 or not self:same_type(t1, t2) then
         return nil
      end
   end
   return f
end

function Context:same_call_mt_in_all_union_entries(u)
   return self:same_in_all_union_entries(u, function(t)
      t = self:to_structural(t)
      if t.fields then
         local call_mt = t.meta_fields and t.meta_fields["__call"]
         if call_mt.typename == "function" then
            local args_tuple = a_type(u, "tuple", { tuple = {} })
            for i = 2, #call_mt.args.tuple do
               table.insert(args_tuple.tuple, call_mt.args.tuple[i])
            end
            return args_tuple, call_mt
         end
      end
   end)
end

function Context:resolve_for_call(func, args, is_method)

   if self.feat_lax and is_unknown(func) then
      local unk = func
      func = a_function(func, {
         min_arity = 0,
         args = a_vararg(func, { unk }),
         rets = a_vararg(func, { unk }),
      })
   end

   func = self:to_structural(func)

   if func.typename == "generic" then
      func = self:apply_generic(func, func)
   end

   if func.typename == "function" or func.typename == "poly" then
      return func, is_method
   end


   if func.typename == "union" then
      local r = self:same_call_mt_in_all_union_entries(func)
      if r then
         table.insert(args.tuple, 1, func.types[1])
         return r, true
      end

   elseif func.typename == "typedecl" then
      return self:resolve_for_call(func.def, args, is_method)

   elseif func.fields and func.meta_fields and func.meta_fields["__call"] then
      table.insert(args.tuple, 1, func)
      func = func.meta_fields["__call"]
      func = self:to_structural(func)
      is_method = true
   end

   if func.typename == "generic" then
      func = self:apply_generic(func, func)
   end

   return func, is_method
end

do
   local function mark_invalid_typeargs(self, typeargs)
      for _, a in ipairs(typeargs) do
         if not self:find_var_type(a.typearg) then
            if a.constraint then
               self:add_var(nil, a.typearg, a.constraint)
            else
               self:add_var(nil, a.typearg, self.feat_lax and a_type(a, "unknown", {}) or a_type(a, "unresolvable_typearg", {
                  typearg = a.typearg,
               }))
            end
         end
      end
   end

   local function infer_emptytables(self, w, wheres, xs, ys, delta)
      local xt, yt = xs.tuple, ys.tuple
      local n_xs = #xt
      local n_ys = #yt

      for i = 1, n_xs do
         local x = xt[i]
         if x.typename == "emptytable" then
            local y = yt[i] or (ys.is_va and yt[n_ys])
            if y then
               local iw = wheres and wheres[i + delta] or w
               local inferred_y = self:infer_at(iw, y)
               self:infer_emptytable(x, inferred_y)
               xt[i] = inferred_y
            end
         end
      end
   end







   local check_call
   do
      local check_args_rets
      do

         local function check_func_type_list(self, w, wheres, xs, ys, from, delta, v, mode)
            local errs = {}
            local xt, yt = xs.tuple, ys.tuple
            local n_xs = #xt
            local n_ys = #yt

            for i = from, math.max(n_xs, n_ys) do
               local pos = i + delta
               local x = xt[i] or (xs.is_va and xt[n_xs]) or a_type(w, "nil", {})
               local y = yt[i] or (ys.is_va and yt[n_ys])
               if y then
                  local iw = wheres and wheres[pos] or w
                  if not self:arg_check(iw, errs, x, y, v, mode, pos) then
                     return nil, errs
                  end
               end
            end

            return true
         end

         check_args_rets = function(self, w, wargs, f, args, expected_rets, argdelta, or_args, or_rets)
            local rets_ok = true
            local args_ok, args_errs = true, nil

            local fargs = or_args or f.args
            local frets = or_rets or f.rets

            local from = 1
            if argdelta == -1 then
               from = 2
               local errs = {}
               local first = fargs.tuple[1]
               if (not (first.typename == "self")) and not self:arg_check(w, errs, first, args.tuple[1], "contravariant", "self") then
                  return nil, errs
               end
            end

            if expected_rets then
               expected_rets = self:infer_at(w, expected_rets)
               infer_emptytables(self, w, nil, expected_rets, frets, 0)

               rets_ok = check_func_type_list(self, w, nil, frets, expected_rets, 1, 0, "covariant", "return")
            end

            args_ok, args_errs = check_func_type_list(self, w, wargs, fargs, args, from, argdelta, "contravariant", "argument")
            if (not args_ok) or (not rets_ok) then
               return nil, args_errs or {}
            end

            infer_emptytables(self, w, wargs, args, fargs, argdelta)

            return true
         end
      end

      local function is_method_mismatch(self, w, arg1, farg1, cm)
         if cm == "method" or not farg1 then
            return false
         end
         if not (arg1 and self:is_a(arg1, farg1)) then
            self.errs:add(w, "invoked method as a regular function: use ':' instead of '.'")
            return true
         end
         if cm == "plain" then
            self.errs:add_warning("hint", w, "invoked method as a regular function: consider using ':' instead of '.'")
         end
         return false
      end

      check_call = function(self, w, wargs, f, args, expected_rets, cm, argdelta, or_args, or_rets)
         local arg1 = args.tuple[1]
         if cm == "method" and arg1 then
            local selftype = arg1
            if selftype.typename == "self" then
               selftype = self:type_of_self(selftype)
            end
            self:add_self_type(w, selftype)
         end

         local fargs = (or_args or f.args).tuple
         if f.is_method and is_method_mismatch(self, w, arg1, fargs[1], cm) then
            return false
         end

         local given = #args.tuple
         local wanted = #fargs
         local min_arity = self.feat_arity and f.min_arity or 0

         if given < min_arity or (given > wanted and not (or_args or f.args).is_va) then
            return nil, { errors.at(w, "wrong number of arguments (given " .. given .. ", expects " .. types.show_arity(f) .. ")") }
         end

         return check_args_rets(self, w, wargs, f, args, expected_rets, argdelta, or_args, or_rets)
      end
   end

   function Context:iterate_poly(p)
      local i = 0
      return function()
         i = i + 1
         local fg = p.types[i]
         if not fg then
            return
         elseif fg.typename == "function" then
            return i, fg
         elseif fg.typename == "generic" then
            return i, self:apply_generic(p, fg)
         end
      end
   end

   local check_poly_call
   do
      local function fail_poly_call_arity(self, w, p, given)
         local expects = {}
         for _, f in self:iterate_poly(p) do
            table.insert(expects, types.show_arity(f))
         end
         table.sort(expects)
         for i = #expects, 1, -1 do
            if expects[i] == expects[i + 1] then
               table.remove(expects, i)
            end
         end
         return { errors.at(w, "wrong number of arguments (given " .. given .. ", expects " .. table.concat(expects, " or ") .. ")") }
      end

      check_poly_call = function(self, w, wargs, p, args, expected_rets, cm, argdelta, or_args, or_rets)
         local given = #args.tuple

         local tried = {}
         local first_rets
         local first_errs

         for pass = 1, 3 do
            for i, f in self:iterate_poly(p) do
               assert(f.typename == "function", f.typename)
               assert(f.args)
               first_rets = first_rets or or_rets or f.rets

               local wanted = #f.args.tuple
               local min_arity = self.feat_arity and f.min_arity or 0

               if (not tried[i]) and

                  ((pass == 1 and given == wanted) or

                  (pass == 2 and (given < wanted and given >= min_arity)) or

                  (pass == 3 and (f.args.is_va and given > wanted))) then

                  local ok, errs = check_call(self, w, wargs, f, args, expected_rets, cm, argdelta, or_args, or_rets)
                  if ok then
                     return f, or_rets or f.rets
                  elseif expected_rets then

                     infer_emptytables(self, w, wargs, or_rets or f.rets, or_rets or f.rets, argdelta)
                  end

                  self:rollback_scope_transaction()

                  first_errs = first_errs or errs
                  tried[i] = true
               end
            end
         end

         if not first_errs then
            return nil, first_rets, fail_poly_call_arity(self, w, p, given)
         end

         return nil, first_rets, first_errs
      end
   end

   local function should_warn_dot(node, e1, is_method)
      if is_method then
         return "method"
      end
      if node_is_funcall(node) and e1 and e1.receiver then
         local receiver = e1.receiver
         if receiver.typename == "nominal" then
            local resolved = receiver.resolved
            if resolved and resolved.typename == "typedecl" then
               return "type_dot"
            end
         end
      end
      return "plain"
   end

   function Context:type_check_function_call(node, func, args, argdelta, or_args, or_rets, e1, e2)
      e1 = e1 or node.e1
      e2 = e2 or node.e2

      local expected = node.expected
      local expected_rets
      if expected and expected.typename == "tuple" then
         expected_rets = expected
      else
         expected_rets = a_type(node, "tuple", { tuple = { node.expected } })
      end

      self:begin_scope_transaction(node)

      local g
      local typeargs
      if func.typename == "generic" then
         g = func
         func, typeargs = self:apply_generic(node, func)
      end

      local is_method = (argdelta == -1)

      if not (func.typename == "function" or func.typename == "poly") then
         func, is_method = self:resolve_for_call(func, args, is_method)
         if is_method then
            argdelta = -1
         end
      end

      local cm = should_warn_dot(node, e1, is_method)

      local errs
      local f, ret

      if func.typename == "poly" then
         f, ret, errs = check_poly_call(self, node, e2, func, args, expected_rets, cm, argdelta, or_args, or_rets)
      elseif func.typename == "function" then
         local _
         _, errs = check_call(self, node, e2, func, args, expected_rets, cm, argdelta, or_args, or_rets)
         f, ret = func, or_rets or func.rets
      else
         ret = self.errs:invalid_at(node, "not a function: %s", func)
      end

      if errs then
         self.errs:collect(errs)
      end

      if g then
         mark_invalid_typeargs(self, typeargs)
      end

      self:commit_scope_transaction(node)

      ret = self:assert_resolved_typevars_at(node, ret)

      if self.collector then
         self.collector.store_type(e1.y, e1.x, f)
      end

      if f and f.macroexp then
         local argexps
         if is_method then
            argexps = {}
            if e1.kind == "op" then
               table.insert(argexps, e1.e1)
            else
               table.insert(argexps, e1)
            end
            for _, e in ipairs(e2) do
               table.insert(argexps, e)
            end
         else
            argexps = e2
         end
         macroexps.expand(node, argexps, f.macroexp)
      end

      return ret, f
   end
end

function Context:resolve_self(t, resolve_interface)
   local selftype, selfdecl = self:type_of_self(t)
   local checktype = selftype
   if selftype.typename == "generic" then
      checktype = selftype.t
   end

   if (resolve_interface and checktype.typename == "interface") or checktype.typename == "record" then
      return types.map(self, t, {
         ["self"] = function(_, typ)
            return typedecl_to_nominal(typ, checktype.declname, selfdecl)
         end,
      })
   else
      return t
   end
end

do
   local function add_interface_fields(self, fields, field_order, resolved, named, list)
      for fname, ftype in fields_of(resolved, list) do
         if fields[fname] then
            if not self:is_a(fields[fname], ftype) then
               local what = list == "meta" and "metamethod" or "field"
               self.errs:add(fields[fname], what .. " '" .. fname .. "' does not match definition in interface %s", named)
            end
         else
            if not (ftype.typename == "typedecl") then
               table.insert(field_order, fname)
               fields[fname] = self:resolve_self(ftype)
            end
         end
      end
   end

   local function collect_interfaces(self, list, t, seen)
      if t.interface_list then
         for _, iface in ipairs(t.interface_list) do
            if iface.typename == "nominal" then
               local ri = self:resolve_nominal(iface)
               if ri.typename == "interface" then
                  table.insert(list, iface)
                  if ri.interfaces_expanded and not seen[ri] then
                     seen[ri] = true
                     collect_interfaces(self, list, ri, seen)
                  end
               else
                  self.errs:add(iface, "attempted to use %s as interface, but its type is %s", iface, ri)
               end
            else
               if not seen[iface] then
                  seen[iface] = true
                  table.insert(list, iface)
               end
            end
         end
      end
      return list
   end

   function Context:expand_interfaces(t)
      if t.interfaces_expanded then
         return
      end
      t.interfaces_expanded = true

      t.interface_list = collect_interfaces(self, {}, t, {})

      for _, iface in ipairs(t.interface_list) do
         if iface.typename == "nominal" then
            local ri = self:resolve_nominal(iface)
            assert(ri.typename == "interface")
            add_interface_fields(self, t.fields, t.field_order, ri, iface)
            if ri.meta_fields then
               t.meta_fields = t.meta_fields or {}
               t.meta_field_order = t.meta_field_order or {}
               add_interface_fields(self, t.meta_fields, t.meta_field_order, ri, iface, "meta")
            end
         else
            if not t.elements then
               t.elements = iface.elements
            else
               if not self:same_type(iface.elements, t.elements) then
                  self.errs:add(t, "incompatible array interfaces")
               end
            end
         end
      end
   end
end

function Context:begin_temporary_record_types(typ)
   self:add_self_type(typ, typ)

   for fname, ftype in fields_of(typ) do
      if ftype.typename == "typedecl" then
         local def = ftype.def
         if def.typename == "nominal" then
            assert(ftype.is_alias)
            self:resolve_nominal(def)
         end
         self:add_var(nil, fname, ftype)
      end
   end
end

function Context:end_temporary_record_types(typ)


   local scope = self.st[#self.st]
   scope.vars["@self"] = nil
   for fname, ftype in fields_of(typ) do
      if ftype.typename == "typedecl" then
         scope.vars[fname] = nil
      end
   end
end

function Context:check_metamethod(node, method_name, a, b, orig_a, orig_b, flipped)
   if self.feat_lax and ((a and is_unknown(a)) or (b and is_unknown(b))) then
      return a_type(node, "unknown", {}), nil
   end

   local ameta = a.fields and a.meta_fields
   local bmeta = b and b.fields and b.meta_fields

   if not ameta and not bmeta then
      return nil, nil
   end

   local meta_on_operator = 1
   local metamethod
   if method_name ~= "__is" then
      metamethod = ameta and ameta[method_name or ""]
   end
   if (not metamethod) and b and method_name ~= "__index" then
      metamethod = bmeta and bmeta[method_name or ""]
      meta_on_operator = 2
   end

   if metamethod then
      local e2 = { node.e1 }
      local args = a_type(node, "tuple", { tuple = { orig_a } })
      if b and method_name ~= "__is" then
         e2[2] = node.e2
         args.tuple[2] = orig_b
      end
      if flipped then
         e2[2], e2[1] = e2[1], e2[2]
      end

      local mtdelta = metamethod.typename == "function" and metamethod.is_method and -1 or 0
      local ret_call = self:type_check_function_call(node, metamethod, args, mtdelta, nil, nil, node, e2)
      local ret_unary = untuple(ret_call)
      local ret = self:to_structural(ret_unary)
      return ret, meta_on_operator
   else
      return nil, nil
   end
end

function Context:match_record_key(t, rec, key)
   t = self:to_structural(t)

   if t.typename == "self" then
      t = self:type_of_self(t)
   end

   if t.typename == "string" or t.typename == "enum" then

      t = self.env.modules["string"]
      self.needs_compat["string"] = true
   end

   if t.typename == "typedecl" then
      if t.is_nested_alias then
         return nil, "cannot use a nested type alias as a concrete value"
      end
      local def = t.def
      if def.typename == "nominal" then
         assert(t.is_alias)
         t = self:resolve_nominal(def)
      else
         t = def
      end
   end

   if t.typename == "generic" then
      t = self:apply_generic(t, t)
   end

   if t.typename == "union" then
      local ty = self:same_in_all_union_entries(t, function(typ)
         local v = self:match_record_key(typ, rec, key)
         return v, v
      end)
      if ty then
         return ty
      end
   end

   if (t.typename == "typevar" or t.typename == "typearg") and t.constraint then
      local ty = self:match_record_key(t.constraint, rec, key)
      if ty then
         return ty
      end
   end

   local keyg = key:gsub("%%", "%%%%")

   if t.fields then
      assert(t.fields, "record has no fields!?")

      if t.fields[key] then
         return t.fields[key]
      end

      local str = a_type(rec, "string", {})
      local meta_t = self:check_metamethod(rec, "__index", t, str, t, str)
      if meta_t then
         return meta_t
      end

      if rec.kind == "variable" then
         if t.typename == "interface" then
            return nil, "invalid key '" .. keyg .. "' in '" .. rec.tk .. "' of interface type %s"
         else
            return nil, "invalid key '" .. keyg .. "' in record '" .. rec.tk .. "' of type %s"
         end
      else
         return nil, "invalid key '" .. keyg .. "' in type %s"
      end
   elseif t.typename == "emptytable" or is_unknown(t) then
      if self.feat_lax then
         return a_type(rec, "unknown", {})
      end
      return nil, "cannot index a value of unknown type"
   end

   if rec.kind == "variable" then
      return nil, "cannot index key '" .. keyg .. "' in variable '" .. rec.tk .. "' of type %s"
   else
      return nil, "cannot index key '" .. keyg .. "' in type %s"
   end
end

do
   local function assigned_anywhere(name, root)
      local visit_node = {
         cbs = {
            ["assignment"] = {
               after = function(_, node, _children)
                  for _, v in ipairs(node.vars) do
                     if v.kind == "variable" and v.tk == name then
                        return true
                     end
                  end
                  return false
               end,
            },
         },
         after = function(_, _node, children, ret)
            ret = ret or false
            for _, c in ipairs(children) do
               local ca = c
               if type(ca) == "boolean" then
                  ret = ret or c
               end
            end
            return ret
         end,
      }

      local visit_type = {
         after = function()
            return false
         end,
      }

      return traverse_nodes(nil, root, visit_node, visit_type)
   end

   function Context:widen_all_unions(node)
      for i = #self.st, 1, -1 do
         local scope = self.st[i]
         if scope.narrows then
            for name, _ in pairs(scope.narrows) do
               if not node or assigned_anywhere(name, node) then
                  self:widen_in_scope(i, name)
               end
            end
         end
      end
   end
end

function Context:add_global(node, varname, valtype, is_assigning)
   if self.feat_lax and is_unknown(valtype) and (varname ~= "self" and varname ~= "...") then
      self.errs:add_unknown(node, varname)
   end

   local is_const = node.attribute ~= nil
   local existing, scope, existing_attr = self:find_var(varname)
   if existing then
      if scope > 1 then
         self.errs:add(node, "cannot define a global when a local with the same name is in scope")
      elseif is_assigning and existing_attr then
         self.errs:add(node, "cannot reassign to <" .. existing_attr .. "> global: " .. varname)
      elseif existing_attr and not is_const then
         self.errs:add(node, "global was previously declared as <" .. existing_attr .. ">: " .. varname)
      elseif (not existing_attr) and is_const then
         self.errs:add(node, "global was previously declared as not <" .. node.attribute .. ">: " .. varname)
      elseif valtype and not self:same_type(existing.t, valtype) then
         self.errs:add(node, "cannot redeclare global with a different type: previous type of " .. varname .. " is %s", existing.t)
      end
      return nil
   end

   local var = { t = valtype, attribute = is_const and "const" or nil }
   self.st[1].vars[varname] = var

   return var
end

function Context:add_internal_function_variables(node, args)
   self:add_var(nil, "@is_va", a_type(node, args.is_va and "any" or "nil", {}))
   self:add_var(nil, "@return", node.rets or a_type(node, "tuple", { tuple = {} }))

   if node.typeargs then
      for _, t in ipairs(node.typeargs) do
         local v = self:find_var(t.typearg, "check_only")
         if not v or not v.used_as_type then
            self.errs:add(t, "type argument '%s' is not used in function signature", t)
         end
      end
   end
end

function Context:add_function_definition_for_recursion(node, fnargs, feat_arity)
   self:add_var(nil, node.name.tk, wrap_generic_if_typeargs(node.typeargs, a_function(node, {
      min_arity = feat_arity and node.min_arity or 0,
      args = fnargs,
      rets = self.get_rets(node.rets),
   })))
end

function Context:end_function_scope(node)
   self.errs:fail_unresolved_labels(self.st[#self.st])
   self:end_scope(node)
end

function Context:match_all_record_field_names(node, a, field_names, errmsg)
   local t
   for _, k in ipairs(field_names) do
      local f = a.fields[k]
      if not t then
         t = f
      else
         if not self:same_type(f, t) then
            errmsg = errmsg .. string.format(" (types of fields '%s' and '%s' do not match)", field_names[1], k)
            t = nil
            break
         end
      end
   end
   if t then
      return t
   else
      return self.errs:invalid_at(node, errmsg)
   end
end

function Context:type_check_index(anode, bnode, a, b)
   assert(not (a.typename == "tuple"))
   assert(not (b.typename == "tuple"))

   local ra = self:to_structural(a)
   local rb = self:to_structural(b)

   if self.feat_lax and is_unknown(a) then
      return a
   end

   local errm
   local erra
   local errb

   if ra.typename == "typedecl" then
      ra = ra.def
   end

   if ra.typename == "tupletable" and rb.typename == "integer" then
      if bnode.constnum then
         if bnode.constnum >= 1 and bnode.constnum <= #ra.types and bnode.constnum == math.floor(bnode.constnum) then
            return ra.types[bnode.constnum]
         end

         errm, erra = "index " .. tostring(bnode.constnum) .. " out of range for tuple %s", ra
      else
         local array_type = self:arraytype_from_tuple(bnode, ra)
         if array_type then
            return array_type.elements
         end

         errm = "cannot index this tuple with a variable because it would produce a union type that cannot be discriminated at runtime"
      end
   elseif ra.typename == "self" then
      return self:type_check_index(anode, bnode, self:type_of_self(a), b)
   elseif ra.elements and rb.typename == "integer" then
      return ra.elements
   elseif ra.typename == "emptytable" then
      if ra.keys == nil then
         ra.keys = self:infer_at(bnode, b)
      end

      if self:is_a(b, ra.keys) then
         return a_type(anode, "unresolved_emptytable_value", {
            emptytable_type = ra,
         })
      end

      errm, erra, errb = "inconsistent index type: got %s, expected %s" .. types.inferred_msg(ra.keys, "type of keys "), b, ra.keys
   elseif ra.typename == "unresolved_emptytable_value" then
      local et = a_type(ra, "emptytable", { keys = b })
      self:infer_emptytable_from_unresolved_value(a, ra, et)
      return a_type(anode, "unresolved_emptytable_value", {
         emptytable_type = et,
      })
   elseif ra.typename == "map" then
      if self:is_a(b, ra.keys) then
         return ra.values
      end

      errm, erra, errb = "wrong index type: got %s, expected %s", b, ra.keys
   elseif rb.typename == "string" and rb.literal then
      local t, e = self:match_record_key(a, anode, rb.literal)
      if t then

         if t.typename == "function" and t.is_method then
            local t2 = shallow_copy_new_type(t)
            t2.args = shallow_copy_new_type(t.args)
            t2.args.tuple = shallow_copy_table(t2.args.tuple)
            for i, p in ipairs(t2.args.tuple) do
               if p.typename == "self" then
                  t2.args.tuple[i] = a
               end
            end
            return t2
         end

         return t
      end

      errm, erra = e, a
   elseif ra.fields then
      if rb.typename == "enum" then
         local field_names = sorted_keys(rb.enumset)
         for _, k in ipairs(field_names) do
            if not ra.fields[k] then
               errm, erra = "enum value '" .. k:gsub("%%", "%%%%") .. "' is not a field in %s", ra
               break
            end
         end
         if not errm then
            return self:match_all_record_field_names(bnode, ra, field_names,
            "cannot index, not all enum values map to record fields of the same type")
         end
      elseif rb.typename == "string" then
         errm, erra = "cannot index object of type %s with a string, consider using an enum", a
      else
         errm, erra, errb = "cannot index object of type %s with %s", a, b
      end
   else
      errm, erra, errb = "cannot index object of type %s with %s", a, b
   end

   local meta_t = self:check_metamethod(anode, "__index", ra, b, a, b)
   if meta_t then
      return meta_t
   end

   return self.errs:invalid_at(bnode, errm, erra, errb)
end

function Context:expand_type(w, old, new)
   if not old or old.typename == "nil" then
      return new
   end
   if self:is_a(new, old) then
      return old
   end

   if new.fields and (old.typename == "map" or old.fields) then
      local keys
      local values
      if old.typename == "map" then
         keys = old.keys
         if not (keys.typename == "string") then
            self.errs:add(w, "cannot determine table literal type")
            return old
         end
         values = old.values
      elseif old.fields then
         keys = a_type(w, "string", {})
         for _, ftype in fields_of(old) do
            values = self:expand_type(w, values, ftype)
         end
      end

      for _, ftype in fields_of(new) do
         values = self:expand_type(w, values, ftype)
      end

      return a_type(w, "map", { keys = keys, values = values })
   end

   return unite(w, { old, new }, true)
end

function Context:find_record_to_extend(exp)

   if exp.kind == "type_identifier" then
      local v = self:find_var(exp.tk)
      if not v then
         return nil, nil, exp.tk
      end

      local t = v.t
      if t.typename == "typedecl" then
         if t.closed then
            return nil, nil, exp.tk
         end

         return t.def, v, exp.tk
      end

      return t, v, exp.tk

   elseif exp.kind == "op" then
      local t, v, rname = self:find_record_to_extend(exp.e1)
      local fname = exp.e2.tk
      local dname = rname .. "." .. fname
      if not t then
         return nil, nil, dname
      end
      if not t.fields then
         return nil, nil, dname
      end
      t = t.fields[fname]

      if t.typename == "typedecl" then
         local def = t.def
         if def.typename == "nominal" then
            assert(t.is_alias)
            t = def.resolved
         else
            t = def
         end
      end

      return t, v, dname
   end
end

function Context:get_self_type(exp)

   if exp.kind == "type_identifier" then
      local t = self:find_var_type(exp.tk)
      if not t then
         return nil
      end

      if t.typename == "typedecl" then
         return typedecl_to_nominal(exp, exp.tk, t)
      else
         return t
      end

   elseif exp.kind == "op" then
      local t = self:get_self_type(exp.e1)
      if not t then
         return nil
      end

      if t.typename == "nominal" then
         local found = t.found
         if found then
            if found.typename == "typedecl" then
               local def = found.def
               if def.fields and def.fields[exp.e2.tk] then
                  table.insert(t.names, exp.e2.tk)
                  local ft = def.fields[exp.e2.tk]
                  if ft.typename == "typedecl" then
                     t.found = ft
                  else
                     return nil
                  end
               end
            end
         end
      elseif t.fields then
         return t.fields and t.fields[exp.e2.tk]
      end
      return t
   end
end

function Context:apply_facts(w, known)
   if not known then
      return
   end

   local fcts = eval_fact(self, known)

   for v, f in pairs(fcts) do
      if f.typ.typename == "invalid" then
         self.errs:add(w, "cannot resolve a type for " .. v .. " here")
      end
      local t = f.no_infer and f.typ or self:infer_at(w, f.typ)
      if f.no_infer then
         t.inferred_at = nil
      end
      self:add_var(nil, v, t, "const", "narrow")
   end
end

function Context:apply_facts_from(w, from)
   self:apply_facts(w, self.fdb:get(from or w))
end

function Context:dismiss_unresolved(name)
   for i = #self.st, 1, -1 do
      local scope = self.st[i]
      local uses = scope.pending_nominals and scope.pending_nominals[name]
      if uses then
         for _, t in ipairs(uses) do
            self:resolve_nominal(t)
         end
         scope.pending_nominals[name] = nil
         return
      end
   end
end

function Context:type_check_funcall(node, a, b, argdelta)
   if node.e1.op and node.e1.op.op == ":" then
      table.insert(b.tuple, 1, node.e1.receiver)
      argdelta = -1
   else
      argdelta = argdelta or 0
   end

   local sa = types.resolve_for_special_function(a)
   if sa then
      local special_tyck = special_functions[sa.special_function_handler]
      if special_tyck then
         return special_tyck(self, node, a, b, argdelta)
      end
   end

   return (self:type_check_function_call(node, a, b, argdelta))
end

function Context:missing_initializer(node, i, name)
   if self.feat_lax then
      return a_type(node, "unknown", {})
   else
      if node.exps then
         return self.errs:invalid_at(node.vars[i], "assignment in declaration did not produce an initial value for variable '" .. name .. "'")
      else
         return self.errs:invalid_at(node.vars[i], "variable '" .. name .. "' has no type or initial value")
      end
   end
end

function Context:infer_negation_of_if_blocks(w, ifnode, n)
   local f = facts_not(w, self.fdb:get(ifnode.if_blocks[1].exp))
   for e = 2, n do
      local b = ifnode.if_blocks[e]
      if b.exp then
         f = facts_and(w, f, facts_not(w, self.fdb:get(b.exp)))
      end
   end
   self:apply_facts(w, f)
end

function Context:determine_declaration_type(var, node, infertypes, i)
   local ok = true
   local name = var.tk
   local infertype = infertypes and infertypes.tuple[i]
   if self.feat_lax and infertype and infertype.typename == "nil" then
      infertype = nil
   end

   local decltype = node.decltuple and node.decltuple.tuple[i]
   if decltype then
      local rdecltype = self:to_structural(decltype)
      if rdecltype.typename == "invalid" then
         decltype = rdecltype
      end

      if infertype then
         local w = node.exps and node.exps[i] or node.vars[i]

         local errs
         ok, errs = self:is_a(infertype, decltype)
         if not ok then
            self.errs:add_prefixing(w, errs, self.errs:get_context(node, name))
         end
      end
   else
      if infertype then
         if infertype.typename == "unresolvable_typearg" then
            ok = false
            infertype = self.errs:invalid_at(node.vars[i], "cannot infer declaration type; an explicit type annotation is necessary")
         else



            infertype = ensure_not_method(infertype)
         end
      end
   end

   if var.attribute == "total" then
      local rd = decltype and self:to_structural(decltype)
      if rd and (not (rd.typename == "map")) and (not (rd.typename == "record")) then
         self.errs:add(var, "attribute <total> only applies to maps and records")
         ok = false
      elseif not infertype then
         self.errs:add(var, "variable declared <total> does not declare an initialization value")
         ok = false
      else
         local valnode = node.exps[i]
         if not valnode or valnode.kind ~= "literal_table" then
            self.errs:add(var, "attribute <total> only applies to literal tables")
            ok = false
         else
            if not valnode.is_total then
               local missing = ""
               if valnode.missing then
                  missing = " (missing: " .. table.concat(valnode.missing, ", ") .. ")"
               end
               local ri = self:to_structural(infertype)
               if ri.typename == "map" then
                  self.errs:add(var, "map variable declared <total> does not declare values for all possible keys" .. missing)
                  ok = false
               elseif ri.typename == "record" then
                  self.errs:add(var, "record variable declared <total> does not declare values for all fields" .. missing)
                  ok = false
               end
            end
         end
      end
   end

   local t = decltype or infertype
   if t == nil then
      t = self:missing_initializer(node, i, name)
   elseif t.typename == "emptytable" then
      t.is_global = node.kind == "global_declaration"
      t.assigned_to = name
   elseif t.elements then
      t.inferred_len = nil
   elseif t.typename == "nominal" then
      self:resolve_nominal(t)
      local rt = t.resolved
      if rt and rt.typename == "typedecl" then
         t.resolved = rt.def
      end
   end

   return ok, t, infertype ~= nil
end





function Context:check_assignment(varnode, vartype, valtype)
   local varname = varnode.tk
   local attr = varnode.attribute

   if varname then
      if self:widen_back_var(varname) then
         vartype, attr = self:find_var_type(varname)
         if not vartype then
            self.errs:add(varnode, "unknown variable")
            return nil
         end
      end
   end
   if attr == "close" or attr == "const" or attr == "total" then
      self.errs:add(varnode, "cannot assign to <" .. attr .. "> variable")
      return nil
   end

   local var = self:to_structural(vartype)
   if var.typename == "typedecl" then
      self.errs:add(varnode, "cannot reassign a type")
      return nil
   end

   if not valtype then
      self.errs:add(varnode, "variable is not being assigned a value")
      return nil, nil, "missing"
   end

   if vartype.typename == "emptytable" then
      vartype = type_at(varnode, vartype)
   end

   local ok, errs = self:is_a(valtype, vartype)
   if not ok then
      self.errs:add_prefixing(varnode, errs, "in assignment: ")
   end

   local val = self:to_structural(valtype)

   return var, val
end

do
   local function aliasing_variable(self, def)
      if def.typename == "nominal" then
         return (self:find_var(def.names[1], "use_type"))
      end

      if def.typename == "generic" then
         local nom = def.t
         if nom.typename == "nominal" then
            return (self:find_var(nom.names[1], "use_type"))
         end
      end
   end

   local function recurse_type_declaration(self, n)
      if n.kind == "op" then

         if n.op.op == "." then
            local ty = recurse_type_declaration(self, n.e1)
            if not (ty.typename == "typedecl") then
               return ty
            end
            local def = ty.def
            if not (def.typename == "record") then
               return self.errs:invalid_at(n.e1, "type is not a record")
            end
            local t = def.fields[n.e2.tk]
            if t and t.typename == "typedecl" then
               return t
            end
            return self.errs:invalid_at(n.e2, "nested type '" .. n.e2.tk .. "' not found in record")

         elseif n.op.op == "@funcall" and
            n.e1.kind == "variable" and
            n.e1.tk == "require" then

            local ty = untuple(
            special_functions["require"](
            self, n, self:find_var_type("require"),
            a_type(n.e2, "tuple", { tuple = { a_type(n.e2[1], "string", {}) } })))


            if not (ty.typename == "typedecl") then
               return self.errs:invalid_at(n.e1, "'require' did not return a type, got %s", ty)
            end
            if ty.is_alias then
               return self:resolve_typealias(ty)
            end
            return ty
         end
      end

      local newtype = n.newtype
      if newtype.is_alias then
         return self:resolve_typealias(newtype), aliasing_variable(self, newtype.def)
      end
      return newtype, nil
   end

   function Context:get_typedecl(value)
      local resolved, aliasing = recurse_type_declaration(self, value)
      local nt = value.newtype
      if nt and nt.is_alias and resolved.typename == "typedecl" then
         local ntdef = nt.def
         local rdef = resolved.def
         if ntdef.typename == "generic" and rdef.typename == "generic" then



            ntdef.typeargs = rdef.typeargs
         end
      end
      return resolved, aliasing
   end
end

function Context:is_pending_global(name)
   local global_scope = self.st[1]
   return not not global_scope.pending_global_types[name]
end

do
   local function set_feat(feat, default)
      if feat then
         return (feat == "on")
      else
         return default
      end
   end

   function Context.new(env, filename)
      local self = {
         filename = filename,
         env = env,
         st = {
            {
               vars = env.globals,
               pending_global_types = {},
            },
         },
         fdb = FactDatabase.new(),
         errs = Errors.new(filename),
         needs_compat = {},
         dependencies = {},
         subtype_relations = relations.subtype_relations,
         eqtype_relations = relations.eqtype_relations,
         type_priorities = relations.type_priorities,
      }

      if env.report_types then
         env.reporter = env.reporter or type_reporter.new()
         self.collector = env.reporter:get_collector(filename)
      end

      self.cache_std_metatable_type = env.globals["metatable"] and (env.globals["metatable"].t).def

      self.feat_arity = set_feat(env.opts.feat_arity, true)
      self.feat_lax = not not filename:match("%.lua$")

      if self.feat_lax then
         self.feat_arity = false
         self.type_priorities = relations.lax_type_priorities()
         self.subtype_relations = relations.lax_subtype_relations()
         self.get_rets = function(rets)
            if #rets.tuple == 0 then
               return a_vararg(rets, { a_type(rets, "unknown", {}) })
            end
            return rets
         end
      else
         self.get_rets = function(rets)
            return rets
         end
      end

      setmetatable(self, {
         __index = Context,
         __tostring = function() return "Context" end,
      })

      return self
   end
end



return context
