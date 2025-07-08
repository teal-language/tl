--------------------------------------------------------------------------------
-- AST traversal
--------------------------------------------------------------------------------
local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG

local type types = require("teal.types")
local type Type = types.Type
local type GenericType = types.GenericType
local type TypeDeclType = types.TypeDeclType
local type LiteralTableItemType = types.LiteralTableItemType
local type NominalType = types.NominalType
local type ArrayType = types.ArrayType
local type RecordLikeType = types.RecordLikeType
local type TupleType = types.TupleType
local type TypeArgType = types.TypeArgType
local type MapType = types.MapType
local type FunctionType = types.FunctionType
local type AggregateType = types.AggregateType
local type TypeName = types.TypeName
local show_type = types.show_type

local type parser = require("teal.parser")
local type Node = parser.Node
local type NodeKind = parser.NodeKind

local record traversal
   record VisitorCallbacks<S, N, T>
      before: function(S, N)
      before_exp: function(S, {N}, {T})
      before_arguments: function(S, {N}, {T})
      before_statements: function(S, {N}, {T})
      before_e2: function(S, {N}, {T})
      after: function(S, N, {T}): T
   end

   enum VisitorExtraCallback
      "before_arguments"
      "before_statements"
      "before_exp"
      "before_e2"
   end

   type VisitorAfter = function<S, N, T>(S, N, {T}, T): T

   record Visitor<S, K, N, T>
      cbs: {K:VisitorCallbacks<S, N, T>}
      after: VisitorAfter<S, N, T>
      allow_missing_cbs: boolean
   end

   enum MetaMode
      "meta"
   end
end

local type VisitorExtraCallback = traversal.VisitorExtraCallback
local type Visitor = traversal.Visitor
local type MetaMode = traversal.MetaMode

function traversal.fields_of(t: RecordLikeType, meta?: MetaMode): (function(): string, Type)
   local i = 1
   local field_order, fields: {string}, {string:Type}
   if meta then
      field_order, fields = t.meta_field_order, t.meta_fields
   else
      field_order, fields = t.field_order, t.fields
   end
   if not fields then
      return function(): string, Type
      end
   end
   return function(): string, Type
      local name = field_order[i]
      if not name then
         return nil
      end
      i = i + 1
      return name, fields[name]
   end
end


local recurse_type: function<S, T>(s: S, ast: Type, visit: Visitor<S, TypeName, Type, T>): T

local function aggregate_type_walker<S, T>(s: S, ast: AggregateType, visit: Visitor<S, TypeName, Type, T>): {T}
   local xs: {T} = {}
   for i, child in ipairs(ast.types) do
      xs[i] = recurse_type(s, child, visit)
   end
   return xs
end

local function record_like_type_walker<S, T>(s: S, ast: RecordLikeType, visit: Visitor<S, TypeName, Type, T>): {T}
   local xs: {T} = {}
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

local type_walkers <total>: {TypeName: boolean | function<S, T>(s: S, ast: Type, visit: Visitor<S, TypeName, Type, T>): {T}} = {
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

   ["generic"] = function<S, T>(s: S, ast: GenericType, visit: Visitor<S, TypeName, Type, T>): {T}
      local xs: {T} = {}
      for _, child in ipairs(ast.typeargs) do
         table.insert(xs, recurse_type(s, child, visit))
      end
      table.insert(xs, recurse_type(s, ast.t, visit))
      return xs
   end,
   ["tuple"] = function<S, T>(s: S, ast: TupleType, visit: Visitor<S, TypeName, Type, T>): {T}
      local xs: {T} = {}
      for i, child in ipairs(ast.tuple) do
         xs[i] = recurse_type(s, child, visit)
      end
      return xs
   end,
   ["union"] = aggregate_type_walker,
   ["tupletable"] = aggregate_type_walker,
   ["poly"] = aggregate_type_walker,
   ["map"] = function<S, T>(s: S, ast: MapType, visit: Visitor<S, TypeName, Type, T>): {T}
      return {
         recurse_type(s, ast.keys, visit),
         recurse_type(s, ast.values, visit),
      }
   end,
   ["record"] = record_like_type_walker,
   ["interface"] = record_like_type_walker,
   ["function"] = function<S, T>(s: S, ast: FunctionType, visit: Visitor<S, TypeName, Type, T>): {T}
      local xs: {T} = {}
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
   ["nominal"] = function<S, T>(s: S, ast: NominalType, visit: Visitor<S, TypeName, Type, T>): {T}
      local xs: {T} = {}
      if ast.typevals then
         for _, child in ipairs(ast.typevals) do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
      return xs
   end,
   ["typearg"] = function<S, T>(s: S, ast: TypeArgType, visit: Visitor<S, TypeName, Type, T>): {T}
      return {
         ast.constraint and recurse_type(s, ast.constraint, visit)
      }
   end,
   ["array"] = function<S, T>(s: S, ast: ArrayType, visit: Visitor<S, TypeName, Type, T>): {T}
      return {
         recurse_type(s, ast.elements, visit)
      }
   end,
   ["literal_table_item"] = function<S, T>(s: S, ast: LiteralTableItemType, visit: Visitor<S, TypeName, Type, T>): {T}
      return {
         recurse_type(s, ast.ktype, visit),
         recurse_type(s, ast.vtype, visit),
      }
   end,
   ["typedecl"] = function<S, T>(s: S, ast: TypeDeclType, visit: Visitor<S, TypeName, Type, T>): {T}
      return {
         recurse_type(s, ast.def, visit)
      }
   end,
}

