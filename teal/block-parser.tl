local reader = require("teal.reader")
local type Block = reader.Block
local errors = require("teal.errors")
local type Error = errors.Error
local type Where = errors.Where

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
local enum ParseTypeListMode
   "rets"
   "decltuple"
   "casttype"
end

local parse_type: function(state: ParseState, block: Block): Type
local parse_type_list: function(state: ParseState, block: Block, mode: ParseTypeListMode): TupleType
local parse_typeargs_if_any: function(state: ParseState, block: Block): {TypeArgType}

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

local function end_at(node: Node, block: Block)
   if block then
      node.yend = block.yend or block.y
      node.xend = block.xend or (block.x + #(block.tk or "") - 1)
   end
end

local function new_node(state: ParseState, block: Block, kind?: NodeKind): Node
   if not block then
      return nil
   end
   local node = setmetatable({ 
      f = state.filename, 
      y = block.y, 
      x = block.x, 
      tk = block.tk, 
      kind = kind or (block.kind as NodeKind) 
   } as Node, node_mt)
   end_at(node, block)
   return node
end

local function fail(state: ParseState, block: Block, msg: string): boolean
   table.insert(state.errs, {
      filename = state.filename,
      y = block and block.y or 1,
      x = block and block.x or 1,
      msg = assert(msg, "syntax error, but no error message provided"),
   })
   return false
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
   if not block then
      -- empty expr list
      local dummy_block = { kind = "expression_list", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      return new_node(state, dummy_block, "expression_list")
   end
   local node = new_node(state, block, "expression_list")
   if not node then
      local dummy_block = { kind = "expression_list", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "expression_list")
   end
   return parse_list(state, block, node, parse_expression)
end

local function parse_variable_list(state: ParseState, block: Block): Node
   if not block then
      -- Create a dummy block for an empty variable list
      local dummy_block = { kind = "variable_list", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      return new_node(state, dummy_block, "variable_list")
   end
   local node = new_node(state, block, "variable_list")
   if not node then
      local dummy_block = { kind = "variable_list", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "variable_list")
   end
   for _, var_block in ipairs(block) do
      local var_node = new_node(state, var_block)
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
   if not block then
      local dummy_block = { kind = "argument_list", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      return new_node(state, dummy_block, "argument_list")
   end
   
   local node = new_node(state, block, "argument_list")
   if not node then
      local dummy_block = { kind = "argument_list", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "argument_list")
   end
   
   local min_arity = 0
   local has_optional = false
   local has_varargs = false
   
   for a, arg_block in ipairs(block) do
      local arg_node = new_node(state, arg_block, "argument")
      if not arg_node then
         fail(state, arg_block, "invalid argument")
      else
         -- Handle varargs
         if arg_block.tk == "..." then
            if a < #block then
               fail(state, arg_block, "'...' can only be the last argument")
            end
            has_varargs = true
            arg_node.kind = "..."
         else
            local is_optional = false
            if is_optional then
               arg_node.opt = true
               has_optional = true
            elseif has_optional and not has_varargs then
               fail(state, arg_block, "non-optional argument follows optional argument")
            end
            
            if not is_optional and not has_varargs then
               min_arity = min_arity + 1
            end
         end
         
         table.insert(node, arg_node)
      end
   end
   
   node.min_arity = min_arity
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
      if not node.e1 then
         -- Create a dummy error node if first expression failed to parse
         local dummy_block = { kind = "error_node", y = block.y or 1, x = block.x or 1, tk = "", yend = block.yend or 1, xend = block.xend or 1 } as Block
         node.e1 = new_node(state, dummy_block, "error_node")
      end
      if op_info.arity == 2 then
         if op_info.op == "@funcall" then
            node.e2 = parse_expression_list(state, block[2])
         elseif op_info.op == "as" or op_info.op == "is" then
            node.e2 = new_node(state, block[2], "cast")
            if node.e2 and block[2] and block[2][1] then
               node.e2.casttype = parse_type(state, block[2][1])
            end
         elseif op_info.op == "." then
            -- For dot operations, the right-hand side should be treated as an identifier
            node.e2 = new_node(state, block[2], "identifier")
            if not node.e2 then
               local dummy_block = { kind = "identifier", y = block.y or 1, x = block.x or 1, tk = "", yend = block.yend or 1, xend = block.xend or 1 } as Block
               node.e2 = new_node(state, dummy_block, "identifier")
            end
         else
            node.e2 = parse_expression(state, block[2])
            if not node.e2 then
               local dummy_block = { kind = "error_node", y = block.y or 1, x = block.x or 1, tk = "", yend = block.yend or 1, xend = block.xend or 1 } as Block
               node.e2 = new_node(state, dummy_block, "error_node")
            end
         end
      end
      return node
   end

   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "error_node", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "error_node")
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
      -- Set all required fields for function expression
      node.typeargs = {} --TODO
      node.args = parse_argument_list(state, block[3])
      node.min_arity = node.args and #node.args or 0
      node.rets = parse_type_list(state, block[4], "rets")
      node.body = parse_statements(state, block[5])
   end
   return node
end

local function new_type(state: ParseState, block: Block, typename: TypeName): Type
   return raw_type(state.filename, block.y, block.x, typename)
end

local function new_typedecl(state: ParseState, block: Block, def: FirstClassType): TypeDeclType
   local t = new_type(state, block, "typedecl") as TypeDeclType
   t.def = def
   return t
end

local function parse_newtype(state: ParseState, block: Block): Node
   local node = new_node(state, block, "newtype")
   if not node then
      local dummy_block = { kind = "newtype", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "newtype")
   end
   
   -- Default to an "any" type if nothing else can be parsed
   local default_type = new_type(state, block, "any") as FirstClassType
   node.newtype = new_typedecl(state, block, default_type)
   
   -- The block should contain the type definition 
   if block[1] then
      local def_block = block[1]
      if def_block.kind == "typedecl" and def_block[1] then
         -- This is a complex type like enum, record, etc.
         local inner_type = def_block[1]
         local typename = inner_type.kind
         if typename as string == "enum" then
            local enum_type = new_type(state, inner_type, "enum") as EnumType
            enum_type.enumset = {}
            for i = 1, #inner_type do
               local value_block = inner_type[i]
               if value_block and value_block.tk then
                  local value_str = value_block.tk
                  if value_str:match('^".*"$') or value_str:match("^'.*'$") then
                     value_str = value_str:sub(2, -2)
                  end
                  enum_type.enumset[value_str] = true
               end
            end
            enum_type.declname = state.filename or "anonymous" -- Will be set later by the caller
            node.newtype = new_typedecl(state, def_block, enum_type)
         else
            local type_node = parse_type(state, inner_type)
            if type_node then
               node.newtype = new_typedecl(state, def_block, type_node as FirstClassType)
               if type_node.typename == "nominal" then
                  node.newtype.is_alias = true
               end
            end
         end
      else
         local type_node = parse_type(state, def_block)
         if type_node then
            node.newtype = new_typedecl(state, block, type_node as FirstClassType)
            if type_node.typename == "nominal" then
               node.newtype.is_alias = true
            end
         end
      end
   end
   
   return node
end

local type ParseFn = function(state: ParseState, block: Block): Node
local parse_fns: {string: ParseFn} = {}

parse_fns.local_declaration = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "local_declaration", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "local_declaration")
   end
   node.vars = parse_variable_list(state, block[1])
   local next_child = 2
   if block[next_child] and block[next_child].kind == "tuple_type" then
      node.decltuple = parse_type_list(state, block[next_child], "decltuple")
      next_child = 3
   else
      -- Always set decltuple, even if empty, to match regular parser behavior
      -- TODO: I aint too sure abt this one...
      local dummy_block = { kind = "tuple_type", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      dummy_block[1] = { kind = "typelist", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node.decltuple = parse_type_list(state, dummy_block, "decltuple")
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
      local dummy_block = { kind = "assignment", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "assignment")
   end
   node.vars = parse_variable_list(state, block[1])
   node.exps = parse_expression_list(state, block[2])
   return node
end

parse_fns["if"] = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "if", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "if")
   end
   
   node.if_blocks = {}
   
   -- The structure from the reader is:
   -- if -> [1] (kind=nil, not "nil" string) -> array of if_block nodes
   -- Each if_block has [1] = expression (for if/elseif) or statements (for else)
   -- Each if_block has [2] = statements (for if/elseif only)
   
   local if_blocks_container = block[1]
   if not if_blocks_container then
      fail(state, block, "if statement missing condition blocks")
      return node
   end
   
   for i, if_block_block in ipairs(if_blocks_container) do
      local if_block_node = new_node(state, if_block_block, "if_block")
      if not if_block_node then
         fail(state, if_block_block, "invalid if block")
      else
         if_block_node.if_parent = node
         if_block_node.if_block_n = i
         
         if #if_block_block == 2 then 
            -- if or elseif (has expression and statements)
            if_block_node.exp = parse_expression(state, if_block_block[1])
            if not if_block_node.exp then
               fail(state, if_block_block[1], "invalid condition expression")
            end
            if_block_node.body = parse_statements(state, if_block_block[2])
         else 
            -- else (has only statements)
            if_block_node.body = parse_statements(state, if_block_block[1])
         end
         
         if not if_block_node.body then
            fail(state, if_block_block, "invalid block body")
         end
         
         table.insert(node.if_blocks, if_block_node)
      end
   end
   
   if #node.if_blocks == 0 then
      fail(state, block, "if statement has no blocks")
   end
   
   return node
end

parse_fns["while"] = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "while", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "while")
   end
   
   if not block[1] then
      fail(state, block, "while statement missing condition")
      return node
   end
   if not block[2] then
      fail(state, block, "while statement missing body")
      return node
   end
   
   node.exp = parse_expression(state, block[1])
   if not node.exp then
      fail(state, block[1], "invalid while condition")
   end
   
   node.body = parse_statements(state, block[2])
   if not node.body then
      fail(state, block[2], "invalid while body")
   end
   
   return node
end

parse_fns.fornum = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "fornum", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "fornum")
   end

   -- [1] = variable (loop variable)
   -- [2] = from expression
   -- [3] = to expression 
   -- [4] = step expression (optional)
   -- [5] = body statements
   
   node.var = new_node(state, block[1], "variable")
   
   node.from = parse_expression(state, block[2])
   if node.from and node.from.kind == "integer" then
      node.from.kind = "number"
   end
   
   node.to = parse_expression(state, block[3])
   if node.to and node.to.kind == "integer" then
      node.to.kind = "number"
   end
   
   if block[5] then
      -- We have a step value
      node.step = parse_expression(state, block[4])
      if node.step and node.step.kind == "integer" then
         node.step.kind = "number"
      end
      node.body = parse_statements(state, block[5])
   else
      -- No step, block[4] is the body
      node.body = parse_statements(state, block[4])
   end
   
   return node
end

parse_fns.forin = function(state: ParseState, block: Block): Node
   local node = new_node(state, block, "forin")
   if not node then
      local dummy_block = { kind = "forin", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "forin")
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
      local dummy_block = { kind = "repeat", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "repeat")
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
      local dummy_block = { kind = "do", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "do")
   end
   node.body = parse_statements(state, block[1])
   return node
end

parse_fns["return"] = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "return", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "return")
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
      local dummy_block = { kind = "goto", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "goto")
   end
   if block[1] then
      node.label = block[1].tk
   end
   return node
