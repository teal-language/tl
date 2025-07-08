local type type_checker = require("teal.check.type_checker")
local type TypeChecker = type_checker.TypeChecker

local parser = require("teal.parser")
local type Node = parser.Node
local type NodeKind = parser.NodeKind
local node_at = parser.node_at

local traversal = require("teal.traversal")
local type VisitorAfter = traversal.VisitorAfter
local type Visitor = traversal.Visitor
local traverse_nodes = traversal.traverse_nodes

local type types = require("teal.types")

local util = require("teal.util")
local shallow_copy_table = util.shallow_copy_table

local record macroexps
   expand: function(orignode: Node, args: {Node}, macroexp: types.Node)
   apply: function(orignode: Node)
end

local type OnArgId = function<T>(node: Node, i: integer): T
local type OnNode = function<S, T>(s: S, node: Node, children: {T}, ret: T): T

local function traverse_macroexp<T>(macroexp: Node, on_arg_id: OnArgId<T>, on_node: OnNode<nil, T>): T
   local root = macroexp.exp
   local argnames = {}
   for i, a in ipairs(macroexp.args) do
      argnames[a.tk] = i
   end

   local visit_node: Visitor<nil, NodeKind, Node, T> = {
      cbs = {
         ["variable"] = {
            after = function(_: nil, node: Node, _children: {T}): T
               local i = argnames[node.tk]
               if not i then
                  return nil
               end

               return on_arg_id(node, i)
            end
         },
         ["..."] = {
            after = function(_: nil, node: Node, _children: {T}): T
               local i = argnames[node.tk]
               if not i then
                  return nil
               end

               return on_arg_id(node, i)
            end
         }
      },
      after = on_node as VisitorAfter<nil, Node, T>,
   }

   return traverse_nodes(nil, root, visit_node, {})
end

function macroexps.expand(orignode: Node, args: {Node}, macroexp: types.Node)
   local on_arg_id = function(node: Node, i: integer): {Node, Node}
      if node.kind == '...' then
         -- we have to handle varargs specifically
         local nd: Node = node_at(orignode, {
            kind = "expression_list",
         })
         for n = i, #args do
            nd[n - i + 1] = args[n]
         end
         return { Node, nd }
      else
         -- the function should have already been typechecked for optional
         -- parameters.
         -- this one is optional, so return nil
         local nd: Node = args[i] or node_at(orignode, { kind = "nil", tk = "nil" })
         return { Node, nd }
      end
   end

   local on_node = function(_: nil, node: Node, children: {{Node, Node}}, ret: {Node, Node}): {Node, Node}
      local orig = ret and ret[2] or node

      local out = shallow_copy_table(orig)

      local map = {}
      for _, pair in pairs(children as {integer:{Node, Node}}) do
         if type(pair) == "table" then
            map[pair[1]] = pair[2]
         end
      end

      for k, v in pairs(orig as {any:Node}) do
         if type(v) == "table" and map[v] then
            (out as {any:any})[k] = map[v]
         end
      end

      out.yend = out.yend and (orignode.y + (out.yend - out.y)) or nil
      out.xend = nil
      out.y = orignode.y
      out.x = orignode.x
      return { node, out }
   end

   local p = traverse_macroexp(macroexp as Node, on_arg_id, on_node)
   orignode.expanded = p[2]
end

function macroexps.check_arg_use(ck: TypeChecker, macroexp: Node)
   local used: {string:boolean} = {}

   local on_arg_id = function(node: Node, _i: integer): {Node, Node}
      if used[node.tk] then
         ck:add_error(node, "cannot use argument '" .. node.tk .. "' multiple times in macroexp")
      else
         used[node.tk] = true
      end
   end

   traverse_macroexp(macroexp, on_arg_id, nil)
end

function macroexps.apply(orignode: Node)
   local expanded = orignode.expanded
   orignode.expanded = nil

   for k, _ in pairs(orignode as {any:any}) do
      (orignode as {any:any})[k] = nil
   end
   for k, v in pairs(expanded as {any:any}) do
      (orignode as {any:any})[k] = v
   end
end

return macroexps
