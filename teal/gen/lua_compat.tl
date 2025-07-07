local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG

local type environment = require("teal.environment")
local type GenCompat = environment.GenCompat
local type Result = environment.Result

local parser = require("teal.parser")
local type Node = parser.Node
local type NodeKind = parser.NodeKind
local node_at = parser.node_at

local metamethods = require("teal.metamethods")
local unop_to_metamethod = metamethods.unop_to_metamethod
local binop_to_metamethod = metamethods.binop_to_metamethod

local traversal = require("teal.traversal")
local type Visitor = traversal.Visitor
local traverse_nodes = traversal.traverse_nodes

local util = require("teal.util")
local sorted_keys = util.sorted_keys

local record lua_compat
end

local compat_code_cache: {string:Node} = {}

local function add_compat_entries(program: Node, used_set: {string: boolean}, gen_compat: GenCompat)
   if not next(used_set) or gen_compat == "off" then
      return
   end

   local tl_debug = TL_DEBUG
   TL_DEBUG = nil

   local used_list: {string} = sorted_keys(used_set)

   local compat_loaded = false

   local n = 1
   local function load_code(name: string, text: string)
      local code: Node = compat_code_cache[name]
      if not code then
         code = parser.parse(text, "@<internal>.lua") as Node
         compat_code_cache[name] = code
      end
      for _, c in ipairs(code) do
         table.insert(program, n, c)
         n = n + 1
      end
   end

   local function req(m: string): string
      return (gen_compat == "optional")
             and "pcall(require, '" .. m .. "')"
             or  "true, require('" .. m .. "')"
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

local function convert_node_to_compat_call(node: Node, mod_name: string, fn_name: string, e1: Node, e2?: Node)
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

local function convert_node_to_compat_mt_call(node: Node, mt_name: string, which_self: integer, e1: Node, e2?: Node)
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

local bit_operators: {string:string} = {
   ["&"] = "band",
   ["|"] = "bor",
   ["~"] = "bxor",
   [">>"] = "rshift",
   ["<<"] = "lshift",
}

local function adjust_code(ast: Node, needs_compat: {string:boolean}, gen_compat: GenCompat, gen_target: string)
   if gen_target == "5.4" then
      return
   end

   local visit_node: Visitor<nil, NodeKind, Node, nil> = {
      cbs = {}
   }

   if gen_compat ~= "off" then
      visit_node.cbs["op"] = {
         after = function(_: nil, node: Node, _children: {nil}): nil
            if node.op.op == "is" then
               if node.e2.casttype.typename == "integer" then
                  needs_compat["math"] = true
               elseif node.e2.casttype.typename ~= "nil" then
                  needs_compat["type"] = true
               end
            elseif node.op.op == "." then
               if node.op.needs_compat then
                  -- only apply to a literal use, not a propagated type
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
                  local div: Node = node_at(node, { kind = "op", op = parser.operator(node, 2, "/"), e1 = node.e1, e2 = node.e2 })
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
         end
      }
   end

   traverse_nodes(nil, ast, visit_node, {})

   add_compat_entries(ast, needs_compat, gen_compat)
end

function lua_compat.apply(result: Result)
   if result.compat_applied then
      return
   end
   result.compat_applied = true

   local gen_compat = result.env.opts.gen_compat or environment.DEFAULT_GEN_COMPAT
   local gen_target = result.env.opts.gen_target or environment.DEFAULT_GEN_TARGET

   adjust_code(result.ast, result.needs_compat, gen_compat, gen_target)
end

return lua_compat
