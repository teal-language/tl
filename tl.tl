local tl = {}

--------------------------------------------------------------------------------
-- Lexer
--------------------------------------------------------------------------------

local inspect: function(any):string = require "inspect"

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
   fields: {string: Type}

   -- array
   elements: Type

   -- function
   args: {Type}
   rets: {Type}
   vararg: boolean

   -- nominal
   name: string
   
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
   method: Node

   typename: string
   type: Type
   decltype: Type
end

local parse_expression: function({Token}, number, {ParseError}): number, Node, number
local parse_statements: function({Token}, number, {ParseError}): number, Node
local parse_argument_list: function

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

local ParseItem = functiontype({Token}, number, {ParseError}, number): number, Node, number

local function parse_list(tokens: {Token}, i: number, errs: {ParseError}, node: Node, close: {string:boolean}, is_sep: boolean, parse_item: ParseItem): number, Node
   local n = 1
   while tokens[i].kind ~= "$EOF$" do
      if close[tokens[i].tk] then
         break
      end
      local item: Node
      i, item, n = parse_item(tokens, i, errs, n)
      table.insert(node, item)
      if tokens[i].tk == "," then
         i = i + 1
         if is_sep and close[tokens[i].tk] then
            return fail(tokens, i, errs)
         end
      end
   end
   return i, node
end

local function parse_bracket_list(tokens: {Token}, i: number, errs: {ParseError}, node_kind: string, open: string, close: string, is_sep: boolean, parse_item: ParseItem): number, Node
   local node = new_node(tokens, i, node_kind)
   i = verify_tk(tokens, i, errs, open)
   i = parse_list(tokens, i, errs, node, { [close] = true }, is_sep, parse_item)
   i = i + 1
   return i, node
end

