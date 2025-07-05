local type type_checker = require("teal.check.type_checker")
local type VarUse = type_checker.VarUse

local type context = require("teal.check.context")
local type Context = context.Context

local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG

local type errors = require("teal.errors")
local type Where = errors.Where

local types = require("teal.types")
local type Type = types.Type
local type GenericType = types.GenericType
local type StringType = types.StringType
local type NumericType = types.NumericType
local type IntegerType = types.IntegerType
local type BooleanType = types.BooleanType
local type BooleanContextType = types.BooleanContextType
local type TypeDeclType = types.TypeDeclType
local type LiteralTableItemType = types.LiteralTableItemType
local type NominalType = types.NominalType
local type SelfType = types.SelfType
local type ArrayLikeType = types.ArrayLikeType
local type ArrayType = types.ArrayType
local type RecordLikeType = types.RecordLikeType
local type RecordType = types.RecordType
local type InterfaceType = types.InterfaceType
local type InvalidType = types.InvalidType
local type UnknownType = types.UnknownType
local type TupleType = types.TupleType
local type TypeArgType = types.TypeArgType
local type TypeVarType = types.TypeVarType
local type MapType = types.MapType
local type NilType = types.NilType
local type EmptyTableType = types.EmptyTableType
local type FunctionType = types.FunctionType
local type UnionType = types.UnionType
local type TupleTableType = types.TupleTableType
local type PolyType = types.PolyType
local type EnumType = types.EnumType
local type FirstClassType = types.FirstClassType
local type TypeName = types.TypeName
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
local type Node = parser.Node
local type NodeKind = parser.NodeKind
local node_at = parser.node_at
local node_is_funcall = parser.node_is_funcall

local facts = require("teal.facts")
local type IsFact = facts.IsFact
local facts_not = facts.facts_not

local macroexps = require("teal.macroexps")

local metamethods = require("teal.metamethods")
local unop_to_metamethod = metamethods.unop_to_metamethod
local binop_to_metamethod = metamethods.binop_to_metamethod
local flip_binop_to_metamethod = metamethods.flip_binop_to_metamethod

local traversal = require("teal.traversal")
local type Visitor = traversal.Visitor
local traverse_nodes = traversal.traverse_nodes
local fields_of = traversal.fields_of

local type_errors = require("teal.type_errors")
local type CheckableKey = type_errors.CheckableKey
local ensure_not_abstract = type_errors.ensure_not_abstract

local type variables = require("teal.variables")
local type Variable = variables.Variable

local util = require("teal.util")
local sorted_keys = util.sorted_keys

--------------------------------------------------------------------------------

local record visitors
   visit_node: Visitor<Context, NodeKind, Node, Type>
   visit_type: Visitor<Context, TypeName, Type, Type>
end

visitors.visit_node = {}
visitors.visit_type = {}
local visit_node = visitors.visit_node
local visit_type = visitors.visit_type

--------------------------------------------------------------------------------

local macroexp a_self(w: Where, display_type: Type): SelfType
   return a_type(w, "self", { display_type = display_type } as SelfType)
end

local macroexp a_tuple(w: Where, t: {Type}): TupleType
   return a_type(w, "tuple", { tuple = t } as TupleType)
end

local macroexp an_array(w: Where, t: Type): ArrayType
   return a_type(w, "array", { elements = t } as ArrayType)
end

local macroexp a_map(w: Where, k: Type, v: Type): MapType
   return a_type(w, "map", { keys = k, values = v } as MapType)
end

local macroexp an_invalid(w: Where): InvalidType
   return a_type(w, "invalid", {} as InvalidType)
end

local macroexp an_unknown(w: Where): UnknownType
   return a_type(w, "unknown", {} as UnknownType)
end


--------------------------------------------------------------------------------

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
   }
}

local unop_types: {string:{TypeName:TypeName}} = {
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

local binop_types: {string:{TypeName:{TypeName:TypeName}}} = {
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
      }
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
      }
   },
}

local function resolve_typedecl(t: Type): Type
   if t is TypeDeclType then
      return t.def
   else
      return t
   end
end

-- This type must never be used for any values
local NONE = a_type({ f = "@none", x = -1, y = -1 }, "none", {})

local function end_scope_and_none_type(self: Context, node: Node, _children: {Type}): Type
   self:end_scope(node)
   return NONE
end

local is_lua_table_type: function(t: Type): boolean

do
   local known_table_types: {TypeName:boolean} = {
      array = true,
      map = true,
      record = true,
      tupletable = true,
      interface = true,
   }

   -- Is the type represented concretely as a Lua table?
   is_lua_table_type = function(t: Type): boolean
      return known_table_types[t.typename]
             and not (t is RecordLikeType and t.is_userdata)
   end
end

local function type_is_closable(t: Type): boolean
   if t is InvalidType then
      return false
   end
   if t is NilType then
      return true
   end
   if t is NominalType then
      t = assert(t.resolved)
   end
   if t is RecordLikeType then
      return t.meta_fields and t.meta_fields["__close"] ~= nil
   end
end

local definitely_not_closable_exprs <const>: {NodeKind:boolean} = {
   ["string"] = true,
   ["number"] = true,
   ["integer"] = true,
   ["boolean"] = true,
   ["literal_table"] = true,
}
local function expr_is_definitely_not_closable(e: Node): boolean
   return definitely_not_closable_exprs[e.kind]
end

local function make_is_node(self: Context, var: Node, v: Type, t: Type): Node, integer
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

local function convert_is_of_union_to_or_of_is(self: Context, node: Node, v: Type, u: UnionType): boolean
   local var = node.e1
   node.op.op = "or"
   node.op.arity = 2
   node.op.prec = 1
   local has_any: integer = nil
   node.e1, has_any = make_is_node(self, var, v, u.types[1])
   local at = node
   local n = #u.types
   for i = 2, n - 1 do
      at.e2 = node_at(var, { kind = "op", op = { op = "or", arity = 2, prec = 1 } })
      local has: integer
      at.e2.e1, has = make_is_node(self, var, v, u.types[i])
      has_any = has_any or has
      self.fdb:set_or(node, at.e1, at.e2)
      at = at.e2
   end
   at.e2 = make_is_node(self, var, v, u.types[n])
   self.fdb:set_or(node, at.e1, at.e2)
   return not not has_any
end