end

parse_fns.label = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "label", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "label")
   end
   if block[1] then
      node.label = block[1].tk
   end
   return node
end

parse_fns.local_function = function(state: ParseState, block: Block): Node
   local node = new_node(state, block, "local_function")
   if not node then
      local dummy_block = { kind = "local_function", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "local_function")
   end
   
   if not block[1] then
      fail(state, block, "local function missing name")
      return node
   end
   if not block[3] then
      fail(state, block, "local function missing argument list")
      return node
   end
   if not block[5] then
      fail(state, block, "local function missing body")
      return node
   end
   
   node.name = new_node(state, block[1], "identifier")
   if not node.name then
      fail(state, block[1], "invalid function name")
      return node
   end
   
   node.typeargs = parse_typeargs_if_any(state, block[2])
   node.args = parse_argument_list(state, block[3])
   node.min_arity = node.args and node.args.min_arity or 0
   node.rets = parse_type_list(state, block[4], "rets")
   node.body = parse_statements(state, block[5])
   
   if not node.body then
      fail(state, block[5], "invalid function body")
   end
   
   return node
end

parse_fns.global_function = function(state: ParseState, block: Block): Node
   local node = new_node(state, block, "global_function")
   if not node then
      local dummy_block = { kind = "global_function", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "global_function")
   end

   if not block[1] then
      fail(state, block, "global function missing name")
      return node
   end
   if not block[3] then
      fail(state, block, "global function missing argument list")
      return node
   end
   if not block[5] then
      fail(state, block, "global function missing body")
      return node
   end

   node.name = new_node(state, block[1], "identifier")
   if not node.name then
      fail(state, block[1], "invalid function name")
      return node
   end

   node.typeargs = parse_typeargs_if_any(state, block[2])
   node.args = parse_argument_list(state, block[3])
   node.min_arity = node.args and node.args.min_arity or 0
   node.rets = parse_type_list(state, block[4], "rets")
   node.body = parse_statements(state, block[5])

   if not node.body then
      fail(state, block[5], "invalid function body")
   end

   return node
