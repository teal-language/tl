local context = require("teal.check.context")
local type Context = context.Context

local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG

local type environment = require("teal.environment")
local type Env = environment.Env
local type Result = environment.Result

local type errors = require("teal.errors")
local type Where = errors.Where

local type parser = require("teal.parser")
local type Node = parser.Node
local type NodeKind = parser.NodeKind

local type traversal = require("teal.traversal")
local type VisitorAfter = traversal.VisitorAfter
local type Visitor = traversal.Visitor
local traverse_nodes = traversal.traverse_nodes

local types = require("teal.types")
local type Type = types.Type
local type TypeName = types.TypeName
local a_type = types.a_type

local util = require("teal.util")
local shallow_copy_table = util.shallow_copy_table

local variables = require("teal.variables")

local visitors = require("teal.check.visitors")
local visit_node = visitors.visit_node
local visit_type = visitors.visit_type

local record check
   check: function(ast: Node, env: Env, filename: string): Result
end

local type VisitorAfterPatcher = function<S, N, T>(VisitorAfter<S, N, T>): VisitorAfter<S, N, T>

local function internal_compiler_check<S, N>(fn: VisitorAfter<S, N, Type>): VisitorAfter<S, N, Type>
   return function(s: S, n: N, children: {Type}, t: Type): Type
      t = fn and fn(s, n, children, t) or t

      if type(t) ~= "table" then
         error(((n as Node).kind or (n as Type).typename) .. " did not produce a type")
      end
      if type(t.typename) ~= "string" then
         error(((n as Node).kind or (n as Type).typename) .. " type does not have a typename")
      end

      return t
   end
end

local function store_type_after<N>(fn: VisitorAfter<Context, N, Type>): VisitorAfter<Context, N, Type>
   return function(self: Context, n: N, children: {Type}, t: Type): Type
      t = fn and fn(self, n, children, t) or t

      local w = n as Where

      if w.y then
         self.collector.store_type(w.y, w.x, t)
      end

      return t
   end
end

local function debug_type_after<S>(fn: VisitorAfter<S, Node, Type>): VisitorAfter<S, Node, Type>
   return function(s: S, node: Node, children: {Type}, t: Type): Type
      t = fn and fn(s, node, children, t) or t

      node.debug_type = t
      return t
   end
end

local function patch_visitors(my_visit_node: Visitor<Context, NodeKind, Node, Type>,
                              after_node: VisitorAfterPatcher<Context, Node, Type>,
                              my_visit_type?: Visitor<Context, TypeName, Type, Type>,
                              after_type?: VisitorAfterPatcher<Context, Type, Type>):
                              Visitor<Context, NodeKind, Node, Type>,
                              Visitor<Context, TypeName, Type, Type>
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

function check.check(ast: Node, env: Env, filename: string): Result
   assert(filename)

   local self = Context.new(env, filename)

   local visit_node, visit_type = visit_node, visit_type
   if env.opts.run_internal_compiler_checks then
      visit_node, visit_type = patch_visitors(
         visit_node, internal_compiler_check,
         visit_type, internal_compiler_check
      )
   end
   if self.collector then
      visit_node, visit_type = patch_visitors(
         visit_node, store_type_after,
         visit_type, store_type_after
      )
   end
   if TL_DEBUG then
      visit_node, visit_type = patch_visitors(
         visit_node, debug_type_after
      )
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