local function flat_tuple(w: Where, vt: {FirstClassType | TupleType}): TupleType
   local n_vals = #vt
   local ret = a_tuple(w, {})
   local rt = ret.tuple

   if n_vals == 0 then
      return ret
   end

   -- get all arguments except the last...
   for i = 1, n_vals - 1 do
      rt[i] = untuple(vt[i])
   end

   local last = vt[n_vals]
   if last is TupleType then
      -- ...then unpack the last tuple
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

local function get_assignment_values(w: Where, vals: TupleType, wanted: integer): TupleType
   if vals == nil then
      return a_tuple(w, {})
   end

   -- ...if the last is vararg, repeat its type until it matches the number of wanted args
   if vals.is_va then
      local vt = vals.tuple
      local n_vals = #vt
      if n_vals > 0 and n_vals < wanted then
         local last = vt[n_vals]
         local ret = a_tuple(w, {})
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

-- is the i-th assignment in a local declaration of the form `x = x` ?
local function is_localizing_a_variable(node: Node, i: integer): boolean
   return node.exps
      and node.exps[i]
      and node.exps[i].kind == "variable"
      and node.exps[i].tk == node.vars[i].tk
end

local function set_expected_types_to_decltuple(self: Context, node: Node, children: {Type})
   local decltuple = node.kind == "assignment" and children[1] or node.decltuple
   assert(decltuple is TupleType)
   local decls = decltuple.tuple
   if decls and node.exps then
      local ndecl = #decls
      local nexps = #node.exps
      for i = 1, nexps do
         local typ: Type
         typ = decls[i]
         if typ then
            if i == nexps and ndecl > nexps and node_is_funcall(node.exps[i]) then
               typ = a_tuple(node, {})
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

local function is_positive_int(n: number): boolean
   return n and n >= 1 and math.floor(n) == n
end

local function infer_table_literal(self: Context, node: Node, children: {LiteralTableItemType}): Type
   local is_record = false
   local is_array = false
   local is_map = false

   local is_tuple = false
   local is_not_tuple = false

   local last_array_idx = 1
   local largest_array_idx = -1

   local seen_keys: {CheckableKey:Where} = {}

   -- array, tupletable
   local typs: {Type}
   -- record
   local fields: {string:Type}
   local field_order: {string}
   -- array, record
   local elements: Type
   -- map
   local keys, values: Type, Type

   for i, child in ipairs(children) do
      local ck = child.kname
      local cktype = child.ktype
      local key: CheckableKey = ck
      local n: number
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
      elseif cktype is NumericType then
         is_array = true
         if not is_not_tuple then
            is_tuple = true
         end
         if not typs then
            typs = {}
         end

         if node[i].key_parsed == "implicit" then
            local cv = child.vtype
            if i == #children and cv is TupleType then
               -- need to expand last item in an array (e.g { 1, 2, 3, f() })
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
         else -- explicit
            if not is_positive_int(n) then
               elements = self:expand_type(node, elements, uvtype)
               is_not_tuple = true
            elseif n then
               typs[n as integer] = uvtype
               if n > largest_array_idx then
                  largest_array_idx = n as integer
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

   local t: Type

   if is_array and is_map then
      self.errs:add(node, "cannot determine type of table literal")
      t = a_map(node,
         self:expand_type(node, keys, a_type(node, "integer", {})),
         self:expand_type(node, values, elements)
      )
   elseif is_record and is_array then
      t = a_type(node, "record", {
         fields = fields,
         field_order = field_order,
         elements = elements,
         interface_list = {
            an_array(node, elements)
         }
      } as RecordType)
      -- TODO adopt logic from self:is_array below when we accept tupletable as an interface
   elseif is_record and is_map then
      if keys is StringType then
         for _, fname in ipairs(field_order) do
            values = self:expand_type(node, values, fields[fname])
         end
         t = a_map(node, keys, values)
      else
         self.errs:add(node, "cannot determine type of table literal")
      end
   elseif is_array then
      local pure_array = true
      if not is_not_tuple then
         local last_t: Type
         for _, current_t in pairs(typs as {integer:Type}) do
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
         t = an_array(node, elements)
         t.consttypes = typs
         t.inferred_len = largest_array_idx - 1
      else
         t = a_type(node, "tupletable", { inferred_at = node }) as TupleTableType
         t.types = typs
      end
   elseif is_record then
      t = a_type(node, "record", {
         fields = fields,
         field_order = field_order,
      } as RecordType)
   elseif is_map then
      t = a_map(node, keys, values)
   elseif is_tuple then
      t = a_type(node, "tupletable", { inferred_at = node }) as TupleTableType
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

local function total_check_key(key: CheckableKey, seen_keys: {CheckableKey:Where}, is_total: boolean, missing: {string}): boolean, {string}
   if not seen_keys[key] then
      missing = missing or {}
      table.insert(missing, tostring(key))
      return false, missing
   end
   return is_total, missing
end

local function total_record_check(t: RecordLikeType, seen_keys: {CheckableKey:Where}): boolean, {string}
   local is_total = true
   local missing: {string}
   for _, key in ipairs(t.field_order) do
      local ftype = t.fields[key]
      if not (ftype is TypeDeclType or (ftype is FunctionType and ftype.is_record_function)) then
         is_total, missing = total_check_key(key, seen_keys, is_total, missing)
      end
   end
   return is_total, missing
end

local function total_map_check(keys: Type, seen_keys: {CheckableKey:Where}): boolean, {string}
   local is_total = true
   local missing: {string}
   if keys is EnumType then
      for _, key in ipairs(sorted_keys(keys.enumset)) do
         is_total, missing = total_check_key(key, seen_keys, is_total, missing)
      end
   elseif keys is BooleanType then
      for _, key in ipairs({ true, false }) do
         is_total, missing = total_check_key(key, seen_keys, is_total, missing)
      end
   else
      is_total = false
   end
   return is_total, missing
end

local function discard_tuple(node: Node, t: Type, b: Type): Type
   if b is TupleType then
      node.discarded_tuple = true
   end
   return untuple(t)
end

local function assert_is_a(ctx: Context, w: Where, t1: Type, t2: Type, ectx?: Node|string, name?: string): boolean
   t1 = untuple(t1)
   t2 = untuple(t2)

   if t2 is EmptyTableType then
      t2 = type_at(w, t2) -- minor hack: tweak point of inference
   end

   local ok, errs = ctx:is_a(t1, t2)
   if not ok then
      ctx.errs:add_prefixing(w, errs, ctx.errs:get_context(ectx, name))
   end
   return ok
end

