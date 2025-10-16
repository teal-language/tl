--------------------------------------------------------------------------------
-- Recursive descent parser
--------------------------------------------------------------------------------
local attributes = require("teal.attributes")
local type Attribute = attributes.Attribute
local is_attribute = attributes.is_attribute

local errors = require("teal.errors")
local type Where = errors.Where
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
local a_type = types.a_type
local raw_type = types.raw_type
local simple_types = types.simple_types

local lexer = require("teal.lexer")
local type Token = lexer.Token
local type TokenKind = lexer.TokenKind
local type Comment = lexer.Comment

local enum MetaMode
   "meta"
end

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
   comments: {Comment}
   symbol_list_slot: integer
   semicolon: boolean
   hashbang: string

   unattached_comments: {Comment}

   is_longstring: boolean

   yend: integer
   xend: integer

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
   meta_on_operand: integer
   needs_compat: boolean
end

local enum KeyParsed
   "short"
   "long"
   "implicit"
end

local record parser
   type Node = Node
   type NodeKind = NodeKind
   type ParseLang = ParseLang

   parse: function(input: string, filename: string): Node, {Error}, {string}
   operator: function(Node, integer, string): Operator
end

function parser.node_is_require_call(n: Node): string
   if not (n.e1 and n.e2) then
      return nil
   end
   if n.op and n.op.op == "." then
      -- `require("str").something`
      return parser.node_is_require_call(n.e1)
   elseif n.e1.kind == "variable" and n.e1.tk == "require"
      and n.e2.kind == "expression_list" and #n.e2 == 1
      and n.e2[1].kind == "string"
   then
      -- `require("str")`
      return n.e2[1].conststr
   end
   return nil -- table.insert cares about arity
end

function parser.node_is_funcall(node: Node): boolean
   return node.kind == "op" and node.op.op == "@funcall"
end

local record ParseState
   tokens: {Token}
   errs: {Error}
   filename: string
   end_alignment_hint: Error

   required_modules: {string}
   parse_lang: ParseLang
end

local enum ParseTypeListMode
   "rets"
   "decltuple"
   "casttype"
end

-- type names used by parse_type_body_fns
local enum BodyTypeName
   "interface"
   "record"
   "enum"
end

local parse_type_list: function(ParseState, integer, ParseTypeListMode): integer, TupleType
local parse_typeargs_if_any: function(ps: ParseState, i: integer): integer, {TypeArgType}
local parse_expression: function(ParseState, integer): integer, Node, integer
local parse_expression_and_tk: function(ps: ParseState, i: integer, tk: string): integer, Node
local parse_statements: function(ParseState, integer, ? boolean): integer, Node
local parse_argument_list: function(ParseState, integer): integer, Node, integer
local parse_argument_type_list: function(ParseState, integer): integer, TupleType, boolean, integer
local parse_type: function(ParseState, integer): integer, FirstClassType, integer
local parse_type_declaration: function(ps: ParseState, i: integer, node_name: NodeKind): integer, Node
local parse_interface_name: function(ps: ParseState, i: integer): integer, Type, integer

local type ParseBody = function(ps: ParseState, i: integer, def: Type): integer, boolean
local parse_enum_body: function(ps: ParseState, i: integer, def: EnumType): integer, boolean
local parse_record_body: function(ps: ParseState, i: integer, def: Type): integer, boolean
local parse_type_body_fns: {BodyTypeName:ParseBody}

