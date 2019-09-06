local tl = {}

--------------------------------------------------------------------------------
-- Lexer
--------------------------------------------------------------------------------

--local inspect: function(any):string = require "inspect"

local inspect = function(x: any):string
   return tostring(x)
end

local keywords: {string:boolean} = {
   ["and"] = true,
   ["break"] = true,
   ["do"] = true,
   ["else"] = true,
   ["elseif"] = true,
   ["end"] = true,
   ["false"] = true,
   ["for"] = true,
   ["function"] = true,
   ["goto"] = true,
   ["if"] = true,
   ["in"] = true,
   ["local"] = true,
   ["nil"] = true,
   ["not"] = true,
   ["or"] = true,
   ["repeat"] = true,
   ["return"] = true,
   ["then"] = true,
   ["true"] = true,
   ["until"] = true,
   ["while"] = true,
}

local Token = record
   x: number
   y: number
   i: number
   tk: string
   kind: string
end

function tl.lex(input: string): {Token}
   local tokens: {Token} = {}

   local state = "any"
   local fwd = true
   local y = 1
   local x = 0
   local i = 0
   local lc_open_lvl = 0
   local lc_close_lvl = 0
   local ls_open_lvl = 0
   local ls_close_lvl = 0

   local function begin_token()
      table.insert(tokens, { x = x, y = y, i = i })
   end

   local function drop_token()
      table.remove(tokens)
   end

   local function end_token(kind: string, t: string, last: number)
      assert(type(kind) == "string")

      local token: Token = tokens[#tokens]
      token.tk = t or input:sub(token.i, last or i) or ""
      if keywords[token.tk] then
         kind = "keyword"
      end
      token.kind = kind
   end

   while i <= #input do
      if fwd then
         i = i + 1
      end
      if i > #input then
         break
      end

      local c: string = input:sub(i, i)

      if fwd then
         if c == "\n" then
            y = y + 1
            x = 0
         else
            x = x + 1
         end
      else
         fwd = true
      end

      if state == "any" then
         if c == "-" then
            state = "maybecomment"
            begin_token()
         elseif c == "." then
            state = "maybedotdot"
            begin_token()
         elseif c == "\"" then
            state = "dblquote_string"
            begin_token()
         elseif c == "'" then
            state = "singlequote_string"
            begin_token()
         elseif c:match("[a-zA-Z_]") then
            state = "word"
            begin_token()
         elseif c:match("[0-9]") then
            state = "number"
            begin_token()
         elseif c:match("[<>=~]") then
            state = "maybeequals"
            begin_token()
         elseif c == "[" then
            state = "maybelongstring"
            begin_token()
         elseif c:match("[][(){},:#`]") then
            begin_token()
            end_token(c, nil, nil)
         elseif c:match("[+*/]") then
            begin_token()
            end_token("op", nil, nil)
         end
      elseif state == "maybecomment" then
         if c == "-" then
            state = "maybecomment2"
         else
            end_token("op", "-")
            fwd = false
            state = "any"
         end
      elseif state == "maybecomment2" then
         if c == "[" then
            state = "maybelongcomment"
         else
            state = "comment"
            drop_token()
         end
      elseif state == "maybelongcomment" then
         if c == "[" then
            state = "longcomment"
         elseif c == "=" then
            lc_open_lvl = lc_open_lvl + 1
         else
            state = "comment"
            drop_token()
            lc_open_lvl = 0
         end
      elseif state == "longcomment" then
         if c == "]" then
            state = "maybelongcommentend"
         end
      elseif state == "maybelongcommentend" then
         if c == "]" and lc_close_lvl == lc_open_lvl then
            drop_token()
            state = "any"
            lc_open_lvl = 0
            lc_close_lvl = 0
         elseif c == "=" then
            lc_close_lvl = lc_close_lvl + 1
         else
            state = "longcomment"
            lc_close_lvl = 0
         end
      elseif state == "dblquote_string" then
         if c == "\\" then
            state = "escape_dblquote_string"
         elseif c == "\"" then
            end_token("string")
            state = "any"
         end
      elseif state == "escape_dblquote_string" then
         state = "dblquote_string"
      elseif state == "singlequote_string" then
         if c == "\\" then
            state = "escape_singlequote_string"
         elseif c == "'" then
            end_token("string")
            state = "any"
         end
      elseif state == "escape_singlequote_string" then
         state = "singlequote_string"
      elseif state == "maybeequals" then
         if c == "=" then
            end_token("op")
            state = "any"
         else
            end_token("=", nil, i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "maybelongstring" then
         if c == "[" then
            state = "longstring"
         elseif c == "=" then
            ls_open_lvl = ls_open_lvl + 1
         else
            end_token("[", nil, i - 1)
            fwd = false
            state = "any"
            ls_open_lvl = 0
         end
      elseif state == "longstring" then
         if c == "]" then
            state = "maybelongstringend"
         end
      elseif state == "maybelongstringend" then
         if c == "]" and ls_close_lvl == ls_open_lvl then
            end_token("string")
            state = "any"
            ls_open_lvl = 0
            ls_close_lvl = 0
         elseif c == "=" then
            ls_close_lvl = ls_close_lvl + 1
         else
            state = "longstring"
            ls_close_lvl = 0
         end
      elseif state == "maybedotdot" then
         if c == "." then
            end_token("op")
            state = "maybedotdotdot"
         else
            end_token(".", nil, i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "maybedotdotdot" then
         if c == "." then
            end_token("...")
            state = "any"
         else
            end_token("op", nil, i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "comment" then
         if c == "\n" then
            state = "any"
         end
      elseif state == "word" then
         if not c:match("[a-zA-Z0-9_]") then
            end_token("word", nil, i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "number" then
         if not c:match("[0-9]") then
            end_token("number", nil, i - 1)
            fwd = false
            state = "any"
         end
      end
   end

   if #tokens > 0 and tokens[#tokens].tk == nil then
      if state == "word" or state == "number" then
         end_token(state, nil, i - 1)
      else
         drop_token()
      end
   end

   return tokens
end

--------------------------------------------------------------------------------
-- Pretty-print tokens
--------------------------------------------------------------------------------

local add_space: {string:boolean} = {
   ["word:keyword"] = true,
   ["word:word"] = true,
   ["word:string"] = true,
   ["word:="] = true,
   ["word:op"] = true,

   ["keyword:word"] = true,
   ["keyword:keyword"] = true,
   ["keyword:string"] = true,
   ["keyword:number"] = true,
   ["keyword:="] = true,
   ["keyword:op"] = true,
   ["keyword:{"] = true,
   ["keyword:("] = true,
   ["keyword:#"] = true,

   ["=:word"] = true,
   ["=:keyword"] = true,
   ["=:string"] = true,
   ["=:number"] = true,
   ["=:{"] = true,
   ["=:("] = true,
   ["op:("] = true,
   ["op:{"] = true,
   ["op:#"] = true,

   [",:word"] = true,
   [",:keyword"] = true,
   [",:string"] = true,
   [",:{"] = true,

   ["):op"] = true,
   ["):word"] = true,
   ["):keyword"] = true,

   ["op:string"] = true,
   ["op:number"] = true,
   ["op:word"] = true,
   ["op:keyword"] = true,

   ["]:word"] = true,
   ["]:keyword"] = true,
   ["]:="] = true,
   ["]:op"] = true,

   ["string:op"] = true,
   ["string:word"] = true,
   ["string:keyword"] = true,

   ["number:word"] = true,
   ["number:keyword"] = true,
}

local should_unindent: {string:boolean} = {
   ["end"] = true,
   ["elseif"] = true,
   ["else"] = true,
   ["}"] = true,
}

local should_indent: {string:boolean} = {
   ["{"] = true,
   ["for"] = true,
   ["if"] = true,
   ["while"] = true,
   ["elseif"] = true,
   ["else"] = true,
   ["function"] = true,
}

function tl.pretty_print_tokens(tokens: {Token}): string
   local y = 1
   local out = {}
   local indent = 0
   local newline = false
   local kind: string = ""
   for _, t in ipairs(tokens) do
      while t.y > y do
         table.insert(out, "\n")
         y = y + 1
         newline = true
         kind = ""
      end
      if should_unindent[t.tk] then
         indent = indent - 1
         if indent < 0 then
            indent = 0
         end
      end
      if newline then
         for _ = 1, indent do
            table.insert(out, "   ")
         end
         newline = false
      end
      if should_indent[t.tk] then
         indent = indent + 1
      end
      if add_space[(kind or "") .. ":" .. t.kind] then
         table.insert(out, " ")
      end
      table.insert(out, t.tk)
      kind = t.kind or ""
   end
   return table.concat(out)
end

--------------------------------------------------------------------------------
-- Recursive descent parser
--------------------------------------------------------------------------------

local ParseError = record
   y: number
   x: number
   msg: string
end

local Type = record
   {Type}
   y: number
   x: number
   kind: string
   typename: string
   tk: string

   -- poly
   poly: {Type}

   -- typetype
   def: Type

   -- map
   keys: Type
   values: Type

   -- records
   typevars: {Type}
   fields: {string: Type}
   field_order: {string}

   -- array
   elements: Type

   -- function
   is_method: boolean
   args: Type
   rets: Type
   vararg: boolean

   -- nominal
   name: string
   typevals: Type

   -- typevar
   typevar: string

   -- array and record entries
   i: number
   k: string
   v: Type
   items: {Type}
end

local Operator = record
   y: number
   x: number
   arity: number
   op: string
   prec: number
end

local Node = record
   {Node}
   y: number
   x: number
   tk: string
   kind: string

   key: Node
   value: Node

   args: Node
   rets: Type
   body: Node
   vararg: boolean

   name: Node

   module: Node
   record_name: Node

   exp: Node
   thenpart: Node
   elseifs: Node
   elsepart: Node

   -- fornum
   var: Node
   from: Node
   to: Node
   step: Node

   -- forin
   vars: Node
   exps: Node

   -- newtype
   newtype: Type

   -- expressions
   op: Operator
   e1: Node
   e2: Node

   casttype: Type

   typename: string
   type: Type
   decltype: Type
end

local parse_expression: function({Token}, number, {ParseError}): number, Node, number
local parse_statements: function({Token}, number, {ParseError}): number, Node
local parse_argument_list: function({Token}, number, {ParseError}): number, Node


local function fail(tokens: {Token}, i: number, errs: {ParseError}, msg: string): number
   if not tokens[i] then
      local eof = tokens[#tokens]
      table.insert(errs, { y = eof.y, x = eof.x, msg = msg or "unexpected end of file" })
      return #tokens
   end
   table.insert(errs, { y = tokens[i].y, x = tokens[i].x, msg = msg or "syntax error" })
   return i + 1
end

local function verify_tk(tokens: {Token}, i: number, errs: {ParseError}, tk: string): number
   if tokens[i].tk == tk then
      return i + 1
   end
   return fail(tokens, i, errs)
end

local function new_node(tokens: {Token}, i: number, kind: string): Node
   local t = tokens[i]
   return { y = t.y, x = t.x, tk = t.tk, kind = kind or t.kind }
end

local function new_type(tokens: {Token}, i: number, kind: string): Type
   local t = tokens[i]
   return { y = t.y, x = t.x, tk = t.tk, kind = kind or t.kind }
end

local function verify_kind(tokens: {Token}, i: number, errs: {ParseError}, kind: string, node_kind: string): number, Node
   if tokens[i].kind == kind then
      return i + 1, new_node(tokens, i, node_kind)
   end
   return fail(tokens, i, errs)
end

local function parse_table_item(tokens: {Token}, i: number, errs: {ParseError}, n: number): number, Node, number
   local node = new_node(tokens, i, "table_item")
   if tokens[i].kind == "$EOF$" then
      return fail(tokens, i, errs)
   end
   if tokens[i].tk == "[" then
      i = i + 1
      i, node.key = parse_expression(tokens, i, errs)
      i = verify_tk(tokens, i, errs, "]")
      i = verify_tk(tokens, i, errs, "=")
      i, node.value = parse_expression(tokens, i, errs)
      return i, node, n
   elseif tokens[i].kind == "word" and tokens[i+1].tk == "=" then
      i, node.key = verify_kind(tokens, i, errs, "word", "string")
      node.key.tk = "\"" .. node.key.tk .. "\""
      i = verify_tk(tokens, i, errs, "=")
      i, node.value = parse_expression(tokens, i, errs)
      return i, node, n
   else
      node.key = new_node(tokens, i, "number")
      node.key.tk = tostring(n)
      i, node.value = parse_expression(tokens, i, errs)
      return i, node, n + 1
   end
end

local ParseItem = functiontype<`T>({Token}, number, {ParseError}, number): number, `T, number

local function parse_list(tokens: {Token}, i: number, errs: {ParseError}, list: {`T}, close: {string:boolean}, is_sep: boolean, parse_item: ParseItem<`T>): number, `T
   local n = 1
   while tokens[i].kind ~= "$EOF$" do
      if close[tokens[i].tk] then
         break
      end
      local item: `T
      i, item, n = parse_item(tokens, i, errs, n)
      table.insert(list, item)
      if tokens[i].tk == "," then
         i = i + 1
         if is_sep and close[tokens[i].tk] then
            return fail(tokens, i, errs)
         end
      end
   end
   return i, list
end

local function parse_bracket_list(tokens: {Token}, i: number, errs: {ParseError}, list: {`T}, open: string, close: string, is_sep: boolean, parse_item: ParseItem<`T>): number, `T
   i = verify_tk(tokens, i, errs, open)
   i = parse_list(tokens, i, errs, list, { [close] = true }, is_sep, parse_item)
   i = i + 1
   return i, list
end

local function parse_table_literal(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "table_literal")
   return parse_bracket_list(tokens, i, errs, node, "{", "}", false, parse_table_item)
end

local function parse_trying_list(tokens: {Token}, i: number, errs: {ParseError}, list: {`T}, parse_item: function): number, {`T}
   local item
   i, item = parse_item(tokens, i, errs)
   table.insert(list, item)
   if tokens[i].tk == "," then
      while tokens[i].tk == "," do
         i = i + 1
         i, item = parse_item(tokens, i, errs)
         table.insert(list, item)
      end
   end
   return i, list
end

local parse_type_list: function({Token}, number, {ParseError}, string): number, Type

local function parse_function_type(tokens: {Token}, i: number, errs: {ParseError}): number, Type
   i = i + 1
   local node: Type = {
      kind = "typedecl",
      typename = "function",
      args = {},
      rets = {},
   }
   if tokens[i].tk == "(" then
      i, node.args = parse_type_list(tokens, i, errs, "(")
      i = verify_tk(tokens, i, errs, ")")
      i, node.rets = parse_type_list(tokens, i, errs)
   else
      node.vararg = true -- FIXME alert that return values are unknown
   end
   return i, node
end

local function parse_typevar_type(tokens: {Token}, i: number, errs: {ParseError}): number, Type, number
   i = i + 1
   i = verify_kind(tokens, i, errs, "word")
   return i, {
      kind = "typedecl",
      typename = "typevar",
      typevar = "`" .. tokens[i-1].tk,
   }
end

local function parse_typevar_list(tokens: {Token}, i: number, errs: {ParseError}): number, Type
   local typ = new_type(tokens, i, "typevar_list")
   return parse_bracket_list(tokens, i, errs, typ, "<", ">", true, parse_typevar_type)
end

local parse_type: function({Token}, number, {ParseError}): number, Type, number

local function parse_typeval_list(tokens: {Token}, i: number, errs: {ParseError}): number, Type
   local typ = new_type(tokens, i, "typeval_list")
   return parse_bracket_list(tokens, i, errs, typ, "<", ">", true, parse_type)
end

parse_type = function(tokens: {Token}, i: number, errs: {ParseError}): number, Type, number
   if tokens[i].tk == "string"
      or tokens[i].tk == "boolean"
      or tokens[i].tk == "number" then
      return i + 1, { kind = "typedecl", typename = tokens[i].tk }
   elseif tokens[i].tk == "table" then
      return i + 1, {
         kind = "typedecl",
         typename = "map",
         keys = { typename = "any" },
         values = { typename = "any" },
      }
   elseif tokens[i].tk == "function" then
      return parse_function_type(tokens, i, errs)
   elseif tokens[i].tk == "{" then
      i = i + 1
      local decl = new_type(tokens, i, "typedecl")
      local t: Type
      i, t = parse_type(tokens, i, errs)
      if tokens[i].tk == "}" then
         decl.typename = "array"
         decl.elements = t
         i = verify_tk(tokens, i, errs, "}")
      elseif tokens[i].tk == ":" then
         decl.typename = "map"
         i = i + 1
         decl.keys = t
         i, decl.values = parse_type(tokens, i, errs)
         i = verify_tk(tokens, i, errs, "}")
      end
      return i, decl
   elseif tokens[i].tk == "`" then
      return parse_typevar_type(tokens, i, errs)
   elseif tokens[i].kind == "word" then
      local typ: Type = {
         kind = "typedecl",
         typename = "nominal",
         name = tokens[i].tk,
      }
      i = i + 1
      if tokens[i].tk == "<" then
         i, typ.typevals = parse_typeval_list(tokens, i, errs)
      end
      return i, typ
   end
   return fail(tokens, i, errs)
end

parse_type_list = function(tokens: {Token}, i: number, errs: {ParseError}, open: string): number, Type
   local list = new_type(tokens, i, "type_list")
   if tokens[i].tk == (open or ":") then
      i = i + 1
      i = parse_trying_list(tokens, i, errs, list, parse_type)
   end
   return i, list
end

local function parse_function_value(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "function")
   i = verify_tk(tokens, i, errs, "function")
   i, node.args = parse_argument_list(tokens, i, errs)
   i, node.rets = parse_type_list(tokens, i, errs)
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_literal(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   if tokens[i].tk == "{" then
      return parse_table_literal(tokens, i, errs)
   elseif tokens[i].kind == "..." then
      return verify_kind(tokens, i, errs, "...")
   elseif tokens[i].kind == "string" then
      return verify_kind(tokens, i, errs, "string")
   elseif tokens[i].kind == "word" then
      -- TODO function call
      return verify_kind(tokens, i, errs, "word", "variable")
   elseif tokens[i].kind == "number" then
      return verify_kind(tokens, i, errs, "number")
   elseif tokens[i].tk == "true" then
      return verify_kind(tokens, i, errs, "keyword", "boolean")
   elseif tokens[i].tk == "false" then
      return verify_kind(tokens, i, errs, "keyword", "boolean")
   elseif tokens[i].tk == "nil" then
      return verify_kind(tokens, i, errs, "keyword", "nil")
   elseif tokens[i].tk == "function" then
      return parse_function_value(tokens, i, errs)
   end
   return fail(tokens, i, errs)
end

-- Shunting-yard algorithm for parsing expressions, as described in
-- https://www.engr.mun.ca/~theo/Misc/exp_parsing.htm#shunting_yard
do
   local precedences: {number:{string:number}} = {
      [1] = {
         ["not"] = 11,
         ["#"] = 11,
         ["-"] = 11,
         ["~"] = 11,
      },
      [2] = {
         ["or"] = 1,
         ["and"] = 2,
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
         ["+"] = 8,
         ["-"] = 9,
         ["*"] = 10,
         ["/"] = 10,
         ["//"] = 10,
         ["%"] = 10,
         ["^"] = 12,
         ["@funcall"] = 100,
         ["@index"] = 100,
         ["."] = 100,
         [":"] = 100,
      },
   }

   local sentinel: Operator = { op = "sentinel" }

   local function is_unop(token: Token): boolean
      return precedences[1][token.tk] ~= nil
   end

   local function is_binop(token: Token): boolean
      return precedences[2][token.tk] ~= nil
   end

   local function prec(op: Operator): number
      if op == sentinel then
         return -9999
      end
      return precedences[op.arity][op.op]
   end

   local function debug_op(name: string, op: Operator, level: number)
      level = level or 0
      io.stderr:write(("| "):rep(level - 1) .. ("+-") .. name .. "\n")
      io.stderr:write(("| "):rep(level) .. ("+-") .. "op...: " .. tostring(op.op) .. "\n")
      io.stderr:write(("| "):rep(level) .. ("+-") .. "prec.: " .. op.prec .. "\n")
      io.stderr:write(("| "):rep(level) .. ("+-") .. "arity: " .. op.arity .. "\n")
   end

   local function debug_exp(name: string, node: Node, level: number)
      level = level or 0
      io.stderr:write(("| "):rep(level - 1) .. ("+-") .. name .. "\n")
      if node.kind then
         io.stderr:write(("| "):rep(level) .. ("+-") .. "kind.: " .. node.kind .. "\n")
      end
      if node.tk then
         io.stderr:write(("| "):rep(level) .. ("+-") .. "tk...: " .. node.tk .. "\n")
      end
      if type(node.op) == "table" then
         debug_op("op", node.op, level + 1)
      end
      if node.e1 then
         debug_exp("e1", node.e1, level + 1)
      end
      if node.e2 then
         debug_exp("e2", node.e2, level + 1)
      end
      if node[1] then
         for i = 1, #node do
            debug_exp(tostring(i), node[i], level + 1)
         end
      end
   end

   local function pop_operator(operators: {Operator}, operands: {Node}): boolean
      if operators[#operators].arity == 2 then
         local t2: Node = table.remove(operands)
         local t1: Node = table.remove(operands)
         if not t1 or not t2 then
            return false
         end
         local operator: Operator = table.remove(operators)
         table.insert(operands, { y = t1.y, x = t1.x, kind = "op", op = operator, e1 = t1, e2 = t2 })
      else
         local t1: Node = table.remove(operands)
         table.insert(operands, { y = t1.y, x = t1.x, kind = "op", op = table.remove(operators), e1 = t1 })
      end
      return true
   end

   local function push_operator(op: Operator, operators: {Operator}, operands: {Node}): boolean
      while #operands > 0 and prec(operators[#operators]) >= prec(op) do
         local ok = pop_operator(operators, operands)
         if not ok then
            return false
         end
      end
      op.prec = assert(precedences[op.arity][op.op])
      table.insert(operators, op)
      return true
   end

   local P: function({Token}, number, {ParseError}, {Operator}, {Node}): number
   local E: function({Token}, number, {ParseError}, {Operator}, {Node}): number

   P = function(tokens: {Token}, i: number, errs: {ParseError}, operators: {Operator}, operands: {Node}): number
      if tokens[i].kind == "$EOF$" then
         return i
      end
      if is_unop(tokens[i]) then
         local ok = push_operator({ y = tokens[i].y, x = tokens[i].x, arity = 1, op = tokens[i].tk }, operators, operands)
         if not ok then
            return fail(tokens, i, errs)
         end
         i = i + 1
         i = P(tokens, i, errs, operators, operands)
         return i
      elseif tokens[i].tk == "(" then
         i = i + 1
         table.insert(operators, sentinel)
         i = E(tokens, i, errs, operators, operands)
         i = verify_tk(tokens, i, errs, ")")
         table.remove(operators)
         return i
      else
         local leaf: Node
         i, leaf = parse_literal(tokens, i, errs)
         if leaf then
            table.insert(operands, leaf)
         end
         return i
      end
   end

   local function push_arguments(tokens: {Token}, i: number, errs: {ParseError}, operands: {Node}): number
      local args: Node
      local node = new_node(tokens, i, "expression_list")
      i, args = parse_bracket_list(tokens, i, errs, node, "(", ")", true, parse_expression)
      table.insert(operands, args)
      return i
   end

   local function push_index(tokens: {Token}, i: number, errs: {ParseError}, operands: {Node}): number
      local arg: Node
      i = verify_tk(tokens, i, errs, "[")
      i, arg = parse_expression(tokens, i, errs)
      i = verify_tk(tokens, i, errs, "]")
      table.insert(operands, arg)
      return i
   end

   E = function(tokens: {Token}, i: number, errs: {ParseError}, operators: {Operator}, operands: {Node}): number
      if tokens[i].kind == "$EOF$" then
         return i
      end
      i = P(tokens, i, errs, operators, operands)
      while tokens[i].kind ~= "$EOF$" do
         if tokens[i].kind == "string" or tokens[i].kind == "{" then
            local ok = push_operator({ y = tokens[i].y, x = tokens[i].x, arity = 2, op = "@funcall" }, operators, operands)
            if not ok then
               return fail(tokens, i, errs)
            end
            local arglist: Node = new_node(tokens, i, "argument_list")
            local arg: Node
            if tokens[i].kind == "string" then
               arg = new_node(tokens, i)
               i = i + 1
            else
               i, arg = parse_table_literal(tokens, i, errs)
            end
            table.insert(arglist, arg)
            table.insert(operands, arglist)
         elseif tokens[i].tk == "(" then
            local ok = push_operator({ y = tokens[i].y, x = tokens[i].x, arity = 2, op = "@funcall" }, operators, operands)
            if not ok then
               return fail(tokens, i, errs)
            end
            i = push_arguments(tokens, i, errs, operands)
         elseif tokens[i].tk == "[" then
            local ok = push_operator({ y = tokens[i].y, x = tokens[i].x, arity = 2, op = "@index" }, operators, operands)
            if not ok then
               return fail(tokens, i, errs)
            end
            i = push_index(tokens, i, errs, operands)
         elseif is_binop(tokens[i]) then
            local ok = push_operator({ y = tokens[i].y, x = tokens[i].x, arity = 2, op = tokens[i].tk }, operators, operands)
            if not ok then
               return fail(tokens, i, errs)
            end
            i = i + 1
            i = P(tokens, i, errs, operators, operands)
         else
            break
         end
      end
      while operators[#operators] ~= sentinel do
         local ok = pop_operator(operators, operands)
         if not ok then
            return fail(tokens, i, errs)
         end
      end
      return i
   end

   parse_expression = function(tokens: {Token}, i: number, errs: {ParseError}): number, Node, number
      local operands: {Node} = {}
      local operators: {Operator} = {}
      table.insert(operators, sentinel)
      i = E(tokens, i, errs, operators, operands)
      if tokens[i].tk == "as" then
         i = i + 1
         local node = new_node(tokens, i, "cast")
         i, node.casttype = parse_type(tokens, i, errs)
         node.exp = operands[#operands]
         return i, node, 0
      end
      return i, operands[#operands], 0
   end
end

local function parse_variable(tokens: {Token}, i: number, errs: {ParseError}): number, Node, number
   if tokens[i].tk == "..." then
      return verify_kind(tokens, i, errs, "...")
   end
   return verify_kind(tokens, i, errs, "word", "variable")
end

local function parse_argument(tokens: {Token}, i: number, errs: {ParseError}): number, Node, number
   if tokens[i].tk == "..." then
      return verify_kind(tokens, i, errs, "...")
   end
   local node: Node
   i, node = verify_kind(tokens, i, errs, "word", "variable")
   if tokens[i].tk == ":" then
      i = i + 1
      i, node.decltype = parse_type(tokens, i, errs)
   end
   return i, node, 0
end

parse_argument_list = function(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "argument_list")
   return parse_bracket_list(tokens, i, errs, node, "(", ")", true, parse_argument)
end

local function parse_local_function(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "local_function")
   i = verify_tk(tokens, i, errs, "local")
   i = verify_tk(tokens, i, errs, "function")
   i, node.name = verify_kind(tokens, i, errs, "word")
   i, node.args = parse_argument_list(tokens, i, errs)
   i, node.rets = parse_type_list(tokens, i, errs)
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_function(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "global_function")
   i = verify_tk(tokens, i, errs, "function")
   i, node.name = verify_kind(tokens, i, errs, "word")
   if tokens[i].tk == "." then
      i = i + 1
      node.module = node.name
      i, node.name = verify_kind(tokens, i, errs, "word")
      node.kind = "module_function"
   elseif tokens[i].tk == ":" then
      i = i + 1
      node.record_name = node.name
      i, node.name = verify_kind(tokens, i, errs, "word")
      node.kind = "record_method"
   end
   local selfx, selfy = tokens[i].x, tokens[i].y
   i, node.args = parse_argument_list(tokens, i, errs)
   if node.kind == "record_method" then
      table.insert(node.args, 1, { x = selfx, y = selfy, tk = "self", kind = "variable" })
   end
   i, node.rets = parse_type_list(tokens, i, errs)
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_if(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "if")
   i = verify_tk(tokens, i, errs, "if")
   i, node.exp = parse_expression(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "then")
   i, node.thenpart = parse_statements(tokens, i, errs)
   node.elseifs = {}
   while tokens[i].tk == "elseif" do
      i = i + 1
      local subnode = new_node(tokens, i, "elseif")
      i, subnode.exp = parse_expression(tokens, i, errs)
      i = verify_tk(tokens, i, errs, "then")
      i, subnode.thenpart = parse_statements(tokens, i, errs)
      table.insert(node.elseifs, subnode)
   end
   if tokens[i].tk == "else" then
      i = i + 1
      local subnode = new_node(tokens, i, "else")
      i, subnode.elsepart = parse_statements(tokens, i, errs)
      node.elsepart = subnode
   end
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_while(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "while")
   i = verify_tk(tokens, i, errs, "while")
   i, node.exp = parse_expression(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_fornum(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "fornum")
   i = i + 1
   i, node.var = verify_kind(tokens, i, errs, "word", "variable")
   i = verify_tk(tokens, i, errs, "=")
   i, node.from = parse_expression(tokens, i, errs)
   i = verify_tk(tokens, i, errs, ",")
   i, node.to = parse_expression(tokens, i, errs)
   if tokens[i].tk == "," then
      i = i + 1
      i, node.step = parse_expression(tokens, i, errs)
   end
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_forin(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "forin")
   i = i + 1
   node.vars = new_node(tokens, i, "variables")
   i, node.vars = parse_list(tokens, i, errs, node.vars, { ["in"] = true }, true, parse_variable)
   i = verify_tk(tokens, i, errs, "in")
   i, node.exp = parse_expression(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_for(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   if tokens[i+1].kind == "word" and tokens[i+2].tk == "=" then
      return parse_fornum(tokens, i, errs)
   else
      return parse_forin(tokens, i, errs)
   end
end

local function parse_repeat(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "repeat")
   i = verify_tk(tokens, i, errs, "repeat")
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "until")
   i, node.exp = parse_expression(tokens, i, errs)
   return i, node
end

local function parse_do(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "do")
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_break(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "break")
   i = verify_tk(tokens, i, errs, "break")
   return i, node
end

local stop_statement_list: {string:boolean} = {
   ["end"] = true,
   ["else"] = true,
   ["elseif"] = true,
   ["until"] = true,
}

local function parse_return(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "return")
   i = verify_tk(tokens, i, errs, "return")
   node.exps = new_node(tokens, i, "expression_list")
   i = parse_list(tokens, i, errs, node.exps, stop_statement_list, true, parse_expression)
   return i, node
end

local function parse_newtype(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node: Node = new_node(tokens, i, "newtype")
   node.newtype = new_type(tokens, i, "typedecl")
   node.newtype.typename = "typetype"
   if tokens[i].tk == "record" then
      local def = new_type(tokens, i, "typedecl")
      node.newtype.def = def
      def.typename = "record"
      def.fields = {}
      def.field_order = {}
      i = i + 1
      if tokens[i].tk == "<" then
         i, def.typevars = parse_typevar_list(tokens, i, errs)
      end
      while not ((not tokens[i]) or tokens[i].tk == "end") do
         if tokens[i].tk == "{" then
            if def.typename == "arrayrecord" then
               return fail(tokens, i, errs, "duplicated declaration of array element type in record")
            end
            i = i + 1
            local t: Type
            i, t = parse_type(tokens, i, errs)
            if tokens[i].tk == "}" then
               i = verify_tk(tokens, i, errs, "}")
            else
               return fail(tokens, i, errs, "expected an array declaration")
            end
            def.typename = "arrayrecord"
            def.elements = t
         else
            local v: Node
            i, v = verify_kind(tokens, i, errs, "word", "variable")
            if not v then
               return fail(tokens, i, errs, "expected a variable name")
            end
            i = verify_tk(tokens, i, errs, ":")
            local t: Type
            i, t = parse_type(tokens, i, errs)
            if not t then
               return fail(tokens, i, errs, "expected a type")
            end
            def.fields[v.tk] = t
            table.insert(def.field_order, v.tk)
         end
      end
      i = verify_tk(tokens, i, errs, "end")
      return i, node
   elseif tokens[i].tk == "functiontype" then
      local typevars: Type
      i = i + 1
      if tokens[i].tk == "<" then
         i, typevars = parse_typevar_list(tokens, i, errs)
      end
      i = i - 1
      i, node.newtype.def = parse_function_type(tokens, i, errs)
      if typevars then
         node.newtype.def.typevars = typevars
      end
      return i, node
   end
   return fail(tokens, i, errs)
end

local is_newtype: {string:boolean} = {
   ["record"] = true,
   ["functiontype"] = true,
}

local function parse_call_or_assignment(tokens: {Token}, i: number, errs: {ParseError}, is_local: boolean): number, Node
   local asgn: Node = new_node(tokens, i, "assignment")
   if is_local then
      asgn.kind = "local_declaration"
   end

   asgn.vars = new_node(tokens, i, "variables")
   i = parse_trying_list(tokens, i, errs, asgn.vars, is_local and parse_variable or parse_expression)
   assert(#asgn.vars >= 1)
   local lhs: Node = asgn.vars[1]

   if is_local then
      i, asgn.decltype = parse_type_list(tokens, i, errs)
   end
   if tokens[i].tk == "=" then
      asgn.exps = new_node(tokens, i, "values")
      repeat
         i = i + 1
         local val: Node
         if is_newtype[tokens[i].tk] then
            if #asgn.vars > 1 then
               return fail(tokens, i, errs, "cannot perform multiple assignment of type definitions")
            end
            i, val = parse_newtype(tokens, i, errs)
         else
            i, val = parse_expression(tokens, i, errs)
         end
         table.insert(asgn.exps, val)
      until tokens[i].tk ~= ","
      return i, asgn
   elseif is_local then
      return i, asgn
   end
   if lhs.op and lhs.op.op == "@funcall" then
      return i, lhs
   end
   return fail(tokens, i, errs)
end

local function parse_statement(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   if tokens[i].tk == "local" then
      if tokens[i+1].tk == "function" then
         return parse_local_function(tokens, i, errs)
      else
         i = i + 1
         return parse_call_or_assignment(tokens, i, errs, true)
      end
   elseif tokens[i].tk == "function" then
      return parse_function(tokens, i, errs)
   elseif tokens[i].tk == "if" then
      return parse_if(tokens, i, errs)
   elseif tokens[i].tk == "while" then
      return parse_while(tokens, i, errs)
   elseif tokens[i].tk == "repeat" then
      return parse_repeat(tokens, i, errs)
   elseif tokens[i].tk == "for" then
      return parse_for(tokens, i, errs)
   elseif tokens[i].tk == "do" then
      return parse_do(tokens, i, errs)
   elseif tokens[i].tk == "break" then
      return parse_break(tokens, i, errs)
   elseif tokens[i].tk == "return" then
      return parse_return(tokens, i, errs)
   elseif tokens[i].kind == "word" then
      return parse_call_or_assignment(tokens, i, errs, false)
   end
   return fail(tokens, i, errs)
end

parse_statements = function(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "statements")
   while tokens[i].kind ~= "$EOF$" do
      if stop_statement_list[tokens[i].tk] then
         break
      end
      local item: Node
      i, item = parse_statement(tokens, i, errs)
      if not item then
         break
      end
      table.insert(node, item)
   end
   return i, node
end

function tl.parse_program(tokens: {Token}, errs: {ParseError}): number, Node
   errs = errs or {}
   local last = tokens[#tokens]
   table.insert(tokens, { y = last.y, x = last.x + #last.tk, tk = "$EOF$", kind = "$EOF$" })
   return parse_statements(tokens, 1, errs)
end

--------------------------------------------------------------------------------
-- AST traversal
--------------------------------------------------------------------------------

local VisitorCallbacks = record<`N, `T>
   before: function(`N, {`T})
   before_statements: function({`N}, {`T})
   after: function(`N, {`T}, `T): `T
end

local function visit_before(ast: `N, kind: string, visit: {string:VisitorCallbacks<`N,`T>}): `T
   assert(visit[kind], "no visitor for " .. kind)
   if visit["@before"] and visit["@before"].before then
      visit["@before"].before(ast)
   end
   if visit[kind].before then
      visit[kind].before(ast)
   end
   if visit["@before"] and visit["@before"].after then
      visit["@before"].after(ast)
   end
end

local function visit_after(ast: `N, kind: string, visit: {string:VisitorCallbacks<`N,`T>}, xs: {`T}): `T
   if visit["@after"] and visit["@after"].before then
      visit["@after"].before(ast, xs)
   end
   local ret: `T
   if visit[kind].after then
      ret = visit[kind].after(ast, xs)
   end
   if visit["@after"] and visit["@after"].after then
      ret = visit["@after"].after(ast, xs, ret)
   end
   return ret
end

local function recurse_type(ast: Type, visit_type: {string:VisitorCallbacks<Type, `T>}): `T
   visit_before(ast, ast.kind, visit_type)
   local xs: {`T} = {}
   if ast.kind == "type_list" then
      for i, child in ipairs(ast) do
         xs[i] = recurse_type(child, visit_type)
      end
   elseif ast.kind == "typedecl" then
   else
      if not ast.kind then
         error("wat: " .. inspect(ast))
      end
      error("unknown node kind " .. ast.kind)
   end
   return visit_after(ast, ast.kind, visit_type, xs)
end

local function recurse_node(ast: Node, visit_node: {string:VisitorCallbacks<Node, `T>}, visit_type: {string:VisitorCallbacks<Type, `T>}): `T
   visit_before(ast, ast.kind, visit_node)
   local xs: {`T} = {}
   if ast.kind == "statements"
      or ast.kind == "variables"
      or ast.kind == "values"
      or ast.kind == "argument_list"
      or ast.kind == "expression_list"
      or ast.kind == "table_literal" then
      for i, child in ipairs(ast) do
         xs[i] = recurse_node(child, visit_node, visit_type)
      end
   elseif ast.kind == "local_declaration"
          or ast.kind == "assignment" then
      xs[1] = recurse_node(ast.vars, visit_node, visit_type)
      if ast.exps then
         xs[2] = recurse_node(ast.exps, visit_node, visit_type)
      end
   elseif ast.kind == "table_item" then
      xs[1] = recurse_node(ast.key, visit_node, visit_type)
      xs[2] = recurse_node(ast.value, visit_node, visit_type)
   elseif ast.kind == "if" then
      xs[1] = recurse_node(ast.exp, visit_node, visit_type)
      xs[2] = recurse_node(ast.thenpart, visit_node, visit_type)
      for i, e in ipairs(ast.elseifs) do
         table.insert(xs, recurse_node(e, visit_node, visit_type))
      end
      if ast.elsepart then
         table.insert(xs, recurse_node(ast.elsepart, visit_node, visit_type))
      end
   elseif ast.kind == "while" then
      xs[1] = recurse_node(ast.exp, visit_node, visit_type)
      xs[2] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "repeat" then
      xs[1] = recurse_node(ast.body, visit_node, visit_type)
      xs[2] = recurse_node(ast.exp, visit_node, visit_type)
   elseif ast.kind == "function" then
      xs[1] = recurse_node(ast.args, visit_node, visit_type)
      xs[2] = recurse_type(ast.rets, visit_type)
      xs[3] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "forin" then
      xs[1] = recurse_node(ast.vars, visit_node, visit_type)
      xs[2] = recurse_node(ast.exp, visit_node, visit_type)
      if visit_node["forin"].before_statements then
         visit_node["forin"].before_statements(ast)
      end
      xs[3] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "fornum" then
      xs[1] = recurse_node(ast.var, visit_node, visit_type)
      xs[2] = recurse_node(ast.from, visit_node, visit_type)
      xs[3] = recurse_node(ast.to, visit_node, visit_type)
      xs[4] = ast.step and recurse_node(ast.step, visit_node, visit_type)
      xs[5] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "elseif" then
      xs[1] = recurse_node(ast.exp, visit_node, visit_type)
      xs[2] = recurse_node(ast.thenpart, visit_node, visit_type)
   elseif ast.kind == "else" then
      xs[1] = recurse_node(ast.elsepart, visit_node, visit_type)
   elseif ast.kind == "return" then
      xs[1] = recurse_node(ast.exps, visit_node, visit_type)
   elseif ast.kind == "cast" then
      xs[1] = recurse_node(ast.exp, visit_node, visit_type)
   elseif ast.kind == "do" then
      xs[1] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "local_function"
          or ast.kind == "global_function" then
      xs[1] = recurse_node(ast.name, visit_node, visit_type)
      xs[2] = recurse_node(ast.args, visit_node, visit_type)
      xs[3] = recurse_type(ast.rets, visit_type)
      xs[4] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "module_function" then
      xs[1] = recurse_node(ast.module, visit_node, visit_type)
      xs[2] = recurse_node(ast.name, visit_node, visit_type)
      xs[3] = recurse_node(ast.args, visit_node, visit_type)
      xs[4] = recurse_type(ast.rets, visit_type)
      xs[5] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "record_method" then
      xs[1] = recurse_node(ast.record_name, visit_node, visit_type)
      xs[2] = recurse_node(ast.name, visit_node, visit_type)
      xs[3] = recurse_node(ast.args, visit_node, visit_type)
      xs[4] = recurse_type(ast.rets, visit_type)
      if visit_node["record_method"].before_statements then
         visit_node["record_method"].before_statements(ast, xs)
      end
      xs[5] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "op" then
      xs[1] = recurse_node(ast.e1, visit_node, visit_type)
      local p1 = ast.e1.op and ast.e1.op.prec or nil
      if ast.op.op == ":" and ast.e1.kind == "string" then
         p1 = -999
      end
      xs[2] = p1
      if ast.op.arity == 2 then
         xs[3] = recurse_node(ast.e2, visit_node, visit_type)
         xs[4] = ast.e2.op and ast.e2.op.prec
      end
   elseif ast.kind == "newtype" then
      xs[1] = recurse_type(ast.newtype, visit_type)
   elseif ast.kind == "variable"
          or ast.kind == "word"
          or ast.kind == "string"
          or ast.kind == "number"
          or ast.kind == "break"
          or ast.kind == "nil"
          or ast.kind == "..."
          or ast.kind == "boolean" then
   else
      if not ast.kind then
         error("wat: " .. inspect(ast))
      end
      error("unknown node kind " .. ast.kind)
   end
   return visit_after(ast, ast.kind, visit_node, xs)
end

--------------------------------------------------------------------------------
-- Pretty-print AST
--------------------------------------------------------------------------------

local tight_op: {string:boolean} = {
   ["."] = true,
   ["-"] = true,
   ["~"] = true,
   ["#"] = true,
   [":"] = true,
}

local spaced_op: {string:boolean} = {
   ["not"] = true,
   ["or"] = true,
   ["and"] = true,
   ["<"] = true,
   [">"] = true,
   ["<="] = true,
   [">="] = true,
   ["~="] = true,
   ["=="] = true,
   ["|"] = true,
   ["~"] = true,
   ["&"] = true,
   ["<<"] = true,
   [">>"] = true,
   [".."] = true,
   ["+"] = true,
   ["-"] = true,
   ["*"] = true,
   ["/"] = true,
   ["//"] = true,
   ["%"] = true,
   ["^"] = true,
}

function tl.pretty_print_ast(ast: Node): string
   local indent = 0

   local visit_node: {string:VisitorCallbacks<Node, string>} = {
      ["statements"] = {
         after = function(node: Node, children: {string}): string
            local out: {string} = {}
            for _, child in ipairs(children) do
               table.insert(out, ("   "):rep(indent))
               table.insert(out, child)
               table.insert(out, "\n")
            end
            if #children == 0 then
               table.insert(out, "\n")
            end
            return table.concat(out)
         end
      },
      ["local_declaration"] = {
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, "local ")
            table.insert(out, children[1])
            if children[2] then
               table.insert(out, " = ")
               table.insert(out, children[2])
            end
            return table.concat(out)
         end,
      },
      ["assignment"] = {
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, children[1])
            table.insert(out, " = ")
            table.insert(out, children[2])
            return table.concat(out)
         end,
      },
      ["if"] = {
         before = function()
            indent = indent + 1
         end,
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, "if ")
            table.insert(out, children[1])
            table.insert(out, " then\n")
            table.insert(out, children[2])
            indent = indent - 1
            for i = 3, #children do
               table.insert(out, ("   "):rep(indent))
               table.insert(out, children[i])
            end
            table.insert(out, ("   "):rep(indent))
            table.insert(out, "end")
            return table.concat(out)
         end,
      },
      ["while"] = {
         before = function()
            indent = indent + 1
         end,
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, "while ")
            table.insert(out, children[1])
            table.insert(out, " do\n")
            table.insert(out, children[2])
            indent = indent - 1
            table.insert(out, ("   "):rep(indent))
            table.insert(out, "end")
            return table.concat(out)
         end,
      },
      ["repeat"] = {
         before = function()
            indent = indent + 1
         end,
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, "repeat\n")
            table.insert(out, children[1])
            indent = indent - 1
            table.insert(out, ("   "):rep(indent))
            table.insert(out, "until ")
            table.insert(out, children[2])
            return table.concat(out)
         end,
      },
      ["do"] = {
         before = function()
            indent = indent + 1
         end,
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, "do\n")
            table.insert(out, children[1])
            indent = indent - 1
            table.insert(out, ("   "):rep(indent))
            table.insert(out, "end")
            return table.concat(out)
         end,
      },
      ["forin"] = {
         before = function()
            indent = indent + 1
         end,
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, "for ")
            table.insert(out, children[1])
            table.insert(out, " in ")
            table.insert(out, children[2])
            table.insert(out, " do\n")
            table.insert(out, children[3])
            indent = indent - 1
            table.insert(out, ("   "):rep(indent))
            table.insert(out, "end")
            return table.concat(out)
         end,
      },
      ["fornum"] = {
         before = function()
            indent = indent + 1
         end,
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, "for ")
            table.insert(out, children[1])
            table.insert(out, " = ")
            table.insert(out, children[2])
            table.insert(out, ", ")
            table.insert(out, children[3])
            if children[4] then
               table.insert(out, ", ")
               table.insert(out, children[4])
            end
            table.insert(out, " do\n")
            table.insert(out, children[5])
            indent = indent - 1
            table.insert(out, ("   "):rep(indent))
            table.insert(out, "end")
            return table.concat(out)
         end,
      },
      ["cast"] = {
         after = function(node: Node, children: {string}): string
            return children[1]
         end,
      },
      ["return"] = {
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, "return ")
            table.insert(out, children[1])
            return table.concat(out)
         end,
      },
      ["break"] = {
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, "break")
            return table.concat(out)
         end,
      },
      ["elseif"] = {
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, "elseif ")
            table.insert(out, children[1])
            table.insert(out, " then\n")
            table.insert(out, children[2])
            return table.concat(out)
         end,
      },
      ["else"] = {
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, "else\n")
            table.insert(out, children[1])
            return table.concat(out)
         end,
      },
      ["variables"] = {
         after = function(node: Node, children: {string}): string
            local out = {}
            for i, child in ipairs(children) do
               if i > 1 then
                  table.insert(out, ", ")
               end
               table.insert(out, tostring(child))
            end
            return table.concat(out)
         end,
      },
      ["table_literal"] = {
         before = function()
            indent = indent + 1
         end,
         after = function(node: Node, children: {string}): string
            local out = {}
            if #children == 0 then
               indent = indent - 1
               return "{}"
            end
            table.insert(out, "{\n")
            for _, child in ipairs(children) do
               table.insert(out, ("   "):rep(indent))
               table.insert(out, child)
               table.insert(out, "\n")
            end
            indent = indent - 1
            table.insert(out, ("   "):rep(indent))
            table.insert(out, "}")
            return table.concat(out)
         end,
      },
      ["table_item"] = {
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, "[")
            table.insert(out, children[1])
            table.insert(out, "] = ")
            table.insert(out, children[2])
            table.insert(out, ", ")
            return table.concat(out)
         end,
      },
      ["local_function"] = {
         before = function()
            indent = indent + 1
         end,
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, "local function ")
            table.insert(out, children[1])
            table.insert(out, "(")
            table.insert(out, children[2])
            table.insert(out, ")\n")
            table.insert(out, children[4])
            indent = indent - 1
            table.insert(out, ("   "):rep(indent))
            table.insert(out, "end")
            return table.concat(out)
         end,
      },
      ["global_function"] = {
         before = function()
            indent = indent + 1
         end,
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, "function ")
            table.insert(out, children[1])
            table.insert(out, "(")
            table.insert(out, children[2])
            table.insert(out, ")\n")
            table.insert(out, children[4])
            indent = indent - 1
            table.insert(out, ("   "):rep(indent))
            table.insert(out, "end")
            return table.concat(out)
         end,
      },
      ["module_function"] = {
         before = function()
            indent = indent + 1
         end,
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, "function ")
            table.insert(out, children[1])
            table.insert(out, ".")
            table.insert(out, children[2])
            table.insert(out, "(")
            table.insert(out, children[3])
            table.insert(out, ")\n")
            table.insert(out, children[5])
            indent = indent - 1
            table.insert(out, ("   "):rep(indent))
            table.insert(out, "end")
            return table.concat(out)
         end,
      },
      ["record_method"] = {
         before = function()
            indent = indent + 1
         end,
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, "function ")
            table.insert(out, children[1])
            table.insert(out, ":")
            table.insert(out, children[2])
            table.insert(out, "(")
            table.insert(out, children[3])
            table.insert(out, ")\n")
            table.insert(out, children[5])
            indent = indent - 1
            table.insert(out, ("   "):rep(indent))
            table.insert(out, "end")
            return table.concat(out)
         end,
      },
      ["function"] = {
         before = function()
            indent = indent + 1
         end,
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, "function(")
            table.insert(out, children[1])
            table.insert(out, ")\n")
            table.insert(out, children[3])
            indent = indent - 1
            table.insert(out, ("   "):rep(indent))
            table.insert(out, "end")
            return table.concat(out)
         end,
      },
      ["op"] = {
         after = function(node: Node, children: {string}): string
            local out = {}
            if node.op.op == "@funcall" then
               table.insert(out, children[1])
               table.insert(out, "(")
               table.insert(out, children[3])
               table.insert(out, ")")
            elseif node.op.op == "@index" then
               table.insert(out, children[1])
               table.insert(out, "[")
               table.insert(out, children[3])
               table.insert(out, "]")
            elseif tight_op[node.op.op] or spaced_op[node.op.op] then
               if node.op.arity == 1 then
                  table.insert(out, node.op.op)
                  if spaced_op[node.op.op] then
                     table.insert(out, " ")
                  end
               end
               if children[2] and node.op.prec > tonumber(children[2]) then
                  table.insert(out, "(")
               end
               table.insert(out, children[1])
               if children[2] and node.op.prec > tonumber(children[2]) then
                  table.insert(out, ")")
               end
               if node.op.arity == 2 then
                  if spaced_op[node.op.op] then
                     table.insert(out, " ")
                  end
                  table.insert(out, node.op.op)
                  if spaced_op[node.op.op] then
                     table.insert(out, " ")
                  end
                  if children[4] and node.op.prec > tonumber(children[4]) then
                     table.insert(out, "(")
                  end
                  table.insert(out, children[3])
                  if children[4] and node.op.prec > tonumber(children[4]) then
                     table.insert(out, ")")
                  end
               end
            else
               error("unknown node op " .. node.op.op)
            end
            return table.concat(out)
         end,
      },
      ["variable"] = {
         after = function(node: Node, children: {string}): string
            local out = {}
            table.insert(out, node.tk)
            return table.concat(out)
         end,
      },
      ["newtype"] = {
         after = function(node: Node, children: {string}): string
            return "{}"
         end,
      },
   }

   local visit_type: {string:VisitorCallbacks<Type, string>} = {
      ["type_list"] = {
         after = function(typ: Type, children: {string}): string
            return ""
         end,
      },
   }

   visit_node["values"] = visit_node["variables"]
   visit_node["expression_list"] = visit_node["variables"]
   visit_node["argument_list"] = visit_node["variables"]

   visit_node["word"] = visit_node["variable"]
   visit_node["string"] = visit_node["variable"]
   visit_node["number"] = visit_node["variable"]
   visit_node["nil"] = visit_node["variable"]
   visit_node["boolean"] = visit_node["variable"]
   visit_node["..."] = visit_node["variable"]

   visit_type["typedecl"] = visit_type["type_list"]

   return recurse_node(ast, visit_node, visit_type)
end

--------------------------------------------------------------------------------
-- Type check
--------------------------------------------------------------------------------

local ANY = { typename = "any" }
local NIL = { typename = "nil" }
local NUMBER = { typename = "number" }
local STRING = { typename = "string" }
local BOOLEAN = { typename = "boolean" }
local ALPHA = { typename = "typevar", typevar = "`a" }
local BETA = { typename = "typevar", typevar = "`b" }
local ARRAY_OF_ANY = { typename = "array", elements = ANY }
local ARRAY_OF_STRING = { typename = "array", elements = STRING }
local ARRAY_OF_ALPHA = { typename = "array", elements = ALPHA }
local MAP_OF_ALPHA_TO_BETA = { typename = "map", keys = ALPHA, values = BETA }
local FUNCTION = { typename = "function", vararg = true, args = {}, rets = {} }
local INVALID = { typename = "invalid" }
local NOMINAL_FILE = { typename = "nominal", name = "FILE" }
local METATABLE = { typename = "nominal", name = "METATABLE" }

local numeric_binop = {
   ["number"] = {
      ["number"] = NUMBER,
   }
}

local relational_binop = {
   ["number"] = {
      ["number"] = BOOLEAN,
   },
   ["string"] = {
      ["string"] = BOOLEAN,
   },
   ["boolean"] = {
      ["boolean"] = BOOLEAN,
   },
}

local equality_binop = {
   ["number"] = {
      ["number"] = BOOLEAN,
      ["nil"] = BOOLEAN,
   },
   ["string"] = {
      ["string"] = BOOLEAN,
      ["nil"] = BOOLEAN,
   },
   ["boolean"] = {
      ["boolean"] = BOOLEAN,
      ["nil"] = BOOLEAN,
   },
   ["record"] = {
      ["arrayrecord"] = BOOLEAN,
      ["record"] = BOOLEAN,
      ["nil"] = BOOLEAN,
   },
   ["array"] = {
      ["arrayrecord"] = BOOLEAN,
      ["array"] = BOOLEAN,
      ["nil"] = BOOLEAN,
   },
   ["arrayrecord"] = {
      ["arrayrecord"] = BOOLEAN,
      ["record"] = BOOLEAN,
      ["array"] = BOOLEAN,
      ["nil"] = BOOLEAN,
   },
   ["map"] = {
      ["map"] = BOOLEAN,
      ["nil"] = BOOLEAN,
   },
}

local unop_types: {string:{string:Type}} = {
   ["#"] = {
      ["arrayrecord"] = NUMBER,
      ["string"] = NUMBER,
      ["array"] = NUMBER,
      ["map"] = NUMBER,
   },
   ["-"] = {
      ["number"] = NUMBER,
   },
   ["not"] = {
      ["string"] = BOOLEAN,
      ["number"] = BOOLEAN,
      ["boolean"] = BOOLEAN,
      ["record"] = BOOLEAN,
      ["arrayrecord"] = BOOLEAN,
      ["array"] = BOOLEAN,
      ["map"] = BOOLEAN,
   },
}

local binop_types: {string:{string:{string:Type}}} = {
   ["+"] = numeric_binop,
   ["-"] = {
      ["number"] = {
         ["number"] = NUMBER,
      }
   },
   ["*"] = numeric_binop,
   ["/"] = numeric_binop,
   ["=="] = equality_binop,
   ["~="] = equality_binop,
   ["<="] = relational_binop,
   [">="] = relational_binop,
   ["<"] = relational_binop,
   [">"] = relational_binop,
   ["or"] = {
      ["boolean"] = {
         ["boolean"] = BOOLEAN,
         ["function"] = FUNCTION, -- HACK
      },
      ["number"] = {
         ["number"] = NUMBER,
         ["boolean"] = BOOLEAN,
      },
      ["string"] = {
         ["string"] = STRING,
         ["boolean"] = BOOLEAN,
      },
      ["function"] = {
         ["function"] = FUNCTION,
         ["boolean"] = BOOLEAN,
      },
      ["array"] = {
         ["boolean"] = BOOLEAN,
      },
      ["record"] = {
         ["boolean"] = BOOLEAN,
      },
      ["arrayrecord"] = {
         ["boolean"] = BOOLEAN,
      },
      ["map"] = {
         ["boolean"] = BOOLEAN,
      },
   },
   [".."] = {
      ["string"] = {
         ["string"] = STRING,
         ["number"] = STRING,
      },
      ["number"] = {
         ["number"] = STRING,
         ["string"] = STRING,
      }
   },
}

local function show_type(t: Type): string
   if t.typename == "nominal" then
      if t.typevals then
         local out = { t.name, "<" }
         local vals: {string} = {}
         for _, v in ipairs(t.typevals) do
            table.insert(vals, show_type(v))
         end
         table.insert(out, table.concat(vals, ", "))
         table.insert(out, ">")
         return table.concat(out)
      else
         return t.name
      end
   elseif t.typename == "tuple" then
      local out: {string} = {}
      for _, v in ipairs(t) do
         table.insert(out, show_type(v))
      end
      return "(" .. table.concat(out, ", ") .. ")"
   elseif t.typename == "poly" then
      local out: {string} = {}
      for _, v in ipairs(t.poly) do
         table.insert(out, show_type(v))
      end
      return table.concat(out, " or ")
   elseif t.typename == "map" then
      return "{" .. show_type(t.keys) .. " : " .. show_type(t.values) .. "}"
   elseif t.typename == "array" then
      return "{" .. show_type(t.elements) .. "}"
   elseif t.typename == "record" then
      local out: {string} = {}
      for _, k in ipairs(t.field_order) do
         local v = t.fields[k]
         table.insert(out, k .. ": " .. show_type(v))
      end
      return "{" .. table.concat(out, ", ") .. "}"
   elseif t.typename == "function" then
      local out: {string} = {}
      table.insert(out, "function(")
      local args = {}
      if t.is_method then
         table.insert(args, "self")
      end
      for i, v in ipairs(t.args) do
         if not t.is_method or i > 1 then
            table.insert(args, show_type(v))
         end
      end
      table.insert(out, table.concat(args, ","))
      table.insert(out, ")")
      if #t.rets > 0 then
         table.insert(out, ":")
         local rets = {}
         for _, v in ipairs(t.rets) do
            table.insert(rets, show_type(v))
         end
         table.insert(out, table.concat(rets, ","))
      end
      return table.concat(out)
   elseif t.typename == "string"
       or t.typename == "number"
       or t.typename == "boolean" then
      return t.typename
   elseif t.typename == "typevar" then
      return t.typevar
   elseif t.typename == "unknown" then
      return "<unknown type>"
   elseif t.typename == "invalid" then
      return "<invalid type>"
   elseif t.typename == "any" then
      return "<any type>"
   else
      return inspect(t)
   end
end

function tl.type_check(ast: Node): {Error}
   local st: {{string:Type}} = {
      {
         ["@return"] = { typename = "tuple", ANY },
         ["any"] = { typename = "typetype", def = ANY },
         ["require"] = { typename = "function", args = { STRING }, rets = {} },
         ["setmetatable"] = { typename = "function", args = { ALPHA, METATABLE }, rets = { ALPHA } },
         ["next"] = {
            typename = "poly",
            poly = {
               { typename = "function", args = { MAP_OF_ALPHA_TO_BETA }, rets = { ALPHA, BETA } },
               { typename = "function", args = { ARRAY_OF_ALPHA }, rets = { NUMBER, ALPHA } },
            },
         },
         ["FILE"] = {
            typename = "typetype",
            def = {
               typename = "record",
               fields = {
                  ["write"] = { typename = "function", args = { NOMINAL_FILE, STRING }, rets = {} },
                  -- TODO complete...
               },
            },
         },
         ["METATABLE"] = {
            typename = "typetype",
            def = {
               typename = "record",
               fields = {
                  ["__tostring"] = { typename = "function", args = {}, rets = { STRING } },
                  -- TODO complete...
               },
            },
         },
         ["io"] = {
            typename = "record",
            fields = {
               ["stderr"] = NOMINAL_FILE,
            },
         },
         ["table"] = {
            typename = "record",
            fields = {
               ["insert"] = {
                  typename = "poly",
                  poly = {
                     { typename = "function", args = { ARRAY_OF_ALPHA, NUMBER, ANY }, rets = {} },
                     { typename = "function", args = { ARRAY_OF_ALPHA, ANY }, rets = {} },
                  }
               },
               ["remove"] = {
                  typename = "poly",
                  poly = {
                     { typename = "function", args = { ARRAY_OF_ALPHA, NUMBER }, rets = { ALPHA } },
                     { typename = "function", args = { ARRAY_OF_ALPHA }, rets = { ALPHA } },
                  }
               },
               ["concat"] = {
                  typename = "poly",
                  poly = {
                     { typename = "function", args = { ARRAY_OF_STRING, STRING }, rets = { STRING } },
                     { typename = "function", args = { ARRAY_OF_STRING }, rets = { STRING } },
                  }
               },
               ["sort"] = { typename = "function", args = { ARRAY_OF_ALPHA }, rets = {} },
            },
         },
         ["string"] = {
            typename = "record",
            fields = {
               ["sub"] = { typename = "function", args = { STRING, NUMBER, NUMBER }, rets = { STRING } },
               ["match"] = { typename = "function", args = { STRING, STRING }, rets = { STRING } },
               ["rep"] = { typename = "function", args = { STRING, NUMBER }, rets = { STRING } },
               ["gsub"] = {
                  typename = "poly",
                  poly = {
                     { typename = "function", args = { STRING, STRING, STRING }, rets = { STRING } },
                     { typename = "function", args = { STRING, STRING, { typename = "map", keys = STRING, values = STRING } }, rets = { STRING } },
                     -- FIXME any other modes
                  }
               },
               ["char"] = { typename = "function", args = { NUMBER }, rets = { STRING } },
               ["format"] = { typename = "function", args = { STRING }, vararg = true, rets = { STRING } },
            },
         },
         ["math"] = {
            typename = "record",
            fields = {
               ["min"] = { typename = "function", args = { NUMBER, NUMBER }, rets = { NUMBER } },
            },
         },
         ["type"] = { typename = "function", args = { ANY }, rets = { STRING } },
         ["ipairs"] = { typename = "function", args = { ARRAY_OF_ALPHA }, rets = {
            { typename = "function", args = {}, rets = { NUMBER, ALPHA } },
         } },
         ["pairs"] = { typename = "function", args = { { typename = "map", keys = ALPHA, values = BETA } }, rets = {
            { typename = "function", args = {}, rets = { ALPHA, BETA } },
         } },
         ["assert"] = {
            typename = "poly",
            poly = {
               { typename = "function", args = { ALPHA }, rets = { ALPHA } },
               { typename = "function", args = { ALPHA, STRING }, rets = { ALPHA } },
            }
         },
         ["print"] = {
            typename = "poly",
            poly = {
               { typename = "function", args = { ANY }, rets = {} },
               { typename = "function", args = { ANY, ANY }, rets = {} },
               { typename = "function", args = { ANY, ANY, ANY }, rets = {} },
               { typename = "function", args = { ANY, ANY, ANY, ANY }, rets = {} },
               { typename = "function", args = { ANY, ANY, ANY, ANY, ANY }, rets = {} },
            }
         },
         ["tostring"] = { typename = "function", args = { ANY }, rets = { STRING } },
         ["tonumber"] = { typename = "function", args = { ANY }, rets = { NUMBER } },
         ["error"] = { typename = "function", args = { STRING }, rets = {} },
         ["debug"] = {
            typename = "record",
            fields = {
               ["traceback"] = { typename = "function", args = {}, rets = { STRING } },
            },
         }
      }
   }
   local function fill_field_order(t: Type)
      if t.typename == "record" then
         t.field_order = {}
         for k, v in pairs(t.fields) do
            table.insert(t.field_order, k)
         end
         table.sort(t.field_order)
      end
   end
   for _, t in pairs(st[1]) do
      fill_field_order(t)
   end
   fill_field_order(st[1]["FILE"].def)

   local Error = record
      y: number
      x: number
      err: string
   end

   local errors: {Error} = {}

   local function find_var(name: string): Type
      for i = #st, 1, -1 do
         local scope = st[i]
         if scope[name] then
            return scope[name]
         end
      end
      return { typename = "unknown", tk = name }
   end

   local function resolve_tuple(t: Type): Type
      if t.typename == "tuple" then
         t = t[1]
      end
      if t == nil then
         return NIL
      end
      return t
   end

   local function resolve_typevars(t: Type, typevars: {string:Type}, has_cycle: {Type:boolean}): Type
      has_cycle = has_cycle or {}
      if has_cycle[t] then
         error("HAS CYCLE IN TYPE " .. inspect(t))
      end
      has_cycle[t] = true
      if t.typename == "typevar" then
         if not typevars[t.typevar] then
            return t -- leave it unresolved
         end
         return typevars[t.typevar]
      end
      local copy: {string:Type} = {}
      for k, v in pairs(t as {string:Type}) do
         if type(v) == "table" and k ~= "type" then
            copy[k] = resolve_typevars(v, typevars, has_cycle)
         else
            copy[k] = v
         end
      end
      return copy as Type
   end

   local function resolve_nominal(t: Type, typevars: {string:Type}): Type
      local typetype = find_var(t.name)
      local y, x = -1, -1 -- FIXME
      if typetype.typename == "typetype" then
         local def = typetype.def
         if t.typevals and def.typevars then
            if #t.typevals ~= #def.typevars then
               table.insert(errors, { y = y, x = x, err = "mismatch in number of type arguments" })
               return { typename = "bad_nominal", name = t.name }
            end

            local newtypevars: {string:Type} = {}
            for k,v in pairs(typevars or {}) do
               newtypevars[k] = v
            end
            for i, tt in ipairs(t.typevals) do
               newtypevars[def.typevars[i].typevar] = tt
            end
            return resolve_typevars(def, newtypevars)
         elseif t.typevals then
            table.insert(errors, { y = y, x = x, err = "spurious type arguments" })
         elseif def.typevars then
            table.insert(errors, { y = y, x = x, err = "missing type arguments in " .. show_type(def) })
         end
         return def
      else
         return { typename = "bad_nominal", name = t.name }
      end
   end

   local function resolve_unary(t: Type, typevars: {string:Type}): Type
      t = resolve_tuple(t)
      if t.typename == "nominal" then
         return resolve_nominal(t, typevars)
      end
      return t
   end

   local CompareTypes = functiontype(Type, Type, {string:Type}, boolean): boolean

   local function compare_typevars(t1: Type, t2: Type, typevars: {string:Type}, comp: CompareTypes): boolean
      if t1.typevar == t2.typevar then
         return true
      end
      if not typevars then
         return false
      end
      local function cmp(k: string, v: Type, a: Type, b: Type): boolean
         if typevars[k] then
            return comp(a, b, typevars)
         else
            typevars[k] = v
            return true
         end
      end
      if t1.typename == "typevar" then
         return cmp(t1.typevar, t2, typevars[t1.typevar], t2)
      else
         return cmp(t2.typevar, t1, t1, typevars[t2.typevar])
      end
   end

   local function same_type(t1: Type, t2: Type, typevars: {string:Type}): boolean
      assert(type(t1) == "table")
      assert(type(t2) == "table")

      if t1.typename == "typevar" or t2.typename == "typevar" then
         return compare_typevars(t1, t2, typevars, same_type)
      end

      if t1.typename ~= t2.typename then
         return false
      end
      if t1.typename == "array" then
         return same_type(t1.elements, t2.elements)
      elseif t1.typename == "map" then
         return same_type(t1.keys, t2.keys) and same_type(t1.values, t2.values)
      elseif t1.typename == "nominal" then
         return t1.name == t2.name
      end
      return true
   end

   local function is_empty_table(t: Type): boolean
      return t.typename == "record" and next(t.fields) == nil
   end

   local TypeGetter = functiontype(string): Type

   local is_a: function(Type, Type, {string:Type}, boolean): boolean, string

   local function match_record_fields(t1: Type, t2: TypeGetter, typevars: {string:Type}): boolean, string
      local fielderrs: {string} = {}
      for _, k in ipairs(t1.field_order) do
         local f = t1.fields[k]
         local t2k = t2(k)
         if t2k == nil then
            table.insert(fielderrs, "unknown field " .. k)
         else
            local match, why_not = is_a(f, t2k, typevars)
            if not match then
               table.insert(fielderrs, k .. (why_not and ": " .. why_not or ""))
            end
         end
      end
      if #fielderrs > 0 then
         return false, "record fields don't match: " .. table.concat(fielderrs, "; ")
      end
      return true
   end

   local function match_fields_to_record(t1: Type, t2: Type, typevars: {string:Type}): boolean, string
      return match_record_fields(t1, function(k: string): Type return t2.fields[k] end, typevars)
   end

   local function match_fields_to_map(t1: Type, t2: Type, typevars: {string:Type}): boolean, string
      return match_record_fields(t1, function(_: string): Type return t2.values end, typevars)
   end

   is_a = function(t1: Type, t2: Type, typevars: {string:Type}, for_equality: boolean): boolean, string
      assert(type(t1) == "table")
      assert(type(t2) == "table")

      if t2.typename ~= "tuple" then
         t1 = resolve_tuple(t1)
      end
      if t2.typename == "tuple" and t1.typename ~= "tuple" then
         t1 = {
            typename = "tuple",
            [1] = t1,
         }
      end

      if t1.typename == "typevar" or t2.typename == "typevar" then
         return compare_typevars(t1, t2, typevars, is_a)
      end

      if t2.typename == "any" then
         return true
      elseif t2.typename == "poly" then
         for _, t in ipairs(t2.poly) do
            if is_a(t1, t, typevars) then
               return true
            end
         end
         return false
      elseif t1.typename == "poly" then
         for _, t in ipairs(t1.poly) do
            if is_a(t, t2, typevars) then
               return true
            end
         end
         return false
      elseif t1.typename == "nil" then -- TODO nilable
         return true
      elseif t1.typename == "nominal" and t2.typename == "nominal" and t2.name == "any" then
         return true
      elseif t1.typename == "nominal" and t2.typename == "nominal" then
         if t1.name == t2.name then
            if t1.typevals == nil and t2.typevals == nil then
               return true
            elseif t1.typevals and t2.typevals and #t1.typevals == #t2.typevals then
               for i = 1, #t1.typevals do
                  if not same_type(t1.typevals[i], t2.typevals[i], typevars) then
                     return false
                  end
               end
               return true
            end
         end
         return false
      elseif t1.typename == "nominal" or t2.typename == "nominal" then
         t1 = resolve_unary(t1, typevars)
         t2 = resolve_unary(t2, typevars)
         return is_a(t1, t2, typevars)
      elseif is_empty_table(t1) and (t2.typename == "array" or t2.typename == "map" or t2.typename == "record" or t2.typename == "arrayrecord") then
         return true
      elseif t2.typename == "array" then
         if t1.typename == "array" or t1.typename == "arrayrecord" then
            return is_a(t1.elements, t2.elements, typevars)
         elseif t1.typename == "map" then
            return is_a(t1.keys, NUMBER, typevars) and is_a(t1.values, t2.elements, typevars)
         end
         return false
      elseif t2.typename == "record" then
         if t1.typename == "record" or t1.typename == "arrayrecord" then
            return match_fields_to_record(t1, t2, typevars)
         elseif t1.typename == "map" then
            if not is_a(t1.keys, STRING, typevars) then
               return false
            end
            for _, f in pairs(t2.fields) do
               if not is_a(t1.values, f, typevars) then
                  return false
               end
            end
            return true
         end
         return false
      elseif t2.typename == "arrayrecord" then
         if t1.typename == "array" then
            return is_a(t1.elements, t2.elements, typevars)
         elseif t1.typename == "record" then
            return match_fields_to_record(t1, t2, typevars)
         elseif t1.typename == "arrayrecord" then
            if not is_a(t1.elements, t2.elements, typevars) then
               return false
            end
            return match_fields_to_record(t1, t2, typevars)
         end
         return false
      elseif t2.typename == "map" then
         if t1.typename == "map" then
            local matchkeys = is_a(t1.keys, t2.keys, typevars)
            local matchvalues = is_a(t2.values, t1.values, typevars)
            return matchkeys and matchvalues
         elseif t1.typename == "array" then
            return is_a(NUMBER, t2.keys, typevars) and is_a(t1.elements, t2.values, typevars)
         elseif t1.typename == "record" or t1.typename == "arrayrecord" then -- FIXME
            if not is_a(STRING, t2.keys, typevars) then
               return false, "can't match a record to a map with non-string keys"
            end
            return match_fields_to_map(t1, t2, typevars)
         end
         return false
      elseif t1.typename == "function" and t2.typename == "function" then
         if (not t2.vararg) and #t1.args > #t2.args then
            return false, "failed on number of arguments"
         end
         if #t1.rets < #t2.rets then
            return false, "failed on number of returns"
         end
         for i = (t1.is_method and 2 or 1), #t1.args do
            if not is_a(t1.args[i], t2.args[i] or ANY, typevars) then
               return false, "failed on argument " .. i
            end
         end
         for i = 1, #t2.rets do
            if not same_type(t1.rets[i], t2.rets[i], typevars) then
               return false, "failed on return " .. i
            end
         end
         return true
      elseif (not for_equality) and t2.typename == "boolean" then -- all values can be used in a boolean context (but not in == or ~=)
         return true
      elseif t1.typename ~= t2.typename then
         return false
      end
      return true
   end

   local function assert_is_a(node: Node, t1: Type, t2: Type, typevars: {string:Type}, context: string)
      t1 = resolve_tuple(t1)
      t2 = resolve_tuple(t2)
      local match, why_not = is_a(t1, t2, typevars)
      if not match then
         table.insert(errors, { y = node.y, x = node.x, err = context .. " mismatch: " .. (node.tk or node.op.op) .. ": " .. show_type(t1) .. " is not a " .. show_type(t2) .. (why_not and ": " .. why_not or "") })
      end
   end

   local function try_match_func_args(node: Node, f: Type, args: {Type}, is_method: boolean): Type, {Error}
      local ok = true
      local typevars = {}
      local errs = {}

      if f.is_method and not is_method and not is_a(args[1], f.args[1], typevars) then
         table.insert(errs, { y = node.y, x = node.x, err = "invoked method as a regular function: use ':' instead of '.'" })
         return nil, errs
      end

      for a = 1, math.min(#args, #f.args) do
         local arg = args[a]
         local matches, why_not = is_a(arg, f.args[a], typevars)
         if not matches then
            errs = errs or {}
            local at = node.e2 and node.e2[a] or node
            table.insert(errs, { y = at.y, x = at.x, err = "error in argument " .. (is_method and a-1 or a) .. ": " .. show_type(arg) .. " is not a " .. show_type(f.args[a]) .. (why_not and ": " .. why_not or "") })
            ok = false
            break
         end
      end
      if ok == true then
         f.rets.typename = "tuple"
         return resolve_typevars(f.rets, typevars)
      end
      return nil, errs
   end

   local function match_func_args(node: Node, func: Type, args: {Type}, is_method: boolean): Type
      assert(type(func) == "table")
      assert(type(args) == "table")

      func = resolve_unary(func, {}) -- FIXME propagate typevars?

      args = args or {}
      local poly: Type = func.typename == "poly" and func or { poly = { func } }
      local first_errs: {Error}
      local expects: {string} = {}
      -- try exact match first
      for _, f in ipairs(poly.poly) do
         if f.typename ~= "function" then
            table.insert(errors, { y = node.y, x = node.x, err = "not a function: " .. show_type(f) })
            return INVALID
         end
         table.insert(expects, tostring(#f.args or 0))
         if #args == (#f.args or 0) then
            local matched, errs = try_match_func_args(node, f, args, is_method)
            if matched then
               return matched
            end
            first_errs = first_errs or errs
         end
      end
      -- [nil-lenient] now try passing nils to missing arguments
      for _, f in ipairs(poly.poly) do
         if #args < (#f.args or 0) then
            local matched, errs = try_match_func_args(node, f, args, is_method)
            if matched then
               return matched
            end
            first_errs = first_errs or errs
         end
      end
      -- now try vararg functions
      for _, f in ipairs(poly.poly) do
         if f.vararg and #args > (#f.args or 0) then
            local matched, errs = try_match_func_args(node, f, args, is_method)
            if matched then
               return matched
            end
            first_errs = first_errs or errs
         end
      end

      if not first_errs then
         table.insert(errors, { y = node.y, x = node.x, err = "wrong number of arguments (given " .. #args .. ", expects " .. table.concat(expects, " or ") .. ")" }) -- .. " => " .. debug.traceback() })
      else
         for _, err in ipairs(first_errs) do
            table.insert(errors, err)
         end
      end

      poly.poly[1].rets.typename = "tuple"
      return poly.poly[1].rets
   end

   local function match_record_key(node: Node, tbl: Type, key: Node, orig_tbl: Type): Type
      assert(type(tbl) == "table")
      assert(type(key) == "table")

      tbl = resolve_unary(tbl)
      if tbl.typename == "string" then
         tbl = find_var("string") -- simulate string metatable
      end

      if not (tbl.typename == "record" or tbl.typename == "arrayrecord") then
         table.insert(errors, { y = node.y, x = node.x, err = "cannot index something that is not a record: " .. show_type(tbl) })
         return INVALID
      end

      assert(tbl.fields, "record has no fields!? " .. show_type(tbl))

      if key.typename == "string" or key.typename == "unknown" or key.kind == "variable" then -- "unknown" is a plain atom (e.g 'insert' in 'table.insert')
         if tbl.fields[key.tk] then
            return tbl.fields[key.tk]
         end
      end

      table.insert(errors, { y = node.y, x = node.x, err = "invalid key in record type " .. show_type(orig_tbl) .. ": " .. key.tk })
      return INVALID
   end

   local function add_var(var: string, valtype: Type)
      st[#st][var] = valtype
   end

   local function add_global(var: string, valtype: Type)
      st[1][var] = valtype
   end

   local function begin_function_scope(node: Node)
      table.insert(st, {})
      local args = {}
      for _, arg in ipairs(node.args) do
         local t = arg.decltype or { typename = "unknown" }
         table.insert(args, t)
         add_var(arg.tk, t)
      end
      add_var("@return", node.rets or { typename = "tuple" })
      -- HACK for recursive functions
      if node.name then
         add_var(node.name.tk, {
            typename = "function",
            args = args,
            rets = node.rets,
         })
      end
   end

   local function end_function_scope()
      table.remove(st)
   end

   local function flatten_list(list: {Type}): {Type}
      local exps = {}
      for i = 1, #list - 1 do
         table.insert(exps, resolve_unary(list[i]))
      end
      if #list > 0 then
         local last = list[#list]
         if last.typename == "tuple" then
            for _, val in ipairs(last) do
               table.insert(exps, val)
            end
         else
            table.insert(exps, last)
         end
      end
      return exps
   end

   local function get_assignment_values(vals: {Type}): {Type}
      if vals and #vals == 1 and vals[1].typename == "tuple" then
         vals = vals[1] -- FIXME expand last item, not only item
      end
      return vals
   end

   local visit_node: {string:VisitorCallbacks<Node,Type>} = {
      ["statements"] = {
         before = function()
            table.insert(st, {})
         end,
         after = function(node: Node, children: {Type}): Type
            table.remove(st)
            -- TODO extract node type from `return`
            node.type = { typename = "none" }
         end
      },
      ["local_declaration"] = {
         after = function(node: Node, children: {Type}): Type
            local vals: {Type} = get_assignment_values(children[2])
            for i, var in ipairs(node.vars) do
               local decltype = node.decltype and node.decltype[i]
               local infertype = vals and vals[i]
               if decltype and infertype then
                  assert_is_a(node.vars[i], infertype, decltype, {}, "local declaration")
               end
               local t = decltype or infertype or { typename = "unknown" }
               add_var(var.tk, t)
            end
            node.type = { typename = "none" }
         end,
      },
      ["assignment"] = {
         after = function(node: Node, children: {Type}): Type
            local vals: {Type} = get_assignment_values(children[2])
            local exps = flatten_list(vals)
            for i, var in ipairs(children[1]) do
               if var then
                  local val = exps[i] or NIL
                  assert_is_a(node.vars[i], val, var, {}, "assignment")
               else
                  table.insert(errors, { y = node.y, x = node.x, err = "unknown variable" })
               end
            end
            node.type = { typename = "none" }
         end,
      },
      ["if"] = {
         after = function(node: Node, children: {Type}): Type
            node.type = { typename = "none" }
         end,
      },
      ["forin"] = {
         before = function()
            table.insert(st, {})
         end,
         before_statements = function(node: Node)
            local exptype = resolve_tuple(node.exp.type)
            if exptype.typename == "function" then
               add_var(node.vars[1].tk, exptype.rets[1])
               add_var(node.vars[2].tk, exptype.rets[2])
               -- check common errors:
               if node.exp.op.op == "@funcall" then
                  local t = resolve_unary(node.exp.e2.type)
                  if node.exp.e1.tk == "pairs" and not (t.typename == "map" or t.typename == "record") then
                     table.insert(errors, { y = node.y, x = node.x, err = "attempting pairs loop on something that's not a map or record: " .. show_type(node.exp.e2.type) })
                  elseif node.exp.e1.tk == "ipairs" and not (t.typename == "array" or t.typename == "arrayrecord") then
                     table.insert(errors, { y = node.y, x = node.x, err = "attempting ipairs loop on something that's not an array: " .. show_type(node.exp.e2.type) })
                  end
               end
            else
               table.insert(errors, { y = node.y, x = node.x, err = "expression in for loop does not return an iterator" })
            end
         end,
         after = function(node: Node, children: {Type}): Type
            table.remove(st)
            node.type = { typename = "none" }
         end,
      },
      ["fornum"] = {
         before = function(node: Node)
            table.insert(st, {})
            add_var(node.var.tk, NUMBER)
         end,
         after = function(node: Node, children: {Type}): Type
            table.remove(st)
            node.type = { typename = "none" }
         end,
      },
      ["return"] = {
         after = function(node: Node, children: {Type}): Type
            local rets = find_var("@return")
            if #children > #rets then
               table.insert(errors, { y = node.y, x = node.x, err = "excess return values" })
            end
            for i = 1, math.min(#children, #rets) do
               assert_is_a(node.exps[i], children[i], rets[i], nil, "return value")
            end
            node.type = { typename = "none" }
         end,
      },
      ["variables"] = {
         after = function(node: Node, children: {Type}): Type
            node.type = children
            node.type.typename = "tuple"
         end,
      },
      ["table_literal"] = {
         after = function(node: Node, children: {Type}): Type
            node.type = {
               typename = "record",
            }
            for _, child in ipairs(children) do
               if child.typename == "kv" then
                  if not node.type.fields then
                     node.type.fields = {}
                     node.type.field_order = {}
                  end
                  node.type.fields[child.k] = child.v
                  table.insert(node.type.field_order, child.k)
               elseif child.typename == "iv" then
                  if not node.type.items then
                     node.type.items = {}
                  end
                  node.type.items[tonumber(child.i)] = child.v
                  if not node.type.elements then
                     node.type.typename = "arrayrecord"
                     node.type.elements = assert(child.v)
                  else
                     if not is_a(child.v, node.type.elements) then
                        node.type.elements = {
                           typename = "poly",
                           poly = node.type.items,
                        }
                     end
                  end
               end
            end
            if not node.type.fields then
               if node.type.elements then
                  node.type.typename = "array"
               else
                  node.type.fields = {}
                  node.type.field_order = {}
               end
            end
         end,
      },
      ["table_item"] = {
         after = function(node: Node, children: {Type}): Type
            local key = node.key.tk
            if children[1].typename == "number" then
               node.type = { typename = "iv", i = tonumber(key), v = children[2] }
               return
            end
            if node.key.kind == "string" then
               key = key:sub(2, -2)
            end
            node.type = { typename = "kv", k = key, v = children[2] }
         end,
      },
      ["local_function"] = {
         before = function(node: Node)
            begin_function_scope(node)
         end,
         after = function(node: Node, children: {Type}): Type
            end_function_scope()
            add_var(node.name.tk, {
               typename = "function",
               args = children[2],
               rets = children[3],
            })
            node.type = { typename = "none" }
         end,
      },
      ["global_function"] = {
         before = function(node: Node)
            begin_function_scope(node)
         end,
         after = function(node: Node, children: {Type}): Type
            end_function_scope()
            add_global(node.name.tk, {
               typename = "function",
               args = children[2],
               rets = children[3],
            })
            node.type = { typename = "none" }
         end,
      },
      ["module_function"] = {
         before = function(node: Node)
            begin_function_scope(node)
         end,
         after = function(node: Node, children: {Type}): Type
            end_function_scope()
            local var = find_var(node.module.tk)
            if (var.typename == "record" or var.typename == "arrayrecord") then
               var.fields = var.fields or {}
               var.field_order = var.field_order or {}
               var.fields[node.name.tk] = {
                  typename = "function",
                  args = children[3],
                  rets = children[4],
               }
               table.insert(var.field_order, node.name.tk)
            else
               table.insert(errors, { y = node.y, x = node.x, err = "not a module: " .. node.module.tk })
            end
            node.type = { typename = "none" }
         end,
      },
      ["record_method"] = {
         before = function(node: Node)
            begin_function_scope(node)
         end,
         before_statements = function(node: Node, children: {Type})
            local rtype = assert(find_var(node.record_name.tk))
            children[3][1] = rtype
            add_var("self", rtype)
         end,
         after = function(node: Node, children: {Type}): Type
            end_function_scope()
            local rtype = find_var(node.record_name.tk)
            if (rtype.typename == "record" or rtype.typename == "arrayrecord") then
               rtype.fields = rtype.fields or {}
               rtype.field_order = rtype.field_order or {}
               rtype.fields[node.name.tk] = {
                  typename = "function",
                  is_method = true,
                  args = children[3],
                  rets = children[4],
               }
               table.insert(rtype.field_order, node.name.tk)
            else
               table.insert(errors, { y = node.y, x = node.x, err = "not a record: " .. node.module.tk })
            end
            node.type = { typename = "none" }
         end,
      },
      ["function"] = {
         before = function(node: Node)
            begin_function_scope(node)
         end,
         after = function(node: Node, children: {Type}): Type
            end_function_scope()
            -- children[1] args
            -- children[2] body
            node.type = {
               typename = "function",
               args = children[1],
               rets = children[2],
            }
         end,
      },
      ["cast"] = {
         after = function(node: Node, children: {Type}): Type
            node.type = node.casttype
         end
      },
      ["op"] = {
         after = function(node: Node, children: {Type}): Type
            local a: Type = children[1]
            local b: Type = children[3]
            local orig_a = a
            local orig_b = b
            if node.op.op == "@funcall" then
               if node.e1.op and node.e1.op.op == ":" then
                  local func = node.e1.type
                  if func.typename == "function" or func.typename == "poly" then
                     table.insert(b, 1, node.e1.e1.type)
                     node.type = match_func_args(node, func, b, true)
                  else
                     node.type = INVALID
                  end
               else
                  node.type = match_func_args(node, a, b, false)
               end
            elseif node.op.op == "@index" then
               a = resolve_unary(a)
               b = resolve_unary(b)
               if a.typename == "array" or a.typename == "arrayrecord" and is_a(b, NUMBER) then
                  node.type = a.elements
               elseif a.typename == "map" then
                  if is_a(b, a.keys) then
                     node.type = a.values
                  else
                     table.insert(errors, { y = node.y, x = node.x, err = "wrong index type: " .. show_type(b) .. ", expected " .. show_type(a.keys) })
                     node.type = INVALID
                  end
               elseif node.e2.kind == "string" then
                  node.type = match_record_key(node, a, { typename = "string", tk = node.e2.tk:sub(2, -2) }, orig_a)
               elseif a.typename == "record" or a.typename == "arrayrecord" and is_a(b, STRING) then
                  local ff: Type
                  local typevars: {string: Type} = {}
                  for _ k in ipairs(a.field_order) do
                     local f = a.fields[k]
                     if not ff then
                        ff = f
                     else
                        local match, why_not = same_type(f, ff, typevars)
                        if not match then
                           ff = nil
                           break
                        end
                     end
                  end
                  if ff then
                     node.type = ff
                  else
                     table.insert(errors, { y = node.y, x = node.x, err = "cannot index, not all fields in record have the same type" })
                     node.type = INVALID
                  end
               else
                  table.insert(errors, { y = node.y, x = node.x, err = "cannot index object of type " .. show_type(orig_a) .. " with " .. show_type(orig_b) })
                  node.type = INVALID
               end
            elseif node.op.op == "." then
               a = resolve_unary(a, {}) -- FIXME propagate typevars?
               if a.typename == "map" then
                  if is_a(STRING, a.keys) then
                     node.type = a.values
                  else
                     table.insert(errors, { y = node.y, x = node.x, err = "cannot use . index, expects keys of type " .. show_type(a.keys) })
                     node.type = INVALID
                  end
               else
                  node.type = match_record_key(node, a, { typename = "string", tk = node.e2.tk }, orig_a)
               end
            elseif node.op.op == ":" then
               node.type = match_record_key(node, node.e1.type, node.e2, orig_a)
            elseif node.op.op == "and" then
               node.type = b
            elseif node.op.op == "or" and is_empty_table(b) then
               node.type = a
            elseif node.op.op == "or" and same_type(a, b) then
               node.type = a
            elseif node.op.op == "or" and b.typename == "nil" then
               node.type = a
            elseif node.op.op == "or" and a.typename == "nominal" and b.typename == "nominal" and a.name == b.name then
               node.type = a
            elseif node.op.op == "or" and a.typename == "nominal" and (b.typename == "record" or b.typename == "arrayrecord") and is_a(b, a) then
               node.type = a
            elseif node.op.op == "==" or node.op.op == "~=" then
               if is_a(a, b, {}, true) or is_a(b, a, {}, true) then
                  node.type = BOOLEAN
               else
                  table.insert(errors, { y = node.y, x = node.x, err = "types are not comparable for equality: " .. show_type(a) .. " " .. show_type(b) })
                  node.type = INVALID
               end
            elseif node.op.arity == 1 and unop_types[node.op.op] then
               a = resolve_unary(a)
               local types_op = unop_types[node.op.op]
               node.type = types_op[a.typename]
               if not node.type then
                  table.insert(errors, { y = node.y, x = node.x, err = "unop mismatch: " .. node.op.op .. " " .. a.typename })
                  node.type = INVALID
               end
            elseif node.op.arity == 2 and binop_types[node.op.op] then
               a = resolve_unary(a)
               b = resolve_unary(b)
               local types_op = binop_types[node.op.op]
               node.type = types_op[a.typename] and types_op[a.typename][b.typename]
               if not node.type then
                  table.insert(errors, { y = node.y, x = node.x, err = "binop mismatch for " .. node.op.op .. ": " .. show_type(orig_a) .. " " .. show_type(orig_b) })
                  node.type = INVALID
               end
            else
               error("unknown node op " .. node.op.op)
            end
         end,
      },
      ["variable"] = {
         after = function(node: Node, children: {Type}): Type
            node.type = find_var(node.tk)
         end,
      },
      ["newtype"] = {
         after = function(node: Node, children: {Type}): Type
            node.type = node.newtype
         end,
      }
   }

   visit_node["while"] = visit_node["if"]
   visit_node["repeat"] = visit_node["if"]
   visit_node["do"] = visit_node["if"]
   visit_node["break"] = visit_node["if"]
   visit_node["elseif"] = visit_node["if"]
   visit_node["else"] = visit_node["if"]

   visit_node["values"] = visit_node["variables"]
   visit_node["expression_list"] = visit_node["variables"]
   visit_node["argument_list"] = visit_node["variables"]

   visit_node["word"] = visit_node["variable"]

   visit_node["string"] = {
      after = function(node: Node, children: {Type}): Type
         node.type = {
            typename = node.kind,
            tk = node.tk,
         }
         return node.type
      end,
   }
   visit_node["number"] = visit_node["string"]
   visit_node["nil"] = visit_node["string"]
   visit_node["boolean"] = visit_node["string"]
   visit_node["array"] = visit_node["string"]
   visit_node["..."] = visit_node["string"]

   visit_node["@after"] = {
      after = function(node: Node, children: {Type}): Type
         assert(type(node.type) == "table", node.kind .. " did not produce a type")
         assert(type(node.type.typename) == "string", node.kind .. " type does not have a typename")
         return node.type
      end
   }

   local visit_type: {string:VisitorCallbacks<Type,Type>} = {
      ["typedecl"] = {
         after = function(typ: Type, children: {Type}): Type
            return typ
         end,
      },
      ["type_list"] = {
         after = function(typ: Type, children: {Type}): Type
            local ret: Type = children
            ret.typename = "tuple"
            return ret
         end,
      },
      ["@after"] = {
         after = function(typ: Type, children: {Type}, ret: Type): Type
            assert(type(ret) == "table", typ.kind .. " did not produce a type")
            assert(type(ret.typename) == "string", typ.kind .. " type does not have a typename")
            return ret
         end
      },
   }

   recurse_node(ast, visit_node, visit_type)

   return errors
end

return tl

