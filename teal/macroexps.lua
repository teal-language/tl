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