local function fail(ps: ParseState, i: integer, msg: string): integer
   if not ps.tokens[i] then
      local eof = ps.tokens[#ps.tokens]
      table.insert(ps.errs, { filename = ps.filename, y = eof.y, x = eof.x, msg = msg or "unexpected end of file" })
      return #ps.tokens
   end
   table.insert(ps.errs, { filename = ps.filename, y = ps.tokens[i].y, x = ps.tokens[i].x, msg = assert(msg, "syntax error, but no error message provided") })
   return math.min(#ps.tokens, i + 1)
end

local function end_at(node: Node, tk: Token)
   node.yend = tk.y
   node.xend = tk.x + #tk.tk - 1
end

local function verify_tk(ps: ParseState, i: integer, tk: string): integer
   if ps.tokens[i].tk == tk then
      return i + 1
   end
   return fail(ps, i, "syntax error, expected '" .. tk .. "'")
end

local function verify_end(ps: ParseState, i: integer, istart: integer, node: Node): integer
   if ps.tokens[i].tk == "end" then
      local endy, endx = ps.tokens[i].y, ps.tokens[i].x
      node.yend = endy
      node.xend = endx + 2
      if node.kind ~= "function" and endy ~= node.y and endx ~= node.x then
         if not ps.end_alignment_hint then
            ps.end_alignment_hint = { filename = ps.filename, y = node.y, x = node.x, msg = "syntax error hint: construct starting here is not aligned with its 'end' at " .. ps.filename .. ":" .. endy .. ":" .. endx .. ":" }
         end
      end
      return i + 1
   end
   end_at(node, ps.tokens[i])
   if ps.end_alignment_hint then
      table.insert(ps.errs, ps.end_alignment_hint)
      ps.end_alignment_hint = nil
   end
   return fail(ps, i, "syntax error, expected 'end' to close construct started at " .. ps.filename .. ":" .. ps.tokens[istart].y .. ":" .. ps.tokens[istart].x .. ":")
end

local node_mt: metatable<Node> = {
   __tostring = function(n: Node): string
      return n.f .. ":" .. n.y .. ":" .. n.x .. " " .. n.kind
   end
}

local function new_node(ps: ParseState, i: integer, kind?: NodeKind): Node
   local t = ps.tokens[i]
   return setmetatable({ f = ps.filename, y = t.y, x = t.x, tk = t.tk, kind = kind or (t.kind as NodeKind) }, node_mt)
end

local function new_type(ps: ParseState, i: integer, typename: TypeName): Type
   local token = ps.tokens[i]
   return raw_type(ps.filename, token.y, token.x, typename)
end

local function new_first_order_type(ps: ParseState, i: integer, tn: BodyTypeName): FirstOrderType
   return new_type(ps, i, tn as TypeName) as FirstOrderType
end

local function new_generic(ps: ParseState, i: integer, typeargs: {TypeArgType}, typ: FirstOrderType): GenericType
   local gt = new_type(ps, i, "generic") as GenericType
   gt.typeargs = typeargs
   gt.t = typ
   return gt
end

local function new_typedecl(ps: ParseState, i: integer, def: FirstClassType): TypeDeclType
   local t = new_type(ps, i, "typedecl") as TypeDeclType
   t.def = def
   return t
end

local function new_tuple(ps: ParseState, i: integer, typelist?: {Type}, is_va?: boolean): TupleType, {Type}
   local t = new_type(ps, i, "tuple") as TupleType
   t.is_va = is_va
   t.tuple = typelist or {}
   return t, t.tuple
end

local function new_nominal(ps: ParseState, i: integer, name?: string): NominalType
   local t = new_type(ps, i, "nominal") as NominalType
   if name then
      t.names = { name }
   end
   return t
end

local function verify_kind(ps: ParseState, i: integer, kind: TokenKind, node_kind?: NodeKind): integer, Node
   if ps.tokens[i].kind == kind then
      return i + 1, new_node(ps, i, node_kind)
   end
   return fail(ps, i, "syntax error, expected " .. kind)
end

local type SkipFunction = function(ParseState, integer): integer, Node | boolean

local function skip(ps: ParseState, i: integer, skip_fn: SkipFunction): integer, Node | boolean
   local err_ps: ParseState = {
      filename = ps.filename,
      tokens = ps.tokens,
      errs = {},
      required_modules = {},
      parse_lang = ps.parse_lang,
   }
   return skip_fn(err_ps, i)
end

local function failskip(ps: ParseState, i: integer, msg: string, skip_fn: SkipFunction, starti?: integer): integer
   local skip_i = skip(ps, starti or i, skip_fn)
   fail(ps, i, msg)
   return skip_i
end

local function parse_type_body(ps: ParseState, i: integer, istart: integer, node: Node, tn: BodyTypeName): integer, GenericType | FirstOrderType
   local typeargs: {TypeArgType}
   local def: FirstOrderType
   i, typeargs = parse_typeargs_if_any(ps, i)

   def = new_first_order_type(ps, istart, tn)

   local ok: boolean
   i, ok = parse_type_body_fns[tn](ps, i, def)
   if not ok then
      return fail(ps, i, "expected a type")
   end

   i = verify_end(ps, i, istart, node)

   if typeargs then
      return i, new_generic(ps, istart, typeargs, def)
   end

   return i, def
end

local function skip_type_body(ps: ParseState, i: integer): integer, boolean
   local tn = ps.tokens[i].tk as BodyTypeName
   i = i + 1
   assert(parse_type_body_fns[tn], tn .. " has no parse body function")
   local ii, tt = parse_type_body(ps, i, i - 1, {}, tn)
   return ii, not not tt
end

local function parse_table_value(ps: ParseState, i: integer): integer, Node, integer
   local next_word = ps.tokens[i].tk
   if next_word == "record" or next_word == "interface" then
      local skip_i, e = skip(ps, i, skip_type_body)
      if e then
         fail(ps, i, next_word == "record"
                     and "syntax error: this syntax is no longer valid; declare nested record inside a record"
                     or  "syntax error: cannot declare interface inside a table; use a statement")
         return skip_i, new_node(ps, i, "error_node")
      end
   elseif next_word == "enum" and ps.tokens[i + 1].kind == "string" then
      i = failskip(ps, i, "syntax error: this syntax is no longer valid; declare nested enum inside a record", skip_type_body)
      return i, new_node(ps, i - 1, "error_node")
   end

   local e: Node
   i, e = parse_expression(ps, i)
   if not e then
      e = new_node(ps, i - 1, "error_node")
   end
   return i, e
end

local function parse_table_item(ps: ParseState, i: integer, n?: integer): integer, Node, integer
   local node = new_node(ps, i, "literal_table_item")
   if ps.tokens[i].kind == "$EOF$" then
      return fail(ps, i, "unexpected eof")
   end

   if ps.tokens[i].tk == "[" then
      node.key_parsed = "long"
      i = i + 1
      i, node.key = parse_expression_and_tk(ps, i, "]")
      i = verify_tk(ps, i, "=")
      i, node.value = parse_table_value(ps, i)
      return i, node, n
   elseif ps.tokens[i].kind == "identifier" then
      if ps.tokens[i+1].tk == "=" then
         node.key_parsed = "short"
         i, node.key = verify_kind(ps, i, "identifier", "string")
         node.key.conststr = node.key.tk
         node.key.tk = '"' .. node.key.tk .. '"'
         i = verify_tk(ps, i, "=")
         i, node.value = parse_table_value(ps, i)
         return i, node, n
      elseif ps.tokens[i+1].tk == ":" then
         node.key_parsed = "short"
         local orig_i = i
         local try_ps: ParseState = {
            filename = ps.filename,
            tokens = ps.tokens,
            errs = {},
            required_modules = ps.required_modules,
            parse_lang = ps.parse_lang,
         }
         i, node.key = verify_kind(try_ps, i, "identifier", "string")
         node.key.conststr = node.key.tk
         node.key.tk = '"' .. node.key.tk .. '"'
         i = verify_tk(try_ps, i, ":")
         i, node.itemtype = parse_type(try_ps, i)
         if node.itemtype and ps.tokens[i].tk == "=" then
            i = verify_tk(try_ps, i, "=")
            i, node.value = parse_table_value(try_ps, i)
            if node.value then
               for _, e in ipairs(try_ps.errs) do
                  table.insert(ps.errs, e)
               end
               return i, node, n
            end
         end
         -- backtrack:
         node.itemtype = nil
         i = orig_i
      end
   end

   node.key = new_node(ps, i, "integer")
   node.key_parsed = "implicit"
   node.key.constnum = n
   node.key.tk = tostring(n)
   i, node.value = parse_expression(ps, i)
   if not node.value then
      return fail(ps, i, "expected an expression")
   end
   return i, node, n + 1
end

local type ParseItem = function<T>(ParseState, integer, ? integer): integer, T, integer

local enum SeparatorMode
   "sep"
   "term"
end

local function parse_list<T>(ps: ParseState, i: integer, list: {T}, close: {string:boolean}, sep: SeparatorMode, parse_item: ParseItem<T>): integer, {T}
   local n = 1
   while ps.tokens[i].kind ~= "$EOF$" do
      if close[ps.tokens[i].tk] then
         end_at(list as Node, ps.tokens[i])
         break
      end
      local item: T
      local oldn = n
      i, item, n = parse_item(ps, i, n)
      n = n or oldn
      table.insert(list, item)
      if ps.tokens[i].tk == "," then
         i = i + 1
         if sep == "sep" and close[ps.tokens[i].tk] then
            fail(ps, i, "unexpected '" .. ps.tokens[i].tk .. "'")
            return i, list
         end
      elseif sep == "term" and ps.tokens[i].tk == ";" then
         i = i + 1
      elseif not close[ps.tokens[i].tk] then
         local options = {}
         for k, _ in pairs(close) do
            table.insert(options, "'" .. k .. "'")
         end
         table.sort(options)
         local first = options[1]:sub(2, -2)
         local msg: string
         -- heuristic for parenthesized lists
         if first == ")" and ps.tokens[i].tk == "=" then
            msg = "syntax error, cannot perform an assignment here (did you mean '=='?)"
            i = failskip(ps, i, msg, parse_expression, i + 1)
         else
            table.insert(options, "','")
            msg = "syntax error, expected one of: " .. table.concat(options, ", ")
            fail(ps, i, msg)
         end
         -- heuristic for error recovery to avoid a cascade of errors:
         -- * if we're parsing a bracketed list, assume the missing token is a separator;
         -- * otherwise, if we have a line break, insert expected terminator token.
         if first ~= "}" and ps.tokens[i].y ~= ps.tokens[i-1].y then
            -- FIXME closing token may not be a keyword (but non-keywords are checked with verify_tk, so it should work)
            table.insert(ps.tokens, i, { tk = first, y = ps.tokens[i-1].y, x = ps.tokens[i-1].x + 1, kind = "keyword" })
            return i, list
         end
      end
   end
   return i, list
end

local function parse_bracket_list<T>(ps: ParseState, i: integer, list: {T}, open: string, close: string, sep: SeparatorMode, parse_item: ParseItem<T>): integer, {T}
   i = verify_tk(ps, i, open)
   i = parse_list(ps, i, list, { [close] = true }, sep, parse_item)
   i = verify_tk(ps, i, close)
   return i, list
end

local function parse_table_literal(ps: ParseState, i: integer): integer, Node
   local node = new_node(ps, i, "literal_table")
   return parse_bracket_list(ps, i, node, "{", "}", "term", parse_table_item)
end

local function parse_trying_list<T>(ps: ParseState, i: integer, list: {T}, parse_item: ParseItem<T>, ret_lookahead?: boolean): integer, {T}
   local try_ps: ParseState = {
      filename = ps.filename,
      tokens = ps.tokens,
      errs = {},
      required_modules = ps.required_modules,
      parse_lang = ps.parse_lang
   }
   local tryi, item: integer, T = parse_item(try_ps, i)
   if not item then
      return i, list
   end
   for _, e in ipairs(try_ps.errs) do
      table.insert(ps.errs, e)
   end
   i = tryi
   table.insert(list, item)
   while ps.tokens[i].tk == ","
   and (not ret_lookahead
        or (not (ps.tokens[i + 1].kind == "identifier"
                 and ps.tokens[i + 2] and ps.tokens[i + 2].tk == ":")))
   do
      i = i + 1
      i, item = parse_item(ps, i)
      table.insert(list, item)
   end
   return i, list
end

local function parse_anglebracket_list<T is Type>(ps: ParseState, i: integer, parse_item: ParseItem<T>): integer, {T}
   local second = ps.tokens[i+1]
   if second.tk == ">" then
      return fail(ps, i+1, "type argument list cannot be empty")
   elseif second.tk == ">>" then
      -- tokenizer hack: consume one bracket from '>>', don't skip over it
      second.tk = ">"
      fail(ps, i+1, "type argument list cannot be empty")
      return i+1
   end

   local typelist: {T} = {}
   i = verify_tk(ps, i, "<")
   i = parse_list(ps, i, typelist, { [">"] = true, [">>"] = true, }, "sep", parse_item)
   if ps.tokens[i].tk == ">" then
      i = i + 1
   elseif ps.tokens[i].tk == ">>" then
      -- tokenizer hack: consume one bracket from '>>', don't increment i
      ps.tokens[i].tk = ">"
   else
      return fail(ps, i, "syntax error, expected '>'")
   end
   return i, typelist
end

local function parse_typearg(ps: ParseState, i: integer): integer, TypeArgType, integer
   local name = ps.tokens[i].tk
   local constraint: Type
   local t = new_type(ps, i, "typearg") as TypeArgType
   i = verify_kind(ps, i, "identifier")
   if ps.tokens[i].tk == "is" then
      i = i + 1
      i, constraint = parse_interface_name(ps, i) -- FIXME what about generic interfaces
   end
   t.typearg = name
   t.constraint = constraint
   return i, t
end

local function parse_return_types(ps: ParseState, i: integer): integer, TupleType
   local iprev = i - 1
   local t: TupleType
   i, t = parse_type_list(ps, i, "rets")
   if #t.tuple == 0 then
      t.x = ps.tokens[iprev].x
      t.y = ps.tokens[iprev].y
   end
   return i, t
end

parse_typeargs_if_any = function(ps: ParseState, i: integer): integer, {TypeArgType}
   if ps.tokens[i].tk == "<" then
      return parse_anglebracket_list(ps, i, parse_typearg)
   end
   return i
end

local function parse_function_type(ps: ParseState, i: integer): integer, GenericType | FunctionType
   local typeargs: {TypeArgType}
   local typ = new_type(ps, i, "function") as FunctionType
   i = i + 1

   i, typeargs = parse_typeargs_if_any(ps, i)
   if ps.tokens[i].tk == "(" then
      i, typ.args, typ.maybe_method, typ.min_arity = parse_argument_type_list(ps, i)
      i, typ.rets = parse_return_types(ps, i)
   else
      typ.args = new_tuple(ps, i, { new_type(ps, i, "any") }, true)
      typ.rets = new_tuple(ps, i, { new_type(ps, i, "any") }, true)
      typ.is_method = false
      typ.min_arity = 0
   end

   if typeargs then
      return i, new_generic(ps, i, typeargs, typ)
   end

   return i, typ
end

local function parse_simple_type_or_nominal(ps: ParseState, i: integer): integer, FirstOrderType
   local tk = ps.tokens[i].tk
   local st = simple_types[tk as TypeName]
   if st then
      return i + 1, new_type(ps, i, tk as TypeName) as StructuralType
   elseif tk == "table" and ps.tokens[i + 1].tk ~= "."  then
      local typ = new_type(ps, i, "map") as MapType
      typ.keys = new_type(ps, i, "any")
      typ.values = new_type(ps, i, "any")
      return i + 1, typ
   end

   local typ = new_nominal(ps, i, tk)
   i = i + 1
   while ps.tokens[i].tk == "." do
      i = i + 1
      if ps.tokens[i].kind == "identifier" then
         table.insert(typ.names, ps.tokens[i].tk)
         i = i + 1
      else
         return fail(ps, i, "syntax error, expected identifier")
      end
   end

   if ps.tokens[i].tk == "<" then
      i, typ.typevals = parse_anglebracket_list(ps, i, parse_type)
   end
   return i, typ
end

local function parse_base_type(ps: ParseState, i: integer): integer, FirstClassType, integer
   local tk = ps.tokens[i].tk
   if ps.tokens[i].kind == "identifier" then
      return parse_simple_type_or_nominal(ps, i)
   elseif tk == "{" then
      local istart = i
      i = i + 1
      local t: Type
      i, t = parse_type(ps, i)
      if not t then
         return i
      end
      if ps.tokens[i].tk == "}" then
         local decl = new_type(ps, istart, "array") as ArrayType
         decl.elements = t
         end_at(decl as Node, ps.tokens[i])
         i = verify_tk(ps, i, "}")
         return i, decl
      elseif ps.tokens[i].tk == "," then
         local decl = new_type(ps, istart, "tupletable") as TupleTableType
         decl.types = { t }
         local n = 2
         repeat
            i = i + 1
            i, decl.types[n] = parse_type(ps, i)
            if not decl.types[n] then
               break
            end
            n = n + 1
         until ps.tokens[i].tk ~= ","
         end_at(decl as Node, ps.tokens[i])
         i = verify_tk(ps, i, "}")
         return i, decl
      elseif ps.tokens[i].tk == ":" then
         local decl = new_type(ps, istart, "map") as MapType
         i = i + 1
         decl.keys = t
         i, decl.values = parse_type(ps, i)
         if not decl.values then
            return i
         end
         end_at(decl as Node, ps.tokens[i])
         i = verify_tk(ps, i, "}")
         return i, decl
      end
      return fail(ps, i, "syntax error; did you forget a '}'?")
   elseif tk == "function" then
      return parse_function_type(ps, i)
   elseif tk == "nil" then
      return i + 1, new_type(ps, i, "nil") as NilType
   end
   return fail(ps, i, "expected a type")
end

parse_type = function(ps: ParseState, i: integer): integer, FirstClassType, integer
   if ps.tokens[i].tk == "(" then
      i = i + 1
      local t: Type
      i, t = parse_type(ps, i)
      i = verify_tk(ps, i, ")")
      return i, t
   end

   local bt: FirstClassType
   local istart = i
   i, bt = parse_base_type(ps, i)
   if not bt then
      return i
   end
   if ps.tokens[i].tk == "|" then
      local u = new_type(ps, istart, "union") as UnionType
      u.types = { bt }
      while ps.tokens[i].tk == "|" do
         i = i + 1
         i, bt = parse_base_type(ps, i)
         if not bt then
            return i
         end
         table.insert(u.types, bt)
      end
      bt = u
   end
   return i, bt
end

parse_type_list = function(ps: ParseState, i: integer, mode: ParseTypeListMode): integer, TupleType
   local t, list = new_tuple(ps, i)

   local first_token = ps.tokens[i].tk
   if mode == "rets" or mode == "decltuple" then
      if first_token == ":" then
         i = i + 1
      else
         return i, t
      end
   end

   local optional_paren = false
   if ps.tokens[i].tk == "(" then
      optional_paren = true
      i = i + 1
   end

   local prev_i = i
   i = parse_trying_list(ps, i, list, parse_type, mode == "rets")
   if i == prev_i and ps.tokens[i].tk ~= ")" then
      fail(ps, i - 1, "expected a type list")
   end

   if mode == "rets" and ps.tokens[i].tk == "..." then
      i = i + 1
      local nrets = #list
      if nrets > 0 then
         t.is_va = true
      else
         fail(ps, i, "unexpected '...'")
      end
   end

   if optional_paren then
      i = verify_tk(ps, i, ")")
   end

   return i, t
end

local function parse_function_args_rets_body(ps: ParseState, i: integer, node: Node): integer, Node
   local istart = i - 1
   i, node.typeargs = parse_typeargs_if_any(ps, i)
   i, node.args, node.min_arity = parse_argument_list(ps, i)
   i, node.rets = parse_return_types(ps, i)
   i, node.body = parse_statements(ps, i)
   end_at(node, ps.tokens[i])
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_function_value(ps: ParseState, i: integer): integer, Node
   local node = new_node(ps, i, "function")
   i = verify_tk(ps, i, "function")
   return parse_function_args_rets_body(ps, i, node)
end

local function unquote(str: string): string, boolean
   local f = str:sub(1, 1)
   if f == '"' or f == "'" then
      return str:sub(2, -2), false
   end
   f = str:match("^%[=*%[")
   local l = #f + 1
   return str:sub(l, -l), true
end

local function parse_literal(ps: ParseState, i: integer): integer, Node
   local tk = ps.tokens[i].tk
   local kind = ps.tokens[i].kind
   if kind == "identifier" then
      return verify_kind(ps, i, "identifier", "variable")
   elseif kind == "string" then
      local node = new_node(ps, i, "string")
      node.conststr, node.is_longstring = unquote(tk)
      return i + 1, node
   elseif kind == "number" or kind == "integer" then
      local n = tonumber(tk)
      local node: Node
      i, node = verify_kind(ps, i, kind)
      node.constnum = n
      return i, node
   elseif tk == "true" then
      return verify_kind(ps, i, "keyword", "boolean")
   elseif tk == "false" then
      return verify_kind(ps, i, "keyword", "boolean")
   elseif tk == "nil" then
      return verify_kind(ps, i, "keyword", "nil")
   elseif tk == "function" then
      return parse_function_value(ps, i)
   elseif tk == "{" then
      return parse_table_literal(ps, i)
   elseif kind == "..." then
      return verify_kind(ps, i, "...")
   elseif kind == "$ERR$" then
      return fail(ps, i, "invalid token")
   end
   return fail(ps, i, "syntax error")
end

local function node_is_require_call_or_pcall(n: Node): string
   local r = parser.node_is_require_call(n)
   if r then
      return r
   end
   if parser.node_is_funcall(n)
      and n.e1 and n.e1.tk == "pcall"
      and n.e2 and #n.e2 == 2
      and n.e2[1].kind == "variable" and n.e2[1].tk == "require"
      and n.e2[2].kind == "string" and n.e2[2].conststr
   then
      -- `pcall(require, "str")`
      return n.e2[2].conststr
   end
   return nil -- table.insert cares about arity
end

do
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

   local is_right_assoc: {string:boolean} = {
      ["^"] = true,
      [".."] = true,
   }

   local function new_operator(tk: Token, arity: integer, op: string): Operator
      return { y = tk.y, x = tk.x, arity = arity, op = op, prec = precedences[arity][op] }
   end

   parser.operator = function(node: Node, arity: integer, op: string): Operator
      return { y = node.y, x = node.x, arity = arity, op = op, prec = precedences[arity][op] }
   end

   local args_starters: {TokenKind:boolean} = {
      ["("] = true,
      ["{"] = true,
      ["string"] = true,
   }

   local E: function(ParseState, integer, Node, integer): integer, Node

   local function after_valid_prefixexp(ps: ParseState, prevnode: Node, i: integer): boolean
      return ps.tokens[i - 1].kind == ")" -- '(' exp ')'
         or (prevnode.kind == "op"
             and (prevnode.op.op == "@funcall"
                  or prevnode.op.op == "@index"
                  or prevnode.op.op == "."
                  or prevnode.op.op == ":")
             )
         or prevnode.kind == "identifier"
         or prevnode.kind == "variable"
   end

   -- small hack: for the sake of `tl types`, parse an invalid binary exp
   -- as a paren to produce a unary indirection on e1 and save its location.
   local function failstore(ps: ParseState, tkop: Token, e1: Node): Node
      return { f = ps.filename, y = tkop.y, x = tkop.x, kind = "paren", e1 = e1, failstore = true }
   end

   local function P(ps: ParseState, i: integer): integer, Node
      if ps.tokens[i].kind == "$EOF$" then
         return i
      end
      local e1: Node
      local t1 = ps.tokens[i]
      if precedences[1][t1.tk] ~= nil then
         local op: Operator = new_operator(t1, 1, t1.tk)
         i = i + 1
         local prev_i = i
         i, e1 = P(ps, i)
         if not e1 then
            fail(ps, prev_i, "expected an expression")
            return i
         end
         e1 = { f = ps.filename, y = t1.y, x = t1.x, kind = "op", op = op, e1 = e1 }
      elseif ps.tokens[i].tk == "(" then
         i = i + 1
         local prev_i = i
         i, e1 = parse_expression_and_tk(ps, i, ")")
         if not e1 then
            fail(ps, prev_i, "expected an expression")
            return i
         end
         e1 = { f = ps.filename, y = t1.y, x = t1.x, kind = "paren", e1 = e1 }
      else
         i, e1 = parse_literal(ps, i)
      end

      if not e1 then
         return i
      end

      while true do
         local tkop = ps.tokens[i]
         if tkop.kind == "," or tkop.kind == ")" then -- check most common terminators first
            break
         end
         if tkop.tk == "." or tkop.tk == ":" then
            local op: Operator = new_operator(tkop, 2, tkop.tk)

            local prev_i = i

            local key: Node
            i = i + 1
            if ps.tokens[i].kind ~= "identifier" then
               local skipped = skip(ps, i, parse_type as SkipFunction)
               if skipped > i + 1 then
                  fail(ps, i, "syntax error, cannot declare a type here (missing 'local' or 'global'?)")
                  return skipped, failstore(ps, tkop, e1)
               end
            end
            i, key = verify_kind(ps, i, "identifier")
            if not key then
               return i, failstore(ps, tkop, e1)
            end

            if op.op == ":" then
               if not args_starters[ps.tokens[i].kind] then
                  if ps.tokens[i].tk == "=" then
                     fail(ps, i, "syntax error, cannot perform an assignment here (missing 'local' or 'global'?)")
                  else
                     fail(ps, i, "expected a function call for a method")
                  end
                  return i, failstore(ps, tkop, e1)
               end

               if not after_valid_prefixexp(ps, e1, prev_i) then
                  fail(ps, prev_i, "cannot call a method on this expression")
                  return i, failstore(ps, tkop, e1)
               end
            end

            e1 = { f = ps.filename, y = tkop.y, x = tkop.x, kind = "op", op = op, e1 = e1, e2 = key }
         elseif tkop.tk == "(" then
            local prev_tk = ps.tokens[i - 1]
            if tkop.y > prev_tk.y and ps.parse_lang ~= "lua" then
               table.insert(ps.tokens, i, { y = prev_tk.y, x = prev_tk.x + #prev_tk.tk, tk = ";", kind = ";" })
               break
            end

            local op: Operator = new_operator(tkop, 2, "@funcall")

            local prev_i = i

            local args = new_node(ps, i, "expression_list")
            i, args = parse_bracket_list(ps, i, args, "(", ")", "sep", parse_expression)

            if not after_valid_prefixexp(ps, e1, prev_i) then
               fail(ps, prev_i, "cannot call this expression")
               return i, failstore(ps, tkop, e1)
            end

            e1 = { f = ps.filename, y = args.y, x = args.x, kind = "op", op = op, e1 = e1, e2 = args }

            table.insert(ps.required_modules, node_is_require_call_or_pcall(e1))
         elseif tkop.tk == "[" then
            local op: Operator = new_operator(tkop, 2, "@index")

            local prev_i = i

            local idx: Node
            i = i + 1
            i, idx = parse_expression_and_tk(ps, i, "]")

            if not after_valid_prefixexp(ps, e1, prev_i) then
               fail(ps, prev_i, "cannot index this expression")
               return i, failstore(ps, tkop, e1)
            end

            e1 = { f = ps.filename, y = tkop.y, x = tkop.x, kind = "op", op = op, e1 = e1, e2 = idx }
         elseif tkop.kind == "string" or tkop.kind == "{" then
            local op: Operator = new_operator(tkop, 2, "@funcall")

            local prev_i = i

            local args = new_node(ps, i, "expression_list")
            local argument: Node
            if tkop.kind == "string" then
               argument = new_node(ps, i)
               argument.conststr = unquote(tkop.tk)
               i = i + 1
            else
               i, argument = parse_table_literal(ps, i)
            end

            if not after_valid_prefixexp(ps, e1, prev_i) then
               if tkop.kind == "string" then
                  fail(ps, prev_i, "cannot use a string here; if you're trying to call the previous expression, wrap it in parentheses")
               else
                  fail(ps, prev_i, "cannot use a table here; if you're trying to call the previous expression, wrap it in parentheses")
               end
               return i, failstore(ps, tkop, e1)
            end

            table.insert(args, argument)
            e1 = { f = ps.filename, y = args.y, x = args.x, kind = "op", op = op, e1 = e1, e2 = args }

            table.insert(ps.required_modules, node_is_require_call_or_pcall(e1))
         elseif tkop.tk == "as" or tkop.tk == "is" then
            local op: Operator = new_operator(tkop, 2, tkop.tk)

            i = i + 1
            local cast = new_node(ps, i, "cast")
            if ps.tokens[i].tk == "(" then
               i, cast.casttype = parse_type_list(ps, i, "casttype")
            else
               i, cast.casttype = parse_type(ps, i)
            end
            if not cast.casttype then
               return i, failstore(ps, tkop, e1)
            end
            e1 = { f = ps.filename, y = tkop.y, x = tkop.x, kind = "op", op = op, e1 = e1, e2 = cast, conststr = e1.conststr }
         else
            break
         end
      end

      return i, e1
   end

   E = function(ps: ParseState, i: integer, lhs: Node, min_precedence: integer): integer, Node
      local lookahead = ps.tokens[i].tk
      while precedences[2][lookahead] and precedences[2][lookahead] >= min_precedence do
         local t1 = ps.tokens[i]
         local op: Operator = new_operator(t1, 2, t1.tk)
         i = i + 1
         local rhs: Node
         i, rhs = P(ps, i)
         if not rhs then
            fail(ps, i, "expected an expression")
            return i
         end
         lookahead = ps.tokens[i].tk
         while precedences[2][lookahead] and ((precedences[2][lookahead] > (precedences[2][op.op]))
            or (is_right_assoc[lookahead] and (precedences[2][lookahead] == precedences[2][op.op]))) do
            i, rhs = E(ps, i, rhs, precedences[2][lookahead])
            if not rhs then
               fail(ps, i, "expected an expression")
               return i
            end
            lookahead = ps.tokens[i].tk
         end
         lhs = { f = ps.filename, y = t1.y, x = t1.x, kind = "op", op = op, e1 = lhs, e2 = rhs, }
      end
      return i, lhs
   end

   parse_expression = function(ps: ParseState, i: integer): integer, Node, integer
      local lhs: Node
      local istart = i
      i, lhs = P(ps, i)
      if lhs then
         i, lhs = E(ps, i, lhs, 0)
      end
      if lhs then
         return i, lhs, 0
      end
      -- if cursor moved, a more specific error was already thrown
      if i == istart then
         i = fail(ps, i, "expected an expression")
      end
      return i
   end
end

parse_expression_and_tk = function(ps: ParseState, i: integer, tk: string): integer, Node
   local e: Node
   i, e = parse_expression(ps, i)
   if not e then
      e = new_node(ps, i - 1, "error_node")
   end
   if ps.tokens[i].tk == tk then
      i = i + 1
   else
      local msg = "syntax error, expected '" .. tk .. "'"
      if ps.tokens[i].tk == "=" then
         msg = "syntax error, cannot perform an assignment here (did you mean '=='?)"
      end

      -- try to resync the parser for a bit
      for n = 0, 19 do
         local t = ps.tokens[i + n]
         if t.kind == "$EOF$" then
            break
         end
         if t.tk == tk then
            fail(ps, i, msg)
            return i + n + 1, e
         end
      end
      i = fail(ps, i, msg)
   end
   return i, e
end

local function parse_variable_name(ps: ParseState, i: integer): integer, Node, integer
   local node: Node
   i, node = verify_kind(ps, i, "identifier")
   if not node then
      return i
   end
   if ps.tokens[i].tk == "<" then
      i = i + 1
      local annotation: Node
      i, annotation = verify_kind(ps, i, "identifier")
      if annotation then
         if not is_attribute[annotation.tk] then
            fail(ps, i, "unknown variable annotation: " .. annotation.tk)
         end
         node.attribute = annotation.tk as Attribute
      else
         fail(ps, i, "expected a variable annotation")
      end
      i = verify_tk(ps, i, ">")
   end
   return i, node
end

local function parse_argument(ps: ParseState, i: integer): integer, Node, integer
   local node: Node
   if ps.tokens[i].tk == "..." then
      i, node = verify_kind(ps, i, "...", "argument")
      node.opt = true
   else
      i, node = verify_kind(ps, i, "identifier", "argument")
   end
   if ps.tokens[i].tk == "..." then
      fail(ps, i, "'...' needs to be declared as a typed argument")
   end
   if ps.tokens[i].tk == "?" then
      i = i + 1
      node.opt = true
   end
   if ps.tokens[i].tk == ":" then
      i = i + 1
      local argtype: Type

      i, argtype = parse_type(ps, i)

      if node then
         node.argtype = argtype
      end
   end
   return i, node, 0
end

parse_argument_list = function(ps: ParseState, i: integer): integer, Node, integer
   local node = new_node(ps, i, "argument_list")
   i, node = parse_bracket_list(ps, i, node, "(", ")", "sep", parse_argument)
   local opts = false
   local min_arity = 0
   for a, fnarg in ipairs(node) do
      if fnarg.tk == "..." then
         if a ~= #node then
            fail(ps, i, "'...' can only be last argument")
            break
         end
      elseif fnarg.opt then
         opts = true
      elseif opts then
         return fail(ps, i, "non-optional arguments cannot follow optional arguments")
      else
         min_arity = min_arity + 1
      end
   end
   return i, node, min_arity
end

local record ArgumentInfo
   i: integer
   type: Type
   is_va: boolean
   is_self: boolean
   opt: boolean
end

local function parse_argument_type(ps: ParseState, i: integer): integer, ArgumentInfo, integer
   local opt = 0
   local is_va = false
   local is_self = false
   local argument_name: string = nil

   if ps.tokens[i].kind == "identifier" then
      argument_name = ps.tokens[i].tk
      if ps.tokens[i + 1].tk == "?" then
         opt = i + 1
         if ps.tokens[i + 2].tk == ":" then
            i = i + 3
         end
      elseif ps.tokens[i + 1].tk == ":" then
         i = i + 2
      end
   elseif ps.tokens[i].kind == "?" then
      opt = i
      i = i + 1
   elseif ps.tokens[i].tk == "..." then
      if ps.tokens[i + 1].tk == "?" then
         fail(ps, i + 1, "cannot mix '?' and '...' in a declaration; '...' already implies optional")
         i = i + 1
      end
      if ps.tokens[i + 1].tk == ":" then
         i = i + 2
         is_va = true
      else
         return fail(ps, i, "cannot have untyped '...' when declaring the type of an argument")
      end
   end

   local typ: Type; i, typ = parse_type(ps, i)
   if typ then
      if not is_va and ps.tokens[i].tk == "..." then
         i = i + 1
         is_va = true
         if opt > 0 then
            fail(ps, opt, "cannot mix '?' and '...' in a declaration; '...' already implies optional")
         end
      end

      if argument_name == "self" then
         is_self = true
      end
   end

   return i, { i = i, type = typ, is_va = is_va, is_self = is_self, opt = (opt > 0) or is_va }, 0
end

parse_argument_type_list = function(ps: ParseState, i: integer): integer, Type, boolean, integer
   local ars: {ArgumentInfo} = {}
   i = parse_bracket_list(ps, i, ars, "(", ")", "sep", parse_argument_type)
   local t, list = new_tuple(ps, i)
   local n = #ars
   local min_arity = 0
   for l, ar in ipairs(ars) do
      list[l] = ar.type
      if ar.is_va and l < n then
         fail(ps, ar.i, "'...' can only be last argument")
      end
      if not ar.opt then
         min_arity = min_arity + 1
      end
   end
   if n > 0 and ars[n].is_va then
      t.is_va = true
   end
   return i, t, (n > 0 and ars[1].is_self), min_arity
end

local function parse_identifier(ps: ParseState, i: integer): integer, Node, integer
   if ps.tokens[i].kind == "identifier" then
      return i + 1, new_node(ps, i, "identifier")
   end
   i = fail(ps, i, "syntax error, expected identifier")
   return i, new_node(ps, i, "error_node")
end

local function parse_local_function(ps: ParseState, i: integer): integer, Node
   i = verify_tk(ps, i, "local")
   i = verify_tk(ps, i, "function")
   local node = new_node(ps, i - 2, "local_function")
   i, node.name = parse_identifier(ps, i)
   return parse_function_args_rets_body(ps, i, node)
end

local enum FunctionKind
   "global"
   "record"
end

local function parse_function(ps: ParseState, i: integer, fk: FunctionKind): integer, Node
   local orig_i = i
   i = verify_tk(ps, i, "function")
   local fn = new_node(ps, i - 1, "global_function")
   local names: {Node} = {}
   i, names[1] = parse_identifier(ps, i)
   while ps.tokens[i].tk == "." do
      i = i + 1
      i, names[#names + 1] = parse_identifier(ps, i)
   end
   if ps.tokens[i].tk == ":" then
      i = i + 1
      i, names[#names + 1] = parse_identifier(ps, i)
      fn.is_method = true
   end

   if #names > 1 then
      fn.kind = "record_function"
      local owner = names[1]
      owner.kind = "type_identifier"
      for i2 = 2, #names - 1 do
         local dot = parser.operator(names[i2], 2, ".")
         names[i2].kind = "identifier"
         owner = { f = ps.filename, y = names[i2].y, x = names[i2].x, kind = "op", op = dot, e1 = owner, e2 = names[i2] }
      end
      fn.fn_owner = owner
   end
   fn.name = names[#names]

   local selfx, selfy = ps.tokens[i].x, ps.tokens[i].y
   i = parse_function_args_rets_body(ps, i, fn)
   if fn.is_method and fn.args then
      table.insert(fn.args, 1, { f = ps.filename, x = selfx, y = selfy, tk = "self", kind = "identifier" })
      fn.min_arity = fn.min_arity + 1
   end

   if not fn.name then
      return orig_i + 1
   end

   if fn.kind == "record_function" and fk == "global" then
      fail(ps, orig_i, "record functions cannot be annotated as 'global'")
   elseif fn.kind == "global_function" and fk == "record" then
      fn.implicit_global_function = true
   end

   return i, fn
end

local function parse_if_block(ps: ParseState, i: integer, n: integer, node: Node, is_else?: boolean): integer, Node
   local block = new_node(ps, i, "if_block")
   i = i + 1
   block.if_parent = node
   block.if_block_n = n
   if not is_else then
      i, block.exp = parse_expression_and_tk(ps, i, "then")
      if not block.exp then
         return i
      end
   end
   i, block.body = parse_statements(ps, i)
   if not block.body then
      return i
   end
   block.yend, block.xend = block.body.yend, block.body.xend
   table.insert(node.if_blocks, block)
   return i, node
end

local function parse_if(ps: ParseState, i: integer): integer, Node
   local istart = i
   local node = new_node(ps, i, "if")
   node.if_blocks = {}
   i, node = parse_if_block(ps, i, 1, node)
   if not node then
      return i
   end
   local n = 2
   while ps.tokens[i].tk == "elseif" do
      i, node = parse_if_block(ps, i, n, node)
      if not node then
         return i
      end
      n = n + 1
   end
   if ps.tokens[i].tk == "else" then
      i, node = parse_if_block(ps, i, n, node, true)
      if not node then
         return i
      end
   end
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_while(ps: ParseState, i: integer): integer, Node
   local istart = i
   local node = new_node(ps, i, "while")
   i = verify_tk(ps, i, "while")
   i, node.exp = parse_expression_and_tk(ps, i, "do")
   i, node.body = parse_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_fornum(ps: ParseState, i: integer): integer, Node
   local istart = i
   local node = new_node(ps, i, "fornum")
   i = i + 1
   i, node.var = parse_identifier(ps, i)
   i = verify_tk(ps, i, "=")
   i, node.from = parse_expression_and_tk(ps, i, ",")
   i, node.to = parse_expression(ps, i)
   if ps.tokens[i].tk == "," then
      i = i + 1
      i, node.step = parse_expression_and_tk(ps, i, "do")
   else
      i = verify_tk(ps, i, "do")
   end
   i, node.body = parse_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_forin(ps: ParseState, i: integer): integer, Node
   local istart = i
   local node = new_node(ps, i, "forin")
   i = i + 1
   node.vars = new_node(ps, i, "variable_list")
   i, node.vars = parse_list(ps, i, node.vars, { ["in"] = true }, "sep", parse_identifier)
   i = verify_tk(ps, i, "in")
   node.exps = new_node(ps, i, "expression_list")
   i = parse_list(ps, i, node.exps, { ["do"] = true }, "sep", parse_expression)
   if #node.exps < 1 then
      return fail(ps, i, "missing iterator expression in generic for")
   elseif #node.exps > 3 then
      return fail(ps, i, "too many expressions in generic for")
   end
   i = verify_tk(ps, i, "do")
   i, node.body = parse_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_for(ps: ParseState, i: integer): integer, Node
   if ps.tokens[i+1].kind == "identifier" and ps.tokens[i+2].tk == "=" then
      return parse_fornum(ps, i)
   else
      return parse_forin(ps, i)
   end
end

local function parse_repeat(ps: ParseState, i: integer): integer, Node
   local node = new_node(ps, i, "repeat")
   i = verify_tk(ps, i, "repeat")
   i, node.body = parse_statements(ps, i)
   node.body.is_repeat = true
   i = verify_tk(ps, i, "until")
   i, node.exp = parse_expression(ps, i)
   end_at(node, ps.tokens[i - 1])
   return i, node
end

local function parse_do(ps: ParseState, i: integer): integer, Node
   local istart = i
   local node = new_node(ps, i, "do")
   i = verify_tk(ps, i, "do")
   i, node.body = parse_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_break(ps: ParseState, i: integer): integer, Node
   local node = new_node(ps, i, "break")
   i = verify_tk(ps, i, "break")
   return i, node
end

local function parse_goto(ps: ParseState, i: integer): integer, Node
   local node = new_node(ps, i, "goto")
   i = verify_tk(ps, i, "goto")
   node.label = ps.tokens[i].tk
   i = verify_kind(ps, i, "identifier")
   return i, node
end

local function parse_label(ps: ParseState, i: integer): integer, Node
   local node = new_node(ps, i, "label")
   i = verify_tk(ps, i, "::")
   node.label = ps.tokens[i].tk
   i = verify_kind(ps, i, "identifier")
   i = verify_tk(ps, i, "::")
   return i, node
end

local stop_statement_list: {string:boolean} = {
   ["end"] = true,
   ["else"] = true,
   ["elseif"] = true,
   ["until"] = true,
}

local stop_return_list: {string:boolean} = {
   [";"] = true,
   ["$EOF$"] = true,
}

for k, v in pairs(stop_statement_list) do
   stop_return_list[k] = v
end

local function parse_return(ps: ParseState, i: integer): integer, Node
   local node = new_node(ps, i, "return")
   i = verify_tk(ps, i, "return")
   node.exps = new_node(ps, i, "expression_list")
   i = parse_list(ps, i, node.exps, stop_return_list, "sep", parse_expression)
   if ps.tokens[i].kind == ";" then
      i = i + 1
      if ps.tokens[i].kind ~= "$EOF$" and not stop_statement_list[ps.tokens[i].kind] then
         return fail(ps, i, "return must be the last statement of its block")
      end
   end
   return i, node
end

local function store_field_in_record(ps: ParseState, i: integer, field_name: string, newt: Type, def: RecordLikeType, comments?: {Comment}, meta?: MetaMode): boolean
   local field_order, fields, field_comments: {string}, {string:Type}, {string: {{Comment}}}
   if meta then
      field_order, fields, field_comments = def.meta_field_order, def.meta_fields, def.meta_field_comments
   else
      field_order, fields, field_comments = def.field_order, def.fields, def.field_comments
   end

   if comments and not field_comments then
      field_comments = {}
      if meta then
         def.meta_field_comments = field_comments
      else
         def.field_comments = field_comments
      end
   end

   if not fields[field_name] then
      fields[field_name] = newt
      if comments then
         field_comments[field_name] = {comments}
      end
      table.insert(field_order, field_name)
      return true
   end

   local oldt = fields[field_name]
   local oldf = oldt is GenericType and oldt.t or oldt
   local newf = newt is GenericType and newt.t or newt

   local function store_comment_for_poly(poly: PolyType)
      if comments then
         if not field_comments[field_name] then
            field_comments[field_name] = {}
            for idx = 1, #poly.types - 1 do -- padding for existing types
               field_comments[field_name][idx] = {}
            end
         end
         table.insert(field_comments[field_name], comments)
      elseif field_comments and field_comments[field_name] then
         table.insert(field_comments[field_name], {})
      end
   end

   if newf is FunctionType then
      if oldf is FunctionType then
         local p = new_type(ps, i, "poly") as PolyType
         p.types = { oldt as FunctionType, newt as FunctionType }
         fields[field_name] = p
         store_comment_for_poly(p)
         return true
      elseif oldt is PolyType then
         table.insert(oldt.types, newt as FunctionType)
         store_comment_for_poly(oldt)
         return true
      end
   end
   fail(ps, i, "attempt to redeclare field '" .. field_name .. "' (only functions can be overloaded)")
   return false
end

local function set_declname(def: Type, declname: string)
   if def is GenericType then
      def = def.t
   end

   if def is RecordType or def is InterfaceType or def is EnumType then
      if not def.declname then
         def.declname = declname
      end
   end
end

local function get_attached_comments(token: Token): {Comment}
   if not token.comments then
      return nil
   end

   local function is_long_comment(c: Comment): boolean
      return c.text:match("^%-%-%[(=*)%[") ~= nil
   end
   local last_comment = token.comments[#token.comments]

   -- special case for long comments
   if is_long_comment(last_comment) then
      local _, newlines = string.gsub(last_comment.text, "\n", "")
      local diff_y = token.y - last_comment.y - newlines
      -- we want to attach only long comments that end just before the token
      if diff_y >= 0 and diff_y <= 1 then
         return {last_comment}
      else
         return nil
      end
   end

   local diff_y = token.y - last_comment.y
   if diff_y < 0 or diff_y > 1 then
      return nil
   end
   local first_n = 1
   for i = #token.comments, 2, -1 do
      local prev = token.comments[i - 1]
      if is_long_comment(prev) then
         first_n = i
         break
      end
      -- we want to attach only consecutive comments
      if token.comments[i].y - prev.y > 1 then
         first_n = i
         break
      end
   end

   local attached_comments =
      table.move(token.comments, first_n, #token.comments, 1, {})

   return attached_comments
end

local function parse_nested_type(ps: ParseState, i: integer, def: RecordLikeType, tn: BodyTypeName): integer, boolean
   local istart = i
   i = i + 1 -- skip 'record' or 'enum'
   local iv = i

   local v: Node
   i, v = verify_kind(ps, i, "identifier", "type_identifier")
   if not v then
      return fail(ps, i, "expected a variable name")
   end

   local nt: Node = new_node(ps, istart, "newtype")

   local ndef: Type
   i, ndef = parse_type_body(ps, i, istart, nt, tn)
   if not ndef then
      return i
   end

   set_declname(ndef, v.tk)

   nt.newtype = new_typedecl(ps, istart, ndef)

   store_field_in_record(ps, iv, v.tk, nt.newtype, def, get_attached_comments(ps.tokens[istart]))
   return i
end

parse_enum_body = function(ps: ParseState, i: integer, def: EnumType): integer, boolean
   def.enumset = {}
   while ps.tokens[i].tk ~= "$EOF$" and ps.tokens[i].tk ~= "end" do
      local item: Node
      i, item = verify_kind(ps, i, "string", "string")
      if item then
         local name = unquote(item.tk)
         def.enumset[name] = true
         local comments = get_attached_comments(ps.tokens[i - 1])
         if comments then
            if not def.value_comments then
               def.value_comments = {}
            end
            def.value_comments[name] = comments
         end
      end
   end
   return i, true
end

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

local function parse_macroexp(ps: ParseState, istart: integer, iargs: integer): integer, Node
   local node = new_node(ps, istart, "macroexp")

   local i: integer
   if ps.tokens[istart + 1].tk == "<" then
      i, node.typeargs = parse_anglebracket_list(ps, istart + 1, parse_typearg)
   else
      i = iargs
   end

   i, node.args, node.min_arity = parse_argument_list(ps, i)
   i, node.rets = parse_return_types(ps, i)
   i = verify_tk(ps, i, "return")
   i, node.exp = parse_expression(ps, i)
   end_at(node, ps.tokens[i])
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_where_clause(ps: ParseState, i: integer, def: RecordLikeType): integer, Node
   local node = new_node(ps, i, "macroexp")

   node.is_method = true
   node.args = new_node(ps, i, "argument_list")
   node.args[1] = new_node(ps, i, "argument")
   node.args[1].tk = "self"
   node.args[1].argtype = new_type(ps, i, "self")
   (node.args[1].argtype as SelfType).display_type = def
   node.min_arity = 1
   node.rets = new_tuple(ps, i)
   node.rets.tuple[1] = new_type(ps, i, "boolean")
   i, node.exp = parse_expression(ps, i)
   end_at(node, ps.tokens[i - 1])
   return i, node
end

parse_interface_name = function(ps: ParseState, i: integer): integer, FirstOrderType, integer
   local istart = i
   local typ: FirstOrderType
   i, typ = parse_simple_type_or_nominal(ps, i)
   if not typ is NominalType then
      return fail(ps, istart, "expected an interface")
   end
   return i, typ
end

local function parse_array_interface_type(ps: ParseState, i: integer, def: RecordLikeType): integer, ArrayType
   if def.interface_list then
      local first = def.interface_list[1]
      if first is ArrayType then
         return failskip(ps, i, "duplicated declaration of array element type", parse_type as SkipFunction)
      end
   end
   local t: Type
   i, t = parse_base_type(ps, i)
   if not t then
      return i
   end
   if not t is ArrayType then
      fail(ps, i, "expected an array declaration")
      return i
   end
   def.elements = t.elements
   return i, t
end

-- FIXME (a) GenericType do we need to patch the where-generated __is function into a generic? (see (b))
--local function clone_typeargs(ps: ParseState, i: integer, typeargs: {TypeArgType}): {TypeArgType}
--   local copy = {}
--   for a, ta in ipairs(typeargs) do
--      local cta = new_type(ps, i, "typearg") as TypeArgType
--      cta.typearg = ta.typearg
--      copy[a] = cta
--   end
--   return copy
--end

local function extract_userdata_from_interface_list(ps: ParseState, i: integer, def: RecordLikeType)
   for j = #def.interface_list, 1, -1 do
      local iface = def.interface_list[j]
      if iface is NominalType and #iface.names == 1 and iface.names[1] == "userdata" then
         table.remove(def.interface_list, j)
         if def.is_userdata then
            fail(ps, i, "duplicated 'userdata' declaration")
         end
         def.is_userdata = true
      end
   end
end

parse_record_body = function(ps: ParseState, i: integer, def: RecordLikeType): integer, boolean
   def.fields = {}
   def.field_order = {}

   if ps.tokens[i].tk == "{" then
      local atype: Type
      i, atype = parse_array_interface_type(ps, i, def)
      if atype then
         def.interface_list = { atype }
      end
   end

   if ps.tokens[i].tk == "is" then
      i = i + 1

      if ps.tokens[i].tk == "{" then
         local atype: Type
         i, atype = parse_array_interface_type(ps, i, def)
         if ps.tokens[i].tk == "," then
            i = i + 1
            i, def.interface_list = parse_trying_list(ps, i, {}, parse_interface_name)
         else
            def.interface_list = {}
         end
         if atype then
            table.insert(def.interface_list, 1, atype)
         end
      else
         i, def.interface_list = parse_trying_list(ps, i, {}, parse_interface_name)
      end

      if def.interface_list then
         extract_userdata_from_interface_list(ps, i, def)
      end
   end

   if ps.tokens[i].tk == "where" then
      local wstart = i
      i = i + 1
      local where_macroexp: Node
      i, where_macroexp = parse_where_clause(ps, i, def)

      local typ = new_type(ps, wstart, "function") as FunctionType
      -- FIXME (b) GenericType do we need to patch the where-generated __is function into a generic? (see (a))
      typ.is_method = true
      typ.min_arity = 1
      typ.args = new_tuple(ps, wstart, {
         a_type(where_macroexp, "self", { display_type = def } as SelfType)
      })
      typ.rets = new_tuple(ps, wstart, { new_type(ps, wstart, "boolean") })
      typ.macroexp = where_macroexp

      def.meta_fields = {}
      def.meta_field_order = {}
      store_field_in_record(ps, i, "__is", typ, def, nil, "meta")
   end

   while not (ps.tokens[i].kind == "$EOF$" or ps.tokens[i].tk == "end") do
      local tn = ps.tokens[i].tk as BodyTypeName
      if ps.tokens[i].tk == "userdata" and ps.tokens[i+1].tk ~= ":" then
         if def.is_userdata then
            fail(ps, i, "duplicated 'userdata' declaration")
         else
            def.is_userdata = true
         end
         i = i + 1
      elseif ps.tokens[i].tk == "{" then
         return fail(ps, i, "syntax error: this syntax is no longer valid; declare array interface at the top with 'is {...}'")
      elseif ps.tokens[i].tk == "type" and ps.tokens[i + 1].tk ~= ":" then
         local comments = get_attached_comments(ps.tokens[i])
         i = i + 1
         local iv = i

         local lt: Node
         i, lt = parse_type_declaration(ps, i, "local_type") -- local_type Node will be discarded
         if not lt then
            return fail(ps, i, "expected a type definition")
         end

         local v = lt.var
         if not v then
            return fail(ps, i, "expected a variable name")
         end

         local nt = lt.value
         if not nt or not nt.newtype then
            return fail(ps, i, "expected a type definition")
         end

         local ntt = nt.newtype
         if ntt.is_alias then
            ntt.is_nested_alias = true
         end

         store_field_in_record(ps, iv, v.tk, nt.newtype, def, comments)
      elseif parse_type_body_fns[tn] and ps.tokens[i+1].tk ~= ":" then
         if def.typename == "interface" and tn == "record" then
            i = failskip(ps, i, "interfaces cannot contain record definitions", skip_type_body)
         else
            i = parse_nested_type(ps, i, def, tn)
         end
      else
         local comments = get_attached_comments(ps.tokens[i])
         local is_metamethod = false
         if ps.tokens[i].tk == "metamethod" and ps.tokens[i+1].tk ~= ":" then
            is_metamethod = true
            i = i + 1
         end

         local v: Node
         if ps.tokens[i].tk == "[" then
            i, v = parse_literal(ps, i+1)
            if v and not v.conststr then
               return fail(ps, i, "expected a string literal")
            end
            i = verify_tk(ps, i, "]")
         else
            i, v = verify_kind(ps, i, "identifier", "variable")
         end
         local iv = i
         if not v then
            return fail(ps, i, "expected a variable name")
         end

         if ps.tokens[i].tk == ":" then
            i = i + 1
            local t: Type
            i, t = parse_type(ps, i)
            if not t then
               return fail(ps, i, "expected a type")
            end
            if t is FunctionType and t.maybe_method then
               t.is_method = true
            end

            local field_name = v.conststr or v.tk
            if is_metamethod then
               if not def.meta_fields then
                  def.meta_fields = {}
                  def.meta_field_order = {}
               end
               if not metamethod_names[field_name] then
                  fail(ps, i - 1, "not a valid metamethod: " .. field_name)
               end
            end

            if ps.tokens[i].tk == "=" and ps.tokens[i + 1].tk == "macroexp" then
               local tt = t is GenericType and t.t or t

               if tt is FunctionType then
                  i, tt.macroexp = parse_macroexp(ps, i + 1, i + 2)
               else
                  fail(ps, i + 1, "macroexp must have a function type")
               end
            end

            store_field_in_record(ps, iv, field_name, t, def, comments, is_metamethod and "meta" or nil)
         elseif ps.tokens[i].tk == "=" then
            local next_word = ps.tokens[i + 1].tk
            if next_word == "record" or next_word == "enum" then
               return fail(ps, i, "syntax error: this syntax is no longer valid; use '" .. next_word .. " " .. v.tk .. "'")
            elseif next_word == "functiontype" then
               return fail(ps, i, "syntax error: this syntax is no longer valid; use 'type " .. v.tk .. " = function('...")
            else
               return fail(ps, i, "syntax error: this syntax is no longer valid; use 'type " .. v.tk .. " = '...")
            end
         else
            fail(ps, i, "syntax error: expected ':' for an attribute or '=' for a nested type")
         end
      end
   end
   return i, true
end

parse_type_body_fns = {
   ["interface"] = parse_record_body,
   ["record"] = parse_record_body,
   ["enum"] = parse_enum_body,
}

local function parse_newtype(ps: ParseState, i: integer): integer, Node
   local node: Node = new_node(ps, i, "newtype")
   local def: FirstClassType
   local tn = ps.tokens[i].tk as BodyTypeName
   local istart = i

   if parse_type_body_fns[tn] then
      i, def = parse_type_body(ps, i + 1, istart, node, tn)
   else
      i, def = parse_type(ps, i)
   end
   if not def then
      return fail(ps, i, "expected a type")
   end

   node.newtype = new_typedecl(ps, istart, def)

   if def is NominalType then
      node.newtype.is_alias = true
   elseif def is GenericType then
      local deft = def.t
      if deft is NominalType then
         node.newtype.is_alias = true
      end
   end

   return i, node
end

local function parse_assignment_expression_list(ps: ParseState, i: integer, asgn: Node): integer, Node
   asgn.exps = new_node(ps, i, "expression_list")
   repeat
      i = i + 1
      local val: Node
      i, val = parse_expression(ps, i)
      if not val then
         if #asgn.exps == 0 then
            asgn.exps = nil
         end
         return i
      end
      table.insert(asgn.exps, val)
   until ps.tokens[i].tk ~= ","
   return i, asgn
end

local parse_call_or_assignment: function(ps: ParseState, i: integer): integer, Node
do
   local function is_lvalue(node: Node): boolean
      node.is_lvalue = node.kind == "variable"
                       or (node.kind == "op"
                           and (node.op.op == "@index" or node.op.op == "."))
      return node.is_lvalue
   end

   local function parse_variable(ps: ParseState, i: integer): integer, Node, integer
      local node: Node
      i, node = parse_expression(ps, i)
      if not (node and is_lvalue(node)) then
         return fail(ps, i, "expected a variable")
      end
      return i, node
   end

   parse_call_or_assignment = function(ps: ParseState, i: integer): integer, Node
      local exp: Node
      local istart = i
      i, exp = parse_expression(ps, i)
      if not exp then
         return i
      end

      if parser.node_is_funcall(exp) or exp.failstore then
         return i, exp
      end

      if not is_lvalue(exp) then
         return fail(ps, i, "syntax error")
      end

      local asgn: Node = new_node(ps, istart, "assignment")
      asgn.vars = new_node(ps, istart, "variable_list")
      asgn.vars[1] = exp
      if ps.tokens[i].tk == "," then
         i = i + 1
         i = parse_trying_list(ps, i, asgn.vars, parse_variable)
         if #asgn.vars < 2 then
            return fail(ps, i, "syntax error")
         end
      end

      if ps.tokens[i].tk ~= "=" then
         verify_tk(ps, i, "=")
         return i
      end

      i, asgn = parse_assignment_expression_list(ps, i, asgn)
      return i, asgn
   end
end

local function parse_variable_declarations(ps: ParseState, i: integer, node_name: NodeKind): integer, Node
   local asgn: Node = new_node(ps, i, node_name)

   asgn.vars = new_node(ps, i, "variable_list")
   i = parse_trying_list(ps, i, asgn.vars, parse_variable_name)
   if #asgn.vars == 0 then
      return fail(ps, i, "expected a local variable definition")
   end

   i, asgn.decltuple = parse_type_list(ps, i, "decltuple")

   if ps.tokens[i].tk == "=" then
      -- produce nice error message when using <= 0.7.1 syntax
      local next_word = ps.tokens[i + 1].tk
      local tn = next_word as BodyTypeName
      if parse_type_body_fns[tn] then
         local scope = node_name == "local_declaration" and "local" or "global"
         return failskip(ps, i + 1, "syntax error: this syntax is no longer valid; use '" .. scope .. " " .. next_word .. " " .. asgn.vars[1].tk .. "'", skip_type_body)
      elseif next_word == "functiontype" then
         local scope = node_name == "local_declaration" and "local" or "global"
         return failskip(ps, i + 1, "syntax error: this syntax is no longer valid; use '" .. scope .. " type " .. asgn.vars[1].tk .. " = function('...", parse_function_type as SkipFunction)
      end

      i, asgn = parse_assignment_expression_list(ps, i, asgn)
   end
   return i, asgn
end

local function parse_type_require(ps: ParseState, i: integer, asgn: Node): integer, Node
   local istart = i
   i, asgn.value = parse_expression(ps, i)
   if not asgn.value then
      return i
   end
   if asgn.value.op and asgn.value.op.op ~= "@funcall" and asgn.value.op.op ~= "." then
      fail(ps, istart, "require() in type declarations cannot be part of larger expressions")
      return i
   end
   if not parser.node_is_require_call(asgn.value) then
      fail(ps, istart, "require() for type declarations must have a literal argument")
      return i
   end
   return i, asgn
end

local function parse_special_type_declaration(ps: ParseState, i: integer, asgn: Node): boolean, integer, Node
   if ps.tokens[i].tk == "require" then
      return true, parse_type_require(ps, i, asgn)
   elseif ps.tokens[i].tk == "pcall" then
      fail(ps, i, "pcall() cannot be used in type declarations")
      return true, i
   end
   return false, i, asgn
end

parse_type_declaration = function(ps: ParseState, i: integer, node_name: NodeKind): integer, Node
   local asgn: Node = new_node(ps, i, node_name)
   local var: Node

   i, var = verify_kind(ps, i, "identifier")
   if not var then
      return fail(ps, i, "expected a type name")
   end
   local typeargs: {TypeArgType}
   local itypeargs = i
   i, typeargs = parse_typeargs_if_any(ps, i)

   asgn.var = var

   if node_name == "global_type" and ps.tokens[i].tk ~= "=" then
      return i, asgn
   end

   i = verify_tk(ps, i, "=")
   local istart = i

   if ps.tokens[i].kind == "identifier" then
      local is_done: boolean
      is_done, i, asgn = parse_special_type_declaration(ps, i, asgn)
      if is_done then
         return i, asgn
      end
   end

   i, asgn.value = parse_newtype(ps, i)
   if not asgn.value then
      return i
   end

   local nt = asgn.value.newtype
   if nt is TypeDeclType then
      if typeargs then
         local def = nt.def
         if def is GenericType then
            fail(ps, itypeargs, "cannot declare type arguments twice in type declaration")
         else
            nt.def = new_generic(ps, istart, typeargs, def)
         end
      end

      set_declname(nt.def, asgn.var.tk)
   end

   return i, asgn
end

local function parse_type_constructor(ps: ParseState, i: integer, node_name: NodeKind, tn: BodyTypeName): integer, Node
   local asgn: Node = new_node(ps, i, node_name)
   local nt: Node = new_node(ps, i, "newtype")
   asgn.value = nt
   local istart = i
   local def: Type

   i = i + 2 -- skip `local` or `global`, and the constructor name

   i, asgn.var = verify_kind(ps, i, "identifier")
   if not asgn.var then
      return fail(ps, i, "expected a type name")
   end

   i, def = parse_type_body(ps, i, istart, nt, tn)
   if not def then
      return i
   end

   set_declname(def, asgn.var.tk)

   nt.newtype = new_typedecl(ps, istart, def)

   return i, asgn
end

local function skip_type_declaration(ps: ParseState, i: integer): integer, Node
   return parse_type_declaration(ps, i + 1, "local_type")
end

local function parse_local_macroexp(ps: ParseState, i: integer): integer, Node
   local istart = i
   i = i + 2 -- skip `local`
   local node = new_node(ps, i, "local_macroexp")
   i, node.name = parse_identifier(ps, i)
   i, node.macrodef = parse_macroexp(ps, istart, i)
   end_at(node, ps.tokens[i - 1])
   return i, node
end

local function parse_local(ps: ParseState, i: integer): integer, Node
   local comments = get_attached_comments(ps.tokens[i])
   local ntk = ps.tokens[i + 1].tk
   local tn = ntk as TypeName

   local node: Node
   if ntk == "function" then
      i, node = parse_local_function(ps, i)
   elseif ntk == "type" and ps.tokens[i + 2].kind == "identifier" then
      i, node = parse_type_declaration(ps, i + 2, "local_type")
   elseif ntk == "macroexp" and ps.tokens[i+2].kind == "identifier" then
      i, node = parse_local_macroexp(ps, i)
   elseif parse_type_body_fns[tn as BodyTypeName] and ps.tokens[i+2].kind == "identifier" then
      i, node = parse_type_constructor(ps, i, "local_type", tn as BodyTypeName)
   else
      i, node = parse_variable_declarations(ps, i + 1, "local_declaration")
   end
   if node then
      node.comments = comments
   end
   return i, node
end

local function parse_global(ps: ParseState, i: integer): integer, Node
   local comments = get_attached_comments(ps.tokens[i])
   local ntk = ps.tokens[i + 1].tk
   local tn = ntk as TypeName

   local node: Node
   if ntk == "function" then
      i, node = parse_function(ps, i + 1, "global")
   elseif ntk == "type" and ps.tokens[i + 2].kind == "identifier" then
      i, node = parse_type_declaration(ps, i + 2, "global_type")
   elseif parse_type_body_fns[tn as BodyTypeName] and ps.tokens[i+2].kind == "identifier" then
      i, node = parse_type_constructor(ps, i, "global_type", tn as BodyTypeName)
   elseif ps.tokens[i+1].kind == "identifier" then
      i, node = parse_variable_declarations(ps, i + 1, "global_declaration")
   else
      return parse_call_or_assignment(ps, i) -- global is a soft keyword
   end
   if node then
      node.comments = comments
   end
   return i, node
end

local function parse_record_function(ps: ParseState, i: integer): integer, Node
   local comments = get_attached_comments(ps.tokens[i])
   local node: Node
   i, node = parse_function(ps, i, "record")
   if node then
      node.comments = comments
   end
   return i, node
end

local function parse_pragma(ps: ParseState, i: integer): integer, Node
   i = i + 1 -- skip "--#pragma"
   local pragma = new_node(ps, i, "pragma")

   if ps.tokens[i].kind ~= "pragma_identifier" then
      return fail(ps, i, "expected pragma name")
   end
   pragma.pkey = ps.tokens[i].tk
   i = i + 1

   if ps.tokens[i].kind ~= "pragma_identifier" then
      return fail(ps, i, "expected pragma value")
   end
   pragma.pvalue = ps.tokens[i].tk
   i = i + 1

   return i, pragma
end

local parse_statement_fns: {string : function(ParseState, integer):(integer, Node)} = {
   ["--#pragma"] = parse_pragma,
   ["::"] = parse_label,
   ["do"] = parse_do,
   ["if"] = parse_if,
   ["for"] = parse_for,
   ["goto"] = parse_goto,
   ["local"] = parse_local,
   ["while"] = parse_while,
   ["break"] = parse_break,
   ["global"] = parse_global,
   ["repeat"] = parse_repeat,
   ["return"] = parse_return,
   ["function"] = parse_record_function,
}

local function type_needs_local_or_global(ps: ParseState, i: integer): integer, Node
   local tk = ps.tokens[i].tk
   return failskip(ps, i, ("%s needs to be declared with 'local %s' or 'global %s'"):format(tk, tk, tk), skip_type_body)
end

local needs_local_or_global: {string : function(ParseState, integer):(integer, Node)} = {
   ["type"] = function(ps: ParseState, i: integer): integer, Node
      return failskip(ps, i, "types need to be declared with 'local type' or 'global type'", skip_type_declaration)
   end,
   ["record"] = type_needs_local_or_global,
   ["enum"] = type_needs_local_or_global,
}

local function store_unattached_comments(node: Node, token: Token, item: Node)
   for _, tc in ipairs(token.comments) do
      local is_attached = false
      if item.comments then
         for _, nc in ipairs(item.comments) do
            if tc == nc then
               is_attached = true
               break
            end
         end
      end
      if not is_attached then
         if not node.unattached_comments then
            node.unattached_comments = {}
         end
         table.insert(node.unattached_comments, tc)
      else
         break
      end
   end
end

parse_statements = function(ps: ParseState, i: integer, toplevel?: boolean): integer, Node
   local node = new_node(ps, i, "statements")
   local item: Node
   while true do
      while ps.tokens[i].kind == ";" do
         i = i + 1
         if item then
            item.semicolon = true
         end
      end

      if ps.tokens[i].kind == "$EOF$" then
         break
      end
      local token = ps.tokens[i]
      local tk = token.tk
      if (not toplevel) and stop_statement_list[tk] then
         break
      end

      local fn = parse_statement_fns[tk]
      if not fn then
         local skip_fn = needs_local_or_global[tk]
         if skip_fn and ps.tokens[i + 1].kind == "identifier" then
            fn = skip_fn
         else
            fn = parse_call_or_assignment
         end
      end

      i, item = fn(ps, i)

      if item then
         if toplevel and token.comments then
            store_unattached_comments(node, token, item)
         end
         table.insert(node, item)
      elseif i > 1 then
         -- heuristic to resync at the next line after an invalid statement
         local lasty = ps.tokens[i - 1].y
         while ps.tokens[i].kind ~= "$EOF$" and ps.tokens[i].y == lasty do
            i = i + 1
         end
      end
   end

   end_at(node, ps.tokens[i])
   return i, node
end

function parser.parse_program(tokens: {Token}, errs: {Error}, filename?: string, parse_lang?: ParseLang): Node, {string}
   errs = errs or {}
   local ps: ParseState = {
      tokens = tokens as {Token},
      errs = errs,
      filename = filename or "",
      required_modules = {},
      parse_lang = parse_lang,
   }
   local i = 1
   local hashbang: string
   if ps.tokens[i].kind == "hashbang" then
      hashbang = ps.tokens[i].tk
      i = i + 1
   end
   local _, node = parse_statements(ps, i, true)
   if hashbang then
      node.hashbang = hashbang
   end

   errors.clear_redundant_errors(errs)
   return node, ps.required_modules
end

local function lang_heuristic(filename?: string, input?: string): ParseLang
   if filename then
      local pattern <const> = "(.*)%.([a-z]+)$"
      local _, extension = filename:match(pattern)
      extension = extension and extension:lower()

      if extension == "tl" then
         return "tl"
      elseif extension == "lua" then
         return "lua"
      end
   end
   if input then
      return (input:match("^#![^\n]*lua[^\n]*\n")) and "lua" or "tl"
   end
   return "tl"
end

function parser.parse(input: string, filename: string): Node, {Error}, {string}
   local parse_lang = lang_heuristic(filename, input)
   local tokens, errs = lexer.lex(input, filename)
   local node, required_modules = parser.parse_program(tokens, errs, filename, parse_lang)
   return node, errs, required_modules
end

function parser.node_at(w: Where, n: Node): Node
   n.f = assert(w.f)
   n.x = w.x
   n.y = w.y
   return n
end

return parser
