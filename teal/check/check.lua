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