end

parse_fns.record_function = function(state: ParseState, block: Block): Node
   local node = new_node(state, block, "record_function")
   if not node then
      local dummy_block = { kind = "record_function", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "record_function")
   end
   
   if not block[1] then
      fail(state, block, "record function missing owner")
      return node
   end
   if not block[2] then
      fail(state, block, "record function missing name")
      return node
   end
   if not block[4] then
      fail(state, block, "record function missing argument list")
      return node
   end
   if not block[6] then
      fail(state, block, "record function missing body")
      return node
   end
   
   local owner_block = block[1]
   local name_block = block[2]

   node.fn_owner = new_node(state, owner_block, "type_identifier")
   if not node.fn_owner then
      fail(state, owner_block, "invalid function owner")
      return node
   end

   node.name = new_node(state, name_block, "identifier")
   if not node.name then
      fail(state, name_block, "invalid function name")
      return node
   end

   node.typeargs = parse_typeargs_if_any(state, block[3])

   node.is_method = false
   node.args = parse_argument_list(state, block[4])
   node.min_arity = node.args and node.args.min_arity or 0
   node.rets = parse_type_list(state, block[5], "rets")
   node.body = parse_statements(state, block[6])
   
   if not node.body then
      fail(state, block[6], "invalid function body")
   end
   
   return node
