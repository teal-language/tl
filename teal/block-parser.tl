local reader = require("teal.reader")
local type Block = reader.Block
local errors = require("teal.errors")
local type Error = errors.Error

local types = require("teal.types")
local type Type = types.Type
local type GenericType = types.GenericType
local type FirstOrderType = types.FirstOrderType
local type StructuralType = types.StructuralType
local type TypeDeclType = types.TypeDeclType
local type NominalType = types.NominalType
local type SelfType = types.SelfType
local type ArrayType = types.ArrayType
local type RecordLikeType = types.RecordLikeType
local type RecordType = types.RecordType
local type InterfaceType = types.InterfaceType
local type TupleType = types.TupleType
local type TypeArgType = types.TypeArgType
local type MapType = types.MapType
local type NilType = types.NilType
local type FunctionType = types.FunctionType
local type UnionType = types.UnionType
local type TupleTableType = types.TupleTableType
local type PolyType = types.PolyType
local type EnumType = types.EnumType
local type FirstClassType = types.FirstClassType
local type TypeName = types.TypeName
local type Where = types.Where
local a_type = types.a_type
local raw_type = types.raw_type
local simple_types = types.simple_types

local facts = require("teal.facts")
local type Fact = facts.Fact

local lexer = require("teal.lexer")
local type Token = lexer.Token
local type TokenKind = lexer.TokenKind

local enum NodeKind
   "op"
   "nil"
   "string"
   "number"
   "integer"
   "boolean"
   "literal_table"
   "literal_table_item"
   "function"
   "expression_list"
   "if"
   "if_block"
   "while"
   "fornum"
   "forin"
   "goto"
   "label"
   "repeat"
   "do"
   "break"
   "return"
   "newtype"
   "argument"
   "type_identifier"
   "variable"
   "variable_list"
   "statements"
   "assignment"
   "argument_list"
   "local_function"
   "global_function"
   "local_type"
   "global_type"
   "record_function"
   "local_declaration"
   "global_declaration"
   "identifier"
   "cast"
   "..."
   "paren"
   "macroexp"
   "local_macroexp"
   "interface"
   "pragma"
   "error_node"
end

local record Node
   is {Node}, types.Node, Where
   where self.kind ~= nil

   record ExpectedContext
      kind: NodeKind
      name: string
   end

   tk: string
   kind: NodeKind
   symbol_list_slot: integer
   semicolon: boolean
   hashbang: string

   is_longstring: boolean

   yend: integer
   xend: integer

   known: Fact

   -- bidirectional inference
   expected: Type
   expected_context: Node.ExpectedContext

   key: Node
   value: Node
   key_parsed: KeyParsed

   typeargs: {TypeArgType}
   min_arity: integer
   args: Node
   rets: TupleType
   body: Node
   implicit_global_function: boolean
   is_predeclared_local_function: boolean

   name: Node

   -- statements list in a `repeat`, delay closing scope
   is_repeat: boolean

   -- var declaration
   attribute: Attribute

   fn_owner: Node
   is_method: boolean

   exp: Node
   if_parent: Node
   if_block_n: integer
   if_blocks: {Node}
   if_widens: {string: boolean}
   block_returns: boolean

   -- fornum
   var: Node
   from: Node
   to: Node
   step: Node

   -- forin
   vars: Node
   exps: Node

   -- newtype
   newtype: TypeDeclType
   elide_type: boolean

   -- expressions
   op: Operator
   e1: Node
   e2: Node
   constnum: number
   conststr: string
   failstore: boolean
   discarded_tuple: boolean
   receiver: Type

   -- table literal
   array_len: integer
   is_total: boolean
   missing: {string}

   -- goto
   label: string

   -- label
   used_label: boolean

   casttype: Type

   -- variable
   is_lvalue: boolean

   -- macroexp
   macrodef: Node
   expanded: Node

   argtype: Type
   itemtype: Type
   decltuple: TupleType

   -- pragma
   pkey: string
   pvalue: string

   opt: boolean

   debug_type: Type
end

local enum ParseLang
   "lua"
   "tl"
end

local record Operator
   y: integer
   x: integer
   arity: integer
   op: string
   prec: integer
end

local enum KeyParsed
   "short"
   "long"
   "implicit"
end

local enum Attribute
   "const"
   "close"
   "total"
end


