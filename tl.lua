-- module teal.api.v2 from teal/api/v2.lua
package.preload["teal.api.v2"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local check = require("teal.check.check")
local environment = require("teal.environment")
local errors = require("teal.errors")
local lexer = require("teal.lexer")
local loader = require("teal.loader")
local lua_generator = require("teal.gen.lua_generator")
local lua_compat = require("teal.gen.lua_compat")
local package_loader = require("teal.package_loader")
local parser = require("teal.parser")
local require_file = require("teal.check.require_file")
local input = require("teal.input")
local targets = require("teal.gen.targets")

local type_reporter = require("teal.type_reporter")





local v2 = { CheckOptions = {}, EnvOptions = {} }
























































environment.set_require_module_fn(require_file.require_module)

v2.warning_kinds = errors.warning_kinds
v2.typecodes = type_reporter.typecodes

















local function env_from_check_options(opts)
   return environment.new(opts and {
      feat_arity = opts.feat_arity,
      gen_compat = opts.gen_compat,
      gen_target = opts.gen_target,
   })
end

v2.check = function(ast, filename, opts, env)
   if opts and opts.gen_target == "5.4" and opts.gen_compat ~= "off" then
      return nil, "gen-compat must be explicitly 'off' when gen-target is '5.4'"
   end

   if opts and env then










      if opts.feat_arity and env.opts.feat_arity and opts.feat_arity ~= env.opts.feat_arity then
         return nil, "opts.feat_arity does not match environment setting"
      end
      if opts.gen_compat and env.opts.gen_compat and opts.gen_compat ~= env.opts.gen_compat then
         return nil, "opts.gen_compat does not match environment setting"
      end
      if opts.gen_target and env.opts.gen_target and opts.gen_target ~= env.opts.gen_target then
         return nil, "opts.gen_target does not match environment setting"
      end
   elseif opts or not env then
      env = env_from_check_options(opts)
   end

   local result = check.check(ast, env, filename or "<input>.tl")
   if result and result.ast then
      lua_compat.apply(result)
   end
   return result
end

v2.check_file = function(filename, env, fd)
   env = env or environment.new()
   local err
   if not fd then
      fd, err = io.open(filename, "rb")
      if not fd then
         return nil, err
      end
   end
   local code
   code, err = fd:read("*a")
   if not code then
      return nil, err
   end
   local result = input.check(env, filename, code)
   if result.ast then
      lua_compat.apply(result)
   end
   return result
end

v2.check_string = function(teal_code, env, filename, parse_lang)
   env = env or environment.new()
   if not filename then
      filename = parse_lang == "lua" and "<input>.lua" or "<input>.tl"
   end
   local result = input.check(env, filename, teal_code)
   if result and result.ast then
      lua_compat.apply(result)
   end
   return result
end

v2.gen = function(teal_code, env, opts, parse_lang)
   env = env or environment.new()
   local filename = parse_lang == "lua" and "<input>.lua" or "<input>.tl"
   local result = input.check(env, filename, teal_code)
   if (not result.ast) or #result.syntax_errors > 0 then
      return nil, result
   end
   lua_compat.apply(result)
   local code = lua_generator.generate(result.ast, env.opts.gen_target, opts)
   return code, result
end

v2.generate = function(ast, gen_target, opts)
   return lua_generator.generate(ast, gen_target, opts)
end

v2.get_token_at = lexer.get_token_at

v2.lex = lexer.lex

v2.load = loader.load

v2.loader = package_loader.install_loader

local function predefine_modules(env, predefined_modules)
   for _, name in ipairs(predefined_modules) do
      local ok = environment.load_module(env, name)
      if not ok then
         return nil, "Error: could not predefine module '" .. name .. "'"
      end
   end

   return true
end

v2.new_env = function(opts)
   local env = env_from_check_options(opts and opts.defaults)

   if opts and opts.predefined_modules then
      local ok, err = predefine_modules(env, opts.predefined_modules)
      if not ok then
         return nil, err
      end
   end

   return env
end

v2.parse = function(teal_code, filename, _parse_lang)
   local ast, errs, required_modules = parser.parse(teal_code, filename)
   return ast, errs, required_modules
end

v2.parse_program = function(tokens, errs, filename, parse_lang)
   local ast, required_modules = parser.parse_program(tokens, errs, filename, parse_lang)
   return ast, required_modules
end

v2.process = v2.check_file

v2.search_module = function(module_name, search_all)
   local found, _, tried = require_file.search_module(module_name, search_all and require_file.all_extensions)
   if found then
      return found, (io.open(found)), nil
   end
   return nil, nil, tried
end

v2.symbols_in_scope = function(tr, y, x, filename)
   return tr:symbols_in_scope(filename, y, x)
end

v2.target_from_lua_version = targets.detect

v2.version = function()
   return environment.VERSION
end



return v2

end

-- module teal.attributes from teal/attributes.lua
package.preload["teal.attributes"] = function(...)
local attributes = {}









local all_attributes = {
   ["const"] = true,
   ["close"] = true,
   ["total"] = true,
}

attributes.is_attribute = all_attributes

return attributes

end

-- module teal.check.check from teal/check/check.lua
package.preload["teal.check.check"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local context = require("teal.check.context")
local Context = context.Context

local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG

local environment = require("teal.environment")



local errors = require("teal.errors")






local traversal = require("teal.traversal")


local traverse_nodes = traversal.traverse_nodes

local types = require("teal.types")


local a_type = types.a_type

local util = require("teal.util")
local shallow_copy_table = util.shallow_copy_table

local variables = require("teal.variables")

local visitors = require("teal.check.visitors")
local visit_node = visitors.visit_node
local visit_type = visitors.visit_type

local check = {}





local function internal_compiler_check(fn)
   return function(s, n, children, t)
      t = fn and fn(s, n, children, t) or t

      if type(t) ~= "table" then
         error(((n).kind or (n).typename) .. " did not produce a type")
      end
      if type(t.typename) ~= "string" then
         error(((n).kind or (n).typename) .. " type does not have a typename")
      end

      return t
   end
end

local function store_type_after(fn)
   return function(self, n, children, t)
      t = fn and fn(self, n, children, t) or t

      local w = n

      if w.y then
         self.collector.store_type(w.y, w.x, t)
      end

      return t
   end
end

local function debug_type_after(fn)
   return function(s, node, children, t)
      t = fn and fn(s, node, children, t) or t

      node.debug_type = t
      return t
   end
end

local function patch_visitors(my_visit_node,
   after_node,
   my_visit_type,
   after_type)


   if my_visit_node == visit_node then
      my_visit_node = shallow_copy_table(my_visit_node)
   end
   my_visit_node.after = after_node(my_visit_node.after)
   if my_visit_type then
      if my_visit_type == visit_type then
         my_visit_type = shallow_copy_table(my_visit_type)
      end
      my_visit_type.after = after_type(my_visit_type.after)
   else
      my_visit_type = visit_type
   end
   return my_visit_node, my_visit_type
end

function check.check(ast, env, filename)
   assert(filename)

   local self = Context.new(env, filename)

   local visit_node, visit_type = visit_node, visit_type
   if env.opts.run_internal_compiler_checks then
      visit_node, visit_type = patch_visitors(
      visit_node, internal_compiler_check,
      visit_type, internal_compiler_check)

   end
   if self.collector then
      visit_node, visit_type = patch_visitors(
      visit_node, store_type_after,
      visit_type, store_type_after)

   end
   if TL_DEBUG then
      visit_node, visit_type = patch_visitors(
      visit_node, debug_type_after)

   end

   assert(ast.kind == "statements")
   traverse_nodes(self, ast, visit_node, visit_type)

   local global_scope = self.st[1]
   variables.close_types(global_scope)
   self.errs:check_var_usage(global_scope, true)

   errors.clear_redundant_errors(self.errs.errors)

   local result = {
      ast = ast,
      env = env,
      type = self.module_type or a_type(ast, "boolean", {}),
      filename = filename,
      warnings = self.errs.warnings,
      type_errors = self.errs.errors,
      dependencies = self.dependencies,
      needs_compat = self.needs_compat,
   }

   environment.register(env, filename, result)

   if self.collector then
      env.reporter:store_result(self.collector, env.globals)
   end

   return result
end

return check

end

-- module teal.check.context from teal/check/context.lua
package.preload["teal.check.context"] = function(...)
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

end

-- module teal.check.relations from teal/check/relations.lua
package.preload["teal.check.relations"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local errors = require("teal.errors")


local types = require("teal.types")


























local a_type = types.a_type
local show_arity = types.show_arity
local show_type = types.show_type
local untuple = types.untuple




local util = require("teal.util")
local shallow_copy_table = util.shallow_copy_table

local relations = {}















local function compare_true(_, _, _)
   return true
end

local function compare_map(ck, ak, bk, av, bv, no_hack)
   local ok1, errs_k = ck:is_a(bk, ak)
   local ok2, errs_v = ck:is_a(av, bv)


   if bk.typename == "any" and not no_hack then
      ok1, errs_k = true, nil
   end
   if bv.typename == "any" and not no_hack then
      ok2, errs_v = true, nil
   end

   if ok1 and ok2 then
      return true
   end


   for i = 1, errs_k and #errs_k or 0 do
      errs_k[i].msg = "in map key: " .. errs_k[i].msg
   end
   for i = 1, errs_v and #errs_v or 0 do
      errs_v[i].msg = "in map value: " .. errs_v[i].msg
   end
   if errs_k and errs_v then
      for i = 1, #errs_v do
         table.insert(errs_k, errs_v[i])
      end
      return false, errs_k
   end
   return false, errs_k or errs_v
end

local function compare_or_infer_typevar(ck, typevar, a, b, cmp)



   local vt, _, constraint = ck:find_var_type(typevar)
   if vt then

      return cmp(ck, a or vt, b or vt)
   else

      local other = a or b


      if constraint then
         if not ck:is_a(other, constraint) then
            return false, { types.error("given type %s does not satisfy %s constraint in type variable " .. types.show_typevar(typevar, "typevar"), other, constraint) }
         end

         if ck:same_type(other, constraint) then



            return true
         end
      end

      local r, errs = ck:resolve_typevars(other)
      if errs then
         return false, errs
      end


      if r.typename == "boolean_context" then
         return true
      end

      if r.typename == "typevar" and r.typevar == typevar then
         return true
      end
      ck:add_implied_var(typevar, r)
      return true
   end
end

local function subtype_record(ck, a, b)
   if a.elements and b.elements then
      if not ck:is_a(a.elements, b.elements) then
         return false, { errors.new("array parts have incompatible element types") }
      end
   end

   if a.is_userdata ~= b.is_userdata then
      return false, { errors.new(a.is_userdata and "userdata is not a record" or
"record is not a userdata"), }
   end

   local errs = {}
   for _, k in ipairs(a.field_order) do
      local ak = a.fields[k]
      local bk = b.fields[k]
      if bk then
         local ok, fielderrs = ck:is_a(ak, bk)
         if not ok then
            ck:add_errors_prefixing(nil, fielderrs, "record field doesn't match: " .. k .. ": ", errs)
         end
      elseif b.typename == "record" then
         table.insert(errs, errors.new("record field doesn't exist: " .. k))
      end
   end
   if #errs > 0 then
      for _, err in ipairs(errs) do
         err.msg = show_type(a) .. " is not a " .. show_type(b) .. ": " .. err.msg
      end
      return false, errs
   end

   return true
end

local function eqtype_record(ck, a, b)

   if (a.elements ~= nil) ~= (b.elements ~= nil) then
      return false, { errors.new("types do not have the same array interface") }
   end
   if a.elements then
      local ok, errs = ck:same_type(a.elements, b.elements)
      if not ok then
         return ok, errs
      end
   end

   local ok, errs = subtype_record(ck, a, b)
   if not ok then
      return ok, errs
   end
   ok, errs = subtype_record(ck, b, a)
   if not ok then
      return ok, errs
   end
   return true
end


local function compare_true_inferring_emptytable(ck, a, b)
   ck:infer_emptytable(b, ck:infer_at(b, a))
   return true
end

local function compare_true_inferring_emptytable_if_not_userdata(ck, a, b)
   if a.is_userdata then
      return false, { types.error("{} cannot be used with userdata type %s", a) }
   end
   return compare_true_inferring_emptytable(ck, a, b)
end

local function is_in_interface_list(ck, r, iface)
   if not r.interface_list then
      return false
   end

   for _, t in ipairs(r.interface_list) do
      if ck:is_a(t, iface) then
         return true
      end
   end

   return false
end

local function a_is_interface_b(ck, a, b)
   if (not a.found) or (not b.found) then
      return false
   end

   local af = a.found.def
   if af.typename == "generic" then
      af = ck:apply_generic(a, af, a.typevals)
   end

   if af.fields then
      if is_in_interface_list(ck, af, b) then
         return true
      end
   end

   return ck:is_a(a, ck:resolve_nominal(b))
end

local are_same_nominals
do
   local function are_same_unresolved_global_type(ck, t1, t2)

      if t1.names[1] == t2.names[1] then
         if ck:is_pending_global(t1.names[1]) then
            return true
         end
      end
      return false
   end

   local function fail_nominals(ck, t1, t2)
      local t1name = show_type(t1)
      local t2name = show_type(t2)
      if t1name == t2name then
         ck:resolve_nominal(t1)
         if t1.found then
            t1name = t1name .. " (defined in " .. t1.found.f .. ":" .. t1.found.y .. ")"
         end
         ck:resolve_nominal(t2)
         if t2.found then
            t2name = t2name .. " (defined in " .. t2.found.f .. ":" .. t2.found.y .. ")"
         end
      end
      return false, { errors.new(t1name .. " is not a " .. t2name) }
   end

   local function nominal_found_type(ck, nom)
      local typedecl = nom.found
      if not typedecl then
         typedecl = ck:find_type(nom.names)
         if not typedecl then
            return nil
         end
      end
      local t = typedecl.def

      if t.typename == "generic" then
         t = t.t
      end

      return t
   end

   are_same_nominals = function(ck, t1, t2)
      local t1f = nominal_found_type(ck, t1)
      local t2f = nominal_found_type(ck, t2)
      if (not t1f or not t2f) then
         if are_same_unresolved_global_type(ck, t1, t2) then
            return true
         end

         if not t1f then
            ck:add_error(t1, "unknown type %s", t1)
         end
         if not t2f then
            ck:add_error(t2, "unknown type %s", t2)
         end
         return false, {}
      end

      if t1f.typeid ~= t2f.typeid then
         return fail_nominals(ck, t1, t2)
      end

      if t1.typevals == nil and t2.typevals == nil then
         return true
      end

      if t1.typevals and t2.typevals and #t1.typevals == #t2.typevals then
         local errs = {}
         for i = 1, #t1.typevals do
            local _, typeval_errs = ck:same_type(t1.typevals[i], t2.typevals[i])
            ck:add_errors_prefixing(nil, typeval_errs, "type parameter <" .. show_type(t2.typevals[i]) .. ">: ", errs)
         end
         return errors.any(errs)
      end


      return true
   end
end

local function has_all_types_of(ck, t1s, t2s)
   for _, t1 in ipairs(t1s) do
      local found = false
      for _, t2 in ipairs(t2s) do
         if ck:same_type(t2, t1) then
            found = true
            break
         end
      end
      if not found then
         return false
      end
   end
   return true
end


local emptytable_relations = {
   ["emptytable"] = compare_true,
   ["array"] = compare_true,
   ["map"] = compare_true,
   ["tupletable"] = compare_true,
   ["interface"] = function(_ck, _a, b)
      return not b.is_userdata
   end,
   ["record"] = function(_ck, _a, b)
      return not b.is_userdata
   end,
}

relations.eqtype_relations = {
   ["typevar"] = {
      ["typevar"] = function(ck, a, b)
         if a.typevar == b.typevar then
            return true
         end

         return compare_or_infer_typevar(ck, b.typevar, a, nil, ck.same_type)
      end,
      ["*"] = function(ck, a, b)
         return compare_or_infer_typevar(ck, a.typevar, nil, b, ck.same_type)
      end,
   },
   ["emptytable"] = emptytable_relations,
   ["tupletable"] = {
      ["tupletable"] = function(ck, a, b)
         for i = 1, math.min(#a.types, #b.types) do
            if not ck:same_type(a.types[i], b.types[i]) then
               return false, { types.error("in tuple entry " .. tostring(i) .. ": got %s, expected %s", a.types[i], b.types[i]) }
            end
         end
         if #a.types ~= #b.types then
            return false, { types.error("tuples have different size", a, b) }
         end
         return true
      end,
      ["emptytable"] = compare_true_inferring_emptytable,
   },
   ["array"] = {
      ["array"] = function(ck, a, b)
         return ck:same_type(a.elements, b.elements)
      end,
      ["emptytable"] = compare_true_inferring_emptytable,
   },
   ["map"] = {
      ["map"] = function(ck, a, b)
         return compare_map(ck, a.keys, b.keys, a.values, b.values, true)
      end,
      ["emptytable"] = compare_true_inferring_emptytable,
   },
   ["union"] = {
      ["union"] = function(ck, a, b)
         return (has_all_types_of(ck, a.types, b.types) and
         has_all_types_of(ck, b.types, a.types))
      end,
   },
   ["nominal"] = {
      ["nominal"] = are_same_nominals,
      ["typedecl"] = function(ck, a, b)

         return ck:same_type(ck:resolve_nominal(a), b.def)
      end,
   },
   ["record"] = {
      ["record"] = eqtype_record,
      ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
   },
   ["interface"] = {
      ["interface"] = function(_ck, a, b)
         return a.typeid == b.typeid
      end,
      ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
   },
   ["function"] = {
      ["function"] = function(ck, a, b)
         local argdelta = a.is_method and 1 or 0
         local naargs, nbargs = #a.args.tuple, #b.args.tuple
         if naargs ~= nbargs then
            if (not not a.is_method) ~= (not not b.is_method) then
               return false, { errors.new("different number of input arguments: method and non-method are not the same type") }
            end
            return false, { errors.new("different number of input arguments: got " .. naargs - argdelta .. ", expected " .. nbargs - argdelta) }
         end
         local narets, nbrets = #a.rets.tuple, #b.rets.tuple
         if narets ~= nbrets then
            return false, { errors.new("different number of return values: got " .. narets .. ", expected " .. nbrets) }
         end
         local errs = {}
         for i = 1, naargs do
            ck:arg_check(a, errs, a.args.tuple[i], b.args.tuple[i], "invariant", "argument", i - argdelta)
         end
         for i = 1, narets do
            ck:arg_check(a, errs, a.rets.tuple[i], b.rets.tuple[i], "invariant", "return", i)
         end
         return errors.any(errs)
      end,
   },
   ["self"] = {
      ["self"] = function(_ck, _a, _b)
         return true
      end,
      ["*"] = function(ck, a, b)
         return ck:same_type(ck:type_of_self(a), b)
      end,
   },
   ["boolean_context"] = {
      ["boolean"] = compare_true,
   },
   ["generic"] = {
      ["generic"] = function(ck, a, b)
         if #a.typeargs ~= #b.typeargs then
            return false
         end
         for i = 1, #a.typeargs do
            if not ck:same_type(a.typeargs[i], b.typeargs[i]) then
               return false
            end
         end
         return ck:same_type(a.t, b.t)
      end,
   },
   ["*"] = {
      ["boolean_context"] = compare_true,
      ["self"] = function(ck, a, b)
         return ck:same_type(a, (ck:type_of_self(b)))
      end,
      ["typevar"] = function(ck, a, b)
         return compare_or_infer_typevar(ck, b.typevar, a, nil, ck.same_type)
      end,
   },
}


local function exists_supertype_in(ck, t, xs)
   for _, x in ipairs(xs.types) do
      if ck:is_a(t, x) then
         return x
      end
   end
end


local function forall_are_subtype_of(ck, xs, t)
   for _, x in ipairs(xs.types) do
      if not ck:is_a(x, t) then
         return false
      end
   end
   return true
end

local function subtype_nominal(ck, a, b)
   local ra = a.typename == "nominal" and ck:resolve_nominal(a) or a
   local rb = b.typename == "nominal" and ck:resolve_nominal(b) or b
   local ok, errs = ck:is_a(ra, rb)
   if errs and #errs == 1 and errs[1].msg:match("^got ") then
      return false
   end
   return ok, errs
end

local function subtype_array(ck, a, b)
   if (not a.elements) or (not ck:is_a(a.elements, b.elements)) then
      return false
   end
   if a.consttypes and #a.consttypes > 1 then

      for _, e in ipairs(a.consttypes) do
         if not ck:is_a(e, b.elements) then
            return false, { types.error("%s is not a member of %s", e, b.elements) }
         end
      end
   end
   return true
end

relations.subtype_relations = {
   ["nil"] = {
      ["*"] = compare_true,
   },
   ["tuple"] = {
      ["tuple"] = function(ck, a, b)
         local at, bt = a.tuple, b.tuple
         if #at ~= #bt then
            return false
         end
         for i = 1, #at do
            if not ck:is_a(at[i], bt[i]) then
               return false
            end
         end
         return true
      end,
      ["*"] = function(ck, a, b)
         return ck:is_a(untuple(a), b)
      end,
   },
   ["typevar"] = {
      ["typevar"] = function(ck, a, b)
         if a.typevar == b.typevar then
            return true
         end

         return compare_or_infer_typevar(ck, b.typevar, a, nil, ck.is_a)
      end,
      ["*"] = function(ck, a, b)
         return compare_or_infer_typevar(ck, a.typevar, nil, b, ck.is_a)
      end,
   },
   ["union"] = {
      ["nominal"] = function(ck, a, b)

         local rb = ck:resolve_nominal(b)
         if rb.typename == "union" then
            return ck:is_a(a, rb)
         end

         return forall_are_subtype_of(ck, a, b)
      end,
      ["union"] = function(ck, a, b)
         local used = {}
         for _, t in ipairs(a.types) do
            ck:begin_implied_scope()
            local u = exists_supertype_in(ck, t, b)
            ck:end_implied_scope()
            if not u then
               return false
            end
            if not used[u] then
               used[u] = t
            end
         end
         for u, t in pairs(used) do
            ck:is_a(t, u)
         end
         return true
      end,
      ["*"] = forall_are_subtype_of,
   },
   ["poly"] = {



      ["*"] = function(ck, a, b)
         if exists_supertype_in(ck, b, a) then
            return true
         end
         return false, { errors.new("cannot match against any alternatives of the polymorphic type") }
      end,
   },
   ["nominal"] = {
      ["nominal"] = function(ck, a, b)
         local ok, errs = are_same_nominals(ck, a, b)
         if ok then
            return true
         end

         local ra = ck:resolve_nominal(a)
         local rb = ck:resolve_nominal(b)


         local union_a = ra.typename == "union"
         local union_b = rb.typename == "union"
         if union_a or union_b then
            return ck:is_a(union_a and ra or a, union_b and rb or b)
         end


         if rb.typename == "interface" then
            return a_is_interface_b(ck, a, b)
         end


         return ok, errs
      end,
      ["union"] = function(ck, a, b)

         local ra = ck:resolve_nominal(a)
         if ra.typename == "union" then
            return ck:is_a(ra, b)
         end

         return not not exists_supertype_in(ck, a, b)
      end,
      ["*"] = subtype_nominal,
   },
   ["enum"] = {
      ["string"] = compare_true,
   },
   ["string"] = {
      ["enum"] = function(_ck, a, b)
         if not a.literal then
            return false, { types.error("%s is not a %s", a, b) }
         end

         if b.enumset[a.literal] then
            return true
         end

         return false, { types.error("%s is not a member of %s", a, b) }
      end,
   },
   ["integer"] = {
      ["number"] = compare_true,
   },
   ["interface"] = {
      ["interface"] = function(ck, a, b)
         if is_in_interface_list(ck, a, b) then
            return true
         end
         return ck:same_type(a, b)
      end,
      ["array"] = subtype_array,
      ["tupletable"] = function(ck, a, b)
         return relations.subtype_relations["record"]["tupletable"](ck, a, b)
      end,
      ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
   },
   ["emptytable"] = emptytable_relations,
   ["tupletable"] = {
      ["tupletable"] = function(ck, a, b)
         for i = 1, math.min(#a.types, #b.types) do
            if not ck:is_a(a.types[i], b.types[i]) then
               return false, { types.error("in tuple entry " ..
tostring(i) .. ": got %s, expected %s",
a.types[i], b.types[i]), }
            end
         end
         if #a.types > #b.types then
            return false, { types.error("tuple %s is too big for tuple %s", a, b) }
         end
         return true
      end,
      ["record"] = function(ck, a, b)
         if b.elements then
            return relations.subtype_relations["tupletable"]["array"](ck, a, b)
         end
      end,
      ["array"] = function(ck, a, b)
         if b.inferred_len and b.inferred_len > #a.types then
            return false, { errors.new("incompatible length, expected maximum length of " .. tostring(#a.types) .. ", got " .. tostring(b.inferred_len)) }
         end
         local aa, err = ck:arraytype_from_tuple(a.inferred_at or a, a)
         if not aa then
            return false, err
         end
         if not ck:is_a(aa, b) then
            return false, { types.error("got %s (from %s), expected %s", aa, a, b) }
         end
         return true
      end,
      ["map"] = function(ck, a, b)
         local aa = ck:arraytype_from_tuple(a.inferred_at or a, a)
         if not aa then
            return false, { types.error("Unable to convert tuple %s to map", a) }
         end

         return compare_map(ck, a_type(a, "integer", {}), b.keys, aa.elements, b.values)
      end,
      ["emptytable"] = compare_true_inferring_emptytable,
   },
   ["record"] = {
      ["record"] = subtype_record,
      ["interface"] = function(ck, a, b)
         if is_in_interface_list(ck, a, b) then
            return true
         end
         if not a.declname then

            return subtype_record(ck, a, b)
         end
      end,
      ["array"] = subtype_array,
      ["map"] = function(ck, a, b)
         if not ck:is_a(b.keys, a_type(b, "string", {})) then
            return false, { errors.new("can't match a record to a map with non-string keys") }
         end

         for _, k in ipairs(a.field_order) do
            local bk = b.keys
            if bk.typename == "enum" and not bk.enumset[k] then
               return false, { errors.new("key is not an enum value: " .. k) }
            end
            if not ck:is_a(a.fields[k], b.values) then
               return false, { errors.new("record is not a valid map; not all fields have the same type") }
            end
         end

         return true
      end,
      ["tupletable"] = function(ck, a, b)
         if a.elements then
            return relations.subtype_relations["array"]["tupletable"](ck, a, b)
         end
      end,
      ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
   },
   ["array"] = {
      ["array"] = subtype_array,
      ["record"] = function(ck, a, b)
         if b.elements then
            return subtype_array(ck, a, b)
         end
      end,
      ["map"] = function(ck, a, b)
         return compare_map(ck, a_type(a, "integer", {}), b.keys, a.elements, b.values)
      end,
      ["tupletable"] = function(ck, a, b)
         local alen = a.inferred_len or 0
         if alen > #b.types then
            return false, { errors.new("incompatible length, expected maximum length of " .. tostring(#b.types) .. ", got " .. tostring(alen)) }
         end



         for i = 1, (alen > 0) and alen or #b.types do
            if not ck:is_a(a.elements, b.types[i]) then
               return false, { types.error("tuple entry " .. i .. " of type %s does not match type of array elements, which is %s", b.types[i], a.elements) }
            end
         end
         return true
      end,
      ["emptytable"] = compare_true_inferring_emptytable,
   },
   ["map"] = {
      ["map"] = function(ck, a, b)
         return compare_map(ck, a.keys, b.keys, a.values, b.values)
      end,
      ["array"] = function(ck, a, b)
         return compare_map(ck, a.keys, a_type(b, "integer", {}), a.values, b.elements)
      end,
      ["emptytable"] = compare_true_inferring_emptytable,
   },
   ["typedecl"] = {
      ["*"] = function(ck, a, b)
         return ck:is_a(a.def, b)
      end,
   },
   ["function"] = {
      ["function"] = function(ck, a, b)
         local errs = {}

         local aa, ba = a.args.tuple, b.args.tuple
         if (not b.args.is_va) and (ck.feat_arity and (#aa > #ba and a.min_arity > b.min_arity)) then
            table.insert(errs, types.error("incompatible number of arguments: got " .. show_arity(a) .. " %s, expected " .. show_arity(b) .. " %s", a.args, b.args))
         else
            for i = ((a.is_method or b.is_method) and 2 or 1), #aa do
               local ai = aa[i]
               local bi = ba[i] or (b.args.is_va and ba[#ba])
               if bi then
                  ck:arg_check(nil, errs, ai, bi, "bivariant", "argument", i)
               end
            end
         end

         local ar, br = a.rets.tuple, b.rets.tuple
         local diff_by_va = #br - #ar == 1 and b.rets.is_va
         if #ar < #br and not diff_by_va then
            table.insert(errs, types.error("incompatible number of returns: got " .. #ar .. " %s, expected " .. #br .. " %s", a.rets, b.rets))
         else
            local nrets = #br
            if diff_by_va then
               nrets = nrets - 1
            end
            for i = 1, nrets do
               ck:arg_check(nil, errs, ar[i], br[i], "bivariant", "return", i)
            end
         end

         return errors.any(errs)
      end,
   },
   ["self"] = {
      ["self"] = function(_ck, _a, _b)
         return true
      end,
      ["*"] = function(ck, a, b)
         return ck:is_a(ck:type_of_self(a), b)
      end,
   },
   ["typearg"] = {
      ["typearg"] = function(_ck, a, b)
         return a.typearg == b.typearg
      end,
      ["*"] = function(ck, a, b)
         if a.constraint then
            return ck:is_a(a.constraint, b)
         end
      end,
   },
   ["boolean_context"] = {
      ["boolean"] = compare_true,
   },
   ["generic"] = {
      ["*"] = function(ck, a, b)


         local aa = ck:apply_generic(a, a)
         local ok, errs = ck:is_a(aa, b)

         return ok, errs
      end,
   },
   ["*"] = {
      ["any"] = compare_true,
      ["boolean_context"] = compare_true,
      ["emptytable"] = function(_ck, a, _b)
         return false, { types.error("assigning %s to a variable declared with {}", a) }
      end,
      ["unresolved_emptytable_value"] = function(ck, a, b)
         ck:infer_emptytable_from_unresolved_value(b, b, a)
         return true
      end,
      ["generic"] = function(ck, a, b)


         local bb = ck:apply_generic(b, b)
         local ok, errs = ck:is_a(a, bb)

         return ok, errs
      end,
      ["self"] = function(ck, a, b)
         return ck:is_a(a, (ck:type_of_self(b)))
      end,
      ["tuple"] = function(ck, a, b)
         local tuple = a_type(a, "tuple", { tuple = { a } })
         return ck:is_a(tuple, b)
      end,
      ["typedecl"] = function(ck, a, b)
         return ck:is_a(a, b.def)
      end,
      ["typevar"] = function(ck, a, b)
         return compare_or_infer_typevar(ck, b.typevar, a, nil, ck.is_a)
      end,
      ["typearg"] = function(ck, a, b)
         if b.constraint then
            return ck:is_a(a, b.constraint)
         end
      end,



      ["union"] = exists_supertype_in,
      ["nominal"] = subtype_nominal,



      ["poly"] = function(ck, a, b)
         for _, t in ipairs(b.types) do
            if not ck:is_a(a, t) then
               return false, { errors.new("cannot match against all alternatives of the polymorphic type") }
            end
         end
         return true
      end,
   },
}


relations.type_priorities = {

   ["generic"] = -1,
   ["nil"] = 0,
   ["unresolved_emptytable_value"] = 1,
   ["emptytable"] = 2,
   ["self"] = 3,
   ["tuple"] = 4,
   ["typevar"] = 5,
   ["typedecl"] = 6,
   ["any"] = 7,
   ["boolean_context"] = 8,
   ["union"] = 9,
   ["poly"] = 10,

   ["typearg"] = 11,

   ["nominal"] = 12,

   ["enum"] = 13,
   ["string"] = 13,
   ["integer"] = 13,
   ["boolean"] = 13,

   ["interface"] = 14,

   ["tupletable"] = 15,
   ["record"] = 15,
   ["array"] = 15,
   ["map"] = 15,
   ["function"] = 15,
}

function relations.compare_types(ck, prios, rels, t1, t2)
   if t1.typeid == t2.typeid then
      return true
   end

   local s1 = rels[t1.typename]
   local fn = s1 and s1[t2.typename]
   if not fn then
      local p1 = prios[t1.typename] or 999
      local p2 = prios[t2.typename] or 999
      fn = (p1 < p2 and (s1 and s1["*"]) or (rels["*"][t2.typename]))
   end

   local ok, err
   if fn then
      if fn == compare_true then
         return true
      end
      ok, err = fn(ck, t1, t2)
   else
      ok = t1.typename == t2.typename
   end

   if (not ok) and not err then
      if t1.typename == "invalid" or t2.typename == "invalid" then
         return false, {}
      end
      local show_t1 = show_type(t1)
      local show_t2 = show_type(t2)
      if show_t1 == show_t2 then
         return false, { errors.at(t1, "types are incompatible") }
      else
         return false, { errors.at(t1, "got " .. show_t1 .. ", expected " .. show_t2) }
      end
   end
   return ok, err
end

function relations.lax_type_priorities()
   local copy = shallow_copy_table(relations.type_priorities)
   copy["unknown"] = -10
   return copy
end

function relations.lax_subtype_relations()
   local copy = shallow_copy_table(relations.subtype_relations)

   copy["unknown"] = {}
   copy["unknown"]["*"] = compare_true

   copy["*"] = shallow_copy_table(copy["*"])
   copy["*"]["unknown"] = compare_true

   copy["*"]["boolean"] = compare_true

   return copy
end

return relations

end

-- module teal.check.require_file from teal/check/require_file.lua
package.preload["teal.check.require_file"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local os = _tl_compat and _tl_compat.os or os; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local input = require("teal.input")




local types = require("teal.types")


local a_type = types.a_type





local require_file = {}











require_file.all_extensions = {
   [".d.tl"] = true,
   [".tl"] = true,
   [".lua"] = true,
}

local function search_for(module_name, suffix, path, tried)
   for entry in path:gmatch("[^;]+") do
      local slash_name = module_name:gsub("%.", "/")


      if not entry:match("%?[/\\]init%.lua$") then
         local filename = entry:gsub("?", slash_name)
         local tl_filename = filename:gsub("%.lua$", suffix)
         local fd = io.open(tl_filename, "rb")
         if not fd then
            table.insert(tried, "no file '" .. tl_filename .. "'")


            tl_filename = filename:gsub("%.lua$", "/init" .. suffix)
            fd = io.open(tl_filename, "rb")
            if not fd then
               table.insert(tried, "no file '" .. tl_filename .. "'")
            end
         end

         if fd then
            local code = fd:read("*a")
            if not code then
               return nil, nil, tried
            end
            fd:close()
            return tl_filename, code, tried
         end
      end
   end
   return nil, nil, tried
end

function require_file.search_module(module_name, extension_set)
   local found
   local code
   local tried = {}
   local path = os.getenv("TL_PATH") or package.path

   if extension_set and extension_set[".d.tl"] then
      found, code, tried = search_for(module_name, ".d.tl", path, tried)
      if found then
         return found, code
      end
   end
   if (not extension_set) or extension_set[".tl"] then
      found, code, tried = search_for(module_name, ".tl", path, tried)
      if found then
         return found, code
      end
   end
   if extension_set and extension_set[".lua"] then
      found, code, tried = search_for(module_name, ".lua", path, tried)
      if found then
         return found, code
      end
   end
   return nil, nil, tried
end

local function a_circular_require(w)
   return a_type(w, "typedecl", { def = a_type(w, "circular_require", {}) })
end

function require_file.search_and_load(env, module_name, extension_set)
   local found, code, tried = require_file.search_module(module_name, extension_set)
   if not found then
      return nil, nil, tried
   end

   env.module_filenames[module_name] = found

   local w = { f = found, x = 1, y = 1 }
   env.modules[module_name] = a_circular_require(w)

   local found_result = input.check(env, found, code)
   if not found_result then
      return nil, nil, tried
   end

   env.modules[module_name] = found_result.type

   return found_result, found
end

function require_file.require_module(env, module_name)
   local mod = env.modules[module_name]
   if mod then
      return mod, env.module_filenames[module_name]
   end

   local extensions = require_file.all_extensions
   local found_result, found = require_file.search_and_load(env, module_name, extensions)
   if not found_result then
      return nil
   end

   return found_result.type, found
end

return require_file

end

-- module teal.check.special_functions from teal/check/special_functions.lua
package.preload["teal.check.special_functions"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table





local parser = require("teal.parser")

local node_at = parser.node_at

local types = require("teal.types")

















local a_type = types.a_type
local a_function = types.a_function
local a_vararg = types.a_vararg
local ensure_not_method = types.ensure_not_method
local is_unknown = types.is_unknown

























local function special_pcall_xpcall(self, node, a, b, argdelta)
   local isx = a.special_function_handler == "xpcall"
   local base_nargs = isx and 2 or 1
   local bool = a_type(node, "boolean", {})
   if #node.e2 < base_nargs then
      self:add_error(node, "wrong number of arguments (given " .. #node.e2 .. ", expects at least " .. base_nargs .. ")")
      return a_type(node, "tuple", { tuple = { bool } })
   end

   local ftype = table.remove(b.tuple, 1)




   ftype = ensure_not_method(ftype)

   local fe2 = node_at(node.e2, {})
   if isx then
      base_nargs = 2
      local arg2 = node.e2[2]
      local msgh = table.remove(b.tuple, 1)
      local msgh_type = a_function(arg2, {
         min_arity = self.feat_arity and 1 or 0,
         args = a_type(arg2, "tuple", { tuple = { a_type(arg2, "any", {}) } }),
         rets = a_vararg(arg2, { a_type(arg2, "any", {}) }),
      })
      local ok, errs = self:is_a(msgh, msgh_type)
      if not ok then
         self:add_errors_prefixing(arg2, errs, "in message handler: ")
      end
   end
   for i = base_nargs + 1, #node.e2 do
      table.insert(fe2, node.e2[i])
   end
   local fnode = node_at(node, {
      kind = "op",
      op = { op = "@funcall" },
      e1 = node.e2[1],
      e2 = fe2,
   })
   local rets = self:type_check_funcall(fnode, ftype, b, argdelta + base_nargs)
   if rets.typename == "invalid" then
      return rets
   end
   table.insert(rets.tuple, 1, bool)
   return rets
end

local function pattern_findclassend(pat, i, strict)
   local c = pat:sub(i, i)
   if c == "%" then
      local peek = pat:sub(i + 1, i + 1)
      if peek == "f" then

         if pat:sub(i + 2, i + 2) ~= "[" then
            return nil, nil, "malformed pattern: missing '[' after %f"
         end
         local e, _, err = pattern_findclassend(pat, i + 2, strict)
         if not e then
            return nil, nil, err
         else
            return e, false
         end
      elseif peek == "b" then
         if pat:sub(i + 3, i + 3) == "" then
            return nil, nil, "malformed pattern: need balanced characters"
         end
         return i + 3, false
      elseif peek == "" then
         return nil, nil, "malformed pattern: expected class"
      elseif peek:match("[1-9]") then
         return i + 1, false
      elseif strict and not peek:match("[][^$()%%.*+%-?AaCcDdGgLlPpSsUuWwXxZz]") then
         return nil, nil, "malformed pattern: invalid class '" .. peek .. "'"
      else
         return i + 1, true
      end
   elseif c == "[" then
      if pat:sub(i + 1, i + 1) == "^" then
         i = i + 2
      else
         i = i + 1
      end

      local isfirst = true
      repeat
         local c_ = pat:sub(i, i)
         if c_ == "" then
            return nil, nil, "malformed pattern: missing ']'"
         elseif c_ == "%" then
            if strict and not pat:sub(i + 1, i + 1):match("[][^$()%%.*+%-?AaCcDdGgLlPpSsUuWwXxZz]") then
               return nil, nil, "malformed pattern: invalid escape"
            end
            i = i + 2
         elseif c_ == "-" and strict and not isfirst then
            return nil, nil, "malformed pattern: unexpected '-'"
         else
            local c2 = pat:sub(i + 1, i + 1)
            local c3 = pat:sub(i + 2, i + 2)
            if c2 == "-" then
               if strict and c3 == "]" then
                  return nil, nil, "malformed pattern: unexpected ']'"
               elseif strict and c3 == "-" then
                  return nil, nil, "malformed pattern: unexpected '-'"
               elseif strict and c3 == "%" then
                  return nil, nil, "malformed pattern: unexpected '%'"
               end

               i = i + 2
            else
               i = i + 1
            end
         end
         isfirst = false
      until pat:sub(i, i) == "]"

      return i, true
   else
      return i, true
   end
end

local pattern_isop = {
   ["?"] = true,
   ["+"] = true,
   ["-"] = true,
   ["*"] = true,
}

local function parse_pattern_string(node, pat, inclempty)





















   local strict = false

   local results = {}

   local i = pat:sub(1, 1) == "^" and 2 or 1
   local unclosed = 0

   while i <= #pat do
      local c = pat:sub(i, i)

      if i == #pat and c == "$" then
         break
      end

      local classend, canhavemul, err = pattern_findclassend(pat, i, strict)
      if not classend then
         return nil, err
      end

      local peek = pat:sub(classend + 1, classend + 1)

      if c == "(" and peek == ")" then

         table.insert(results, a_type(node, "integer", {}))
         i = i + 2
      elseif c == "(" then
         table.insert(results, a_type(node, "string", {}))
         unclosed = unclosed + 1
         i = i + 1
      elseif c == ")" then
         unclosed = unclosed - 1
         if unclosed < 0 then
            return nil, "malformed pattern: unexpected ')'"
         end
         i = i + 1
      elseif strict and c:match("[]^$()*+%-?]") then
         return nil, "malformed pattern: character was unexpected: '" .. c .. "'"
      elseif pattern_isop[peek] and canhavemul then
         i = classend + 2
      else

         i = classend + 1
      end
   end

   if inclempty and not results[1] then
      results[1] = a_type(node, "string", {})
   end
   if unclosed ~= 0 then
      return nil, "malformed pattern: " .. unclosed .. " capture" .. (unclosed == 1 and "" or "s") .. " not closed"
   end
   return results
end

local function parse_format_string(node, pat)
   local pos = 1
   local results = {}
   while pos <= #pat do

      local endc = pat:match("%%[-+#0-9. ]*()", pos)
      if not endc then return results end
      local c = pat:sub(endc, endc)
      if c == "" then
         return nil, "missing pattern specifier at end"
      end
      if c:match("[AaEefGg]") then
         table.insert(results, a_type(node, "number", {}))
      elseif c:match("[cdiouXx]") then
         table.insert(results, a_type(node, "integer", {}))
      elseif c == "q" then
         table.insert(results,
         a_type(node, "union", { types = {
            a_type(node, "string", {}),
            a_type(node, "number", {}),
            a_type(node, "integer", {}),
            a_type(node, "boolean", {}),
            a_type(node, "nil", {}),
         } }))

      elseif c == "p" or c == "s" then
         table.insert(results, a_type(node, "any", {}))
      elseif c == "%" then

      else
         return nil, "invalid pattern specifier: '" .. c .. "'"
      end
      pos = endc + 1
   end
   return results
end

local function pack_string_skipnum(pos, pat)

   return pat:match("[0-9]*()", pos)
end

local function parse_pack_string(node, pat)
   local pos = 1
   local results = {}
   local skip_next = false
   while pos <= #pat do
      local c = pat:sub(pos, pos)
      local to_add
      local goto_next
      if c:match("[<> =x]") then

         if skip_next then
            return nil, "expected argument for 'X'"
         end
         pos = pos + 1
         goto_next = true
      elseif c == "X" then
         if skip_next then
            return nil, "expected argument for 'X'"
         end
         skip_next = true
         pos = pos + 1
         goto_next = true
      elseif c == "!" then
         if skip_next then
            return nil, "expected argument for 'X'"
         end
         pos = pack_string_skipnum(pos + 1, pat)
         goto_next = true
      elseif c:match("[Ii]") then
         pos = pack_string_skipnum(pos + 1, pat)
         to_add = a_type(node, "integer", {})
      elseif c:match("[bBhHlLjJT]") then
         pos = pos + 1
         to_add = a_type(node, "integer", {})
      elseif c:match("[fdn]") then
         pos = pos + 1
         to_add = a_type(node, "number", {})
      elseif c == "z" or c == "s" or c == "c" then
         if c == "z" then
            pos = pos + 1
         else
            pos = pack_string_skipnum(pos + 1, pat)
         end

         to_add = a_type(node, "string", {})
      else
         return nil, "invalid format option: '" .. c .. "'"
      end
      if not goto_next then
         if skip_next then
            skip_next = false
         else
            table.insert(results, to_add)
         end
      end
   end
   if skip_next then
      return nil, "expected argument for 'X'"
   end
   return results
end

local special_functions = {
   ["pairs"] = function(self, node, a, b, argdelta)
      if not b.tuple[1] then
         return self:invalid_at(node, "pairs requires an argument")
      end
      local t = self:to_structural(b.tuple[1])
      if t.elements then
         self:add_warning("hint", node, "hint: applying pairs on an array: did you intend to apply ipairs?")
      end

      if not (t.typename == "map") then
         if not (self.feat_lax and is_unknown(t)) then
            if t.fields then
               self:match_all_record_field_names(node.e2, t, t.field_order,
               "attempting pairs on a record with attributes of different types")
               local ct = t.typename == "record" and "{string:any}" or "{any:any}"
               self:add_warning("hint", node.e2, "hint: if you want to iterate over fields of a record, cast it to " .. ct)
            else
               self:add_error(node.e2, "cannot apply pairs on values of type: %s", t)
            end
         end
      end

      return (self:type_check_function_call(node, a, b, argdelta))
   end,

   ["ipairs"] = function(self, node, a, b, argdelta)
      if not b.tuple[1] then
         return self:invalid_at(node, "ipairs requires an argument")
      end
      local orig_t = b.tuple[1]
      local t = self:to_structural(orig_t)

      if t.typename == "tupletable" then
         local arr_type = self:arraytype_from_tuple(node.e2, t)
         if not arr_type then
            return self:invalid_at(node.e2, "attempting ipairs on tuple that's not a valid array: %s", orig_t)
         end
      elseif not t.elements then
         if not (self.feat_lax and (is_unknown(t) or t.typename == "emptytable")) then
            return self:invalid_at(node.e2, "attempting ipairs on something that's not an array: %s", orig_t)
         end
      end

      return (self:type_check_function_call(node, a, b, argdelta))
   end,

   ["rawget"] = function(self, node, _a, b, _argdelta)

      if #b.tuple == 2 then
         return a_type(node, "tuple", { tuple = { self:type_check_index(node.e2[1], node.e2[2], b.tuple[1], b.tuple[2]) } })
      else
         return self:invalid_at(node, "rawget expects two arguments")
      end
   end,

   ["require"] = function(self, node, _a, b, _argdelta)
      if #b.tuple ~= 1 then
         return self:invalid_at(node, "require expects one literal argument")
      end
      if node.e2[1].kind ~= "string" then
         return a_type(node, "tuple", { tuple = { a_type(node, "any", {}) } })
      end

      local module_name = assert(node.e2[1].conststr)
      local t, module_filename = self.env:require_module(module_name)
      if not t then
         return self:invalid_at(node, "module not found: '" .. module_name .. "'")
      end

      if self.feat_lax then
         if t.typename == "invalid" then
            return a_type(node, "tuple", { tuple = { a_type(node, "unknown", {}) } })
         end
      elseif module_filename and module_filename:match("%.lua$") then
         return self:invalid_at(node, "no type information for required module: '" .. module_name .. "'")
      end

      self.dependencies[module_name] = module_filename
      return a_type(node, "tuple", { tuple = { t } })
   end,

   ["pcall"] = special_pcall_xpcall,
   ["xpcall"] = special_pcall_xpcall,
   ["assert"] = function(self, node, a, b, argdelta)
      self.fdb:set_truthy(node)
      local r = self:type_check_function_call(node, a, b, argdelta)
      if node.e2[1] then
         self:apply_facts_from(node, node.e2[1])
      end
      return r
   end,
   ["string.pack"] = function(self, node, a, b, argdelta)
      if #b.tuple < 1 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects at least 1)")
      end

      local packstr = b.tuple[1]

      if packstr.typename == "string" and packstr.literal and a.typename == "function" then
         local st = packstr.literal
         local items, e = parse_pack_string(node, st)

         if e then
            if items then

               self:add_warning("hint", packstr, e)
            else
               return self:invalid_at(packstr, e)
            end
         end

         table.insert(items, 1, a_type(node, "string", {}))

         if #items ~= #b.tuple then
            return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects " .. #items .. ")")
         end

         return (self:type_check_function_call(node, a, b, argdelta, a_type(node, "tuple", { tuple = items }), nil))
      else
         return (self:type_check_function_call(node, a, b, argdelta))
      end
   end,

   ["string.unpack"] = function(self, node, a, b, argdelta)
      if #b.tuple < 2 or #b.tuple > 3 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 2 or 3)")
      end

      local packstr = b.tuple[1]

      local rets

      if packstr.typename == "string" and packstr.literal then
         local st = packstr.literal
         local items, e = parse_pack_string(node, st)

         if e then
            if items then

               self:add_warning("hint", packstr, e)
            else
               return self:invalid_at(packstr, e)
            end
         end

         table.insert(items, a_type(node, "integer", {}))


         rets = a_type(node, "tuple", { tuple = items })
      end

      return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
   end,

   ["string.format"] = function(self, node, a, b, argdelta)
      if #b.tuple < 1 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects at least 1)")
      end

      local fstr = b.tuple[1]

      if fstr.typename == "string" and fstr.literal and a.typename == "function" then
         local st = fstr.literal
         local items, e = parse_format_string(node, st)

         if e then
            if items then

               self:add_warning("hint", fstr, e)
            else
               return self:invalid_at(fstr, e)
            end
         end

         table.insert(items, 1, a_type(node, "string", {}))

         if #items ~= #b.tuple then
            return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects " .. #items .. ")")
         end


         return (self:type_check_function_call(node, a, b, argdelta, a_type(node, "tuple", { tuple = items }), nil))
      else
         return (self:type_check_function_call(node, a, b, argdelta))
      end
   end,

   ["string.match"] = function(self, node, a, b, argdelta)
      if #b.tuple < 2 or #b.tuple > 3 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 2 or 3)")
      end

      local rets
      local pat = b.tuple[2]

      if pat.typename == "string" and pat.literal then
         local st = pat.literal
         local items, e = parse_pattern_string(node, st, true)

         if e then
            if items then

               self:add_warning("hint", pat, e)
            else
               return self:invalid_at(pat, e)
            end
         end


         rets = a_type(node, "tuple", { tuple = items })
      end
      return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
   end,

   ["string.find"] = function(self, node, a, b, argdelta)
      if #b.tuple < 2 or #b.tuple > 4 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects at least 2 and at most 4)")
      end

      local plainarg = node.e2[4 + (argdelta or 0)]
      local pat = b.tuple[2]

      local rets

      if pat.typename == "string" and pat.literal and
         ((not plainarg) or (plainarg.kind == "boolean" and plainarg.tk == "false")) then

         local st = pat.literal

         local items, e = parse_pattern_string(node, st, false)

         if e then
            if items then

               self:add_warning("hint", pat, e)
            else
               return self:invalid_at(pat, e)
            end
         end

         table.insert(items, 1, a_type(pat, "integer", {}))
         table.insert(items, 1, a_type(pat, "integer", {}))


         rets = a_type(node, "tuple", { tuple = items })
      end

      return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
   end,

   ["string.gmatch"] = function(self, node, a, b, argdelta)
      if #b.tuple < 2 or #b.tuple > 3 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 2 or 3)")
      end

      local rets
      local pat = b.tuple[2]

      if pat.typename == "string" and pat.literal then
         local st = pat.literal
         local items, e = parse_pattern_string(node, st, true)

         if e then
            if items then

               self:add_warning("hint", pat, e)
            else
               return self:invalid_at(pat, e)
            end
         end


         rets = a_type(node, "tuple", { tuple = {
            a_function(node, {
               min_arity = 0,
               args = a_type(node, "tuple", { tuple = {} }),
               rets = a_type(node, "tuple", { tuple = items }),
            }),
         } })
      end

      return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
   end,

   ["string.gsub"] = function(self, node, a, b, argdelta)



      if #b.tuple < 3 or #b.tuple > 4 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 3 or 4)")
      end
      local pat = b.tuple[2]
      local orig_t = b.tuple[3]
      local trepl = self:to_structural(orig_t)

      local has_fourth = b.tuple[4]

      local args

      if pat.typename == "string" and pat.literal then
         local st = pat.literal
         local items, e = parse_pattern_string(node, st, true)

         if e then
            if items then

               self:add_warning("hint", pat, e)
            else
               return self:invalid_at(pat, e)
            end
         end

         local i1 = items[1]






         local replarg_type

         local expected_pat_return = a_type(node, "union", { types = {
            a_type(node, "string", {}),
            a_type(node, "integer", {}),
            a_type(node, "number", {}),
         } })
         if self:is_a(trepl, expected_pat_return) then

            replarg_type = expected_pat_return
         elseif trepl.typename == "map" then
            replarg_type = a_type(node, "map", { keys = i1, values = expected_pat_return })
         elseif trepl.fields then
            if not (i1.typename == "string") then
               self:invalid_at(trepl, "expected a table with integers as keys")
            end
            replarg_type = a_type(node, "map", { keys = i1, values = expected_pat_return })
         elseif trepl.elements then
            if not (i1.typename == "integer") then
               self:invalid_at(trepl, "expected a table with strings as keys")
            end
            replarg_type = a_type(node, "array", { elements = expected_pat_return })
         elseif trepl.typename == "function" then
            local validftype = a_function(node, {
               min_arity = self.feat_arity and #items or 0,
               args = a_type(node, "tuple", { tuple = items }),
               rets = a_vararg(node, { expected_pat_return }),
            })
            replarg_type = validftype
         end


         if replarg_type then
            args = a_type(node, "tuple", { tuple = {
               a_type(node, "string", {}),
               a_type(node, "string", {}),
               replarg_type,
               has_fourth and a_type(node, "integer", {}) or nil,
            } })
         end
      end

      return (self:type_check_function_call(node, a, b, argdelta, args, nil))
   end,
}

return special_functions

end

-- module teal.check.visitors from teal/check/visitors.lua
package.preload["teal.check.visitors"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table





local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG




local types = require("teal.types")































local a_type = types.a_type
local a_function = types.a_function
local a_vararg = types.a_vararg
local drop_constant_value = types.drop_constant_value
local edit_type = types.edit_type
local ensure_not_method = types.ensure_not_method
local is_unknown = types.is_unknown
local is_valid_union = types.is_valid_union
local show_type = types.show_type
local simple_types = types.simple_types
local type_at = types.type_at
local typedecl_to_nominal = types.typedecl_to_nominal
local unite = types.unite
local untuple = types.untuple
local wrap_generic_if_typeargs = types.wrap_generic_if_typeargs

local parser = require("teal.parser")


local node_at = parser.node_at
local node_is_funcall = parser.node_is_funcall

local facts = require("teal.facts")
local IsFact = facts.IsFact
local facts_not = facts.facts_not

local macroexps = require("teal.macroexps")

local metamethods = require("teal.metamethods")
local unop_to_metamethod = metamethods.unop_to_metamethod
local binop_to_metamethod = metamethods.binop_to_metamethod
local flip_binop_to_metamethod = metamethods.flip_binop_to_metamethod

local traversal = require("teal.traversal")

local traverse_nodes = traversal.traverse_nodes
local fields_of = traversal.fields_of

local type_errors = require("teal.type_errors")

local ensure_not_abstract = type_errors.ensure_not_abstract




local util = require("teal.util")
local sorted_keys = util.sorted_keys



local visitors = {}




visitors.visit_node = {}
visitors.visit_type = {}
local visit_node = visitors.visit_node
local visit_type = visitors.visit_type






























local numeric_binop = {
   ["number"] = {
      ["number"] = "number",
      ["integer"] = "number",
   },
   ["integer"] = {
      ["integer"] = "integer",
      ["number"] = "number",
   },
}

local float_binop = {
   ["number"] = {
      ["number"] = "number",
      ["integer"] = "number",
   },
   ["integer"] = {
      ["integer"] = "number",
      ["number"] = "number",
   },
}

local integer_binop = {
   ["number"] = {
      ["number"] = "integer",
      ["integer"] = "integer",
   },
   ["integer"] = {
      ["integer"] = "integer",
      ["number"] = "integer",
   },
}

local relational_binop = {
   ["number"] = {
      ["integer"] = "boolean",
      ["number"] = "boolean",
   },
   ["integer"] = {
      ["number"] = "boolean",
      ["integer"] = "boolean",
   },
   ["string"] = {
      ["string"] = "boolean",
   },
   ["boolean"] = {
      ["boolean"] = "boolean",
   },
}

local equality_binop = {
   ["number"] = {
      ["number"] = "boolean",
      ["integer"] = "boolean",
      ["nil"] = "boolean",
   },
   ["integer"] = {
      ["number"] = "boolean",
      ["integer"] = "boolean",
      ["nil"] = "boolean",
   },
   ["string"] = {
      ["string"] = "boolean",
      ["nil"] = "boolean",
   },
   ["boolean"] = {
      ["boolean"] = "boolean",
      ["nil"] = "boolean",
   },
   ["record"] = {
      ["emptytable"] = "boolean",
      ["record"] = "boolean",
      ["nil"] = "boolean",
   },
   ["array"] = {
      ["emptytable"] = "boolean",
      ["array"] = "boolean",
      ["nil"] = "boolean",
   },
   ["map"] = {
      ["emptytable"] = "boolean",
      ["map"] = "boolean",
      ["nil"] = "boolean",
   },
   ["thread"] = {
      ["thread"] = "boolean",
      ["nil"] = "boolean",
   },
}

local unop_types = {
   ["#"] = {
      ["enum"] = "integer",
      ["string"] = "integer",
      ["array"] = "integer",
      ["tupletable"] = "integer",
      ["map"] = "integer",
      ["emptytable"] = "integer",
   },
   ["-"] = {
      ["number"] = "number",
      ["integer"] = "integer",
   },
   ["~"] = {
      ["number"] = "integer",
      ["integer"] = "integer",
   },
   ["not"] = {
      ["string"] = "boolean",
      ["number"] = "boolean",
      ["integer"] = "boolean",
      ["boolean"] = "boolean",
      ["record"] = "boolean",
      ["array"] = "boolean",
      ["tupletable"] = "boolean",
      ["map"] = "boolean",
      ["emptytable"] = "boolean",
      ["thread"] = "boolean",
   },
}

local binop_types = {
   ["+"] = numeric_binop,
   ["-"] = numeric_binop,
   ["*"] = numeric_binop,
   ["%"] = numeric_binop,
   ["/"] = float_binop,
   ["//"] = numeric_binop,
   ["^"] = float_binop,
   ["&"] = integer_binop,
   ["|"] = integer_binop,
   ["<<"] = integer_binop,
   [">>"] = integer_binop,
   ["~"] = integer_binop,
   ["=="] = equality_binop,
   ["~="] = equality_binop,
   ["<="] = relational_binop,
   [">="] = relational_binop,
   ["<"] = relational_binop,
   [">"] = relational_binop,
   ["or"] = {
      ["boolean"] = {
         ["boolean"] = "boolean",
      },
      ["number"] = {
         ["integer"] = "number",
         ["number"] = "number",
         ["boolean"] = "boolean",
      },
      ["integer"] = {
         ["integer"] = "integer",
         ["number"] = "number",
         ["boolean"] = "boolean",
      },
      ["string"] = {
         ["string"] = "string",
         ["boolean"] = "boolean",
         ["enum"] = "string",
      },
      ["function"] = {
         ["boolean"] = "boolean",
      },
      ["array"] = {
         ["boolean"] = "boolean",
      },
      ["record"] = {
         ["boolean"] = "boolean",
      },
      ["map"] = {
         ["boolean"] = "boolean",
      },
      ["enum"] = {
         ["string"] = "string",
      },
      ["thread"] = {
         ["boolean"] = "boolean",
      },
   },
   [".."] = {
      ["string"] = {
         ["string"] = "string",
         ["enum"] = "string",
         ["number"] = "string",
         ["integer"] = "string",
      },
      ["number"] = {
         ["integer"] = "string",
         ["number"] = "string",
         ["string"] = "string",
         ["enum"] = "string",
      },
      ["integer"] = {
         ["integer"] = "string",
         ["number"] = "string",
         ["string"] = "string",
         ["enum"] = "string",
      },
      ["enum"] = {
         ["number"] = "string",
         ["integer"] = "string",
         ["string"] = "string",
         ["enum"] = "string",
      },
   },
}

local function resolve_typedecl(t)
   if t.typename == "typedecl" then
      return t.def
   else
      return t
   end
end


local NONE = a_type({ f = "@none", x = -1, y = -1 }, "none", {})

local function end_scope_and_none_type(self, node, _children)
   self:end_scope(node)
   return NONE
end

local is_lua_table_type

do
   local known_table_types = {
      array = true,
      map = true,
      record = true,
      tupletable = true,
      interface = true,
   }


   is_lua_table_type = function(t)
      return known_table_types[t.typename] and
      not (t.fields and t.is_userdata)
   end
end

local function type_is_closable(t)
   if t.typename == "invalid" then
      return false
   end
   if t.typename == "nil" then
      return true
   end
   if t.typename == "nominal" then
      t = assert(t.resolved)
   end
   if t.fields then
      return t.meta_fields and t.meta_fields["__close"] ~= nil
   end
end

local definitely_not_closable_exprs = {
   ["string"] = true,
   ["number"] = true,
   ["integer"] = true,
   ["boolean"] = true,
   ["literal_table"] = true,
}
local function expr_is_definitely_not_closable(e)
   return definitely_not_closable_exprs[e.kind]
end

local function make_is_node(self, var, v, t)
   local node = node_at(var, { kind = "op", op = { op = "is", arity = 2, prec = 3 } })
   node.e1 = var
   node.e2 = node_at(var, { kind = "cast", casttype = self:infer_at(var, t) })
   local _, has = self:check_metamethod(node, "__is", self:to_structural(v), self:to_structural(t), v, t)
   if node.expanded then
      macroexps.apply(node)
   end
   self.fdb:set_is(node, var.tk, t)
   return node, has
end

local function convert_is_of_union_to_or_of_is(self, node, v, u)
   local var = node.e1
   node.op.op = "or"
   node.op.arity = 2
   node.op.prec = 1
   local has_any = nil
   node.e1, has_any = make_is_node(self, var, v, u.types[1])
   local at = node
   local n = #u.types
   for i = 2, n - 1 do
      at.e2 = node_at(var, { kind = "op", op = { op = "or", arity = 2, prec = 1 } })
      local has
      at.e2.e1, has = make_is_node(self, var, v, u.types[i])
      has_any = has_any or has
      self.fdb:set_or(node, at.e1, at.e2)
      at = at.e2
   end
   at.e2 = make_is_node(self, var, v, u.types[n])
   self.fdb:set_or(node, at.e1, at.e2)
   return not not has_any
end

local function flat_tuple(w, vt)
   local n_vals = #vt
   local ret = a_type(w, "tuple", { tuple = {} })
   local rt = ret.tuple

   if n_vals == 0 then
      return ret
   end


   for i = 1, n_vals - 1 do
      rt[i] = untuple(vt[i])
   end

   local last = vt[n_vals]
   if last.typename == "tuple" then

      local lt = last.tuple
      for _, v in ipairs(lt) do
         table.insert(rt, v)
      end
      ret.is_va = last.is_va
   else
      rt[n_vals] = vt[n_vals]
   end

   return ret
end

local function get_assignment_values(w, vals, wanted)
   if vals == nil then
      return a_type(w, "tuple", { tuple = {} })
   end


   if vals.is_va then
      local vt = vals.tuple
      local n_vals = #vt
      if n_vals > 0 and n_vals < wanted then
         local last = vt[n_vals]
         local ret = a_type(w, "tuple", { tuple = {} })
         local rt = ret.tuple
         for i = 1, n_vals do
            table.insert(rt, vt[i])
         end
         for _ = n_vals + 1, wanted do
            table.insert(rt, last)
         end
         return ret
      end
   end
   return vals
end


local function is_localizing_a_variable(node, i)
   return node.exps and
   node.exps[i] and
   node.exps[i].kind == "variable" and
   node.exps[i].tk == node.vars[i].tk
end

local function set_expected_types_to_decltuple(self, node, children)
   local decltuple = node.kind == "assignment" and children[1] or node.decltuple
   assert(decltuple.typename == "tuple")
   local decls = decltuple.tuple
   if decls and node.exps then
      local ndecl = #decls
      local nexps = #node.exps
      for i = 1, nexps do
         local typ
         typ = decls[i]
         if typ then
            if i == nexps and ndecl > nexps and node_is_funcall(node.exps[i]) then
               typ = a_type(node, "tuple", { tuple = {} })
               for a = i, ndecl do
                  table.insert(typ.tuple, decls[a])
               end
            end
            node.exps[i].expected = typ
            node.exps[i].expected_context = { kind = node.kind, name = node.vars[i].tk }
         end
      end
   end

   if node.decltuple then
      local ndecltuple = #node.decltuple.tuple
      local nvars = #node.vars
      if ndecltuple > nvars then
         self.errs:add(node.decltuple.tuple[nvars + 1], "number of types exceeds number of variables")
      end
   end
end

local function is_positive_int(n)
   return n and n >= 1 and math.floor(n) == n
end

local function infer_table_literal(self, node, children)
   local is_record = false
   local is_array = false
   local is_map = false

   local is_tuple = false
   local is_not_tuple = false

   local last_array_idx = 1
   local largest_array_idx = -1

   local seen_keys = {}


   local typs

   local fields
   local field_order

   local elements

   local keys, values

   for i, child in ipairs(children) do
      local ck = child.kname
      local cktype = child.ktype
      local key = ck
      local n
      if not key then
         n = node[i].key.constnum
         key = n
         if not key and node[i].key.kind == "boolean" then
            key = (node[i].key.tk == "true")
         end
      end

      self.errs:check_redeclared_key(node[i], nil, seen_keys, key)

      local uvtype = untuple(child.vtype)
      if ck then
         is_record = true
         if not fields then
            fields = {}
            field_order = {}
         end
         fields[ck] = uvtype
         table.insert(field_order, ck)
      elseif is_numeric_type(cktype) then
         is_array = true
         if not is_not_tuple then
            is_tuple = true
         end
         if not typs then
            typs = {}
         end

         if node[i].key_parsed == "implicit" then
            local cv = child.vtype
            if i == #children and cv.typename == "tuple" then

               for _, c in ipairs(cv.tuple) do
                  elements = self:expand_type(node, elements, c)
                  typs[last_array_idx] = untuple(c)
                  last_array_idx = last_array_idx + 1
               end
            else
               typs[last_array_idx] = uvtype
               last_array_idx = last_array_idx + 1
               elements = self:expand_type(node, elements, uvtype)
            end
         else
            if not is_positive_int(n) then
               elements = self:expand_type(node, elements, uvtype)
               is_not_tuple = true
            elseif n then
               typs[n] = uvtype
               if n > largest_array_idx then
                  largest_array_idx = n
               end
               elements = self:expand_type(node, elements, uvtype)
            end
         end

         if last_array_idx > largest_array_idx then
            largest_array_idx = last_array_idx
         end
         if not elements then
            is_array = false
         end
      else
         is_map = true
         keys = self:expand_type(node, keys, drop_constant_value(cktype))
         values = self:expand_type(node, values, uvtype)
      end
   end

   local t

   if is_array and is_map then
      self.errs:add(node, "cannot determine type of table literal")
      t = a_type(node, "map", { keys =
self:expand_type(node, keys, a_type(node, "integer", {})), values =

self:expand_type(node, values, elements) })
   elseif is_record and is_array then
      t = a_type(node, "record", {
         fields = fields,
         field_order = field_order,
         elements = elements,
         interface_list = {
            a_type(node, "array", { elements = elements }),
         },
      })

   elseif is_record and is_map then
      if keys.typename == "string" then
         for _, fname in ipairs(field_order) do
            values = self:expand_type(node, values, fields[fname])
         end
         t = a_type(node, "map", { keys = keys, values = values })
      else
         self.errs:add(node, "cannot determine type of table literal")
      end
   elseif is_array then
      local pure_array = true
      if not is_not_tuple then
         local last_t
         for _, current_t in pairs(typs) do
            if last_t then
               if not self:same_type(last_t, current_t) then
                  pure_array = false
                  break
               end
            end
            last_t = current_t
         end
      end
      if pure_array then
         t = a_type(node, "array", { elements = elements })
         t.consttypes = typs
         t.inferred_len = largest_array_idx - 1
      else
         t = a_type(node, "tupletable", { inferred_at = node })
         t.types = typs
      end
   elseif is_record then
      t = a_type(node, "record", {
         fields = fields,
         field_order = field_order,
      })
   elseif is_map then
      t = a_type(node, "map", { keys = keys, values = values })
   elseif is_tuple then
      t = a_type(node, "tupletable", { inferred_at = node })
      t.types = typs
      if not typs or #typs == 0 then
         self.errs:add(node, "cannot determine type of tuple elements")
      end
   end

   if not t then
      t = a_type(node, "emptytable", {})
   end

   return type_at(node, t)
end

local function total_check_key(key, seen_keys, is_total, missing)
   if not seen_keys[key] then
      missing = missing or {}
      table.insert(missing, tostring(key))
      return false, missing
   end
   return is_total, missing
end

local function total_record_check(t, seen_keys)
   local is_total = true
   local missing
   for _, key in ipairs(t.field_order) do
      local ftype = t.fields[key]
      if not (ftype.typename == "typedecl" or (ftype.typename == "function" and ftype.is_record_function)) then
         is_total, missing = total_check_key(key, seen_keys, is_total, missing)
      end
   end
   return is_total, missing
end

local function total_map_check(keys, seen_keys)
   local is_total = true
   local missing
   if keys.typename == "enum" then
      for _, key in ipairs(sorted_keys(keys.enumset)) do
         is_total, missing = total_check_key(key, seen_keys, is_total, missing)
      end
   elseif keys.typename == "boolean" then
      for _, key in ipairs({ true, false }) do
         is_total, missing = total_check_key(key, seen_keys, is_total, missing)
      end
   else
      is_total = false
   end
   return is_total, missing
end

local function discard_tuple(node, t, b)
   if b.typename == "tuple" then
      node.discarded_tuple = true
   end
   return untuple(t)
end

local function assert_is_a(ctx, w, t1, t2, ectx, name)
   t1 = untuple(t1)
   t2 = untuple(t2)

   if t2.typename == "emptytable" then
      t2 = type_at(w, t2)
   end

   local ok, errs = ctx:is_a(t1, t2)
   if not ok then
      ctx.errs:add_prefixing(w, errs, ctx.errs:get_context(ectx, name))
   end
   return ok
end

visit_node.cbs = {
   ["statements"] = {
      before = function(self, node)
         self:begin_scope(node)
      end,
      after = function(self, node, _children)

         if #self.st == 2 then
            self.errs:fail_unresolved_labels(self.st[2])
            self.errs:fail_unresolved_nominals(self.st[2], self.st[1])
         end

         if not node.is_repeat then
            self:end_scope(node)
         end

         return NONE
      end,
   },
   ["local_type"] = {
      before = function(self, node)
         local name = node.var.tk
         local resolved, aliasing = self:get_typedecl(node.value)
         local var = self:add_var(node.var, name, resolved, node.var.attribute)
         if aliasing then
            var.aliasing = aliasing
         end
      end,
      after = function(self, node, _children)
         self:dismiss_unresolved(node.var.tk)
         return NONE
      end,
   },
   ["global_type"] = {
      before = function(self, node)
         local global_scope = self.st[1]
         local name = node.var.tk
         if node.value then
            local resolved, aliasing = self:get_typedecl(node.value)
            local added = self:add_global(node.var, name, resolved)
            if resolved.typename == "invalid" then
               return
            end
            node.value.newtype = resolved
            if aliasing then
               added.aliasing = aliasing
            end

            if global_scope.pending_global_types[name] then
               global_scope.pending_global_types[name] = nil
            end
         else
            if not self.st[1].vars[name] then
               global_scope.pending_global_types[name] = true
            end
         end
      end,
      after = function(self, node, _children)
         self:dismiss_unresolved(node.var.tk)
         return NONE
      end,
   },
   ["local_declaration"] = {
      before = function(self, node)
         if self.collector then
            for _, var in ipairs(node.vars) do
               self.collector.reserve_symbol_list_slot(var)
            end
         end
      end,
      before_exp = set_expected_types_to_decltuple,
      after = function(self, node, children)
         local valtuple = children[3]

         local encountered_close = false
         local infertypes = get_assignment_values(node, valtuple, #node.vars)
         for i, var in ipairs(node.vars) do
            if var.attribute == "close" then
               if self.env.opts.gen_target ~= "5.4" then
                  self.errs:add(var, "<close> attribute is only valid for Lua 5.4 (current target is " .. tostring(self.env.opts.gen_target) .. ")")
               end
               if encountered_close then
                  self.errs:add(var, "only one <close> per declaration is allowed")
               else
                  encountered_close = true
               end
            end

            local ok, t = self:determine_declaration_type(var, node, infertypes, i)

            if var.attribute == "close" then
               if not type_is_closable(t) then
                  self.errs:add(var, "to-be-closed variable " .. var.tk .. " has a non-closable type %s", t)
               elseif node.exps and node.exps[i] and expr_is_definitely_not_closable(node.exps[i]) then
                  self.errs:add(var, "to-be-closed variable " .. var.tk .. " assigned a non-closable value")
               end
            end

            assert(var)
            self:add_var(var, var.tk, t, var.attribute, is_localizing_a_variable(node, i) and "localizing")
            if var.elide_type then
               self.errs:add_warning("hint", node, "hint: consider using 'local type' instead")
            end

            local infertype = infertypes.tuple[i]
            if ok and infertype then
               local w = node.exps[i] or node.exps

               local rt = self:to_structural(t)
               if (not (rt.typename == "enum")) and
                  ((not (t.typename == "nominal")) or (rt.typename == "union")) and
                  not self:same_type(t, infertype) then

                  t = self:infer_at(w, infertype)
                  self:add_var(w, var.tk, t, "const", "narrowed_declaration")
               end
            end

            if self.collector then
               self.collector.store_type(var.y, var.x, t)
            end

            self:dismiss_unresolved(var.tk)
         end
         return NONE
      end,
   },
   ["global_declaration"] = {
      before_exp = set_expected_types_to_decltuple,
      after = function(self, node, children)
         local valtuple = children[3]

         local infertypes = get_assignment_values(node, valtuple, #node.vars)
         for i, var in ipairs(node.vars) do
            local _, t, is_inferred = self:determine_declaration_type(var, node, infertypes, i)

            if var.attribute == "close" then
               self.errs:add(var, "globals may not be <close>")
            end

            self:add_global(var, var.tk, t, is_inferred)
            if var.elide_type then
               self.errs:add_warning("hint", node, "hint: consider using 'global type' instead")
            end

            self:dismiss_unresolved(var.tk)
         end
         return NONE
      end,
   },
   ["assignment"] = {
      before_exp = set_expected_types_to_decltuple,
      after = function(self, node, children)
         local vartuple = children[1]
         assert(vartuple.typename == "tuple")
         local vartypes = vartuple.tuple
         local valtuple = children[3]
         assert(valtuple.typename == "tuple")
         local valtypes = get_assignment_values(node, valtuple, #vartypes)
         for i, vartype in ipairs(vartypes) do
            local varnode = node.vars[i]
            local varname = varnode.tk
            local valtype = valtypes.tuple[i]
            local rvar, rval, err = self:check_assignment(varnode, vartype, valtype)
            if err == "missing" then
               if #node.exps == 1 and node_is_funcall(node.exps[1]) then
                  local msg = #valtuple.tuple == 1 and
                  "only 1 value is returned by the function" or
                  ("only " .. #valtuple.tuple .. " values are returned by the function")
                  self.errs:add_warning("hint", varnode, msg)
               end
            end

            if rval and rvar then

               if rval.typename == "function" then
                  self:widen_all_unions()
               end

               if varname and (rvar.typename == "union" or rvar.typename == "interface") then

                  self:add_var(varnode, varname, valtype, nil, "narrow")
               end

               if self.collector then
                  self.collector.store_type(varnode.y, varnode.x, valtype)
               end
            end
         end

         return NONE
      end,
   },
   ["if"] = {
      after = function(self, node, _children)
         if node.if_widens then


            self:widen_all(node.if_widens, {})
         end

         local all_return = true
         for _, b in ipairs(node.if_blocks) do
            if not b.block_returns then
               all_return = false
               break
            end
         end
         if all_return then
            node.block_returns = true
            self:infer_negation_of_if_blocks(node, node, #node.if_blocks)
         end

         return NONE
      end,
   },
   ["if_block"] = {
      before = function(self, node)
         self:begin_scope(node)
         if node.if_block_n > 1 then
            self:infer_negation_of_if_blocks(node, node.if_parent, node.if_block_n - 1)
         end
         if node.exp then
            node.exp.expected = a_type(node, "boolean_context", {})
         end
      end,
      before_statements = function(self, node)
         if node.exp then
            self:apply_facts_from(node.exp)
         end
      end,
      after = function(self, node, _children)
         node.if_parent.if_widens = self:collect_if_widens(node.if_parent.if_widens)

         self:end_scope(node)

         if #node.body > 0 and node.body[#node.body].block_returns then
            node.block_returns = true
         end

         return NONE
      end,
   },
   ["while"] = {
      before = function(self, node)

         self:widen_all_unions(node)
         node.exp.expected = a_type(node, "boolean_context", {})
      end,
      before_statements = function(self, node)
         self:begin_scope(node)
         self:apply_facts_from(node.exp)
      end,
      after = end_scope_and_none_type,
   },
   ["label"] = {
      before = function(self, node)

         self:widen_all_unions()
         local label_id = node.label
         do
            local scope = self.st[#self.st]
            scope.labels = scope.labels or {}
            if scope.labels[label_id] then
               self.errs:add(node, "label '" .. node.label .. "' already defined")
            else
               scope.labels[label_id] = node
            end
         end


         local scope = self.st[#self.st]
         if scope.pending_labels and scope.pending_labels[label_id] then
            node.used_label = true
            scope.pending_labels[label_id] = nil

         end

      end,
      after = function()
         return NONE
      end,
   },
   ["goto"] = {
      after = function(self, node, _children)
         local label_id = node.label
         local found_label
         for i = #self.st, 1, -1 do
            local scope = self.st[i]
            if scope.labels and scope.labels[label_id] then
               found_label = scope.labels[label_id]
               break
            end
         end

         if found_label then
            found_label.used_label = true
         else
            local scope = self.st[#self.st]
            scope.pending_labels = scope.pending_labels or {}
            scope.pending_labels[label_id] = scope.pending_labels[label_id] or {}
            table.insert(scope.pending_labels[label_id], node)
         end

         return NONE
      end,
   },
   ["repeat"] = {
      before = function(self, node)

         self:widen_all_unions(node)
         node.exp.expected = a_type(node, "boolean_context", {})
      end,

      after = end_scope_and_none_type,
   },
   ["forin"] = {
      before = function(self, node)
         self:begin_scope(node)
      end,
      before_statements = function(self, node, children)
         local exptuple = children[2]
         assert(exptuple.typename == "tuple")
         local exptypes = exptuple.tuple

         local exp1 = node.exps[1]
         if #exptypes < 1 then
            self.errs:invalid_at(exp1, "expression in 'for' statement does not return any values")
            return
         end

         self:widen_all_unions(node)

         local args = a_type(node.exps, "tuple", { tuple = {
            node.exps[2] and exptypes[2],
            node.exps[3] and exptypes[3],
         } })
         local exp1type = self:resolve_for_call(exptypes[1], args, false)

         if exp1type.typename == "poly" then
            local _r, f
            _r, f = self:type_check_function_call(exp1, exp1type, args, 0, nil, nil, exp1, { node.exps[2], node.exps[3] })
            if f then
               exp1type = f
            else
               self.errs:add(exp1, "cannot resolve polymorphic function given arguments")
            end
         end

         if exp1type.typename == "function" then

            local last
            local rets = exp1type.rets
            for i, v in ipairs(node.vars) do
               local r = rets.tuple[i]
               if not r then
                  if rets.is_va then
                     r = last
                  else
                     r = self.feat_lax and a_type(v, "unknown", {}) or a_type(v, "invalid", {})
                  end
               end
               self:add_var(v, v.tk, r)

               if self.collector then
                  self.collector.store_type(v.y, v.x, r)
               end

               last = r
            end
            local nrets = #rets.tuple
            if (not self.feat_lax) and (not rets.is_va and #node.vars > nrets) then
               local at = node.vars[nrets + 1]
               local n_values = nrets == 1 and "1 value" or tostring(nrets) .. " values"
               self.errs:add(at, "too many variables for this iterator; it produces " .. n_values)
            end
         else
            if not (self.feat_lax and is_unknown(exp1type)) then
               self.errs:add(exp1, "expression in for loop does not return an iterator")
            end
         end
      end,
      after = end_scope_and_none_type,
   },
   ["fornum"] = {
      before_statements = function(self, node, children)
         self:widen_all_unions(node)
         self:begin_scope(node)
         local from_t = self:to_structural(untuple(children[2]))
         local to_t = self:to_structural(untuple(children[3]))
         local step_t = children[4] and self:to_structural(children[4])
         local typename = (from_t.typename == "integer" and
         to_t.typename == "integer" and
         (not step_t or step_t.typename == "integer")) and
         "integer" or
         "number"
         self:add_var(node.var, node.var.tk, a_type(node.var, typename, {}))
      end,
      after = end_scope_and_none_type,
   },
   ["return"] = {
      before = function(self, node)
         local rets = self:find_var_type("@return")
         if rets and rets.typename == "tuple" then
            for i, exp in ipairs(node.exps) do
               exp.expected = rets.tuple[i]
            end
         end
      end,
      after = function(self, node, children)
         local got = children[1]
         assert(got.typename == "tuple")
         local got_t = got.tuple
         local n_got = #got_t

         node.block_returns = true
         local expected = self:find_var_type("@return")
         if not expected then

            local module_type = untuple(got)
            if module_type.typename == "nominal" then
               self:resolve_nominal(module_type)
               self.module_type = module_type.resolved
            else
               self.module_type = drop_constant_value(module_type)
            end

            expected = self:infer_at(node, got)
            self.st[2].vars["@return"] = { t = expected }
         end
         local expected_t = expected.tuple

         local what = "in return value"
         if expected.inferred_at then
            what = what .. types.inferred_msg(expected)
         end

         local n_expected = #expected_t
         local vatype
         if n_expected > 0 then
            vatype = expected.is_va and expected.tuple[n_expected]
         end

         if n_got > n_expected and (not self.feat_lax) and not vatype then
            self.errs:add(node, what .. ": excess return values, expected " .. n_expected .. " %s, got " .. n_got .. " %s", expected, got)
         end

         if n_expected > 1 and
            #node.exps == 1 and
            node.exps[1].kind == "op" and
            (node.exps[1].op.op == "and" or node.exps[1].op.op == "or") and
            node.exps[1].discarded_tuple then
            self.errs:add_warning("hint", node.exps[1].e2, "additional return values are being discarded due to '" .. node.exps[1].op.op .. "' expression; suggest parentheses if intentional")
         end

         for i = 1, n_got do
            local e = expected_t[i] or vatype
            if e then
               e = untuple(e)
               local w = (node.exps[i] and node.exps[i].x) and
               node.exps[i] or
               node.exps
               assert(w and w.x)
               assert_is_a(self, w, got_t[i], e, what)
            end
         end

         return NONE
      end,
   },
   ["variable_list"] = {
      after = function(self, node, children)
         local tuple = flat_tuple(node, children)

         for i, t in ipairs(tuple.tuple) do
            local ok, err = ensure_not_abstract(t, node[i])
            if not ok then
               self.errs:add(node[i], err)
            end
         end

         return tuple
      end,
   },
   ["literal_table"] = {
      before = function(self, node)
         if node.expected then
            local decltype = self:to_structural(node.expected)

            if decltype.typename == "typevar" and decltype.constraint then
               decltype = resolve_typedecl(self:to_structural(decltype.constraint))
            end

            if decltype.typename == "generic" then
               decltype = self:apply_generic(node, decltype)
            end

            if decltype.typename == "tupletable" then
               for _, child in ipairs(node) do
                  local n = child.key.constnum
                  if n and is_positive_int(n) then
                     child.value.expected = decltype.types[n]
                  end
               end
            elseif decltype.elements then
               for _, child in ipairs(node) do
                  if child.key.constnum then
                     child.value.expected = decltype.elements
                  end
               end
            elseif decltype.typename == "map" then
               for _, child in ipairs(node) do
                  child.key.expected = decltype.keys
                  child.value.expected = decltype.values
               end
            end

            if decltype.fields then
               for _, child in ipairs(node) do
                  if child.key.conststr then
                     child.value.expected = decltype.fields[child.key.conststr]
                  end
               end
            end
         end
      end,
      after = function(self, node, children)
         self.fdb:set_truthy(node)

         if not node.expected then
            return infer_table_literal(self, node, children)
         end

         local decltype = self:to_structural(node.expected)

         local constraint
         if decltype.typename == "typevar" and decltype.constraint then
            constraint = resolve_typedecl(decltype.constraint)
            decltype = self:to_structural(constraint)
         end

         if decltype.typename == "generic" then
            decltype = self:apply_generic(node, decltype)
         end

         if decltype.typename == "union" then
            local single_table_type
            local single_table_rt

            for _, t in ipairs(decltype.types) do
               local rt = self:to_structural(t)
               if is_lua_table_type(rt) then
                  if single_table_type then

                     single_table_type = nil
                     single_table_rt = nil
                     break
                  end

                  single_table_type = t
                  single_table_rt = rt
               end
            end

            if single_table_type then
               node.expected = single_table_type
               decltype = single_table_rt
            end
         end

         if not is_lua_table_type(decltype) then
            return infer_table_literal(self, node, children)
         end

         if decltype.fields then
            self:begin_implied_scope()
            self:add_self_type(node, decltype)
            decltype = self:resolve_self(decltype, true)
            self:end_implied_scope()
         end

         local force_array = nil

         local seen_keys = {}

         for i, child in ipairs(children) do
            local cvtype = untuple(child.vtype)
            local ck = child.kname
            local cktype = child.ktype
            local n = node[i].key.constnum
            local b = nil
            if cktype.typename == "boolean" then
               b = (node[i].key.tk == "true")
            end
            self.errs:check_redeclared_key(node[i], node, seen_keys, ck or n or b)
            if decltype.fields and ck then
               local df = decltype.fields[ck]
               if not df then
                  self.errs:add_in_context(node[i], node, "unknown field " .. ck)
               else
                  if df.typename == "typedecl" then
                     self.errs:add_in_context(node[i], node, "cannot reassign a type")
                  else
                     assert_is_a(self, node[i], cvtype, df, "in record field", ck)
                  end
               end
            elseif decltype.typename == "tupletable" and is_numeric_type(cktype) then
               local dt = decltype.types[n]
               if not n then
                  self.errs:add_in_context(node[i], node, "unknown index in tuple %s", decltype)
               elseif not dt then
                  self.errs:add_in_context(node[i], node, "unexpected index " .. n .. " in tuple %s", decltype)
               else
                  assert_is_a(self, node[i], cvtype, dt, node, "in tuple: at index " .. tostring(n))
               end
            elseif decltype.elements and is_numeric_type(cktype) then
               local cv = child.vtype
               if cv.typename == "tuple" and i == #children and node[i].key_parsed == "implicit" then

                  for ti, tt in ipairs(cv.tuple) do
                     assert_is_a(self, node[i], tt, decltype.elements, node, "expected an array: at index " .. tostring(i + ti - 1))
                  end
               else
                  assert_is_a(self, node[i], cvtype, decltype.elements, node, "expected an array: at index " .. tostring(n))
               end
            elseif node[i].key_parsed == "implicit" then
               if decltype.typename == "map" then
                  assert_is_a(self, node[i].key, a_type(node[i].key, "integer", {}), decltype.keys, node, "in map key")
                  assert_is_a(self, node[i].value, cvtype, decltype.values, node, "in map value")
               end
               force_array = self:expand_type(node[i], force_array, child.vtype)
            elseif decltype.typename == "map" then
               force_array = nil
               assert_is_a(self, node[i].key, cktype, decltype.keys, node, "in map key")
               assert_is_a(self, node[i].value, cvtype, decltype.values, node, "in map value")
            else
               self.errs:add_in_context(node[i], node, "unexpected key of type %s in table of type %s", cktype, decltype)
            end
         end

         local t = force_array and a_type(node, "array", { elements = force_array }) or node.expected
         t = self:infer_at(node, t)

         if decltype.typename == "record" then
            local rt = self:to_structural(t)
            if rt.typename == "record" then
               node.is_total, node.missing = total_record_check(decltype, seen_keys)
            end
         elseif decltype.typename == "map" then
            local rt = self:to_structural(t)
            if rt.typename == "map" then
               local rk = self:to_structural(rt.keys)
               node.is_total, node.missing = total_map_check(rk, seen_keys)
            end
         end

         if constraint then
            return constraint
         end

         return t
      end,
   },
   ["literal_table_item"] = {
      after = function(self, node, children)
         local kname = node.key.conststr
         local ktype = children[1]
         local vtype = children[2]
         if node.itemtype then
            vtype = node.itemtype
            assert_is_a(self, node.value, children[2], node.itemtype, node)
         end



         vtype = ensure_not_method(vtype)
         return a_type(node, "literal_table_item", {
            kname = kname,
            ktype = ktype,
            vtype = vtype,
         })
      end,
   },
   ["local_function"] = {
      before = function(self, node)
         self:widen_all_unions()
         if self.collector then
            self.collector.reserve_symbol_list_slot(node)
         end
         self:begin_scope(node)
      end,
      before_statements = function(self, node, children)
         local args = children[2]
         assert(args.typename == "tuple")

         self:add_internal_function_variables(node, args)
         self:add_function_definition_for_recursion(node, args, self.feat_arity)
      end,
      after = function(self, node, children)
         local args = children[2]
         assert(args.typename == "tuple")
         local rets = children[3]
         assert(rets.typename == "tuple")

         self:end_function_scope(node)

         local t = wrap_generic_if_typeargs(node.typeargs, a_function(node, {
            min_arity = self.feat_arity and node.min_arity or 0,
            args = args,
            rets = self.get_rets(rets),
         }))

         self:add_var(node, node.name.tk, t)
         return t
      end,
   },
   ["local_macroexp"] = {
      before = function(self, node)
         self:widen_all_unions()
         if self.collector then
            self.collector.reserve_symbol_list_slot(node)
         end
         self:begin_scope(node)
      end,
      after = function(self, node, children)
         local args = children[2]
         assert(args.typename == "tuple")
         local rets = children[3]
         assert(rets.typename == "tuple")

         self:end_function_scope(node)

         macroexps.check_arg_use(self, node.macrodef)

         local t = wrap_generic_if_typeargs(node.typeargs, a_function(node, {
            min_arity = self.feat_arity and node.macrodef.min_arity or 0,
            args = args,
            rets = self.get_rets(rets),
            macroexp = node.macrodef,
         }))

         self:add_var(node, node.name.tk, t)
         return t
      end,
   },
   ["global_function"] = {
      before = function(self, node)
         self:widen_all_unions()
         self:begin_scope(node)
         if node.implicit_global_function then
            local typ = self:find_var_type(node.name.tk)
            if typ then
               if typ.typename == "function" then
                  node.is_predeclared_local_function = true
               elseif not self.feat_lax then
                  self.errs:add(node, "cannot declare function: type of " .. node.name.tk .. " is %s", typ)
               end
            elseif not self.feat_lax then
               self.errs:add(node, "functions need an explicit 'local' or 'global' annotation")
            end
         end
      end,
      before_statements = function(self, node, children)
         local args = children[2]
         assert(args.typename == "tuple")

         self:add_internal_function_variables(node, args)
         self:add_function_definition_for_recursion(node, args, self.feat_arity)
      end,
      after = function(self, node, children)
         local args = children[2]
         assert(args.typename == "tuple")
         local rets = children[3]
         assert(rets.typename == "tuple")

         self:end_function_scope(node)
         if node.is_predeclared_local_function or (node.implicit_global_function and not self.feat_lax) then
            return NONE
         end

         self:add_global(node, node.name.tk, wrap_generic_if_typeargs(node.typeargs, a_function(node, {
            min_arity = self.feat_arity and node.min_arity or 0,
            args = args,
            rets = self.get_rets(rets),
         })))

         return NONE
      end,
   },
   ["record_function"] = {
      before = function(self, node)
         self:widen_all_unions()
         self:begin_scope(node)
      end,
      before_arguments = function(self, _node, children)
         local rtype = self:to_structural(resolve_typedecl(children[1]))


         if rtype.typename == "generic" then
            for _, typ in ipairs(rtype.typeargs) do
               self:add_var(nil, typ.typearg, a_type(typ, "typearg", {
                  typearg = typ.typearg,
                  constraint = typ.constraint,
               }))
            end
         end
      end,
      before_statements = function(self, node, children)
         local args = children[3]
         assert(args.typename == "tuple")
         local rets = children[4]
         assert(rets.typename == "tuple")

         local t = children[1]
         local rtype = self:to_structural(resolve_typedecl(t))


         self:add_internal_function_variables(node, args)

         if rtype.typename == "generic" then
            rtype = rtype.t
         end

         do
            local ok, err = ensure_not_abstract(t)
            if not ok then
               self.errs:add(node, err)
            end
         end

         if self.feat_lax and rtype.typename == "unknown" then
            return
         end

         if rtype.typename == "emptytable" then
            edit_type(rtype, rtype, "record")
            local r = rtype
            r.fields = {}
            r.field_order = {}
         end

         if not rtype.fields then
            local _, _, owner_name = self:find_record_to_extend(node.fn_owner)
            local short_type = show_type(rtype, true)
            local msg = ("record function syntax cannot be used with this type: %s is %s"):format(owner_name, short_type)
            self.errs:add(node, msg, rtype)
            if rtype.typename == "map" then
               self.errs:add_warning("hint", node, "use the assignment syntax to store functions in maps", rtype)
            end
            return
         end

         local selftype = self:get_self_type(node.fn_owner)
         if node.is_method then
            if not selftype then
               self.errs:add(node, "could not resolve type of self")
               return
            end
            args.tuple[1] = a_type(node, "self", { display_type = selftype })
            self:add_var(nil, "self", selftype)
            self:add_self_type(node, selftype)
            if self.collector then
               self.collector.add_to_symbol_list(node.fn_owner, "self", selftype)
            end
         end

         local fn_type = wrap_generic_if_typeargs(node.typeargs, a_function(node, {
            min_arity = self.feat_arity and node.min_arity or 0,
            is_method = node.is_method,
            args = args,
            rets = self.get_rets(rets),
            is_record_function = true,
         }))

         local open_t, open_v, owner_name = self:find_record_to_extend(node.fn_owner)
         local open_k = owner_name .. "." .. node.name.tk
         local rfieldtype = rtype.fields[node.name.tk]
         if rfieldtype then
            rfieldtype = self:to_structural(rfieldtype)

            if open_v and open_v.implemented and open_v.implemented[open_k] then
               self.errs:redeclaration_warning(node, node.name.tk, "function")
            end

            if fn_type.typename == "generic" and not (rfieldtype.typename == "generic") then
               self:begin_implied_scope()
               fn_type = self:apply_generic(node, fn_type)
               self:end_implied_scope()
            end

            local ok, err = self:same_type(fn_type, rfieldtype)
            if not ok then
               if rfieldtype.typename == "poly" then
                  self.errs:add_prefixing(node, err, "type signature does not match declaration: field has multiple function definitions (such polymorphic declarations are intended for Lua module interoperability): ")
                  return
               end

               local shortname = selftype and show_type(selftype) or owner_name
               local msg = "type signature of '" .. node.name.tk .. "' does not match its declaration in " .. shortname .. ": "
               self.errs:add_prefixing(node, err, msg)
               return
            end
         else
            if open_t and open_t.typename == "generic" then
               open_t = open_t.t
            end
            if self.feat_lax or rtype == open_t then





               rtype.fields[node.name.tk] = fn_type
               table.insert(rtype.field_order, node.name.tk)

               if self.collector then
                  self.env.reporter:add_field(rtype, node.name.tk, fn_type)
               end
            else
               self.errs:add(node, "cannot add undeclared function '" .. node.name.tk .. "' outside of the scope where '" .. owner_name .. "' was originally declared")
               return
            end

         end

         if open_v then
            if not open_v.implemented then
               open_v.implemented = {}
            end
            open_v.implemented[open_k] = true
         end

      end,
      after = function(self, node, _children)
         self:end_function_scope(node)
         return NONE
      end,
   },
   ["function"] = {
      before = function(self, node)
         self:widen_all_unions(node)
         self:begin_scope(node)

         local expected = node.expected
         if expected and expected.typename == "function" then
            for i, t in ipairs(expected.args.tuple) do
               if node.args[i] then
                  node.args[i].expected = t
               end
            end
         end
      end,
      before_statements = function(self, node, children)
         local args = children[1]
         assert(args.typename == "tuple")

         self:add_internal_function_variables(node, args)
      end,
      after = function(self, node, children)
         local args = children[1]
         assert(args.typename == "tuple")
         local rets = children[2]
         assert(rets.typename == "tuple")

         self:end_function_scope(node)

         return wrap_generic_if_typeargs(node.typeargs, a_function(node, {
            min_arity = self.feat_arity and node.min_arity or 0,
            args = args,
            rets = self.get_rets(rets),
         }))
      end,
   },
   ["macroexp"] = {
      before = function(self, node)
         self:widen_all_unions(node)
         self:begin_scope(node)
      end,
      before_exp = function(self, node, children)
         local args = children[1]
         assert(args.typename == "tuple")

         self:add_internal_function_variables(node, args)
      end,
      after = function(self, node, children)
         local args = children[1]
         assert(args.typename == "tuple")
         local rets = children[2]
         assert(rets.typename == "tuple")

         self:end_function_scope(node)
         return wrap_generic_if_typeargs(node.typeargs, a_function(node, {
            min_arity = self.feat_arity and node.min_arity or 0,
            args = args,
            rets = rets,
         }))
      end,
   },
   ["cast"] = {
      after = function(_self, node, _children)
         return node.casttype
      end,
   },
   ["paren"] = {
      before = function(_self, node)
         node.e1.expected = node.expected
      end,
      after = function(self, node, children)
         self.fdb:set_from(node, node.e1)
         return untuple(children[1])
      end,
   },
   ["op"] = {
      before = function(self, node)
         self:begin_implied_scope()
         if node.expected then
            if node.op.op == "and" then
               node.e2.expected = node.expected
            elseif node.op.op == "or" then
               node.e1.expected = node.expected
               if not (node.e2.kind == "literal_table" and #node.e2 == 0) then
                  node.e2.expected = node.expected
               end
            end
         end
         if node.op.op == "not" then
            node.e1.expected = a_type(node, "boolean_context", {})
         end
      end,
      before_e2 = function(self, node, children)
         local e1type = children[1]

         if node.op.op == "and" then
            self:apply_facts_from(node, node.e1)
         elseif node.op.op == "or" then
            self:apply_facts(node, facts_not(node, self.fdb:get(node.e1)))


            if node.e1.kind == "op" and node.e1.op.op == "and" and
               node.e1.e1.kind == "op" and node.e1.e1.op.op == "is" and
               node.e1.e2.kind == "variable" and
               node.e1.e2.tk == node.e1.e1.e1.tk and
               node.e1.e1.e2.casttype.typename ~= "boolean" and
               node.e1.e1.e2.casttype.typename ~= "nil" then

               self:apply_facts(node, facts_not(node, IsFact({ var = node.e1.e1.e1.tk, typ = node.e1.e1.e2.casttype, w = node })))
            end

         elseif node.op.op == "@funcall" then
            if e1type.typename == "generic" then
               e1type = self:apply_generic(node, e1type)
            end
            if e1type.typename == "function" then
               local argdelta = (node.e1.op and node.e1.op.op == ":") and -1 or 0
               if node.expected then

                  self:is_a(e1type.rets, node.expected)
               end
               local e1args = e1type.args.tuple
               local at = argdelta
               for _, typ in ipairs(e1args) do
                  at = at + 1
                  if node.e2[at] then
                     node.e2[at].expected = self:infer_at(node.e2[at], typ)
                  end
               end
               if e1type.args.is_va then
                  local typ = e1args[#e1args]
                  for i = at + 1, #node.e2 do
                     node.e2[i].expected = self:infer_at(node.e2[i], typ)
                  end
               end
            end
         elseif node.op.op == "@index" then
            if e1type.typename == "map" then
               node.e2.expected = e1type.keys
            end
         end
      end,
      after = function(self, node, children)
         self:end_implied_scope()


         local ga = children[1]
         local gb = children[3]


         local ua = untuple(ga)
         local ub


         local ra = self:to_structural(ua)
         local rb

         if ra.typename == "circular_require" or (ra.typename == "typedecl" and ra.def and ra.def.typename == "circular_require") then
            return self.errs:invalid_at(node, "cannot dereference a type from a circular require")
         end

         if node.op.op == "@funcall" then
            if self.feat_lax and is_unknown(ua) then
               if node.e1.op and node.e1.op.op == ":" and node.e1.e1.kind == "variable" then
                  self.errs:add_unknown_dot(node, node.e1.e1.tk .. "." .. node.e1.e2.tk)
               end
            end
            assert(gb.typename == "tuple")
            local t = self:type_check_funcall(node, ua, gb)
            return t

         elseif node.op.op == "as" then
            local ok, err = ensure_not_abstract(ra)
            if not ok then
               return self.errs:invalid_at(node.e1, err)
            end
            return gb

         elseif node.op.op == "is" and ra.typename == "typedecl" then
            return self.errs:invalid_at(node, "can only use 'is' on variables, not types")
         end

         local ok, err = ensure_not_abstract(ra)
         if not ok then
            return self.errs:invalid_at(node.e1, err)
         end
         if ra.typename == "typedecl" and ra.def.typename == "record" then
            ra = ra.def
         end



         if gb then
            ub = untuple(gb)
            rb = self:to_structural(ub)
            ok, err = ensure_not_abstract(rb)
            if not ok then
               return self.errs:invalid_at(node.e2, err)
            end
            if rb.typename == "typedecl" and rb.def.typename == "record" then
               rb = rb.def
            end
         end

         if node.op.op == "." then
            node.receiver = ua

            assert(node.e2.kind == "identifier")
            local bnode = node_at(node.e2, {
               tk = node.e2.tk,
               kind = "string",
            })
            local btype = a_type(node.e2, "string", { literal = node.e2.tk })
            local t = self:type_check_index(node.e1, bnode, ua, btype)
            if t.needs_compat then
               node.op.needs_compat = true
            end

            return t
         end

         if node.op.op == "@index" then
            return self:type_check_index(node.e1, node.e2, ua, ub)
         end

         if node.op.op == "is" then
            if ra.typename == "typedecl" then
               self.errs:add(node, "can only use 'is' on variables, not types")
            elseif node.e1.kind == "variable" then
               if rb.typename == "union" then
                  convert_is_of_union_to_or_of_is(self, node, ra, rb)
               else
                  self:check_metamethod(node, "__is", ra, resolve_typedecl(rb), ua, ub)
                  self.fdb:set_is(node, node.e1.tk, ub)
               end
            else
               self.errs:add(node, "can only use 'is' on variables")
            end
            return a_type(node, "boolean", {})
         end

         if node.op.op == ":" then
            node.receiver = ua



            if self.feat_lax and (is_unknown(ua) or ua.typename == "typevar") then
               if node.e1.kind == "variable" then
                  self.errs:add_unknown_dot(node.e1, node.e1.tk .. "." .. node.e2.tk)
               end
               return a_type(node, "unknown", {})
            end

            local t, e = self:match_record_key(ra, node.e1, node.e2.conststr or node.e2.tk)
            if not t then
               return self.errs:invalid_at(node.e2, e, ua)
            end

            return t
         end

         if node.op.op == "not" then
            self.fdb:set_not(node, node.e1)
            return a_type(node, "boolean", {})
         end

         if node.op.op == "and" then
            self.fdb:set_and(node, node.e1, node.e2)
            return discard_tuple(node, ub, gb)
         end

         if node.op.op == "or" then
            local t

            local expected = node.expected and self:to_structural(untuple(node.expected))

            if ub.typename == "nil" then
               self.fdb:unset(node)
               t = ua

            elseif is_lua_table_type(ra) and rb.typename == "emptytable" then
               self.fdb:unset(node)
               t = ua

            elseif ((ra.typename == "enum" and rb.typename == "string" and self:is_a(rb, ra)) or
               (ra.typename == "string" and rb.typename == "enum" and self:is_a(ra, rb))) then
               self.fdb:unset(node)
               t = (ra.typename == "enum" and ra or rb)

            elseif expected and expected.typename == "union" then

               self.fdb:set_or(node, node.e1, node.e2)
               local u = unite(node, { ra, rb }, true)
               if u.typename == "union" then
                  ok, err = is_valid_union(u)
                  if not ok then
                     u = err and self.errs:invalid_at(node, err, u) or a_type(node, "invalid", {})
                  end
               end
               t = u


            elseif ra.typename == "union" and not (rb.typename == "union") and self:is_a(rb, ra) then

               t = drop_constant_value(ra)

            elseif rb.typename == "union" and not (ra.typename == "union") and self:is_a(ra, rb) then

               t = drop_constant_value(rb)

            else


               local a_ge_b = self:is_a(ub, ua)
               local b_ge_a = self:is_a(ua, ub)
               self.fdb:set_or(node, node.e1, node.e2)


               local is_same = self:same_type(ra, rb)


               local ambiguous = a_ge_b and b_ge_a and not is_same



               if is_same then
                  t = ua
               elseif (a_ge_b or b_ge_a) and not ambiguous then
                  local larger_type = b_ge_a and ub or ua
                  t = larger_type
               elseif expected and self:is_a(ua, expected) and self:is_a(ub, expected) then
                  t = self:infer_at(node, expected)
               end

               if ambiguous and not t then
                  if TL_DEBUG then
                     self.errs:add_warning("debug", node, "the resulting type is ambiguous: %s or %s", ua, ub)
                     self.errs:add_warning("debug", node, "currently choosing %s", ub)
                  end

                  t = ub
               end
               if t then
                  t = drop_constant_value(t)
               end

               if expected and expected.typename == "boolean_context" then
                  t = a_type(node, "boolean", {})
               end
            end

            if t then
               return discard_tuple(node, t, gb)
            end

         end

         if node.op.op == "==" or node.op.op == "~=" then
            if is_lua_table_type(ra) and is_lua_table_type(rb) then
               self:check_metamethod(node, binop_to_metamethod[node.op.op], ra, rb, ua, ub)
            end

            if ra.typename == "enum" and rb.typename == "string" then
               if not (rb.literal and ra.enumset[rb.literal]) then
                  return self.errs:invalid_at(node, "%s is not a member of %s", ub, ua)
               end
            elseif ra.typename == "tupletable" and rb.typename == "tupletable" and #ra.types ~= #rb.types then
               return self.errs:invalid_at(node, "tuples are not the same size")
            elseif self:is_a(ub, ua) or ua.typename == "typevar" then
               if node.op.op == "==" and node.e1.kind == "variable" then
                  self.fdb:set_eq(node, node.e1.tk, ub)
               end
            elseif self:is_a(ua, ub) or ub.typename == "typevar" then
               if node.op.op == "==" and node.e2.kind == "variable" then
                  self.fdb:set_eq(node, node.e2.tk, ua)
               end
            elseif self.feat_lax and (is_unknown(ua) or is_unknown(ub)) then
               return a_type(node, "unknown", {})
            else
               return self.errs:invalid_at(node, "types are not comparable for equality: %s and %s", ua, ub)
            end

            return a_type(node, "boolean", {})
         end

         if node.op.arity == 1 and unop_types[node.op.op] then
            if ra.typename == "union" then
               ra = unite(node, ra.types, true)
            end

            local types_op = unop_types[node.op.op]

            local tn = types_op[ra.typename]
            local t = tn and a_type(node, tn, {})

            if not t then
               local mt_name = unop_to_metamethod[node.op.op]
               if mt_name then
                  t, node.op.meta_on_operand = self:check_metamethod(node, mt_name, ra, nil, ua, nil)
               end
            end

            if not t and ra.fields then
               if ra.interface_list then
                  for _, iface in ipairs(ra.interface_list) do
                     if types_op[iface.typename] then
                        t = a_type(node, types_op[iface.typename], {})
                        break
                     end
                  end
               end
            end

            if ra.typename == "map" then
               if ra.keys.typename == "number" or ra.keys.typename == "integer" then
                  self.errs:add_warning("hint", node, "using the '#' operator on a map with numeric key type may produce unexpected results")
               else
                  self.errs:add(node, "using the '#' operator on this map will always return 0")
               end
            end

            if not t then
               return self.errs:invalid_at(node, "cannot use operator '" .. node.op.op:gsub("%%", "%%%%") .. "' on type %s", ua)
            end

            if not (t.typename == "boolean" or is_unknown(t)) then
               self.fdb:set_truthy(node)
            end

            return t
         end

         if node.op.arity == 2 and binop_types[node.op.op] then
            if node.op.op == "or" then
               self.fdb:set_or(node, node.e1, node.e2)
            end

            if ra.typename == "union" then
               ra = unite(ra, ra.types, true)
            end
            if rb.typename == "union" then
               rb = unite(rb, rb.types, true)
            end

            local types_op = binop_types[node.op.op]

            local tn = types_op[ra.typename] and types_op[ra.typename][rb.typename]
            local t = tn and a_type(node, tn, {})

            if not t then
               local mt_name = binop_to_metamethod[node.op.op]
               local flipped = false
               if not mt_name then
                  mt_name = flip_binop_to_metamethod[node.op.op]
                  if mt_name then
                     flipped = true
                     ra, rb = rb, ra
                     ua, ub = ub, ua
                  end
               end
               if mt_name then
                  t, node.op.meta_on_operand = self:check_metamethod(node, mt_name, ra, rb, ua, ub, flipped)
                  if flipped and not node.op.meta_on_operand then
                     ra, rb = rb, ra
                     ua, ub = ub, ua
                  end
               end
            end

            if (not t) and ua.typename == "nominal" and ub.typename == "nominal" and not node.op.meta_on_operand then
               if self:is_a(ua, ub) then
                  t = ua
               end
            end

            if types_op == numeric_binop or node.op.op == ".." then
               self.fdb:set_truthy(node)
            end

            if not t then
               if node.op.op == "or" then
                  local u = unite(node, { ua, ub })
                  if u.typename == "union" and is_valid_union(u) then
                     self.errs:add_warning("hint", node, "if a union type was intended, consider declaring it explicitly")
                  end
               end
               return self.errs:invalid_at(node, "cannot use operator '" .. node.op.op:gsub("%%", "%%%%") .. "' for types %s and %s", ua, ub)
            end

            return t
         end

         error("unknown node op " .. node.op.op)
      end,
   },
   ["variable"] = {
      after = function(self, node, _children)
         if node.tk == "..." then
            local va_sentinel = self:find_var_type("@is_va")
            if not va_sentinel or va_sentinel.typename == "nil" then
               return self.errs:invalid_at(node, "cannot use '...' outside a vararg function")
            end
         end

         local t
         if node.tk == "_G" then
            t, node.attribute = self:simulate_g()
         else
            local use = node.is_lvalue and "lvalue" or "use"
            t, node.attribute = self:find_var_type(node.tk, use)
         end
         if not t then
            if self.feat_lax then
               self.errs:add_unknown(node, node.tk)
               return a_type(node, "unknown", {})
            end

            return self.errs:invalid_at(node, "unknown variable: " .. node.tk)
         end

         if t.typename == "typedecl" then
            t = typedecl_to_nominal(node, node.tk, t, t)
         end

         return t
      end,
   },
   ["type_identifier"] = {
      after = function(self, node, _children)
         local typ, attr = self:find_var_type(node.tk)
         node.attribute = attr
         if typ then
            return typ
         end

         if self.feat_lax then
            self.errs:add_unknown(node, node.tk)
            return a_type(node, "unknown", {})
         end

         return self.errs:invalid_at(node, "unknown variable: " .. node.tk)
      end,
   },
   ["argument"] = {
      after = function(self, node, children)
         local t = children[1]
         if not t then
            if node.expected and node.tk == "self" then
               t = node.expected
            else
               t = self.feat_lax and
               a_type(node, "unknown", {}) or
               a_type(node, "any", {})
            end
         end
         if node.tk == "..." then
            t = a_vararg(node, { t })
         end
         self:add_var(node, node.tk, t).is_func_arg = true
         return t
      end,
   },
   ["identifier"] = {
      after = function(_self, _node, _children)
         return NONE
      end,
   },
   ["newtype"] = {
      after = function(_self, node, _children)
         return node.newtype
      end,
   },
   ["pragma"] = {
      after = function(self, node, _children)
         if node.pkey == "arity" then
            if node.pvalue == "on" then
               self.feat_arity = true
               self.env.opts.feat_arity = "on"
            elseif node.pvalue == "off" then
               self.feat_arity = false
               self.env.opts.feat_arity = "off"
            else
               return self.errs:invalid_at(node, "invalid value for pragma 'arity': " .. node.pvalue)
            end
         else
            return self.errs:invalid_at(node, "invalid pragma: " .. node.pkey)
         end
         return NONE
      end,
   },
   ["error_node"] = {
      after = function(_self, node, _children)
         return a_type(node, "invalid", {})
      end,
   },
}

visit_node.cbs["break"] = {
   after = function(_self, _node, _children)
      return NONE
   end,
}
visit_node.cbs["do"] = visit_node.cbs["break"]

local function after_literal(self, node)
   self.fdb:set_truthy(node)
   return a_type(node, node.kind, {})
end

visit_node.cbs["string"] = {
   after = function(self, node, _children)
      local t = after_literal(self, node)
      t.literal = node.conststr

      local expected = node.expected and self:to_structural(node.expected)
      if expected and expected.typename == "enum" and self:is_a(t, expected) then
         return node.expected
      end

      return t
   end,
}
visit_node.cbs["number"] = { after = after_literal }
visit_node.cbs["integer"] = { after = after_literal }

visit_node.cbs["boolean"] = {
   after = function(self, node, _children)
      local t = after_literal(self, node)
      if node.tk == "true" then
         self.fdb:set_truthy(node)
      else
         self.fdb:unset(node)
      end
      return t
   end,
}
visit_node.cbs["nil"] = visit_node.cbs["boolean"]

visit_node.cbs["..."] = visit_node.cbs["variable"]
visit_node.cbs["argument_list"] = visit_node.cbs["variable_list"]
visit_node.cbs["expression_list"] = visit_node.cbs["variable_list"]

visit_node.after = function(_self, node, _children, t)
   if node.expanded then
      macroexps.apply(node)
   end

   return t
end



local function ensure_is_method_self(typ, selfarg, g)
   if selfarg.typename == "self" then
      return true
   end
   if not (selfarg.typename == "nominal") then
      return false
   end

   if #selfarg.names ~= 1 or selfarg.names[1] ~= typ.declname then
      return false
   end

   if g then
      if not selfarg.typevals then
         return false
      end

      if g.t.typeid ~= typ.typeid then
         return false
      end

      for j = 1, #g.typeargs do
         local tv = selfarg.typevals[j]
         if not (tv and tv.typename == "typevar" and tv.typevar == g.typeargs[j].typearg) then
            return false
         end
      end
   end

   return true
end

local metamethod_is_method = {
   ["__bnot"] = true,
   ["__call"] = true,
   ["__close"] = true,
   ["__gc"] = true,
   ["__index"] = true,
   ["__is"] = true,
   ["__len"] = true,
   ["__newindex"] = true,
   ["__pairs"] = true,
   ["__tostring"] = true,
   ["__unm"] = true,
}

visit_type.cbs = {
   ["generic"] = {
      before = function(self, typ)
         self:begin_implied_scope()
         self:add_var(nil, "@generic", typ)
      end,
      after = function(self, typ, _children)
         self:end_implied_scope()
         return self:fresh_typeargs(typ)
      end,
   },
   ["function"] = {
      after = function(self, typ, _children)
         if self.feat_arity == false then
            typ.min_arity = 0
         end
         return typ
      end,
   },
   ["record"] = {
      before = function(self, typ)
         self:begin_implied_scope()
         self:begin_temporary_record_types(typ)
      end,
      after = function(self, typ, children)
         local i = 1
         if typ.interface_list then
            for j, _ in ipairs(typ.interface_list) do
               local iface = children[i]
               if iface.typename == "array" then
                  typ.interface_list[j] = iface
               elseif iface.typename == "nominal" then
                  local ri = self:resolve_nominal(iface)
                  if ri.typename == "interface" then
                     typ.interface_list[j] = iface
                  else
                     self.errs:add(children[i], "%s is not an interface", children[i])
                  end
               end
               i = i + 1
            end
         end
         if typ.elements then
            typ.elements = children[i]
            i = i + 1
         end
         local fmacros
         local g
         for name, _ in fields_of(typ) do
            local ftype = children[i]
            if ftype.typename == "function" then
               if ftype.macroexp then
                  fmacros = fmacros or {}
                  table.insert(fmacros, ftype)
               end

               if ftype.is_method then
                  local fargs = ftype.args.tuple
                  if fargs[1] then
                     if not g then
                        g = self:find_var("@generic")
                     end
                     ftype.is_method = ensure_is_method_self(typ, fargs[1], g and g.t)
                     if ftype.is_method then
                        fargs[1] = a_type(fargs[1], "self", { display_type = typ })
                     end
                  end
               end
            elseif ftype.typename == "typedecl" and ftype.is_alias then
               self:resolve_typealias(ftype)
            end

            typ.fields[name] = ftype
            i = i + 1
         end
         for name, _ in fields_of(typ, "meta") do
            local ftype = children[i]
            if ftype.typename == "function" then
               if ftype.macroexp then
                  fmacros = fmacros or {}
                  table.insert(fmacros, ftype)
               end
               ftype.is_method = metamethod_is_method[name]
            end
            typ.meta_fields[name] = ftype
            i = i + 1
         end

         if typ.interface_list then
            self:expand_interfaces(typ)

            if self.collector then
               for fname, ftype in fields_of(typ) do
                  self.env.reporter:add_field(typ, fname, ftype)
               end
            end
         end

         if fmacros then
            for _, t in ipairs(fmacros) do
               local macroexp_type = traverse_nodes(self, t.macroexp, visit_node, visit_type)

               macroexps.check_arg_use(self, t.macroexp)

               if not self:is_a(macroexp_type, t) then
                  self.errs:add(macroexp_type, "macroexp type does not match declaration")
               end
            end
         end

         self:end_temporary_record_types(typ)
         self:end_implied_scope()

         return typ
      end,
   },
   ["typearg"] = {
      after = function(self, typ, _children)
         local name = typ.typearg
         local old = self:find_var(name, "check_only")
         if old then
            self.errs:redeclaration_warning(typ, name, "type argument", old)
         end
         if simple_types[name] then
            self.errs:add(typ, "cannot use base type name '" .. name .. "' as a type variable")
         end

         self:add_var(nil, name, a_type(typ, "typearg", {
            typearg = name,
            constraint = typ.constraint,
         }))
         return typ
      end,
   },
   ["typevar"] = {
      after = function(self, typ, _children)
         if not self:find_var_type(typ.typevar) then
            self.errs:add(typ, "undefined type variable " .. typ.typevar)
         end
         return typ
      end,
   },
   ["nominal"] = {
      after = function(self, typ, _children)
         if typ.found then
            return typ
         end

         local t, typearg = self:find_type(typ.names)
         if t then
            local def = t.def
            if t.is_alias then
               if def.typename == "generic" then
                  def = def.t
               end
               if def.typename == "nominal" then
                  typ.found = def.found
               end
            elseif def.typename ~= "circular_require" then
               typ.found = t
            end
         elseif typearg then

            typ.names = nil
            edit_type(typ, typ, "typevar")
            local tv = typ
            tv.typevar = typearg.typearg
            tv.constraint = typearg.constraint
         else
            local name = typ.names[1]
            local scope = self.st[#self.st]
            scope.pending_nominals = scope.pending_nominals or {}
            scope.pending_nominals[name] = scope.pending_nominals[name] or {}
            table.insert(scope.pending_nominals[name], typ)
         end
         return typ
      end,
   },
   ["union"] = {
      after = function(self, typ, _children)
         local _, err = is_valid_union(typ)
         if err then
            return self.errs:invalid_at(typ, err, typ)
         end
         return typ
      end,
   },
}

local default_type_visitor = {
   after = function(_self, typ, _children)
      return typ
   end,
}

visit_type.cbs["interface"] = visit_type.cbs["record"]

visit_type.cbs["typedecl"] = default_type_visitor
visit_type.cbs["self"] = default_type_visitor
visit_type.cbs["string"] = default_type_visitor
visit_type.cbs["tupletable"] = default_type_visitor
visit_type.cbs["array"] = default_type_visitor
visit_type.cbs["map"] = default_type_visitor
visit_type.cbs["enum"] = default_type_visitor
visit_type.cbs["boolean"] = default_type_visitor
visit_type.cbs["nil"] = default_type_visitor
visit_type.cbs["number"] = default_type_visitor
visit_type.cbs["integer"] = default_type_visitor
visit_type.cbs["thread"] = default_type_visitor
visit_type.cbs["emptytable"] = default_type_visitor
visit_type.cbs["literal_table_item"] = default_type_visitor
visit_type.cbs["unresolved_emptytable_value"] = default_type_visitor
visit_type.cbs["tuple"] = default_type_visitor
visit_type.cbs["poly"] = default_type_visitor
visit_type.cbs["any"] = default_type_visitor
visit_type.cbs["unknown"] = default_type_visitor
visit_type.cbs["invalid"] = default_type_visitor
visit_type.cbs["none"] = default_type_visitor

return visitors

end

-- module teal.debug from teal/debug.lua
package.preload["teal.debug"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local debug = _tl_compat and _tl_compat.debug or debug; local io = _tl_compat and _tl_compat.io or io; local math = _tl_compat and _tl_compat.math or math; local _tl_math_maxinteger = math.maxinteger or math.pow(2, 53); local os = _tl_compat and _tl_compat.os or os; local string = _tl_compat and _tl_compat.string or string


local tldebug = {}







function tldebug.write(...)
   io.stderr:write(...)
end

function tldebug.flush()
   io.stderr:flush()
end

tldebug.TL_DEBUG = os.getenv("TL_DEBUG")
tldebug.TL_DEBUG_FACTS = os.getenv("TL_DEBUG_FACTS")
tldebug.TL_DEBUG_MAXLINE = _tl_math_maxinteger

if tldebug.TL_DEBUG_FACTS and not tldebug.TL_DEBUG then
   tldebug.TL_DEBUG = "1"
end

if tldebug.TL_DEBUG then
   local max = assert(tonumber(tldebug.TL_DEBUG), "TL_DEBUG was defined, but not a number")
   if max < 0 then
      tldebug.TL_DEBUG_MAXLINE = math.tointeger(-max)
   elseif max > 1 then
      local count = 0
      local skip
      debug.sethook(function(event)
         if event == "call" or event == "tail call" or event == "return" then
            local info = debug.getinfo(2)

            if skip then
               if info.name == skip and event == "return" then
                  skip = nil
               end
               return
            elseif (info.name or "?"):match("^tl_debug_") and event == "call" then
               skip = info.name
               return
            end

            local name = info.name or "<anon>", info.currentline > 0 and "@" .. info.currentline or ""
            tldebug.write(name, " :: ", event, "\n")
            tldebug.flush()
         else
            count = count + 100
            if count > max then
               error("Too many instructions")
            end
         end
      end, "cr", 100)
   end
end

do







   local curr_indent = 0
   local curr_entry = nil
   local curr_y = 1

   local function loc(y, x)
      return (tostring(y) or "?") .. ":" .. (tostring(x) or "?")
   end

   function tldebug.indent_push(mark, y, x, fmt, ...)
      if curr_entry then
         if curr_entry.y and (curr_entry.y > curr_y) then
            tldebug.write("\n")
            curr_y = curr_entry.y
         end
         tldebug.write(("   "):rep(curr_indent) .. curr_entry.mark .. " " ..
         loc(curr_entry.y, curr_entry.x) .. " " ..
         curr_entry.msg .. "\n")
         tldebug.flush()
         curr_entry = nil
         curr_indent = curr_indent + 1
      end
      curr_entry = {
         mark = mark,
         y = y,
         x = x,
         msg = fmt:format(...),
      }
   end

   function tldebug.indent_pop(mark, single, y, x, fmt, ...)
      if curr_entry then
         local msg = curr_entry.msg
         if fmt then
            msg = fmt:format(...)
         end
         if y and (y > curr_y) then
            tldebug.write("\n")
            curr_y = y
         end
         tldebug.write(("   "):rep(curr_indent) .. single .. " " .. loc(y, x) .. " " .. msg .. "\n")
         tldebug.flush()
         curr_entry = nil
      else
         curr_indent = curr_indent - 1
         if fmt then
            tldebug.write(("   "):rep(curr_indent) .. mark .. " " .. fmt:format(...) .. "\n")
            tldebug.flush()
         end
      end
   end
end

return tldebug

end

-- module teal.environment from teal/environment.lua
package.preload["teal.environment"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table
local VERSION = "0.25.0-alpha+dev"

local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG

local default_env = require("teal.precompiled.default_env")




local targets = require("teal.gen.targets")





local types = require("teal.types")






local a_type = types.a_type







local environment = { EnvOptions = {}, Env = {}, Result = {} }
























































environment.VERSION = VERSION
environment.DEFAULT_GEN_COMPAT = "optional"
environment.DEFAULT_GEN_TARGET = "5.3"





local require_module

function environment.set_require_module_fn(fn)
   require_module = fn
end

local function empty_environment()
   return {
      modules = {},
      module_filenames = {},
      loaded = {},
      loaded_order = {},
      globals = {},
      opts = {},
      require_module = require_module,
   }
end

local function declare_globals(env)
   for name, var in pairs(environment.stdlib_globals) do
      env.globals[name] = var
      local t = var.t
      if t.typename == "typedecl" then

         env.modules[name] = t
      end
   end
end

local function load_precompiled_default_env(env)
   if not environment.stdlib_globals then



      environment.stdlib_globals = default_env.globals
      types.internal_force_state(default_env.typeid_ctr, default_env.typevar_ctr)
   end

   declare_globals(env)
end


function environment.new(opts)
   local env = empty_environment()
   env.opts = opts or env.opts
   load_precompiled_default_env(env)
   return env
end





function environment.for_runtime()
   local gen_target = targets.detect()
   local gen_compat = (gen_target == "5.4") and "off" or environment.DEFAULT_GEN_COMPAT
   return environment.new({
      gen_target = gen_target,
      gen_compat = gen_compat,
      run_internal_compiler_checks = false,
   })
end

do
   local stdlib_compat = {
      ["io"] = true,
      ["math"] = true,
      ["string"] = true,
      ["table"] = true,
      ["utf8"] = true,
      ["coroutine"] = true,
      ["os"] = true,
      ["package"] = true,
      ["debug"] = true,
      ["load"] = true,
      ["loadfile"] = true,
      ["assert"] = true,
      ["pairs"] = true,
      ["ipairs"] = true,
      ["pcall"] = true,
      ["xpcall"] = true,
      ["rawlen"] = true,
   }

   local function set_special_function(t, fname)
      t = types.resolve_for_special_function(t)
      t.special_function_handler = fname
   end










   function environment.construct(opts, prelude, stdlib)
      if opts and opts.gen_target == "5.4" and opts.gen_compat ~= "off" then
         return nil, "gen-compat must be explicitly 'off' when gen-target is '5.4'"
      end

      local env = empty_environment()
      env.opts = opts or env.opts

      local stdlib_globals = environment.stdlib_globals
      if not stdlib_globals then
         local tl_debug = TL_DEBUG
         TL_DEBUG = nil

         local typ = env:require_module(prelude or "teal.default.prelude")
         if typ.typename == "invalid" then
            return nil, "prelude contains errors"
         end

         typ = env:require_module(stdlib or "teal.default.stdlib")
         if typ.typename == "invalid" then
            return nil, "standard library contains errors"
         end

         stdlib_globals = env.globals
         environment.stdlib_globals = env.globals

         TL_DEBUG = tl_debug


         local math_t = (stdlib_globals["math"].t).def
         local table_t = (stdlib_globals["table"].t).def
         math_t.fields["maxinteger"].needs_compat = true
         math_t.fields["mininteger"].needs_compat = true
         table_t.fields["pack"].needs_compat = true
         table_t.fields["unpack"].needs_compat = true


         local string_t = (stdlib_globals["string"].t).def
         set_special_function(string_t.fields["find"], "string.find")
         set_special_function(string_t.fields["format"], "string.format")
         set_special_function(string_t.fields["gmatch"], "string.gmatch")
         set_special_function(string_t.fields["gsub"], "string.gsub")
         set_special_function(string_t.fields["match"], "string.match")
         set_special_function(string_t.fields["pack"], "string.pack")
         set_special_function(string_t.fields["unpack"], "string.unpack")

         set_special_function(stdlib_globals["assert"].t, "assert")
         set_special_function(stdlib_globals["ipairs"].t, "ipairs")
         set_special_function(stdlib_globals["pairs"].t, "pairs")
         set_special_function(stdlib_globals["pcall"].t, "pcall")
         set_special_function(stdlib_globals["xpcall"].t, "xpcall")
         set_special_function(stdlib_globals["rawget"].t, "rawget")
         set_special_function(stdlib_globals["require"].t, "require")




         local w = { filename = "@<stdlib>.tl", y = 1, x = 1 }
         stdlib_globals["..."] = { t = a_type(w, "tuple", { tuple = { a_type(w, "string", {}) }, is_va = true }) }
         stdlib_globals["@is_va"] = { t = a_type(w, "any", {}) }

         env.globals = {}
      end

      declare_globals(env)

      for name, _ in pairs(stdlib_compat) do
         env.globals[name].needs_compat = true
      end

      return env
   end
end

function environment.load_module(env, name)
   local module_type = env:require_module(name)

   if not module_type then
      return false, string.format("could not load module '%s'", name)
   end

   return true
end

function environment.register(env, filename, result)
   env.loaded[filename] = result

   table.insert(env.loaded_order, filename)
end

function environment.register_failed(env, filename, syntax_errors)
   local result = {
      filename = filename,
      type = a_type({ f = filename, y = 1, x = 1 }, "boolean", {}),
      type_errors = {},
      syntax_errors = syntax_errors,
      dependencies = {},
      env = env,
   }
   env.loaded[filename] = result
   table.insert(env.loaded_order, filename)
   return result
end

return environment

end

-- module teal.errors from teal/errors.lua
package.preload["teal.errors"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table; local errors = { Error = {}, ErrorContext = {} }






































function errors.new(msg)
   return { msg = msg }
end

function errors.at(w, msg)
   return {
      msg = msg,
      x = assert(w.x),
      y = assert(w.y),
      filename = assert(w.f),
   }
end

function errors.any(all_errs)
   if #all_errs == 0 then
      return true
   else
      return false, all_errs
   end
end

function errors.clear_redundant_errors(errs)
   local redundant = {}
   local lastx, lasty = 0, 0
   for i, err in ipairs(errs) do
      err.i = i
   end
   table.sort(errs, function(a, b)
      local af = assert(a.filename)
      local bf = assert(b.filename)
      return af < bf or
      (af == bf and (a.y < b.y or
      (a.y == b.y and (a.x < b.x or
      (a.x == b.x and (a.i < b.i))))))
   end)
   for i, err in ipairs(errs) do
      err.i = nil
      if err.x == lastx and err.y == lasty then
         table.insert(redundant, i)
      end
      lastx, lasty = err.x, err.y
   end
   for i = #redundant, 1, -1 do
      table.remove(errs, redundant[i])
   end
end

local wk = {
   ["unknown"] = true,
   ["unused"] = true,
   ["redeclaration"] = true,
   ["branch"] = true,
   ["hint"] = true,
   ["debug"] = true,
   ["unread"] = true,
}
errors.warning_kinds = wk

return errors

end

-- module teal.facts from teal/facts.lua
package.preload["teal.facts"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local tldebug = require("teal.debug")
local TL_DEBUG_FACTS = tldebug.TL_DEBUG_FACTS




local types = require("teal.types")




local a_type = types.a_type
local show_type = types.show_type
local unite = types.unite




local util = require("teal.util")
local sorted_keys = util.sorted_keys

local facts = { TruthyFact = {}, NotFact = {}, AndFact = {}, OrFact = {}, EqFact = {}, IsFact = {}, FactDatabase = {} }























































































local IsFact = facts.IsFact
local EqFact = facts.EqFact
local AndFact = facts.AndFact
local OrFact = facts.OrFact
local NotFact = facts.NotFact
local TruthyFact = facts.TruthyFact
local FactDatabase = facts.FactDatabase

local IsFact_mt = {
   __tostring = function(f)
      return ("(%s is %s)"):format(f.var, show_type(f.typ))
   end,
}

setmetatable(IsFact, {
   __call = function(_, fact)
      fact.fact = "is"
      assert(fact.w)
      return setmetatable(fact, IsFact_mt)
   end,
})

local EqFact_mt = {
   __tostring = function(f)
      return ("(%s == %s)"):format(f.var, show_type(f.typ))
   end,
}

setmetatable(EqFact, {
   __call = function(_, fact)
      fact.fact = "=="
      assert(fact.w)
      return setmetatable(fact, EqFact_mt)
   end,
})

local TruthyFact_mt = {
   __tostring = function(_f)
      return "*"
   end,
}

setmetatable(TruthyFact, {
   __call = function(_, fact)
      fact.fact = "truthy"
      return setmetatable(fact, TruthyFact_mt)
   end,
})

local NotFact_mt = {
   __tostring = function(f)
      return ("(not %s)"):format(tostring(f.f1))
   end,
}

setmetatable(NotFact, {
   __call = function(_, fact)
      fact.fact = "not"
      return setmetatable(fact, NotFact_mt)
   end,
})

local AndFact_mt = {
   __tostring = function(f)
      return ("(%s and %s)"):format(tostring(f.f1), tostring(f.f2))
   end,
}

setmetatable(AndFact, {
   __call = function(_, fact)
      fact.fact = "and"
      return setmetatable(fact, AndFact_mt)
   end,
})

local OrFact_mt = {
   __tostring = function(f)
      return ("(%s or %s)"):format(tostring(f.f1), tostring(f.f2))
   end,
}

setmetatable(OrFact, {
   __call = function(_, fact)
      fact.fact = "or"
      return setmetatable(fact, OrFact_mt)
   end,
})


local FACT_TRUTHY = TruthyFact({})
facts.FACT_TRUTHY = FACT_TRUTHY

function facts.facts_and(w, f1, f2)
   if not f1 and not f2 then
      return
   end
   return AndFact({ f1 = f1, f2 = f2, w = w })
end

function facts.facts_or(w, f1, f2)
   return OrFact({ f1 = f1 or FACT_TRUTHY, f2 = f2 or FACT_TRUTHY, w = w })
end

function facts.facts_not(w, f1)
   if f1 then
      return NotFact({ f1 = f1, w = w })
   else
      return nil
   end
end


local function unite_types(w, t1, t2)
   return unite(w, { t2, t1 })
end


local function intersect_types(ck, w, t1, t2)
   if t2.typename == "union" then
      t1, t2 = t2, t1
   end
   if t1.typename == "union" then
      local out = {}
      for _, t in ipairs(t1.types) do
         if ck:is_a(t, t2) then
            table.insert(out, t)
         end
      end
      if #out > 0 then
         return unite(w, out)
      end
   end
   if ck:is_a(t1, t2) then
      return t1
   elseif ck:is_a(t2, t1) then
      return t2
   else
      return a_type(w, "nil", {})
   end
end

local function resolve_if_union(ck, t)
   local rt = ck:to_structural(t)
   if rt.typename == "union" then
      return rt
   end
   return t
end


local function subtract_types(ck, w, t1, t2)
   local typs = {}

   t1 = resolve_if_union(ck, t1)


   if not (t1.typename == "union") then
      return t1
   end

   t2 = resolve_if_union(ck, t2)
   local t2types = t2.typename == "union" and t2.types or { t2 }

   for _, at in ipairs(t1.types) do
      local not_present = true
      for _, bt in ipairs(t2types) do
         if ck:same_type(at, bt) then
            not_present = false
            break
         end
      end
      if not_present then
         table.insert(typs, at)
      end
   end

   if #typs == 0 then
      return a_type(w, "nil", {})
   end

   return unite(w, typs)
end

local eval_not
local not_facts
local or_facts
local and_facts

local function invalid_from(f)
   return IsFact({ fact = "is", var = f.var, typ = a_type(f.w, "invalid", {}), w = f.w })
end





not_facts = function(ck, fs)
   local ret = {}
   for var, f in pairs(fs) do
      local typ = ck:find_var_type(f.var, "check_only")

      if not typ then
         ret[var] = EqFact({ var = var, typ = a_type(f.w, "invalid", {}), w = f.w, no_infer = f.no_infer })
      elseif f.fact == "==" then

         ret[var] = EqFact({ var = var, typ = typ, w = f.w, no_infer = true })
      elseif typ.typename == "typevar" then
         assert(f.fact == "is")

         ret[var] = EqFact({ var = var, typ = typ, w = f.w, no_infer = true })
      elseif not ck:is_a(f.typ, typ) then
         assert(f.fact == "is")
         ck:add_warning("branch", f.w, f.var .. " (of type %s) can never be a %s", show_type(typ), show_type(f.typ))
         ret[var] = EqFact({ var = var, typ = a_type(f.w, "invalid", {}), w = f.w, no_infer = f.no_infer })
      else
         assert(f.fact == "is")
         ret[var] = IsFact({ var = var, typ = subtract_types(ck, f.w, typ, f.typ), w = f.w, no_infer = f.no_infer })
      end
   end
   return ret
end

eval_not = function(ck, f)
   if not f then
      return {}
   elseif f.fact == "is" then
      return not_facts(ck, { [f.var] = f })
   elseif f.fact == "not" then
      return facts.eval_fact(ck, f.f1)
   elseif f.fact == "and" and f.f2 and f.f2.fact == "truthy" then
      return eval_not(ck, f.f1)
   elseif f.fact == "or" and f.f2 and f.f2.fact == "truthy" then
      return eval_not(ck, f.f1)
   elseif f.fact == "and" then
      return or_facts(ck, eval_not(ck, f.f1), eval_not(ck, f.f2))
   elseif f.fact == "or" then
      return and_facts(ck, eval_not(ck, f.f1), eval_not(ck, f.f2))
   else
      return not_facts(ck, facts.eval_fact(ck, f))
   end
end

or_facts = function(_ck, fs1, fs2)
   local ret = {}

   for var, f in pairs(fs2) do
      if fs1[var] then
         local united = unite_types(f.w, f.typ, fs1[var].typ)
         if fs1[var].fact == "is" and f.fact == "is" then
            ret[var] = IsFact({ var = var, typ = united, w = f.w })
         else
            ret[var] = EqFact({ var = var, typ = united, w = f.w })
         end
      end
   end

   return ret
end

and_facts = function(ck, fs1, fs2)
   local ret = {}
   local has = {}

   for var, f in pairs(fs1) do
      local rt
      local ctor = EqFact
      if fs2[var] then
         if fs2[var].fact == "is" and f.fact == "is" then
            ctor = IsFact
         end
         rt = intersect_types(ck, f.w, f.typ, fs2[var].typ)
      else
         rt = f.typ
      end
      local ff = ctor({ var = var, typ = rt, w = f.w, no_infer = f.no_infer })
      ret[var] = ff
      has[ff.fact] = true
   end

   for var, f in pairs(fs2) do
      if not fs1[var] then
         ret[var] = EqFact({ var = var, typ = f.typ, w = f.w, no_infer = f.no_infer })
         has["=="] = true
      end
   end

   if has["is"] and has["=="] then
      for _, f in pairs(ret) do
         f.fact = "=="
      end
   end

   return ret
end

function facts.eval_fact(ck, f)
   if not f then
      return {}
   elseif f.fact == "is" then
      local typ = ck:find_var_type(f.var, "check_only")
      if not typ then
         return { [f.var] = invalid_from(f) }
      end
      if not (typ.typename == "typevar") then
         if ck:is_a(typ, f.typ) then


            return { [f.var] = f }
         elseif not ck:is_a(f.typ, typ) then
            ck:add_error(f.w, f.var .. " (of type %s) can never be a %s", typ, f.typ)
            return { [f.var] = invalid_from(f) }
         end
      end
      return { [f.var] = f }
   elseif f.fact == "==" then
      return { [f.var] = f }
   elseif f.fact == "not" then
      return eval_not(ck, f.f1)
   elseif f.fact == "truthy" then
      return {}
   elseif f.fact == "and" and f.f2 and f.f2.fact == "truthy" then
      return facts.eval_fact(ck, f.f1)
   elseif f.fact == "or" and f.f2 and f.f2.fact == "truthy" then
      return eval_not(ck, f.f1)
   elseif f.fact == "and" then
      return and_facts(ck, facts.eval_fact(ck, f.f1), facts.eval_fact(ck, f.f2))
   elseif f.fact == "or" then
      return or_facts(ck, facts.eval_fact(ck, f.f1), facts.eval_fact(ck, f.f2))
   end
end

if TL_DEBUG_FACTS then
   local eval_indent = -1
   local real_eval_fact = facts.eval_fact
   facts.eval_fact = function(self, known)
      eval_indent = eval_indent + 1
      tldebug.write(("   "):rep(eval_indent))
      tldebug.write("eval fact: ", tostring(known), "\n")
      local fcts = real_eval_fact(self, known)
      if fcts then
         for _, k in ipairs(sorted_keys(fcts)) do
            local f = fcts[k]
            tldebug.write(("   "):rep(eval_indent), "=> ", tostring(f), "\n")
         end
      else
         tldebug.write(("   "):rep(eval_indent), "=> .\n")
      end
      tldebug.flush()
      eval_indent = eval_indent - 1
      return fcts
   end
end

function FactDatabase.new()
   local self = {
      db = {},
   }
   setmetatable(self, { __index = FactDatabase })
   return self
end

function FactDatabase:set_truthy(w)
   self.db[w] = FACT_TRUTHY
end

function FactDatabase:set_is(w, var, typ)
   self.db[w] = IsFact({ var = var, typ = typ, w = w })
end

function FactDatabase:set_eq(w, var, typ)
   self.db[w] = EqFact({ var = var, typ = typ, w = w })
end

function FactDatabase:set_or(w, e1, e2)
   self.db[w] = OrFact({ f1 = self.db[e1] or FACT_TRUTHY, f2 = self.db[e2] or FACT_TRUTHY, w = w })
end

function FactDatabase:set_not(w, e1)
   self.db[w] = facts.facts_not(w, self.db[e1])
end

function FactDatabase:set_and(w, e1, e2)
   self.db[w] = facts.facts_and(w, self.db[e1], self.db[e2])
end

function FactDatabase:set_from(w, from)
   if from then
      self.db[w] = self.db[from]
   end
end

function FactDatabase:unset(w)
   self.db[w] = nil
end

function FactDatabase:get(w)
   return self.db[w]
end

return facts

end

-- module teal.gen.lua_compat from teal/gen/lua_compat.lua
package.preload["teal.gen.lua_compat"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG

local environment = require("teal.environment")



local parser = require("teal.parser")


local node_at = parser.node_at

local metamethods = require("teal.metamethods")
local unop_to_metamethod = metamethods.unop_to_metamethod
local binop_to_metamethod = metamethods.binop_to_metamethod

local traversal = require("teal.traversal")

local traverse_nodes = traversal.traverse_nodes

local util = require("teal.util")
local sorted_keys = util.sorted_keys

local lua_compat = {}


local compat_code_cache = {}

local function add_compat_entries(program, used_set, gen_compat)
   if not next(used_set) or gen_compat == "off" then
      return
   end

   local tl_debug = TL_DEBUG
   TL_DEBUG = nil

   local used_list = sorted_keys(used_set)

   local compat_loaded = false

   local n = 1
   local function load_code(name, text)
      local code = compat_code_cache[name]
      if not code then
         code = parser.parse(text, "@<internal>.lua")
         compat_code_cache[name] = code
      end
      for _, c in ipairs(code) do
         table.insert(program, n, c)
         n = n + 1
      end
   end

   local function req(m)
      return (gen_compat == "optional") and
      "pcall(require, '" .. m .. "')" or
      "true, require('" .. m .. "')"
   end

   for _, name in ipairs(used_list) do
      if name == "table.unpack" then
         load_code(name, "local _tl_table_unpack = unpack or table.unpack")
      elseif name == "table.pack" then
         load_code(name, [[local _tl_table_pack = table.pack or function(...) return { n = select("#", ...), ... } end]])
      elseif name == "bit32" then
         load_code(name, "local bit32 = bit32; if not bit32 then local p, m = " .. req("bit32") .. "; if p then bit32 = m end")
      elseif name == "mt" then
         load_code(name, "local _tl_mt = function(m, s, a, b) return (getmetatable(s == 1 and a or b)[m](a, b) end")
      elseif name == "math.maxinteger" then
         load_code(name, "local _tl_math_maxinteger = math.maxinteger or math.pow(2,53)")
      elseif name == "math.mininteger" then
         load_code(name, "local _tl_math_mininteger = math.mininteger or -math.pow(2,53) - 1")
      elseif name == "type" then
         load_code(name, "local type = type")
      else
         if not compat_loaded then
            load_code("compat", "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = " .. req("compat53.module") .. "; if p then _tl_compat = m end")
            compat_loaded = true
         end
         load_code(name, (("local $NAME = _tl_compat and _tl_compat.$NAME or $NAME"):gsub("$NAME", name)))
      end
   end
   program.y = 1

   TL_DEBUG = tl_debug
end

local function convert_node_to_compat_call(node, mod_name, fn_name, e1, e2)
   node.op.op = "@funcall"
   node.op.arity = 2
   node.op.prec = 100
   node.e1 = node_at(node, { kind = "op", op = parser.operator(node, 2, ".") })
   node.e1.e1 = node_at(node, { kind = "identifier", tk = mod_name })
   node.e1.e2 = node_at(node, { kind = "identifier", tk = fn_name })
   node.e2 = node_at(node, { kind = "expression_list" })
   node.e2[1] = e1
   node.e2[2] = e2
end

local function convert_node_to_compat_mt_call(node, mt_name, which_self, e1, e2)
   node.op.op = "@funcall"
   node.op.arity = 2
   node.op.prec = 100
   node.e1 = node_at(node, { kind = "identifier", tk = "_tl_mt" })
   node.e2 = node_at(node, { kind = "expression_list" })
   node.e2[1] = node_at(node, { kind = "string", tk = "\"" .. mt_name .. "\"" })
   node.e2[2] = node_at(node, { kind = "integer", tk = tostring(which_self) })
   node.e2[3] = e1
   node.e2[4] = e2
end

local bit_operators = {
   ["&"] = "band",
   ["|"] = "bor",
   ["~"] = "bxor",
   [">>"] = "rshift",
   ["<<"] = "lshift",
}

local function adjust_code(ast, needs_compat, gen_compat, gen_target)
   if gen_target == "5.4" then
      return
   end

   local visit_node = {
      cbs = {},
   }

   if gen_compat ~= "off" then
      visit_node.cbs["op"] = {
         after = function(_, node, _children)
            if node.op.op == "is" then
               if node.e2.casttype.typename == "integer" then
                  needs_compat["math"] = true
               elseif node.e2.casttype.typename ~= "nil" then
                  needs_compat["type"] = true
               end
            elseif node.op.op == "." then
               if node.op.needs_compat then

                  if node.e1.kind == "variable" and node.e2.kind == "identifier" then
                     local key = node.e1.tk .. "." .. node.e2.tk
                     node.kind = "variable"
                     node.tk = "_tl_" .. node.e1.tk .. "_" .. node.e2.tk
                     needs_compat[key] = true
                  end
               end
            elseif node.op.op == "~" and gen_target == "5.1" then
               if node.op.meta_on_operand then
                  needs_compat["mt"] = true
                  convert_node_to_compat_mt_call(node, unop_to_metamethod[node.op.op], 1, node.e1)
               else
                  needs_compat["bit32"] = true
                  convert_node_to_compat_call(node, "bit32", "bnot", node.e1)
               end
            elseif node.op.op == "//" and gen_target == "5.1" then
               if node.op.meta_on_operand then
                  needs_compat["mt"] = true
                  convert_node_to_compat_mt_call(node, "__idiv", node.op.meta_on_operand, node.e1, node.e2)
               else
                  local div = node_at(node, { kind = "op", op = parser.operator(node, 2, "/"), e1 = node.e1, e2 = node.e2 })
                  convert_node_to_compat_call(node, "math", "floor", div)
               end
            elseif bit_operators[node.op.op] and gen_target == "5.1" then
               if node.op.meta_on_operand then
                  needs_compat["mt"] = true
                  convert_node_to_compat_mt_call(node, binop_to_metamethod[node.op.op], node.op.meta_on_operand, node.e1, node.e2)
               else
                  needs_compat["bit32"] = true
                  convert_node_to_compat_call(node, "bit32", bit_operators[node.op.op], node.e1, node.e2)
               end
            end
         end,
      }
   end

   traverse_nodes(nil, ast, visit_node, {})

   add_compat_entries(ast, needs_compat, gen_compat)
end

function lua_compat.apply(result)
   if result.compat_applied then
      return
   end
   result.compat_applied = true

   local gen_compat = result.env.opts.gen_compat or environment.DEFAULT_GEN_COMPAT
   local gen_target = result.env.opts.gen_target or environment.DEFAULT_GEN_TARGET

   adjust_code(result.ast, result.needs_compat, gen_compat, gen_target)
end

return lua_compat

end

-- module teal.gen.lua_generator from teal/gen/lua_generator.lua
package.preload["teal.gen.lua_generator"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local utf8 = _tl_compat and _tl_compat.utf8 or utf8





local targets = require("teal.gen.targets")


local types = require("teal.types")












local traversal = require("teal.traversal")



local lua_generator = { Options = {} }












local tight_op = {
   [1] = {
      ["-"] = true,
      ["~"] = true,
      ["#"] = true,
   },
   [2] = {
      ["."] = true,
      [":"] = true,
   },
}

local spaced_op = {
   [1] = {
      ["not"] = true,
   },
   [2] = {
      ["or"] = true,
      ["and"] = true,
      ["<"] = true,
      [">"] = true,
      ["<="] = true,
      [">="] = true,
      ["~="] = true,
      ["=="] = true,
      ["|"] = true,
      ["~"] = true,
      ["&"] = true,
      ["<<"] = true,
      [">>"] = true,
      [".."] = true,
      ["+"] = true,
      ["-"] = true,
      ["*"] = true,
      ["/"] = true,
      ["//"] = true,
      ["%"] = true,
      ["^"] = true,
   },
}


lua_generator.default_opts = {
   preserve_indent = true,
   preserve_newlines = true,
   preserve_hashbang = false,
}

lua_generator.fast_opts = {
   preserve_indent = false,
   preserve_newlines = true,
   preserve_hashbang = false,
}

function lua_generator.generate(ast, gen_target, opts)
   local indent = 0

   opts = opts or lua_generator.default_opts







   local save_indent = {}

   local function increment_indent(_, node)
      local child = node.body or node[1]
      if not child then
         return
      end
      if child.y ~= node.y then
         if indent == 0 and #save_indent > 0 then
            indent = save_indent[#save_indent] + 1
         else
            indent = indent + 1
         end
      else
         table.insert(save_indent, indent)
         indent = 0
      end
   end

   local function decrement_indent(node, child)
      if child.y ~= node.y then
         indent = indent - 1
      else
         indent = table.remove(save_indent)
      end
   end

   if not opts.preserve_indent then
      increment_indent = nil
      decrement_indent = function() end
   end

   local function add_string(out, s)
      table.insert(out, s)
      if string.find(s, "\n", 1, true) then
         for _nl in s:gmatch("\n") do
            out.h = out.h + 1
         end
      end
   end

   local function add_child(out, child, space, current_indent)
      if #child == 0 then
         return
      end

      if child.y ~= -1 and child.y < out.y then
         out.y = child.y
      end

      if child.y > out.y + out.h and opts.preserve_newlines then
         local delta = child.y - (out.y + out.h)
         out.h = out.h + delta
         table.insert(out, ("\n"):rep(delta))
      else
         if space then
            if space ~= "" then
               table.insert(out, space)
            end
            current_indent = nil
         end
      end
      if current_indent and opts.preserve_indent then
         table.insert(out, ("   "):rep(current_indent))
      end
      table.insert(out, child)
      out.h = out.h + child.h
   end

   local function concat_output(out)
      for i, s in ipairs(out) do
         if type(s) == "table" then
            out[i] = concat_output(s)
         end
      end
      return table.concat(out)
   end

   local function print_record_def(typ)
      local out = { "{" }
      local i = 0
      for fname, ftype in traversal.fields_of(typ) do
         if ftype.typename == "typedecl" then
            local def = ftype.def
            if def.typename == "generic" then
               def = def.t
            end
            if def.typename == "record" then
               if i > 0 then
                  table.insert(out, ",")
               end
               i = i + 1
               table.insert(out, " ")
               table.insert(out, fname)
               table.insert(out, " = ")
               table.insert(out, print_record_def(def))
            end
         end
      end
      if i > 0 then
         table.insert(out, " ")
      end
      table.insert(out, "}")
      return table.concat(out)
   end

   local visit_node = {}

   local lua_54_attribute = {
      ["const"] = " <const>",
      ["close"] = " <close>",
      ["total"] = " <const>",
   }

   local function emit_exactly(_, node, _children)
      local out = { y = node.y, h = 0 }
      add_string(out, node.tk)
      return out
   end

   local emit_exactly_visitor_cbs = { after = emit_exactly }

   local emit_nothing_visitor_cbs = {
      after = function(_, node, _children)
         local out = { y = node.y, h = 0 }
         return out
      end,
   }

   local function starts_with_longstring(n)
      while n.e1 do n = n.e1 end
      return n.is_longstring
   end

   visit_node.cbs = {
      ["statements"] = {
         after = function(_, node, children)
            local out
            if opts.preserve_hashbang and node.hashbang then
               out = { y = 1, h = 0 }
               table.insert(out, node.hashbang)
            else
               out = { y = node.y, h = 0 }
            end
            local space
            for i, child in ipairs(children) do
               add_child(out, child, space, indent)
               if node[i].semicolon then
                  table.insert(out, ";")
                  space = " "
               else
                  space = "; "
               end
            end
            return out
         end,
      },
      ["local_declaration"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "local ")
            for i, var in ipairs(node.vars) do
               if i > 1 then
                  add_string(out, ", ")
               end
               add_string(out, var.tk)
               if var.attribute and gen_target == "5.4" then
                  add_string(out, lua_54_attribute[var.attribute])
               end
            end
            if children[3] then
               table.insert(out, " =")
               add_child(out, children[3], " ")
            end
            return out
         end,
      },
      ["local_type"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            if not node.var.elide_type then
               table.insert(out, "local")
               add_child(out, children[1], " ")
               table.insert(out, " =")
               add_child(out, children[2], " ")
            end
            return out
         end,
      },
      ["global_type"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            if children[2] then
               add_child(out, children[1])
               table.insert(out, " =")
               add_child(out, children[2], " ")
            end
            return out
         end,
      },
      ["global_declaration"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            if children[3] then
               add_child(out, children[1])
               table.insert(out, " =")
               add_child(out, children[3], " ")
            end
            return out
         end,
      },
      ["assignment"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            add_child(out, children[1])
            table.insert(out, " =")
            add_child(out, children[3], " ")
            return out
         end,
      },
      ["if"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            for i, child in ipairs(children) do
               add_child(out, child, i > 1 and " ", child.y ~= node.y and indent)
            end
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["if_block"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            if node.if_block_n == 1 then
               table.insert(out, "if")
            elseif not node.exp then
               table.insert(out, "else")
            else
               table.insert(out, "elseif")
            end
            if node.exp then
               add_child(out, children[1], " ")
               table.insert(out, " then")
            end
            add_child(out, children[2], " ")
            decrement_indent(node, node.body)
            return out
         end,
      },
      ["while"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "while")
            add_child(out, children[1], " ")
            table.insert(out, " do")
            add_child(out, children[2], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["repeat"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "repeat")
            add_child(out, children[1], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "until " }, " ", indent)
            add_child(out, children[2])
            return out
         end,
      },
      ["do"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "do")
            add_child(out, children[1], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["forin"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "for")
            add_child(out, children[1], " ")
            table.insert(out, " in")
            add_child(out, children[2], " ")
            table.insert(out, " do")
            add_child(out, children[3], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["fornum"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "for")
            add_child(out, children[1], " ")
            table.insert(out, " =")
            add_child(out, children[2], " ")
            table.insert(out, ",")
            add_child(out, children[3], " ")
            if children[4] then
               table.insert(out, ",")
               add_child(out, children[4], " ")
            end
            table.insert(out, " do")
            add_child(out, children[5], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["return"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "return")
            if #children[1] > 0 then
               add_child(out, children[1], " ")
            end
            return out
         end,
      },
      ["break"] = {
         after = function(_, node, _children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "break")
            return out
         end,
      },
      ["variable_list"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            local space
            for i, child in ipairs(children) do
               if i > 1 then
                  table.insert(out, ",")
                  space = " "
               end
               add_child(out, child, space, child.y ~= node.y and indent)
            end
            return out
         end,
      },
      ["literal_table"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            if #children == 0 then
               table.insert(out, "{}")
               return out
            end
            table.insert(out, "{")
            local n = #children
            for i, child in ipairs(children) do
               add_child(out, child, " ", child.y ~= node.y and indent)
               if i < n or node.yend ~= node.y then
                  table.insert(out, ",")
               end
            end
            decrement_indent(node, node[1])
            add_child(out, { y = node.yend, h = 0, [1] = "}" }, " ", indent)
            return out
         end,
      },
      ["literal_table_item"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            if node.key_parsed ~= "implicit" then
               if node.key_parsed == "short" then
                  children[1][1] = children[1][1]:sub(2, -2)
                  add_child(out, children[1])
                  table.insert(out, " = ")
               else
                  table.insert(out, "[")
                  if node.key_parsed == "long" and node.key.is_longstring then
                     table.insert(children[1], 1, " ")
                     table.insert(children[1], " ")
                  end
                  add_child(out, children[1])
                  table.insert(out, "] = ")
               end
            end
            add_child(out, children[2])
            return out
         end,
      },
      ["local_macroexp"] = {
         before = increment_indent,
         after = function(_, node, _children)
            return { y = node.y, h = 0 }
         end,
      },
      ["local_function"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "local function")
            add_child(out, children[1], " ")
            table.insert(out, "(")
            add_child(out, children[2])
            table.insert(out, ")")
            add_child(out, children[4], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["global_function"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "function")
            add_child(out, children[1], " ")
            table.insert(out, "(")
            add_child(out, children[2])
            table.insert(out, ")")
            add_child(out, children[4], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["record_function"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "function")
            add_child(out, children[1], " ")
            table.insert(out, node.is_method and ":" or ".")
            add_child(out, children[2])
            table.insert(out, "(")
            if node.is_method then

               table.remove(children[3], 1)
               if children[3][1] == "," then
                  table.remove(children[3], 1)
                  if children[3][1] == " " then
                     table.remove(children[3], 1)
                  end
               end
            end
            add_child(out, children[3])
            table.insert(out, ")")
            add_child(out, children[5], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["function"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "function(")
            add_child(out, children[1])
            table.insert(out, ")")
            add_child(out, children[3], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["paren"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "(")
            add_child(out, children[1], "", indent)
            table.insert(out, ")")
            return out
         end,
      },
      ["op"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            if node.op.op == "@funcall" then
               add_child(out, children[1], "", indent)
               table.insert(out, "(")
               add_child(out, children[3], "", indent)
               table.insert(out, ")")
            elseif node.op.op == "@index" then
               add_child(out, children[1], "", indent)
               table.insert(out, "[")
               if starts_with_longstring(node.e2) then
                  table.insert(children[3], 1, " ")
                  table.insert(children[3], " ")
               end
               add_child(out, children[3], "", indent)
               table.insert(out, "]")
            elseif node.op.op == "as" then
               add_child(out, children[1], "", indent)
            elseif node.op.op == "is" then
               if node.e2.casttype.typename == "integer" then
                  table.insert(out, "math.type(")
                  add_child(out, children[1], "", indent)
                  table.insert(out, ") == \"integer\"")
               elseif node.e2.casttype.typename == "nil" then
                  add_child(out, children[1], "", indent)
                  table.insert(out, " == nil")
               else
                  table.insert(out, "type(")
                  add_child(out, children[1], "", indent)
                  table.insert(out, ") == \"")
                  add_child(out, children[3], "", indent)
                  table.insert(out, "\"")
               end
            elseif spaced_op[node.op.arity][node.op.op] or tight_op[node.op.arity][node.op.op] then
               local space = spaced_op[node.op.arity][node.op.op] and " " or ""
               if children[2] and node.op.prec > tonumber(children[2]) then
                  table.insert(children[1], 1, "(")
                  table.insert(children[1], ")")
               end
               if node.op.arity == 1 then
                  table.insert(out, node.op.op)
                  add_child(out, children[1], space, indent)
               elseif node.op.arity == 2 then
                  add_child(out, children[1], "", indent)
                  if space == " " then
                     table.insert(out, " ")
                  end
                  table.insert(out, node.op.op)
                  if children[4] and node.op.prec > tonumber(children[4]) then
                     table.insert(children[3], 1, "(")
                     table.insert(children[3], ")")
                  end
                  add_child(out, children[3], space, indent)
               end
            else
               error("unknown node op " .. node.op.op)
            end
            return out
         end,
      },
      ["newtype"] = {
         after = function(_, node, _children)
            local out = { y = node.y, h = 0 }
            local nt = node.newtype
            if nt.typename == "typedecl" then
               local def = nt.def
               if def.fields then
                  table.insert(out, print_record_def(def))
               elseif def.typename == "nominal" then
                  table.insert(out, table.concat(def.names, "."))
               else
                  table.insert(out, "{}")
               end
            end
            return out
         end,
      },
      ["goto"] = {
         after = function(_, node, _children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "goto ")
            table.insert(out, node.label)
            return out
         end,
      },
      ["label"] = {
         after = function(_, node, _children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "::")
            table.insert(out, node.label)
            table.insert(out, "::")
            return out
         end,
      },
      ["string"] = {
         after = function(_, node, children)






            if node.tk:sub(1, 1) == "[" or gen_target ~= "5.1" or not node.tk:find("\\", 1, true) then
               return emit_exactly(nil, node, children)
            end

            local str = node.tk
            local replaced = {}

            local i = 1
            local currstrstart = 1
            while true do
               local slashpos = str:find("\\", i)
               if not slashpos then break end
               local nextc = str:sub(slashpos + 1, slashpos + 1)
               if nextc == "z" then
                  table.insert(replaced, str:sub(currstrstart, slashpos - 1))
                  local wsend = str:find("%S", slashpos + 2)
                  currstrstart = wsend
                  i = currstrstart
               elseif nextc == "x" then
                  table.insert(replaced, str:sub(currstrstart, slashpos - 1))
                  local digits = str:sub(slashpos + 2, slashpos + 3)
                  local byte = tonumber(digits, 16)
                  table.insert(replaced, string.format("\\%03d", byte))
                  currstrstart = slashpos + 4
                  i = currstrstart
               elseif nextc == "u" then
                  table.insert(replaced, str:sub(currstrstart, slashpos - 1))
                  local _, e, hex_digits = str:find("{(.-)}", slashpos + 2)
                  local codepoint = tonumber(hex_digits, 16)
                  local sequence = utf8.char(codepoint)
                  table.insert(replaced, (sequence:gsub(".", function(c)
                     return ("\\%03d"):format(string.byte(c))
                  end)))
                  currstrstart = e + 1
                  i = currstrstart
               else
                  i = slashpos + 2
               end
            end
            if currstrstart <= #str then
               table.insert(replaced, str:sub(currstrstart))
            end

            local h = 0
            local finalstr = table.concat(replaced)
            for _ in finalstr:gmatch("\n") do
               h = h + 1
            end
            return {
               y = node.y,
               h = h,
               finalstr,
            }
         end,
      },

      ["variable"] = emit_exactly_visitor_cbs,
      ["identifier"] = emit_exactly_visitor_cbs,
      ["number"] = emit_exactly_visitor_cbs,
      ["integer"] = emit_exactly_visitor_cbs,
      ["nil"] = emit_exactly_visitor_cbs,
      ["boolean"] = emit_exactly_visitor_cbs,
      ["..."] = emit_exactly_visitor_cbs,
      ["argument"] = emit_exactly_visitor_cbs,
      ["type_identifier"] = emit_exactly_visitor_cbs,

      ["cast"] = emit_nothing_visitor_cbs,
      ["pragma"] = emit_nothing_visitor_cbs,
   }

   local visit_type = {}
   visit_type.cbs = {}
   local default_type_visitor = {
      after = function(_, typ, _children)
         local out = { y = typ.y or -1, h = 0 }
         local r = typ.typename == "nominal" and typ.resolved or typ
         local lua_type = types.lua_primitives[r.typename] or "table"
         if r.fields and r.is_userdata then
            lua_type = "userdata"
         end
         table.insert(out, lua_type)
         return out
      end,
   }

   visit_type.cbs["string"] = default_type_visitor
   visit_type.cbs["typedecl"] = default_type_visitor
   visit_type.cbs["typevar"] = default_type_visitor
   visit_type.cbs["typearg"] = default_type_visitor
   visit_type.cbs["function"] = default_type_visitor
   visit_type.cbs["thread"] = default_type_visitor
   visit_type.cbs["array"] = default_type_visitor
   visit_type.cbs["map"] = default_type_visitor
   visit_type.cbs["tupletable"] = default_type_visitor
   visit_type.cbs["record"] = default_type_visitor
   visit_type.cbs["enum"] = default_type_visitor
   visit_type.cbs["boolean"] = default_type_visitor
   visit_type.cbs["nil"] = default_type_visitor
   visit_type.cbs["number"] = default_type_visitor
   visit_type.cbs["integer"] = default_type_visitor
   visit_type.cbs["union"] = default_type_visitor
   visit_type.cbs["nominal"] = default_type_visitor
   visit_type.cbs["emptytable"] = default_type_visitor
   visit_type.cbs["literal_table_item"] = default_type_visitor
   visit_type.cbs["unresolved_emptytable_value"] = default_type_visitor
   visit_type.cbs["tuple"] = default_type_visitor
   visit_type.cbs["poly"] = default_type_visitor
   visit_type.cbs["any"] = default_type_visitor
   visit_type.cbs["unknown"] = default_type_visitor
   visit_type.cbs["invalid"] = default_type_visitor
   visit_type.cbs["none"] = default_type_visitor

   visit_node.cbs["expression_list"] = visit_node.cbs["variable_list"]
   visit_node.cbs["argument_list"] = visit_node.cbs["variable_list"]

   local out = traversal.traverse_nodes(nil, ast, visit_node, visit_type)

   local code
   if opts.preserve_newlines then
      code = { y = 1, h = 0 }
      add_child(code, out)
   else
      code = out
   end
   return (concat_output(code):gsub(" *\n", "\n"))
end

return lua_generator

end

-- module teal.gen.targets from teal/gen/targets.lua
package.preload["teal.gen.targets"] = function(...)
local targets = {}







function targets.detect(override)
   local version = override or _VERSION
   if version == "Lua 5.1" or
      version == "Lua 5.2" then
      return "5.1"
   elseif version == "Lua 5.3" then
      return "5.3"
   elseif version == "Lua 5.4" then
      return "5.4"
   end
end

return targets

end

-- module teal.input from teal/input.lua
package.preload["teal.input"] = function(...)
local check = require("teal.check.check")

local parser = require("teal.parser")


local environment = require("teal.environment")



local input = {}


function input.check(env, filename, code)
   if env.loaded and env.loaded[filename] then
      return env.loaded[filename]
   end

   local program, syntax_errors = parser.parse(code, filename)

   if (not env.keep_going) and #syntax_errors > 0 then
      return environment.register_failed(env, filename, syntax_errors)
   end

   local result = check.check(program, env, filename)

   result.syntax_errors = syntax_errors

   return result
end

return input

end

-- module teal.lexer from teal/lexer.lua
package.preload["teal.lexer"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table


local errors = require("teal.errors")


local util = require("teal.util")
local binary_search = util.binary_search

local lexer = { Comment = {}, Token = {} }







































do





































   local last_token_kind = {
      ["start"] = nil,
      ["any"] = nil,
      ["identifier"] = "identifier",
      ["got -"] = "op",
      ["got --"] = nil,
      ["got ."] = ".",
      ["got .."] = "op",
      ["got ="] = "op",
      ["got ~"] = "op",
      ["got ["] = "[",
      ["got 0"] = "number",
      ["got <"] = "op",
      ["got >"] = "op",
      ["got /"] = "op",
      ["got :"] = "op",
      ["got --["] = nil,
      ["string single"] = "$ERR$",
      ["string single got \\"] = "$ERR$",
      ["string double"] = "$ERR$",
      ["string double got \\"] = "$ERR$",
      ["string long"] = "$ERR$",
      ["string long got ]"] = "$ERR$",
      ["comment short"] = nil,
      ["comment long"] = "$ERR$",
      ["comment long got ]"] = "$ERR$",
      ["number dec"] = "integer",
      ["number decfloat"] = "number",
      ["number hex"] = "integer",
      ["number hexfloat"] = "number",
      ["number power"] = "number",
      ["number powersign"] = "$ERR$",
      ["pragma"] = nil,
      ["pragma any"] = nil,
      ["pragma word"] = "pragma_identifier",
   }

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

   local lex_any_char_states = {
      ["\""] = "string double",
      ["'"] = "string single",
      ["-"] = "got -",
      ["."] = "got .",
      ["0"] = "got 0",
      ["<"] = "got <",
      [">"] = "got >",
      ["/"] = "got /",
      [":"] = "got :",
      ["="] = "got =",
      ["~"] = "got ~",
      ["["] = "got [",
   }

   for c = string.byte("a"), string.byte("z") do
      lex_any_char_states[string.char(c)] = "identifier"
   end
   for c = string.byte("A"), string.byte("Z") do
      lex_any_char_states[string.char(c)] = "identifier"
   end
   lex_any_char_states["_"] = "identifier"

   for c = string.byte("1"), string.byte("9") do
      lex_any_char_states[string.char(c)] = "number dec"
   end

   local lex_word = {}
   for c = string.byte("a"), string.byte("z") do
      lex_word[string.char(c)] = true
   end
   for c = string.byte("A"), string.byte("Z") do
      lex_word[string.char(c)] = true
   end
   for c = string.byte("0"), string.byte("9") do
      lex_word[string.char(c)] = true
   end
   lex_word["_"] = true

   local lex_decimals = {}
   for c = string.byte("0"), string.byte("9") do
      lex_decimals[string.char(c)] = true
   end

   local lex_hexadecimals = {}
   for c = string.byte("0"), string.byte("9") do
      lex_hexadecimals[string.char(c)] = true
   end
   for c = string.byte("a"), string.byte("f") do
      lex_hexadecimals[string.char(c)] = true
   end
   for c = string.byte("A"), string.byte("F") do
      lex_hexadecimals[string.char(c)] = true
   end

   local lex_any_char_kinds = {}
   local single_char_kinds = { "[", "]", "(", ")", "{", "}", ",", ";", "?" }
   for _, c in ipairs(single_char_kinds) do
      lex_any_char_kinds[c] = c
   end
   for _, c in ipairs({ "#", "+", "*", "|", "&", "%", "^" }) do
      lex_any_char_kinds[c] = "op"
   end

   local lex_space = {}
   for _, c in ipairs({ " ", "\t", "\v", "\n", "\r" }) do
      lex_space[c] = true
   end

   local escapable_characters = {
      a = true,
      b = true,
      f = true,
      n = true,
      r = true,
      t = true,
      v = true,
      z = true,
      ["\\"] = true,
      ["\'"] = true,
      ["\""] = true,
      ["\r"] = true,
      ["\n"] = true,
   }

   local function lex_string_escape(input, i, c)
      if escapable_characters[c] then
         return 0, true
      elseif c == "x" then
         return 2, (
         lex_hexadecimals[input:sub(i + 1, i + 1)] and
         lex_hexadecimals[input:sub(i + 2, i + 2)])

      elseif c == "u" then
         if input:sub(i + 1, i + 1) == "{" then
            local p = i + 2
            if not lex_hexadecimals[input:sub(p, p)] then
               return 2, false
            end
            while true do
               p = p + 1
               c = input:sub(p, p)
               if not lex_hexadecimals[c] then
                  return p - i, c == "}"
               end
            end
         end
      elseif lex_decimals[c] then
         local len = lex_decimals[input:sub(i + 1, i + 1)] and
         (lex_decimals[input:sub(i + 2, i + 2)] and 2 or 1) or
         0
         return len, tonumber(input:sub(i, i + len)) < 256
      else
         return 0, false
      end
   end

   lexer.lex = function(input, filename)
      local tokens = {}

      local state = "any"
      local fwd = true
      local y = 1
      local x = 0
      local i = 0
      local lc_open_lvl = 0
      local lc_close_lvl = 0
      local ls_open_lvl = 0
      local ls_close_lvl = 0
      local errs = {}
      local nt = 0

      local tx
      local ty
      local ti
      local in_token = false

      local comments

      local function begin_token()
         tx = x
         ty = y
         ti = i
         in_token = true
      end

      local function end_token(kind, tk)
         nt = nt + 1
         tokens[nt] = {
            x = tx,
            y = ty,
            tk = tk,
            kind = kind,
            comments = comments,
         }
         comments = nil
         in_token = false
      end

      local function end_token_identifier()
         local tk = input:sub(ti, i - 1)
         nt = nt + 1
         tokens[nt] = {
            x = tx,
            y = ty,
            tk = tk,
            kind = keywords[tk] and "keyword" or "identifier",
            comments = comments,
         }
         comments = nil
         in_token = false
      end

      local function end_token_prev(kind)
         local tk = input:sub(ti, i - 1)
         nt = nt + 1
         tokens[nt] = {
            x = tx,
            y = ty,
            tk = tk,
            kind = kind,
            comments = comments,
         }
         comments = nil
         in_token = false
      end

      local function end_token_here(kind)
         local tk = input:sub(ti, i)
         nt = nt + 1
         tokens[nt] = {
            x = tx,
            y = ty,
            tk = tk,
            kind = kind,
            comments = comments,

         }
         comments = nil
         in_token = false
      end

      local function drop_token()
         in_token = false
      end

      local function add_syntax_error(msg)
         local t = tokens[nt]
         table.insert(errs, {
            filename = filename,
            y = t.y,
            x = t.x,
            msg = msg or "invalid token '" .. t.tk .. "'",
         })
      end

      local function add_comment(text)
         if not comments then
            comments = {}
         end
         comments[#comments + 1] = {
            x = tx,
            y = ty,
            text = text,
         }
      end

      local bom = "\239\187\191"
      local bom_len = bom:len()
      if input:sub(1, bom_len) == bom then
         input = input:sub(bom_len + 1)
      end

      local len = #input
      if input:sub(1, 2) == "#!" then
         begin_token()
         i = input:find("\n")
         if not i then
            i = len + 1
         end
         end_token_prev("hashbang")
         y = 2
         x = 0
      end
      state = "any"

      while i <= len do
         if fwd then
            i = i + 1
            if i > len then
               break
            end
         end

         local c = input:sub(i, i)

         if fwd then
            if c == "\n" then
               y = y + 1
               x = 0
            else
               x = x + 1
            end
         else
            fwd = true
         end

         if state == "any" then
            local st = lex_any_char_states[c]
            if st then
               state = st
               begin_token()
            else
               local k = lex_any_char_kinds[c]
               if k then
                  begin_token()
                  end_token(k, c)
               elseif not lex_space[c] then
                  begin_token()
                  end_token_here("$ERR$")
                  add_syntax_error()
               end
            end
         elseif state == "identifier" then
            if not lex_word[c] then
               end_token_identifier()
               fwd = false
               state = "any"
            end
         elseif state == "string double" then
            if c == "\\" then
               state = "string double got \\"
            elseif c == "\"" then
               end_token_here("string")
               state = "any"
            end
         elseif state == "comment short" then
            if c == "\n" then
               add_comment(input:sub(ti, i - 1))
               state = "any"
            end
         elseif state == "got =" then
            local t
            if c == "=" then
               t = "=="
            else
               t = "="
               fwd = false
            end
            end_token("op", t)
            state = "any"
         elseif state == "got ." then
            if c == "." then
               state = "got .."
            elseif lex_decimals[c] then
               state = "number decfloat"
            else
               end_token(".", ".")
               fwd = false
               state = "any"
            end
         elseif state == "got :" then
            local t
            if c == ":" then
               t = "::"
            else
               t = ":"
               fwd = false
            end
            end_token(t, t)
            state = "any"
         elseif state == "got [" then
            if c == "[" then
               state = "string long"
            elseif c == "=" then
               ls_open_lvl = ls_open_lvl + 1
            else
               end_token("[", "[")
               fwd = false
               state = "any"
               ls_open_lvl = 0
            end
         elseif state == "number dec" then
            if lex_decimals[c] then

            elseif c == "." then
               state = "number decfloat"
            elseif c == "e" or c == "E" then
               state = "number powersign"
            else
               end_token_prev("integer")
               fwd = false
               state = "any"
            end
         elseif state == "got -" then
            if c == "-" then
               state = "got --"
            else
               end_token("op", "-")
               fwd = false
               state = "any"
            end
         elseif state == "got .." then
            if c == "." then
               end_token("...", "...")
            else
               end_token("op", "..")
               fwd = false
            end
            state = "any"
         elseif state == "number hex" then
            if lex_hexadecimals[c] then

            elseif c == "." then
               state = "number hexfloat"
            elseif c == "p" or c == "P" then
               state = "number powersign"
            else
               end_token_prev("integer")
               fwd = false
               state = "any"
            end
         elseif state == "got --" then
            if c == "[" then
               state = "got --["
            elseif c == "#" then
               state = "pragma"
            else
               fwd = false
               state = "comment short"
               drop_token()
            end
         elseif state == "pragma" then
            if not lex_word[c] then
               end_token_prev("pragma")
               if tokens[nt].tk == "--#pragma" then
                  state = "pragma any"
               else
                  state = "comment short"
                  table.remove(tokens)
                  nt = nt - 1
                  drop_token()
               end
               fwd = false
            end
         elseif state == "pragma any" then
            if c == "\n" then
               state = "any"
            elseif lex_word[c] then
               state = "pragma word"
               begin_token()
            elseif not lex_space[c] then
               begin_token()
               end_token_here("$ERR$")
               add_syntax_error()
            end
         elseif state == "pragma word" then
            if not lex_word[c] then
               end_token_prev("pragma_identifier")
               fwd = false
               state = (c == "\n") and "any" or "pragma any"
            end
         elseif state == "got 0" then
            if c == "x" or c == "X" then
               state = "number hex"
            elseif c == "e" or c == "E" then
               state = "number powersign"
            elseif lex_decimals[c] then
               state = "number dec"
            elseif c == "." then
               state = "number decfloat"
            else
               end_token_prev("integer")
               fwd = false
               state = "any"
            end
         elseif state == "got --[" then
            if c == "[" then
               state = "comment long"
            elseif c == "=" then
               lc_open_lvl = lc_open_lvl + 1
            else
               fwd = false
               state = "comment short"
               drop_token()
               lc_open_lvl = 0
            end
         elseif state == "comment long" then
            if c == "]" then
               state = "comment long got ]"
            end
         elseif state == "comment long got ]" then
            if c == "]" and lc_close_lvl == lc_open_lvl then
               add_comment(input:sub(ti, i))
               drop_token()
               state = "any"
               lc_open_lvl = 0
               lc_close_lvl = 0
            elseif c == "=" then
               lc_close_lvl = lc_close_lvl + 1
            else
               state = "comment long"
               lc_close_lvl = 0
            end
         elseif state == "string double got \\" then
            local skip, valid = lex_string_escape(input, i, c)
            i = i + skip
            if not valid then
               end_token_here("$ERR$")
               add_syntax_error("malformed string")
            end
            x = x + skip
            state = "string double"
         elseif state == "string single" then
            if c == "\\" then
               state = "string single got \\"
            elseif c == "'" then
               end_token_here("string")
               state = "any"
            end
         elseif state == "string single got \\" then
            local skip, valid = lex_string_escape(input, i, c)
            i = i + skip
            if not valid then
               end_token_here("$ERR$")
               add_syntax_error("malformed string")
            end
            x = x + skip
            state = "string single"
         elseif state == "got ~" then
            local t
            if c == "=" then
               t = "~="
            else
               t = "~"
               fwd = false
            end
            end_token("op", t)
            state = "any"
         elseif state == "got <" then
            local t
            if c == "=" then
               t = "<="
            elseif c == "<" then
               t = "<<"
            else
               t = "<"
               fwd = false
            end
            end_token("op", t)
            state = "any"
         elseif state == "got >" then
            local t
            if c == "=" then
               t = ">="
            elseif c == ">" then
               t = ">>"
            else
               t = ">"
               fwd = false
            end
            end_token("op", t)
            state = "any"
         elseif state == "got /" then
            local t
            if c == "/" then
               t = "//"
            else
               t = "/"
               fwd = false
            end
            end_token("op", t)
            state = "any"
         elseif state == "string long" then
            if c == "]" then
               state = "string long got ]"
            end
         elseif state == "string long got ]" then
            if c == "]" then
               if ls_close_lvl == ls_open_lvl then
                  end_token_here("string")
                  state = "any"
                  ls_open_lvl = 0
                  ls_close_lvl = 0
               end
            elseif c == "=" then
               ls_close_lvl = ls_close_lvl + 1
            else
               state = "string long"
               ls_close_lvl = 0
            end
         elseif state == "number hexfloat" then
            if c == "p" or c == "P" then
               state = "number powersign"
            elseif not lex_hexadecimals[c] then
               end_token_prev("number")
               fwd = false
               state = "any"
            end
         elseif state == "number decfloat" then
            if c == "e" or c == "E" then
               state = "number powersign"
            elseif not lex_decimals[c] then
               end_token_prev("number")
               fwd = false
               state = "any"
            end
         elseif state == "number powersign" then
            if c == "-" or c == "+" then
               state = "number power"
            elseif lex_decimals[c] then
               state = "number power"
            elseif lex_space[c] then
               end_token_prev("$ERR$")
               fwd = false
               add_syntax_error("malformed number")
               state = "any"
            else
               end_token_here("$ERR$")
               add_syntax_error("malformed number")
               state = "any"
            end
         elseif state == "number power" then
            if not lex_decimals[c] then
               end_token_prev("number")
               fwd = false
               state = "any"
            end
         end
      end

      if in_token then
         if last_token_kind[state] then
            end_token_prev(last_token_kind[state])
            if last_token_kind[state] == "$ERR$" then
               local state_type = state:sub(1, 6)
               if state_type == "string" then
                  add_syntax_error("malformed string")
               elseif state_type == "number" then
                  add_syntax_error("malformed number")
               elseif state_type == "commen" then
                  add_syntax_error("unfinished long comment")
               else
                  add_syntax_error()
               end
            elseif keywords[tokens[nt].tk] then
               tokens[nt].kind = "keyword"
            end
         else
            drop_token()
         end
      end

      table.insert(tokens, { x = x + 1, y = y, tk = "$EOF$", kind = "$EOF$", comments = comments })

      return tokens, errs
   end
end

lexer.get_token_at = function(tks, y, x)
   local _, found = binary_search(
   tks, nil,
   function(tk)
      return tk.y < y or
      (tk.y == y and tk.x <= x)
   end)


   if found and
      found.y == y and
      found.x <= x and x < found.x + #found.tk then

      return found.tk
   end
end

return lexer

end

-- module teal.loader from teal/loader.lua
package.preload["teal.loader"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local load = _tl_compat and _tl_compat.load or load; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local environment = require("teal.environment")
local lua_generator = require("teal.gen.lua_generator")
local package_loader = require("teal.package_loader")
local input = require("teal.input")


local loader = {}
















local function env_for(env_tbl)
   if not env_tbl then
      if not package_loader.env then
         package_loader.env = environment.for_runtime()
      end
      return assert(package_loader.env)
   end

   if not loader.load_envs then
      loader.load_envs = setmetatable({}, { __mode = "k" })
   end

   loader.load_envs[env_tbl] = loader.load_envs[env_tbl] or environment.for_runtime()
   return loader.load_envs[env_tbl]
end

function loader.load(teal_code, chunkname, mode, ...)
   local env = env_for(...)
   local filename = chunkname or ("string \"" .. teal_code:sub(45) .. (#teal_code > 45 and "..." or "") .. "\".tl")
   local result = input.check(env, filename, teal_code)

   local errs = result.syntax_errors
   if #errs > 0 then
      return nil, (chunkname or "") .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg
   end

   if mode and mode:match("c") then
      if #result.type_errors > 0 then
         local errout = {}
         for _, err in ipairs(result.type_errors) do
            table.insert(errout, err.filename .. ":" .. err.y .. ":" .. err.x .. ": " .. (err.msg or ""))
         end
         return nil, table.concat(errout, "\n")
      end

      mode = mode:gsub("c", "")
   end

   local lua_code = lua_generator.generate(result.ast, package_loader.env.opts.gen_target, lua_generator.fast_opts)

   return load(lua_code, chunkname, mode, ...)
end

return loader

end

-- module teal.macroexps from teal/macroexps.lua
package.preload["teal.macroexps"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs


local parser = require("teal.parser")
local Node = parser.Node

local node_at = parser.node_at

local traversal = require("teal.traversal")


local traverse_nodes = traversal.traverse_nodes



local util = require("teal.util")
local shallow_copy_table = util.shallow_copy_table

local macroexps = {}







local function traverse_macroexp(macroexp, on_arg_id, on_node)
   local root = macroexp.exp
   local argnames = {}
   for i, a in ipairs(macroexp.args) do
      argnames[a.tk] = i
   end

   local visit_node = {
      cbs = {
         ["variable"] = {
            after = function(_, node, _children)
               local i = argnames[node.tk]
               if not i then
                  return nil
               end

               return on_arg_id(node, i)
            end,
         },
         ["..."] = {
            after = function(_, node, _children)
               local i = argnames[node.tk]
               if not i then
                  return nil
               end

               return on_arg_id(node, i)
            end,
         },
      },
      after = on_node,
   }

   return traverse_nodes(nil, root, visit_node, {})
end

function macroexps.expand(orignode, args, macroexp)
   local on_arg_id = function(node, i)
      if node.kind == '...' then

         local nd = node_at(orignode, {
            kind = "expression_list",
         })
         for n = i, #args do
            nd[n - i + 1] = args[n]
         end
         return { Node, nd }
      else



         local nd = args[i] or node_at(orignode, { kind = "nil", tk = "nil" })
         return { Node, nd }
      end
   end

   local on_node = function(_, node, children, ret)
      local orig = ret and ret[2] or node

      local out = shallow_copy_table(orig)

      local map = {}
      for _, pair in pairs(children) do
         if type(pair) == "table" then
            map[pair[1]] = pair[2]
         end
      end

      for k, v in pairs(orig) do
         if type(v) == "table" and map[v] then
            (out)[k] = map[v]
         end
      end

      out.yend = out.yend and (orignode.y + (out.yend - out.y)) or nil
      out.xend = nil
      out.y = orignode.y
      out.x = orignode.x
      return { node, out }
   end

   local p = traverse_macroexp(macroexp, on_arg_id, on_node)
   orignode.expanded = p[2]
end

function macroexps.check_arg_use(ck, macroexp)
   local used = {}

   local on_arg_id = function(node, _i)
      if used[node.tk] then
         ck:add_error(node, "cannot use argument '" .. node.tk .. "' multiple times in macroexp")
      else
         used[node.tk] = true
      end
   end

   traverse_macroexp(macroexp, on_arg_id, nil)
end

function macroexps.apply(orignode)
   local expanded = orignode.expanded
   orignode.expanded = nil

   for k, _ in pairs(orignode) do
      (orignode)[k] = nil
   end
   for k, v in pairs(expanded) do
      (orignode)[k] = v
   end
end

return macroexps

end

-- module teal.metamethods from teal/metamethods.lua
package.preload["teal.metamethods"] = function(...)
local metamethods = {}





metamethods.unop_to_metamethod = {
   ["#"] = "__len",
   ["-"] = "__unm",
   ["~"] = "__bnot",
}

metamethods.binop_to_metamethod = {
   ["+"] = "__add",
   ["-"] = "__sub",
   ["*"] = "__mul",
   ["/"] = "__div",
   ["%"] = "__mod",
   ["^"] = "__pow",
   ["//"] = "__idiv",
   ["&"] = "__band",
   ["|"] = "__bor",
   ["~"] = "__bxor",
   ["<<"] = "__shl",
   [">>"] = "__shr",
   [".."] = "__concat",
   ["=="] = "__eq",
   ["<"] = "__lt",
   ["<="] = "__le",
   ["@index"] = "__index",
   ["is"] = "__is",
}

metamethods.flip_binop_to_metamethod = {
   [">"] = "__lt",
   [">="] = "__le",
}

return metamethods

end

-- module teal.package_loader from teal/package_loader.lua
package.preload["teal.package_loader"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local load = _tl_compat and _tl_compat.load or load; local package = _tl_compat and _tl_compat.package or package; local table = _tl_compat and _tl_compat.table or table; local environment = require("teal.environment")


local require_file = require("teal.check.require_file")

local lua_generator = require("teal.gen.lua_generator")

local package_loader = {}



local function tl_package_loader(module_name)
   local env = package_loader.env
   if not env then
      package_loader.env = environment.for_runtime()
      env = package_loader.env
   end

   local result, found_filename, tried = require_file.search_and_load(env, module_name)
   if not found_filename then
      return table.concat(tried, "\n\t")
   end

   local errs = result.syntax_errors
   if #errs > 0 then
      error(found_filename .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg)
   end



   local code = assert(lua_generator.generate(result.ast, env.opts.gen_target, lua_generator.fast_opts))
   local chunk, err = load(code, "@" .. found_filename, "t")
   if not chunk then
      error("Internal Compiler Error: Teal generator produced invalid Lua. Please report a bug at https://github.com/teal-language/tl\n\n" .. err)
   end

   return function(modname, loader_data)
      if loader_data == nil then
         loader_data = found_filename
      end
      local ret = chunk(modname, loader_data)
      return ret
   end, found_filename
end

function package_loader.install_loader()
   local searchers = package.searchers or package.loaders
   table.insert(searchers, 2, tl_package_loader)
end

return package_loader

end

-- module teal.parser from teal/parser.lua
package.preload["teal.parser"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table


local attributes = require("teal.attributes")

local is_attribute = attributes.is_attribute

local errors = require("teal.errors")



local types = require("teal.types")






















local a_type = types.a_type
local raw_type = types.raw_type
local simple_types = types.simple_types

local lexer = require("teal.lexer")































































































































































































local parser = {}








function parser.node_is_require_call(n)
   if not (n.e1 and n.e2) then
      return nil
   end
   if n.op and n.op.op == "." then

      return parser.node_is_require_call(n.e1)
   elseif n.e1.kind == "variable" and n.e1.tk == "require" and
      n.e2.kind == "expression_list" and #n.e2 == 1 and
      n.e2[1].kind == "string" then


      return n.e2[1].conststr
   end
   return nil
end

function parser.node_is_funcall(node)
   return node.kind == "op" and node.op.op == "@funcall"
end
























local parse_type_list
local parse_typeargs_if_any
local parse_expression
local parse_expression_and_tk
local parse_statements
local parse_argument_list
local parse_argument_type_list
local parse_type
local parse_type_declaration
local parse_interface_name


local parse_enum_body
local parse_record_body
local parse_type_body_fns

local function fail(ps, i, msg)
   if not ps.tokens[i] then
      local eof = ps.tokens[#ps.tokens]
      table.insert(ps.errs, { filename = ps.filename, y = eof.y, x = eof.x, msg = msg or "unexpected end of file" })
      return #ps.tokens
   end
   table.insert(ps.errs, { filename = ps.filename, y = ps.tokens[i].y, x = ps.tokens[i].x, msg = assert(msg, "syntax error, but no error message provided") })
   return math.min(#ps.tokens, i + 1)
end

local function end_at(node, tk)
   node.yend = tk.y
   node.xend = tk.x + #tk.tk - 1
end

local function verify_tk(ps, i, tk)
   if ps.tokens[i].tk == tk then
      return i + 1
   end
   return fail(ps, i, "syntax error, expected '" .. tk .. "'")
end

local function verify_end(ps, i, istart, node)
   if ps.tokens[i].tk == "end" then
      local endy, endx = ps.tokens[i].y, ps.tokens[i].x
      node.yend = endy
      node.xend = endx + 2
      if node.kind ~= "function" and endy ~= node.y and endx ~= node.x then
         if not ps.end_alignment_hint then
            ps.end_alignment_hint = { filename = ps.filename, y = node.y, x = node.x, msg = "syntax error hint: construct starting here is not aligned with its 'end' at " .. ps.filename .. ":" .. endy .. ":" .. endx .. ":" }
         end
      end
      return i + 1
   end
   end_at(node, ps.tokens[i])
   if ps.end_alignment_hint then
      table.insert(ps.errs, ps.end_alignment_hint)
      ps.end_alignment_hint = nil
   end
   return fail(ps, i, "syntax error, expected 'end' to close construct started at " .. ps.filename .. ":" .. ps.tokens[istart].y .. ":" .. ps.tokens[istart].x .. ":")
end

local node_mt = {
   __tostring = function(n)
      return n.f .. ":" .. n.y .. ":" .. n.x .. " " .. n.kind
   end,
}

local function new_node(ps, i, kind)
   local t = ps.tokens[i]
   return setmetatable({ f = ps.filename, y = t.y, x = t.x, tk = t.tk, kind = kind or (t.kind) }, node_mt)
end

local function new_type(ps, i, typename)
   local token = ps.tokens[i]
   return raw_type(ps.filename, token.y, token.x, typename)
end

local function new_first_order_type(ps, i, tn)
   return new_type(ps, i, tn)
end

local function new_generic(ps, i, typeargs, typ)
   local gt = new_type(ps, i, "generic")
   gt.typeargs = typeargs
   gt.t = typ
   return gt
end

local function new_typedecl(ps, i, def)
   local t = new_type(ps, i, "typedecl")
   t.def = def
   return t
end

local function new_tuple(ps, i, typelist, is_va)
   local t = new_type(ps, i, "tuple")
   t.is_va = is_va
   t.tuple = typelist or {}
   return t, t.tuple
end

local function new_nominal(ps, i, name)
   local t = new_type(ps, i, "nominal")
   if name then
      t.names = { name }
   end
   return t
end

local function verify_kind(ps, i, kind, node_kind)
   if ps.tokens[i].kind == kind then
      return i + 1, new_node(ps, i, node_kind)
   end
   return fail(ps, i, "syntax error, expected " .. kind)
end



local function skip(ps, i, skip_fn)
   local err_ps = {
      filename = ps.filename,
      tokens = ps.tokens,
      errs = {},
      required_modules = {},
      parse_lang = ps.parse_lang,
   }
   return skip_fn(err_ps, i)
end

local function failskip(ps, i, msg, skip_fn, starti)
   local skip_i = skip(ps, starti or i, skip_fn)
   fail(ps, i, msg)
   return skip_i
end

local function parse_type_body(ps, i, istart, node, tn)
   local typeargs
   local def
   i, typeargs = parse_typeargs_if_any(ps, i)

   def = new_first_order_type(ps, istart, tn)

   local ok
   i, ok = parse_type_body_fns[tn](ps, i, def)
   if not ok then
      return fail(ps, i, "expected a type")
   end

   i = verify_end(ps, i, istart, node)

   if typeargs then
      return i, new_generic(ps, istart, typeargs, def)
   end

   return i, def
end

local function skip_type_body(ps, i)
   local tn = ps.tokens[i].tk
   i = i + 1
   assert(parse_type_body_fns[tn], tn .. " has no parse body function")
   local ii, tt = parse_type_body(ps, i, i - 1, {}, tn)
   return ii, not not tt
end

local function parse_table_value(ps, i)
   local next_word = ps.tokens[i].tk
   if next_word == "record" or next_word == "interface" then
      local skip_i, e = skip(ps, i, skip_type_body)
      if e then
         fail(ps, i, next_word == "record" and
         "syntax error: this syntax is no longer valid; declare nested record inside a record" or
         "syntax error: cannot declare interface inside a table; use a statement")
         return skip_i, new_node(ps, i, "error_node")
      end
   elseif next_word == "enum" and ps.tokens[i + 1].kind == "string" then
      i = failskip(ps, i, "syntax error: this syntax is no longer valid; declare nested enum inside a record", skip_type_body)
      return i, new_node(ps, i - 1, "error_node")
   end

   local e
   i, e = parse_expression(ps, i)
   if not e then
      e = new_node(ps, i - 1, "error_node")
   end
   return i, e
end

local function parse_table_item(ps, i, n)
   local node = new_node(ps, i, "literal_table_item")
   if ps.tokens[i].kind == "$EOF$" then
      return fail(ps, i, "unexpected eof")
   end

   if ps.tokens[i].tk == "[" then
      node.key_parsed = "long"
      i = i + 1
      i, node.key = parse_expression_and_tk(ps, i, "]")
      i = verify_tk(ps, i, "=")
      i, node.value = parse_table_value(ps, i)
      return i, node, n
   elseif ps.tokens[i].kind == "identifier" then
      if ps.tokens[i + 1].tk == "=" then
         node.key_parsed = "short"
         i, node.key = verify_kind(ps, i, "identifier", "string")
         node.key.conststr = node.key.tk
         node.key.tk = '"' .. node.key.tk .. '"'
         i = verify_tk(ps, i, "=")
         i, node.value = parse_table_value(ps, i)
         return i, node, n
      elseif ps.tokens[i + 1].tk == ":" then
         node.key_parsed = "short"
         local orig_i = i
         local try_ps = {
            filename = ps.filename,
            tokens = ps.tokens,
            errs = {},
            required_modules = ps.required_modules,
            parse_lang = ps.parse_lang,
         }
         i, node.key = verify_kind(try_ps, i, "identifier", "string")
         node.key.conststr = node.key.tk
         node.key.tk = '"' .. node.key.tk .. '"'
         i = verify_tk(try_ps, i, ":")
         i, node.itemtype = parse_type(try_ps, i)
         if node.itemtype and ps.tokens[i].tk == "=" then
            i = verify_tk(try_ps, i, "=")
            i, node.value = parse_table_value(try_ps, i)
            if node.value then
               for _, e in ipairs(try_ps.errs) do
                  table.insert(ps.errs, e)
               end
               return i, node, n
            end
         end

         node.itemtype = nil
         i = orig_i
      end
   end

   node.key = new_node(ps, i, "integer")
   node.key_parsed = "implicit"
   node.key.constnum = n
   node.key.tk = tostring(n)
   i, node.value = parse_expression(ps, i)
   if not node.value then
      return fail(ps, i, "expected an expression")
   end
   return i, node, n + 1
end








local function parse_list(ps, i, list, close, sep, parse_item)
   local n = 1
   while ps.tokens[i].kind ~= "$EOF$" do
      if close[ps.tokens[i].tk] then
         end_at(list, ps.tokens[i])
         break
      end
      local item
      local oldn = n
      i, item, n = parse_item(ps, i, n)
      n = n or oldn
      table.insert(list, item)
      if ps.tokens[i].tk == "," then
         i = i + 1
         if sep == "sep" and close[ps.tokens[i].tk] then
            fail(ps, i, "unexpected '" .. ps.tokens[i].tk .. "'")
            return i, list
         end
      elseif sep == "term" and ps.tokens[i].tk == ";" then
         i = i + 1
      elseif not close[ps.tokens[i].tk] then
         local options = {}
         for k, _ in pairs(close) do
            table.insert(options, "'" .. k .. "'")
         end
         table.sort(options)
         local first = options[1]:sub(2, -2)
         local msg

         if first == ")" and ps.tokens[i].tk == "=" then
            msg = "syntax error, cannot perform an assignment here (did you mean '=='?)"
            i = failskip(ps, i, msg, parse_expression, i + 1)
         else
            table.insert(options, "','")
            msg = "syntax error, expected one of: " .. table.concat(options, ", ")
            fail(ps, i, msg)
         end



         if first ~= "}" and ps.tokens[i].y ~= ps.tokens[i - 1].y then

            table.insert(ps.tokens, i, { tk = first, y = ps.tokens[i - 1].y, x = ps.tokens[i - 1].x + 1, kind = "keyword" })
            return i, list
         end
      end
   end
   return i, list
end

local function parse_bracket_list(ps, i, list, open, close, sep, parse_item)
   i = verify_tk(ps, i, open)
   i = parse_list(ps, i, list, { [close] = true }, sep, parse_item)
   i = verify_tk(ps, i, close)
   return i, list
end

local function parse_table_literal(ps, i)
   local node = new_node(ps, i, "literal_table")
   return parse_bracket_list(ps, i, node, "{", "}", "term", parse_table_item)
end

local function parse_trying_list(ps, i, list, parse_item, ret_lookahead)
   local try_ps = {
      filename = ps.filename,
      tokens = ps.tokens,
      errs = {},
      required_modules = ps.required_modules,
      parse_lang = ps.parse_lang,
   }
   local tryi, item = parse_item(try_ps, i)
   if not item then
      return i, list
   end
   for _, e in ipairs(try_ps.errs) do
      table.insert(ps.errs, e)
   end
   i = tryi
   table.insert(list, item)
   while ps.tokens[i].tk == "," and
      (not ret_lookahead or
      (not (ps.tokens[i + 1].kind == "identifier" and
      ps.tokens[i + 2] and ps.tokens[i + 2].tk == ":"))) do

      i = i + 1
      i, item = parse_item(ps, i)
      table.insert(list, item)
   end
   return i, list
end

local function parse_anglebracket_list(ps, i, parse_item)
   local second = ps.tokens[i + 1]
   if second.tk == ">" then
      return fail(ps, i + 1, "type argument list cannot be empty")
   elseif second.tk == ">>" then

      second.tk = ">"
      fail(ps, i + 1, "type argument list cannot be empty")
      return i + 1
   end

   local typelist = {}
   i = verify_tk(ps, i, "<")
   i = parse_list(ps, i, typelist, { [">"] = true, [">>"] = true }, "sep", parse_item)
   if ps.tokens[i].tk == ">" then
      i = i + 1
   elseif ps.tokens[i].tk == ">>" then

      ps.tokens[i].tk = ">"
   else
      return fail(ps, i, "syntax error, expected '>'")
   end
   return i, typelist
end

local function parse_typearg(ps, i)
   local name = ps.tokens[i].tk
   local constraint
   local t = new_type(ps, i, "typearg")
   i = verify_kind(ps, i, "identifier")
   if ps.tokens[i].tk == "is" then
      i = i + 1
      i, constraint = parse_interface_name(ps, i)
   end
   t.typearg = name
   t.constraint = constraint
   return i, t
end

local function parse_return_types(ps, i)
   local iprev = i - 1
   local t
   i, t = parse_type_list(ps, i, "rets")
   if #t.tuple == 0 then
      t.x = ps.tokens[iprev].x
      t.y = ps.tokens[iprev].y
   end
   return i, t
end

parse_typeargs_if_any = function(ps, i)
   if ps.tokens[i].tk == "<" then
      return parse_anglebracket_list(ps, i, parse_typearg)
   end
   return i
end

local function parse_function_type(ps, i)
   local typeargs
   local typ = new_type(ps, i, "function")
   i = i + 1

   i, typeargs = parse_typeargs_if_any(ps, i)
   if ps.tokens[i].tk == "(" then
      i, typ.args, typ.maybe_method, typ.min_arity = parse_argument_type_list(ps, i)
      i, typ.rets = parse_return_types(ps, i)
   else
      typ.args = new_tuple(ps, i, { new_type(ps, i, "any") }, true)
      typ.rets = new_tuple(ps, i, { new_type(ps, i, "any") }, true)
      typ.is_method = false
      typ.min_arity = 0
   end

   if typeargs then
      return i, new_generic(ps, i, typeargs, typ)
   end

   return i, typ
end

local function parse_simple_type_or_nominal(ps, i)
   local tk = ps.tokens[i].tk
   local st = simple_types[tk]
   if st then
      return i + 1, new_type(ps, i, tk)
   elseif tk == "table" and ps.tokens[i + 1].tk ~= "." then
      local typ = new_type(ps, i, "map")
      typ.keys = new_type(ps, i, "any")
      typ.values = new_type(ps, i, "any")
      return i + 1, typ
   end

   local typ = new_nominal(ps, i, tk)
   i = i + 1
   while ps.tokens[i].tk == "." do
      i = i + 1
      if ps.tokens[i].kind == "identifier" then
         table.insert(typ.names, ps.tokens[i].tk)
         i = i + 1
      else
         return fail(ps, i, "syntax error, expected identifier")
      end
   end

   if ps.tokens[i].tk == "<" then
      i, typ.typevals = parse_anglebracket_list(ps, i, parse_type)
   end
   return i, typ
end

local function parse_base_type(ps, i)
   local tk = ps.tokens[i].tk
   if ps.tokens[i].kind == "identifier" then
      return parse_simple_type_or_nominal(ps, i)
   elseif tk == "{" then
      local istart = i
      i = i + 1
      local t
      i, t = parse_type(ps, i)
      if not t then
         return i
      end
      if ps.tokens[i].tk == "}" then
         local decl = new_type(ps, istart, "array")
         decl.elements = t
         end_at(decl, ps.tokens[i])
         i = verify_tk(ps, i, "}")
         return i, decl
      elseif ps.tokens[i].tk == "," then
         local decl = new_type(ps, istart, "tupletable")
         decl.types = { t }
         local n = 2
         repeat
            i = i + 1
            i, decl.types[n] = parse_type(ps, i)
            if not decl.types[n] then
               break
            end
            n = n + 1
         until ps.tokens[i].tk ~= ","
         end_at(decl, ps.tokens[i])
         i = verify_tk(ps, i, "}")
         return i, decl
      elseif ps.tokens[i].tk == ":" then
         local decl = new_type(ps, istart, "map")
         i = i + 1
         decl.keys = t
         i, decl.values = parse_type(ps, i)
         if not decl.values then
            return i
         end
         end_at(decl, ps.tokens[i])
         i = verify_tk(ps, i, "}")
         return i, decl
      end
      return fail(ps, i, "syntax error; did you forget a '}'?")
   elseif tk == "function" then
      return parse_function_type(ps, i)
   elseif tk == "nil" then
      return i + 1, new_type(ps, i, "nil")
   end
   return fail(ps, i, "expected a type")
end

parse_type = function(ps, i)
   if ps.tokens[i].tk == "(" then
      i = i + 1
      local t
      i, t = parse_type(ps, i)
      i = verify_tk(ps, i, ")")
      return i, t
   end

   local bt
   local istart = i
   i, bt = parse_base_type(ps, i)
   if not bt then
      return i
   end
   if ps.tokens[i].tk == "|" then
      local u = new_type(ps, istart, "union")
      u.types = { bt }
      while ps.tokens[i].tk == "|" do
         i = i + 1
         i, bt = parse_base_type(ps, i)
         if not bt then
            return i
         end
         table.insert(u.types, bt)
      end
      bt = u
   end
   return i, bt
end

parse_type_list = function(ps, i, mode)
   local t, list = new_tuple(ps, i)

   local first_token = ps.tokens[i].tk
   if mode == "rets" or mode == "decltuple" then
      if first_token == ":" then
         i = i + 1
      else
         return i, t
      end
   end

   local optional_paren = false
   if ps.tokens[i].tk == "(" then
      optional_paren = true
      i = i + 1
   end

   local prev_i = i
   i = parse_trying_list(ps, i, list, parse_type, mode == "rets")
   if i == prev_i and ps.tokens[i].tk ~= ")" then
      fail(ps, i - 1, "expected a type list")
   end

   if mode == "rets" and ps.tokens[i].tk == "..." then
      i = i + 1
      local nrets = #list
      if nrets > 0 then
         t.is_va = true
      else
         fail(ps, i, "unexpected '...'")
      end
   end

   if optional_paren then
      i = verify_tk(ps, i, ")")
   end

   return i, t
end

local function parse_function_args_rets_body(ps, i, node)
   local istart = i - 1
   i, node.typeargs = parse_typeargs_if_any(ps, i)
   i, node.args, node.min_arity = parse_argument_list(ps, i)
   i, node.rets = parse_return_types(ps, i)
   i, node.body = parse_statements(ps, i)
   end_at(node, ps.tokens[i])
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_function_value(ps, i)
   local node = new_node(ps, i, "function")
   i = verify_tk(ps, i, "function")
   return parse_function_args_rets_body(ps, i, node)
end

local function unquote(str)
   local f = str:sub(1, 1)
   if f == '"' or f == "'" then
      return str:sub(2, -2), false
   end
   f = str:match("^%[=*%[")
   local l = #f + 1
   return str:sub(l, -l), true
end

local function parse_literal(ps, i)
   local tk = ps.tokens[i].tk
   local kind = ps.tokens[i].kind
   if kind == "identifier" then
      return verify_kind(ps, i, "identifier", "variable")
   elseif kind == "string" then
      local node = new_node(ps, i, "string")
      node.conststr, node.is_longstring = unquote(tk)
      return i + 1, node
   elseif kind == "number" or kind == "integer" then
      local n = tonumber(tk)
      local node
      i, node = verify_kind(ps, i, kind)
      node.constnum = n
      return i, node
   elseif tk == "true" then
      return verify_kind(ps, i, "keyword", "boolean")
   elseif tk == "false" then
      return verify_kind(ps, i, "keyword", "boolean")
   elseif tk == "nil" then
      return verify_kind(ps, i, "keyword", "nil")
   elseif tk == "function" then
      return parse_function_value(ps, i)
   elseif tk == "{" then
      return parse_table_literal(ps, i)
   elseif kind == "..." then
      return verify_kind(ps, i, "...")
   elseif kind == "$ERR$" then
      return fail(ps, i, "invalid token")
   end
   return fail(ps, i, "syntax error")
end

local function node_is_require_call_or_pcall(n)
   local r = parser.node_is_require_call(n)
   if r then
      return r
   end
   if parser.node_is_funcall(n) and
      n.e1 and n.e1.tk == "pcall" and
      n.e2 and #n.e2 == 2 and
      n.e2[1].kind == "variable" and n.e2[1].tk == "require" and
      n.e2[2].kind == "string" and n.e2[2].conststr then


      return n.e2[2].conststr
   end
   return nil
end

do
   local precedences = {
      [1] = {
         ["not"] = 11,
         ["#"] = 11,
         ["-"] = 11,
         ["~"] = 11,
      },
      [2] = {
         ["or"] = 1,
         ["and"] = 2,
         ["is"] = 3,
         ["<"] = 3,
         [">"] = 3,
         ["<="] = 3,
         [">="] = 3,
         ["~="] = 3,
         ["=="] = 3,
         ["|"] = 4,
         ["~"] = 5,
         ["&"] = 6,
         ["<<"] = 7,
         [">>"] = 7,
         [".."] = 8,
         ["+"] = 9,
         ["-"] = 9,
         ["*"] = 10,
         ["/"] = 10,
         ["//"] = 10,
         ["%"] = 10,
         ["^"] = 12,
         ["as"] = 50,
         ["@funcall"] = 100,
         ["@index"] = 100,
         ["."] = 100,
         [":"] = 100,
      },
   }

   local is_right_assoc = {
      ["^"] = true,
      [".."] = true,
   }

   local function new_operator(tk, arity, op)
      return { y = tk.y, x = tk.x, arity = arity, op = op, prec = precedences[arity][op] }
   end

   parser.operator = function(node, arity, op)
      return { y = node.y, x = node.x, arity = arity, op = op, prec = precedences[arity][op] }
   end

   local args_starters = {
      ["("] = true,
      ["{"] = true,
      ["string"] = true,
   }

   local E

   local function after_valid_prefixexp(ps, prevnode, i)
      return ps.tokens[i - 1].kind == ")" or
      (prevnode.kind == "op" and
      (prevnode.op.op == "@funcall" or
      prevnode.op.op == "@index" or
      prevnode.op.op == "." or
      prevnode.op.op == ":")) or

      prevnode.kind == "identifier" or
      prevnode.kind == "variable"
   end



   local function failstore(ps, tkop, e1)
      return { f = ps.filename, y = tkop.y, x = tkop.x, kind = "paren", e1 = e1, failstore = true }
   end

   local function P(ps, i)
      if ps.tokens[i].kind == "$EOF$" then
         return i
      end
      local e1
      local t1 = ps.tokens[i]
      if precedences[1][t1.tk] ~= nil then
         local op = new_operator(t1, 1, t1.tk)
         i = i + 1
         local prev_i = i
         i, e1 = P(ps, i)
         if not e1 then
            fail(ps, prev_i, "expected an expression")
            return i
         end
         e1 = { f = ps.filename, y = t1.y, x = t1.x, kind = "op", op = op, e1 = e1 }
      elseif ps.tokens[i].tk == "(" then
         i = i + 1
         local prev_i = i
         i, e1 = parse_expression_and_tk(ps, i, ")")
         if not e1 then
            fail(ps, prev_i, "expected an expression")
            return i
         end
         e1 = { f = ps.filename, y = t1.y, x = t1.x, kind = "paren", e1 = e1 }
      else
         i, e1 = parse_literal(ps, i)
      end

      if not e1 then
         return i
      end

      while true do
         local tkop = ps.tokens[i]
         if tkop.kind == "," or tkop.kind == ")" then
            break
         end
         if tkop.tk == "." or tkop.tk == ":" then
            local op = new_operator(tkop, 2, tkop.tk)

            local prev_i = i

            local key
            i = i + 1
            if ps.tokens[i].kind ~= "identifier" then
               local skipped = skip(ps, i, parse_type)
               if skipped > i + 1 then
                  fail(ps, i, "syntax error, cannot declare a type here (missing 'local' or 'global'?)")
                  return skipped, failstore(ps, tkop, e1)
               end
            end
            i, key = verify_kind(ps, i, "identifier")
            if not key then
               return i, failstore(ps, tkop, e1)
            end

            if op.op == ":" then
               if not args_starters[ps.tokens[i].kind] then
                  if ps.tokens[i].tk == "=" then
                     fail(ps, i, "syntax error, cannot perform an assignment here (missing 'local' or 'global'?)")
                  else
                     fail(ps, i, "expected a function call for a method")
                  end
                  return i, failstore(ps, tkop, e1)
               end

               if not after_valid_prefixexp(ps, e1, prev_i) then
                  fail(ps, prev_i, "cannot call a method on this expression")
                  return i, failstore(ps, tkop, e1)
               end
            end

            e1 = { f = ps.filename, y = tkop.y, x = tkop.x, kind = "op", op = op, e1 = e1, e2 = key }
         elseif tkop.tk == "(" then
            local prev_tk = ps.tokens[i - 1]
            if tkop.y > prev_tk.y and ps.parse_lang ~= "lua" then
               table.insert(ps.tokens, i, { y = prev_tk.y, x = prev_tk.x + #prev_tk.tk, tk = ";", kind = ";" })
               break
            end

            local op = new_operator(tkop, 2, "@funcall")

            local prev_i = i

            local args = new_node(ps, i, "expression_list")
            i, args = parse_bracket_list(ps, i, args, "(", ")", "sep", parse_expression)

            if not after_valid_prefixexp(ps, e1, prev_i) then
               fail(ps, prev_i, "cannot call this expression")
               return i, failstore(ps, tkop, e1)
            end

            e1 = { f = ps.filename, y = args.y, x = args.x, kind = "op", op = op, e1 = e1, e2 = args }

            table.insert(ps.required_modules, node_is_require_call_or_pcall(e1))
         elseif tkop.tk == "[" then
            local op = new_operator(tkop, 2, "@index")

            local prev_i = i

            local idx
            i = i + 1
            i, idx = parse_expression_and_tk(ps, i, "]")

            if not after_valid_prefixexp(ps, e1, prev_i) then
               fail(ps, prev_i, "cannot index this expression")
               return i, failstore(ps, tkop, e1)
            end

            e1 = { f = ps.filename, y = tkop.y, x = tkop.x, kind = "op", op = op, e1 = e1, e2 = idx }
         elseif tkop.kind == "string" or tkop.kind == "{" then
            local op = new_operator(tkop, 2, "@funcall")

            local prev_i = i

            local args = new_node(ps, i, "expression_list")
            local argument
            if tkop.kind == "string" then
               argument = new_node(ps, i)
               argument.conststr = unquote(tkop.tk)
               i = i + 1
            else
               i, argument = parse_table_literal(ps, i)
            end

            if not after_valid_prefixexp(ps, e1, prev_i) then
               if tkop.kind == "string" then
                  fail(ps, prev_i, "cannot use a string here; if you're trying to call the previous expression, wrap it in parentheses")
               else
                  fail(ps, prev_i, "cannot use a table here; if you're trying to call the previous expression, wrap it in parentheses")
               end
               return i, failstore(ps, tkop, e1)
            end

            table.insert(args, argument)
            e1 = { f = ps.filename, y = args.y, x = args.x, kind = "op", op = op, e1 = e1, e2 = args }

            table.insert(ps.required_modules, node_is_require_call_or_pcall(e1))
         elseif tkop.tk == "as" or tkop.tk == "is" then
            local op = new_operator(tkop, 2, tkop.tk)

            i = i + 1
            local cast = new_node(ps, i, "cast")
            if ps.tokens[i].tk == "(" then
               i, cast.casttype = parse_type_list(ps, i, "casttype")
            else
               i, cast.casttype = parse_type(ps, i)
            end
            if not cast.casttype then
               return i, failstore(ps, tkop, e1)
            end
            e1 = { f = ps.filename, y = tkop.y, x = tkop.x, kind = "op", op = op, e1 = e1, e2 = cast, conststr = e1.conststr }
         else
            break
         end
      end

      return i, e1
   end

   E = function(ps, i, lhs, min_precedence)
      local lookahead = ps.tokens[i].tk
      while precedences[2][lookahead] and precedences[2][lookahead] >= min_precedence do
         local t1 = ps.tokens[i]
         local op = new_operator(t1, 2, t1.tk)
         i = i + 1
         local rhs
         i, rhs = P(ps, i)
         if not rhs then
            fail(ps, i, "expected an expression")
            return i
         end
         lookahead = ps.tokens[i].tk
         while precedences[2][lookahead] and ((precedences[2][lookahead] > (precedences[2][op.op])) or
            (is_right_assoc[lookahead] and (precedences[2][lookahead] == precedences[2][op.op]))) do
            i, rhs = E(ps, i, rhs, precedences[2][lookahead])
            if not rhs then
               fail(ps, i, "expected an expression")
               return i
            end
            lookahead = ps.tokens[i].tk
         end
         lhs = { f = ps.filename, y = t1.y, x = t1.x, kind = "op", op = op, e1 = lhs, e2 = rhs }
      end
      return i, lhs
   end

   parse_expression = function(ps, i)
      local lhs
      local istart = i
      i, lhs = P(ps, i)
      if lhs then
         i, lhs = E(ps, i, lhs, 0)
      end
      if lhs then
         return i, lhs, 0
      end

      if i == istart then
         i = fail(ps, i, "expected an expression")
      end
      return i
   end
end

parse_expression_and_tk = function(ps, i, tk)
   local e
   i, e = parse_expression(ps, i)
   if not e then
      e = new_node(ps, i - 1, "error_node")
   end
   if ps.tokens[i].tk == tk then
      i = i + 1
   else
      local msg = "syntax error, expected '" .. tk .. "'"
      if ps.tokens[i].tk == "=" then
         msg = "syntax error, cannot perform an assignment here (did you mean '=='?)"
      end


      for n = 0, 19 do
         local t = ps.tokens[i + n]
         if t.kind == "$EOF$" then
            break
         end
         if t.tk == tk then
            fail(ps, i, msg)
            return i + n + 1, e
         end
      end
      i = fail(ps, i, msg)
   end
   return i, e
end

local function parse_variable_name(ps, i)
   local node
   i, node = verify_kind(ps, i, "identifier")
   if not node then
      return i
   end
   if ps.tokens[i].tk == "<" then
      i = i + 1
      local annotation
      i, annotation = verify_kind(ps, i, "identifier")
      if annotation then
         if not is_attribute[annotation.tk] then
            fail(ps, i, "unknown variable annotation: " .. annotation.tk)
         end
         node.attribute = annotation.tk
      else
         fail(ps, i, "expected a variable annotation")
      end
      i = verify_tk(ps, i, ">")
   end
   return i, node
end

local function parse_argument(ps, i)
   local node
   if ps.tokens[i].tk == "..." then
      i, node = verify_kind(ps, i, "...", "argument")
      node.opt = true
   else
      i, node = verify_kind(ps, i, "identifier", "argument")
   end
   if ps.tokens[i].tk == "..." then
      fail(ps, i, "'...' needs to be declared as a typed argument")
   end
   if ps.tokens[i].tk == "?" then
      i = i + 1
      node.opt = true
   end
   if ps.tokens[i].tk == ":" then
      i = i + 1
      local argtype

      i, argtype = parse_type(ps, i)

      if node then
         node.argtype = argtype
      end
   end
   return i, node, 0
end

parse_argument_list = function(ps, i)
   local node = new_node(ps, i, "argument_list")
   i, node = parse_bracket_list(ps, i, node, "(", ")", "sep", parse_argument)
   local opts = false
   local min_arity = 0
   for a, fnarg in ipairs(node) do
      if fnarg.tk == "..." then
         if a ~= #node then
            fail(ps, i, "'...' can only be last argument")
            break
         end
      elseif fnarg.opt then
         opts = true
      elseif opts then
         return fail(ps, i, "non-optional arguments cannot follow optional arguments")
      else
         min_arity = min_arity + 1
      end
   end
   return i, node, min_arity
end









local function parse_argument_type(ps, i)
   local opt = 0
   local is_va = false
   local is_self = false
   local argument_name = nil

   if ps.tokens[i].kind == "identifier" then
      argument_name = ps.tokens[i].tk
      if ps.tokens[i + 1].tk == "?" then
         opt = i + 1
         if ps.tokens[i + 2].tk == ":" then
            i = i + 3
         end
      elseif ps.tokens[i + 1].tk == ":" then
         i = i + 2
      end
   elseif ps.tokens[i].kind == "?" then
      opt = i
      i = i + 1
   elseif ps.tokens[i].tk == "..." then
      if ps.tokens[i + 1].tk == "?" then
         fail(ps, i + 1, "cannot mix '?' and '...' in a declaration; '...' already implies optional")
         i = i + 1
      end
      if ps.tokens[i + 1].tk == ":" then
         i = i + 2
         is_va = true
      else
         return fail(ps, i, "cannot have untyped '...' when declaring the type of an argument")
      end
   end

   local typ; i, typ = parse_type(ps, i)
   if typ then
      if not is_va and ps.tokens[i].tk == "..." then
         i = i + 1
         is_va = true
         if opt > 0 then
            fail(ps, opt, "cannot mix '?' and '...' in a declaration; '...' already implies optional")
         end
      end

      if argument_name == "self" then
         is_self = true
      end
   end

   return i, { i = i, type = typ, is_va = is_va, is_self = is_self, opt = (opt > 0) or is_va }, 0
end

parse_argument_type_list = function(ps, i)
   local ars = {}
   i = parse_bracket_list(ps, i, ars, "(", ")", "sep", parse_argument_type)
   local t, list = new_tuple(ps, i)
   local n = #ars
   local min_arity = 0
   for l, ar in ipairs(ars) do
      list[l] = ar.type
      if ar.is_va and l < n then
         fail(ps, ar.i, "'...' can only be last argument")
      end
      if not ar.opt then
         min_arity = min_arity + 1
      end
   end
   if n > 0 and ars[n].is_va then
      t.is_va = true
   end
   return i, t, (n > 0 and ars[1].is_self), min_arity
end

local function parse_identifier(ps, i)
   if ps.tokens[i].kind == "identifier" then
      return i + 1, new_node(ps, i, "identifier")
   end
   i = fail(ps, i, "syntax error, expected identifier")
   return i, new_node(ps, i, "error_node")
end

local function parse_local_function(ps, i)
   i = verify_tk(ps, i, "local")
   i = verify_tk(ps, i, "function")
   local node = new_node(ps, i - 2, "local_function")
   i, node.name = parse_identifier(ps, i)
   return parse_function_args_rets_body(ps, i, node)
end






local function parse_function(ps, i, fk)
   local orig_i = i
   i = verify_tk(ps, i, "function")
   local fn = new_node(ps, i - 1, "global_function")
   local names = {}
   i, names[1] = parse_identifier(ps, i)
   while ps.tokens[i].tk == "." do
      i = i + 1
      i, names[#names + 1] = parse_identifier(ps, i)
   end
   if ps.tokens[i].tk == ":" then
      i = i + 1
      i, names[#names + 1] = parse_identifier(ps, i)
      fn.is_method = true
   end

   if #names > 1 then
      fn.kind = "record_function"
      local owner = names[1]
      owner.kind = "type_identifier"
      for i2 = 2, #names - 1 do
         local dot = parser.operator(names[i2], 2, ".")
         names[i2].kind = "identifier"
         owner = { f = ps.filename, y = names[i2].y, x = names[i2].x, kind = "op", op = dot, e1 = owner, e2 = names[i2] }
      end
      fn.fn_owner = owner
   end
   fn.name = names[#names]

   local selfx, selfy = ps.tokens[i].x, ps.tokens[i].y
   i = parse_function_args_rets_body(ps, i, fn)
   if fn.is_method and fn.args then
      table.insert(fn.args, 1, { f = ps.filename, x = selfx, y = selfy, tk = "self", kind = "identifier" })
      fn.min_arity = fn.min_arity + 1
   end

   if not fn.name then
      return orig_i + 1
   end

   if fn.kind == "record_function" and fk == "global" then
      fail(ps, orig_i, "record functions cannot be annotated as 'global'")
   elseif fn.kind == "global_function" and fk == "record" then
      fn.implicit_global_function = true
   end

   return i, fn
end

local function parse_if_block(ps, i, n, node, is_else)
   local block = new_node(ps, i, "if_block")
   i = i + 1
   block.if_parent = node
   block.if_block_n = n
   if not is_else then
      i, block.exp = parse_expression_and_tk(ps, i, "then")
      if not block.exp then
         return i
      end
   end
   i, block.body = parse_statements(ps, i)
   if not block.body then
      return i
   end
   block.yend, block.xend = block.body.yend, block.body.xend
   table.insert(node.if_blocks, block)
   return i, node
end

local function parse_if(ps, i)
   local istart = i
   local node = new_node(ps, i, "if")
   node.if_blocks = {}
   i, node = parse_if_block(ps, i, 1, node)
   if not node then
      return i
   end
   local n = 2
   while ps.tokens[i].tk == "elseif" do
      i, node = parse_if_block(ps, i, n, node)
      if not node then
         return i
      end
      n = n + 1
   end
   if ps.tokens[i].tk == "else" then
      i, node = parse_if_block(ps, i, n, node, true)
      if not node then
         return i
      end
   end
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_while(ps, i)
   local istart = i
   local node = new_node(ps, i, "while")
   i = verify_tk(ps, i, "while")
   i, node.exp = parse_expression_and_tk(ps, i, "do")
   i, node.body = parse_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_fornum(ps, i)
   local istart = i
   local node = new_node(ps, i, "fornum")
   i = i + 1
   i, node.var = parse_identifier(ps, i)
   i = verify_tk(ps, i, "=")
   i, node.from = parse_expression_and_tk(ps, i, ",")
   i, node.to = parse_expression(ps, i)
   if ps.tokens[i].tk == "," then
      i = i + 1
      i, node.step = parse_expression_and_tk(ps, i, "do")
   else
      i = verify_tk(ps, i, "do")
   end
   i, node.body = parse_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_forin(ps, i)
   local istart = i
   local node = new_node(ps, i, "forin")
   i = i + 1
   node.vars = new_node(ps, i, "variable_list")
   i, node.vars = parse_list(ps, i, node.vars, { ["in"] = true }, "sep", parse_identifier)
   i = verify_tk(ps, i, "in")
   node.exps = new_node(ps, i, "expression_list")
   i = parse_list(ps, i, node.exps, { ["do"] = true }, "sep", parse_expression)
   if #node.exps < 1 then
      return fail(ps, i, "missing iterator expression in generic for")
   elseif #node.exps > 3 then
      return fail(ps, i, "too many expressions in generic for")
   end
   i = verify_tk(ps, i, "do")
   i, node.body = parse_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_for(ps, i)
   if ps.tokens[i + 1].kind == "identifier" and ps.tokens[i + 2].tk == "=" then
      return parse_fornum(ps, i)
   else
      return parse_forin(ps, i)
   end
end

local function parse_repeat(ps, i)
   local node = new_node(ps, i, "repeat")
   i = verify_tk(ps, i, "repeat")
   i, node.body = parse_statements(ps, i)
   node.body.is_repeat = true
   i = verify_tk(ps, i, "until")
   i, node.exp = parse_expression(ps, i)
   end_at(node, ps.tokens[i - 1])
   return i, node
end

local function parse_do(ps, i)
   local istart = i
   local node = new_node(ps, i, "do")
   i = verify_tk(ps, i, "do")
   i, node.body = parse_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_break(ps, i)
   local node = new_node(ps, i, "break")
   i = verify_tk(ps, i, "break")
   return i, node
end

local function parse_goto(ps, i)
   local node = new_node(ps, i, "goto")
   i = verify_tk(ps, i, "goto")
   node.label = ps.tokens[i].tk
   i = verify_kind(ps, i, "identifier")
   return i, node
end

local function parse_label(ps, i)
   local node = new_node(ps, i, "label")
   i = verify_tk(ps, i, "::")
   node.label = ps.tokens[i].tk
   i = verify_kind(ps, i, "identifier")
   i = verify_tk(ps, i, "::")
   return i, node
end

local stop_statement_list = {
   ["end"] = true,
   ["else"] = true,
   ["elseif"] = true,
   ["until"] = true,
}

local stop_return_list = {
   [";"] = true,
   ["$EOF$"] = true,
}

for k, v in pairs(stop_statement_list) do
   stop_return_list[k] = v
end

local function parse_return(ps, i)
   local node = new_node(ps, i, "return")
   i = verify_tk(ps, i, "return")
   node.exps = new_node(ps, i, "expression_list")
   i = parse_list(ps, i, node.exps, stop_return_list, "sep", parse_expression)
   if ps.tokens[i].kind == ";" then
      i = i + 1
      if ps.tokens[i].kind ~= "$EOF$" and not stop_statement_list[ps.tokens[i].kind] then
         return fail(ps, i, "return must be the last statement of its block")
      end
   end
   return i, node
end

local function store_field_in_record(ps, i, field_name, newt, def, comments, meta)
   local field_order, fields, field_comments
   if meta then
      field_order, fields, field_comments = def.meta_field_order, def.meta_fields, def.meta_field_comments
   else
      field_order, fields, field_comments = def.field_order, def.fields, def.field_comments
   end

   if comments and not field_comments then
      field_comments = {}
      if meta then
         def.meta_field_comments = field_comments
      else
         def.field_comments = field_comments
      end
   end

   if not fields[field_name] then
      fields[field_name] = newt
      if comments then
         field_comments[field_name] = { comments }
      end
      table.insert(field_order, field_name)
      return true
   end

   local oldt = fields[field_name]
   local oldf = oldt.typename == "generic" and oldt.t or oldt
   local newf = newt.typename == "generic" and newt.t or newt

   local function store_comment_for_poly(poly)
      if comments then
         if not field_comments[field_name] then
            field_comments[field_name] = {}
            for idx = 1, #poly.types - 1 do
               field_comments[field_name][idx] = {}
            end
         end
         table.insert(field_comments[field_name], comments)
      elseif field_comments and field_comments[field_name] then
         table.insert(field_comments[field_name], {})
      end
   end

   if newf.typename == "function" then
      if oldf.typename == "function" then
         local p = new_type(ps, i, "poly")
         p.types = { oldt, newt }
         fields[field_name] = p
         store_comment_for_poly(p)
         return true
      elseif oldt.typename == "poly" then
         table.insert(oldt.types, newt)
         store_comment_for_poly(oldt)
         return true
      end
   end
   fail(ps, i, "attempt to redeclare field '" .. field_name .. "' (only functions can be overloaded)")
   return false
end

local function set_declname(def, declname)
   if def.typename == "generic" then
      def = def.t
   end

   if def.typename == "record" or def.typename == "interface" or def.typename == "enum" then
      if not def.declname then
         def.declname = declname
      end
   end
end

local function get_attached_comments(token)
   if not token.comments then
      return nil
   end

   local function is_long_comment(c)
      return c.text:match("^%-%-%[(=*)%[") ~= nil
   end
   local last_comment = token.comments[#token.comments]


   if is_long_comment(last_comment) then
      local _, newlines = string.gsub(last_comment.text, "\n", "")
      local diff_y = token.y - last_comment.y - newlines

      if diff_y >= 0 and diff_y <= 1 then
         return { last_comment }
      else
         return nil
      end
   end

   local diff_y = token.y - last_comment.y
   if diff_y < 0 or diff_y > 1 then
      return nil
   end
   local first_n = 1
   for i = #token.comments, 2, -1 do
      local prev = token.comments[i - 1]
      if is_long_comment(prev) then
         first_n = i
         break
      end

      if token.comments[i].y - prev.y > 1 then
         first_n = i
         break
      end
   end

   local attached_comments =
   table.move(token.comments, first_n, #token.comments, 1, {})

   return attached_comments
end

local function parse_nested_type(ps, i, def, tn)
   local istart = i
   i = i + 1
   local iv = i

   local v
   i, v = verify_kind(ps, i, "identifier", "type_identifier")
   if not v then
      return fail(ps, i, "expected a variable name")
   end

   local nt = new_node(ps, istart, "newtype")

   local ndef
   i, ndef = parse_type_body(ps, i, istart, nt, tn)
   if not ndef then
      return i
   end

   set_declname(ndef, v.tk)

   nt.newtype = new_typedecl(ps, istart, ndef)

   store_field_in_record(ps, iv, v.tk, nt.newtype, def, get_attached_comments(ps.tokens[istart]))
   return i
end

parse_enum_body = function(ps, i, def)
   def.enumset = {}
   while ps.tokens[i].tk ~= "$EOF$" and ps.tokens[i].tk ~= "end" do
      local item
      i, item = verify_kind(ps, i, "string", "string")
      if item then
         local name = unquote(item.tk)
         def.enumset[name] = true
         local comments = get_attached_comments(ps.tokens[i - 1])
         if comments then
            if not def.value_comments then
               def.value_comments = {}
            end
            def.value_comments[name] = comments
         end
      end
   end
   return i, true
end

local metamethod_names = {
   ["__add"] = true,
   ["__sub"] = true,
   ["__mul"] = true,
   ["__div"] = true,
   ["__mod"] = true,
   ["__pow"] = true,
   ["__unm"] = true,
   ["__idiv"] = true,
   ["__band"] = true,
   ["__bor"] = true,
   ["__bxor"] = true,
   ["__bnot"] = true,
   ["__shl"] = true,
   ["__shr"] = true,
   ["__concat"] = true,
   ["__len"] = true,
   ["__eq"] = true,
   ["__lt"] = true,
   ["__le"] = true,
   ["__index"] = true,
   ["__newindex"] = true,
   ["__call"] = true,
   ["__tostring"] = true,
   ["__pairs"] = true,
   ["__gc"] = true,
   ["__close"] = true,
   ["__is"] = true,
}

local function parse_macroexp(ps, istart, iargs)
   local node = new_node(ps, istart, "macroexp")

   local i
   if ps.tokens[istart + 1].tk == "<" then
      i, node.typeargs = parse_anglebracket_list(ps, istart + 1, parse_typearg)
   else
      i = iargs
   end

   i, node.args, node.min_arity = parse_argument_list(ps, i)
   i, node.rets = parse_return_types(ps, i)
   i = verify_tk(ps, i, "return")
   i, node.exp = parse_expression(ps, i)
   end_at(node, ps.tokens[i])
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_where_clause(ps, i, def)
   local node = new_node(ps, i, "macroexp")

   node.is_method = true
   node.args = new_node(ps, i, "argument_list")
   node.args[1] = new_node(ps, i, "argument")
   node.args[1].tk = "self"
   node.args[1].argtype = new_type(ps, i, "self");
   (node.args[1].argtype).display_type = def
   node.min_arity = 1
   node.rets = new_tuple(ps, i)
   node.rets.tuple[1] = new_type(ps, i, "boolean")
   i, node.exp = parse_expression(ps, i)
   end_at(node, ps.tokens[i - 1])
   return i, node
end

parse_interface_name = function(ps, i)
   local istart = i
   local typ
   i, typ = parse_simple_type_or_nominal(ps, i)
   if not (typ.typename == "nominal") then
      return fail(ps, istart, "expected an interface")
   end
   return i, typ
end

local function parse_array_interface_type(ps, i, def)
   if def.interface_list then
      local first = def.interface_list[1]
      if first.typename == "array" then
         return failskip(ps, i, "duplicated declaration of array element type", parse_type)
      end
   end
   local t
   i, t = parse_base_type(ps, i)
   if not t then
      return i
   end
   if not (t.typename == "array") then
      fail(ps, i, "expected an array declaration")
      return i
   end
   def.elements = t.elements
   return i, t
end












local function extract_userdata_from_interface_list(ps, i, def)
   for j = #def.interface_list, 1, -1 do
      local iface = def.interface_list[j]
      if iface.typename == "nominal" and #iface.names == 1 and iface.names[1] == "userdata" then
         table.remove(def.interface_list, j)
         if def.is_userdata then
            fail(ps, i, "duplicated 'userdata' declaration")
         end
         def.is_userdata = true
      end
   end
end

parse_record_body = function(ps, i, def)
   def.fields = {}
   def.field_order = {}

   if ps.tokens[i].tk == "{" then
      local atype
      i, atype = parse_array_interface_type(ps, i, def)
      if atype then
         def.interface_list = { atype }
      end
   end

   if ps.tokens[i].tk == "is" then
      i = i + 1

      if ps.tokens[i].tk == "{" then
         local atype
         i, atype = parse_array_interface_type(ps, i, def)
         if ps.tokens[i].tk == "," then
            i = i + 1
            i, def.interface_list = parse_trying_list(ps, i, {}, parse_interface_name)
         else
            def.interface_list = {}
         end
         if atype then
            table.insert(def.interface_list, 1, atype)
         end
      else
         i, def.interface_list = parse_trying_list(ps, i, {}, parse_interface_name)
      end

      if def.interface_list then
         extract_userdata_from_interface_list(ps, i, def)
      end
   end

   if ps.tokens[i].tk == "where" then
      local wstart = i
      i = i + 1
      local where_macroexp
      i, where_macroexp = parse_where_clause(ps, i, def)

      local typ = new_type(ps, wstart, "function")

      typ.is_method = true
      typ.min_arity = 1
      typ.args = new_tuple(ps, wstart, {
         a_type(where_macroexp, "self", { display_type = def }),
      })
      typ.rets = new_tuple(ps, wstart, { new_type(ps, wstart, "boolean") })
      typ.macroexp = where_macroexp

      def.meta_fields = {}
      def.meta_field_order = {}
      store_field_in_record(ps, i, "__is", typ, def, nil, "meta")
   end

   while not (ps.tokens[i].kind == "$EOF$" or ps.tokens[i].tk == "end") do
      local tn = ps.tokens[i].tk
      if ps.tokens[i].tk == "userdata" and ps.tokens[i + 1].tk ~= ":" then
         if def.is_userdata then
            fail(ps, i, "duplicated 'userdata' declaration")
         else
            def.is_userdata = true
         end
         i = i + 1
      elseif ps.tokens[i].tk == "{" then
         return fail(ps, i, "syntax error: this syntax is no longer valid; declare array interface at the top with 'is {...}'")
      elseif ps.tokens[i].tk == "type" and ps.tokens[i + 1].tk ~= ":" then
         local comments = get_attached_comments(ps.tokens[i])
         i = i + 1
         local iv = i

         local lt
         i, lt = parse_type_declaration(ps, i, "local_type")
         if not lt then
            return fail(ps, i, "expected a type definition")
         end

         local v = lt.var
         if not v then
            return fail(ps, i, "expected a variable name")
         end

         local nt = lt.value
         if not nt or not nt.newtype then
            return fail(ps, i, "expected a type definition")
         end

         local ntt = nt.newtype
         if ntt.is_alias then
            ntt.is_nested_alias = true
         end

         store_field_in_record(ps, iv, v.tk, nt.newtype, def, comments)
      elseif parse_type_body_fns[tn] and ps.tokens[i + 1].tk ~= ":" then
         if def.typename == "interface" and tn == "record" then
            i = failskip(ps, i, "interfaces cannot contain record definitions", skip_type_body)
         else
            i = parse_nested_type(ps, i, def, tn)
         end
      else
         local comments = get_attached_comments(ps.tokens[i])
         local is_metamethod = false
         if ps.tokens[i].tk == "metamethod" and ps.tokens[i + 1].tk ~= ":" then
            is_metamethod = true
            i = i + 1
         end

         local v
         if ps.tokens[i].tk == "[" then
            i, v = parse_literal(ps, i + 1)
            if v and not v.conststr then
               return fail(ps, i, "expected a string literal")
            end
            i = verify_tk(ps, i, "]")
         else
            i, v = verify_kind(ps, i, "identifier", "variable")
         end
         local iv = i
         if not v then
            return fail(ps, i, "expected a variable name")
         end

         if ps.tokens[i].tk == ":" then
            i = i + 1
            local t
            i, t = parse_type(ps, i)
            if not t then
               return fail(ps, i, "expected a type")
            end
            if t.typename == "function" and t.maybe_method then
               t.is_method = true
            end

            local field_name = v.conststr or v.tk
            if is_metamethod then
               if not def.meta_fields then
                  def.meta_fields = {}
                  def.meta_field_order = {}
               end
               if not metamethod_names[field_name] then
                  fail(ps, i - 1, "not a valid metamethod: " .. field_name)
               end
            end

            if ps.tokens[i].tk == "=" and ps.tokens[i + 1].tk == "macroexp" then
               local tt = t.typename == "generic" and t.t or t

               if tt.typename == "function" then
                  i, tt.macroexp = parse_macroexp(ps, i + 1, i + 2)
               else
                  fail(ps, i + 1, "macroexp must have a function type")
               end
            end

            store_field_in_record(ps, iv, field_name, t, def, comments, is_metamethod and "meta" or nil)
         elseif ps.tokens[i].tk == "=" then
            local next_word = ps.tokens[i + 1].tk
            if next_word == "record" or next_word == "enum" then
               return fail(ps, i, "syntax error: this syntax is no longer valid; use '" .. next_word .. " " .. v.tk .. "'")
            elseif next_word == "functiontype" then
               return fail(ps, i, "syntax error: this syntax is no longer valid; use 'type " .. v.tk .. " = function('...")
            else
               return fail(ps, i, "syntax error: this syntax is no longer valid; use 'type " .. v.tk .. " = '...")
            end
         else
            fail(ps, i, "syntax error: expected ':' for an attribute or '=' for a nested type")
         end
      end
   end
   return i, true
end

parse_type_body_fns = {
   ["interface"] = parse_record_body,
   ["record"] = parse_record_body,
   ["enum"] = parse_enum_body,
}

local function parse_newtype(ps, i)
   local node = new_node(ps, i, "newtype")
   local def
   local tn = ps.tokens[i].tk
   local istart = i

   if parse_type_body_fns[tn] then
      i, def = parse_type_body(ps, i + 1, istart, node, tn)
   else
      i, def = parse_type(ps, i)
   end
   if not def then
      return fail(ps, i, "expected a type")
   end

   node.newtype = new_typedecl(ps, istart, def)

   if def.typename == "nominal" then
      node.newtype.is_alias = true
   elseif def.typename == "generic" then
      local deft = def.t
      if deft.typename == "nominal" then
         node.newtype.is_alias = true
      end
   end

   return i, node
end

local function parse_assignment_expression_list(ps, i, asgn)
   asgn.exps = new_node(ps, i, "expression_list")
   repeat
      i = i + 1
      local val
      i, val = parse_expression(ps, i)
      if not val then
         if #asgn.exps == 0 then
            asgn.exps = nil
         end
         return i
      end
      table.insert(asgn.exps, val)
   until ps.tokens[i].tk ~= ","
   return i, asgn
end

local parse_call_or_assignment
do
   local function is_lvalue(node)
      node.is_lvalue = node.kind == "variable" or
      (node.kind == "op" and
      (node.op.op == "@index" or node.op.op == "."))
      return node.is_lvalue
   end

   local function parse_variable(ps, i)
      local node
      i, node = parse_expression(ps, i)
      if not (node and is_lvalue(node)) then
         return fail(ps, i, "expected a variable")
      end
      return i, node
   end

   parse_call_or_assignment = function(ps, i)
      local exp
      local istart = i
      i, exp = parse_expression(ps, i)
      if not exp then
         return i
      end

      if parser.node_is_funcall(exp) or exp.failstore then
         return i, exp
      end

      if not is_lvalue(exp) then
         return fail(ps, i, "syntax error")
      end

      local asgn = new_node(ps, istart, "assignment")
      asgn.vars = new_node(ps, istart, "variable_list")
      asgn.vars[1] = exp
      if ps.tokens[i].tk == "," then
         i = i + 1
         i = parse_trying_list(ps, i, asgn.vars, parse_variable)
         if #asgn.vars < 2 then
            return fail(ps, i, "syntax error")
         end
      end

      if ps.tokens[i].tk ~= "=" then
         verify_tk(ps, i, "=")
         return i
      end

      i, asgn = parse_assignment_expression_list(ps, i, asgn)
      return i, asgn
   end
end

local function parse_variable_declarations(ps, i, node_name)
   local asgn = new_node(ps, i, node_name)

   asgn.vars = new_node(ps, i, "variable_list")
   i = parse_trying_list(ps, i, asgn.vars, parse_variable_name)
   if #asgn.vars == 0 then
      return fail(ps, i, "expected a local variable definition")
   end

   i, asgn.decltuple = parse_type_list(ps, i, "decltuple")

   if ps.tokens[i].tk == "=" then

      local next_word = ps.tokens[i + 1].tk
      local tn = next_word
      if parse_type_body_fns[tn] then
         local scope = node_name == "local_declaration" and "local" or "global"
         return failskip(ps, i + 1, "syntax error: this syntax is no longer valid; use '" .. scope .. " " .. next_word .. " " .. asgn.vars[1].tk .. "'", skip_type_body)
      elseif next_word == "functiontype" then
         local scope = node_name == "local_declaration" and "local" or "global"
         return failskip(ps, i + 1, "syntax error: this syntax is no longer valid; use '" .. scope .. " type " .. asgn.vars[1].tk .. " = function('...", parse_function_type)
      end

      i, asgn = parse_assignment_expression_list(ps, i, asgn)
   end
   return i, asgn
end

local function parse_type_require(ps, i, asgn)
   local istart = i
   i, asgn.value = parse_expression(ps, i)
   if not asgn.value then
      return i
   end
   if asgn.value.op and asgn.value.op.op ~= "@funcall" and asgn.value.op.op ~= "." then
      fail(ps, istart, "require() in type declarations cannot be part of larger expressions")
      return i
   end
   if not parser.node_is_require_call(asgn.value) then
      fail(ps, istart, "require() for type declarations must have a literal argument")
      return i
   end
   return i, asgn
end

local function parse_special_type_declaration(ps, i, asgn)
   if ps.tokens[i].tk == "require" then
      return true, parse_type_require(ps, i, asgn)
   elseif ps.tokens[i].tk == "pcall" then
      fail(ps, i, "pcall() cannot be used in type declarations")
      return true, i
   end
   return false, i, asgn
end

parse_type_declaration = function(ps, i, node_name)
   local asgn = new_node(ps, i, node_name)
   local var

   i, var = verify_kind(ps, i, "identifier")
   if not var then
      return fail(ps, i, "expected a type name")
   end
   local typeargs
   local itypeargs = i
   i, typeargs = parse_typeargs_if_any(ps, i)

   asgn.var = var

   if node_name == "global_type" and ps.tokens[i].tk ~= "=" then
      return i, asgn
   end

   i = verify_tk(ps, i, "=")
   local istart = i

   if ps.tokens[i].kind == "identifier" then
      local is_done
      is_done, i, asgn = parse_special_type_declaration(ps, i, asgn)
      if is_done then
         return i, asgn
      end
   end

   i, asgn.value = parse_newtype(ps, i)
   if not asgn.value then
      return i
   end

   local nt = asgn.value.newtype
   if nt.typename == "typedecl" then
      if typeargs then
         local def = nt.def
         if def.typename == "generic" then
            fail(ps, itypeargs, "cannot declare type arguments twice in type declaration")
         else
            nt.def = new_generic(ps, istart, typeargs, def)
         end
      end

      set_declname(nt.def, asgn.var.tk)
   end

   return i, asgn
end

local function parse_type_constructor(ps, i, node_name, tn)
   local asgn = new_node(ps, i, node_name)
   local nt = new_node(ps, i, "newtype")
   asgn.value = nt
   local istart = i
   local def

   i = i + 2

   i, asgn.var = verify_kind(ps, i, "identifier")
   if not asgn.var then
      return fail(ps, i, "expected a type name")
   end

   i, def = parse_type_body(ps, i, istart, nt, tn)
   if not def then
      return i
   end

   set_declname(def, asgn.var.tk)

   nt.newtype = new_typedecl(ps, istart, def)

   return i, asgn
end

local function skip_type_declaration(ps, i)
   return parse_type_declaration(ps, i + 1, "local_type")
end

local function parse_local_macroexp(ps, i)
   local istart = i
   i = i + 2
   local node = new_node(ps, i, "local_macroexp")
   i, node.name = parse_identifier(ps, i)
   i, node.macrodef = parse_macroexp(ps, istart, i)
   end_at(node, ps.tokens[i - 1])
   return i, node
end

local function parse_local(ps, i)
   local comments = get_attached_comments(ps.tokens[i])
   local ntk = ps.tokens[i + 1].tk
   local tn = ntk

   local node
   if ntk == "function" then
      i, node = parse_local_function(ps, i)
   elseif ntk == "type" and ps.tokens[i + 2].kind == "identifier" then
      i, node = parse_type_declaration(ps, i + 2, "local_type")
   elseif ntk == "macroexp" and ps.tokens[i + 2].kind == "identifier" then
      i, node = parse_local_macroexp(ps, i)
   elseif parse_type_body_fns[tn] and ps.tokens[i + 2].kind == "identifier" then
      i, node = parse_type_constructor(ps, i, "local_type", tn)
   else
      i, node = parse_variable_declarations(ps, i + 1, "local_declaration")
   end
   if node then
      node.comments = comments
   end
   return i, node
end

local function parse_global(ps, i)
   local comments = get_attached_comments(ps.tokens[i])
   local ntk = ps.tokens[i + 1].tk
   local tn = ntk

   local node
   if ntk == "function" then
      i, node = parse_function(ps, i + 1, "global")
   elseif ntk == "type" and ps.tokens[i + 2].kind == "identifier" then
      i, node = parse_type_declaration(ps, i + 2, "global_type")
   elseif parse_type_body_fns[tn] and ps.tokens[i + 2].kind == "identifier" then
      i, node = parse_type_constructor(ps, i, "global_type", tn)
   elseif ps.tokens[i + 1].kind == "identifier" then
      i, node = parse_variable_declarations(ps, i + 1, "global_declaration")
   else
      return parse_call_or_assignment(ps, i)
   end
   if node then
      node.comments = comments
   end
   return i, node
end

local function parse_record_function(ps, i)
   local comments = get_attached_comments(ps.tokens[i])
   local node
   i, node = parse_function(ps, i, "record")
   if node then
      node.comments = comments
   end
   return i, node
end

local function parse_pragma(ps, i)
   i = i + 1
   local pragma = new_node(ps, i, "pragma")

   if ps.tokens[i].kind ~= "pragma_identifier" then
      return fail(ps, i, "expected pragma name")
   end
   pragma.pkey = ps.tokens[i].tk
   i = i + 1

   if ps.tokens[i].kind ~= "pragma_identifier" then
      return fail(ps, i, "expected pragma value")
   end
   pragma.pvalue = ps.tokens[i].tk
   i = i + 1

   return i, pragma
end

local parse_statement_fns = {
   ["--#pragma"] = parse_pragma,
   ["::"] = parse_label,
   ["do"] = parse_do,
   ["if"] = parse_if,
   ["for"] = parse_for,
   ["goto"] = parse_goto,
   ["local"] = parse_local,
   ["while"] = parse_while,
   ["break"] = parse_break,
   ["global"] = parse_global,
   ["repeat"] = parse_repeat,
   ["return"] = parse_return,
   ["function"] = parse_record_function,
}

local function type_needs_local_or_global(ps, i)
   local tk = ps.tokens[i].tk
   return failskip(ps, i, ("%s needs to be declared with 'local %s' or 'global %s'"):format(tk, tk, tk), skip_type_body)
end

local needs_local_or_global = {
   ["type"] = function(ps, i)
      return failskip(ps, i, "types need to be declared with 'local type' or 'global type'", skip_type_declaration)
   end,
   ["record"] = type_needs_local_or_global,
   ["enum"] = type_needs_local_or_global,
}

local function store_unattached_comments(node, token, item)
   for _, tc in ipairs(token.comments) do
      local is_attached = false
      if item.comments then
         for _, nc in ipairs(item.comments) do
            if tc == nc then
               is_attached = true
               break
            end
         end
      end
      if not is_attached then
         if not node.unattached_comments then
            node.unattached_comments = {}
         end
         table.insert(node.unattached_comments, tc)
      else
         break
      end
   end
end

parse_statements = function(ps, i, toplevel)
   local node = new_node(ps, i, "statements")
   local item
   while true do
      while ps.tokens[i].kind == ";" do
         i = i + 1
         if item then
            item.semicolon = true
         end
      end

      if ps.tokens[i].kind == "$EOF$" then
         break
      end
      local token = ps.tokens[i]
      local tk = token.tk
      if (not toplevel) and stop_statement_list[tk] then
         break
      end

      local fn = parse_statement_fns[tk]
      if not fn then
         local skip_fn = needs_local_or_global[tk]
         if skip_fn and ps.tokens[i + 1].kind == "identifier" then
            fn = skip_fn
         else
            fn = parse_call_or_assignment
         end
      end

      i, item = fn(ps, i)

      if item then
         if toplevel and token.comments then
            store_unattached_comments(node, token, item)
         end
         table.insert(node, item)
      elseif i > 1 then

         local lasty = ps.tokens[i - 1].y
         while ps.tokens[i].kind ~= "$EOF$" and ps.tokens[i].y == lasty do
            i = i + 1
         end
      end
   end

   end_at(node, ps.tokens[i])
   return i, node
end

function parser.parse_program(tokens, errs, filename, parse_lang)
   errs = errs or {}
   local ps = {
      tokens = tokens,
      errs = errs,
      filename = filename or "",
      required_modules = {},
      parse_lang = parse_lang,
   }
   local i = 1
   local hashbang
   if ps.tokens[i].kind == "hashbang" then
      hashbang = ps.tokens[i].tk
      i = i + 1
   end
   local _, node = parse_statements(ps, i, true)
   if hashbang then
      node.hashbang = hashbang
   end

   errors.clear_redundant_errors(errs)
   return node, ps.required_modules
end

local function lang_heuristic(filename, input)
   if filename then
      local pattern = "(.*)%.([a-z]+)$"
      local _, extension = filename:match(pattern)
      extension = extension and extension:lower()

      if extension == "tl" then
         return "tl"
      elseif extension == "lua" then
         return "lua"
      end
   end
   if input then
      return (input:match("^#![^\n]*lua[^\n]*\n")) and "lua" or "tl"
   end
   return "tl"
end

function parser.parse(input, filename)
   local parse_lang = lang_heuristic(filename, input)
   local tokens, errs = lexer.lex(input, filename)
   local node, required_modules = parser.parse_program(tokens, errs, filename, parse_lang)
   return node, errs, required_modules
end

function parser.node_at(w, n)
   n.f = assert(w.f)
   n.x = w.x
   n.y = w.y
   return n
end

return parser

end

-- module teal.precompiled.default_env from teal/precompiled/default_env.lua
package.preload["teal.precompiled.default_env"] = function(...)
local K1,K2,K3,K4,K5,K6,K7,K8,K9,K10="typename","typeid","./teal/default/stdlib.d.tl","tuple","typevar","min_arity","function","./teal/default/prelude.d.tl","maybe_method","typearg"
local K11,K12,K13,K14,K15,K16,K17,K18,K19,K20="string","integer","number","is_va","nominal","names","found","types","typeargs","generic"
local K21,K22,K23,K24,K25,K26,K27,K28,K29,K30="typedecl","union","fresh","boolean","declname","const","attribute","values","needs_compat","elements"
local K31,K32,K33,K34,K35,K36,K37,K38,K39,K40="array","fields","field_order","closed","thread","special_function_handler","record","enumset","resolved","AnyFunction"
local K41,K42,K43,K44,K45,K46,K47,K48,K49,K50="is_method","--[[special_function]]","typevals","metatable","close","unpack","OpenMode","HookFunction","GetInfoTable","FileStringMode"
local K={"interfaces_expanded","SeekWhence","SetVBufMode","flush","lines","write","FileNumberMode","FileMode","interface_list","__close","FileType","used_as_type","interface","Function","debug","HookEvent","getmetatable","setmetatable","ntransfer","field_comments","__newindex","userdata","LoadMode","Numeric","constraint","DateTable","DateMode","remove","format","gmatch","packsize","upper","--[[needs_compat]]","SortFunction","PackTable","tupletable"}
local T1 = {[K34]=true,f=K3,[K2]=1118,[K1]=K21,x=1,y=142,}
local T2 = {[K25]="FILE",f=K3,[K[1]]=true,["is_userdata"]=true,[K2]=967,[K1]=K37,x=1,y=142,}
local T3 = {f=K3,[K2]=978,[K1]=K21,x=4,y=146,}
local T4 = {f=K3,[K2]=980,[K1]=K21,x=4,y=150,}
local T5 = {f=K3,[K2]=556,[K1]=K21,x=1,y=18,}
local T6 = {f=K3,[K2]=554,[K1]=K21,x=1,y=14,}
local T7 = {f=K3,[K2]=558,[K1]=K21,x=1,y=22,}
local T8 = {[K34]=true,f=K3,[K2]=966,[K1]=K21,x=1,y=101,}
local T9 = {f=K3,[K2]=822,[K1]=K21,x=4,y=109,}
local T10 = {f=K3,[K2]=820,[K1]=K21,x=4,y=102,}
local T11 = {f=K3,kind="variable",tk="self",x=18,y=144,}
local T12 = {f=K3,[K2]=565,[K1]=K21,x=20,y=27,}
local T13 = {f=K3,[K2]=645,[K1]=K21,x=23,y=65,}
local T14 = {[K34]=true,f=K3,[K2]=631,[K1]=K21,x=4,y=40,}
local T15 = {f=K3,[K2]=633,[K1]=K21,x=4,y=59,}
local T16 = {f=K3,[K2]=639,[K1]=K21,x=24,y=63,}
local T17 = {f=K8,[K2]=230,[K1]=K21,x=1,y=18,}
local T18 = {f=K8,[K2]=15,[K1]=K21,x=4,y=19,}
local T19 = {[K34]=true,f=K8,[K2]=11,[K1]=K21,x=1,y=14,}
local T20 = {f=K3,[K2]=1892,[K1]=K21,x=24,y=362,}
local T21 = {f=K3,[K2]=1894,[K1]=K21,x=4,y=364,}
local T22 = {f=K3,[K2]=1123,[K1]=K21,x=19,y=178,}
local T23 = {f=K3,[K2]=1126,[K1]=K15,x=23,y=180,}
local T24 = {f=K3,[K2]=1364,[K1]=K21,x=4,y=247,}
local T25 = {[K34]=true,f=K3,[K2]=1362,[K1]=K21,x=4,y=235,}
local T26 = {f=K3,[K2]=1683,[K1]=K21,x=4,y=309,}
local T27 = {f=K3,[K2]=2376,[K1]=K5,[K5]="A",x=11,y=310,}
local T28 = {f=K3,[K2]=1676,[K1]=K21,x=24,y=307,}
local T0 = {["..."]={t={[K14]=true,[K4]={[1]={[K2]=2846,[K1]=K11,x=1,y=1,},},[K2]=2847,[K1]=K4,x=1,y=1,},},["@is_va"]={t={[K2]=2848,[K1]="any",x=1,y=1,},},FILE={t=T1,[K[12]]=true,},["_VERSION"]={[K27]=K26,t={f=K3,[K2]=2245,[K1]=K11,x=14,y=423,},},any={t={[K34]=true,def={[K25]="any",f=K8,[K33]={},[K32]={},[K2]=5,[K1]=K[13],x=1,y=8,},f=K8,[K2]=6,[K1]=K21,x=1,y=8,},},arg={[K27]=K26,t={[K30]={f=K3,[K2]=1901,[K1]=K11,x=10,y=370,},f=K3,[K2]=1902,[K1]=K31,x=9,xend=16,y=370,yend=370,},},["assert"]={[K27]=K26,[K29]=true,t={f=K3,[K23]=true,t={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2573,[K1]=K5,[K5]="A@43",x=27,y=371,},[2]={f=K3,[K2]=2574,[K1]=K5,[K5]="B@43",x=32,y=371,},[3]={f=K3,[K2]=1908,[K1]="any",x=40,y=371,},},[K2]=2575,[K1]=K4,x=44,y=371,},f=K3,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=2576,[K1]=K5,[K5]="A@43",x=46,y=371,},},[K2]=2577,[K1]=K4,x=44,y=371,},[K36]="assert",[K2]=2578,[K1]=K7,x=12,y=371,},[K19]={[1]={f=K3,[K10]="A@43",[K2]=2571,[K1]=K10,x=21,y=371,},[2]={f=K3,[K10]="B@43",[K2]=2572,[K1]=K10,x=24,y=371,},},[K2]=2579,[K1]=K20,x=4,y=373,},},["collectgarbage"]={[K27]=K26,t={f=K3,[K2]=1924,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={[1]={f=K3,[K17]={def={[K25]="CollectGarbageCommand",[K38]={["collect"]=true,["count"]=true,["restart"]=true,stop=true,},f=K3,[K2]=1882,[K1]="enum",x=4,y=345,},f=K3,[K2]=1883,[K1]=K21,x=4,y=345,},[K16]={[1]="CollectGarbageCommand",},[K2]=1914,[K1]=K15,x=31,y=373,},},[K2]=1915,[K1]=K4,x=53,y=373,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1917,[K1]=K13,x=55,y=373,},},[K2]=1916,[K1]=K4,x=53,y=373,},[K2]=1913,[K1]=K7,x=20,y=373,},[2]={args={f=K3,[K4]={[1]={f=K3,[K17]={def={[K25]="CollectGarbageSetValue",[K38]={["setpause"]=true,["setstepmul"]=true,step=true,},f=K3,[K2]=1884,[K1]="enum",x=4,y=352,},f=K3,[K2]=1885,[K1]=K21,x=4,y=352,},[K16]={[1]="CollectGarbageSetValue",},[K2]=1919,[K1]=K15,x=29,y=374,},[2]={f=K3,[K2]=1920,[K1]=K12,x=53,y=374,},},[K2]=1921,[K1]=K4,x=61,y=374,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=1923,[K1]=K13,x=63,y=374,},},[K2]=1922,[K1]=K4,x=61,y=374,},[K2]=1918,[K1]=K7,x=20,y=374,},[3]={args={f=K3,[K4]={[1]={f=K3,[K17]={def={[K25]="CollectGarbageIsRunning",[K38]={["isrunning"]=true,},f=K3,[K2]=1886,[K1]="enum",x=4,y=358,},f=K3,[K2]=1887,[K1]=K21,x=4,y=358,},[K16]={[1]="CollectGarbageIsRunning",},[K2]=1926,[K1]=K15,x=29,y=375,},},[K2]=1927,[K1]=K4,x=53,y=375,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1929,[K1]=K24,x=55,y=375,},},[K2]=1928,[K1]=K4,x=53,y=375,},[K2]=1925,[K1]=K7,x=20,y=375,},[4]={args={f=K3,[K4]={[1]={f=K3,[K2]=1931,[K1]=K11,x=29,y=376,},[2]={f=K3,[K2]=1932,[K1]=K13,x=39,y=376,},},[K2]=1933,[K1]=K4,x=46,y=376,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1936,[K1]=K22,[K18]={[1]={f=K3,[K2]=1935,[K1]=K24,x=49,y=376,},[2]={f=K3,[K2]=1937,[K1]=K13,x=59,y=376,},},x=49,y=376,},},[K2]=1934,[K1]=K4,x=46,y=376,},[K2]=1930,[K1]=K7,x=20,y=376,},},x=18,y=374,},},["coroutine"]={[K29]=true,t={[K34]=true,def={[K25]="coroutine",f=K3,[K33]={[1]=K[14],[2]=K45,[3]="create",[4]="isyieldable",[5]="resume",[6]="running",[7]="status",[8]="wrap",[9]="yield",},[K32]={[K[14]]=T12,[K45]={args={f=K3,[K4]={[1]={f=K3,[K2]=567,[K1]=K35,x=20,y=29,},},[K2]=568,[K1]=K4,x=27,y=29,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=570,[K1]=K24,x=29,y=29,},[2]={f=K3,[K2]=571,[K1]=K11,x=38,y=29,},},[K2]=569,[K1]=K4,x=27,y=29,},[K2]=566,[K1]=K7,x=11,y=29,},["create"]={args={f=K3,[K4]={[1]={f=K3,[K17]=T12,[K16]={[1]=K[14],},[K2]=573,[K1]=K15,x=21,y=30,},},[K2]=574,[K1]=K4,x=30,y=30,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=576,[K1]=K35,x=32,y=30,},},[K2]=575,[K1]=K4,x=30,y=30,},[K2]=572,[K1]=K7,x=12,y=30,},["isyieldable"]={args={f=K3,[K4]={},[K2]=578,[K1]=K4,x=27,y=31,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=580,[K1]=K24,x=29,y=31,},},[K2]=579,[K1]=K4,x=27,y=31,},[K2]=577,[K1]=K7,x=17,y=31,},["resume"]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=582,[K1]=K35,x=21,y=32,},[2]={f=K3,[K2]=583,[K1]="any",x=29,y=32,},},[K2]=584,[K1]=K4,x=36,y=32,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=586,[K1]=K24,x=38,y=32,},[2]={f=K3,[K2]=587,[K1]="any",x=47,y=32,},},[K2]=585,[K1]=K4,x=36,y=32,},[K2]=581,[K1]=K7,x=12,y=32,},["running"]={args={f=K3,[K4]={},[K2]=589,[K1]=K4,x=23,y=33,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=591,[K1]=K35,x=25,y=33,},[2]={f=K3,[K2]=592,[K1]=K24,x=33,y=33,},},[K2]=590,[K1]=K4,x=23,y=33,},[K2]=588,[K1]=K7,x=13,y=33,},["status"]={args={f=K3,[K4]={[1]={f=K3,[K2]=594,[K1]=K35,x=21,y=34,},},[K2]=595,[K1]=K4,x=28,y=34,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=597,[K1]=K11,x=30,y=34,},},[K2]=596,[K1]=K4,x=28,y=34,},[K2]=593,[K1]=K7,x=12,y=34,},wrap={f=K3,[K23]=true,t={args={f=K3,[K4]={[1]={f=K3,[K2]=2277,[K1]=K5,[K5]="F@23",x=22,y=35,},},[K2]=2278,[K1]=K4,x=24,y=35,},f=K3,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=2279,[K1]=K5,[K5]="F@23",x=26,y=35,},},[K2]=2280,[K1]=K4,x=24,y=35,},[K2]=2281,[K1]=K7,x=10,y=35,},[K19]={[1]={f=K3,[K10]="F@23",[K2]=2276,[K1]=K10,x=19,y=35,},},[K2]=2282,[K1]=K20,x=4,y=36,},["yield"]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=606,[K1]="any",x=20,y=36,},},[K2]=607,[K1]=K4,x=27,y=36,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=609,[K1]="any",x=29,y=36,},},[K2]=608,[K1]=K4,x=27,y=36,},[K2]=605,[K1]=K7,x=11,y=36,},},[K2]=559,[K1]=K37,x=1,y=26,},f=K3,[K2]=610,[K1]=K21,x=1,y=26,},},[K[15]]={[K29]=true,t={[K34]=true,def={[K25]=K[15],f=K3,[K33]={[1]=K49,[2]=K[16],[3]=K48,[4]=K40,[5]=K[15],[6]="gethook",[7]="getinfo",[8]="getlocal",[9]=K[17],[10]="getregistry",[11]="getupvalue",[12]="getuservalue",[13]="sethook",[14]="setlocal",[15]=K[18],[16]="setupvalue",[17]="setuservalue",[18]="traceback",[19]="upvalueid",[20]="upvaluejoin",},[K32]={[K40]=T13,[K49]=T14,[K[16]]=T15,[K48]=T16,[K[15]]={args={f=K3,[K4]={},[K2]=647,[K1]=K4,x=4,y=68,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={},[K2]=648,[K1]=K4,x=20,y=67,},[K2]=646,[K1]=K7,x=11,y=67,},["gethook"]={args={f=K3,[K4]={[1]={f=K3,[K2]=650,[K1]=K35,x=24,y=68,},},[K2]=651,[K1]=K4,x=31,y=68,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K17]=T16,[K16]={[1]=K48,},[K2]=653,[K1]=K15,x=33,y=68,},[2]={f=K3,[K2]=654,[K1]=K12,x=47,y=68,},},[K2]=652,[K1]=K4,x=31,y=68,},[K2]=649,[K1]=K7,x=13,y=68,},["getinfo"]={f=K3,[K2]=672,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={[1]={f=K3,[K2]=656,[K1]=K35,x=22,y=70,},[2]={f=K3,[K2]=658,[K1]=K22,[K18]={[1]={f=K3,[K17]=T13,[K16]={[1]=K40,},[K2]=657,[K1]=K15,x=30,y=70,},[2]={f=K3,[K2]=659,[K1]=K12,x=44,y=70,},},x=30,y=70,},[3]={f=K3,[K2]=660,[K1]=K11,x=55,y=70,},},[K2]=661,[K1]=K4,x=62,y=70,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K17]=T14,[K16]={[1]=K49,},[K2]=663,[K1]=K15,x=64,y=70,},},[K2]=662,[K1]=K4,x=62,y=70,},[K2]=655,[K1]=K7,x=13,y=70,},[2]={args={f=K3,[K4]={[1]={f=K3,[K2]=666,[K1]=K22,[K18]={[1]={f=K3,[K17]=T13,[K16]={[1]=K40,},[K2]=665,[K1]=K15,x=30,y=71,},[2]={f=K3,[K2]=667,[K1]=K12,x=44,y=71,},},x=30,y=71,},[2]={f=K3,[K2]=668,[K1]=K11,x=55,y=71,},},[K2]=669,[K1]=K4,x=62,y=71,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K17]=T14,[K16]={[1]=K49,},[K2]=671,[K1]=K15,x=64,y=71,},},[K2]=670,[K1]=K4,x=62,y=71,},[K2]=664,[K1]=K7,x=13,y=71,},},x=11,y=71,},["getlocal"]={f=K3,[K2]=688,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={[1]={f=K3,[K2]=674,[K1]=K35,x=23,y=73,},[2]={f=K3,[K17]=T13,[K16]={[1]=K40,},[K2]=675,[K1]=K15,x=31,y=73,},[3]={f=K3,[K2]=676,[K1]=K12,x=44,y=73,},},[K2]=677,[K1]=K4,x=52,y=73,},f=K3,[K9]=false,[K6]=3,rets={f=K3,[K4]={[1]={f=K3,[K2]=679,[K1]=K11,x=54,y=73,},},[K2]=678,[K1]=K4,x=52,y=73,},[K2]=673,[K1]=K7,x=14,y=73,},[2]={args={f=K3,[K4]={[1]={f=K3,[K2]=681,[K1]=K35,x=23,y=74,},[2]={f=K3,[K2]=682,[K1]=K12,x=31,y=74,},[3]={f=K3,[K2]=683,[K1]=K12,x=40,y=74,},},[K2]=684,[K1]=K4,x=48,y=74,},f=K3,[K9]=false,[K6]=3,rets={f=K3,[K4]={[1]={f=K3,[K2]=686,[K1]=K11,x=50,y=74,},[2]={f=K3,[K2]=687,[K1]="any",x=58,y=74,},},[K2]=685,[K1]=K4,x=48,y=74,},[K2]=680,[K1]=K7,x=14,y=74,},[3]={args={f=K3,[K4]={[1]={f=K3,[K17]=T13,[K16]={[1]=K40,},[K2]=690,[K1]=K15,x=23,y=75,},[2]={f=K3,[K2]=691,[K1]=K12,x=36,y=75,},},[K2]=692,[K1]=K4,x=44,y=75,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=694,[K1]=K11,x=46,y=75,},},[K2]=693,[K1]=K4,x=44,y=75,},[K2]=689,[K1]=K7,x=14,y=75,},[4]={args={f=K3,[K4]={[1]={f=K3,[K2]=696,[K1]=K12,x=23,y=76,},[2]={f=K3,[K2]=697,[K1]=K12,x=32,y=76,},},[K2]=698,[K1]=K4,x=40,y=76,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=700,[K1]=K11,x=42,y=76,},[2]={f=K3,[K2]=701,[K1]="any",x=50,y=76,},},[K2]=699,[K1]=K4,x=40,y=76,},[K2]=695,[K1]=K7,x=14,y=76,},},x=12,y=74,},[K[17]]={f=K3,[K23]=true,t={args={f=K3,[K4]={[1]={f=K3,[K2]=2289,[K1]=K5,[K5]="T@24",x=30,y=78,},},[K2]=2290,[K1]=K4,x=32,y=78,},f=K3,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K17]=T17,[K16]={[1]=K44,},[K2]=2292,[K1]=K15,[K43]={[1]={f=K3,[K2]=2291,[K1]=K5,[K5]="T@24",x=44,y=78,},},x=34,y=78,},},[K2]=2293,[K1]=K4,x=32,y=78,},[K2]=2294,[K1]=K7,x=18,y=78,},[K19]={[1]={f=K3,[K10]="T@24",[K2]=2288,[K1]=K10,x=27,y=78,},},[K2]=2295,[K1]=K20,x=4,y=79,},["getregistry"]={args={f=K3,[K4]={},[K2]=711,[K1]=K4,x=27,y=79,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,keys={f=K3,[K2]=713,[K1]="any",x=30,y=79,},[K2]=714,[K1]="map",[K28]={f=K3,[K2]=715,[K1]="any",x=34,y=79,},x=29,xend=37,y=79,yend=79,},},[K2]=712,[K1]=K4,x=27,y=79,},[K2]=710,[K1]=K7,x=17,y=79,},["getupvalue"]={args={f=K3,[K4]={[1]={f=K3,[K17]=T13,[K16]={[1]=K40,},[K2]=717,[K1]=K15,x=25,y=80,},[2]={f=K3,[K2]=718,[K1]=K12,x=38,y=80,},},[K2]=719,[K1]=K4,x=46,y=80,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=721,[K1]=K11,x=48,y=80,},[2]={f=K3,[K2]=722,[K1]="any",x=56,y=80,},},[K2]=720,[K1]=K4,x=46,y=80,},[K2]=716,[K1]=K7,x=16,y=80,},["getuservalue"]={args={f=K3,[K4]={[1]={f=K3,[K17]=T19,[K16]={[1]=K[22],},[K2]=724,[K1]=K15,x=27,y=81,},[2]={f=K3,[K2]=725,[K1]=K12,x=39,y=81,},},[K2]=726,[K1]=K4,x=47,y=81,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=728,[K1]="any",x=49,y=81,},[2]={f=K3,[K2]=729,[K1]=K24,x=54,y=81,},},[K2]=727,[K1]=K4,x=47,y=81,},[K2]=723,[K1]=K7,x=18,y=81,},["sethook"]={f=K3,[K2]=743,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={[1]={f=K3,[K2]=731,[K1]=K35,x=22,y=83,},[2]={f=K3,[K17]=T16,[K16]={[1]=K48,},[K2]=732,[K1]=K15,x=30,y=83,},[3]={f=K3,[K2]=733,[K1]=K11,x=44,y=83,},[4]={f=K3,[K2]=734,[K1]=K12,x=54,y=83,},},[K2]=735,[K1]=K4,x=4,y=84,},f=K3,[K9]=false,[K6]=3,rets={f=K3,[K4]={},[K2]=736,[K1]=K4,x=61,y=83,},[K2]=730,[K1]=K7,x=13,y=83,},[2]={args={f=K3,[K4]={[1]={f=K3,[K17]=T16,[K16]={[1]=K48,},[K2]=738,[K1]=K15,x=22,y=84,},[2]={f=K3,[K2]=739,[K1]=K11,x=36,y=84,},[3]={f=K3,[K2]=740,[K1]=K12,x=46,y=84,},},[K2]=741,[K1]=K4,x=4,y=86,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={},[K2]=742,[K1]=K4,x=53,y=84,},[K2]=737,[K1]=K7,x=13,y=84,},},x=11,y=84,},["setlocal"]={f=K3,[K2]=759,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={[1]={f=K3,[K2]=745,[K1]=K35,x=23,y=86,},[2]={f=K3,[K2]=746,[K1]=K12,x=31,y=86,},[3]={f=K3,[K2]=747,[K1]=K12,x=40,y=86,},[4]={f=K3,[K2]=748,[K1]="any",x=49,y=86,},},[K2]=749,[K1]=K4,x=53,y=86,},f=K3,[K9]=false,[K6]=4,rets={f=K3,[K4]={[1]={f=K3,[K2]=751,[K1]=K11,x=55,y=86,},},[K2]=750,[K1]=K4,x=53,y=86,},[K2]=744,[K1]=K7,x=14,y=86,},[2]={args={f=K3,[K4]={[1]={f=K3,[K2]=753,[K1]=K12,x=23,y=87,},[2]={f=K3,[K2]=754,[K1]=K12,x=32,y=87,},[3]={f=K3,[K2]=755,[K1]="any",x=41,y=87,},},[K2]=756,[K1]=K4,x=45,y=87,},f=K3,[K9]=false,[K6]=3,rets={f=K3,[K4]={[1]={f=K3,[K2]=758,[K1]=K11,x=47,y=87,},},[K2]=757,[K1]=K4,x=45,y=87,},[K2]=752,[K1]=K7,x=14,y=87,},},x=12,y=87,},[K[18]]={f=K3,[K23]=true,t={args={f=K3,[K4]={[1]={f=K3,[K2]=2301,[K1]=K5,[K5]="T@25",x=30,y=89,},[2]={f=K3,[K17]=T17,[K16]={[1]=K44,},[K2]=2303,[K1]=K15,[K43]={[1]={f=K3,[K2]=2302,[K1]=K5,[K5]="T@25",x=43,y=89,},},x=33,y=89,},},[K2]=2304,[K1]=K4,x=46,y=89,},f=K3,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=2305,[K1]=K5,[K5]="T@25",x=48,y=89,},},[K2]=2306,[K1]=K4,x=46,y=89,},[K2]=2307,[K1]=K7,x=18,y=89,},[K19]={[1]={f=K3,[K10]="T@25",[K2]=2300,[K1]=K10,x=27,y=89,},},[K2]=2308,[K1]=K20,x=4,y=90,},["setupvalue"]={args={f=K3,[K4]={[1]={f=K3,[K17]=T13,[K16]={[1]=K40,},[K2]=770,[K1]=K15,x=25,y=90,},[2]={f=K3,[K2]=771,[K1]=K12,x=38,y=90,},[3]={f=K3,[K2]=772,[K1]="any",x=47,y=90,},},[K2]=773,[K1]=K4,x=51,y=90,},f=K3,[K9]=false,[K6]=3,rets={f=K3,[K4]={[1]={f=K3,[K2]=775,[K1]=K11,x=53,y=90,},},[K2]=774,[K1]=K4,x=51,y=90,},[K2]=769,[K1]=K7,x=16,y=90,},["setuservalue"]={f=K3,[K23]=true,t={args={f=K3,[K4]={[1]={f=K3,[K2]=2313,[K1]=K5,[K5]="U@26",x=30,y=91,},[2]={f=K3,[K2]=779,[K1]="any",x=33,y=91,},[3]={f=K3,[K2]=780,[K1]=K12,x=38,y=91,},},[K2]=2314,[K1]=K4,x=46,y=91,},f=K3,[K6]=3,rets={f=K3,[K4]={[1]={f=K3,[K2]=2315,[K1]=K5,[K5]="U@26",x=48,y=91,},},[K2]=2316,[K1]=K4,x=46,y=91,},[K2]=2317,[K1]=K7,x=18,y=91,},[K19]={[1]={f=K3,[K10]="U@26",[K2]=2312,[K1]=K10,x=27,y=91,},},[K2]=2318,[K1]=K20,x=4,y=93,},["traceback"]={f=K3,[K2]=798,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={[1]={f=K3,[K2]=786,[K1]=K35,x=24,y=93,},[2]={f=K3,[K2]=787,[K1]=K11,x=34,y=93,},[3]={f=K3,[K2]=788,[K1]=K12,x=44,y=93,},},[K2]=789,[K1]=K4,x=52,y=93,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=791,[K1]=K11,x=54,y=93,},},[K2]=790,[K1]=K4,x=52,y=93,},[K2]=785,[K1]=K7,x=15,y=93,},[2]={args={f=K3,[K4]={[1]={f=K3,[K2]=793,[K1]=K11,x=26,y=94,},[2]={f=K3,[K2]=794,[K1]=K12,x=36,y=94,},},[K2]=795,[K1]=K4,x=44,y=94,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=797,[K1]=K11,x=46,y=94,},},[K2]=796,[K1]=K4,x=44,y=94,},[K2]=792,[K1]=K7,x=15,y=94,},[3]={args={f=K3,[K4]={[1]={f=K3,[K2]=800,[K1]="any",x=24,y=95,},},[K2]=801,[K1]=K4,x=28,y=95,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=803,[K1]="any",x=30,y=95,},},[K2]=802,[K1]=K4,x=28,y=95,},[K2]=799,[K1]=K7,x=15,y=95,},},x=13,y=94,},["upvalueid"]={args={f=K3,[K4]={[1]={f=K3,[K17]=T13,[K16]={[1]=K40,},[K2]=805,[K1]=K15,x=24,y=97,},[2]={f=K3,[K2]=806,[K1]=K12,x=37,y=97,},},[K2]=807,[K1]=K4,x=45,y=97,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K17]=T19,[K16]={[1]=K[22],},[K2]=809,[K1]=K15,x=47,y=97,},},[K2]=808,[K1]=K4,x=45,y=97,},[K2]=804,[K1]=K7,x=15,y=97,},["upvaluejoin"]={args={f=K3,[K4]={[1]={f=K3,[K17]=T13,[K16]={[1]=K40,},[K2]=811,[K1]=K15,x=26,y=98,},[2]={f=K3,[K2]=812,[K1]=K12,x=39,y=98,},[3]={f=K3,[K17]=T13,[K16]={[1]=K40,},[K2]=813,[K1]=K15,x=48,y=98,},[4]={f=K3,[K2]=814,[K1]=K12,x=61,y=98,},},[K2]=815,[K1]=K4,x=1,y=99,},f=K3,[K9]=false,[K6]=4,rets={f=K3,[K4]={},[K2]=816,[K1]=K4,x=68,y=98,},[K2]=810,[K1]=K7,x=17,y=98,},},[K2]=611,[K1]=K37,x=1,y=39,},f=K3,[K2]=817,[K1]=K21,x=1,y=39,},},["dofile"]={[K27]=K26,t={args={f=K3,[K4]={[1]={f=K3,[K2]=1939,[K1]=K11,x=23,y=378,},},[K2]=1940,[K1]=K4,x=30,y=378,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1942,[K1]="any",x=32,y=378,},},[K2]=1941,[K1]=K4,x=30,y=378,},[K2]=1938,[K1]=K7,x=12,y=378,},},["error"]={[K27]=K26,t={args={f=K3,[K4]={[1]={f=K3,[K2]=1944,[K1]="any",x=22,y=380,},[2]={f=K3,[K2]=1945,[K1]=K12,x=29,y=380,},},[K2]=1946,[K1]=K4,x=4,y=381,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={},[K2]=1947,[K1]=K4,x=36,y=380,},[K2]=1943,[K1]=K7,x=11,y=380,},},[K[17]]={[K27]=K26,t={f=K3,[K23]=true,t={args={f=K3,[K4]={[1]={f=K3,[K2]=2584,[K1]=K5,[K5]="T@44",x=30,y=381,},},[K2]=2585,[K1]=K4,x=32,y=381,},f=K3,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K17]=T17,[K16]={[1]=K44,},[K2]=2587,[K1]=K15,[K43]={[1]={f=K3,[K2]=2586,[K1]=K5,[K5]="T@44",x=44,y=381,},},x=34,y=381,},},[K2]=2588,[K1]=K4,x=32,y=381,},[K2]=2589,[K1]=K7,x=18,y=381,},[K19]={[1]={f=K3,[K10]="T@44",[K2]=2583,[K1]=K10,x=27,y=381,},},[K2]=2590,[K1]=K20,x=4,y=382,},},io={["has_been_read_from"]=true,[K29]=true,t=T8,},["ipairs"]={[K27]=K26,[K29]=true,t={f=K3,[K23]=true,t={args={f=K3,[K4]={[1]={[K30]={f=K3,[K2]=2597,[K1]=K5,[K5]="A@45",x=25,y=382,},f=K3,[K2]=2598,[K1]=K31,x=24,y=382,},},[K2]=2599,[K1]=K4,x=28,y=382,},f=K3,[K6]=1,rets={f=K3,[K4]={[1]={args={f=K3,[K4]={[1]={[K30]={f=K3,[K2]=2600,[K1]=K5,[K5]="A@45",x=41,y=382,},f=K3,[K2]=2601,[K1]=K31,x=40,y=382,},[2]={f=K3,[K2]=1965,[K1]=K12,x=45,y=382,},},[K2]=2602,[K1]=K4,x=53,y=382,},f=K3,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=1968,[K1]=K12,x=56,y=382,},[2]={f=K3,[K2]=2603,[K1]=K5,[K5]="A@45",x=65,y=382,},},[K2]=2604,[K1]=K4,x=53,y=382,},[K2]=2605,[K1]=K7,x=31,y=382,},[2]={[K30]={f=K3,[K2]=2606,[K1]=K5,[K5]="A@45",x=70,y=382,},f=K3,[K2]=2607,[K1]=K31,x=69,y=382,},[3]={f=K3,[K2]=1972,[K1]=K12,x=74,y=382,},},[K2]=2608,[K1]=K4,x=28,y=382,},[K36]="ipairs",[K2]=2609,[K1]=K7,x=12,y=382,},[K19]={[1]={f=K3,[K10]="A@45",[K2]=2596,[K1]=K10,x=21,y=382,},},[K2]=2610,[K1]=K20,x=4,y=384,},},load={[K27]=K26,[K29]=true,t={f=K3,[K2]=2008,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={[1]={f=K3,[K2]=1976,[K1]=K22,[K18]={[1]={f=K3,[K2]=1975,[K1]=K11,x=20,y=384,},[2]={f=K3,[K17]=T20,[K16]={[1]="LoadFunction",},[K2]=1977,[K1]=K15,x=29,y=384,},},x=20,y=384,},[2]={f=K3,[K2]=1978,[K1]=K11,x=46,y=384,},[3]={f=K3,[K17]=T21,[K16]={[1]=K[23],},[K2]=1979,[K1]=K15,x=56,y=384,},[4]={f=K3,keys={f=K3,[K2]=1980,[K1]="any",x=69,y=384,},[K2]=1981,[K1]="map",[K28]={f=K3,[K2]=1982,[K1]="any",x=73,y=384,},x=68,xend=76,y=384,yend=384,},},[K2]=1983,[K1]=K4,x=78,y=384,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1986,[K1]="any",x=89,y=384,},},[K2]=1987,[K1]=K4,x=89,y=384,},f=K3,[K41]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1988,[K1]="any",x=89,y=384,},},[K2]=1989,[K1]=K4,x=89,y=384,},[K2]=1985,[K1]=K7,x=81,y=384,},[2]={f=K3,[K2]=1990,[K1]=K11,x=91,y=384,},},[K2]=1984,[K1]=K4,x=78,y=384,},[K2]=1974,[K1]=K7,x=10,y=384,},[2]={args={f=K3,[K4]={[1]={f=K3,[K2]=1993,[K1]=K22,[K18]={[1]={f=K3,[K2]=1992,[K1]=K11,x=20,y=385,},[2]={f=K3,[K17]=T20,[K16]={[1]="LoadFunction",},[K2]=1994,[K1]=K15,x=29,y=385,},},x=20,y=385,},[2]={f=K3,[K2]=1995,[K1]=K11,x=46,y=385,},[3]={f=K3,[K2]=1996,[K1]=K11,x=56,y=385,},[4]={f=K3,keys={f=K3,[K2]=1997,[K1]="any",x=69,y=385,},[K2]=1998,[K1]="map",[K28]={f=K3,[K2]=1999,[K1]="any",x=73,y=385,},x=68,xend=76,y=385,yend=385,},},[K2]=2000,[K1]=K4,x=78,y=385,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2003,[K1]="any",x=89,y=385,},},[K2]=2004,[K1]=K4,x=89,y=385,},f=K3,[K41]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2005,[K1]="any",x=89,y=385,},},[K2]=2006,[K1]=K4,x=89,y=385,},[K2]=2002,[K1]=K7,x=81,y=385,},[2]={f=K3,[K2]=2007,[K1]=K11,x=91,y=385,},},[K2]=2001,[K1]=K4,x=78,y=385,},[K2]=1991,[K1]=K7,x=10,y=385,},},x=8,y=385,},},["loadfile"]={[K27]=K26,[K29]=true,t={f=K3,[K2]=2037,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={[1]={f=K3,[K2]=2010,[K1]=K11,x=25,y=387,},[2]={f=K3,[K17]=T21,[K16]={[1]=K[23],},[K2]=2011,[K1]=K15,x=35,y=387,},[3]={f=K3,keys={f=K3,[K2]=2012,[K1]="any",x=48,y=387,},[K2]=2013,[K1]="map",[K28]={f=K3,[K2]=2014,[K1]="any",x=52,y=387,},x=47,xend=55,y=387,yend=387,},},[K2]=2015,[K1]=K4,x=57,y=387,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2018,[K1]="any",x=68,y=387,},},[K2]=2019,[K1]=K4,x=68,y=387,},f=K3,[K41]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2020,[K1]="any",x=68,y=387,},},[K2]=2021,[K1]=K4,x=68,y=387,},[K2]=2017,[K1]=K7,x=60,y=387,},[2]={f=K3,[K2]=2022,[K1]=K11,x=70,y=387,},},[K2]=2016,[K1]=K4,x=57,y=387,},[K2]=2009,[K1]=K7,x=14,y=387,},[2]={args={f=K3,[K4]={[1]={f=K3,[K2]=2024,[K1]=K11,x=25,y=388,},[2]={f=K3,[K2]=2025,[K1]=K11,x=35,y=388,},[3]={f=K3,keys={f=K3,[K2]=2026,[K1]="any",x=48,y=388,},[K2]=2027,[K1]="map",[K28]={f=K3,[K2]=2028,[K1]="any",x=52,y=388,},x=47,xend=55,y=388,yend=388,},},[K2]=2029,[K1]=K4,x=57,y=388,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2032,[K1]="any",x=68,y=388,},},[K2]=2033,[K1]=K4,x=68,y=388,},f=K3,[K41]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2034,[K1]="any",x=68,y=388,},},[K2]=2035,[K1]=K4,x=68,y=388,},[K2]=2031,[K1]=K7,x=60,y=388,},[2]={f=K3,[K2]=2036,[K1]=K11,x=70,y=388,},},[K2]=2030,[K1]=K4,x=57,y=388,},[K2]=2023,[K1]=K7,x=14,y=388,},},x=12,y=388,},},math={[K29]=true,t={[K34]=true,def={[K25]="math",f=K3,[K33]={[1]=K[24],[2]="abs",[3]="acos",[4]="asin",[5]="atan",[6]="atan2",[7]="ceil",[8]="cos",[9]="cosh",[10]="deg",[11]="exp",[12]="floor",[13]="fmod",[14]="frexp",[15]="huge",[16]="ldexp",[17]="log",[18]="log10",[19]="max",[20]="maxinteger",[21]="min",[22]="mininteger",[23]="modf",[24]="pi",[25]="pow",[26]="rad",[27]="random",[28]="randomseed",[29]="sin",[30]="sinh",[31]="sqrt",[32]="tan",[33]="tanh",[34]="tointeger",[35]="type",[36]="ult",},[K32]={[K[24]]=T22,abs={f=K3,[K23]=true,t={args={f=K3,[K4]={[1]={[K[25]]=T23,f=K3,[K2]=2334,[K1]=K5,[K5]="N@27",x=32,y=180,},},[K2]=2335,[K1]=K4,x=34,y=180,},f=K3,[K6]=1,rets={f=K3,[K4]={[1]={[K[25]]=T23,f=K3,[K2]=2336,[K1]=K5,[K5]="N@27",x=36,y=180,},},[K2]=2337,[K1]=K4,x=34,y=180,},[K2]=2338,[K1]=K7,x=9,y=180,},[K19]={[1]={[K[25]]=T23,f=K3,[K10]="N@27",[K2]=2333,[K1]=K10,x=18,y=180,},},[K2]=2339,[K1]=K20,x=4,y=181,},acos={args={f=K3,[K4]={[1]={f=K3,[K2]=1133,[K1]=K13,x=19,y=181,},},[K2]=1134,[K1]=K4,x=26,y=181,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1136,[K1]=K13,x=28,y=181,},},[K2]=1135,[K1]=K4,x=26,y=181,},[K2]=1132,[K1]=K7,x=10,y=181,},asin={args={f=K3,[K4]={[1]={f=K3,[K2]=1138,[K1]=K13,x=19,y=182,},},[K2]=1139,[K1]=K4,x=26,y=182,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1141,[K1]=K13,x=28,y=182,},},[K2]=1140,[K1]=K4,x=26,y=182,},[K2]=1137,[K1]=K7,x=10,y=182,},atan={args={f=K3,[K4]={[1]={f=K3,[K2]=1143,[K1]=K13,x=19,y=183,},[2]={f=K3,[K2]=1144,[K1]=K13,x=29,y=183,},},[K2]=1145,[K1]=K4,x=36,y=183,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1147,[K1]=K13,x=38,y=183,},},[K2]=1146,[K1]=K4,x=36,y=183,},[K2]=1142,[K1]=K7,x=10,y=183,},["atan2"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1149,[K1]=K13,x=20,y=184,},[2]={f=K3,[K2]=1150,[K1]=K13,x=28,y=184,},},[K2]=1151,[K1]=K4,x=35,y=184,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=1153,[K1]=K13,x=37,y=184,},},[K2]=1152,[K1]=K4,x=35,y=184,},[K2]=1148,[K1]=K7,x=11,y=184,},ceil={args={f=K3,[K4]={[1]={f=K3,[K2]=1155,[K1]=K13,x=19,y=185,},},[K2]=1156,[K1]=K4,x=26,y=185,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1158,[K1]=K12,x=28,y=185,},},[K2]=1157,[K1]=K4,x=26,y=185,},[K2]=1154,[K1]=K7,x=10,y=185,},cos={args={f=K3,[K4]={[1]={f=K3,[K2]=1160,[K1]=K13,x=18,y=186,},},[K2]=1161,[K1]=K4,x=25,y=186,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1163,[K1]=K13,x=27,y=186,},},[K2]=1162,[K1]=K4,x=25,y=186,},[K2]=1159,[K1]=K7,x=9,y=186,},cosh={args={f=K3,[K4]={[1]={f=K3,[K2]=1165,[K1]=K13,x=19,y=187,},},[K2]=1166,[K1]=K4,x=26,y=187,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1168,[K1]=K13,x=28,y=187,},},[K2]=1167,[K1]=K4,x=26,y=187,},[K2]=1164,[K1]=K7,x=10,y=187,},deg={args={f=K3,[K4]={[1]={f=K3,[K2]=1170,[K1]=K13,x=18,y=188,},},[K2]=1171,[K1]=K4,x=25,y=188,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1173,[K1]=K13,x=27,y=188,},},[K2]=1172,[K1]=K4,x=25,y=188,},[K2]=1169,[K1]=K7,x=9,y=188,},exp={args={f=K3,[K4]={[1]={f=K3,[K2]=1175,[K1]=K13,x=18,y=189,},},[K2]=1176,[K1]=K4,x=25,y=189,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1178,[K1]=K13,x=27,y=189,},},[K2]=1177,[K1]=K4,x=25,y=189,},[K2]=1174,[K1]=K7,x=9,y=189,},["floor"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1180,[K1]=K13,x=20,y=190,},},[K2]=1181,[K1]=K4,x=27,y=190,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1183,[K1]=K12,x=29,y=190,},},[K2]=1182,[K1]=K4,x=27,y=190,},[K2]=1179,[K1]=K7,x=11,y=190,},fmod={f=K3,[K2]=1196,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={[1]={f=K3,[K2]=1185,[K1]=K12,x=19,y=192,},[2]={f=K3,[K2]=1186,[K1]=K12,x=28,y=192,},},[K2]=1187,[K1]=K4,x=36,y=192,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=1189,[K1]=K12,x=38,y=192,},},[K2]=1188,[K1]=K4,x=36,y=192,},[K2]=1184,[K1]=K7,x=10,y=192,},[2]={args={f=K3,[K4]={[1]={f=K3,[K2]=1191,[K1]=K13,x=19,y=193,},[2]={f=K3,[K2]=1192,[K1]=K13,x=27,y=193,},},[K2]=1193,[K1]=K4,x=34,y=193,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=1195,[K1]=K13,x=36,y=193,},},[K2]=1194,[K1]=K4,x=34,y=193,},[K2]=1190,[K1]=K7,x=10,y=193,},},x=8,y=193,},["frexp"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1198,[K1]=K13,x=20,y=195,},},[K2]=1199,[K1]=K4,x=27,y=195,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1201,[K1]=K13,x=29,y=195,},[2]={f=K3,[K2]=1202,[K1]=K12,x=37,y=195,},},[K2]=1200,[K1]=K4,x=27,y=195,},[K2]=1197,[K1]=K7,x=11,y=195,},huge={f=K3,[K2]=1203,[K1]=K13,x=10,y=196,},["ldexp"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1205,[K1]=K13,x=20,y=197,},[2]={f=K3,[K2]=1206,[K1]=K12,x=28,y=197,},},[K2]=1207,[K1]=K4,x=36,y=197,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=1209,[K1]=K13,x=38,y=197,},},[K2]=1208,[K1]=K4,x=36,y=197,},[K2]=1204,[K1]=K7,x=11,y=197,},log={args={f=K3,[K4]={[1]={f=K3,[K2]=1211,[K1]=K13,x=18,y=198,},[2]={f=K3,[K2]=1212,[K1]=K13,x=28,y=198,},},[K2]=1213,[K1]=K4,x=35,y=198,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1215,[K1]=K13,x=37,y=198,},},[K2]=1214,[K1]=K4,x=35,y=198,},[K2]=1210,[K1]=K7,x=9,y=198,},["log10"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1217,[K1]=K13,x=20,y=199,},},[K2]=1218,[K1]=K4,x=27,y=199,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1220,[K1]=K13,x=29,y=199,},},[K2]=1219,[K1]=K4,x=27,y=199,},[K2]=1216,[K1]=K7,x=11,y=199,},max={f=K3,[K2]=1233,[K1]="poly",[K18]={[1]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1222,[K1]=K12,x=18,y=201,},},[K2]=1223,[K1]=K4,x=29,y=201,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1225,[K1]=K12,x=31,y=201,},},[K2]=1224,[K1]=K4,x=29,y=201,},[K2]=1221,[K1]=K7,x=9,y=201,},[2]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1228,[K1]=K22,[K18]={[1]={f=K3,[K2]=1227,[K1]=K13,x=19,y=202,},[2]={f=K3,[K2]=1229,[K1]=K12,x=28,y=202,},},x=19,y=202,},},[K2]=1230,[K1]=K4,x=40,y=202,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1232,[K1]=K13,x=42,y=202,},},[K2]=1231,[K1]=K4,x=40,y=202,},[K2]=1226,[K1]=K7,x=9,y=202,},[3]={f=K3,t={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2341,[K1]=K5,[K5]="T",x=21,y=203,},},[K2]=1237,[K1]=K4,x=26,y=203,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=2342,[K1]=K5,[K5]="T",x=28,y=203,},},[K2]=1238,[K1]=K4,x=26,y=203,},[K2]=1234,[K1]=K7,x=9,y=203,},[K19]={[1]={f=K3,[K10]="T",[K2]=1235,[K1]=K10,x=18,y=203,},xend=19,yend=203,},[K2]=1240,[K1]=K20,x=4,y=204,},[4]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1242,[K1]="any",x=18,y=204,},},[K2]=1243,[K1]=K4,x=25,y=204,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1245,[K1]="any",x=27,y=204,},},[K2]=1244,[K1]=K4,x=25,y=204,},[K2]=1241,[K1]=K7,x=9,y=204,},},x=7,y=202,},["maxinteger"]={f=K3,[K29]=true,[K2]=1246,[K1]=K12,x=16,y=206,},min={f=K3,[K2]=1259,[K1]="poly",[K18]={[1]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1248,[K1]=K12,x=18,y=208,},},[K2]=1249,[K1]=K4,x=29,y=208,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1251,[K1]=K12,x=31,y=208,},},[K2]=1250,[K1]=K4,x=29,y=208,},[K2]=1247,[K1]=K7,x=9,y=208,},[2]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1254,[K1]=K22,[K18]={[1]={f=K3,[K2]=1253,[K1]=K13,x=19,y=209,},[2]={f=K3,[K2]=1255,[K1]=K12,x=28,y=209,},},x=19,y=209,},},[K2]=1256,[K1]=K4,x=40,y=209,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1258,[K1]=K13,x=42,y=209,},},[K2]=1257,[K1]=K4,x=40,y=209,},[K2]=1252,[K1]=K7,x=9,y=209,},[3]={f=K3,t={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2351,[K1]=K5,[K5]="T",x=21,y=210,},},[K2]=1263,[K1]=K4,x=26,y=210,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=2352,[K1]=K5,[K5]="T",x=28,y=210,},},[K2]=1264,[K1]=K4,x=26,y=210,},[K2]=1260,[K1]=K7,x=9,y=210,},[K19]={[1]={f=K3,[K10]="T",[K2]=1261,[K1]=K10,x=18,y=210,},xend=19,yend=210,},[K2]=1266,[K1]=K20,x=4,y=211,},[4]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1268,[K1]="any",x=18,y=211,},},[K2]=1269,[K1]=K4,x=25,y=211,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1271,[K1]="any",x=27,y=211,},},[K2]=1270,[K1]=K4,x=25,y=211,},[K2]=1267,[K1]=K7,x=9,y=211,},},x=7,y=209,},["mininteger"]={f=K3,[K29]=true,[K2]=1272,[K1]=K12,x=16,y=213,},modf={args={f=K3,[K4]={[1]={f=K3,[K2]=1274,[K1]=K13,x=19,y=215,},},[K2]=1275,[K1]=K4,x=26,y=215,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1277,[K1]=K12,x=28,y=215,},[2]={f=K3,[K2]=1278,[K1]=K13,x=37,y=215,},},[K2]=1276,[K1]=K4,x=26,y=215,},[K2]=1273,[K1]=K7,x=10,y=215,},pi={f=K3,[K2]=1279,[K1]=K13,x=8,y=216,},pow={args={f=K3,[K4]={[1]={f=K3,[K2]=1281,[K1]=K13,x=18,y=217,},[2]={f=K3,[K2]=1282,[K1]=K13,x=26,y=217,},},[K2]=1283,[K1]=K4,x=33,y=217,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=1285,[K1]=K13,x=35,y=217,},},[K2]=1284,[K1]=K4,x=33,y=217,},[K2]=1280,[K1]=K7,x=9,y=217,},rad={args={f=K3,[K4]={[1]={f=K3,[K2]=1287,[K1]=K13,x=18,y=218,},},[K2]=1288,[K1]=K4,x=25,y=218,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1290,[K1]=K13,x=27,y=218,},},[K2]=1289,[K1]=K4,x=25,y=218,},[K2]=1286,[K1]=K7,x=9,y=218,},["random"]={f=K3,[K2]=1301,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={[1]={f=K3,[K2]=1292,[K1]=K12,x=21,y=220,},[2]={f=K3,[K2]=1293,[K1]=K12,x=32,y=220,},},[K2]=1294,[K1]=K4,x=40,y=220,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1296,[K1]=K12,x=42,y=220,},},[K2]=1295,[K1]=K4,x=40,y=220,},[K2]=1291,[K1]=K7,x=12,y=220,},[2]={args={f=K3,[K4]={},[K2]=1298,[K1]=K4,x=22,y=221,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1300,[K1]=K13,x=24,y=221,},},[K2]=1299,[K1]=K4,x=22,y=221,},[K2]=1297,[K1]=K7,x=12,y=221,},},x=10,y=221,},["randomseed"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1303,[K1]=K12,x=27,y=223,},[2]={f=K3,[K2]=1304,[K1]=K12,x=38,y=223,},},[K2]=1305,[K1]=K4,x=46,y=223,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1307,[K1]=K12,x=48,y=223,},[2]={f=K3,[K2]=1308,[K1]=K12,x=57,y=223,},},[K2]=1306,[K1]=K4,x=46,y=223,},[K2]=1302,[K1]=K7,x=16,y=223,},sin={args={f=K3,[K4]={[1]={f=K3,[K2]=1310,[K1]=K13,x=18,y=224,},},[K2]=1311,[K1]=K4,x=25,y=224,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1313,[K1]=K13,x=27,y=224,},},[K2]=1312,[K1]=K4,x=25,y=224,},[K2]=1309,[K1]=K7,x=9,y=224,},sinh={args={f=K3,[K4]={[1]={f=K3,[K2]=1315,[K1]=K13,x=19,y=225,},},[K2]=1316,[K1]=K4,x=26,y=225,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1318,[K1]=K13,x=28,y=225,},},[K2]=1317,[K1]=K4,x=26,y=225,},[K2]=1314,[K1]=K7,x=10,y=225,},sqrt={args={f=K3,[K4]={[1]={f=K3,[K2]=1320,[K1]=K13,x=19,y=226,},},[K2]=1321,[K1]=K4,x=26,y=226,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1323,[K1]=K13,x=28,y=226,},},[K2]=1322,[K1]=K4,x=26,y=226,},[K2]=1319,[K1]=K7,x=10,y=226,},tan={args={f=K3,[K4]={[1]={f=K3,[K2]=1325,[K1]=K13,x=18,y=227,},},[K2]=1326,[K1]=K4,x=25,y=227,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1328,[K1]=K13,x=27,y=227,},},[K2]=1327,[K1]=K4,x=25,y=227,},[K2]=1324,[K1]=K7,x=9,y=227,},tanh={args={f=K3,[K4]={[1]={f=K3,[K2]=1330,[K1]=K13,x=19,y=228,},},[K2]=1331,[K1]=K4,x=26,y=228,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1333,[K1]=K13,x=28,y=228,},},[K2]=1332,[K1]=K4,x=26,y=228,},[K2]=1329,[K1]=K7,x=10,y=228,},["tointeger"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1335,[K1]="any",x=24,y=229,},},[K2]=1336,[K1]=K4,x=28,y=229,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1338,[K1]=K12,x=30,y=229,},},[K2]=1337,[K1]=K4,x=28,y=229,},[K2]=1334,[K1]=K7,x=15,y=229,},type={args={f=K3,[K4]={[1]={f=K3,[K2]=1340,[K1]="any",x=19,y=230,},},[K2]=1341,[K1]=K4,x=23,y=230,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1343,[K1]=K11,x=25,y=230,},},[K2]=1342,[K1]=K4,x=23,y=230,},[K2]=1339,[K1]=K7,x=10,y=230,},ult={args={f=K3,[K4]={[1]={f=K3,[K2]=1345,[K1]=K13,x=18,y=231,},[2]={f=K3,[K2]=1346,[K1]=K13,x=26,y=231,},},[K2]=1347,[K1]=K4,x=33,y=231,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=1349,[K1]=K24,x=35,y=231,},},[K2]=1348,[K1]=K4,x=33,y=231,},[K2]=1344,[K1]=K7,x=9,y=231,},},[K2]=1119,[K1]=K37,x=1,y=177,},f=K3,[K2]=1350,[K1]=K21,x=1,y=177,},},[K44]={t=T17,[K[12]]=true,},next={[K27]=K26,t={f=K3,[K2]=2060,[K1]="poly",[K18]={[1]={f=K3,t={args={f=K3,[K4]={[1]={f=K3,keys={f=K3,[K2]=2613,[K1]=K5,[K5]="K",x=26,y=390,},[K2]=2042,[K1]="map",[K28]={f=K3,[K2]=2614,[K1]=K5,[K5]="V",x=28,y=390,},x=25,xend=29,y=390,yend=390,},[2]={f=K3,[K2]=2615,[K1]=K5,[K5]="K",x=34,y=390,},},[K2]=2045,[K1]=K4,x=36,y=390,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=2616,[K1]=K5,[K5]="K",x=39,y=390,},[2]={f=K3,[K2]=2617,[K1]=K5,[K5]="V",x=42,y=390,},},[K2]=2046,[K1]=K4,x=36,y=390,},[K2]=2038,[K1]=K7,x=10,y=390,},[K19]={[1]={f=K3,[K10]="K",[K2]=2039,[K1]=K10,x=19,y=390,},[2]={f=K3,[K10]="V",[K2]=2040,[K1]=K10,x=22,y=390,},xend=23,yend=390,},[K2]=2049,[K1]=K20,x=4,y=391,},[2]={f=K3,t={args={f=K3,[K4]={[1]={[K30]={f=K3,[K2]=2631,[K1]=K5,[K5]="A",x=23,y=391,},f=K3,[K2]=2053,[K1]=K31,x=22,xend=24,y=391,yend=391,},[2]={f=K3,[K2]=2054,[K1]=K12,x=29,y=391,},},[K2]=2055,[K1]=K4,x=37,y=391,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=2057,[K1]=K12,x=40,y=391,},[2]={f=K3,[K2]=2632,[K1]=K5,[K5]="A",x=49,y=391,},},[K2]=2056,[K1]=K4,x=37,y=391,},[K2]=2050,[K1]=K7,x=10,y=391,},[K19]={[1]={f=K3,[K10]="A",[K2]=2051,[K1]=K10,x=19,y=391,},xend=20,yend=391,},[K2]=2059,[K1]=K20,x=4,y=393,},},x=8,y=391,},},os={[K29]=true,t={[K34]=true,def={[K25]="os",f=K3,[K33]={[1]=K[26],[2]=K[27],[3]="clock",[4]="date",[5]="difftime",[6]="execute",[7]="exit",[8]="getenv",[9]=K[28],[10]="rename",[11]="setlocale",[12]="time",[13]="tmpname",},[K32]={[K[27]]=T24,[K[26]]=T25,["clock"]={args={f=K3,[K4]={},[K2]=1366,[K1]=K4,x=21,y=251,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1368,[K1]=K13,x=23,y=251,},},[K2]=1367,[K1]=K4,x=21,y=251,},[K2]=1365,[K1]=K7,x=11,y=251,},date={f=K3,[K2]=1381,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={[1]={f=K3,[K17]=T24,[K16]={[1]=K[27],},[K2]=1370,[K1]=K15,x=19,y=253,},[2]={f=K3,[K2]=1371,[K1]=K13,x=31,y=253,},},[K2]=1372,[K1]=K4,x=38,y=253,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K17]=T25,[K16]={[1]=K[26],},[K2]=1374,[K1]=K15,x=40,y=253,},},[K2]=1373,[K1]=K4,x=38,y=253,},[K2]=1369,[K1]=K7,x=10,y=253,},[2]={args={f=K3,[K4]={[1]={f=K3,[K2]=1376,[K1]=K11,x=21,y=254,},[2]={f=K3,[K2]=1377,[K1]=K13,x=31,y=254,},},[K2]=1378,[K1]=K4,x=38,y=254,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1380,[K1]=K11,x=40,y=254,},},[K2]=1379,[K1]=K4,x=38,y=254,},[K2]=1375,[K1]=K7,x=10,y=254,},},x=8,y=254,},["difftime"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1383,[K1]=K12,x=23,y=256,},[2]={f=K3,[K2]=1384,[K1]=K12,x=32,y=256,},},[K2]=1385,[K1]=K4,x=40,y=256,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=1387,[K1]=K13,x=42,y=256,},},[K2]=1386,[K1]=K4,x=40,y=256,},[K2]=1382,[K1]=K7,x=14,y=256,},["execute"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1389,[K1]=K11,x=22,y=257,},},[K2]=1390,[K1]=K4,x=29,y=257,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1392,[K1]=K24,x=31,y=257,},[2]={f=K3,[K2]=1393,[K1]=K11,x=40,y=257,},[3]={f=K3,[K2]=1394,[K1]=K12,x=48,y=257,},},[K2]=1391,[K1]=K4,x=29,y=257,},[K2]=1388,[K1]=K7,x=13,y=257,},exit={args={f=K3,[K4]={[1]={f=K3,[K2]=1397,[K1]=K22,[K18]={[1]={f=K3,[K2]=1396,[K1]=K12,x=22,y=258,},[2]={f=K3,[K2]=1398,[K1]=K24,x=32,y=258,},},x=22,y=258,},[2]={f=K3,[K2]=1399,[K1]=K24,x=44,y=258,},},[K2]=1400,[K1]=K4,x=4,y=259,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={},[K2]=1401,[K1]=K4,x=51,y=258,},[K2]=1395,[K1]=K7,x=10,y=258,},["getenv"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1403,[K1]=K11,x=21,y=259,},},[K2]=1404,[K1]=K4,x=28,y=259,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1406,[K1]=K11,x=30,y=259,},},[K2]=1405,[K1]=K4,x=28,y=259,},[K2]=1402,[K1]=K7,x=12,y=259,},[K[28]]={args={f=K3,[K4]={[1]={f=K3,[K2]=1408,[K1]=K11,x=21,y=260,},},[K2]=1409,[K1]=K4,x=28,y=260,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1411,[K1]=K24,x=30,y=260,},[2]={f=K3,[K2]=1412,[K1]=K11,x=39,y=260,},},[K2]=1410,[K1]=K4,x=28,y=260,},[K2]=1407,[K1]=K7,x=12,y=260,},["rename"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1414,[K1]=K11,x=21,y=261,},[2]={f=K3,[K2]=1415,[K1]=K11,x=29,y=261,},},[K2]=1416,[K1]=K4,x=36,y=261,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=1418,[K1]=K24,x=38,y=261,},[2]={f=K3,[K2]=1419,[K1]=K11,x=47,y=261,},},[K2]=1417,[K1]=K4,x=36,y=261,},[K2]=1413,[K1]=K7,x=12,y=261,},["setlocale"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1421,[K1]=K11,x=24,y=262,},[2]={f=K3,[K2]=1422,[K1]=K11,x=34,y=262,},},[K2]=1423,[K1]=K4,x=41,y=262,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1425,[K1]=K11,x=43,y=262,},},[K2]=1424,[K1]=K4,x=41,y=262,},[K2]=1420,[K1]=K7,x=15,y=262,},time={args={f=K3,[K4]={[1]={f=K3,[K17]=T25,[K16]={[1]=K[26],},[K2]=1427,[K1]=K15,x=21,y=263,},},[K2]=1428,[K1]=K4,x=31,y=263,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1430,[K1]=K12,x=33,y=263,},},[K2]=1429,[K1]=K4,x=31,y=263,},[K2]=1426,[K1]=K7,x=10,y=263,},["tmpname"]={args={f=K3,[K4]={},[K2]=1432,[K1]=K4,x=23,y=264,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1434,[K1]=K11,x=25,y=264,},},[K2]=1433,[K1]=K4,x=23,y=264,},[K2]=1431,[K1]=K7,x=13,y=264,},},[K2]=1351,[K1]=K37,x=1,y=234,},f=K3,[K2]=1435,[K1]=K21,x=1,y=234,},},["package"]={[K29]=true,t={[K34]=true,def={[K25]="package",f=K3,[K33]={[1]="config",[2]="cpath",[3]="loaded",[4]="loadlib",[5]="loaders",[6]="path",[7]="preload",[8]="searchers",[9]="searchpath",},[K32]={["config"]={f=K3,[K2]=1437,[K1]=K11,x=12,y=268,},["cpath"]={f=K3,[K2]=1438,[K1]=K11,x=11,y=269,},["loaded"]={f=K3,keys={f=K3,[K2]=1439,[K1]=K11,x=13,y=270,},[K2]=1440,[K1]="map",[K28]={f=K3,[K2]=1441,[K1]="any",x=20,y=270,},x=12,xend=23,y=270,yend=270,},["loaders"]={[K30]={args={f=K3,[K4]={[1]={f=K3,[K2]=1453,[K1]=K11,x=25,y=272,},},[K2]=1454,[K1]=K4,x=32,y=272,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={args={f=K3,[K4]={[1]={f=K3,[K2]=1457,[K1]=K11,x=46,y=272,},[2]={f=K3,[K2]=1458,[K1]="any",x=56,y=272,},},[K2]=1459,[K1]=K4,x=60,y=272,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1461,[K1]="any",x=63,y=272,},},[K2]=1460,[K1]=K4,x=60,y=272,},[K2]=1456,[K1]=K7,x=35,y=272,},[2]={f=K3,[K2]=1462,[K1]="any",x=69,y=272,},},[K2]=1455,[K1]=K4,x=32,y=272,},[K2]=1452,[K1]=K7,x=16,y=272,},f=K3,[K2]=1463,[K1]=K31,x=13,xend=75,y=272,yend=272,},["loadlib"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1443,[K1]=K11,x=22,y=271,},[2]={f=K3,[K2]=1444,[K1]=K11,x=30,y=271,},},[K2]=1445,[K1]=K4,x=37,y=271,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1448,[K1]="any",x=48,y=271,},},[K2]=1449,[K1]=K4,x=48,y=271,},f=K3,[K41]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1450,[K1]="any",x=48,y=271,},},[K2]=1451,[K1]=K4,x=48,y=271,},[K2]=1447,[K1]=K7,x=40,y=271,},},[K2]=1446,[K1]=K4,x=37,y=271,},[K2]=1442,[K1]=K7,x=13,y=271,},path={f=K3,[K2]=1464,[K1]=K11,x=10,y=273,},["preload"]={f=K3,keys={f=K3,[K2]=1465,[K1]=K11,x=14,y=274,},[K2]=1466,[K1]="map",[K28]={args={f=K3,[K4]={[1]={f=K3,[K2]=1468,[K1]=K11,x=34,y=274,},[2]={f=K3,[K2]=1469,[K1]="any",x=44,y=274,},},[K2]=1470,[K1]=K4,x=48,y=274,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1472,[K1]="any",x=51,y=274,},},[K2]=1471,[K1]=K4,x=48,y=274,},[K2]=1467,[K1]=K7,x=23,y=274,},x=13,xend=56,y=274,yend=274,},["searchers"]={[K30]={args={f=K3,[K4]={[1]={f=K3,[K2]=1474,[K1]=K11,x=27,y=275,},},[K2]=1475,[K1]=K4,x=34,y=275,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={args={f=K3,[K4]={[1]={f=K3,[K2]=1478,[K1]=K11,x=48,y=275,},[2]={f=K3,[K2]=1479,[K1]="any",x=58,y=275,},},[K2]=1480,[K1]=K4,x=62,y=275,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1482,[K1]="any",x=65,y=275,},},[K2]=1481,[K1]=K4,x=62,y=275,},[K2]=1477,[K1]=K7,x=37,y=275,},[2]={f=K3,[K2]=1483,[K1]="any",x=71,y=275,},},[K2]=1476,[K1]=K4,x=34,y=275,},[K2]=1473,[K1]=K7,x=18,y=275,},f=K3,[K2]=1484,[K1]=K31,x=15,xend=77,y=275,yend=275,},["searchpath"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1486,[K1]=K11,x=25,y=276,},[2]={f=K3,[K2]=1487,[K1]=K11,x=33,y=276,},[3]={f=K3,[K2]=1488,[K1]=K11,x=43,y=276,},[4]={f=K3,[K2]=1489,[K1]=K11,x=53,y=276,},},[K2]=1490,[K1]=K4,x=60,y=276,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=1492,[K1]=K11,x=62,y=276,},[2]={f=K3,[K2]=1493,[K1]=K11,x=70,y=276,},},[K2]=1491,[K1]=K4,x=60,y=276,},[K2]=1485,[K1]=K7,x=16,y=276,},},[K2]=1436,[K1]=K37,x=1,y=267,},f=K3,[K2]=1494,[K1]=K21,x=1,y=267,},},["pairs"]={[K27]=K26,[K29]=true,t={f=K3,[K23]=true,t={args={f=K3,[K4]={[1]={f=K3,keys={f=K3,[K2]=2655,[K1]=K5,[K5]="K@48",x=27,y=393,},[K2]=2657,[K1]="map",[K28]={f=K3,[K2]=2656,[K1]=K5,[K5]="V@48",x=29,y=393,},x=26,y=393,},},[K2]=2658,[K1]=K4,x=32,y=393,},f=K3,[K6]=1,rets={f=K3,[K4]={[1]={args={f=K3,[K4]={[1]={f=K3,keys={f=K3,[K2]=2659,[K1]=K5,[K5]="K@48",x=45,y=393,},[K2]=2661,[K1]="map",[K28]={f=K3,[K2]=2660,[K1]=K5,[K5]="V@48",x=47,y=393,},x=44,y=393,},[2]={f=K3,[K2]=2662,[K1]=K5,[K5]="K@48",x=53,y=393,},},[K2]=2663,[K1]=K4,x=55,y=393,},f=K3,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=2664,[K1]=K5,[K5]="K@48",x=57,y=393,},[2]={f=K3,[K2]=2665,[K1]=K5,[K5]="V@48",x=60,y=393,},},[K2]=2666,[K1]=K4,x=55,y=393,},[K2]=2667,[K1]=K7,x=35,y=393,},[2]={f=K3,keys={f=K3,[K2]=2668,[K1]=K5,[K5]="K@48",x=65,y=393,},[K2]=2670,[K1]="map",[K28]={f=K3,[K2]=2669,[K1]=K5,[K5]="V@48",x=67,y=393,},x=64,y=393,},[3]={f=K3,[K2]=2671,[K1]=K5,[K5]="K@48",x=71,y=393,},},[K2]=2672,[K1]=K4,x=32,y=393,},[K36]="pairs",[K2]=2673,[K1]=K7,x=11,y=393,},[K19]={[1]={f=K3,[K10]="K@48",[K2]=2653,[K1]=K10,x=20,y=393,},[2]={f=K3,[K10]="V@48",[K2]=2654,[K1]=K10,x=23,y=393,},},[K2]=2674,[K1]=K20,x=4,y=394,},},["pcall"]={[K27]=K26,[K29]=true,t={args={f=K3,[K14]=true,[K4]={[1]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2085,[K1]="any",x=29,y=394,},},[K2]=2086,[K1]=K4,x=36,y=394,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2088,[K1]="any",x=38,y=394,},},[K2]=2087,[K1]=K4,x=36,y=394,},[K2]=2084,[K1]=K7,x=20,y=394,},[2]={f=K3,[K2]=2089,[K1]="any",x=47,y=394,},},[K2]=2090,[K1]=K4,x=54,y=394,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2092,[K1]=K24,x=56,y=394,},[2]={f=K3,[K2]=2093,[K1]="any",x=65,y=394,},},[K2]=2091,[K1]=K4,x=54,y=394,},[K36]="pcall",[K2]=2083,[K1]=K7,x=11,y=394,},},["print"]={[K27]=K26,t={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2095,[K1]="any",x=20,y=395,},},[K2]=2096,[K1]=K4,x=4,y=396,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={},[K2]=2097,[K1]=K4,x=26,y=395,},[K2]=2094,[K1]=K7,x=11,y=395,},},["rawequal"]={[K27]=K26,t={args={f=K3,[K4]={[1]={f=K3,[K2]=2099,[K1]="any",x=23,y=396,},[2]={f=K3,[K2]=2100,[K1]="any",x=28,y=396,},},[K2]=2101,[K1]=K4,x=32,y=396,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=2103,[K1]=K24,x=34,y=396,},},[K2]=2102,[K1]=K4,x=32,y=396,},[K2]=2098,[K1]=K7,x=14,y=396,},},["rawget"]={[K27]=K26,t={f=K3,[K2]=2123,[K1]="poly",[K18]={[1]={f=K3,t={args={f=K3,[K4]={[1]={f=K3,keys={f=K3,[K2]=2677,[K1]=K5,[K5]="K",x=28,y=398,},[K2]=2108,[K1]="map",[K28]={f=K3,[K2]=2678,[K1]=K5,[K5]="V",x=30,y=398,},x=27,xend=31,y=398,yend=398,},[2]={f=K3,[K2]=2679,[K1]=K5,[K5]="K",x=34,y=398,},},[K2]=2111,[K1]=K4,x=36,y=398,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=2680,[K1]=K5,[K5]="V",x=38,y=398,},},[K2]=2112,[K1]=K4,x=36,y=398,},[K36]="rawget",[K2]=2104,[K1]=K7,x=12,y=398,},[K19]={[1]={f=K3,[K10]="K",[K2]=2105,[K1]=K10,x=21,y=398,},[2]={f=K3,[K10]="V",[K2]=2106,[K1]=K10,x=24,y=398,},xend=25,yend=398,},[K2]=2114,[K1]=K20,x=4,y=399,},[2]={args={f=K3,[K4]={[1]={f=K3,keys={f=K3,[K2]=2116,[K1]="any",x=22,y=399,},[K2]=2117,[K1]="map",[K28]={f=K3,[K2]=2118,[K1]="any",x=26,y=399,},x=21,xend=29,y=399,yend=399,},[2]={f=K3,[K2]=2119,[K1]="any",x=32,y=399,},},[K2]=2120,[K1]=K4,x=36,y=399,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=2122,[K1]="any",x=38,y=399,},},[K2]=2121,[K1]=K4,x=36,y=399,},[K2]=2115,[K1]=K7,x=12,y=399,},[3]={args={f=K3,[K4]={[1]={f=K3,[K2]=2125,[K1]="any",x=21,y=400,},[2]={f=K3,[K2]=2126,[K1]="any",x=26,y=400,},},[K2]=2127,[K1]=K4,x=30,y=400,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=2129,[K1]="any",x=32,y=400,},},[K2]=2128,[K1]=K4,x=30,y=400,},[K2]=2124,[K1]=K7,x=12,y=400,},},x=10,y=399,},},["rawlen"]={[K27]=K26,[K29]=true,t={f=K3,[K23]=true,t={args={f=K3,[K4]={[1]={[K30]={f=K3,[K2]=2695,[K1]=K5,[K5]="A@50",x=25,y=402,},f=K3,[K2]=2696,[K1]=K31,x=24,y=402,},},[K2]=2697,[K1]=K4,x=28,y=402,},f=K3,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=2136,[K1]=K12,x=30,y=402,},},[K2]=2135,[K1]=K4,x=28,y=402,},[K2]=2698,[K1]=K7,x=12,y=402,},[K19]={[1]={f=K3,[K10]="A@50",[K2]=2694,[K1]=K10,x=21,y=402,},},[K2]=2699,[K1]=K20,x=4,y=404,},},["rawset"]={[K27]=K26,t={f=K3,[K2]=2163,[K1]="poly",[K18]={[1]={f=K3,t={args={f=K3,[K4]={[1]={f=K3,keys={f=K3,[K2]=2702,[K1]=K5,[K5]="K",x=28,y=404,},[K2]=2142,[K1]="map",[K28]={f=K3,[K2]=2703,[K1]=K5,[K5]="V",x=30,y=404,},x=27,xend=31,y=404,yend=404,},[2]={f=K3,[K2]=2704,[K1]=K5,[K5]="K",x=34,y=404,},[3]={f=K3,[K2]=2705,[K1]=K5,[K5]="V",x=37,y=404,},},[K2]=2146,[K1]=K4,x=39,y=404,},f=K3,[K9]=false,[K6]=3,rets={f=K3,[K4]={[1]={f=K3,keys={f=K3,[K2]=2706,[K1]=K5,[K5]="K",x=42,y=404,},[K2]=2149,[K1]="map",[K28]={f=K3,[K2]=2707,[K1]=K5,[K5]="V",x=44,y=404,},x=41,xend=45,y=404,yend=404,},},[K2]=2147,[K1]=K4,x=39,y=404,},[K2]=2138,[K1]=K7,x=12,y=404,},[K19]={[1]={f=K3,[K10]="K",[K2]=2139,[K1]=K10,x=21,y=404,},[2]={f=K3,[K10]="V",[K2]=2140,[K1]=K10,x=24,y=404,},xend=25,yend=404,},[K2]=2151,[K1]=K20,x=4,y=405,},[2]={args={f=K3,[K4]={[1]={f=K3,keys={f=K3,[K2]=2153,[K1]="any",x=22,y=405,},[K2]=2154,[K1]="map",[K28]={f=K3,[K2]=2155,[K1]="any",x=26,y=405,},x=21,xend=29,y=405,yend=405,},[2]={f=K3,[K2]=2156,[K1]="any",x=32,y=405,},[3]={f=K3,[K2]=2157,[K1]="any",x=37,y=405,},},[K2]=2158,[K1]=K4,x=41,y=405,},f=K3,[K9]=false,[K6]=3,rets={f=K3,[K4]={[1]={f=K3,keys={f=K3,[K2]=2160,[K1]="any",x=44,y=405,},[K2]=2161,[K1]="map",[K28]={f=K3,[K2]=2162,[K1]="any",x=48,y=405,},x=43,xend=51,y=405,yend=405,},},[K2]=2159,[K1]=K4,x=41,y=405,},[K2]=2152,[K1]=K7,x=12,y=405,},[3]={args={f=K3,[K4]={[1]={f=K3,[K2]=2165,[K1]="any",x=21,y=406,},[2]={f=K3,[K2]=2166,[K1]="any",x=26,y=406,},[3]={f=K3,[K2]=2167,[K1]="any",x=31,y=406,},},[K2]=2168,[K1]=K4,x=35,y=406,},f=K3,[K9]=false,[K6]=3,rets={f=K3,[K4]={[1]={f=K3,[K2]=2170,[K1]="any",x=37,y=406,},},[K2]=2169,[K1]=K4,x=35,y=406,},[K2]=2164,[K1]=K7,x=12,y=406,},},x=10,y=405,},},["require"]={[K27]=K26,t={args={f=K3,[K4]={[1]={f=K3,[K2]=2172,[K1]=K11,x=22,y=408,},},[K2]=2173,[K1]=K4,x=29,y=408,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=2175,[K1]="any",x=31,y=408,},},[K2]=2174,[K1]=K4,x=29,y=408,},[K36]="require",[K2]=2171,[K1]=K7,x=13,y=408,},},["select"]={[K27]=K26,t={f=K3,[K2]=2190,[K1]="poly",[K18]={[1]={f=K3,t={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2178,[K1]=K12,x=24,y=410,},[2]={f=K3,[K2]=2723,[K1]=K5,[K5]="T",x=33,y=410,},},[K2]=2180,[K1]=K4,x=38,y=410,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2724,[K1]=K5,[K5]="T",x=40,y=410,},},[K2]=2181,[K1]=K4,x=38,y=410,},[K2]=2176,[K1]=K7,x=12,y=410,},[K19]={[1]={f=K3,[K10]="T",[K2]=2177,[K1]=K10,x=21,y=410,},xend=22,yend=410,},[K2]=2183,[K1]=K20,x=4,y=411,},[2]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2185,[K1]=K12,x=21,y=411,},[2]={f=K3,[K2]=2186,[K1]="any",x=30,y=411,},},[K2]=2187,[K1]=K4,x=37,y=411,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2189,[K1]="any",x=39,y=411,},},[K2]=2188,[K1]=K4,x=37,y=411,},[K2]=2184,[K1]=K7,x=12,y=411,},[3]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2192,[K1]=K11,x=21,y=412,},[2]={f=K3,[K2]=2193,[K1]="any",x=29,y=412,},},[K2]=2194,[K1]=K4,x=36,y=412,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=2196,[K1]=K12,x=38,y=412,},},[K2]=2195,[K1]=K4,x=36,y=412,},[K2]=2191,[K1]=K7,x=12,y=412,},},x=10,y=411,},},[K[18]]={[K27]=K26,t={f=K3,[K23]=true,t={args={f=K3,[K4]={[1]={f=K3,[K2]=2737,[K1]=K5,[K5]="T@53",x=30,y=414,},[2]={f=K3,[K17]=T17,[K16]={[1]=K44,},[K2]=2739,[K1]=K15,[K43]={[1]={f=K3,[K2]=2738,[K1]=K5,[K5]="T@53",x=43,y=414,},},x=33,y=414,},},[K2]=2740,[K1]=K4,x=46,y=414,},f=K3,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=2741,[K1]=K5,[K5]="T@53",x=48,y=414,},},[K2]=2742,[K1]=K4,x=46,y=414,},[K2]=2743,[K1]=K7,x=18,y=414,},[K19]={[1]={f=K3,[K10]="T@53",[K2]=2736,[K1]=K10,x=27,y=414,},},[K2]=2744,[K1]=K20,x=4,y=416,},},[K11]={[K29]=true,t={[K34]=true,def={[K25]=K11,f=K3,[K[20]]={[K[29]]={[1]={[1]={text=K42,x=86,y=285,},},},[K[30]]={[1]={[1]={text=K42,x=45,y=286,},},},gsub={[1]={},[2]={[1]={text=K42,x=71,y=289,},},[3]={[1]={text=K42,x=95,y=290,},},[4]={[1]={text=K42,x=96,y=291,},},},pack={[1]={[1]={text=K42,x=58,y=296,},},},[K[31]]={[1]={[1]={text=K42,x=43,y=297,},},},[K[32]]={[1]={[1]={text=K42,x=56,y=302,},},},},[K33]={[1]="byte",[2]="char",[3]="dump",[4]="find",[5]=K[29],[6]=K[30],[7]="gsub",[8]="len",[9]="lower",[10]="match",[11]="pack",[12]=K[31],[13]="rep",[14]="reverse",[15]="sub",[16]=K46,[17]=K[32],},[K32]={byte={f=K3,[K2]=1509,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={[1]={f=K3,[K2]=1497,[K1]=K11,x=19,y=280,},[2]={f=K3,[K2]=1498,[K1]=K12,x=29,y=280,},},[K2]=1499,[K1]=K4,x=37,y=280,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1501,[K1]=K12,x=39,y=280,},},[K2]=1500,[K1]=K4,x=37,y=280,},[K2]=1496,[K1]=K7,x=10,y=280,},[2]={args={f=K3,[K4]={[1]={f=K3,[K2]=1503,[K1]=K11,x=19,y=281,},[2]={f=K3,[K2]=1504,[K1]=K12,x=27,y=281,},[3]={f=K3,[K2]=1505,[K1]=K12,x=38,y=281,},},[K2]=1506,[K1]=K4,x=46,y=281,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1508,[K1]=K12,x=48,y=281,},},[K2]=1507,[K1]=K4,x=46,y=281,},[K2]=1502,[K1]=K7,x=10,y=281,},},x=8,y=281,},char={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1511,[K1]=K12,x=19,y=283,},},[K2]=1512,[K1]=K4,x=30,y=283,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1514,[K1]=K11,x=32,y=283,},},[K2]=1513,[K1]=K4,x=30,y=283,},[K2]=1510,[K1]=K7,x=10,y=283,},dump={args={f=K3,[K4]={[1]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1517,[K1]="any",x=28,y=284,},},[K2]=1518,[K1]=K4,x=35,y=284,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1520,[K1]="any",x=38,y=284,},},[K2]=1519,[K1]=K4,x=35,y=284,},[K2]=1516,[K1]=K7,x=19,y=284,},[2]={f=K3,[K2]=1521,[K1]=K24,x=46,y=284,},},[K2]=1522,[K1]=K4,x=54,y=284,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1524,[K1]=K11,x=56,y=284,},},[K2]=1523,[K1]=K4,x=54,y=284,},[K2]=1515,[K1]=K7,x=10,y=284,},find={args={f=K3,[K4]={[1]={f=K3,[K2]=1526,[K1]=K11,x=19,y=285,},[2]={f=K3,[K2]=1527,[K1]=K11,x=27,y=285,},[3]={f=K3,[K2]=1528,[K1]=K12,x=37,y=285,},[4]={f=K3,[K2]=1529,[K1]=K24,x=48,y=285,},},[K2]=1530,[K1]=K4,x=56,y=285,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1532,[K1]=K12,x=58,y=285,},[2]={f=K3,[K2]=1533,[K1]=K12,x=67,y=285,},[3]={f=K3,[K2]=1534,[K1]=K11,x=76,y=285,},},[K2]=1531,[K1]=K4,x=56,y=285,},[K36]="string.find",[K2]=1525,[K1]=K7,x=10,y=285,},[K[29]]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1536,[K1]=K11,x=21,y=286,},[2]={f=K3,[K2]=1537,[K1]="any",x=29,y=286,},},[K2]=1538,[K1]=K4,x=36,y=286,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1540,[K1]=K11,x=38,y=286,},},[K2]=1539,[K1]=K4,x=36,y=286,},[K36]="string.format",[K2]=1535,[K1]=K7,x=12,y=286,},[K[30]]={args={f=K3,[K4]={[1]={f=K3,[K2]=1542,[K1]=K11,x=21,y=287,},[2]={f=K3,[K2]=1543,[K1]=K11,x=29,y=287,},[3]={f=K3,[K2]=1544,[K1]=K12,x=39,y=287,},},[K2]=1545,[K1]=K4,x=47,y=287,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={args={f=K3,[K4]={},[K2]=1548,[K1]=K4,x=60,y=287,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1550,[K1]=K11,x=62,y=287,},},[K2]=1549,[K1]=K4,x=60,y=287,},[K2]=1547,[K1]=K7,x=50,y=287,},},[K2]=1546,[K1]=K4,x=47,y=287,},[K36]="string.gmatch",[K2]=1541,[K1]=K7,x=12,y=287,},gsub={f=K3,[K2]=1574,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={[1]={f=K3,[K2]=1552,[K1]=K11,x=19,y=289,},[2]={f=K3,[K2]=1553,[K1]=K11,x=27,y=289,},[3]={f=K3,[K2]=1554,[K1]=K11,x=35,y=289,},[4]={f=K3,[K2]=1555,[K1]=K12,x=45,y=289,},},[K2]=1556,[K1]=K4,x=53,y=289,},f=K3,[K9]=false,[K6]=3,rets={f=K3,[K4]={[1]={f=K3,[K2]=1558,[K1]=K11,x=55,y=289,},[2]={f=K3,[K2]=1559,[K1]=K12,x=63,y=289,},},[K2]=1557,[K1]=K4,x=53,y=289,},[K36]="string.gsub",[K2]=1551,[K1]=K7,x=10,y=289,},[2]={args={f=K3,[K4]={[1]={f=K3,[K2]=1561,[K1]=K11,x=19,y=290,},[2]={f=K3,[K2]=1562,[K1]=K11,x=27,y=290,},[3]={f=K3,keys={f=K3,[K2]=1563,[K1]=K11,x=36,y=290,},[K2]=1564,[K1]="map",[K28]={f=K3,[K2]=1566,[K1]=K22,[K18]={[1]={f=K3,[K2]=1565,[K1]=K11,x=43,y=290,},[2]={f=K3,[K2]=1567,[K1]=K12,x=50,y=290,},[3]={f=K3,[K2]=1568,[K1]=K13,x=58,y=290,},},x=43,y=290,},x=35,xend=64,y=290,yend=290,},[4]={f=K3,[K2]=1569,[K1]=K12,x=69,y=290,},},[K2]=1570,[K1]=K4,x=77,y=290,},f=K3,[K9]=false,[K6]=3,rets={f=K3,[K4]={[1]={f=K3,[K2]=1572,[K1]=K11,x=79,y=290,},[2]={f=K3,[K2]=1573,[K1]=K12,x=87,y=290,},},[K2]=1571,[K1]=K4,x=77,y=290,},[K2]=1560,[K1]=K7,x=10,y=290,},[3]={args={f=K3,[K4]={[1]={f=K3,[K2]=1576,[K1]=K11,x=19,y=291,},[2]={f=K3,[K2]=1577,[K1]=K11,x=27,y=291,},[3]={f=K3,keys={f=K3,[K2]=1578,[K1]=K12,x=36,y=291,},[K2]=1579,[K1]="map",[K28]={f=K3,[K2]=1581,[K1]=K22,[K18]={[1]={f=K3,[K2]=1580,[K1]=K11,x=44,y=291,},[2]={f=K3,[K2]=1582,[K1]=K12,x=51,y=291,},[3]={f=K3,[K2]=1583,[K1]=K13,x=59,y=291,},},x=44,y=291,},x=35,xend=65,y=291,yend=291,},[4]={f=K3,[K2]=1584,[K1]=K12,x=70,y=291,},},[K2]=1585,[K1]=K4,x=78,y=291,},f=K3,[K9]=false,[K6]=3,rets={f=K3,[K4]={[1]={f=K3,[K2]=1587,[K1]=K11,x=80,y=291,},[2]={f=K3,[K2]=1588,[K1]=K12,x=88,y=291,},},[K2]=1586,[K1]=K4,x=78,y=291,},[K2]=1575,[K1]=K7,x=10,y=291,},[4]={args={f=K3,[K4]={[1]={f=K3,[K2]=1590,[K1]=K11,x=19,y=292,},[2]={f=K3,[K2]=1591,[K1]=K11,x=27,y=292,},[3]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1594,[K1]=K22,[K18]={[1]={f=K3,[K2]=1593,[K1]=K11,x=45,y=292,},[2]={f=K3,[K2]=1595,[K1]=K12,x=52,y=292,},},x=45,y=292,},},[K2]=1596,[K1]=K4,x=64,y=292,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1599,[K1]=K22,[K18]={[1]={f=K3,[K2]=1598,[K1]=K11,x=68,y=292,},[2]={f=K3,[K2]=1600,[K1]=K12,x=75,y=292,},[3]={f=K3,[K2]=1601,[K1]=K13,x=83,y=292,},},x=68,y=292,},},[K2]=1597,[K1]=K4,x=64,y=292,},[K2]=1592,[K1]=K7,x=35,y=292,},[4]={f=K3,[K2]=1602,[K1]=K12,x=98,y=292,},},[K2]=1603,[K1]=K4,x=106,y=292,},f=K3,[K9]=false,[K6]=3,rets={f=K3,[K4]={[1]={f=K3,[K2]=1605,[K1]=K11,x=108,y=292,},[2]={f=K3,[K2]=1606,[K1]=K12,x=116,y=292,},},[K2]=1604,[K1]=K4,x=106,y=292,},[K2]=1589,[K1]=K7,x=10,y=292,},},x=8,y=290,},len={args={f=K3,[K4]={[1]={f=K3,[K2]=1608,[K1]=K11,x=18,y=294,},},[K2]=1609,[K1]=K4,x=25,y=294,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1611,[K1]=K12,x=27,y=294,},},[K2]=1610,[K1]=K4,x=25,y=294,},[K2]=1607,[K1]=K7,x=9,y=294,},["lower"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1613,[K1]=K11,x=20,y=295,},},[K2]=1614,[K1]=K4,x=27,y=295,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1616,[K1]=K11,x=29,y=295,},},[K2]=1615,[K1]=K4,x=27,y=295,},[K2]=1612,[K1]=K7,x=11,y=295,},["match"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1618,[K1]=K11,x=20,y=296,},[2]={f=K3,[K2]=1619,[K1]=K11,x=28,y=296,},[3]={f=K3,[K2]=1620,[K1]=K12,x=38,y=296,},},[K2]=1621,[K1]=K4,x=46,y=296,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1623,[K1]=K11,x=48,y=296,},},[K2]=1622,[K1]=K4,x=46,y=296,},[K36]="string.match",[K2]=1617,[K1]=K7,x=11,y=296,},pack={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1625,[K1]=K11,x=19,y=297,},[2]={f=K3,[K2]=1626,[K1]="any",x=27,y=297,},},[K2]=1627,[K1]=K4,x=34,y=297,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1629,[K1]=K11,x=36,y=297,},},[K2]=1628,[K1]=K4,x=34,y=297,},[K36]="string.pack",[K2]=1624,[K1]=K7,x=10,y=297,},[K[31]]={args={f=K3,[K4]={[1]={f=K3,[K2]=1631,[K1]=K11,x=23,y=298,},},[K2]=1632,[K1]=K4,x=30,y=298,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1634,[K1]=K12,x=32,y=298,},},[K2]=1633,[K1]=K4,x=30,y=298,},[K2]=1630,[K1]=K7,x=14,y=298,},rep={args={f=K3,[K4]={[1]={f=K3,[K2]=1636,[K1]=K11,x=18,y=299,},[2]={f=K3,[K2]=1637,[K1]=K12,x=26,y=299,},[3]={f=K3,[K2]=1638,[K1]=K11,x=37,y=299,},},[K2]=1639,[K1]=K4,x=44,y=299,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=1641,[K1]=K11,x=46,y=299,},},[K2]=1640,[K1]=K4,x=44,y=299,},[K2]=1635,[K1]=K7,x=9,y=299,},["reverse"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1643,[K1]=K11,x=22,y=300,},},[K2]=1644,[K1]=K4,x=29,y=300,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1646,[K1]=K11,x=31,y=300,},},[K2]=1645,[K1]=K4,x=29,y=300,},[K2]=1642,[K1]=K7,x=13,y=300,},sub={args={f=K3,[K4]={[1]={f=K3,[K2]=1648,[K1]=K11,x=18,y=301,},[2]={f=K3,[K2]=1649,[K1]=K12,x=26,y=301,},[3]={f=K3,[K2]=1650,[K1]=K12,x=37,y=301,},},[K2]=1651,[K1]=K4,x=45,y=301,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=1653,[K1]=K11,x=47,y=301,},},[K2]=1652,[K1]=K4,x=45,y=301,},[K2]=1647,[K1]=K7,x=9,y=301,},[K46]={args={f=K3,[K4]={[1]={f=K3,[K2]=1655,[K1]=K11,x=21,y=302,},[2]={f=K3,[K2]=1656,[K1]=K11,x=29,y=302,},[3]={f=K3,[K2]=1657,[K1]=K12,x=39,y=302,},},[K2]=1658,[K1]=K4,x=47,y=302,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1660,[K1]="any",x=49,y=302,},},[K2]=1659,[K1]=K4,x=47,y=302,},[K36]="string.unpack",[K2]=1654,[K1]=K7,x=12,y=302,},[K[32]]={args={f=K3,[K4]={[1]={f=K3,[K2]=1662,[K1]=K11,x=20,y=303,},},[K2]=1663,[K1]=K4,x=27,y=303,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1665,[K1]=K11,x=29,y=303,},},[K2]=1664,[K1]=K4,x=27,y=303,},[K2]=1661,[K1]=K7,x=11,y=303,},},[K2]=1495,[K1]=K37,x=1,y=279,},f=K3,[K2]=1666,[K1]=K21,x=1,y=279,},},["table"]={[K29]=true,t={[K34]=true,def={[K25]="table",f=K3,[K[20]]={pack={[1]={},[2]={[1]={text=K[33],x=42,y=322,},},},[K46]={[1]={},[2]={[1]={text=K[33],x=55,y=328,},},[3]={[1]={text=K[33],x=47,y=329,},},[4]={[1]={text=K[33],x=59,y=330,},},[5]={[1]={text=K[33],x=71,y=331,},},},},[K33]={[1]=K[34],[2]=K[35],[3]="concat",[4]="insert",[5]="move",[6]="pack",[7]=K[28],[8]="sort",[9]=K46,},[K32]={[K[35]]=T26,[K[34]]=T28,["concat"]={args={f=K3,[K4]={[1]={[K30]={f=K3,[K2]=1686,[K1]=K22,[K18]={[1]={f=K3,[K2]=1685,[K1]=K11,x=23,y=315,},[2]={f=K3,[K2]=1687,[K1]=K13,x=32,y=315,},},x=23,y=315,},f=K3,[K2]=1688,[K1]=K31,x=21,xend=39,y=315,yend=315,},[2]={f=K3,[K2]=1689,[K1]=K11,x=44,y=315,},[3]={f=K3,[K2]=1690,[K1]=K12,x=54,y=315,},[4]={f=K3,[K2]=1691,[K1]=K12,x=65,y=315,},},[K2]=1692,[K1]=K4,x=73,y=315,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1694,[K1]=K11,x=75,y=315,},},[K2]=1693,[K1]=K4,x=73,y=315,},[K2]=1684,[K1]=K7,x=12,y=315,},["insert"]={f=K3,[K2]=1712,[K1]="poly",[K18]={[1]={f=K3,t={args={f=K3,[K4]={[1]={[K30]={f=K3,[K2]=2382,[K1]=K5,[K5]="A",x=25,y=317,},f=K3,[K2]=1698,[K1]=K31,x=24,xend=26,y=317,yend=317,},[2]={f=K3,[K2]=1699,[K1]=K12,x=29,y=317,},[3]={f=K3,[K2]=2383,[K1]=K5,[K5]="A",x=38,y=317,},},[K2]=1701,[K1]=K4,x=4,y=318,},f=K3,[K9]=false,[K6]=3,rets={f=K3,[K4]={},[K2]=1702,[K1]=K4,x=39,y=317,},[K2]=1695,[K1]=K7,x=12,y=317,},[K19]={[1]={f=K3,[K10]="A",[K2]=1696,[K1]=K10,x=21,y=317,},xend=22,yend=317,},[K2]=1703,[K1]=K20,x=4,y=318,},[2]={f=K3,t={args={f=K3,[K4]={[1]={[K30]={f=K3,[K2]=2392,[K1]=K5,[K5]="A",x=25,y=318,},f=K3,[K2]=1707,[K1]=K31,x=24,xend=26,y=318,yend=318,},[2]={f=K3,[K2]=2393,[K1]=K5,[K5]="A",x=29,y=318,},},[K2]=1709,[K1]=K4,x=4,y=320,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={},[K2]=1710,[K1]=K4,x=30,y=318,},[K2]=1704,[K1]=K7,x=12,y=318,},[K19]={[1]={f=K3,[K10]="A",[K2]=1705,[K1]=K10,x=21,y=318,},xend=22,yend=318,},[K2]=1711,[K1]=K20,x=4,y=320,},},x=10,y=318,},move={f=K3,[K23]=true,t={args={f=K3,[K4]={[1]={[K30]={f=K3,[K2]=2406,[K1]=K5,[K5]="A@34",x=23,y=320,},f=K3,[K2]=2407,[K1]=K31,x=22,y=320,},[2]={f=K3,[K2]=1717,[K1]=K12,x=27,y=320,},[3]={f=K3,[K2]=1718,[K1]=K12,x=36,y=320,},[4]={f=K3,[K2]=1719,[K1]=K12,x=45,y=320,},[5]={[K30]={f=K3,[K2]=2408,[K1]=K5,[K5]="A@34",x=57,y=320,},f=K3,[K2]=2409,[K1]=K31,x=56,y=320,},},[K2]=2410,[K1]=K4,x=60,y=320,},f=K3,[K6]=4,rets={f=K3,[K4]={[1]={[K30]={f=K3,[K2]=2411,[K1]=K5,[K5]="A@34",x=63,y=320,},f=K3,[K2]=2412,[K1]=K31,x=62,y=320,},},[K2]=2413,[K1]=K4,x=60,y=320,},[K2]=2414,[K1]=K7,x=10,y=320,},[K19]={[1]={f=K3,[K10]="A@34",[K2]=2405,[K1]=K10,x=19,y=320,},},[K2]=2415,[K1]=K20,x=4,y=322,},pack={f=K3,[K29]=true,[K2]=1742,[K1]="poly",[K18]={[1]={f=K3,t={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2417,[K1]=K5,[K5]="T",x=22,y=322,},},[K2]=1730,[K1]=K4,x=27,y=322,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K17]=T26,[K16]={[1]=K[35],},[K2]=1732,[K1]=K15,[K43]={[1]={f=K3,[K2]=2418,[K1]=K5,[K5]="T",x=39,y=322,},xend=40,yend=322,},x=29,y=322,},},[K2]=1731,[K1]=K4,x=27,y=322,},[K2]=1727,[K1]=K7,x=10,y=322,},[K19]={[1]={f=K3,[K10]="T",[K2]=1728,[K1]=K10,x=19,y=322,},xend=20,yend=322,},[K2]=1734,[K1]=K20,x=4,y=323,},[2]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1736,[K1]="any",x=19,y=323,},},[K2]=1737,[K1]=K4,x=26,y=323,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,keys={f=K3,[K2]=1739,[K1]="any",x=29,y=323,},[K2]=1740,[K1]="map",[K28]={f=K3,[K2]=1741,[K1]="any",x=33,y=323,},x=28,xend=36,y=323,yend=323,},},[K2]=1738,[K1]=K4,x=26,y=323,},[K2]=1735,[K1]=K7,x=10,y=323,},},x=8,y=323,},[K[28]]={f=K3,[K23]=true,t={args={f=K3,[K4]={[1]={[K30]={f=K3,[K2]=2431,[K1]=K5,[K5]="A@36",x=25,y=325,},f=K3,[K2]=2432,[K1]=K31,x=24,y=325,},[2]={f=K3,[K2]=1747,[K1]=K12,x=31,y=325,},},[K2]=2433,[K1]=K4,x=39,y=325,},f=K3,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=2434,[K1]=K5,[K5]="A@36",x=41,y=325,},},[K2]=2435,[K1]=K4,x=39,y=325,},[K2]=2436,[K1]=K7,x=12,y=325,},[K19]={[1]={f=K3,[K10]="A@36",[K2]=2430,[K1]=K10,x=21,y=325,},},[K2]=2437,[K1]=K20,x=4,y=326,},sort={f=K3,[K23]=true,t={args={f=K3,[K4]={[1]={[K30]={f=K3,[K2]=2442,[K1]=K5,[K5]="A@37",x=23,y=326,},f=K3,[K2]=2443,[K1]=K31,x=22,y=326,},[2]={f=K3,[K17]=T28,[K16]={[1]=K[34],},[K2]=2445,[K1]=K15,[K43]={[1]={f=K3,[K2]=2444,[K1]=K5,[K5]="A@37",x=42,y=326,},},x=29,y=326,},},[K2]=2446,[K1]=K4,x=4,y=328,},f=K3,[K6]=1,rets={f=K3,[K4]={},[K2]=1759,[K1]=K4,x=44,y=326,},[K2]=2447,[K1]=K7,x=10,y=326,},[K19]={[1]={f=K3,[K10]="A@37",[K2]=2441,[K1]=K10,x=19,y=326,},},[K2]=2448,[K1]=K20,x=4,y=328,},[K46]={f=K3,[K29]=true,[K2]=1782,[K1]="poly",[K18]={[1]={f=K3,t={args={f=K3,[K4]={[1]={[K30]={f=K3,[K2]=2450,[K1]=K5,[K5]="A",x=25,y=328,},f=K3,[K2]=1764,[K1]=K31,x=24,xend=26,y=328,yend=328,},[2]={f=K3,[K2]=1765,[K1]=K13,x=31,y=328,},[3]={f=K3,[K2]=1766,[K1]=K13,x=41,y=328,},},[K2]=1767,[K1]=K4,x=48,y=328,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2451,[K1]=K5,[K5]="A",x=50,y=328,},},[K2]=1768,[K1]=K4,x=48,y=328,},[K2]=1761,[K1]=K7,x=12,y=328,},[K19]={[1]={f=K3,[K10]="A",[K2]=1762,[K1]=K10,x=21,y=328,},xend=22,yend=328,},[K2]=1770,[K1]=K20,x=4,y=329,},[2]={f=K3,t={args={f=K3,[K4]={[1]={f=K3,[K2]=1775,[K1]=K[36],[K18]={[1]={f=K3,[K2]=2462,[K1]=K5,[K5]="A1",x=30,y=329,},[2]={f=K3,[K2]=2463,[K1]=K5,[K5]="A2",x=34,y=329,},},x=29,xend=36,y=329,yend=329,},},[K2]=1777,[K1]=K4,x=38,y=329,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=2464,[K1]=K5,[K5]="A1",x=40,y=329,},[2]={f=K3,[K2]=2465,[K1]=K5,[K5]="A2",x=44,y=329,},},[K2]=1778,[K1]=K4,x=38,y=329,},[K2]=1771,[K1]=K7,x=12,y=329,},[K19]={[1]={f=K3,[K10]="A1",[K2]=1772,[K1]=K10,x=21,y=329,},[2]={f=K3,[K10]="A2",[K2]=1773,[K1]=K10,x=25,y=329,},xend=27,yend=329,},[K2]=1781,[K1]=K20,x=4,y=330,},[3]={f=K3,t={args={f=K3,[K4]={[1]={f=K3,[K2]=1788,[K1]=K[36],[K18]={[1]={f=K3,[K2]=2480,[K1]=K5,[K5]="A1",x=34,y=330,},[2]={f=K3,[K2]=2481,[K1]=K5,[K5]="A2",x=38,y=330,},[3]={f=K3,[K2]=2482,[K1]=K5,[K5]="A3",x=42,y=330,},},x=33,xend=44,y=330,yend=330,},},[K2]=1791,[K1]=K4,x=46,y=330,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=2483,[K1]=K5,[K5]="A1",x=48,y=330,},[2]={f=K3,[K2]=2484,[K1]=K5,[K5]="A2",x=52,y=330,},[3]={f=K3,[K2]=2485,[K1]=K5,[K5]="A3",x=56,y=330,},},[K2]=1792,[K1]=K4,x=46,y=330,},[K2]=1783,[K1]=K7,x=12,y=330,},[K19]={[1]={f=K3,[K10]="A1",[K2]=1784,[K1]=K10,x=21,y=330,},[2]={f=K3,[K10]="A2",[K2]=1785,[K1]=K10,x=25,y=330,},[3]={f=K3,[K10]="A3",[K2]=1786,[K1]=K10,x=29,y=330,},xend=31,yend=330,},[K2]=1796,[K1]=K20,x=4,y=331,},[4]={f=K3,t={args={f=K3,[K4]={[1]={f=K3,[K2]=1803,[K1]=K[36],[K18]={[1]={f=K3,[K2]=2504,[K1]=K5,[K5]="A1",x=38,y=331,},[2]={f=K3,[K2]=2505,[K1]=K5,[K5]="A2",x=42,y=331,},[3]={f=K3,[K2]=2506,[K1]=K5,[K5]="A3",x=46,y=331,},[4]={f=K3,[K2]=2507,[K1]=K5,[K5]="A4",x=50,y=331,},},x=37,xend=52,y=331,yend=331,},},[K2]=1807,[K1]=K4,x=54,y=331,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=2508,[K1]=K5,[K5]="A1",x=56,y=331,},[2]={f=K3,[K2]=2509,[K1]=K5,[K5]="A2",x=60,y=331,},[3]={f=K3,[K2]=2510,[K1]=K5,[K5]="A3",x=64,y=331,},[4]={f=K3,[K2]=2511,[K1]=K5,[K5]="A4",x=68,y=331,},},[K2]=1808,[K1]=K4,x=54,y=331,},[K2]=1797,[K1]=K7,x=12,y=331,},[K19]={[1]={f=K3,[K10]="A1",[K2]=1798,[K1]=K10,x=21,y=331,},[2]={f=K3,[K10]="A2",[K2]=1799,[K1]=K10,x=25,y=331,},[3]={f=K3,[K10]="A3",[K2]=1800,[K1]=K10,x=29,y=331,},[4]={f=K3,[K10]="A4",[K2]=1801,[K1]=K10,x=33,y=331,},xend=35,yend=331,},[K2]=1813,[K1]=K20,x=4,y=332,},[5]={f=K3,t={args={f=K3,[K4]={[1]={f=K3,[K2]=1821,[K1]=K[36],[K18]={[1]={f=K3,[K2]=2534,[K1]=K5,[K5]="A1",x=42,y=332,},[2]={f=K3,[K2]=2535,[K1]=K5,[K5]="A2",x=46,y=332,},[3]={f=K3,[K2]=2536,[K1]=K5,[K5]="A3",x=50,y=332,},[4]={f=K3,[K2]=2537,[K1]=K5,[K5]="A4",x=54,y=332,},[5]={f=K3,[K2]=2538,[K1]=K5,[K5]="A5",x=58,y=332,},},x=41,xend=60,y=332,yend=332,},},[K2]=1826,[K1]=K4,x=62,y=332,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=2539,[K1]=K5,[K5]="A1",x=64,y=332,},[2]={f=K3,[K2]=2540,[K1]=K5,[K5]="A2",x=68,y=332,},[3]={f=K3,[K2]=2541,[K1]=K5,[K5]="A3",x=72,y=332,},[4]={f=K3,[K2]=2542,[K1]=K5,[K5]="A4",x=76,y=332,},[5]={f=K3,[K2]=2543,[K1]=K5,[K5]="A5",x=80,y=332,},},[K2]=1827,[K1]=K4,x=62,y=332,},[K2]=1814,[K1]=K7,x=12,y=332,},[K19]={[1]={f=K3,[K10]="A1",[K2]=1815,[K1]=K10,x=21,y=332,},[2]={f=K3,[K10]="A2",[K2]=1816,[K1]=K10,x=25,y=332,},[3]={f=K3,[K10]="A3",[K2]=1817,[K1]=K10,x=29,y=332,},[4]={f=K3,[K10]="A4",[K2]=1818,[K1]=K10,x=33,y=332,},[5]={f=K3,[K10]="A5",[K2]=1819,[K1]=K10,x=37,y=332,},xend=39,yend=332,},[K2]=1833,[K1]=K20,x=1,y=333,},},x=10,y=329,},},[K2]=1667,[K1]=K37,x=1,y=306,},f=K3,[K2]=1834,[K1]=K21,x=1,y=306,},},[K35]={t={[K34]=true,def={[K25]=K35,f=K8,[K33]={},[K32]={},[K2]=7,[K1]=K[13],x=1,y=11,},f=K8,[K2]=8,[K1]=K21,x=1,y=11,},},["tonumber"]={[K27]=K26,t={f=K3,[K2]=2217,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={[1]={f=K3,[K2]=2207,[K1]="any",x=23,y=416,},},[K2]=2208,[K1]=K4,x=27,y=416,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=2210,[K1]=K13,x=29,y=416,},},[K2]=2209,[K1]=K4,x=27,y=416,},[K2]=2206,[K1]=K7,x=14,y=416,},[2]={args={f=K3,[K4]={[1]={f=K3,[K2]=2212,[K1]="any",x=23,y=417,},[2]={f=K3,[K2]=2213,[K1]=K12,x=28,y=417,},},[K2]=2214,[K1]=K4,x=36,y=417,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=2216,[K1]=K12,x=38,y=417,},},[K2]=2215,[K1]=K4,x=36,y=417,},[K2]=2211,[K1]=K7,x=14,y=417,},},x=12,y=417,},},["tostring"]={[K27]=K26,t={args={f=K3,[K4]={[1]={f=K3,[K2]=2219,[K1]="any",x=23,y=419,},},[K2]=2220,[K1]=K4,x=27,y=419,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=2222,[K1]=K11,x=29,y=419,},},[K2]=2221,[K1]=K4,x=27,y=419,},[K2]=2218,[K1]=K7,x=14,y=419,},},type={[K27]=K26,t={args={f=K3,[K4]={[1]={f=K3,[K2]=2224,[K1]="any",x=19,y=420,},},[K2]=2225,[K1]=K4,x=23,y=420,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=2227,[K1]=K11,x=25,y=420,},},[K2]=2226,[K1]=K4,x=23,y=420,},[K2]=2223,[K1]=K7,x=10,y=420,},},[K[22]]={t=T19,[K[12]]=true,},utf8={[K29]=true,t={[K34]=true,def={[K25]="utf8",f=K3,[K33]={[1]="char",[2]="charpattern",[3]="codepoint",[4]="codes",[5]="len",[6]="offset",},[K32]={char={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1837,[K1]=K13,x=19,y=336,},},[K2]=1838,[K1]=K4,x=29,y=336,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1840,[K1]=K11,x=31,y=336,},},[K2]=1839,[K1]=K4,x=29,y=336,},[K2]=1836,[K1]=K7,x=10,y=336,},["charpattern"]={f=K3,[K2]=1841,[K1]=K11,x=17,y=337,},["codepoint"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1843,[K1]=K11,x=24,y=338,},[2]={f=K3,[K2]=1844,[K1]=K13,x=34,y=338,},[3]={f=K3,[K2]=1845,[K1]=K13,x=44,y=338,},[4]={f=K3,[K2]=1846,[K1]=K24,x=54,y=338,},},[K2]=1847,[K1]=K4,x=62,y=338,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1849,[K1]=K12,x=64,y=338,},},[K2]=1848,[K1]=K4,x=62,y=338,},[K2]=1842,[K1]=K7,x=15,y=338,},["codes"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1851,[K1]=K11,x=20,y=339,},[2]={f=K3,[K2]=1852,[K1]=K24,x=30,y=339,},},[K2]=1853,[K1]=K4,x=38,y=339,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={args={f=K3,[K4]={[1]={f=K3,[K2]=1856,[K1]=K11,x=50,y=339,},[2]={f=K3,[K2]=1857,[K1]=K12,x=60,y=339,},},[K2]=1858,[K1]=K4,x=68,y=339,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1860,[K1]=K12,x=71,y=339,},[2]={f=K3,[K2]=1861,[K1]=K12,x=80,y=339,},},[K2]=1859,[K1]=K4,x=68,y=339,},[K2]=1855,[K1]=K7,x=41,y=339,},[2]={f=K3,[K2]=1862,[K1]=K11,x=90,y=339,},[3]={f=K3,[K2]=1863,[K1]=K12,x=98,y=339,},},[K2]=1854,[K1]=K4,x=38,y=339,},[K2]=1850,[K1]=K7,x=11,y=339,},len={args={f=K3,[K4]={[1]={f=K3,[K2]=1865,[K1]=K11,x=18,y=340,},[2]={f=K3,[K2]=1866,[K1]=K13,x=28,y=340,},[3]={f=K3,[K2]=1867,[K1]=K13,x=38,y=340,},[4]={f=K3,[K2]=1868,[K1]=K24,x=48,y=340,},},[K2]=1869,[K1]=K4,x=56,y=340,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1871,[K1]=K12,x=58,y=340,},[2]={f=K3,[K2]=1872,[K1]=K12,x=67,y=340,},},[K2]=1870,[K1]=K4,x=56,y=340,},[K2]=1864,[K1]=K7,x=9,y=340,},["offset"]={args={f=K3,[K4]={[1]={f=K3,[K2]=1874,[K1]=K11,x=21,y=341,},[2]={f=K3,[K2]=1875,[K1]=K13,x=29,y=341,},[3]={f=K3,[K2]=1876,[K1]=K13,x=39,y=341,},},[K2]=1877,[K1]=K4,x=46,y=341,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=1879,[K1]=K12,x=48,y=341,},},[K2]=1878,[K1]=K4,x=46,y=341,},[K2]=1873,[K1]=K7,x=12,y=341,},},[K2]=1835,[K1]=K37,x=1,y=335,},f=K3,[K2]=1880,[K1]=K21,x=1,y=335,},},["xpcall"]={[K27]=K26,[K29]=true,t={args={f=K3,[K14]=true,[K4]={[1]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2235,[K1]="any",x=30,y=422,},},[K2]=2236,[K1]=K4,x=37,y=422,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2238,[K1]="any",x=39,y=422,},},[K2]=2237,[K1]=K4,x=37,y=422,},[K2]=2234,[K1]=K7,x=21,y=422,},[2]={f=K3,[K17]={def={args={f=K3,[K4]={[1]={f=K3,[K2]=1896,[K1]="any",x=39,y=368,},},[K2]=1897,[K1]=K4,x=43,y=368,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1899,[K1]="any",x=45,y=368,},},[K2]=1898,[K1]=K4,x=43,y=368,},[K2]=1895,[K1]=K7,x=30,y=368,},f=K3,[K2]=1900,[K1]=K21,x=30,y=368,},[K16]={[1]="XpcallMsghFunction",},[K2]=2239,[K1]=K15,x=48,y=422,},[3]={f=K3,[K2]=2240,[K1]="any",x=68,y=422,},},[K2]=2241,[K1]=K4,x=75,y=422,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=2243,[K1]=K24,x=77,y=422,},[2]={f=K3,[K2]=2244,[K1]="any",x=86,y=422,},},[K2]=2242,[K1]=K4,x=75,y=422,},[K36]="xpcall",[K2]=2233,[K1]=K7,x=12,y=422,},},}
T1.def=T2
T2[K33]={[1]=K[2],[2]=K[3],[3]=K45,[4]=K[4],[5]=K[5],[6]="read",[7]="seek",[8]="setvbuf",[9]=K[6],}
T2[K32]={[K[2]]=T3,[K[3]]=T4,[K45]={args={f=K3,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K2]=982,[K1]=K15,x=20,y=154,},},[K2]=983,[K1]=K4,x=25,y=154,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=985,[K1]=K24,x=27,y=154,},[2]={f=K3,[K2]=986,[K1]=K11,x=36,y=154,},[3]={f=K3,[K2]=987,[K1]=K12,x=44,y=154,},},[K2]=984,[K1]=K4,x=25,y=154,},[K2]=981,[K1]=K7,x=11,y=154,},[K[4]]={args={f=K3,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K2]=989,[K1]=K15,x=20,y=155,},},[K2]=990,[K1]=K4,x=25,y=155,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=992,[K1]=K24,x=27,y=155,},[2]={f=K3,[K2]=993,[K1]=K11,x=36,y=155,},[3]={f=K3,[K2]=994,[K1]=K12,x=44,y=155,},},[K2]=991,[K1]=K4,x=25,y=155,},[K2]=988,[K1]=K7,x=11,y=155,},[K[5]]={f=K3,[K2]=1012,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K2]=996,[K1]=K15,x=20,y=157,},},[K2]=997,[K1]=K4,x=25,y=157,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={args={f=K3,[K4]={},[K2]=1000,[K1]=K4,x=38,y=157,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1002,[K1]=K11,x=41,y=157,},},[K2]=1001,[K1]=K4,x=38,y=157,},[K2]=999,[K1]=K7,x=28,y=157,},},[K2]=998,[K1]=K4,x=25,y=157,},[K2]=995,[K1]=K7,x=11,y=157,},[2]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K2]=1004,[K1]=K15,x=20,y=158,},[2]={f=K3,[K17]=T5,[K16]={[1]=K[7],},[K2]=1005,[K1]=K15,x=26,y=158,},},[K2]=1006,[K1]=K4,x=44,y=158,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={args={f=K3,[K4]={},[K2]=1009,[K1]=K4,x=57,y=158,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1011,[K1]=K13,x=60,y=158,},},[K2]=1010,[K1]=K4,x=57,y=158,},[K2]=1008,[K1]=K7,x=47,y=158,},},[K2]=1007,[K1]=K4,x=44,y=158,},[K2]=1003,[K1]=K7,x=11,y=158,},[3]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K2]=1014,[K1]=K15,x=20,y=159,},[2]={f=K3,[K2]=1016,[K1]=K22,[K18]={[1]={f=K3,[K2]=1015,[K1]=K13,x=27,y=159,},[2]={f=K3,[K17]=T6,[K16]={[1]=K50,},[K2]=1017,[K1]=K15,x=36,y=159,},},x=27,y=159,},},[K2]=1018,[K1]=K4,x=55,y=159,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={args={f=K3,[K4]={},[K2]=1021,[K1]=K4,x=68,y=159,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1023,[K1]=K11,x=71,y=159,},},[K2]=1022,[K1]=K4,x=68,y=159,},[K2]=1020,[K1]=K7,x=58,y=159,},},[K2]=1019,[K1]=K4,x=55,y=159,},[K2]=1013,[K1]=K7,x=11,y=159,},[4]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K2]=1025,[K1]=K15,x=20,y=160,},[2]={f=K3,[K2]=1027,[K1]=K22,[K18]={[1]={f=K3,[K2]=1026,[K1]=K13,x=27,y=160,},[2]={f=K3,[K17]=T7,[K16]={[1]=K[8],},[K2]=1028,[K1]=K15,x=36,y=160,},},x=27,y=160,},},[K2]=1029,[K1]=K4,x=49,y=160,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={args={f=K3,[K4]={},[K2]=1032,[K1]=K4,x=62,y=160,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1035,[K1]=K22,[K18]={[1]={f=K3,[K2]=1034,[K1]=K11,x=66,y=160,},[2]={f=K3,[K2]=1036,[K1]=K13,x=75,y=160,},},x=66,y=160,},},[K2]=1033,[K1]=K4,x=62,y=160,},[K2]=1031,[K1]=K7,x=52,y=160,},},[K2]=1030,[K1]=K4,x=49,y=160,},[K2]=1024,[K1]=K7,x=11,y=160,},[5]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K2]=1038,[K1]=K15,x=20,y=161,},[2]={f=K3,[K2]=1040,[K1]=K22,[K18]={[1]={f=K3,[K2]=1039,[K1]=K13,x=27,y=161,},[2]={f=K3,[K2]=1041,[K1]=K11,x=36,y=161,},},x=27,y=161,},},[K2]=1042,[K1]=K4,x=47,y=161,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={args={f=K3,[K4]={},[K2]=1045,[K1]=K4,x=60,y=161,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1047,[K1]=K11,x=63,y=161,},},[K2]=1046,[K1]=K4,x=60,y=161,},[K2]=1044,[K1]=K7,x=50,y=161,},},[K2]=1043,[K1]=K4,x=47,y=161,},[K2]=1037,[K1]=K7,x=11,y=161,},},x=9,y=158,},read={f=K3,[K2]=1059,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K2]=1049,[K1]=K15,x=19,y=163,},},[K2]=1050,[K1]=K4,x=24,y=163,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1052,[K1]=K11,x=26,y=163,},},[K2]=1051,[K1]=K4,x=24,y=163,},[K2]=1048,[K1]=K7,x=10,y=163,},[2]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K2]=1054,[K1]=K15,x=19,y=164,},[2]={f=K3,[K17]=T5,[K16]={[1]=K[7],},[K2]=1055,[K1]=K15,x=25,y=164,},},[K2]=1056,[K1]=K4,x=43,y=164,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1058,[K1]=K13,x=45,y=164,},},[K2]=1057,[K1]=K4,x=43,y=164,},[K2]=1053,[K1]=K7,x=10,y=164,},[3]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K2]=1061,[K1]=K15,x=19,y=165,},[2]={f=K3,[K2]=1063,[K1]=K22,[K18]={[1]={f=K3,[K2]=1062,[K1]=K13,x=26,y=165,},[2]={f=K3,[K17]=T6,[K16]={[1]=K50,},[K2]=1064,[K1]=K15,x=35,y=165,},},x=26,y=165,},},[K2]=1065,[K1]=K4,x=54,y=165,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1067,[K1]=K11,x=56,y=165,},},[K2]=1066,[K1]=K4,x=54,y=165,},[K2]=1060,[K1]=K7,x=10,y=165,},[4]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K2]=1069,[K1]=K15,x=19,y=166,},[2]={f=K3,[K2]=1071,[K1]=K22,[K18]={[1]={f=K3,[K2]=1070,[K1]=K13,x=26,y=166,},[2]={f=K3,[K17]=T7,[K16]={[1]=K[8],},[K2]=1072,[K1]=K15,x=35,y=166,},},x=26,y=166,},},[K2]=1073,[K1]=K4,x=48,y=166,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1076,[K1]=K22,[K18]={[1]={f=K3,[K2]=1075,[K1]=K11,x=52,y=166,},[2]={f=K3,[K2]=1077,[K1]=K13,x=61,y=166,},},x=52,y=166,},},[K2]=1074,[K1]=K4,x=48,y=166,},[K2]=1068,[K1]=K7,x=10,y=166,},[5]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K2]=1079,[K1]=K15,x=19,y=167,},[2]={f=K3,[K2]=1081,[K1]=K22,[K18]={[1]={f=K3,[K2]=1080,[K1]=K13,x=26,y=167,},[2]={f=K3,[K2]=1082,[K1]=K11,x=35,y=167,},},x=26,y=167,},},[K2]=1083,[K1]=K4,x=46,y=167,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=1085,[K1]=K11,x=49,y=167,},},[K2]=1084,[K1]=K4,x=46,y=167,},[K2]=1078,[K1]=K7,x=10,y=167,},},x=8,y=164,},seek={args={f=K3,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K2]=1087,[K1]=K15,x=19,y=169,},[2]={f=K3,[K17]=T3,[K16]={[1]=K[2],},[K2]=1088,[K1]=K15,x=27,y=169,},[3]={f=K3,[K2]=1089,[K1]=K12,x=41,y=169,},},[K2]=1090,[K1]=K4,x=49,y=169,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=1092,[K1]=K12,x=51,y=169,},[2]={f=K3,[K2]=1093,[K1]=K11,x=60,y=169,},[3]={f=K3,[K2]=1094,[K1]=K12,x=68,y=169,},},[K2]=1091,[K1]=K4,x=49,y=169,},[K2]=1086,[K1]=K7,x=10,y=169,},["setvbuf"]={args={f=K3,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K2]=1096,[K1]=K15,x=22,y=170,},[2]={f=K3,[K17]=T4,[K16]={[1]=K[3],},[K2]=1097,[K1]=K15,x=28,y=170,},[3]={f=K3,[K2]=1098,[K1]=K12,x=43,y=170,},},[K2]=1099,[K1]=K4,x=51,y=170,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=1101,[K1]=K24,x=53,y=170,},[2]={f=K3,[K2]=1102,[K1]=K11,x=62,y=170,},[3]={f=K3,[K2]=1103,[K1]=K12,x=70,y=170,},},[K2]=1100,[K1]=K4,x=51,y=170,},[K2]=1095,[K1]=K7,x=13,y=170,},[K[6]]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K2]=1105,[K1]=K15,x=20,y=172,},[2]={f=K3,[K2]=1107,[K1]=K22,[K18]={[1]={f=K3,[K2]=1106,[K1]=K11,x=27,y=172,},[2]={f=K3,[K2]=1108,[K1]=K13,x=36,y=172,},},x=27,y=172,},},[K2]=1109,[K1]=K4,x=47,y=172,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K2]=1111,[K1]=K15,x=49,y=172,},[2]={f=K3,[K2]=1112,[K1]=K11,x=55,y=172,},[3]={f=K3,[K2]=1113,[K1]=K12,x=63,y=172,},},[K2]=1110,[K1]=K4,x=47,y=172,},[K2]=1104,[K1]=K7,x=11,y=172,},}
T2[K[9]]={}
T2["meta_field_order"]={[1]="__is",[2]=K[10],}
T2["meta_fields"]={[K[10]]={args={f=K3,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K2]=1115,[K1]=K15,x=33,y=174,},},[K2]=1116,[K1]=K4,x=1,y=175,},f=K3,[K41]=true,[K9]=false,[K6]=1,rets={f=K3,[K4]={},[K2]=1117,[K1]=K4,x=37,y=174,},[K2]=1114,[K1]=K7,x=24,y=174,},["__is"]={args={f=K3,[K4]={[1]={["display_type"]=T2,f=K3,[K2]=973,[K1]="self",x=10,y=144,},},[K2]=974,[K1]=K4,x=4,y=144,},f=K3,[K41]=true,["macroexp"]={args={[1]={["argtype"]={["display_type"]=T2,f=K3,[K2]=969,[K1]="self",x=10,y=144,},f=K3,kind="argument",tk="self",x=10,y=144,},f=K3,kind="argument_list",tk="io",x=10,y=144,},exp={e1={e1={f=K3,kind="variable",tk="io",x=10,y=144,},e2={f=K3,kind="identifier",tk="type",x=13,y=144,},f=K3,kind="op",op={["arity"]=2,op=".",prec=100,x=12,y=144,},["receiver"]={f=K3,[K17]=T8,[K16]={[1]="io",},[K39]=T8,[K2]=2323,[K1]=K15,x=10,y=144,},x=12,y=144,},e2={[1]=T11,f=K3,kind="expression_list",tk="(",x=17,xend=22,y=144,yend=144,},f=K3,kind="op",op={["arity"]=2,op="@funcall",prec=100,x=17,y=144,},x=17,y=144,},f=K3,[K41]=true,kind="macroexp",[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=971,[K1]=K24,x=10,y=144,},},[K2]=970,[K1]=K4,x=10,y=144,},tk="io",x=10,xend=22,y=144,yend=144,},[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K2]=975,[K1]=K24,x=4,y=144,},},[K2]=976,[K1]=K4,x=4,y=144,},[K2]=972,[K1]=K7,x=4,y=144,},}
T3.def={[K25]=K[2],[K38]={cur=true,["end"]=true,set=true,},f=K3,[K2]=977,[K1]="enum",x=4,y=146,}
T4.def={[K25]=K[3],[K38]={full=true,line=true,no=true,},f=K3,[K2]=979,[K1]="enum",x=4,y=150,}
T5.def={[K25]=K[7],[K38]={["*n"]=true,n=true,},f=K3,[K2]=555,[K1]="enum",x=1,y=18,}
T6.def={[K25]=K50,[K38]={["*L"]=true,["*a"]=true,["*l"]=true,L=true,a=true,l=true,},f=K3,[K2]=553,[K1]="enum",x=1,y=14,}
T7.def={[K25]=K[8],[K38]={["*L"]=true,["*a"]=true,["*l"]=true,["*n"]=true,L=true,a=true,l=true,n=true,},f=K3,[K2]=557,[K1]="enum",x=1,y=22,}
T8.def={[K25]="io",f=K3,[K33]={[1]=K47,[2]=K[11],[3]=K45,[4]="input",[5]=K[4],[6]=K[5],[7]="open",[8]="output",[9]="popen",[10]="read",[11]="stderr",[12]="stdin",[13]="stdout",[14]="tmpfile",[15]="type",[16]=K[6],},[K32]={[K[11]]=T9,[K47]=T10,[K45]={args={f=K3,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K39]=T2,[K2]=824,[K1]=K15,x=22,y=114,},},[K2]=825,[K1]=K4,x=4,y=115,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={},[K2]=826,[K1]=K4,x=26,y=114,},[K2]=823,[K1]=K7,x=11,y=114,},[K[4]]={args={f=K3,[K4]={},[K2]=835,[K1]=K4,x=4,y=118,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={},[K2]=836,[K1]=K4,x=20,y=116,},[K2]=834,[K1]=K7,x=11,y=116,},["input"]={args={f=K3,[K4]={[1]={f=K3,[K2]=829,[K1]=K22,[K18]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K39]=T2,[K2]=828,[K1]=K15,x=22,y=115,},[2]={f=K3,[K2]=830,[K1]=K11,x=29,y=115,},},x=22,y=115,},},[K2]=831,[K1]=K4,x=36,y=115,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K39]=T2,[K2]=833,[K1]=K15,x=38,y=115,},},[K2]=832,[K1]=K4,x=36,y=115,},[K2]=827,[K1]=K7,x=11,y=115,},[K[5]]={f=K3,[K2]=854,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={[1]={f=K3,[K2]=838,[K1]=K11,x=22,y=118,},},[K2]=839,[K1]=K4,x=29,y=118,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={args={f=K3,[K4]={},[K2]=842,[K1]=K4,x=42,y=118,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=844,[K1]=K11,x=45,y=118,},},[K2]=843,[K1]=K4,x=42,y=118,},[K2]=841,[K1]=K7,x=32,y=118,},},[K2]=840,[K1]=K4,x=29,y=118,},[K2]=837,[K1]=K7,x=11,y=118,},[2]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=846,[K1]=K11,x=22,y=119,},[2]={f=K3,[K17]=T5,[K16]={[1]=K[7],},[K2]=847,[K1]=K15,x=30,y=119,},},[K2]=848,[K1]=K4,x=48,y=119,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={args={f=K3,[K4]={},[K2]=851,[K1]=K4,x=61,y=119,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=853,[K1]=K13,x=64,y=119,},},[K2]=852,[K1]=K4,x=61,y=119,},[K2]=850,[K1]=K7,x=51,y=119,},},[K2]=849,[K1]=K4,x=48,y=119,},[K2]=845,[K1]=K7,x=11,y=119,},[3]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=856,[K1]=K11,x=22,y=120,},[2]={f=K3,[K2]=858,[K1]=K22,[K18]={[1]={f=K3,[K2]=857,[K1]=K13,x=31,y=120,},[2]={f=K3,[K17]=T6,[K16]={[1]=K50,},[K2]=859,[K1]=K15,x=40,y=120,},},x=31,y=120,},},[K2]=860,[K1]=K4,x=59,y=120,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={args={f=K3,[K4]={},[K2]=863,[K1]=K4,x=72,y=120,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=865,[K1]=K11,x=75,y=120,},},[K2]=864,[K1]=K4,x=72,y=120,},[K2]=862,[K1]=K7,x=62,y=120,},},[K2]=861,[K1]=K4,x=59,y=120,},[K2]=855,[K1]=K7,x=11,y=120,},[4]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=867,[K1]=K11,x=22,y=121,},[2]={f=K3,[K2]=869,[K1]=K22,[K18]={[1]={f=K3,[K2]=868,[K1]=K13,x=31,y=121,},[2]={f=K3,[K17]=T7,[K16]={[1]=K[8],},[K2]=870,[K1]=K15,x=40,y=121,},},x=31,y=121,},},[K2]=871,[K1]=K4,x=53,y=121,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={args={f=K3,[K4]={},[K2]=874,[K1]=K4,x=66,y=121,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=877,[K1]=K22,[K18]={[1]={f=K3,[K2]=876,[K1]=K11,x=70,y=121,},[2]={f=K3,[K2]=878,[K1]=K13,x=79,y=121,},},x=70,y=121,},},[K2]=875,[K1]=K4,x=66,y=121,},[K2]=873,[K1]=K7,x=56,y=121,},},[K2]=872,[K1]=K4,x=53,y=121,},[K2]=866,[K1]=K7,x=11,y=121,},[5]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=880,[K1]=K11,x=22,y=122,},[2]={f=K3,[K2]=882,[K1]=K22,[K18]={[1]={f=K3,[K2]=881,[K1]=K13,x=31,y=122,},[2]={f=K3,[K2]=883,[K1]=K11,x=40,y=122,},},x=31,y=122,},},[K2]=884,[K1]=K4,x=51,y=122,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={args={f=K3,[K4]={},[K2]=887,[K1]=K4,x=64,y=122,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=889,[K1]=K11,x=67,y=122,},},[K2]=888,[K1]=K4,x=64,y=122,},[K2]=886,[K1]=K7,x=54,y=122,},},[K2]=885,[K1]=K4,x=51,y=122,},[K2]=879,[K1]=K7,x=11,y=122,},},x=9,y=119,},open={args={f=K3,[K4]={[1]={f=K3,[K2]=891,[K1]=K11,x=19,y=124,},[2]={f=K3,[K17]=T10,[K16]={[1]=K47,},[K2]=892,[K1]=K15,x=29,y=124,},},[K2]=893,[K1]=K4,x=38,y=124,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K39]=T2,[K2]=895,[K1]=K15,x=40,y=124,},[2]={f=K3,[K2]=896,[K1]=K11,x=46,y=124,},[3]={f=K3,[K2]=897,[K1]=K12,x=54,y=124,},},[K2]=894,[K1]=K4,x=38,y=124,},[K2]=890,[K1]=K7,x=10,y=124,},["output"]={args={f=K3,[K4]={[1]={f=K3,[K2]=900,[K1]=K22,[K18]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K39]=T2,[K2]=899,[K1]=K15,x=23,y=125,},[2]={f=K3,[K2]=901,[K1]=K11,x=30,y=125,},},x=23,y=125,},},[K2]=902,[K1]=K4,x=37,y=125,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K39]=T2,[K2]=904,[K1]=K15,x=39,y=125,},},[K2]=903,[K1]=K4,x=37,y=125,},[K2]=898,[K1]=K7,x=12,y=125,},["popen"]={args={f=K3,[K4]={[1]={f=K3,[K2]=906,[K1]=K11,x=20,y=126,},[2]={f=K3,[K17]=T10,[K16]={[1]=K47,},[K2]=907,[K1]=K15,x=30,y=126,},},[K2]=908,[K1]=K4,x=39,y=126,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K39]=T2,[K2]=910,[K1]=K15,x=41,y=126,},[2]={f=K3,[K2]=911,[K1]=K11,x=47,y=126,},},[K2]=909,[K1]=K4,x=39,y=126,},[K2]=905,[K1]=K7,x=11,y=126,},read={f=K3,[K2]=921,[K1]="poly",[K18]={[1]={args={f=K3,[K4]={},[K2]=913,[K1]=K4,x=20,y=128,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=915,[K1]=K11,x=22,y=128,},},[K2]=914,[K1]=K4,x=20,y=128,},[K2]=912,[K1]=K7,x=10,y=128,},[2]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K17]=T5,[K16]={[1]=K[7],},[K2]=917,[K1]=K15,x=19,y=129,},},[K2]=918,[K1]=K4,x=37,y=129,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=920,[K1]=K13,x=39,y=129,},},[K2]=919,[K1]=K4,x=37,y=129,},[K2]=916,[K1]=K7,x=10,y=129,},[3]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=924,[K1]=K22,[K18]={[1]={f=K3,[K2]=923,[K1]=K13,x=20,y=130,},[2]={f=K3,[K17]=T6,[K16]={[1]=K50,},[K2]=925,[K1]=K15,x=29,y=130,},},x=20,y=130,},},[K2]=926,[K1]=K4,x=48,y=130,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=928,[K1]=K11,x=50,y=130,},},[K2]=927,[K1]=K4,x=48,y=130,},[K2]=922,[K1]=K7,x=10,y=130,},[4]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=931,[K1]=K22,[K18]={[1]={f=K3,[K2]=930,[K1]=K13,x=20,y=131,},[2]={f=K3,[K17]=T7,[K16]={[1]=K[8],},[K2]=932,[K1]=K15,x=29,y=131,},},x=20,y=131,},},[K2]=933,[K1]=K4,x=42,y=131,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=936,[K1]=K22,[K18]={[1]={f=K3,[K2]=935,[K1]=K11,x=46,y=131,},[2]={f=K3,[K2]=937,[K1]=K13,x=55,y=131,},},x=46,y=131,},},[K2]=934,[K1]=K4,x=42,y=131,},[K2]=929,[K1]=K7,x=10,y=131,},[5]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=940,[K1]=K22,[K18]={[1]={f=K3,[K2]=939,[K1]=K13,x=20,y=132,},[2]={f=K3,[K2]=941,[K1]=K11,x=29,y=132,},},x=20,y=132,},},[K2]=942,[K1]=K4,x=40,y=132,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=944,[K1]=K11,x=43,y=132,},},[K2]=943,[K1]=K4,x=40,y=132,},[K2]=938,[K1]=K7,x=10,y=132,},},x=8,y=129,},["stderr"]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K39]=T2,[K2]=945,[K1]=K15,x=12,y=134,},["stdin"]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K39]=T2,[K2]=946,[K1]=K15,x=11,y=135,},["stdout"]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K39]=T2,[K2]=947,[K1]=K15,x=12,y=136,},["tmpfile"]={args={f=K3,[K4]={},[K2]=949,[K1]=K4,x=23,y=137,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K39]=T2,[K2]=951,[K1]=K15,x=25,y=137,},},[K2]=950,[K1]=K4,x=23,y=137,},[K2]=948,[K1]=K7,x=13,y=137,},type={args={f=K3,[K4]={[1]={f=K3,[K2]=953,[K1]="any",x=19,y=138,},},[K2]=954,[K1]=K4,x=23,y=138,},f=K3,[K9]=false,[K6]=1,rets={f=K3,[K4]={[1]={f=K3,[K17]=T9,[K16]={[1]=K[11],},[K2]=956,[K1]=K15,x=25,y=138,},},[K2]=955,[K1]=K4,x=23,y=138,},[K2]=952,[K1]=K7,x=10,y=138,},[K[6]]={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=959,[K1]=K22,[K18]={[1]={f=K3,[K2]=958,[K1]=K11,x=21,y=139,},[2]={f=K3,[K2]=960,[K1]=K13,x=30,y=139,},},x=21,y=139,},},[K2]=961,[K1]=K4,x=41,y=139,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K17]=T1,[K16]={[1]="FILE",},[K39]=T2,[K2]=963,[K1]=K15,x=43,y=139,},[2]={f=K3,[K2]=964,[K1]=K11,x=49,y=139,},[3]={f=K3,[K2]=965,[K1]=K12,x=57,y=139,},},[K2]=962,[K1]=K4,x=41,y=139,},[K2]=957,[K1]=K7,x=11,y=139,},},[K2]=818,[K1]=K37,x=1,y=101,}
T9.def={[K25]=K[11],[K38]={["closed file"]=true,file=true,},f=K3,[K2]=821,[K1]="enum",x=4,y=109,}
T10.def={[K25]=K47,[K38]={["*a"]=true,["*a+"]=true,["*a+b"]=true,["*ab"]=true,["*r"]=true,["*r+"]=true,["*r+b"]=true,["*rb"]=true,["*w"]=true,["*w+"]=true,["*w+b"]=true,["*wb"]=true,a=true,["a+"]=true,["a+b"]=true,ab=true,r=true,["r+"]=true,["r+b"]=true,rb=true,w=true,["w+"]=true,["w+b"]=true,wb=true,},f=K3,[K2]=819,[K1]="enum",x=4,y=102,}
T11["expected"]={f=K3,["inferred_at"]=T11,[K2]=2325,[K1]="any",x=18,y=144,}
T12.def={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=561,[K1]="any",x=29,y=27,},},[K2]=562,[K1]=K4,x=36,y=27,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=564,[K1]="any",x=38,y=27,},},[K2]=563,[K1]=K4,x=36,y=27,},[K2]=560,[K1]=K7,x=20,y=27,}
T13.def={args={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=641,[K1]="any",x=32,y=65,},},[K2]=642,[K1]=K4,x=39,y=65,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K14]=true,[K4]={[1]={f=K3,[K2]=644,[K1]="any",x=40,y=65,},},[K2]=643,[K1]=K4,x=39,y=65,},[K2]=640,[K1]=K7,x=23,y=65,}
T14.def={[K25]=K49,f=K3,[K[20]]={[K[19]]={[1]={[1]={text="-- TODO: what should compat be for these? (5.4+)",x=26,y=55,},},},},[K33]={[1]="name",[2]="namewhat",[3]="source",[4]="short_src",[5]="linedefined",[6]="lastlinedefined",[7]="what",[8]="currentline",[9]="istailcall",[10]="nups",[11]="nparams",[12]="isvararg",[13]="func",[14]="activelines",[15]="ftransfer",[16]=K[19],},[K32]={["activelines"]={f=K3,keys={f=K3,[K2]=626,[K1]=K12,x=21,y=54,},[K2]=627,[K1]="map",[K28]={f=K3,[K2]=628,[K1]=K24,x=29,y=54,},x=20,xend=36,y=54,yend=54,},["currentline"]={f=K3,[K2]=620,[K1]=K12,x=20,y=48,},["ftransfer"]={f=K3,[K2]=629,[K1]=K12,x=18,y=55,},func={f=K3,[K2]=625,[K1]="any",x=13,y=53,},["istailcall"]={f=K3,[K2]=621,[K1]=K24,x=19,y=49,},["isvararg"]={f=K3,[K2]=624,[K1]=K24,x=17,y=52,},["lastlinedefined"]={f=K3,[K2]=618,[K1]=K12,x=24,y=46,},["linedefined"]={f=K3,[K2]=617,[K1]=K12,x=20,y=45,},name={f=K3,[K2]=613,[K1]=K11,x=13,y=41,},["namewhat"]={f=K3,[K2]=614,[K1]=K11,x=17,y=42,},["nparams"]={f=K3,[K2]=623,[K1]=K12,x=16,y=51,},[K[19]]={f=K3,[K2]=630,[K1]=K12,x=18,y=56,},nups={f=K3,[K2]=622,[K1]=K12,x=13,y=50,},["short_src"]={f=K3,[K2]=616,[K1]=K11,x=18,y=44,},["source"]={f=K3,[K2]=615,[K1]=K11,x=15,y=43,},what={f=K3,[K2]=619,[K1]=K11,x=13,y=47,},},[K2]=612,[K1]=K37,x=4,y=40,}
T15.def={[K25]=K[16],[K38]={call=true,["count"]=true,line=true,["return"]=true,["tail call"]=true,},f=K3,[K2]=632,[K1]="enum",x=4,y=59,}
T16.def={args={f=K3,[K4]={[1]={f=K3,[K17]=T15,[K16]={[1]=K[16],},[K2]=635,[K1]=K15,x=33,y=63,},[2]={f=K3,[K2]=636,[K1]=K12,x=44,y=63,},},[K2]=637,[K1]=K4,x=4,y=65,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={},[K2]=638,[K1]=K4,x=51,y=63,},[K2]=634,[K1]=K7,x=24,y=63,}
T17.def={f=K8,t={[K25]=K44,f=K8,[K[20]]={[K[21]]={[1]={[1]={text="--[[FIXME: function | table | anything with an __index metamethod]]",x=17,y=29,},},},},[K33]={[1]="Mode",[2]="__call",[3]="__mode",[4]="__name",[5]="__tostring",[6]="__pairs",[7]="__index",[8]=K[21],[9]="__gc",[10]=K[10],[11]="__add",[12]="__sub",[13]="__mul",[14]="__div",[15]="__idiv",[16]="__mod",[17]="__pow",[18]="__band",[19]="__bor",[20]="__bxor",[21]="__shl",[22]="__shr",[23]="__concat",[24]="__len",[25]="__unm",[26]="__bnot",[27]="__eq",[28]="__lt",[29]="__le",},[K32]={Mode=T18,["__add"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=263,[K1]=K5,[K5]="A@3",x=29,y=35,},[2]={f=K8,[K2]=264,[K1]=K5,[K5]="B@3",x=32,y=35,},},[K2]=265,[K1]=K4,x=34,y=35,},f=K8,[K6]=2,rets={f=K8,[K4]={[1]={f=K8,[K2]=266,[K1]=K5,[K5]="C@3",x=36,y=35,},},[K2]=267,[K1]=K4,x=34,y=35,},[K2]=268,[K1]=K7,x=11,y=35,},[K19]={[1]={f=K8,[K10]="A@3",[K2]=260,[K1]=K10,x=20,y=35,},[2]={f=K8,[K10]="B@3",[K2]=261,[K1]=K10,x=23,y=35,},[3]={f=K8,[K10]="C@3",[K2]=262,[K1]=K10,x=26,y=35,},},[K2]=269,[K1]=K20,x=4,y=36,},["__band"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=375,[K1]=K5,[K5]="A@10",x=30,y=42,},[2]={f=K8,[K2]=376,[K1]=K5,[K5]="B@10",x=33,y=42,},},[K2]=377,[K1]=K4,x=35,y=42,},f=K8,[K6]=2,rets={f=K8,[K4]={[1]={f=K8,[K2]=378,[K1]=K5,[K5]="C@10",x=37,y=42,},},[K2]=379,[K1]=K4,x=35,y=42,},[K2]=380,[K1]=K7,x=12,y=42,},[K19]={[1]={f=K8,[K10]="A@10",[K2]=372,[K1]=K10,x=21,y=42,},[2]={f=K8,[K10]="B@10",[K2]=373,[K1]=K10,x=24,y=42,},[3]={f=K8,[K10]="C@10",[K2]=374,[K1]=K10,x=27,y=42,},},[K2]=381,[K1]=K20,x=4,y=43,},["__bnot"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=479,[K1]=K5,[K5]="T",x=24,y=51,},},[K2]=198,[K1]=K4,x=26,y=51,},f=K8,[K6]=1,rets={f=K8,[K4]={[1]={f=K8,[K2]=482,[K1]=K5,[K5]="A@18",x=28,y=51,},},[K2]=483,[K1]=K4,x=26,y=51,},[K2]=484,[K1]=K7,x=12,y=51,},[K19]={[1]={f=K8,[K10]="A@18",[K2]=481,[K1]=K10,x=21,y=51,},},[K2]=485,[K1]=K20,x=4,y=53,},["__bor"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=391,[K1]=K5,[K5]="A@11",x=29,y=43,},[2]={f=K8,[K2]=392,[K1]=K5,[K5]="B@11",x=32,y=43,},},[K2]=393,[K1]=K4,x=34,y=43,},f=K8,[K6]=2,rets={f=K8,[K4]={[1]={f=K8,[K2]=394,[K1]=K5,[K5]="C@11",x=36,y=43,},},[K2]=395,[K1]=K4,x=34,y=43,},[K2]=396,[K1]=K7,x=11,y=43,},[K19]={[1]={f=K8,[K10]="A@11",[K2]=388,[K1]=K10,x=20,y=43,},[2]={f=K8,[K10]="B@11",[K2]=389,[K1]=K10,x=23,y=43,},[3]={f=K8,[K10]="C@11",[K2]=390,[K1]=K10,x=26,y=43,},},[K2]=397,[K1]=K20,x=4,y=44,},["__bxor"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=407,[K1]=K5,[K5]="A@12",x=30,y=44,},[2]={f=K8,[K2]=408,[K1]=K5,[K5]="B@12",x=33,y=44,},},[K2]=409,[K1]=K4,x=35,y=44,},f=K8,[K6]=2,rets={f=K8,[K4]={[1]={f=K8,[K2]=410,[K1]=K5,[K5]="C@12",x=37,y=44,},},[K2]=411,[K1]=K4,x=35,y=44,},[K2]=412,[K1]=K7,x=12,y=44,},[K19]={[1]={f=K8,[K10]="A@12",[K2]=404,[K1]=K10,x=21,y=44,},[2]={f=K8,[K10]="B@12",[K2]=405,[K1]=K10,x=24,y=44,},[3]={f=K8,[K10]="C@12",[K2]=406,[K1]=K10,x=27,y=44,},},[K2]=413,[K1]=K20,x=4,y=45,},["__call"]={args={f=K8,[K14]=true,[K4]={[1]={f=K8,[K2]=236,[K1]=K5,[K5]="T",x=21,y=23,},[2]={f=K8,[K2]=18,[K1]="any",x=24,y=23,},},[K2]=19,[K1]=K4,x=31,y=23,},f=K8,[K9]=false,[K6]=1,rets={f=K8,[K14]=true,[K4]={[1]={f=K8,[K2]=21,[K1]="any",x=33,y=23,},},[K2]=20,[K1]=K4,x=31,y=23,},[K2]=16,[K1]=K7,x=12,y=23,},[K[10]]={args={f=K8,[K4]={[1]={f=K8,[K2]=253,[K1]=K5,[K5]="T",x=22,y=33,},},[K2]=49,[K1]=K4,x=4,y=35,},f=K8,[K9]=false,[K6]=1,rets={f=K8,[K4]={},[K2]=50,[K1]=K4,x=23,y=33,},[K2]=47,[K1]=K7,x=13,y=33,},["__concat"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=455,[K1]=K5,[K5]="A@15",x=32,y=47,},[2]={f=K8,[K2]=456,[K1]=K5,[K5]="B@15",x=35,y=47,},},[K2]=457,[K1]=K4,x=37,y=47,},f=K8,[K6]=2,rets={f=K8,[K4]={[1]={f=K8,[K2]=458,[K1]=K5,[K5]="C@15",x=39,y=47,},},[K2]=459,[K1]=K4,x=37,y=47,},[K2]=460,[K1]=K7,x=14,y=47,},[K19]={[1]={f=K8,[K10]="A@15",[K2]=452,[K1]=K10,x=23,y=47,},[2]={f=K8,[K10]="B@15",[K2]=453,[K1]=K10,x=26,y=47,},[3]={f=K8,[K10]="C@15",[K2]=454,[K1]=K10,x=29,y=47,},},[K2]=461,[K1]=K20,x=4,y=49,},["__div"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=311,[K1]=K5,[K5]="A@6",x=29,y=38,},[2]={f=K8,[K2]=312,[K1]=K5,[K5]="B@6",x=32,y=38,},},[K2]=313,[K1]=K4,x=34,y=38,},f=K8,[K6]=2,rets={f=K8,[K4]={[1]={f=K8,[K2]=314,[K1]=K5,[K5]="C@6",x=36,y=38,},},[K2]=315,[K1]=K4,x=34,y=38,},[K2]=316,[K1]=K7,x=11,y=38,},[K19]={[1]={f=K8,[K10]="A@6",[K2]=308,[K1]=K10,x=20,y=38,},[2]={f=K8,[K10]="B@6",[K2]=309,[K1]=K10,x=23,y=38,},[3]={f=K8,[K10]="C@6",[K2]=310,[K1]=K10,x=26,y=38,},},[K2]=317,[K1]=K20,x=4,y=39,},["__eq"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=492,[K1]=K5,[K5]="A@19",x=25,y=53,},[2]={f=K8,[K2]=493,[K1]=K5,[K5]="B@19",x=28,y=53,},},[K2]=494,[K1]=K4,x=30,y=53,},f=K8,[K6]=2,rets={f=K8,[K4]={[1]={f=K8,[K2]=209,[K1]=K24,x=32,y=53,},},[K2]=208,[K1]=K4,x=30,y=53,},[K2]=495,[K1]=K7,x=10,y=53,},[K19]={[1]={f=K8,[K10]="A@19",[K2]=490,[K1]=K10,x=19,y=53,},[2]={f=K8,[K10]="B@19",[K2]=491,[K1]=K10,x=22,y=53,},},[K2]=496,[K1]=K20,x=4,y=54,},["__gc"]={args={f=K8,[K4]={[1]={f=K8,[K2]=252,[K1]=K5,[K5]="T",x=19,y=32,},},[K2]=45,[K1]=K4,x=4,y=33,},f=K8,[K9]=false,[K6]=1,rets={f=K8,[K4]={},[K2]=46,[K1]=K4,x=20,y=32,},[K2]=43,[K1]=K7,x=10,y=32,},["__idiv"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=327,[K1]=K5,[K5]="A@7",x=30,y=39,},[2]={f=K8,[K2]=328,[K1]=K5,[K5]="B@7",x=33,y=39,},},[K2]=329,[K1]=K4,x=35,y=39,},f=K8,[K6]=2,rets={f=K8,[K4]={[1]={f=K8,[K2]=330,[K1]=K5,[K5]="C@7",x=37,y=39,},},[K2]=331,[K1]=K4,x=35,y=39,},[K2]=332,[K1]=K7,x=12,y=39,},[K19]={[1]={f=K8,[K10]="A@7",[K2]=324,[K1]=K10,x=21,y=39,},[2]={f=K8,[K10]="B@7",[K2]=325,[K1]=K10,x=24,y=39,},[3]={f=K8,[K10]="C@7",[K2]=326,[K1]=K10,x=27,y=39,},},[K2]=333,[K1]=K20,x=4,y=40,},["__index"]={f=K8,[K2]=41,[K1]="any",x=13,y=29,},["__le"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=514,[K1]=K5,[K5]="A@21",x=25,y=55,},[2]={f=K8,[K2]=515,[K1]=K5,[K5]="B@21",x=28,y=55,},},[K2]=516,[K1]=K4,x=30,y=55,},f=K8,[K6]=2,rets={f=K8,[K4]={[1]={f=K8,[K2]=227,[K1]=K24,x=32,y=55,},},[K2]=226,[K1]=K4,x=30,y=55,},[K2]=517,[K1]=K7,x=10,y=55,},[K19]={[1]={f=K8,[K10]="A@21",[K2]=512,[K1]=K10,x=19,y=55,},[2]={f=K8,[K10]="B@21",[K2]=513,[K1]=K10,x=22,y=55,},},[K2]=518,[K1]=K20,x=1,y=56,},["__len"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=463,[K1]=K5,[K5]="T",x=23,y=49,},},[K2]=184,[K1]=K4,x=25,y=49,},f=K8,[K6]=1,rets={f=K8,[K4]={[1]={f=K8,[K2]=466,[K1]=K5,[K5]="A@16",x=27,y=49,},},[K2]=467,[K1]=K4,x=25,y=49,},[K2]=468,[K1]=K7,x=11,y=49,},[K19]={[1]={f=K8,[K10]="A@16",[K2]=465,[K1]=K10,x=20,y=49,},},[K2]=469,[K1]=K20,x=4,y=50,},["__lt"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=503,[K1]=K5,[K5]="A@20",x=25,y=54,},[2]={f=K8,[K2]=504,[K1]=K5,[K5]="B@20",x=28,y=54,},},[K2]=505,[K1]=K4,x=30,y=54,},f=K8,[K6]=2,rets={f=K8,[K4]={[1]={f=K8,[K2]=218,[K1]=K24,x=32,y=54,},},[K2]=217,[K1]=K4,x=30,y=54,},[K2]=506,[K1]=K7,x=10,y=54,},[K19]={[1]={f=K8,[K10]="A@20",[K2]=501,[K1]=K10,x=19,y=54,},[2]={f=K8,[K10]="B@20",[K2]=502,[K1]=K10,x=22,y=54,},},[K2]=507,[K1]=K20,x=4,y=55,},["__mod"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=343,[K1]=K5,[K5]="A@8",x=29,y=40,},[2]={f=K8,[K2]=344,[K1]=K5,[K5]="B@8",x=32,y=40,},},[K2]=345,[K1]=K4,x=34,y=40,},f=K8,[K6]=2,rets={f=K8,[K4]={[1]={f=K8,[K2]=346,[K1]=K5,[K5]="C@8",x=36,y=40,},},[K2]=347,[K1]=K4,x=34,y=40,},[K2]=348,[K1]=K7,x=11,y=40,},[K19]={[1]={f=K8,[K10]="A@8",[K2]=340,[K1]=K10,x=20,y=40,},[2]={f=K8,[K10]="B@8",[K2]=341,[K1]=K10,x=23,y=40,},[3]={f=K8,[K10]="C@8",[K2]=342,[K1]=K10,x=26,y=40,},},[K2]=349,[K1]=K20,x=4,y=41,},["__mode"]={f=K8,[K17]=T18,[K16]={[1]="Mode",},[K2]=22,[K1]=K15,x=12,y=24,},["__mul"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=295,[K1]=K5,[K5]="A@5",x=29,y=37,},[2]={f=K8,[K2]=296,[K1]=K5,[K5]="B@5",x=32,y=37,},},[K2]=297,[K1]=K4,x=34,y=37,},f=K8,[K6]=2,rets={f=K8,[K4]={[1]={f=K8,[K2]=298,[K1]=K5,[K5]="C@5",x=36,y=37,},},[K2]=299,[K1]=K4,x=34,y=37,},[K2]=300,[K1]=K7,x=11,y=37,},[K19]={[1]={f=K8,[K10]="A@5",[K2]=292,[K1]=K10,x=20,y=37,},[2]={f=K8,[K10]="B@5",[K2]=293,[K1]=K10,x=23,y=37,},[3]={f=K8,[K10]="C@5",[K2]=294,[K1]=K10,x=26,y=37,},},[K2]=301,[K1]=K20,x=4,y=38,},["__name"]={f=K8,[K2]=23,[K1]=K11,x=12,y=25,},[K[21]]={f=K8,[K2]=42,[K1]="any",x=16,y=30,},["__pairs"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=240,[K1]=K5,[K5]="T",x=28,y=27,},},[K2]=33,[K1]=K4,x=30,y=27,},f=K8,[K6]=1,rets={f=K8,[K4]={[1]={args={f=K8,[K4]={},[K2]=36,[K1]=K4,x=42,y=27,},f=K8,[K6]=0,rets={f=K8,[K4]={[1]={f=K8,[K2]=245,[K1]=K5,[K5]="K@2",x=45,y=27,},[2]={f=K8,[K2]=246,[K1]=K5,[K5]="V@2",x=48,y=27,},},[K2]=247,[K1]=K4,x=42,y=27,},[K2]=248,[K1]=K7,x=32,y=27,},},[K2]=249,[K1]=K4,x=30,y=27,},[K2]=250,[K1]=K7,x=13,y=27,},[K19]={[1]={f=K8,[K10]="K@2",[K2]=243,[K1]=K10,x=22,y=27,},[2]={f=K8,[K10]="V@2",[K2]=244,[K1]=K10,x=25,y=27,},},[K2]=251,[K1]=K20,x=4,y=29,},["__pow"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=359,[K1]=K5,[K5]="A@9",x=29,y=41,},[2]={f=K8,[K2]=360,[K1]=K5,[K5]="B@9",x=32,y=41,},},[K2]=361,[K1]=K4,x=34,y=41,},f=K8,[K6]=2,rets={f=K8,[K4]={[1]={f=K8,[K2]=362,[K1]=K5,[K5]="C@9",x=36,y=41,},},[K2]=363,[K1]=K4,x=34,y=41,},[K2]=364,[K1]=K7,x=11,y=41,},[K19]={[1]={f=K8,[K10]="A@9",[K2]=356,[K1]=K10,x=20,y=41,},[2]={f=K8,[K10]="B@9",[K2]=357,[K1]=K10,x=23,y=41,},[3]={f=K8,[K10]="C@9",[K2]=358,[K1]=K10,x=26,y=41,},},[K2]=365,[K1]=K20,x=4,y=42,},["__shl"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=423,[K1]=K5,[K5]="A@13",x=29,y=45,},[2]={f=K8,[K2]=424,[K1]=K5,[K5]="B@13",x=32,y=45,},},[K2]=425,[K1]=K4,x=34,y=45,},f=K8,[K6]=2,rets={f=K8,[K4]={[1]={f=K8,[K2]=426,[K1]=K5,[K5]="C@13",x=36,y=45,},},[K2]=427,[K1]=K4,x=34,y=45,},[K2]=428,[K1]=K7,x=11,y=45,},[K19]={[1]={f=K8,[K10]="A@13",[K2]=420,[K1]=K10,x=20,y=45,},[2]={f=K8,[K10]="B@13",[K2]=421,[K1]=K10,x=23,y=45,},[3]={f=K8,[K10]="C@13",[K2]=422,[K1]=K10,x=26,y=45,},},[K2]=429,[K1]=K20,x=4,y=46,},["__shr"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=439,[K1]=K5,[K5]="A@14",x=29,y=46,},[2]={f=K8,[K2]=440,[K1]=K5,[K5]="B@14",x=32,y=46,},},[K2]=441,[K1]=K4,x=34,y=46,},f=K8,[K6]=2,rets={f=K8,[K4]={[1]={f=K8,[K2]=442,[K1]=K5,[K5]="C@14",x=36,y=46,},},[K2]=443,[K1]=K4,x=34,y=46,},[K2]=444,[K1]=K7,x=11,y=46,},[K19]={[1]={f=K8,[K10]="A@14",[K2]=436,[K1]=K10,x=20,y=46,},[2]={f=K8,[K10]="B@14",[K2]=437,[K1]=K10,x=23,y=46,},[3]={f=K8,[K10]="C@14",[K2]=438,[K1]=K10,x=26,y=46,},},[K2]=445,[K1]=K20,x=4,y=47,},["__sub"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=279,[K1]=K5,[K5]="A@4",x=29,y=36,},[2]={f=K8,[K2]=280,[K1]=K5,[K5]="B@4",x=32,y=36,},},[K2]=281,[K1]=K4,x=34,y=36,},f=K8,[K6]=2,rets={f=K8,[K4]={[1]={f=K8,[K2]=282,[K1]=K5,[K5]="C@4",x=36,y=36,},},[K2]=283,[K1]=K4,x=34,y=36,},[K2]=284,[K1]=K7,x=11,y=36,},[K19]={[1]={f=K8,[K10]="A@4",[K2]=276,[K1]=K10,x=20,y=36,},[2]={f=K8,[K10]="B@4",[K2]=277,[K1]=K10,x=23,y=36,},[3]={f=K8,[K10]="C@4",[K2]=278,[K1]=K10,x=26,y=36,},},[K2]=285,[K1]=K20,x=4,y=37,},["__tostring"]={args={f=K8,[K4]={[1]={f=K8,[K2]=237,[K1]=K5,[K5]="T",x=25,y=26,},},[K2]=26,[K1]=K4,x=27,y=26,},f=K8,[K9]=false,[K6]=1,rets={f=K8,[K4]={[1]={f=K8,[K2]=28,[K1]=K11,x=29,y=26,},},[K2]=27,[K1]=K4,x=27,y=26,},[K2]=24,[K1]=K7,x=16,y=26,},["__unm"]={f=K8,[K23]=true,t={args={f=K8,[K4]={[1]={f=K8,[K2]=471,[K1]=K5,[K5]="T",x=23,y=50,},},[K2]=191,[K1]=K4,x=25,y=50,},f=K8,[K6]=1,rets={f=K8,[K4]={[1]={f=K8,[K2]=474,[K1]=K5,[K5]="A@17",x=27,y=50,},},[K2]=475,[K1]=K4,x=25,y=50,},[K2]=476,[K1]=K7,x=11,y=50,},[K19]={[1]={f=K8,[K10]="A@17",[K2]=473,[K1]=K10,x=20,y=50,},},[K2]=477,[K1]=K20,x=4,y=51,},},[K2]=13,[K1]=K37,x=1,y=18,},[K19]={[1]={f=K8,[K10]="T",[K2]=12,[K1]=K10,x=25,y=18,},xend=26,yend=18,},[K2]=229,[K1]=K20,x=1,y=18,}
T18.def={[K25]="Mode",[K38]={k=true,kv=true,v=true,},f=K8,[K2]=14,[K1]="enum",x=4,y=19,}
T19.def={[K25]=K[22],f=K8,[K33]={},[K32]={},[K[9]]={},[K[1]]=true,["is_userdata"]=true,[K2]=9,[K1]=K[13],x=1,y=14,}
T20.def={args={f=K3,[K4]={},[K2]=1889,[K1]=K4,x=34,y=362,},f=K3,[K9]=false,[K6]=0,rets={f=K3,[K4]={[1]={f=K3,[K2]=1891,[K1]=K11,x=36,y=362,},},[K2]=1890,[K1]=K4,x=34,y=362,},[K2]=1888,[K1]=K7,x=24,y=362,}
T21.def={[K25]=K[23],[K38]={b=true,bt=true,t=true,},f=K3,[K2]=1893,[K1]="enum",x=4,y=364,}
T22.def={f=K3,[K2]=1121,[K1]=K22,[K18]={[1]={f=K3,[K2]=1120,[K1]=K13,x=19,y=178,},[2]={f=K3,[K2]=1122,[K1]=K12,x=28,y=178,},},x=19,y=178,}
T23[K17]=T22
T23[K16]={[1]=K[24],}
T24.def={[K25]=K[27],[K38]={["!*t"]=true,["*t"]=true,},f=K3,[K2]=1363,[K1]="enum",x=4,y=247,}
T25.def={[K25]=K[26],f=K3,[K33]={[1]="year",[2]="month",[3]="day",[4]="hour",[5]="min",[6]="sec",[7]="wday",[8]="yday",[9]="isdst",},[K32]={day={f=K3,[K2]=1355,[K1]=K12,x=12,y=238,},hour={f=K3,[K2]=1356,[K1]=K12,x=13,y=239,},["isdst"]={f=K3,[K2]=1361,[K1]=K24,x=14,y=244,},min={f=K3,[K2]=1357,[K1]=K12,x=12,y=240,},["month"]={f=K3,[K2]=1354,[K1]=K12,x=14,y=237,},sec={f=K3,[K2]=1358,[K1]=K12,x=12,y=241,},wday={f=K3,[K2]=1359,[K1]=K12,x=13,y=242,},yday={f=K3,[K2]=1360,[K1]=K12,x=13,y=243,},year={f=K3,[K2]=1353,[K1]=K12,x=13,y=236,},},[K2]=1352,[K1]=K37,x=4,y=235,}
T26.def={f=K3,t={[K25]=K[35],[K30]=T27,f=K3,[K33]={[1]="n",},[K32]={n={f=K3,[K2]=1681,[K1]=K12,x=10,y=312,},},[K[9]]={[1]={[K30]=T27,f=K3,[K2]=1680,[K1]=K31,x=10,xend=12,y=310,yend=310,},},[K[1]]=true,[K2]=1678,[K1]=K37,x=4,y=309,},[K19]={[1]={f=K3,[K10]="A",[K2]=1677,[K1]=K10,x=21,y=309,},xend=22,yend=309,},[K2]=1682,[K1]=K20,x=4,y=309,}
T28.def={f=K3,t={args={f=K3,[K4]={[1]={f=K3,[K2]=2366,[K1]=K5,[K5]="A",x=36,y=307,},[2]={f=K3,[K2]=2367,[K1]=K5,[K5]="A",x=39,y=307,},},[K2]=1672,[K1]=K4,x=41,y=307,},f=K3,[K9]=false,[K6]=2,rets={f=K3,[K4]={[1]={f=K3,[K2]=1674,[K1]=K24,x=43,y=307,},},[K2]=1673,[K1]=K4,x=41,y=307,},[K2]=1668,[K1]=K7,x=24,y=307,},[K19]={[1]={f=K3,[K10]="A",[K2]=1669,[K1]=K10,x=33,y=307,},xend=34,yend=307,},[K2]=1675,[K1]=K20,x=4,y=309,}

return { globals = T0, typeid_ctr = 2848, typevar_ctr = 53}


end

-- module teal.traversal from teal/traversal.lua
package.preload["teal.traversal"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table; local type = type


local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG

local types = require("teal.types")













local show_type = types.show_type





local traversal = { VisitorCallbacks = {}, Visitor = {} }

































function traversal.fields_of(t, meta)
   local i = 1
   local field_order, fields
   if meta then
      field_order, fields = t.meta_field_order, t.meta_fields
   else
      field_order, fields = t.field_order, t.fields
   end
   if not fields then
      return function()
      end
   end
   return function()
      local name = field_order[i]
      if not name then
         return nil
      end
      i = i + 1
      return name, fields[name]
   end
end


local recurse_type

local function aggregate_type_walker(s, ast, visit)
   local xs = {}
   for i, child in ipairs(ast.types) do
      xs[i] = recurse_type(s, child, visit)
   end
   return xs
end

local function record_like_type_walker(s, ast, visit)
   local xs = {}
   if ast.interface_list then
      for _, child in ipairs(ast.interface_list) do
         table.insert(xs, recurse_type(s, child, visit))
      end
   end
   if ast.elements then
      table.insert(xs, recurse_type(s, ast.elements, visit))
   end
   if ast.fields then
      for _, child in traversal.fields_of(ast) do
         table.insert(xs, recurse_type(s, child, visit))
      end
   end
   if ast.meta_fields then
      for _, child in traversal.fields_of(ast, "meta") do
         table.insert(xs, recurse_type(s, child, visit))
      end
   end
   return xs
end

local type_walkers = {
   ["typevar"] = false,
   ["unresolved_typearg"] = false,
   ["unresolvable_typearg"] = false,
   ["self"] = false,
   ["enum"] = false,
   ["boolean"] = false,
   ["string"] = false,
   ["nil"] = false,
   ["thread"] = false,
   ["userdata"] = false,
   ["number"] = false,
   ["integer"] = false,
   ["circular_require"] = false,
   ["boolean_context"] = false,
   ["emptytable"] = false,
   ["unresolved_emptytable_value"] = false,
   ["any"] = false,
   ["unknown"] = false,
   ["invalid"] = false,
   ["none"] = false,
   ["*"] = false,

   ["generic"] = function(s, ast, visit)
      local xs = {}
      for _, child in ipairs(ast.typeargs) do
         table.insert(xs, recurse_type(s, child, visit))
      end
      table.insert(xs, recurse_type(s, ast.t, visit))
      return xs
   end,
   ["tuple"] = function(s, ast, visit)
      local xs = {}
      for i, child in ipairs(ast.tuple) do
         xs[i] = recurse_type(s, child, visit)
      end
      return xs
   end,
   ["union"] = aggregate_type_walker,
   ["tupletable"] = aggregate_type_walker,
   ["poly"] = aggregate_type_walker,
   ["map"] = function(s, ast, visit)
      return {
         recurse_type(s, ast.keys, visit),
         recurse_type(s, ast.values, visit),
      }
   end,
   ["record"] = record_like_type_walker,
   ["interface"] = record_like_type_walker,
   ["function"] = function(s, ast, visit)
      local xs = {}
      if ast.args then
         for _, child in ipairs(ast.args.tuple) do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
      if ast.rets then
         for _, child in ipairs(ast.rets.tuple) do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
      return xs
   end,
   ["nominal"] = function(s, ast, visit)
      local xs = {}
      if ast.typevals then
         for _, child in ipairs(ast.typevals) do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
      return xs
   end,
   ["typearg"] = function(s, ast, visit)
      return {
         ast.constraint and recurse_type(s, ast.constraint, visit),
      }
   end,
   ["array"] = function(s, ast, visit)
      return {
         recurse_type(s, ast.elements, visit),
      }
   end,
   ["literal_table_item"] = function(s, ast, visit)
      return {
         recurse_type(s, ast.ktype, visit),
         recurse_type(s, ast.vtype, visit),
      }
   end,
   ["typedecl"] = function(s, ast, visit)
      return {
         recurse_type(s, ast.def, visit),
      }
   end,
}

recurse_type = function(s, ast, visit)
   local kind = ast.typename

   if TL_DEBUG then
      tldebug.indent_push("---", ast.y, ast.x, "[%s] = %s", kind, show_type(ast))
   end

   local cbs = visit.cbs
   local cbkind = cbs and cbs[kind]
   if cbkind then
      local cbkind_before = cbkind.before
      if cbkind_before then
         cbkind_before(s, ast)
      end
   end

   local xs
   local walker = type_walkers[ast.typename]
   if not (type(walker) == "boolean") then
      xs = walker(s, ast, visit)
   end

   local ret
   local cbkind_after = cbkind and cbkind.after
   if cbkind_after then
      ret = cbkind_after(s, ast, xs)
   end
   local visit_after = visit.after
   if visit_after then
      ret = visit_after(s, ast, xs, ret)
   end

   if TL_DEBUG then
      tldebug.indent_pop("---", "---", ast.y, ast.x)
   end

   return ret
end

local function recurse_typeargs(s, ast, visit_type)
   if ast.typeargs then
      for _, typearg in ipairs(ast.typeargs) do
         recurse_type(s, typearg, visit_type)
      end
   end
end

local function extra_callback(name,
   s,
   ast,
   xs,
   visit_node)
   local cbs = visit_node.cbs
   if not cbs then return end
   local nbs = cbs[ast.kind]
   if not nbs then return end
   local bs = nbs[name]
   if not bs then return end
   bs(s, ast, xs)
end

local no_traverse_nodes = {
   ["..."] = true,
   ["nil"] = true,
   ["cast"] = true,
   ["goto"] = true,
   ["break"] = true,
   ["label"] = true,
   ["number"] = true,
   ["pragma"] = true,
   ["string"] = true,
   ["boolean"] = true,
   ["integer"] = true,
   ["variable"] = true,
   ["error_node"] = true,
   ["identifier"] = true,
   ["type_identifier"] = true,
}

function traversal.traverse_nodes(s, root,
   visit_node,
   visit_type)
   if not root then

      return
   end

   local recurse

   local function walk_children(ast, xs)
      for i, child in ipairs(ast) do
         xs[i] = recurse(child)
      end
   end

   local function walk_vars_exps(ast, xs)
      xs[1] = recurse(ast.vars)
      if ast.decltuple then
         xs[2] = recurse_type(s, ast.decltuple, visit_type)
      end
      extra_callback("before_exp", s, ast, xs, visit_node)
      if ast.exps then
         xs[3] = recurse(ast.exps)
      end
   end

   local function walk_named_function(ast, xs)
      recurse_typeargs(s, ast, visit_type)
      xs[1] = recurse(ast.name)
      xs[2] = recurse(ast.args)
      xs[3] = recurse_type(s, ast.rets, visit_type)
      extra_callback("before_statements", s, ast, xs, visit_node)
      xs[4] = recurse(ast.body)
   end

   local walkers = {
      ["op"] = function(ast, xs)
         xs[1] = recurse(ast.e1)
         local p1 = ast.e1.op and ast.e1.op.prec or nil
         if ast.op.op == ":" and ast.e1.kind == "string" then
            p1 = -999
         end
         xs[2] = p1
         if ast.op.arity == 2 then
            extra_callback("before_e2", s, ast, xs, visit_node)
            if ast.op.op == "is" or ast.op.op == "as" then
               xs[3] = recurse_type(s, ast.e2.casttype, visit_type)
            else
               xs[3] = recurse(ast.e2)
            end
            xs[4] = (ast.e2.op and ast.e2.op.prec)
         end
      end,

      ["statements"] = walk_children,
      ["argument_list"] = walk_children,
      ["literal_table"] = walk_children,
      ["variable_list"] = walk_children,
      ["expression_list"] = walk_children,

      ["literal_table_item"] = function(ast, xs)
         xs[1] = recurse(ast.key)
         xs[2] = recurse(ast.value)
         if ast.itemtype then
            xs[3] = recurse_type(s, ast.itemtype, visit_type)
         end
      end,

      ["assignment"] = walk_vars_exps,
      ["local_declaration"] = walk_vars_exps,
      ["global_declaration"] = walk_vars_exps,

      ["local_type"] = function(ast, xs)


         xs[1] = recurse(ast.var)
         xs[2] = recurse(ast.value)
      end,

      ["global_type"] = function(ast, xs)


         xs[1] = recurse(ast.var)
         if ast.value then
            xs[2] = recurse(ast.value)
         end
      end,

      ["if"] = function(ast, xs)
         for _, e in ipairs(ast.if_blocks) do
            table.insert(xs, recurse(e))
         end
      end,

      ["if_block"] = function(ast, xs)
         if ast.exp then
            xs[1] = recurse(ast.exp)
         end
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[2] = recurse(ast.body)
      end,

      ["while"] = function(ast, xs)
         xs[1] = recurse(ast.exp)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[2] = recurse(ast.body)
      end,

      ["repeat"] = function(ast, xs)
         xs[1] = recurse(ast.body)
         xs[2] = recurse(ast.exp)
      end,

      ["macroexp"] = function(ast, xs)
         recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.args)
         xs[2] = recurse_type(s, ast.rets, visit_type)
         extra_callback("before_exp", s, ast, xs, visit_node)
         xs[3] = recurse(ast.exp)
      end,

      ["function"] = function(ast, xs)
         recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.args)
         xs[2] = recurse_type(s, ast.rets, visit_type)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[3] = recurse(ast.body)
      end,
      ["local_function"] = walk_named_function,
      ["global_function"] = walk_named_function,
      ["record_function"] = function(ast, xs)
         recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.fn_owner)
         xs[2] = recurse(ast.name)
         extra_callback("before_arguments", s, ast, xs, visit_node)
         xs[3] = recurse(ast.args)
         xs[4] = recurse_type(s, ast.rets, visit_type)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[5] = recurse(ast.body)
      end,
      ["local_macroexp"] = function(ast, xs)

         xs[1] = recurse(ast.name)
         xs[2] = recurse(ast.macrodef.args)
         xs[3] = recurse_type(s, ast.macrodef.rets, visit_type)
         extra_callback("before_exp", s, ast, xs, visit_node)
         xs[4] = recurse(ast.macrodef.exp)
      end,

      ["forin"] = function(ast, xs)
         xs[1] = recurse(ast.vars)
         xs[2] = recurse(ast.exps)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[3] = recurse(ast.body)
      end,

      ["fornum"] = function(ast, xs)
         xs[1] = recurse(ast.var)
         xs[2] = recurse(ast.from)
         xs[3] = recurse(ast.to)
         xs[4] = ast.step and recurse(ast.step)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[5] = recurse(ast.body)
      end,

      ["return"] = function(ast, xs)
         xs[1] = recurse(ast.exps)
      end,

      ["do"] = function(ast, xs)
         xs[1] = recurse(ast.body)
      end,

      ["paren"] = function(ast, xs)
         xs[1] = recurse(ast.e1)
      end,

      ["newtype"] = function(ast, xs)
         xs[1] = recurse_type(s, ast.newtype, visit_type)
      end,

      ["argument"] = function(ast, xs)
         if ast.argtype then
            xs[1] = recurse_type(s, ast.argtype, visit_type)
         end
      end,
   }

   if not visit_node.allow_missing_cbs and not visit_node.cbs then
      error("missing cbs in visit_node")
   end
   local visit_after = visit_node.after

   recurse = function(ast)
      local xs = {}
      local kind = assert(ast.kind)
      local kprint

      local cbs = visit_node.cbs
      local cbkind = cbs and cbs[kind]
      if cbkind then
         if cbkind.before then
            cbkind.before(s, ast)
         end
      end

      if TL_DEBUG then
         if ast.y > tldebug.TL_DEBUG_MAXLINE then
            error("Halting execution at input line " .. ast.y)
         end
         kprint = kind == "op" and "op " .. ast.op.op or
         kind == "identifier" and "identifier " .. ast.tk or
         kind
         tldebug.indent_push("{{{", ast.y, ast.x, "[%s]", kprint)
      end

      local fn = walkers[kind]
      if fn then
         fn(ast, xs)
      else
         assert(no_traverse_nodes[kind])
      end

      local ret
      local cbkind_after = cbkind and cbkind.after
      if cbkind_after then
         ret = cbkind_after(s, ast, xs)
      end
      if visit_after then
         ret = visit_after(s, ast, xs, ret)
      end

      if TL_DEBUG then
         local typ = ast.debug_type and " = " .. show_type(ast.debug_type) or ""
         tldebug.indent_pop("}}}", "***", ast.y, ast.x, "[%s]%s", kprint, typ)
      end

      return ret
   end

   return recurse(root)
end

return traversal

end

-- module teal.type_errors from teal/type_errors.lua
package.preload["teal.type_errors"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type; local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG

local types = require("teal.types")







local a_type = types.a_type

local parser = require("teal.parser")









local variables = require("teal.variables")


local has_var_been_used = variables.has_var_been_used

local type_errors = { Errors = {} }













local Errors = type_errors.Errors

function Errors.new(filename)
   local self = {
      errors = {},
      warnings = {},
      unknown_dots = {},
      filename = filename,
   }
   return setmetatable(self, { __index = Errors })
end

local function insert_error(self, y, x, f, err)
   err.y = assert(y)
   err.x = assert(x)
   err.filename = assert(f)

   if TL_DEBUG then
      tldebug.write("ERROR:" .. err.y .. ":" .. err.x .. ": " .. err.msg .. "\n")
   end

   table.insert(self.errors, err)
end

function Errors:add(w, msg, t, ...)
   local e
   if t then
      e = types.error(msg, t, ...)
   else
      e = { msg = msg }
   end
   if e then
      insert_error(self, w.y, w.x, w.f, e)
   end
end

type_errors.context_name = {
   ["local_declaration"] = "in local declaration",
   ["global_declaration"] = "in global declaration",
   ["assignment"] = "in assignment",
   ["literal_table_item"] = "in table item",
}

function Errors:node_context(ctx, name)
   assert(ctx)
   local ec = ctx.expected_context
   local cn = type_errors.context_name[ec and ec.kind or ctx.kind]
   return (cn and cn .. ": " or "") .. (ec and ec.name and ec.name .. ": " or "") .. (name and name .. ": " or "")
end

function Errors:string_context(ctx, name)
   assert(ctx)
   local cn = ctx
   return (cn .. ": " or "") .. (name and name .. ": " or "")
end

function Errors:get_context(ctx, name)
   assert(ctx)
   local ec = (ctx.kind ~= nil) and ctx.expected_context
   local cn = (type(ctx) == "string") and ctx or
   (ctx.kind ~= nil) and type_errors.context_name[ec and ec.kind or ctx.kind]
   return (cn and cn .. ": " or "") .. (ec and ec.name and ec.name .. ": " or "") .. (name and name .. ": " or "")
end

function Errors:add_in_context(w, ctx, msg, ...)
   if ctx then
      local prefix = self:get_context(ctx)
      msg = prefix .. msg
   end
   return self:add(w, msg, ...)
end


function Errors:collect(errs)
   for _, e in ipairs(errs) do
      insert_error(self, e.y, e.x, e.filename, e)
   end
end

function Errors:add_warning(tag, w, fmt, ...)
   assert(w.y)
   table.insert(self.warnings, {
      y = w.y,
      x = w.x,
      msg = fmt:format(...),
      filename = assert(w.f),
      tag = tag,
   })
end

function Errors:invalid_at(w, msg, ...)
   self:add(w, msg, ...)
   return a_type(w, "invalid", {})
end

function Errors:add_unknown(w, name)
   self:add_warning("unknown", w, "unknown variable: %s", name)
end

function Errors:redeclaration_warning(at, var_name, var_kind, old_var)
   if var_name:sub(1, 1) == "_" then return end

   local short_error = var_kind .. " shadows previous declaration of '%s'"
   if old_var and old_var.declared_at then
      self:add_warning("redeclaration", at, short_error .. " (originally declared at %d:%d)", var_name, old_var.declared_at.y, old_var.declared_at.x)
   else
      self:add_warning("redeclaration", at, short_error, var_name)
   end
end

local function var_should_be_ignored_for_warnings(name, var)
   local prefix = name:sub(1, 1)
   return (not var.declared_at) or
   var.is_specialized == "narrow" or
   prefix == "_" or
   prefix == "@"
end

local function user_facing_variable_description(var)
   local t = var.t
   return var.is_func_arg and "argument" or
   t.typename == "function" and "function" or
   t.typename == "typedecl" and "type" or
   "variable"
end

function Errors:unused_warning(name, var)
   if var_should_be_ignored_for_warnings(name, var) then
      return
   end
   self:add_warning(
   "unused",
   var.declared_at,
   "unused %s %s: %s",
   user_facing_variable_description(var),
   name,
   types.show_type(var.t))

end

function Errors:add_prefixing(w, src, prefix, dst)
   if not src then
      return
   end

   for _, err in ipairs(src) do
      err.msg = prefix .. err.msg
      if w and (
         (err.filename ~= w.f) or
         (not err.y) or
         (w.y > err.y or (w.y == err.y and w.x > err.x))) then

         err.y = w.y
         err.x = w.x
         err.filename = w.f
      end

      if dst then
         table.insert(dst, err)
      else
         insert_error(self, err.y, err.x, err.filename, err)
      end
   end
end

local function ensure_not_abstract_type(def, node)
   if def.typename == "record" then
      return true
   elseif def.typename == "generic" then
      return ensure_not_abstract_type(def.t)
   elseif node and parser.node_is_require_call(node) then
      return nil, "module type is abstract: " .. tostring(def)
   elseif def.typename == "interface" then
      return nil, "interfaces are abstract; consider using a concrete record"
   end
   return nil, "cannot use a type definition as a concrete value"
end

function type_errors.ensure_not_abstract(t, node)
   if t.typename == "function" and t.macroexp then
      return nil, "macroexps are abstract; consider using a concrete function"
   elseif t.typename == "generic" then
      return type_errors.ensure_not_abstract(t.t, node)
   elseif t.typename == "typedecl" then
      return ensure_not_abstract_type(t.def, node)
   end
   return true
end














local function check_var_usage(scope, is_global)
   local vars = scope.vars
   if not next(vars) then
      return
   end
   local usage_warnings
   for name, var in pairs(vars) do
      local t = var.t
      if not var_should_be_ignored_for_warnings(name, var) then
         if var.has_been_written_to and not var.has_been_read_from then
            usage_warnings = usage_warnings or {}
            table.insert(usage_warnings, {
               y = var.declared_at.y,
               x = var.declared_at.x,
               name = name,
               var = var,
               kind = "written but not read",
            })
         end

      end

      if var.declared_at and not has_var_been_used(var) then
         if var.used_as_type then
            var.declared_at.elide_type = true
         else
            if t.typename == "typedecl" and not is_global then
               var.declared_at.elide_type = true
            end
            usage_warnings = usage_warnings or {}
            table.insert(usage_warnings, { y = var.declared_at.y, x = var.declared_at.x, name = name, var = var, kind = "unused" })
         end
      elseif has_var_been_used(var) and t.typename == "typedecl" and var.aliasing then
         var.aliasing.has_been_written_to = var.has_been_written_to
         var.aliasing.has_been_read_from = var.has_been_read_from
         if type_errors.ensure_not_abstract(t) then
            var.aliasing.declared_at.elide_type = false
         end
      end
   end
   if usage_warnings then
      table.sort(usage_warnings, function(a, b)
         return a.y < b.y or (a.y == b.y and a.x < b.x)
      end)
   end
   return usage_warnings
end

function Errors:check_var_usage(scope, is_global)
   local usage_warnings = check_var_usage(scope, is_global)
   if usage_warnings then
      for _, u in ipairs(usage_warnings) do
         if u.kind == "unused" then
            self:unused_warning(u.name, u.var)
         elseif u.kind == "written but not read" then
            self:add_warning(
            "unread",
            u.var.declared_at,
            "%s %s (of type %s) is never read",
            user_facing_variable_description(u.var),
            u.name,
            types.show_type(u.var.t))

         end
      end
   end

   if scope.labels then
      for name, node in pairs(scope.labels) do
         if not node.used_label then
            self:add_warning("unused", node, "unused label ::%s::", name)
         end
      end
   end
end

function Errors:add_unknown_dot(w, name)
   if not self.unknown_dots[name] then
      self.unknown_dots[name] = true
      self:add_unknown(w, name)
   end
end

function Errors:fail_unresolved_labels(scope)
   if scope.pending_labels then
      for name, nodes in pairs(scope.pending_labels) do
         for _, node in ipairs(nodes) do
            self:add(node, "no visible label '" .. name .. "' for goto")
         end
      end
   end
end

function Errors:fail_unresolved_nominals(scope, global_scope)
   if global_scope and scope.pending_nominals then
      for name, typs in pairs(scope.pending_nominals) do
         if not global_scope.pending_global_types[name] then
            for _, typ in ipairs(typs) do
               assert(typ.x)
               assert(typ.y)
               self:add(typ, "unknown type %s", typ)
            end
         end
      end
   end
end

function Errors:check_redeclared_key(w, ctx, seen_keys, key)
   if key ~= nil then
      local s = seen_keys[key]
      if s then
         self:add_in_context(w, ctx, "redeclared key " .. tostring(key) .. " (previously declared at " .. self.filename .. ":" .. s.y .. ":" .. s.x .. ")")
      else
         seen_keys[key] = w
      end
   end
end

return type_errors

end

-- module teal.type_reporter from teal/type_reporter.lua
package.preload["teal.type_reporter"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local types = require("teal.types")












local show_type = types.show_type







local util = require("teal.util")
local binary_search = util.binary_search
local sorted_keys = util.sorted_keys

local type_reporter = { TypeCollector = { Symbol = {} }, TypeInfo = {}, TypeReport = {}, TypeReporter = {} }


































































local TypeReport = type_reporter.TypeReport
local TypeReporter = type_reporter.TypeReporter












local typecodes = {

   NIL = 0x00000001,
   NUMBER = 0x00000002,
   BOOLEAN = 0x00000004,
   STRING = 0x00000008,
   TABLE = 0x00000010,
   FUNCTION = 0x00000020,
   USERDATA = 0x00000040,
   THREAD = 0x00000080,

   INTEGER = 0x00010002,
   ENUM = 0x00010004,
   EMPTY_TABLE = 0x00000008,
   ARRAY = 0x00010008,
   RECORD = 0x00020008,
   MAP = 0x00040008,
   TUPLE = 0x00080008,
   INTERFACE = 0x00100008,
   SELF = 0x00200008,
   POLY = 0x20000020,
   UNION = 0x40000000,

   NOMINAL = 0x10000000,
   TYPE_VARIABLE = 0x08000000,

   ANY = 0xffffffff,
   UNKNOWN = 0x80008000,
   INVALID = 0x80000000,
}





local typename_to_typecode = {
   ["typevar"] = typecodes.TYPE_VARIABLE,
   ["typearg"] = typecodes.TYPE_VARIABLE,
   ["unresolved_typearg"] = typecodes.TYPE_VARIABLE,
   ["unresolvable_typearg"] = typecodes.TYPE_VARIABLE,
   ["function"] = typecodes.FUNCTION,
   ["array"] = typecodes.ARRAY,
   ["map"] = typecodes.MAP,
   ["tupletable"] = typecodes.TUPLE,
   ["interface"] = typecodes.INTERFACE,
   ["self"] = typecodes.SELF,
   ["record"] = typecodes.RECORD,
   ["enum"] = typecodes.ENUM,
   ["boolean"] = typecodes.BOOLEAN,
   ["string"] = typecodes.STRING,
   ["nil"] = typecodes.NIL,
   ["thread"] = typecodes.THREAD,
   ["userdata"] = typecodes.USERDATA,
   ["number"] = typecodes.NUMBER,
   ["integer"] = typecodes.INTEGER,
   ["union"] = typecodes.UNION,
   ["nominal"] = typecodes.NOMINAL,
   ["circular_require"] = typecodes.NOMINAL,
   ["boolean_context"] = typecodes.BOOLEAN,
   ["emptytable"] = typecodes.EMPTY_TABLE,
   ["unresolved_emptytable_value"] = typecodes.EMPTY_TABLE,
   ["poly"] = typecodes.POLY,
   ["any"] = typecodes.ANY,
   ["unknown"] = typecodes.UNKNOWN,
   ["invalid"] = typecodes.INVALID,

   ["none"] = typecodes.UNKNOWN,
   ["tuple"] = typecodes.UNKNOWN,
   ["literal_table_item"] = typecodes.UNKNOWN,
   ["typedecl"] = typecodes.UNKNOWN,
   ["generic"] = typecodes.UNKNOWN,
   ["*"] = typecodes.UNKNOWN,
}

local skip_types = {
   ["none"] = true,
   ["tuple"] = true,
   ["literal_table_item"] = true,
}


local function mark_array(x)
   local arr = x
   arr[0] = false
   return x
end

function type_reporter.new()
   local self = setmetatable({
      next_num = 1,
      typeid_to_num = {},
      typename_to_num = {},
      tr = setmetatable({
         by_pos = {},
         types = {},
         symbols_by_file = {},
         globals = {},
      }, { __index = TypeReport }),
   }, { __index = TypeReporter })

   local names = {}
   for name, _ in pairs(types.simple_types) do
      table.insert(names, name)
   end
   table.sort(names)

   for _, name in ipairs(names) do
      local ti = {
         t = assert(typename_to_typecode[name]),
         str = name,
      }
      local n = self.next_num
      self.typename_to_num[name] = n
      self.tr.types[n] = ti
      self.next_num = self.next_num + 1
   end

   return self
end

function TypeReporter:store_function(ti, rt)
   local args = {}
   for _, fnarg in ipairs(rt.args.tuple) do
      table.insert(args, mark_array({ self:get_typenum(fnarg), nil }))
   end
   ti.args = mark_array(args)
   local rets = {}
   for _, fnarg in ipairs(rt.rets.tuple) do
      table.insert(rets, mark_array({ self:get_typenum(fnarg), nil }))
   end
   ti.rets = mark_array(rets)
   ti.vararg = not not rt.args.is_va
   ti.varret = not not rt.rets.is_va
end

function TypeReporter:get_typenum(t)

   local n = self.typename_to_num[t.typename]
   if n then
      return n
   end

   assert(t.typeid)

   n = self.typeid_to_num[t.typeid]
   if n then
      return n
   end

   local tr = self.tr


   n = self.next_num

   local rt = t
   if rt.typename == "tuple" and #rt.tuple == 1 then
      rt = rt.tuple[1]
   end

   if rt.typename == "typedecl" then
      return self:get_typenum(rt.def)
   end

   local typeargs
   if rt.typename == "generic" then
      typeargs = mark_array({})
      for _, typearg in ipairs(rt.typeargs) do
         local tn
         if typearg.constraint then
            tn = self:get_typenum(typearg.constraint)
         end
         table.insert(typeargs, mark_array({ typearg.typearg, tn }))
      end
      rt = rt.t
   end

   local ti = {
      t = assert(typename_to_typecode[rt.typename]),
      str = show_type(t, true),
      file = t.f,
      y = t.y,
      x = t.x,
      typeargs = typeargs,
   }
   tr.types[n] = ti
   self.typeid_to_num[t.typeid] = n
   self.next_num = self.next_num + 1

   if t.typename == "nominal" then
      if t.found then
         ti.ref = self:get_typenum(t.found)
      end
      if t.resolved then
         rt = t
      end
   end
   assert(not (rt.typename == "typedecl"))

   if rt.fields then

      local r = {}
      for _, k in ipairs(rt.field_order) do
         local v = rt.fields[k]
         r[k] = self:get_typenum(v)
      end
      ti.fields = r
      if rt.meta_fields then

         local m = {}
         for _, k in ipairs(rt.meta_field_order) do
            local v = rt.meta_fields[k]
            m[k] = self:get_typenum(v)
         end
         ti.meta_fields = m
      end
   end

   if rt.elements then
      ti.elements = self:get_typenum(rt.elements)
   end

   if rt.typename == "map" then
      ti.keys = self:get_typenum(rt.keys)
      ti.values = self:get_typenum(rt.values)
   elseif rt.typename == "enum" then
      ti.enums = mark_array(sorted_keys(rt.enumset))
   elseif rt.typename == "function" then
      self:store_function(ti, rt)
   elseif rt.types then
      local tis = {}
      for _, pt in ipairs(rt.types) do
         table.insert(tis, self:get_typenum(pt))
      end
      ti.types = mark_array(tis)
   end

   return n
end

function TypeReporter:add_field(rtype, fname, ftype)
   local n = self:get_typenum(rtype)
   local ti = self.tr.types[n]
   assert(ti.fields)
   ti.fields[fname] = self:get_typenum(ftype)
end

function TypeReporter:set_ref(nom, resolved)
   local n = self:get_typenum(nom)
   local ti = self.tr.types[n]
   ti.ref = self:get_typenum(resolved)
end

function TypeReporter:get_collector(filename)
   local collector = {
      filename = filename,
      symbol_list = {},
   }

   local ft = {}
   self.tr.by_pos[filename] = ft

   local symbol_list = collector.symbol_list
   local symbol_list_n = 0

   collector.store_type = function(y, x, typ)
      if not typ or skip_types[typ.typename] then
         return
      end

      local yt = ft[y]
      if not yt then
         yt = {}
         ft[y] = yt
      end

      yt[x] = self:get_typenum(typ)
   end

   collector.reserve_symbol_list_slot = function(node)
      symbol_list_n = symbol_list_n + 1
      node.symbol_list_slot = symbol_list_n
   end

   collector.add_to_symbol_list = function(node, name, t)
      if not node then
         return
      end
      local slot
      if node.symbol_list_slot then
         slot = node.symbol_list_slot
      else
         symbol_list_n = symbol_list_n + 1
         slot = symbol_list_n
      end
      symbol_list[slot] = { y = node.y, x = node.x, name = name, typ = t }
   end

   collector.begin_symbol_list_scope = function(node)
      symbol_list_n = symbol_list_n + 1
      symbol_list[symbol_list_n] = { y = node.y, x = node.x, name = "@{" }
   end

   collector.rollback_symbol_list_scope = function()
      while symbol_list[symbol_list_n].name ~= "@{" do
         symbol_list[symbol_list_n] = nil
         symbol_list_n = symbol_list_n - 1
      end
   end

   collector.end_symbol_list_scope = function(node)
      if symbol_list[symbol_list_n].name == "@{" then
         symbol_list[symbol_list_n] = nil
         symbol_list_n = symbol_list_n - 1
      else
         symbol_list_n = symbol_list_n + 1
         symbol_list[symbol_list_n] = { y = assert(node.yend), x = assert(node.xend), name = "@}" }
      end
   end

   return collector
end

function TypeReporter:store_result(collector, globals)
   local tr = self.tr

   local filename = collector.filename
   local symbol_list = collector.symbol_list

   tr.by_pos[filename][0] = nil


   do
      local n = 0
      local p = 0
      local n_stack, p_stack = {}, {}
      local level = 0
      for i, s in ipairs(symbol_list) do
         if s.typ then
            n = n + 1
         elseif s.name == "@{" then
            level = level + 1
            n_stack[level], p_stack[level] = n, p
            n, p = 0, i
         else
            if n == 0 then
               symbol_list[p].skip = true
               s.skip = true
            end
            n, p = n_stack[level], p_stack[level]
            level = level - 1
         end
      end
   end

   local symbols = mark_array({})
   tr.symbols_by_file[filename] = symbols


   do
      local stack = {}
      local level = 0
      local i = 0
      for _, s in ipairs(symbol_list) do
         if not s.skip then
            i = i + 1
            local id
            if s.typ then
               id = self:get_typenum(s.typ)
            elseif s.name == "@{" then
               level = level + 1
               stack[level] = i
               id = -1
            else
               local other = stack[level]
               level = level - 1
               symbols[other][4] = i
               id = other - 1
            end
            local sym = mark_array({ s.y, s.x, s.name, id })
            table.insert(symbols, sym)
         end
      end
   end

   local gkeys = sorted_keys(globals)
   for _, name in ipairs(gkeys) do
      if name:sub(1, 1) ~= "@" then
         local var = globals[name]
         tr.globals[name] = self:get_typenum(var.t)
      end
   end

   if not tr.symbols then
      tr.symbols = tr.symbols_by_file[filename]
   end
end

function TypeReporter:get_report()
   return self.tr
end





function TypeReport:symbols_in_scope(filename, y, x)
   local function find(symbols, at_y, at_x)
      local function le(a, b)
         return a[1] < b[1] or
         (a[1] == b[1] and a[2] <= b[2])
      end
      return binary_search(symbols, { at_y, at_x }, le) or 0
   end

   local ret = {}

   local symbols = self.symbols_by_file[filename]
   if not symbols then
      return ret
   end

   local n = find(symbols, y, x)

   while n >= 1 do
      local s = symbols[n]
      local symbol_name = s[3]
      if symbol_name == "@{" then
         n = n - 1
      elseif symbol_name == "@}" then
         n = s[4]
      else
         if ret[symbol_name] == nil then
            ret[symbol_name] = s[4]
         end
         n = n - 1
      end
   end

   return ret
end

return type_reporter

end

-- module teal.types from teal/types.lua
package.preload["teal.types"] = function(...)
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

end

-- module teal.util from teal/util.lua
package.preload["teal.util"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local table = _tl_compat and _tl_compat.table or table


local util = {}


function util.binary_search(list, item, cmp)
   local len = #list
   local mid
   local s, e = 1, len
   while s <= e do
      mid = math.floor((s + e) / 2)
      local val = list[mid]
      local res = cmp(val, item)
      if res then
         if mid == len then
            return mid, val
         else
            if not cmp(list[mid + 1], item) then
               return mid, val
            end
         end
         s = mid + 1
      else
         e = mid - 1
      end
   end
end

function util.shallow_copy_table(t)
   local copy = {}
   for k, v in pairs(t) do
      copy[k] = v
   end
   return copy
end

function util.sorted_keys(m)
   local keys = {}
   for k, _ in pairs(m) do
      table.insert(keys, k)
   end
   table.sort(keys)
   return keys
end

return util

end

-- module teal.variables from teal/variables.lua
package.preload["teal.variables"] = function(...)
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs











local variables = { Variable = {}, Scope = {} }





































function variables.has_var_been_used(var)
   return var.has_been_read_from or var.has_been_written_to
end

local function close_nested_records(t)
   if t.closed then
      return
   end
   local tdef = t.def
   if tdef.fields then
      t.closed = true
      for _, ft in pairs(tdef.fields) do
         if ft.typename == "typedecl" then
            close_nested_records(ft)
         end
      end
   end
end

function variables.close_types(scope)
   for _, var in pairs(scope.vars) do
      local t = var.t
      if t.typename == "typedecl" then
         close_nested_records(t)
      end
   end
end

return variables

end

return require("teal.api.v2")