end

parse_fns.pragma = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "pragma", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "pragma")
   end
   --pkey should be [1] and pvalue should be [2]
   if block[1] then
      node.pkey = block[1].tk
   end
   if block[2] then
      node.pvalue = block[2].tk
   end
   return node
end

parse_fns.local_type = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "local_type", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "local_type")
   end
   if block[1] then
      node.var = new_node(state, block[1])
   end
   if block[2] then
      node.value = parse_newtype(state, block[2])
   end
   return node
end
parse_fns.global_type = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "global_type", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "global_type")
   end
   if block[1] then
      node.var = new_node(state, block[1])
   end
   if block[2] then
      node.value = parse_newtype(state, block[2])
   end
   return node
end
parse_fns.interface = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "interface", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "interface")
   end
   return node
end
parse_fns.local_macroexp = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "local_macroexp", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "local_macroexp")
   end
   return node
end
parse_fns.macroexp = function(state: ParseState, block: Block): Node
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "macroexp", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
      node = new_node(state, dummy_block, "macroexp")
   end
   return node
end




parse_block = function(state: ParseState, block: Block): Node
   if not block then return nil end

   local kind = block.kind as string
   if kind == "forin" then
      return parse_forin(state, block)
   elseif kind == "interface" then
      local node = new_node(state, block, "interface")
      if not node then
         local dummy_block = { kind = "interface", y = 1, x = 1, tk = "", yend = 1, xend = 1 } as Block
         node = new_node(state, dummy_block, "interface")
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

local parse_base_type: function(state: ParseState, block: Block): FirstClassType
local parse_simple_type_or_nominal: function(state: ParseState, block: Block): FirstOrderType
local parse_function_type: function(state: ParseState, block: Block): FunctionType

parse_typeargs_if_any = function(state: ParseState, block: Block): {TypeArgType}
   local out: {TypeArgType} = {}
   if block and block.kind == "typelist" then
      for _, ta_block in ipairs(block) do
         if ta_block.kind == "typeargs" then
            local ta = new_type(state, ta_block, "typearg") as TypeArgType
            if ta_block[1] then
               ta.typearg = ta_block[1].tk
            end
            if ta_block[2] then
               ta.constraint = parse_type(state, ta_block[2])
            end
            table.insert(out, ta)
         end
      end
   end
   return out
end