visit_node.cbs = {
   ["statements"] = {
      before = function(self: Context, node: Node)
         self:begin_scope(node)
      end,
      after = function(self: Context, node: Node, _children: {Type}): Type
         -- if at the top level
         if #self.st == 2 then
            self.errs:fail_unresolved_labels(self.st[2])
            self.errs:fail_unresolved_nominals(self.st[2], self.st[1])
         end

         if not node.is_repeat then
            self:end_scope(node)
         end

         return NONE
      end
   },
   ["local_type"] = {
      before = function(self: Context, node: Node)
         local name = node.var.tk
         local resolved, aliasing = self:get_typedecl(node.value)
         local var = self:add_var(node.var, name, resolved, node.var.attribute)
         if aliasing then
            var.aliasing = aliasing
         end
      end,
      after = function(self: Context, node: Node, _children: {Type}): Type
         self:dismiss_unresolved(node.var.tk)
         return NONE
      end,
   },
   ["global_type"] = {
      before = function(self: Context, node: Node)
         local global_scope = self.st[1]
         local name = node.var.tk
         if node.value then
            local resolved, aliasing = self:get_typedecl(node.value)
            local added = self:add_global(node.var, name, resolved)
            if resolved is InvalidType then
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
      after = function(self: Context, node: Node, _children: {Type}): Type
         self:dismiss_unresolved(node.var.tk)
         return NONE
      end,
   },
   ["local_declaration"] = {
      before = function(self: Context, node: Node)
         if self.collector then
            for _, var in ipairs(node.vars) do
               self.collector.reserve_symbol_list_slot(var)
            end
         end
      end,
      before_exp = set_expected_types_to_decltuple,
      after = function(self: Context, node: Node, children: {Type}): Type
         local valtuple = children[3] as TupleType -- may be nil

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
               if (not rt is EnumType)
                  and ((not t is NominalType) or (rt is UnionType))
                  and not self:same_type(t, infertype)
               then
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
      after = function(self: Context, node: Node, children: {Type}): Type
         local valtuple = children[3] as TupleType -- may be nil

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
      after = function(self: Context, node: Node, children: {Type}): Type
         local vartuple = children[1]
         assert(vartuple is TupleType)
         local vartypes = vartuple.tuple
         local valtuple = children[3]
         assert(valtuple is TupleType)
         local valtypes = get_assignment_values(node, valtuple, #vartypes)
         for i, vartype in ipairs(vartypes) do
            local varnode = node.vars[i]
            local varname = varnode.tk
            local valtype = valtypes.tuple[i]
            local rvar, rval, err = self:check_assignment(varnode, vartype, valtype)
            if err == "missing" then
               if #node.exps == 1 and node_is_funcall(node.exps[1]) then
                  local msg = #valtuple.tuple == 1
                              and "only 1 value is returned by the function"
                              or ("only " .. #valtuple.tuple .. " values are returned by the function")
                  self.errs:add_warning("hint", varnode, msg)
               end
            end

            if rval and rvar then
               -- assigning a function
               if rval is FunctionType then
                  self:widen_all_unions()
               end

               if varname and (rvar is UnionType or rvar is InterfaceType) then
                  -- narrow unions and interfaces
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
      after = function(self: Context, node: Node, _children: {Type}): Type
         if node.if_widens then
            -- TODO we could collect the types from each if_block
            -- and narrow the type to their union
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
      before = function(self: Context, node: Node)
         self:begin_scope(node)
         if node.if_block_n > 1 then
            self:infer_negation_of_if_blocks(node, node.if_parent, node.if_block_n - 1)
         end
         if node.exp then
            node.exp.expected = a_type(node, "boolean_context", {})
         end
      end,
      before_statements = function(self: Context, node: Node)
         if node.exp then
            self:apply_facts_from(node.exp)
         end
      end,
      after = function(self: Context, node: Node, _children: {Type}): Type
         node.if_parent.if_widens = self:collect_if_widens(node.if_parent.if_widens)

         self:end_scope(node)

         if #node.body > 0 and node.body[#node.body].block_returns then
            node.block_returns = true
         end

         return NONE
      end
   },
   ["while"] = {
      before = function(self: Context, node: Node)
         -- widen all narrowed variables because we don't calculate a fixpoint yet
         self:widen_all_unions(node)
         node.exp.expected = a_type(node, "boolean_context", {})
      end,
      before_statements = function(self: Context, node: Node)
         self:begin_scope(node)
         self:apply_facts_from(node.exp)
      end,
      after = end_scope_and_none_type,
   },
   ["label"] = {
      before = function(self: Context, node: Node)
         -- widen all narrowed variables because we don't calculate a fixpoint yet
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

         --for i = #self.st, 1, -1 do
            local scope = self.st[#self.st]
            if scope.pending_labels and scope.pending_labels[label_id] then
               node.used_label = true
               scope.pending_labels[label_id] = nil
               --break
            end
         --end
      end,
      after = function(): Type
         return NONE
      end
   },
   ["goto"] = {
      after = function(self: Context, node: Node, _children: {Type}): Type
         local label_id = node.label
         local found_label: Node
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
      before = function(self: Context, node: Node)
         -- widen all narrowed variables because we don't calculate a fixpoint yet
         self:widen_all_unions(node)
         node.exp.expected = a_type(node, "boolean_context", {})
      end,
      -- only end scope after checking `until`, `statements` in repeat body has is_repeat == true
      after = end_scope_and_none_type,
   },
   ["forin"] = {
      before = function(self: Context, node: Node)
         self:begin_scope(node)
      end,
      before_statements = function(self: Context, node: Node, children: {Type})
         local exptuple = children[2]
         assert(exptuple is TupleType)
         local exptypes = exptuple.tuple

         local exp1 = node.exps[1]
         if #exptypes < 1 then
            self.errs:invalid_at(exp1, "expression in 'for' statement does not return any values")
            return
         end

         self:widen_all_unions(node)

         local args = a_tuple(node.exps, {
            node.exps[2] and exptypes[2],
            node.exps[3] and exptypes[3]
         })
         local exp1type = self:resolve_for_call(exptypes[1], args, false)

         if exp1type is PolyType then
            local _r, f: Type, Type
            _r, f = self:type_check_function_call(exp1, exp1type, args, 0, nil, nil, exp1, {node.exps[2], node.exps[3]})
            if f then
               exp1type = f
            else
               self.errs:add(exp1, "cannot resolve polymorphic function given arguments")
            end
         end

         if exp1type is FunctionType then
            -- TODO: check that exp1's arguments match with (optional self, explicit iterator, state)
            local last: Type
            local rets = exp1type.rets
            for i, v in ipairs(node.vars) do
               local r = rets.tuple[i]
               if not r then
                  if rets.is_va then
                     r = last
                  else
                     r = self.feat_lax and an_unknown(v) or an_invalid(v)
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
      before_statements = function(self: Context, node: Node, children: {Type})
         self:widen_all_unions(node)
         self:begin_scope(node)
         local from_t = self:to_structural(untuple(children[2]))
         local to_t = self:to_structural(untuple(children[3]))
         local step_t = children[4] and self:to_structural(children[4])
         local typename: TypeName = (from_t is IntegerType and
                                     to_t is IntegerType and
                                     (not step_t or step_t is IntegerType))
                                    and "integer"
                                    or  "number"
         self:add_var(node.var, node.var.tk, a_type(node.var, typename, {}))
      end,
      after = end_scope_and_none_type,
   },
   ["return"] = {
      before = function(self: Context, node: Node)
         local rets = self:find_var_type("@return")
         if rets and rets is TupleType then
            for i, exp in ipairs(node.exps) do
               exp.expected = rets.tuple[i]
            end
         end
      end,
      after = function(self: Context, node: Node, children: {Type}): Type
         local got = children[1]
         assert(got is TupleType)
         local got_t = got.tuple
         local n_got = #got_t

         node.block_returns = true
         local expected = self:find_var_type("@return") as TupleType
         if not expected then
            -- if at the toplevel
            local module_type = untuple(got)
            if module_type is NominalType then
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
         local vatype: Type
         if n_expected > 0 then
            vatype = expected.is_va and expected.tuple[n_expected]
         end

         if n_got > n_expected and (not self.feat_lax) and not vatype then
            self.errs:add(node, what ..": excess return values, expected " .. n_expected .. " %s, got " .. n_got .. " %s", expected, got)
         end

         if n_expected > 1
         and #node.exps == 1
         and node.exps[1].kind == "op"
         and (node.exps[1].op.op == "and" or node.exps[1].op.op == "or")
         and node.exps[1].discarded_tuple then
            self.errs:add_warning("hint", node.exps[1].e2, "additional return values are being discarded due to '" .. node.exps[1].op.op .. "' expression; suggest parentheses if intentional")
         end

         for i = 1, n_got do
            local e = expected_t[i] or vatype
            if e then
               e = untuple(e)
               local w = (node.exps[i] and node.exps[i].x)
                         and node.exps[i]
                         or  node.exps
               assert(w and w.x)
               assert_is_a(self, w, got_t[i], e, what)
            end
         end

         return NONE
      end,
   },
   ["variable_list"] = {
      after = function(self: Context, node: Node, children: {FirstClassType | TupleType}): Type
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
      before = function(self: Context, node: Node)
         if node.expected then
            local decltype = self:to_structural(node.expected)

            if decltype is TypeVarType and decltype.constraint then
               decltype = resolve_typedecl(self:to_structural(decltype.constraint))
            end

            if decltype is GenericType then
               decltype = self:apply_generic(node, decltype)
            end

            if decltype is TupleTableType then
               for _, child in ipairs(node) do
                  local n = child.key.constnum
                  if n and is_positive_int(n) then
                     child.value.expected = decltype.types[n as integer]
                  end
               end
            elseif decltype is ArrayLikeType then
               for _, child in ipairs(node) do
                  if child.key.constnum then
                     child.value.expected = decltype.elements
                  end
               end
            elseif decltype is MapType then
               for _, child in ipairs(node) do
                  child.key.expected = decltype.keys
                  child.value.expected = decltype.values
               end
            end

            if decltype is RecordLikeType then
               for _, child in ipairs(node) do
                  if child.key.conststr then
                     child.value.expected = decltype.fields[child.key.conststr]
                  end
               end
            end
         end
      end,
      after = function(self: Context, node: Node, children: {LiteralTableItemType}): Type
         self.fdb:set_truthy(node)

         if not node.expected then
            return infer_table_literal(self, node, children)
         end

         local decltype = self:to_structural(node.expected)

         local constraint: Type
         if decltype is TypeVarType and decltype.constraint then
            constraint = resolve_typedecl(decltype.constraint)
            decltype = self:to_structural(constraint)
         end

         if decltype is GenericType then
            decltype = self:apply_generic(node, decltype)
         end

         if decltype is UnionType then
            local single_table_type: Type
            local single_table_rt: Type

            for _, t in ipairs(decltype.types) do
               local rt = self:to_structural(t)
               if is_lua_table_type(rt) then
                  if single_table_type then
                     -- multiple table types in union, give up
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

         if decltype is RecordLikeType then
            self:begin_implied_scope()
            self:add_self_type(node, decltype)
            decltype = self:resolve_self(decltype, true)
            self:end_implied_scope()
         end

         local force_array: Type = nil

         local seen_keys: {CheckableKey:Where} = {}

         for i, child in ipairs(children) do
            local cvtype = untuple(child.vtype)
            local ck = child.kname
            local cktype = child.ktype
            local n = node[i].key.constnum
            local b: boolean = nil
            if cktype is BooleanType then
               b = (node[i].key.tk == "true")
            end
            self.errs:check_redeclared_key(node[i], node, seen_keys, ck or n or b)
            if decltype is RecordLikeType and ck then
               local df = decltype.fields[ck]
               if not df then
                  self.errs:add_in_context(node[i], node, "unknown field " .. ck)
               else
                  if df is TypeDeclType then
                     self.errs:add_in_context(node[i], node, "cannot reassign a type")
                  else
                     assert_is_a(self, node[i], cvtype, df, "in record field", ck)
                  end
               end
            elseif decltype is TupleTableType and cktype is NumericType then
               local dt = decltype.types[n as integer]
               if not n then
                  self.errs:add_in_context(node[i], node, "unknown index in tuple %s", decltype)
               elseif not dt then
                  self.errs:add_in_context(node[i], node, "unexpected index " .. n .. " in tuple %s", decltype)
               else
                  assert_is_a(self, node[i], cvtype, dt, node, "in tuple: at index " .. tostring(n))
               end
            elseif decltype is ArrayLikeType and cktype is NumericType then
               local cv = child.vtype
               if cv is TupleType and i == #children and node[i].key_parsed == "implicit" then
                  -- need to expand last item in an array (e.g { 1, 2, 3, f() })
                  for ti, tt in ipairs(cv.tuple) do
                     assert_is_a(self, node[i], tt, decltype.elements, node, "expected an array: at index " .. tostring(i + ti - 1))
                  end
               else
                  assert_is_a(self, node[i], cvtype, decltype.elements, node, "expected an array: at index " .. tostring(n))
               end
            elseif node[i].key_parsed == "implicit" then
               if decltype is MapType then
                  assert_is_a(self, node[i].key, a_type(node[i].key, "integer", {}), decltype.keys, node, "in map key")
                  assert_is_a(self, node[i].value, cvtype, decltype.values, node, "in map value")
               end
               force_array = self:expand_type(node[i], force_array, child.vtype)
            elseif decltype is MapType then
               force_array = nil
               assert_is_a(self, node[i].key, cktype, decltype.keys, node, "in map key")
               assert_is_a(self, node[i].value, cvtype, decltype.values, node, "in map value")
            else
               self.errs:add_in_context(node[i], node, "unexpected key of type %s in table of type %s", cktype, decltype)
            end
         end

         local t = force_array and an_array(node, force_array) or node.expected
         t = self:infer_at(node, t)

         if decltype is RecordType then
            local rt = self:to_structural(t)
            if rt is RecordType then
               node.is_total, node.missing = total_record_check(decltype, seen_keys)
            end
         elseif decltype is MapType then
            local rt = self:to_structural(t)
            if rt is MapType then
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
      after = function(self: Context, node: Node, children: {Type}): Type
         local kname = node.key.conststr
         local ktype = children[1]
         local vtype = children[2]
         if node.itemtype then
            vtype = node.itemtype
            assert_is_a(self, node.value, children[2], node.itemtype, node)
         end
         -- If we assign a method to a table item, e.g.
         -- `local a = { myfunc = myobj.dothing }`
         -- the table item should not be treated as a method
         vtype = ensure_not_method(vtype)
         return a_type(node, "literal_table_item", {
            kname = kname,
            ktype = ktype,
            vtype = vtype,
         } as LiteralTableItemType)
      end,
   },
   ["local_function"] = {
      before = function(self: Context, node: Node)
         self:widen_all_unions()
         if self.collector then
            self.collector.reserve_symbol_list_slot(node)
         end
         self:begin_scope(node)
      end,
      before_statements = function(self: Context, node: Node, children: {Type})
         local args = children[2]
         assert(args is TupleType)

         self:add_internal_function_variables(node, args)
         self:add_function_definition_for_recursion(node, args, self.feat_arity)
      end,
      after = function(self: Context, node: Node, children: {Type}): Type
         local args = children[2]
         assert(args is TupleType)
         local rets = children[3]
         assert(rets is TupleType)

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
      before = function(self: Context, node: Node)
         self:widen_all_unions()
         if self.collector then
            self.collector.reserve_symbol_list_slot(node)
         end
         self:begin_scope(node)
      end,
      after = function(self: Context, node: Node, children: {Type}): Type
         local args = children[2]
         assert(args is TupleType)
         local rets = children[3]
         assert(rets is TupleType)

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
      before = function(self: Context, node: Node)
         self:widen_all_unions()
         self:begin_scope(node)
         if node.implicit_global_function then
            local typ = self:find_var_type(node.name.tk)
            if typ then
               if typ is FunctionType then
                  node.is_predeclared_local_function = true
               elseif not self.feat_lax then
                  self.errs:add(node, "cannot declare function: type of " .. node.name.tk .. " is %s", typ)
               end
            elseif not self.feat_lax then
               self.errs:add(node, "functions need an explicit 'local' or 'global' annotation")
            end
         end
      end,
      before_statements = function(self: Context, node: Node, children: {Type})
         local args = children[2]
         assert(args is TupleType)

         self:add_internal_function_variables(node, args)
         self:add_function_definition_for_recursion(node, args, self.feat_arity)
      end,
      after = function(self: Context, node: Node, children: {Type}): Type
         local args = children[2]
         assert(args is TupleType)
         local rets = children[3]
         assert(rets is TupleType)

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
      before = function(self: Context, node: Node)
         self:widen_all_unions()
         self:begin_scope(node)
      end,
      before_arguments = function(self: Context, _node: Node, children: {Type})
         local rtype = self:to_structural(resolve_typedecl(children[1]))

         -- add type arguments from the record implicitly
         if rtype is GenericType then
            for _, typ in ipairs(rtype.typeargs) do
               self:add_var(nil, typ.typearg, a_type(typ, "typearg", {
                  typearg = typ.typearg,
                  constraint = typ.constraint,
               } as TypeArgType))
            end
         end
      end,
      before_statements = function(self: Context, node: Node, children: {Type})
         local args = children[3]
         assert(args is TupleType)
         local rets = children[4]
         assert(rets is TupleType)

         local t = children[1]
         local rtype = self:to_structural(resolve_typedecl(t))

         if rtype is GenericType then
            rtype = rtype.t
         end

         do
            local ok, err = ensure_not_abstract(t)
            if not ok then
               self.errs:add(node, err)
            end
         end

         if self.feat_lax and rtype is UnknownType then
            return
         end

         if rtype is EmptyTableType then
            edit_type(rtype, rtype, "record")
            local r = rtype as RecordType
            r.fields = {}
            r.field_order = {}
         end

         if not rtype is RecordLikeType then
            self.errs:add(node, "not a record: %s", rtype)
            return
         end

         local selftype = self:get_self_type(node.fn_owner)
         if node.is_method then
            if not selftype then
               self.errs:add(node, "could not resolve type of self")
               return
            end
            args.tuple[1] = a_self(node, selftype)
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

            if fn_type is GenericType and not rfieldtype is GenericType then
               self:begin_implied_scope()
               fn_type = self:apply_generic(node, fn_type) as FunctionType
               self:end_implied_scope()
            end

            local ok, err = self:same_type(fn_type, rfieldtype)
            if not ok then
               if rfieldtype is PolyType then
                  self.errs:add_prefixing(node, err, "type signature does not match declaration: field has multiple function definitions (such polymorphic declarations are intended for Lua module interoperability): ")
                  return
               end

               local shortname = selftype and show_type(selftype) or owner_name
               local msg = "type signature of '" .. node.name.tk .. "' does not match its declaration in " .. shortname .. ": "
               self.errs:add_prefixing(node, err, msg)
               return
            end
         else
            if open_t and open_t is GenericType then
               open_t = open_t.t
            end
            if self.feat_lax or rtype == open_t then
               -- TODO is this needed?
               -- if fn_type is GenericType then
               --    fn_type = fresh_typeargs(self, fn_type)
               -- end

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
      after = function(self: Context, node: Node, _children: {Type}): Type
         self:end_function_scope(node)
         return NONE
      end,
   },
   ["function"] = {
      before = function(self: Context, node: Node)
         self:widen_all_unions(node)
         self:begin_scope(node)

         local expected = node.expected
         if expected and expected is FunctionType then
            for i, t in ipairs(expected.args.tuple) do
               if node.args[i] then
                  node.args[i].expected = t
               end
            end
         end
      end,
      before_statements = function(self: Context, node: Node, children: {Type})
         local args = children[1]
         assert(args is TupleType)

         self:add_internal_function_variables(node, args)
      end,
      after = function(self: Context, node: Node, children: {Type}): Type
         local args = children[1]
         assert(args is TupleType)
         local rets = children[2]
         assert(rets is TupleType)

         self:end_function_scope(node)

         return wrap_generic_if_typeargs(node.typeargs, a_function(node, {
            min_arity = self.feat_arity and node.min_arity or 0,
            args = args,
            rets = self.get_rets(rets),
         }))
      end,
   },
   ["macroexp"] = {
      before = function(self: Context, node: Node)
         self:widen_all_unions(node)
         self:begin_scope(node)
      end,
      before_exp = function(self: Context, node: Node, children: {Type})
         local args = children[1]
         assert(args is TupleType)

         self:add_internal_function_variables(node, args)
      end,
      after = function(self: Context, node: Node, children: {Type}): Type
         local args = children[1]
         assert(args is TupleType)
         local rets = children[2]
         assert(rets is TupleType)

         self:end_function_scope(node)
         return wrap_generic_if_typeargs(node.typeargs, a_function(node, {
            min_arity = self.feat_arity and node.min_arity or 0,
            args = args,
            rets = rets,
         }))
      end,
   },
   ["cast"] = {
      after = function(_self: Context, node: Node, _children: {Type}): Type
         return node.casttype
      end
   },
   ["paren"] = {
      before = function(_self: Context, node: Node)
         node.e1.expected = node.expected
      end,
      after = function(self: Context, node: Node, children: {Type}): Type
         self.fdb:set_from(node, node.e1)
         return untuple(children[1])
      end,
   },
   ["op"] = {
      before = function(self: Context, node: Node)
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
      before_e2 = function(self: Context, node: Node, children: {Type})
         local e1type = children[1]

         if node.op.op == "and" then
            self:apply_facts_from(node, node.e1)
         elseif node.op.op == "or" then
            self:apply_facts(node, facts_not(node, self.fdb:get(node.e1)))

            -- special-case `v is T and v or _` when T is a truthy type
            if node.e1.kind == "op" and node.e1.op.op == "and"
               and node.e1.e1.kind == "op" and node.e1.e1.op.op == "is"
               and node.e1.e2.kind == "variable"
               and node.e1.e2.tk == node.e1.e1.e1.tk
               and node.e1.e1.e2.casttype.typename ~= "boolean"
               and node.e1.e1.e2.casttype.typename ~= "nil"
            then
               self:apply_facts(node, facts_not(node, IsFact { var = node.e1.e1.e1.tk, typ = node.e1.e1.e2.casttype, w = node }))
            end

         elseif node.op.op == "@funcall" then
            if e1type is GenericType then
               e1type = self:apply_generic(node, e1type)
            end
            if e1type is FunctionType then
               local argdelta = (node.e1.op and node.e1.op.op == ":") and -1 or 0
               if node.expected then
                  -- this forces typevars in function return types
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
            if e1type is MapType then
               node.e2.expected = e1type.keys
            end
         end
      end,
      after = function(self: Context, node: Node, children: {Type}): Type
         self:end_implied_scope()

         -- given a and b: may be TupleType
         local ga: Type = children[1]
         local gb: Type = children[3]

         -- unary a and b: not TupleType
         local ua = untuple(ga)
         local ub: Type

         -- resolved a and b: not NominalType
         local ra: Type = self:to_structural(ua)
         local rb: Type

         if ra.typename == "circular_require" or (ra is TypeDeclType and ra.def and ra.def.typename == "circular_require") then
            return self.errs:invalid_at(node, "cannot dereference a type from a circular require")
         end

         if node.op.op == "@funcall" then
            if self.feat_lax and is_unknown(ua) then
               if node.e1.op and node.e1.op.op == ":" and node.e1.e1.kind == "variable" then
                  self.errs:add_unknown_dot(node, node.e1.e1.tk .. "." .. node.e1.e2.tk)
               end
            end
            assert(gb is TupleType)
            local t = self:type_check_funcall(node, ua, gb)
            return t

         elseif node.op.op == "as" then
            local ok, err = ensure_not_abstract(ra)
            if not ok then
               return self.errs:invalid_at(node.e1, err)
            end
            return gb

         elseif node.op.op == "is" and ra is TypeDeclType then
            return self.errs:invalid_at(node, "can only use 'is' on variables, not types")
         end

         local ok, err = ensure_not_abstract(ra)
         if not ok then
            return self.errs:invalid_at(node.e1, err)
         end
         if ra is TypeDeclType and ra.def.typename == "record" then
            ra = ra.def
         end

         -- "@funcall" and "as" are the only operators that use tuples, and always in the b position;
         -- after they are handled above, we can resolve b's tuple and only use that instead.
         if gb then
            ub = untuple(gb)
            rb = self:to_structural(ub)
            ok, err = ensure_not_abstract(rb)
            if not ok then
               return self.errs:invalid_at(node.e2, err)
            end
            if rb is TypeDeclType and rb.def.typename == "record" then
               rb = rb.def
            end
         end

         if node.op.op == "." then
            node.receiver = ua

            assert(node.e2.kind == "identifier")
            local bnode: Node = node_at(node.e2, {
               tk = node.e2.tk,
               kind = "string",
            })
            local btype = a_type(node.e2, "string", { literal = node.e2.tk } as StringType)
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
            if ra is TypeDeclType then
               self.errs:add(node, "can only use 'is' on variables, not types")
            elseif node.e1.kind == "variable" then
               if rb is UnionType then
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

            -- we handle ':' separately from '.' because ':' is specific to records,
            -- so we produce different error messages
            if self.feat_lax and (is_unknown(ua) or ua is TypeVarType) then
               if node.e1.kind == "variable" then
                  self.errs:add_unknown_dot(node.e1, node.e1.tk .. "." .. node.e2.tk)
               end
               return an_unknown(node)
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
            local t: Type

            local expected = node.expected and self:to_structural(untuple(node.expected))

            if ub is NilType then
               self.fdb:unset(node)
               t = ua

            elseif is_lua_table_type(ra) and rb is EmptyTableType then
               self.fdb:unset(node)
               t = ua

            elseif ((ra is EnumType and rb is StringType and self:is_a(rb, ra))
               or (ra is StringType and rb is EnumType and self:is_a(ra, rb))) then
               self.fdb:unset(node)
               t = (ra is EnumType and ra or rb)

            elseif expected and expected is UnionType then
               -- must be checked after string/enum above
               self.fdb:set_or(node, node.e1, node.e2)
               local u = unite(node, {ra, rb}, true)
               if u is UnionType then
                  ok, err = is_valid_union(u)
                  if not ok then
                     u = err and self.errs:invalid_at(node, err, u) or an_invalid(node)
                  end
               end
               t = u

            -- prefer the union type if it already works and the other one isn't a union
            elseif ra is UnionType and not (rb is UnionType) and self:is_a(rb, ra) then
               -- convert it to the union type
               t = drop_constant_value(ra)

            elseif rb is UnionType and not (ra is UnionType) and self:is_a(ra, rb) then
               -- convert it to the union type
               t = drop_constant_value(rb)

            else
               -- these compare using the unresolved type to prevent nominal types resolving into
               -- each other.
               local a_ge_b = self:is_a(ub, ua)
               local b_ge_a = self:is_a(ua, ub)
               self.fdb:set_or(node, node.e1, node.e2)
               -- TODO: change this to use unresolved types, but make sure that it works with
               -- table literal and nominal type
               local is_same = self:same_type(ra, rb)

               -- we can have some types that can be converted into either
               local ambiguous = a_ge_b and b_ge_a and not is_same

               -- prefer a type that we can easily work out rather than defaulting to the expected one
               -- (the expected one might need to be collapsed later with special functions)
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
                  -- workaround to keep existing code working
                  t = ub
               end
               if t then
                  t = drop_constant_value(t)
               end

               if expected and expected is BooleanContextType then
                  t = a_type(node, "boolean", {})
               end
            end

            if t then
               return discard_tuple(node, t, gb)
            end
            -- else fallthrough to general binop handler
         end

         if node.op.op == "==" or node.op.op == "~=" then
            if is_lua_table_type(ra) and is_lua_table_type(rb) then
               self:check_metamethod(node, binop_to_metamethod[node.op.op], ra, rb, ua, ub)
            end

            if ra is EnumType and rb is StringType then
               if not (rb.literal and ra.enumset[rb.literal]) then
                  return self.errs:invalid_at(node, "%s is not a member of %s", ub, ua)
               end
            elseif ra is TupleTableType and rb is TupleTableType and #ra.types ~= #rb.types then
               return self.errs:invalid_at(node, "tuples are not the same size")
            elseif self:is_a(ub, ua) or ua is TypeVarType then
               if node.op.op == "==" and node.e1.kind == "variable" then
                  self.fdb:set_eq(node, node.e1.tk, ub)
               end
            elseif self:is_a(ua, ub) or ub is TypeVarType then
               if node.op.op == "==" and node.e2.kind == "variable" then
                  self.fdb:set_eq(node, node.e2.tk, ua)
               end
            elseif self.feat_lax and (is_unknown(ua) or is_unknown(ub)) then
               return an_unknown(node)
            else
               return self.errs:invalid_at(node, "types are not comparable for equality: %s and %s", ua, ub)
            end

            return a_type(node, "boolean", {})
         end

         if node.op.arity == 1 and unop_types[node.op.op] then
            if ra is UnionType then
               ra = unite(node, ra.types, true) -- squash unions of string constants
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

            if not t and ra is RecordLikeType then
               if ra.interface_list then
                  for _, iface in ipairs(ra.interface_list) do
                     if types_op[iface.typename] then
                        t = a_type(node, types_op[iface.typename], {})
                        break
                     end
                  end
               end
            end

            if ra is MapType then
               if ra.keys.typename == "number" or ra.keys.typename == "integer" then
                   self.errs:add_warning("hint", node, "using the '#' operator on a map with numeric key type may produce unexpected results")
               else
                   self.errs:add(node, "using the '#' operator on this map will always return 0")
               end
            end

            if not t then
               return self.errs:invalid_at(node, "cannot use operator '" .. node.op.op:gsub("%%", "%%%%") .. "' on type %s", ua)
            end

            if not (t is BooleanType or is_unknown(t)) then
               self.fdb:set_truthy(node)
            end

            return t
         end

         if node.op.arity == 2 and binop_types[node.op.op] then
            if node.op.op == "or" then
               self.fdb:set_or(node, node.e1, node.e2)
            end

            if ra is UnionType then
               ra = unite(ra, ra.types, true) -- squash unions of string constants
            end
            if rb is UnionType then
               rb = unite(rb, rb.types, true) -- squash unions of string constants
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

            if (not t) and ua is NominalType and ub is NominalType and not node.op.meta_on_operand then
               if self:is_a(ua, ub) then
                  t = ua
               end
            end

            if types_op == numeric_binop or node.op.op == ".." then
               self.fdb:set_truthy(node)
            end

            if not t then
               if node.op.op == "or" then
                  local u = unite(node, {ua, ub})
                  if u is UnionType and is_valid_union(u) then
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
      after = function(self: Context, node: Node, _children: {Type}): Type
         if node.tk == "..." then
            local va_sentinel = self:find_var_type("@is_va")
            if not va_sentinel or va_sentinel is NilType then
               return self.errs:invalid_at(node, "cannot use '...' outside a vararg function")
            end
         end

         local t: Type
         if node.tk == "_G" then
            t, node.attribute = self:simulate_g()
         else
            local use: VarUse = node.is_lvalue and "lvalue" or "use"
            t, node.attribute = self:find_var_type(node.tk, use)
         end
         if not t then
            if self.feat_lax then
               self.errs:add_unknown(node, node.tk)
               return an_unknown(node)
            end

            return self.errs:invalid_at(node, "unknown variable: " .. node.tk)
         end

         if t is TypeDeclType then
            t = typedecl_to_nominal(node, node.tk, t, t)
         end

         return t
      end,
   },
   ["type_identifier"] = {
      after = function(self: Context, node: Node, _children: {Type}): Type
         local typ, attr = self:find_var_type(node.tk)
         node.attribute = attr
         if typ then
            return typ
         end

         if self.feat_lax then
            self.errs:add_unknown(node, node.tk)
            return an_unknown(node)
         end

         return self.errs:invalid_at(node, "unknown variable: " .. node.tk)
      end,
   },
   ["argument"] = {
      after = function(self: Context, node: Node, children: {Type}): Type
         local t = children[1]
         if not t then
            if node.expected and node.tk == "self" then
               t = node.expected
            else
               t = self.feat_lax
                   and an_unknown(node)
                   or  a_type(node, "any", {})
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
      after = function(_self: Context, _node: Node, _children: {Type}): Type
         return NONE -- type is resolved elsewhere
      end,
   },
   ["newtype"] = {
      after = function(_self: Context, node: Node, _children: {Type}): Type
         return node.newtype
      end,
   },
   ["pragma"] = {
      after = function(self: Context, node: Node, _children: {Type}): Type
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
      after = function(_self: Context, node: Node, _children: {Type}): Type
         return an_invalid(node)
      end,
   }
}

visit_node.cbs["break"] = {
   after = function(_self: Context, _node: Node, _children: {Type}): Type
      return NONE
   end,
}
visit_node.cbs["do"] = visit_node.cbs["break"]

local function after_literal(self: Context, node: Node): Type
   self.fdb:set_truthy(node)
   return a_type(node, node.kind as TypeName, {})
end

visit_node.cbs["string"] = {
   after = function(self: Context, node: Node, _children: {Type}): Type
      local t = after_literal(self, node) as StringType
      t.literal = node.conststr

      local expected = node.expected and self:to_structural(node.expected)
      if expected and expected is EnumType and self:is_a(t, expected) then
         return node.expected
      end

      return t
   end,
}
visit_node.cbs["number"] = { after = after_literal }
visit_node.cbs["integer"] = { after = after_literal }

visit_node.cbs["boolean"] = {
   after = function(self: Context, node: Node, _children: {Type}): Type
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

visit_node.after = function(_self: Context, node: Node, _children: {Type}, t: Type): Type
   if node.expanded then
      macroexps.apply(node)
   end

   return t
end



local function ensure_is_method_self(typ: RecordLikeType, selfarg: Type, g?: GenericType): boolean
   if selfarg is SelfType then
      return true
   end
   if not selfarg is NominalType then
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

      for j=1,#g.typeargs do
         local tv = selfarg.typevals[j]
         if not (tv and tv is TypeVarType and tv.typevar == g.typeargs[j].typearg) then
            return false
         end
      end
   end

   return true
end

local metamethod_is_method: {string: boolean} = {
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
      before = function(self: Context, typ: GenericType)
         self:begin_implied_scope()
         self:add_var(nil, "@generic", typ)
      end,
      after = function(self: Context, typ: GenericType, _children: {Type}): Type
         self:end_implied_scope()
         return self:fresh_typeargs(typ)
      end,
   },
   ["function"] = {
      after = function(self: Context, typ: FunctionType, _children: {Type}): Type
         if self.feat_arity == false then
            typ.min_arity = 0
         end
         return typ
      end
   },
   ["record"] = {
      before = function(self: Context, typ: RecordType)
         self:begin_implied_scope()
         self:begin_temporary_record_types(typ)
      end,
      after = function(self: Context, typ: RecordType, children: {Type}): Type
         local i = 1
         if typ.interface_list then
            for j, _ in ipairs(typ.interface_list) do
               local iface = children[i]
               if iface is ArrayType then
                  typ.interface_list[j] = iface
               elseif iface is NominalType then
                  local ri = self:resolve_nominal(iface)
                  if ri is InterfaceType then
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
         local fmacros: {FunctionType}
         local g: Variable
         for name, _ in fields_of(typ) do
            local ftype = children[i]
            if ftype is FunctionType then
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
                     ftype.is_method = ensure_is_method_self(typ, fargs[1], g and g.t as GenericType)
                     if ftype.is_method then
                        fargs[1] = a_self(fargs[1], typ)
                     end
                  end
               end
            elseif ftype is TypeDeclType and ftype.is_alias then
               self:resolve_typealias(ftype)
            end

            typ.fields[name] = ftype
            i = i + 1
         end
         for name, _ in fields_of(typ, "meta") do
            local ftype = children[i]
            if ftype is FunctionType then
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

               macroexps.check_arg_use(self, t.macroexp as Node)

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
      after = function(self: Context, typ: TypeArgType, _children: {Type}): Type
         local name = typ.typearg
         local old <const> = self:find_var(name, "check_only")
         if old then
            self.errs:redeclaration_warning(typ, name, "type argument", old)
         end
         if simple_types[name as TypeName] then
            self.errs:add(typ, "cannot use base type name '" .. name .. "' as a type variable")
         end

         self:add_var(nil, name, a_type(typ, "typearg", {
            typearg = name,
            constraint = typ.constraint,
         } as TypeArgType))
         return typ
      end,
   },
   ["typevar"] = {
      after = function(self: Context, typ: TypeVarType, _children: {Type}): Type
         if not self:find_var_type(typ.typevar) then
            self.errs:add(typ, "undefined type variable " .. typ.typevar)
         end
         return typ
      end,
   },
   ["nominal"] = {
      after = function(self: Context, typ: NominalType, _children: {Type}): Type
         if typ.found then
            return typ
         end

         local t, typearg = self:find_type(typ.names)
         if t then
            local def = t.def
            if t.is_alias then
               if def is GenericType then
                  def = def.t
               end
               if def is NominalType then
                  typ.found = def.found
               end
            elseif def.typename ~= "circular_require" then
               typ.found = t
            end
         elseif typearg then
            -- convert nominal into a typevar
            typ.names = nil
            edit_type(typ, typ, "typevar")
            local tv = typ as TypeVarType
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
      after = function(self: Context, typ: UnionType, _children: {Type}): Type
         local _, err = is_valid_union(typ)
         if err then
            return self.errs:invalid_at(typ, err, typ)
         end
         return typ
      end
   },
}

local default_type_visitor = {
   after = function(_self: Context, typ: Type, _children: {Type}): Type
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