local function parse_table_literal(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   return parse_bracket_list(tokens, i, errs, "table_literal", "{", "}", false, parse_table_item)
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
      node.vararg = true
   end
   return i, node
end

local function parse_type(tokens: {Token}, i: number, errs: {ParseError}): number, Type
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
      i = i + 1
      i = verify_kind(tokens, i, errs, "word")
      return i, {
         kind = "typedecl",
         typename = "typevar",
         typevar = "`" .. tokens[i-1].tk,
      }
   elseif tokens[i].kind == "word" then
      return i + 1, {
         kind = "typedecl",
         typename = "nominal",
         name = tokens[i].tk,
      }
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
         ["@methcall"] = 100,
         ["@index"] = 200,
         ["."] = 200,
         [":"] = 200,
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

   local function pop_operator(operators: {Operator}, operands: {Node}): boolean
      if operators[#operators].arity == 2 then
         local t2: Node = table.remove(operands)
         local t1: Node = table.remove(operands)
         if not t1 or not t2 then
            return false
         end
         local operator: Operator = table.remove(operators)
         if operator.op == "@funcall" and (t1.op and t1.op.op == ":") then
            operator.op = "@methcall"
            table.insert(operands, { y = t1.y, x = t1.x, kind = "op", op = operator, e1 = t1.e1, method = t1.e2, e2 = t2 })
         else
            table.insert(operands, { y = t1.y, x = t1.x, kind = "op", op = operator, e1 = t1, e2 = t2 })
         end
      else
         local t1: Node = table.remove(operands)
         table.insert(operands, { y = t1.y, x = t1.x, kind = "op", op = table.remove(operators), e1 = t1 })
      end
      return true
   end

   local function push_operator(op: Operator, operators: {Operator}, operands: {Node}): boolean
      while prec(operators[#operators]) >= prec(op) do
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
      i, args = parse_bracket_list(tokens, i, errs, "expression_list", "(", ")", true, parse_expression)
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
   return parse_bracket_list(tokens, i, errs, "argument_list", "(", ")", true, parse_argument)
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
   end
   i, node.args = parse_argument_list(tokens, i, errs)
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
      i = i + 1
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
         end
      end
      i = verify_tk(tokens, i, errs, "end")
      return i, node
   elseif tokens[i].tk == "functiontype" then
      i, node.newtype.def = parse_function_type(tokens, i, errs)
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
   if lhs.op and (lhs.op.op == "@funcall" or lhs.op.op == "@methcall") then
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
   local last = tokens[#tokens]
   table.insert(tokens, { y = last.y, x = last.x + #last.tk, tk = "$EOF$", kind = "$EOF$" })
   return parse_statements(tokens, 1, errs)
end

--------------------------------------------------------------------------------
-- AST traversal
--------------------------------------------------------------------------------

local VisitorCallbacks = record
   before: function(Node, {`T})
   before_statements: function({Node})
   after: function(Node, {`T}): `T
end

local function recurse_ast(ast: Node, visitor: {string:VisitorCallbacks}): table
   assert(visitor[ast.kind], "no visitor for " .. ast.kind)
   if visitor["@before"] and visitor["@before"].before then
      visitor["@before"].before(ast)
   end
   if visitor[ast.kind].before then
      visitor[ast.kind].before(ast)
   end
   if visitor["@before"] and visitor["@before"].after then
      visitor["@before"].after(ast)
   end
   local xs: {table} = {}
   if ast.kind == "statements"
      or ast.kind == "variables"
      or ast.kind == "values"
      or ast.kind == "argument_list"
      or ast.kind == "expression_list"
      or ast.kind == "type_list"
      or ast.kind == "table_literal" then
      for i, child in ipairs(ast) do
         xs[i] = recurse_ast(child, visitor)
      end
   elseif ast.kind == "local_declaration"
          or ast.kind == "assignment" then
      xs[1] = recurse_ast(ast.vars, visitor)
      if ast.exps then
         xs[2] = recurse_ast(ast.exps, visitor)
      end
   elseif ast.kind == "table_item" then
      table.insert(xs, recurse_ast(ast.key, visitor) or false)
      table.insert(xs, recurse_ast(ast.value, visitor) or false)
   elseif ast.kind == "if" then
      table.insert(xs, recurse_ast(ast.exp, visitor))
      table.insert(xs, recurse_ast(ast.thenpart, visitor))
      for i, e in ipairs(ast.elseifs) do
         table.insert(xs, recurse_ast(e, visitor))
      end
      if ast.elsepart then
         table.insert(xs, recurse_ast(ast.elsepart, visitor))
      end
   elseif ast.kind == "while" then
      table.insert(xs, recurse_ast(ast.exp, visitor) or false)
      table.insert(xs, recurse_ast(ast.body, visitor) or false)
   elseif ast.kind == "repeat" then
      table.insert(xs, recurse_ast(ast.body, visitor) or false)
      table.insert(xs, recurse_ast(ast.exp, visitor) or false)
   elseif ast.kind == "function" then
      table.insert(xs, recurse_ast(ast.args, visitor) or false)
      table.insert(xs, recurse_ast(ast.rets, visitor) or false)
      table.insert(xs, recurse_ast(ast.body, visitor) or false)
   elseif ast.kind == "forin" then
      table.insert(xs, recurse_ast(ast.vars, visitor) or false)
      table.insert(xs, recurse_ast(ast.exp, visitor) or false)
      if visitor["forin"].before_statements then
         visitor["forin"].before_statements(ast)
      end
      table.insert(xs, recurse_ast(ast.body, visitor) or false)
   elseif ast.kind == "fornum" then
      table.insert(xs, recurse_ast(ast.var, visitor) or false)
      table.insert(xs, recurse_ast(ast.from, visitor) or false)
      table.insert(xs, recurse_ast(ast.to, visitor) or false)
      table.insert(xs, ast.step and recurse_ast(ast.step, visitor) or false)
      table.insert(xs, recurse_ast(ast.body, visitor) or false)
   elseif ast.kind == "elseif" then
      table.insert(xs, recurse_ast(ast.exp, visitor) or false)
      table.insert(xs, recurse_ast(ast.thenpart, visitor) or false)
   elseif ast.kind == "else" then
      table.insert(xs, recurse_ast(ast.elsepart, visitor) or false)
   elseif ast.kind == "return" then
      table.insert(xs, recurse_ast(ast.exps, visitor) or false)
   elseif ast.kind == "do" then
      table.insert(xs, recurse_ast(ast.body, visitor) or false)
   elseif ast.kind == "local_function"
          or ast.kind == "global_function" then
      table.insert(xs, recurse_ast(ast.name, visitor) or false)
      table.insert(xs, recurse_ast(ast.args, visitor) or false)
      table.insert(xs, recurse_ast(ast.rets, visitor) or false)
      table.insert(xs, recurse_ast(ast.body, visitor) or false)
   elseif ast.kind == "module_function" then
      table.insert(xs, recurse_ast(ast.module, visitor) or false)
      table.insert(xs, recurse_ast(ast.name, visitor) or false)
      table.insert(xs, recurse_ast(ast.args, visitor) or false)
      table.insert(xs, recurse_ast(ast.rets, visitor) or false)
      table.insert(xs, recurse_ast(ast.body, visitor) or false)
   elseif ast.kind == "op" then
      table.insert(xs, recurse_ast(ast.e1, visitor) or false)
      local p1 = ast.e1.op and ast.e1.op.prec or false
      if ast.op.op == "@methcall" and ast.e1.kind == "string" then
         p1 = -999
      end
      table.insert(xs, p1)
      if ast.op.arity == 2 then
         table.insert(xs, recurse_ast(ast.e2, visitor) or false)
         table.insert(xs, ast.e2.op and ast.e2.op.prec or false)
      end
   elseif ast.kind == "newtype" then
      table.insert(xs, recurse_ast(ast.newtype, visitor) or false)
   elseif ast.kind == "variable"
          or ast.kind == "word"
          or ast.kind == "string"
          or ast.kind == "number"
          or ast.kind == "break"
          or ast.kind == "nil"
          or ast.kind == "..."
          or ast.kind == "typedecl"
          or ast.kind == "boolean" then
   else
      if not ast.kind then
         error("wat: " .. inspect(ast))
      end
      error("unknown node kind " .. ast.kind)
   end
   if visitor["@after"] and visitor["@after"].before then
      visitor["@after"].before(ast, xs)
   end
   local ret: table
   if visitor[ast.kind].after then
      ret = visitor[ast.kind].after(ast, xs)
   end
   if visitor["@after"] and visitor["@after"].after then
      ret = visitor["@after"].after(ast, xs)
   end
   --print(">>>", ast.kind, ">>>", inspect(ret))
   return ret
end

--------------------------------------------------------------------------------
-- Pretty-print AST
--------------------------------------------------------------------------------

local tight_op: {string:boolean} = {
   ["."] = true,
   ["-"] = true,
   ["~"] = true,
   ["#"] = true,
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

function tl.pretty_print_ast(ast: Node)
   local indent = 0

   local visit: {string:VisitorCallbacks} = {
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
            elseif node.op.op == "@methcall" then
               if children[2] and node.op.prec > tonumber(children[2]) then
                  table.insert(out, "(")
               end
               table.insert(out, children[1])
               if children[2] and node.op.prec > tonumber(children[2]) then
                  table.insert(out, ")")
               end
               table.insert(out, ":")
               table.insert(out, node.method.tk)
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
      ["type_list"] = {
         after = function(node: Node, children: {string}): string
            return ""
         end,
      },
      ["newtype"] = {
         after = function(node: Node, children: {string}): string
            return "{}"
         end,
      },
   }

   visit["values"] = visit["variables"]
   visit["expression_list"] = visit["variables"]
   visit["argument_list"] = visit["variables"]

   visit["word"] = visit["variable"]
   visit["string"] = visit["variable"]
   visit["number"] = visit["variable"]
   visit["nil"] = visit["variable"]
   visit["boolean"] = visit["variable"]
   visit["..."] = visit["variable"]

   visit["typedecl"] = visit["type_list"]

   return recurse_ast(ast, visit)
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
      return t.name
   elseif t.typename == "tuple" and #t == 1 then
      return show_type(t[1])
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

function tl.type_check(ast: Node)
   local st: {{string:Type}} = {
      {
         ["any"] = { typename = "typetype", def = ANY },
         ["require"] = { typename = "function", args = { STRING }, rets = {} },
         ["next"] = {
            typename = "poly",
            poly = {
               { typename = "function", args = { MAP_OF_ALPHA_TO_BETA }, rets = { ALPHA, BETA } },
               { typename = "function", args = { ARRAY_OF_ALPHA }, rets = { NUMBER, ALPHA } },
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
            },
         },
         ["string"] = {
            typename = "record",
            fields = {
               ["sub"] = { typename = "function", args = { STRING, NUMBER, NUMBER }, rets = { STRING } },
               ["match"] = { typename = "function", args = { STRING, STRING }, rets = { STRING } },
               ["rep"] = { typename = "function", args = { STRING, NUMBER }, rets = { STRING } },
            },
         },
         ["math"] = {
            typename = "record",
            fields = {
               ["min"] = { typename = "function", args = { NUMBER, NUMBER }, rets = { NUMBER } },
            },
         },
         ["type"] = { typename = "function", args = { ANY }, rets = { STRING } },
         ["ipairs"] = { typename = "function", args = { ARRAY_OF_ANY }, rets = {} }, -- [magic]
         ["pairs"] = { typename = "function", args = { { typename = "map", keys = ALPHA, values = BETA } }, rets = {} }, -- [magic]
         ["assert"] = {
            typename = "poly",
            poly = {
               { typename = "function", args = { BOOLEAN }, rets = {} },
               { typename = "function", args = { BOOLEAN, STRING }, rets = {} },
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

   local function resolve_unary(t: Type): Type
      t = resolve_tuple(t)
      if t.typename == "nominal" then
         local typetype = find_var(t.name)
         if typetype.typename == "typetype" then
            return typetype.def
         else
            return { typename = "bad_nominal", name = t.name }
         end
      end
      return t
   end
   
   local function same_type(t1: Type, t2: Type, typevars: {string:Type}): boolean
      assert(type(t1) == "table")
      assert(type(t2) == "table")

      if t1.typename == "typevar" then
         if not typevars[t1.typevar] then
            return false
         else
            return same_type(typevars[t1.typevar], t2, typevars)
         end
      end
      if t2.typename == "typevar" then
         if not typevars[t2.typevar] then
            return false
         else
            return same_type(t1, typevars[t2.typevar], typevars)
         end
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

   local is_a: function(Type, Type, {string:Type}): boolean, string

   local function match_record_fields(t1: Type, t2: Type, typevars: {string:Type}): boolean, string
      for k, f in pairs(t1.fields) do
         if t2.fields[k] == nil then
            return false, "unknown field " .. k
         end
         local match, why_not = is_a(f, t2.fields[k], typevars)
         if not match then
            return false, "mismatch in field " .. k .. (why_not and ": " .. why_not or "")
         end
      end
      return true
   end

   is_a = function(t1: Type, t2: Type, typevars: {string:Type}): boolean, string
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
      
      if t1.typename == "typevar" then
         if not typevars[t1.typevar] then
            typevars[t1.typevar] = t1
            return true
         else
            return is_a(typevars[t1.typevar], t2, typevars)
         end
      end
      
      if t2.typename == "typevar" then
         if not typevars[t2.typevar] then
            typevars[t2.typevar] = t1
            return true
         else
            return is_a(t1, typevars[t2.typevar], typevars)
         end
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
         return t1.name == t2.name
      elseif t1.typename == "nominal" or t2.typename == "nominal" then
         t1 = resolve_unary(t1)
         t2 = resolve_unary(t2)
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
            return match_record_fields(t1, t2, typevars)
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
            return match_record_fields(t1, t2, typevars)
         elseif t1.typename == "arrayrecord" then
            if not is_a(t1.elements, t2.elements, typevars) then
               return false
            end
            return match_record_fields(t1, t2, typevars)
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
            for k, f in pairs(t1.fields) do
               local match, why_not = is_a(f, t2.values, typevars)
               if not match then
                  return false, "mismatch in field " .. k .. (why_not and ": " .. why_not or "")
               end
            end
            return true
         end
         return false
      elseif t1.typename == "function" and t2.typename == "function" then
         if (not t2.vararg) and #t1.args > #t2.args then
            return false, "failed on number of arguments"
         end
         if #t1.rets < #t2.rets then
            return false, "failed on number of returns"
         end
         for i = 1, #t1.args do
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
      elseif t2.typename == "boolean" then -- all values can be used in a boolean context
         return true
      elseif t1.typename ~= t2.typename then
         return false
      end
      return true
   end
   
   local function resolve_typevars(t: Type, typevars: {string:Type}, has_cycle: {Type:boolean}): Type
      has_cycle = has_cycle or {}
      if has_cycle[t] then
         error("HAS CYCLE IN TYPE " .. inspect(t))
      end
      has_cycle[t] = true
      if t.typename == "typevar" then
         if not typevars[t.typevar] then
            return INVALID -- this is ok if we don't use it, e.g. discarding a return
         end
         return typevars[t.typevar]
      end
      local copy: Type = {}
      for k,v in pairs(t) do
         if type(v) == "table" and k ~= "type" then
            copy[k] = resolve_typevars(v, typevars, has_cycle)
         else
            copy[k] = v
         end
      end
      return copy
   end
   
   local function assert_is_a(node: Node, t1: Type, t2: Type, context: string)
      local match, why_not = is_a(t1, t2, {})
      if not match then
         table.insert(errors, { y = node.y, x = node.x, err = context .. " mismatch: " .. (node.tk or node.op.op) .. ": " .. show_type(t1) .. " is not a " .. show_type(t2) .. (why_not and ": " .. why_not or "") })
      end
   end
   
   local function try_match_func_args(node: Node, f: Type, args: {Type}, polyerrs: {{Error}}, p: number, is_method: boolean): Type
      local ok = true
      local typevars = {}
      for a = 1, math.min(#args, #f.args) do
         local arg = args[a]
         local matches, why_not = is_a(arg, f.args[a], typevars)
         if not matches then
            polyerrs[p] = polyerrs[p] or {}
            local at = node.e2 and node.e2[a] or node
            table.insert(polyerrs[p], { y = at.y, x = at.x, err = "error in argument " .. (is_method and a-1 or a) .. ": " .. show_type(arg) .. " is not a " .. show_type(f.args[a]) .. (why_not and ": " .. why_not or "") })
            ok = false
            break
         end
      end
      if ok == true then
         f.rets.typename = "tuple"
         return resolve_typevars(f.rets, typevars)
      end
      return nil
   end
   
   local function match_func_args(node: Node, func: Type, args: {Type}, is_method: boolean): Type
      assert(type(func) == "table")
      assert(type(args) == "table")
      
      func = resolve_unary(func)

      args = args or {}
      local poly: Type = func.typename == "poly" and func or { poly = { func } }
      local polyerrs: {{Error}} = {}
      local expects: {string} = {}
      -- try exact match first
      for p, f in ipairs(poly.poly) do
         if f.typename ~= "function" then
            table.insert(errors, { y = node.y, x = node.x, err = "not a function: " .. show_type(f) })
            return INVALID
         end
         table.insert(expects, tostring(#f.args or 0))
         if #args == (#f.args or 0) then
            local matched = try_match_func_args(node, f, args, polyerrs, p, is_method)
            if matched then
               return matched
            end
         end
      end
      -- [nil-lenient] now try passing nils to missing arguments
      for p, f in ipairs(poly.poly) do
         if #args < (#f.args or 0) then
            local matched = try_match_func_args(node, f, args, polyerrs, p, is_method)
            if matched then
               return matched
            end
         end
      end
      -- now try vararg functions
      for p, f in ipairs(poly.poly) do
         if f.vararg and #args > (#f.args or 0) then
            local matched = try_match_func_args(node, f, args, polyerrs, p, is_method)
            if matched then
               return matched
            end
         end
      end
      
      if not next(polyerrs) then
         table.insert(errors, { y = node.y, x = node.x, err = "wrong number of arguments (given " .. #args .. ", expects " .. table.concat(expects, " or ") .. ") => " .. debug.traceback() })
      else
         for _, err in ipairs(polyerrs[next(polyerrs)]) do
            table.insert(errors, err)
         end
      end
      
      poly.poly[1].rets.typename = "tuple"
      return poly.poly[1].rets
   end

   local function match_record_key(node: Node, tbl: Type, key: Node, orig_tbl: Type): Type
      assert(type(tbl) == "table")
      assert(type(key) == "table")

      if not (tbl.typename == "record" or tbl.typename == "arrayrecord") then
         table.insert(errors, { y = node.y, x = node.x, err = "not a record: " .. show_type(tbl) })
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

   local function extract_type_fields(node: Node, fields: {string:Type}): {string:Type}
      local ret: {string:Type} = {}
      for k, v in pairs(fields) do
         if v.typename == "typetype" then
            ret[k] = v.def
         else
            table.insert(errors, { y = node.y, x = node.x, err = "expected type declaration in record: " .. k .. "; got " .. show_type(v) })
            ret[k] = INVALID
         end
      end
      return ret
   end

   local function extract_type_list(node: Node, types: {Type}, name: string): {string:Type}
      local ret: {Type} = {}
      for i, t in ipairs(types) do
         if t.typename == "typetype" then
            ret[i] = t.def
         else
            table.insert(errors, { y = node.y, x = node.x, err = "expected type declaration in list: " .. i .. "; got " .. show_type(t) })
            ret[i] = INVALID
         end
      end
      return ret
   end

   local function get_assignment_values(vals: {Type}): {Type}
      if vals and #vals == 1 and vals[1].typename == "tuple" then
         vals = vals[1] -- FIXME expand last item, not only item
      end
      return vals
   end

   local visit: {string:VisitorCallbacks} = {
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
                  assert_is_a(node.vars[i], infertype, decltype, "local declaration")
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
                  assert_is_a(node.vars[i], val, var, "assignment")
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
            if node.exp.kind == "op" and node.exp.op.op == "@funcall" and node.exp.e1.tk == "ipairs" then -- [magic] ipairs
               local t = resolve_unary(node.exp.e2.type)
               if (t.typename == "array" or t.typename == "arrayrecord") then
                  add_var(node.vars[1].tk, NUMBER)
                  add_var(node.vars[2].tk, t.elements)
               else
                  table.insert(errors, { y = node.y, x = node.x, err = "attempting ipairs loop on something that's not an array: " .. show_type(node.exp.e2.type) })
               end
            elseif node.exp.kind == "op" and node.exp.op.op == "@funcall" and node.exp.e1.tk == "pairs" then -- [magic] pairs
               local t = resolve_unary(node.exp.e2.type)
               if (t.typename == "map") then
                  add_var(node.vars[1].tk, t.keys)
                  add_var(node.vars[2].tk, t.values)
               elseif (t.typename == "record") then
                  add_var(node.vars[1].tk, STRING)
               elseif (t.typename == "arrayrecord") then
                  add_var(node.vars[1].tk, {
                     typename = "poly",
                     poly = {
                        NUMBER,
                        STRING,
                     }
                  })
                  local poly: {Type} = {}
                  table.insert(poly, t.elements)
                  for f, t in pairs(t.fields) do
                     table.insert(poly, t)
                  end
                  add_var(node.vars[2].tk, {
                     typename = "poly",
                     poly = poly,
                  })
               else
                  table.insert(errors, { y = node.y, x = node.x, err = "attempting pairs loop on something that's not a map or record: " .. show_type(node.exp.e2.type) })
               end
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
            -- TODO check that type matches ret type of curr function
            node.type = children[1]
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
                  end
                  node.type.fields[child.k] = child.v
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
               var.fields[node.name.tk] = {
                  typename = "function",
                  args = children[3],
                  rets = children[4],
               }
            else
               table.insert(errors, { y = node.y, x = node.x, err = "not a module: " .. node.module.tk })
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
      ["op"] = {
         after = function(node: Node, children: {Type}): Type
            local a: Type = children[1]
            local b: Type = children[3]
            local orig_a = a
            local orig_b = b
            if node.op.op == "@funcall" then
               node.type = match_func_args(node, a, b, false)
            elseif node.op.op == "@methcall" then
               local obj = a
               if obj.typename == "string" then
                  obj = find_var("string") -- simulate string metatable
               end
               local func = match_record_key(node, obj, node.method, orig_a)
               if func.typename == "function" then
                  table.insert(b, 1, a)
                  node.type = match_func_args(node, func, b, true)
               else
                  table.insert(errors, { y = node.y, x = node.x, err = "method not found: " .. show_type(node) })
                  node.type = INVALID
               end
            elseif node.op.op == "@index" then
               a = resolve_unary(a)
               b = resolve_unary(b)
               if a.typename == "array" or a.typename == "arrayrecord" then
                  if is_a(b, NUMBER) then
                     node.type = a.elements
                  else
                     -- TODO what if we []-index an arrayrecord to get at the fields?
                     table.insert(errors, { y = node.y, x = node.x, err = "wrong index type: " .. show_type(b) .. ", expected number" })
                     node.type = INVALID
                  end
               elseif a.typename == "map" then
                  if is_a(b, a.keys) then
                     node.type = a.values
                  else
                     table.insert(errors, { y = node.y, x = node.x, err = "wrong index type: " .. show_type(b) .. ", expected " .. show_type(a.keys) })
                     node.type = INVALID
                  end
               else
                  node.type = INVALID
               end
            elseif node.op.op == "." then
               a = resolve_unary(a)
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
            elseif node.op.op == "and" then
               node.type = b
            elseif node.op.op == "or" and is_empty_table(b) then
               node.type = a
            elseif node.op.op == "or" and a.typename == "nominal" and b.typename == "nominal" and a.name == b.name then
               node.type = a
            elseif node.op.op == "or" and a.typename == "nominal" and (b.typename == "record" or b.typename == "arrayrecord") and is_a(b, a) then
               node.type = a
            elseif node.op.op == "==" or node.op.op == "~=" then
               if is_a(a, b, {}) or is_a(b, a, {}) then
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
      ["typedecl"] = {
         after = function(node: Node, children: {Type}): Type
            node.type = node
         end,
      },
      ["newtype"] = {
         after = function(node: Node, children: {Type}): Type
            node.type = node.newtype
         end,
      }
   }

   visit["while"] = visit["if"]
   visit["repeat"] = visit["if"]
   visit["do"] = visit["if"]
   visit["break"] = visit["if"]
   visit["elseif"] = visit["if"]
   visit["else"] = visit["if"]

   visit["values"] = visit["variables"]
   visit["expression_list"] = visit["variables"]
   visit["argument_list"] = visit["variables"]
   visit["type_list"] = visit["variables"]

   visit["word"] = visit["variable"]

   visit["string"] = {
      after = function(node: Node, children: {Type}): Type
         node.type = {
            typename = node.kind,
            tk = node.tk,
         }
         return node.type
      end,
   }
   visit["number"] = visit["string"]
   visit["nil"] = visit["string"]
   visit["boolean"] = visit["string"]
   visit["array"] = visit["string"]
   visit["..."] = visit["string"]

   visit["@after"] = {
      after = function(node: Node, children: {Type}): Type
         assert(type(node.type) == "table", node.kind .. " did not produce a type")
         assert(type(node.type.typename) == "string", node.kind .. " type does not have a typename")
         return node.type
      end
   }

   recurse_ast(ast, visit)
   
   return errors
end

return tl
