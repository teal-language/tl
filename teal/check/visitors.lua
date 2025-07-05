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
            self.errs:add(node, "not a record: %s", rtype)
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

         self:add_internal_function_variables(node, args)
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