local record block_parser
   type Attribute = Attribute
   type Node = Node
   type NodeKind = NodeKind
   type ParseLang = ParseLang

   parse: function(input: Block, filename: string, parse_lang?: ParseLang): types.Node, {Error}, {string}
   operator: function(Node, integer, string): Operator
   
   -- Type parsing functions
   parse_type: function(state: ParseState, block: Block): Type
   parse_type_list: function(state: ParseState, block: Block, mode: ParseTypeListMode): TupleType
end

local attributes <total>: {Attribute: boolean} = {
   ["const"] = true,
   ["close"] = true,
   ["total"] = true,
}
local is_attribute <const>: {string:boolean} = attributes as {string:boolean}

local metamethod_names: {string:boolean} = {
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

local precedences: {integer:{string:integer}} = {
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
local record OpKind
   op: string
   arity: integer
end
local op_kinds: {string: OpKind} = {
   op_not = { op = "not", arity = 1 },
   op_len = { op = "#", arity = 1 },
   op_unm = { op = "-", arity = 1 },
   op_bnot = { op = "~", arity = 1 },
   op_or = { op = "or", arity = 2 },
   op_and = { op = "and", arity = 2 },
   op_is = { op = "is", arity = 2 },
   op_lt = { op = "<", arity = 2 },
   op_gt = { op = ">", arity = 2 },
   op_le = { op = "<=", arity = 2 },
   op_ge = { op = ">=", arity = 2 },
   op_ne = { op = "~=", arity = 2 },
   op_eq = { op = "==", arity = 2 },
   op_bor = { op = "|", arity = 2 },
   op_bxor = { op = "~", arity = 2 },
   op_band = { op = "&", arity = 2 },
   op_shl = { op = "<<", arity = 2 },
   op_shr = { op = ">>", arity = 2 },
   op_concat = { op = "..", arity = 2 },
   op_add = { op = "+", arity = 2 },
   op_sub = { op = "-", arity = 2 },
   op_mul = { op = "*", arity = 2 },
   op_div = { op = "/", arity = 2 },
   op_idiv = { op = "//", arity = 2 },
   op_mod = { op = "%", arity = 2 },
   op_pow = { op = "^", arity = 2 },
   op_as = { op = "as", arity = 2 },
   op_funcall = { op = "@funcall", arity = 2 },
   op_index = { op = "@index", arity = 2 },
   op_dot = { op = ".", arity = 2 },
   op_colon = { op = ":", arity = 2 },
}

local record ParseState
   block: Block
   errs: {Error}
   filename: string
   end_alignment_hint: Error

   required_modules: {string}
   parse_lang: ParseLang
end

local node_mt: metatable<Node> = {
   __tostring = function(n: Node): string
      return n.f .. ":" .. n.y .. ":" .. n.x .. " " .. n.kind
   end
}

local function new_node(ps: ParseState, b: Block, kind?: NodeKind): Node
   if not b then
      return nil
   end
   local node = setmetatable({ f = ps.filename, y = b.y, x = b.x, tk = b.tk, kind = kind or (b.kind as NodeKind) } as Node, node_mt)
   node.yend = b.yend
   node.xend = b.xend
   return node
end

local function fail(state: ParseState, block: Block, msg: string)
   return table.insert(state.errs, {
      filename = state.filename,
      y = block.y,
      x = block.x,
      msg = msg,
   })
end

local parse_block: function(state: ParseState, block: Block): Node
local parse_expression: function(state: ParseState, block: Block): Node

local function parse_list(state: ParseState, block: Block, node: Node, parse_fn: function(ParseState, Block):Node): Node
   if not block then return node end
   for _, item_block in ipairs(block) do
      local parsed_item = parse_fn(state, item_block)
      if parsed_item then
         table.insert(node, parsed_item)
      end
   end
   return node
end

local function parse_expression_list(state: ParseState, block: Block): Node
   local node = new_node(state, block, "expression_list")
   if not node then
      return nil
   end
   return parse_list(state, block, node, parse_expression)
end

local function parse_variable_list(state: ParseState, block: Block): Node
   local node = new_node(state, block, "variable_list")
   if not node then
      return nil
   end
   for _, var_block in ipairs(block) do
      local var_node = new_node(state, var_block, "variable")
      if var_node then
         if var_block[1] then
            local annotation = var_block[1]
            if not is_attribute[annotation.tk] then
               fail(state, annotation, "unknown variable annotation: " .. annotation.tk)
            end
            var_node.attribute = annotation.tk as Attribute
         end
         table.insert(node, var_node)
      end
   end
   return node
end

local function parse_argument_list(state: ParseState, block: Block): Node
   local node = new_node(state, block, "argument_list")
   if not node then
      return nil
   end
   node.min_arity = 0
   local opts = false
   for a, arg_block in ipairs(block) do
      local arg_node = new_node(state, arg_block, "argument")
      if arg_node then
         if arg_block.tk == "..." then
            if a < #block then
               fail(state, arg_block, "'...' can only be last argument")
            end
         end
         -- if arg_block.opt then
         --    arg_node.opt = true
         --    opts = true
         -- elseif opts then
         if opts then
            fail(state, arg_block, "non-optional argument follows optional argument")
         end
         table.insert(node, arg_node)
      end
   end
   return node
end

local function parse_statements(state: ParseState, block: Block): Node
   if not block then
      local dummy_block = { kind = "statements", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      return new_node(state, dummy_block, "statements")
   end
   local node = new_node(state, block, "statements")
   
   return parse_list(state, block, node, parse_block)
end

local function parse_forin(state: ParseState, block: Block): Node
   local node = new_node(state, block, "forin")
   node.vars = parse_variable_list(state, block[1])
   node.exps = parse_expression_list(state, block[2])
   if #node.exps < 1 then
      fail(state, block[2], "missing iterator expression in generic for")
   elseif #node.exps > 3 then
      fail(state, block[2], "too many expressions in generic for")
   end
   node.body = parse_statements(state, block[3])
   return node
end

local function node_is_require_call(n: Node): string
   if n.kind == "op" and n.op.op == "." then
      -- `require("str").something`
      return node_is_require_call(n.e1)
   elseif n.kind == "op" and n.op.op == "@funcall"
      and n.e1.kind == "variable" and n.e1.tk == "require"
      and n.e2.kind == "expression_list" and #n.e2 == 1
      and n.e2[1].kind == "string"
   then
      -- `require("str")`
      return n.e2[1].conststr
   end
   return nil -- table.insert cares about arity
end

parse_expression = function(state: ParseState, block: Block): Node
   if not block then return nil end

   local kind = block.kind as string
   local op_info = op_kinds[kind]

   if op_info then
      local node = new_node(state, block, "op")
      node.op = {
         y = block.y,
         x = block.x,
         arity = op_info.arity,
         op = op_info.op,
         prec = precedences[op_info.arity][op_info.op]
      }
      node.e1 = parse_expression(state, block[1])
      if op_info.arity == 2 then
         if op_info.op == "@funcall" then
            node.e2 = parse_expression_list(state, block[2])
         elseif op_info.op == "as" or op_info.op == "is" then
            node.e2 = new_node(state, block[2], "cast")
            -- block[2][1] is the type, ignore for now
         else
            node.e2 = parse_expression(state, block[2])
         end
      end
      return node
   end

   local node = new_node(state, block)
   if not node then
      return nil
   end

   if kind == "string" then
      node.conststr = block.conststr
   elseif kind == "number" or kind == "integer" then
      node.kind = kind as NodeKind
      node.constnum = block.constnum
   elseif kind == "boolean" then
      node.kind = kind as NodeKind
   elseif kind == "identifier" or kind == "variable" then
      node.kind = "variable"
   elseif kind == "paren" then
      node.e1 = parse_expression(state, block[1])
   elseif kind == "literal_table" then
      for _, item_block in ipairs(block) do
         local item_node = new_node(state, item_block, "literal_table_item")
         if item_node then
            item_node.key = parse_expression(state, item_block[1])
            item_node.value = parse_expression(state, item_block[2])
            table.insert(node, item_node)
         end
      end
   elseif kind == "function" then
      node.args = parse_argument_list(state, block[3])
      node.body = parse_statements(state, block[5])
   end
   return node
end

local type ParseFn = function(state: ParseState, block: Block): Node
local parse_fns: {string: ParseFn} = {}

parse_fns.local_declaration = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      return nil
   end
   node.vars = parse_variable_list(state, block[1])
   local next_child = 2
   if block[next_child] and block[next_child].kind == "tuple_type" then
      next_child = 3
   end
   if block[next_child] then
      node.exps = parse_expression_list(state, block[next_child])
   end
   return node
end
parse_fns.global_declaration = parse_fns.local_declaration

parse_fns.assignment = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      return nil
   end
   node.vars = parse_variable_list(state, block[1])
   node.exps = parse_expression_list(state, block[2])
   return node
end

parse_fns["if"] = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      return nil
   end
   node.if_blocks = {}
   
   -- The structure from the reader is:
   -- if -> [1] (kind=nil, not "nil" string) -> array of if_block nodes
   -- Each if_block has [1] = expression (for if/elseif) or statements (for else)
   -- Each if_block has [2] = statements (for if/elseif only)
   -- Yes, this kind of sucks...
   
   local if_blocks_container = block[1]
   if if_blocks_container then
      for i, if_block_block in ipairs(if_blocks_container) do
         local if_block_node = new_node(state, if_block_block, "if_block")
         if if_block_node then
            if_block_node.if_block_n = i
            if #if_block_block == 2 then -- if or elseif (has expression and statements)
               if_block_node.exp = parse_expression(state, if_block_block[1])
               if_block_node.body = parse_statements(state, if_block_block[2])
            else -- else (has only statements)
               if_block_node.body = parse_statements(state, if_block_block[1])
            end
            table.insert(node.if_blocks, if_block_node)
         end
      end
   end
   return node
end

parse_fns["while"] = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      return nil
   end
   node.exp = parse_expression(state, block[1])
   node.body = parse_statements(state, block[2])
   return node
end

parse_fns.fornum = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      return nil
   end
   
   local var_node = new_node(state, block, "variable")
   if var_node then
      var_node.tk = "i"
   end
   node.var = var_node
   
   node.from = parse_expression(state, block[1])
   -- convert integer literals in numeric for loops to number
   -- TODO: I don't think this is a good idea
   if node.from and node.from.kind == "integer" then
      node.from.kind = "number"
   end
   
   node.to = parse_expression(state, block[2])
   if node.to and node.to.kind == "integer" then
      node.to.kind = "number"
   end
   
   if block[3] then
      -- We have a step value
      node.step = parse_expression(state, block[3])
      if node.step and node.step.kind == "integer" then
         node.step.kind = "number"
      end
   end
   
   node.body = parse_statements(state, block[4])
   
   return node
end

parse_fns.forin = function(state: ParseState, block: Block): Node
   local node = new_node(state, block, "forin")
   if not node then
      return nil
   end
   node.vars = parse_variable_list(state, block[1])
   node.exps = parse_expression_list(state, block[2])
   if node.exps and #node.exps < 1 then
      fail(state, block[2], "missing iterator expression in generic for")
   elseif node.exps and #node.exps > 3 then
      fail(state, block[2], "too many expressions in generic for")
   end
   node.body = parse_statements(state, block[3])
   return node
end

parse_fns["repeat"] = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      return nil
   end
   node.body = parse_statements(state, block[1])
   if node.body then
      node.body.is_repeat = true
   end
   node.exp = parse_expression(state, block[2])
   return node
end

parse_fns["do"] = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      return nil
   end
   node.body = parse_statements(state, block[1])
   return node
end

parse_fns["return"] = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      return nil
   end
   node.exps = parse_expression_list(state, block[1])
   return node
end

parse_fns["break"] = function(state: ParseState, block: Block): Node
   return new_node(state, block)
end

parse_fns["goto"] = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      return nil
   end
   node.label = block[1].tk
   return node
end

parse_fns.label = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      return nil
   end
   node.label = block[1].tk
   return node
end

parse_fns.local_function = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      return nil
   end
   node.name = new_node(state, block[1], "variable")
   node.args = parse_argument_list(state, block[3])
   node.body = parse_statements(state, block[5])
   return node
end

parse_fns.global_function = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      return nil
   end
   node.name = new_node(state, block[1], "variable")
   node.args = parse_argument_list(state, block[3])
   node.body = parse_statements(state, block[5])
   return node
end

parse_fns.record_function = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      return nil
   end
   local owner_block = block[1]
   local name_block = block[2]
   --TODO: Check if method

   node.fn_owner = parse_expression(state, owner_block)
   node.name = parse_expression(state, name_block)

   node.args = parse_argument_list(state, block[4])
   node.body = parse_statements(state, block[6])
   return node
end

parse_fns.pragma = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      return nil
   end
   --pkey should be [1] and pvalue should be [2]
   node.pkey = block[1].tk
   if block[2] then
      node.pvalue = block[2].tk
   end
   return node
end

parse_fns.local_type = function(state: ParseState, block: Block): Node
   return new_node(state, block)
end
parse_fns.global_type = function(state: ParseState, block: Block): Node
   return new_node(state, block)
end
parse_fns.interface = function(state: ParseState, block: Block): Node
   return new_node(state, block)
end
parse_fns.local_macroexp = function(state: ParseState, block: Block): Node
   return new_node(state, block)
end
parse_fns.macroexp = function(state: ParseState, block: Block): Node
   return new_node(state, block)
end

local enum ParseTypeListMode
   "rets"
   "decltuple"
   "casttype"
end



parse_block = function(state: ParseState, block: Block): Node
   if not block then return nil end

   local kind = block.kind as string
   if kind == "forin" then
      return parse_forin(state, block)
   elseif kind == "interface" then
      local node = new_node(state, block, "interface")
      if not node then
         return nil
      end
      return node
   elseif kind == "local_type" or kind == "global_type" then
      local node = new_node(state, block)
      if not node then
         return nil
      end
      
      -- Check if this is actually an interface declaration
      -- Interface structure: local_type -> [2] -> newtype -> [1] -> typedecl -> [1] -> interface
      if block[2] and block[2].kind == "newtype" and 
         block[2][1] and block[2][1].kind == "typedecl" and
         block[2][1][1] and block[2][1][1].kind == "interface" then
         local interface_node = new_node(state, block, "interface")
         if not interface_node then
            return nil
         end
         return interface_node
      end
      
      node[1] = new_node(state, block[1], "type_identifier")
      if block[2] then
         local expr_block = block[2]

         if expr_block.kind == "op_funcall" and expr_block[1].kind == "identifier" and expr_block[1].tk == "pcall" then
            fail(state, expr_block, "pcall() cannot be used in type declarations")
         end

         local function get_base_block(b: Block): Block
            if b.kind == "op_dot" or b.kind == "op_funcall" then
               if b[1] then
                  return get_base_block(b[1])
               end
            end
            return b
         end
         local base_block = get_base_block(expr_block)

         if base_block.kind == "variable" and base_block.tk == "require" then
            if expr_block.kind ~= "op_funcall" and expr_block.kind ~= "op_dot" and expr_block.kind ~= "variable" then
               fail(state, expr_block, "require() in type declarations cannot be part of larger expressions")
            end
            local require_node = parse_expression(state, expr_block)
            if not node_is_require_call(require_node) then
               fail(state, expr_block, "require() for type declarations must have a literal argument")
            end
            node[2] = require_node
         else
            node[2] = parse_expression(state, expr_block)
         end
      end
      return node
   end
   if kind == "local_declaration" then
      local node = new_node(state, block, "local_declaration")
      if not node then
         return nil
      end
      node.vars = parse_variable_list(state, block[1])
      local next_child = 2
      if block[next_child] and block[next_child].kind == "tuple_type" then
         next_child = 3
      end
      if block[next_child] then
         node.exps = parse_expression_list(state, block[next_child])
      end
      return node
   end
   local f = parse_fns[block.kind]
   if f then
      return f(state, block)
   else
      return parse_expression(state, block)
   end
end

function block_parser.parse(input: Block, filename: string, parse_lang?: ParseLang): types.Node, {Error}, {string}
   if not input then
      return nil, {{ filename = filename, y = 1, x = 1, msg = "input is nil" }}, {}
   end

   local state: ParseState = {
      block = input,
      errs = {},
      filename = filename,
      end_alignment_hint = nil,
      required_modules = {},
      parse_lang = parse_lang or "tl",
   }

   local nodes = parse_statements(state, input)
   if #state.errs > 0 then
      return nil, state.errs, state.required_modules
   end

   return nodes, {}, state.required_modules
end

local function new_type(state: ParseState, block: Block, typename: TypeName): Type
   return raw_type(state.filename, block.y, block.x, typename)
end


local function new_generic(state: ParseState, block: Block, typeargs: {TypeArgType}, typ: FirstOrderType): GenericType
   local gt = new_type(state, block, "generic") as GenericType
   gt.typeargs = typeargs
   gt.t = typ
   return gt
end



local function new_tuple(state: ParseState, block: Block, typelist?: {Type}, is_va?: boolean): TupleType, {Type}
   local t = new_type(state, block, "tuple") as TupleType
   t.is_va = is_va
   t.tuple = typelist or {}
   return t, t.tuple
end

local function new_nominal(state: ParseState, block: Block, name?: string): NominalType
   local t = new_type(state, block, "nominal") as NominalType
   if name then
      t.names = { name }
   end
   return t
end

local parse_type: function(state: ParseState, block: Block): Type
local parse_type_list: function(state: ParseState, block: Block, mode: ParseTypeListMode): TupleType
local parse_typeargs_if_any: function(state: ParseState, block: Block): {TypeArgType}
local parse_base_type: function(state: ParseState, block: Block): FirstClassType
local parse_simple_type_or_nominal: function(state: ParseState, block: Block): FirstOrderType
local parse_function_type: function(state: ParseState, block: Block): GenericType | FunctionType





parse_typeargs_if_any = function(_state: ParseState, _block: Block): {TypeArgType}
   return {}
end





parse_function_type = function(state: ParseState, block: Block): GenericType | FunctionType
   local typeargs: {TypeArgType} = {}
   local typ = new_type(state, block, "function") as FunctionType
   
   typeargs = parse_typeargs_if_any(state, block)
   
   -- For now, set default function signature - will need to enhance when reader provides arg/ret types
   typ.args = new_tuple(state, block, { new_type(state, block, "any") }, true)
   typ.rets = new_tuple(state, block, { new_type(state, block, "any") }, true)
   typ.is_method = false
   typ.min_arity = 0

   if #typeargs > 0 then
      return new_generic(state, block, typeargs, typ)
   end

   return typ
end

parse_simple_type_or_nominal = function(state: ParseState, block: Block): FirstOrderType
   local tk = block.tk
   local st = simple_types[tk as TypeName]
   if st then
      return new_type(state, block, tk as TypeName) as StructuralType
   elseif tk == "table" then
      local typ = new_type(state, block, "map") as MapType
      typ.keys = new_type(state, block, "any")
      typ.values = new_type(state, block, "any")
      return typ
   end

   local typ = new_nominal(state, block, tk)
   
   -- Handle type arguments if present in sub-blocks
   if block[1] and block[1].kind == "typeargs" then
      typ.typevals = {}
      for _, tv in ipairs(block[1]) do
         table.insert(typ.typevals, parse_type(state, tv) as FirstOrderType)
      end
   end
   
   return typ
end

parse_base_type = function(state: ParseState, block: Block): FirstClassType
   local tk = block.tk
   
   if block.kind == "identifier" or simple_types[tk as TypeName] then
      return parse_simple_type_or_nominal(state, block)
   elseif tk == "function" then
      return parse_function_type(state, block)
   elseif tk == "nil" then
      return new_type(state, block, "nil") as NilType
   elseif block.kind == "literal_table" then
      -- Handle array type {T} or map type {K:V}
      if #block == 1 then
         local decl = new_type(state, block, "array") as ArrayType
         decl.elements = parse_type(state, block[1])
         return decl
      elseif #block == 2 then
         local decl = new_type(state, block, "map") as MapType
         decl.keys = parse_type(state, block[1])
         decl.values = parse_type(state, block[2])
         return decl
      else
         local decl = new_type(state, block, "tupletable") as TupleTableType
         decl.types = {}
         for _, t in ipairs(block) do
            table.insert(decl.types, parse_type(state, t))
         end
         return decl
      end
   end
   
   fail(state, block, "expected a type")
   return new_type(state, block, "any") as FirstClassType
end

parse_type = function(state: ParseState, block: Block): Type
   if not block then
      return nil
   end
   
   -- Handle parenthesized types
   if block.kind == "paren" then
      return parse_type(state, block[1])
   end

   local bt: FirstClassType = parse_base_type(state, block)
   if not bt then
      return nil
   end
   
   -- Handle union types - check if this is a union type block
   if block.kind == "typelist" and #block > 1 then
      local u = new_type(state, block, "union") as UnionType
      u.types = {}
      for _, t in ipairs(block) do
         table.insert(u.types, parse_base_type(state, t))
      end
      bt = u
   end
   
   return bt
end

parse_type_list = function(state: ParseState, block: Block, _mode: ParseTypeListMode): TupleType
   local t, list = new_tuple(state, block)

   if not block then
      return t
   end

   if block.kind == "tuple_type" then
      for _, type_block in ipairs(block) do
         local parsed_type = parse_type(state, type_block)
         if parsed_type then
            table.insert(list, parsed_type)
         end
      end
   else
      -- Single type
      local parsed_type = parse_type(state, block)
      if parsed_type then
         table.insert(list, parsed_type)
      end
   end

   return t
end

-- Add the type parsing functions to the exported interface
function block_parser.parse_type(state: ParseState, block: Block): Type
   return parse_type(state, block)
end

function block_parser.parse_type_list(state: ParseState, block: Block, mode: ParseTypeListMode): TupleType
   return parse_type_list(state, block, mode)
end

return block_parser