parse_function_type = function(state: ParseState, block: Block): FunctionType
   local typ = new_type(state, block, "function") as FunctionType

   typ.args = parse_type_list(state, block[1], "decltuple")
   typ.rets = parse_type_list(state, block[2], "rets")
   typ.is_method = false
   typ.min_arity = 0

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

   if block.kind == "nominal_type" then
      local idx = 1
      if block[1] and block[1].kind == "identifier" then
         typ.names = { block[1].tk }
         idx = 2
      else
         typ.names = { tk }
      end
      while block[idx] and block[idx].kind == "identifier" do
         table.insert(typ.names, block[idx].tk)
         idx = idx + 1
      end
      if block[idx] and block[idx].kind == "typelist" then
         typ.typevals = {}
         for _, tv in ipairs(block[idx]) do
            table.insert(typ.typevals, parse_type(state, tv) as FirstOrderType)
         end
      end
   end

   return typ
end

parse_base_type = function(state: ParseState, block: Block): FirstClassType
   if not block then
      fail(state, { y = 1, x = 1 } as Block, "expected a type")
      return new_type(state, { y = 1, x = 1 } as Block, "any") as FirstClassType
   end

   local tk = block.tk

   if block.kind == "identifier" or block.kind == "nominal_type" or simple_types[tk as TypeName] then
      return parse_simple_type_or_nominal(state, block)
   elseif block.kind == "function" then
      return parse_function_type(state, block)
  elseif block.kind == "generic_type" then
      local typeargs = parse_typeargs_if_any(state, block[1])
      local base = parse_base_type(state, block[2]) as FirstOrderType
      return new_generic(state, block, typeargs, base)
   elseif block.kind as string == "record" then
      local decl = new_type(state, block, "record") as RecordType
      decl.fields = {}
      decl.field_order = {}
      return decl
   elseif block.kind as string == "interface" then
      local decl = new_type(state, block, "interface") as InterfaceType
      decl.fields = {}
      decl.field_order = {}
      decl.interface_list = {}
      return decl
   elseif block.kind == "array_type" then
      local decl = new_type(state, block, "array") as ArrayType
      decl.elements = parse_type(state, block[1])
      return decl
   elseif block.kind == "map_type" then
      local decl = new_type(state, block, "map") as MapType
      decl.keys = parse_type(state, block[1])
      decl.values = parse_type(state, block[2])
      return decl
   elseif block.kind == "typelist" and block.tk == "{" then
      local decl = new_type(state, block, "tupletable") as TupleTableType
      decl.types = {}
      for _, t in ipairs(block) do
         table.insert(decl.types, parse_type(state, t))
      end
      return decl
   elseif block.kind == "union_type" then
      local u = new_type(state, block, "union") as UnionType
      u.types = {}
      for _, t in ipairs(block) do
         table.insert(u.types, parse_type(state, t))
      end
      return u
   elseif block.kind == "nil" then
      return new_type(state, block, "nil") as NilType
   end

   fail(state, block, "expected a type")
   return new_type(state, block, "any") as FirstClassType
end

parse_type = function(state: ParseState, block: Block): Type
   if not block then
      return new_type(state, { y = 1, x = 1 } as Block, "any")
   end
   
   if block.kind == "paren" then
      if not block[1] then
         fail(state, block, "empty parentheses in type")
         return new_type(state, block, "any")
      end
      return parse_type(state, block[1])
   end

   if block.kind == "union_type" then
      local u = new_type(state, block, "union") as UnionType
      u.types = {}
      for _, t in ipairs(block) do
         table.insert(u.types, parse_base_type(state, t))
      end
      return u
   end

   if block.kind == "typelist" and block.tk == "{" then
      return parse_base_type(state, block)
   end

   local bt: FirstClassType = parse_base_type(state, block)
   if not bt then
      fail(state, block, "failed to parse type")
      return new_type(state, block, "any")
   end
   
   return bt
end

parse_type_list = function(state: ParseState, block: Block, _mode: ParseTypeListMode): TupleType
   local t, list = new_tuple(state, block or { y = 1, x = 1 } as Block)

   if not block then
      return t
   end

   if block.kind == "tuple_type" then
      if block[1] and block[1].kind == "..." then
         t.is_va = true
         block = block[2]
      else
         block = block[1]
      end
   end

   if block and block.kind == "typelist" then
      for _, type_block in ipairs(block) do
         table.insert(list, parse_type(state, type_block))
      end
   else
      table.insert(list, parse_type(state, block))
   end

   return t
end

function block_parser.parse_type(state: ParseState, block: Block): Type
   return parse_type(state, block)
end

function block_parser.parse_type_list(state: ParseState, block: Block, mode: ParseTypeListMode): TupleType
   return parse_type_list(state, block, mode)
end

return block_parser