recurse_type = function<S, T>(s: S, ast: Type, visit: Visitor<S, TypeName, Type, T>): T
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

   local xs: {T}
   local walker = type_walkers[ast.typename]
   if not walker is boolean then
      xs = walker(s, ast, visit)
   end

   local ret: T
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

local function recurse_typeargs<S, T>(s: S, ast: Node, visit_type: Visitor<S, TypeName, Type, T>)
   if ast.typeargs then
      for _, typearg in ipairs(ast.typeargs) do
         recurse_type(s, typearg, visit_type)
      end
   end
end

local function extra_callback<S, T>(name: VisitorExtraCallback,
                                    s: S,
                                    ast: Node,
                                    xs: {T},
                                    visit_node: Visitor<S, NodeKind, Node, T>)
   local cbs = visit_node.cbs
   if not cbs then return end
   local nbs = cbs[ast.kind]
   if not nbs then return end
   local bs = nbs[name]
   if not bs then return end
   bs(s, ast, xs)
end

local no_traverse_nodes: {NodeKind : boolean} = {
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

function traversal.traverse_nodes<S, T>(s: S, root: types.Node,
                                  visit_node: Visitor<S, NodeKind, Node, T>,
                                  visit_type: Visitor<S, TypeName, Type, T>): T
   if not root then
      -- parse error
      return
   end

   local recurse: function(types.Node): T

   local function walk_children(ast: Node, xs: {T})
      for i, child in ipairs(ast) do
         xs[i] = recurse(child)
      end
   end

   local function walk_vars_exps(ast: Node, xs: {T})
      xs[1] = recurse(ast.vars)
      if ast.decltuple then
         xs[2] = recurse_type(s, ast.decltuple, visit_type)
      end
      extra_callback("before_exp", s, ast, xs, visit_node)
      if ast.exps then
         xs[3] = recurse(ast.exps)
      end
   end

   local function walk_named_function(ast: Node, xs: {T})
      recurse_typeargs(s, ast, visit_type)
      xs[1] = recurse(ast.name)
      xs[2] = recurse(ast.args)
      xs[3] = recurse_type(s, ast.rets, visit_type)
      extra_callback("before_statements", s, ast, xs, visit_node)
      xs[4] = recurse(ast.body)
   end

   local walkers: {NodeKind : function(Node, {T})} = {
      ["op"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.e1)
         local p1 = ast.e1.op and ast.e1.op.prec or nil
         if ast.op.op == ":" and ast.e1.kind == "string" then
            p1 = -999
         end
         xs[2] = p1 as T
         if ast.op.arity == 2 then
            extra_callback("before_e2", s, ast, xs, visit_node)
            if ast.op.op == "is" or ast.op.op == "as" then
               xs[3] = recurse_type(s, ast.e2.casttype, visit_type)
            else
               xs[3] = recurse(ast.e2)
            end
            xs[4] = (ast.e2.op and ast.e2.op.prec) as T
         end
      end,

      ["statements"] = walk_children,
      ["argument_list"] = walk_children,
      ["literal_table"] = walk_children,
      ["variable_list"] = walk_children,
      ["expression_list"] = walk_children,

      ["literal_table_item"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.key)
         xs[2] = recurse(ast.value)
         if ast.itemtype then
            xs[3] = recurse_type(s, ast.itemtype, visit_type)
         end
      end,

      ["assignment"] = walk_vars_exps,
      ["local_declaration"] = walk_vars_exps,
      ["global_declaration"] = walk_vars_exps,

      ["local_type"] = function(ast: Node, xs: {T})
         -- TODO need to recurse typeargs
         -- recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.var)
         xs[2] = recurse(ast.value)
      end,

      ["global_type"] = function(ast: Node, xs: {T})
         -- TODO need to recurse typeargs
         -- recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.var)
         if ast.value then
            xs[2] = recurse(ast.value)
         end
      end,

      ["if"] = function(ast: Node, xs: {T})
         for _, e in ipairs(ast.if_blocks) do
            table.insert(xs, recurse(e))
         end
      end,

      ["if_block"] = function(ast: Node, xs: {T})
         if ast.exp then
            xs[1] = recurse(ast.exp)
         end
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[2] = recurse(ast.body)
      end,

      ["while"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.exp)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[2] = recurse(ast.body)
      end,

      ["repeat"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.body)
         xs[2] = recurse(ast.exp)
      end,

      ["macroexp"] = function(ast: Node, xs: {T})
         recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.args)
         xs[2] = recurse_type(s, ast.rets, visit_type)
         extra_callback("before_exp", s, ast, xs, visit_node)
         xs[3] = recurse(ast.exp)
      end,

      ["function"] = function(ast: Node, xs: {T})
         recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.args)
         xs[2] = recurse_type(s, ast.rets, visit_type)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[3] = recurse(ast.body)
      end,
      ["local_function"] = walk_named_function,
      ["global_function"] = walk_named_function,
      ["record_function"] = function(ast: Node, xs: {T})
         recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.fn_owner)
         xs[2] = recurse(ast.name)
         extra_callback("before_arguments", s, ast, xs, visit_node)
         xs[3] = recurse(ast.args)
         xs[4] = recurse_type(s, ast.rets, visit_type)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[5] = recurse(ast.body)
      end,
      ["local_macroexp"] = function(ast: Node, xs: {T})
         -- TODO: generic macroexp
         xs[1] = recurse(ast.name)
         xs[2] = recurse(ast.macrodef.args)
         xs[3] = recurse_type(s, ast.macrodef.rets, visit_type)
         extra_callback("before_exp", s, ast, xs, visit_node)
         xs[4] = recurse(ast.macrodef.exp)
      end,

      ["forin"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.vars)
         xs[2] = recurse(ast.exps)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[3] = recurse(ast.body)
      end,

      ["fornum"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.var)
         xs[2] = recurse(ast.from)
         xs[3] = recurse(ast.to)
         xs[4] = ast.step and recurse(ast.step)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[5] = recurse(ast.body)
      end,

      ["return"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.exps)
      end,

      ["do"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.body)
      end,

      ["paren"] = function(ast: Node, xs:{T})
         xs[1] = recurse(ast.e1)
      end,

      ["newtype"] = function(ast: Node, xs:{T})
         xs[1] = recurse_type(s, ast.newtype, visit_type)
      end,

      ["argument"] = function(ast: Node, xs:{T})
         if ast.argtype then
            xs[1] = recurse_type(s, ast.argtype, visit_type)
         end
      end,
   }

   if not visit_node.allow_missing_cbs and not visit_node.cbs then
      error("missing cbs in visit_node")
   end
   local visit_after = visit_node.after

   recurse = function(ast: Node): T
      local xs: {T} = {}
      local kind = assert(ast.kind)
      local kprint: string

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
         kprint = kind == "op" and "op " .. ast.op.op
                  or kind == "identifier" and "identifier " .. ast.tk
                  or kind
         tldebug.indent_push("{{{", ast.y, ast.x, "[%s]", kprint)
      end

      local fn = walkers[kind]
      if fn then
         fn(ast, xs)
      else
         assert(no_traverse_nodes[kind])
      end

      local ret: T
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
