local Env = record
   globals: {string:Variable}
   modules: {string:Type}
   skip_compat53: boolean
end

local TypeCheckOptions = record
   lax: boolean
   filename: string
   skip_compat53: boolean
   env: Env
   result: Result
end

local tl = {
   process: function(string, Env, Result, {string}): (Result, string) = nil,
   type_check: function(Node, TypeCheckOptions): ({Error}, {Error}, Type) = nil,
   init_env: function(boolean, boolean): Env = nil,
}

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

--   ["global"] = true,
}

local TokenKind = enum
   "keyword"
   "op"
   "string"
   "[" "]" "(" ")" "{" "}" "," ":" "#" "`" "." ";"
   "::"
   "..."
   "identifier"
   "number"
   "$invalid$"
   "$EOF$"
end

local Token = record
   x: number
   y: number
   i: number
   tk: string
   kind: TokenKind
end

local lex_word_start: {string:boolean} = {}
for c = string.byte("a"), string.byte("z") do
   lex_word_start[string.char(c)] = true
end
for c = string.byte("A"), string.byte("Z") do
   lex_word_start[string.char(c)] = true
end
lex_word_start["_"] = true

local lex_word: {string:boolean} = {}
for c = string.byte("a"), string.byte("z") do
   lex_word[string.char(c)] = true
end
for c = string.byte("A"), string.byte("Z") do
   lex_word[string.char(c)] = true
end
for c = string.byte("0"), string.byte("9") do
   lex_word[string.char(c)] = true
end
lex_word["_"] = true

local lex_decimal_start: {string:boolean} = {}
for c = string.byte("1"), string.byte("9") do
   lex_decimal_start[string.char(c)] = true
end

local lex_decimals: {string:boolean} = {}
for c = string.byte("0"), string.byte("9") do
   lex_decimals[string.char(c)] = true
end

local lex_hexadecimals: {string:boolean} = {}
for c = string.byte("0"), string.byte("9") do
   lex_hexadecimals[string.char(c)] = true
end
for c = string.byte("a"), string.byte("f") do
   lex_hexadecimals[string.char(c)] = true
end
for c = string.byte("A"), string.byte("F") do
   lex_hexadecimals[string.char(c)] = true
end

local lex_char_symbols: {string:boolean} = {}
for _, c in ipairs({"[", "]", "(", ")", "{", "}", ",", "#", "`", ";"}) do
   lex_char_symbols[c] = true
end

local lex_op_start: {string:boolean} = {}
for _, c in ipairs({"+", "*", "/", "|", "&", "%", "^"}) do
   lex_op_start[c] = true
end

local lex_space: {string:boolean} = {}
for _, c in ipairs({" ", "\t", "\v", "\n", "\r"}) do
   lex_space[c] = true
end

local LexState = enum
   "start"
   "any"
   "identifier"
   "maybecomment"
   "maybecomment2"
   "maybedotdot"
   "maybedotdotdot"
   "decimal_number"
   "decimal_or_hex"
   "decimal_float"
   "power"
   "power_sign"
   "hex_number"
   "hex_float"
   "lt"
   "gt"
   "colon"
   "maybeequals"
   "maybelongstring"
   "dblquote_string"
   "singlequote_string"
   "escape_dblquote_string"
   "escape_singlequote_string"
   "comment"
   "longcomment"
   "maybelongcomment"
   "maybelongcommentend"
   "longstring"
   "maybelongstring"
   "maybelongstringend"
end

function tl.lex(input: string): {Token}, {Token}
   local tokens: {Token} = {}

   local state: LexState = "start"
   local fwd = true
   local y = 1
   local x = 0
   local i = 0
   local lc_open_lvl = 0
   local lc_close_lvl = 0
   local ls_open_lvl = 0
   local ls_close_lvl = 0
   local errs: {Token} = {}

   local tx: number
   local ty: number
   local ti: number
   local in_token = false

   local function begin_token()
      tx = x
      ty = y
      ti = i
      in_token = true
   end

   local function end_token(kind: TokenKind, last: number, t: string)
      local tk = t or input:sub(ti, last or i) or ""
      if keywords[tk] then
         kind = "keyword"
      end
      table.insert(tokens, {
         x = tx,
         y = ty,
         i = ti,
         tk = tk,
         kind = kind,
      })
      in_token = false
   end

   local function drop_token()
      in_token = false
   end

   while i <= #input do
      if fwd then
         i = i + 1
         if i > #input then
            break
         end
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

      if state == "start" then
         if input:sub(1,2) == "#!" then
            i = input:find("\n")
            if not i then
               break
            end
            c = "\n"
            y = 2
            x = 0
         end
         state = "any"
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
         elseif lex_word_start[c] then
            state = "identifier"
            begin_token()
         elseif c == "0" then
            state = "decimal_or_hex"
            begin_token()
         elseif lex_decimal_start[c] then
            state = "decimal_number"
            begin_token()
         elseif c == "<" then
            state = "lt"
            begin_token()
         elseif c == ":" then
            state = "colon"
            begin_token()
         elseif c == ">" then
            state = "gt"
            begin_token()
         elseif c == "=" or c == "~" then
            state = "maybeequals"
            begin_token()
         elseif c == "[" then
            state = "maybelongstring"
            begin_token()
         elseif lex_char_symbols[c] then
            begin_token()
            end_token(c as TokenKind)
         elseif lex_op_start[c] then
            begin_token()
            end_token("op")
         elseif lex_space[c] then
            -- continue
         else
            begin_token()
            end_token("$invalid$")
            table.insert(errs, tokens[#tokens])
         end
      elseif state == "maybecomment" then
         if c == "-" then
            state = "maybecomment2"
         else
            end_token("op", nil, "-")
            fwd = false
            state = "any"
         end
      elseif state == "maybecomment2" then
         if c == "[" then
            state = "maybelongcomment"
         else
            fwd = false
            state = "comment"
            drop_token()
         end
      elseif state == "maybelongcomment" then
         if c == "[" then
            state = "longcomment"
         elseif c == "=" then
            lc_open_lvl = lc_open_lvl + 1
         else
            fwd = false
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
            end_token("op", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "lt" then
         if c == "=" or c == "<" then
            end_token("op")
            state = "any"
         else
            end_token("op", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "colon" then
         if c == ":" then
            end_token("::")
            state = "any"
         else
            end_token(":", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "gt" then
         if c == "=" or c == ">" then
            end_token("op")
            state = "any"
         else
            end_token("op", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "maybelongstring" then
         if c == "[" then
            state = "longstring"
         elseif c == "=" then
            ls_open_lvl = ls_open_lvl + 1
         else
            end_token("[", i - 1)
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
            state = "maybedotdotdot"
         elseif lex_decimals[c] then
            state = "decimal_float"
         else
            end_token(".", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "maybedotdotdot" then
         if c == "." then
            end_token("...")
            state = "any"
         else
            end_token("op", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "comment" then
         if c == "\n" then
            state = "any"
         end
      elseif state == "identifier" then
         if not lex_word[c] then
            end_token("identifier", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "decimal_or_hex" then
         if c == "x" or c == "X" then
            state = "hex_number"
         elseif c == "e" or c == "E" then
            state = "power_sign"
         elseif lex_decimals[c] then
            state = "decimal_number"
         elseif c == "." then
            state = "decimal_float"
         else
            end_token("number", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "hex_number" then
         if c == "." then
            state = "hex_float"
         elseif c == "p" or c == "P" then
            state = "power_sign"
         elseif not lex_hexadecimals[c] then
            end_token("number", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "hex_float" then
         if c == "p" or c == "P" then
            state = "power_sign"
         elseif not lex_hexadecimals[c] then
            end_token("number", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "decimal_number" then
         if c == "." then
            state = "decimal_float"
         elseif c == "e" or c == "E" then
            state = "power_sign"
         elseif not lex_decimals[c] then
            end_token("number", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "decimal_float" then
         if c == "e" or c == "E" then
            state = "power_sign"
         elseif not lex_decimals[c] then
            end_token("number", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "power_sign" then
         if c == "-" or c == "+" then
            state = "power"
         elseif lex_decimals[c] then
            state = "power"
         else
            end_token("$invalid$")
            table.insert(errs, tokens[#tokens])
            state = "any" -- FIXME report malformed number
         end
      elseif state == "power" then
         if not lex_decimals[c] then
            end_token("number", i - 1)
            fwd = false
            state = "any"
         end
      end
   end

   local terminals: {LexState:TokenKind} = {
      ["identifier"] = "identifier",
      ["decimal_or_hex"] = "number",
      ["decimal_number"] = "number",
      ["decimal_float"] = "number",
      ["hex_number"] = "number",
      ["hex_float"] = "number",
      ["power"] = "number",
   }

   if in_token then
      if terminals[state] then
         end_token(terminals[state], i - 1)
      else
         drop_token()
      end
   end

   return tokens, (#errs > 0) and errs
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

local last_typeid = 0

local function new_typeid(): number
   last_typeid = last_typeid + 1
   return last_typeid
end

local ParseError = record
   y: number
   x: number
   msg: string
   filename: string
end

local TypeName = enum
   "typetype"
   "typevar"
   "typearg"
   "function"
   "array"
   "map"
   "arrayrecord"
   "record"
   "enum"
   "boolean"
   "string"
   "nil"
   "number"
   "union"
   "nominal"
   "bad_nominal"
   "emptytable"
   "table_item"
   "unknown_emptytable_value"
   "tuple"
   "poly" -- intersection types, currently restricted to polymorphic functions defined inside records
   "any"
   "unknown"
   "invalid"
   "unresolved_labels"
   "none"
end

local table_types: {TypeName:boolean} = {
   ["array"] = true,
   ["map"] = true,
   ["arrayrecord"] = true,
   ["record"] = true,
   ["emptytable"] = true,
}

local Type = record
   {Type}
   y: number
   x: number
   typename: TypeName
   tk: string

   yend: number

   -- Lua compatibilty
   needs_compat53: boolean

   -- vararg
   is_va: boolean

   -- poly, union
   types: {Type}

   -- typetype
   def: Type

   -- map
   keys: Type
   values: Type

   -- records
   typeargs: {Type}
   fields: {string: Type}
   field_order: {string}

   -- array
   elements: Type

   -- function
   is_method: boolean
   args: Type
   rets: Type

   typeid: number

   -- nominal
   names: {string}
   typevals: Type
   resolved: Type

   -- typevar
   typevar: string

   -- typearg
   typearg: string

   -- table items
   kname: string
   ktype: Type
   vtype: Type

   -- emptytable
   declared_at: Node
   assigned_to: string
   keys_inferred_at: Node
   keys_inferred_at_file: string
   inferred_at: Node
   inferred_at_file: string
   emptytable_type: Type

   -- enum
   enumset: {string:boolean}

   -- goto label checks
   labels: {string:{Node}}
end

local Operator = record
   y: number
   x: number
   arity: number
   op: string
   prec: number
end

local NodeKind = enum
   "op"
   "nil"
   "string"
   "number"
   "boolean"
   "table_literal"
   "table_item"
   "function"
   "expression_list"
   "enum_item"
   "if"
   "elseif"
   "else"
   "while"
   "fornum"
   "forin"
   "goto"
   "label"
   "repeat"
   "do"
   "break"
   "return"
   "values"
   "newtype"
   "argument"
   "variable"
   "variables"
   "statements"
   "assignment"
   "argument_list"
   "local_function"
   "global_function"
   "record_function"
   "local_declaration"
   "global_declaration"
   "identifier"
   "cast"
   "..."
   "paren"
end

local FactType = enum
   "is"
end

local Fact = record
   fact: FactType
   var: string
   typ: Type
end

local Node = record
   {Node}
   y: number
   x: number
   tk: string
   kind: NodeKind

   yend: number

   facts: {Fact}

   key: Node
   value: Node

   typeargs: Type
   args: Node
   rets: Type
   body: Node

   name: Node

   -- local
   is_const: boolean

   fn_owner: Node
   is_method: boolean

   exp: Node
   parent_if: Node
   thenpart: Node
   elseifs: Node
   elseif_n: number
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
   constnum: number
   conststr: string

   -- goto
   label: string

   casttype: Type

   typename: string
   type: Type
   decltype: Type
end

local parse_expression: function({Token}, number, {ParseError}): number, Node, number
local parse_statements: function({Token}, number, {ParseError}, string): number, Node
local parse_type_list: function({Token}, number, {ParseError}, string): number, Type
local parse_argument_list: function({Token}, number, {ParseError}): number, Node
local parse_argument_type_list: function({Token}, number, {ParseError}): number, Type
local parse_type: function({Token}, number, {ParseError}): number, Type, number
local parse_newtype: function(tokens: {Token}, i: number, errs: {ParseError}): number, Node


local function fail(tokens: {Token}, i: number, errs: {ParseError}, msg: string): number
   if not tokens[i] then
      local eof = tokens[#tokens]
      table.insert(errs, { y = eof.y, x = eof.x, msg = msg or "unexpected end of file" })
      return #tokens
   end
   table.insert(errs, { y = tokens[i].y, x = tokens[i].x, msg = msg or "syntax error" })
   return math.min(#tokens, i + 1)
end

local function verify_tk(tokens: {Token}, i: number, errs: {ParseError}, tk: string): number
   if tokens[i].tk == tk then
      return i + 1
   end
   return fail(tokens, i, errs, "syntax error, expected '" .. tk .. "'")
end

local function new_node(tokens: {Token}, i: number, kind: NodeKind): Node
   local t = tokens[i]
   return { y = t.y, x = t.x, tk = t.tk, kind = kind or t.kind }
end

local function a_type(t: Type): Type
   t.typeid = new_typeid()
   return t
end

local function new_type(tokens: {Token}, i: number): Type
   local t = tokens[i]
   return a_type { y = t.y, x = t.x, tk = t.tk }
end

local function verify_kind(tokens: {Token}, i: number, errs: {ParseError}, kind: TokenKind, node_kind: NodeKind): number, Node
   if tokens[i].kind == kind then
      return i + 1, new_node(tokens, i, node_kind)
   end
   return fail(tokens, i, errs, "syntax error, expected " .. kind)
end

local is_newtype: {string:boolean} = {
   ["enum"] = true,
   ["record"] = true,
   ["functiontype"] = true,
}

local function parse_table_value(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   if is_newtype[tokens[i].tk] then
      return parse_newtype(tokens, i, errs)
   else
      local i, node, _ = parse_expression(tokens, i, errs)
      return i, node
   end
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
      i, node.value = parse_table_value(tokens, i, errs)
      return i, node, n
   elseif tokens[i].kind == "identifier" and tokens[i+1].tk == "=" then
      i, node.key = verify_kind(tokens, i, errs, "identifier", "string")
      node.key.conststr = node.key.tk
      node.key.tk = '"' .. node.key.tk .. '"'
      i = verify_tk(tokens, i, errs, "=")
      i, node.value = parse_table_value(tokens, i, errs)
      return i, node, n
   elseif tokens[i].kind == "identifier" and tokens[i+1].tk == ":" then
      local orig_i = i
      local try_errs: {ParseError} = {}
      i, node.key = verify_kind(tokens, i, try_errs, "identifier", "string")
      node.key.conststr = node.key.tk
      node.key.tk = '"' .. node.key.tk .. '"'
      i = verify_tk(tokens, i, try_errs, ":")
      i, node.decltype = parse_type(tokens, i, try_errs)
      if node.decltype and tokens[i].tk == "=" then
         i = verify_tk(tokens, i, try_errs, "=")
         i, node.value = parse_table_value(tokens, i, try_errs)
         if node.value then
            for _, e in ipairs(try_errs) do
               table.insert(errs, e)
            end
            return i, node, n
         end
      end
      -- backtrack:
      node.decltype = nil
      i = orig_i
   end

   node.key = new_node(tokens, i, "number")
   node.key.constnum = n
   node.key.tk = tostring(n)
   i, node.value = parse_expression(tokens, i, errs)
   return i, node, n + 1
end

local ParseItem = functiontype<`T>({Token}, number, {ParseError}, number): number, `T, number

local SeparatorMode = enum
   "sep"
   "term"
end

local function parse_list<`T>(tokens: {Token}, i: number, errs: {ParseError}, list: {`T}, close: {string:boolean}, sep: SeparatorMode, parse_item: ParseItem<`T>): number, {`T}
   local n = 1
   while tokens[i].kind ~= "$EOF$" do
      if close[tokens[i].tk] then
         (list as Node).yend = tokens[i].y
         break
      end
      local item: `T
      i, item, n = parse_item(tokens, i, errs, n)
      table.insert(list, item)
      if tokens[i].tk == "," then
         i = i + 1
      elseif sep == "sep" and not close[tokens[i].tk] then
         return fail(tokens, i, errs)
      elseif sep == "term" and tokens[i].tk == ";" then
         i = i + 1
      end
   end
   return i, list
end

local function parse_bracket_list<`T>(tokens: {Token}, i: number, errs: {ParseError}, list: {`T}, open: string, close: string, sep: SeparatorMode, parse_item: ParseItem<`T>): number, {`T}
   i = verify_tk(tokens, i, errs, open)
   i = parse_list(tokens, i, errs, list, { [close] = true }, sep, parse_item)
   i = verify_tk(tokens, i, errs, close)
   return i, list
end

local function parse_table_literal(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "table_literal")
   return parse_bracket_list(tokens, i, errs, node, "{", "}", "term", parse_table_item)
end

local function parse_trying_list<`T>(tokens: {Token}, i: number, errs: {ParseError}, list: {`T}, parse_item: ParseItem<`T>): number, {`T}
   local tryerrs: {ParseError} = {}
   local tryi, item = parse_item(tokens, i, tryerrs)
   if not item then
      return i, list
   end
   for _, e in ipairs(tryerrs) do
      table.insert(errs, e)
   end
   i = tryi
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

local function parse_typearg_type(tokens: {Token}, i: number, errs: {ParseError}): number, Type, number
   i = verify_tk(tokens, i, errs, "`")
   i = verify_kind(tokens, i, errs, "identifier")
   return i, a_type {
      y = tokens[i - 2].y,
      x = tokens[i - 2].x,
      typename = "typearg",
      typearg = "`" .. tokens[i-1].tk,
   }
end

local function parse_typevar_type(tokens: {Token}, i: number, errs: {ParseError}): number, Type, number
   i = verify_tk(tokens, i, errs, "`")
   i = verify_kind(tokens, i, errs, "identifier")
   return i, a_type {
      y = tokens[i - 2].y,
      x = tokens[i - 2].x,
      typename = "typevar",
      typevar = "`" .. tokens[i-1].tk,
   }
end

local function parse_typearg_list(tokens: {Token}, i: number, errs: {ParseError}): number, Type
   local typ = new_type(tokens, i)
   typ.typename = "tuple"
   return parse_bracket_list(tokens, i, errs, typ, "<", ">", "sep", parse_typearg_type)
end

local function parse_typeval_list(tokens: {Token}, i: number, errs: {ParseError}): number, Type
   local typ = new_type(tokens, i)
   typ.typename = "tuple"
   return parse_bracket_list(tokens, i, errs, typ, "<", ">", "sep", parse_type)
end

local function parse_return_types(tokens: {Token}, i: number, errs: {ParseError}): number, Type
   local rets: Type
   i, rets = parse_type_list(tokens, i, errs)
   if tokens[i].tk == "..." then
      i = i + 1
      local nrets = #rets
      if nrets > 0 then
         rets[nrets].is_va = true
      else
         return fail(tokens, i, errs, "unexpected '...'")
      end
   end

   return i, rets
end

local function parse_function_type(tokens: {Token}, i: number, errs: {ParseError}): number, Type
   i = i + 1
   local node: Type = {
      y = tokens[i - 1].y,
      x = tokens[i - 1].x,
      typename = "function",
      args = {},
      rets = {},
   }
   if tokens[i].tk == "<" then
      i, node.typeargs = parse_typearg_list(tokens, i, errs)
   end
   if tokens[i].tk == "(" then
      i, node.args = parse_argument_type_list(tokens, i, errs)
      i, node.rets = parse_return_types(tokens, i, errs)
   else
      node.args = { { typename = "any", is_va = true } }
      node.rets = { { typename = "any", is_va = true } }
   end
   return i, node
end

local function parse_base_type(tokens: {Token}, i: number, errs: {ParseError}): number, Type, number
   if tokens[i].tk == "string"
      or tokens[i].tk == "boolean"
      or tokens[i].tk == "nil"
      or tokens[i].tk == "number" then
      return i + 1, a_type {
         y = tokens[i].y,
         x = tokens[i].x,
         typename = tokens[i].tk as TypeName
      }
   elseif tokens[i].tk == "table" then
      local typ = new_type(tokens, i)
      typ.typename = "map"
      typ.keys = a_type { typename = "any" }
      typ.values = a_type { typename = "any" }
      return i + 1, typ
   elseif tokens[i].tk == "function" then
      return parse_function_type(tokens, i, errs)
   elseif tokens[i].tk == "{" then
      i = i + 1
      local decl = new_type(tokens, i)
      local t: Type
      i, t = parse_type(tokens, i, errs)
      if tokens[i].tk == "}" then
         decl.typename = "array"
         decl.elements = t
         decl.yend = tokens[i].y
         i = verify_tk(tokens, i, errs, "}")
      elseif tokens[i].tk == ":" then
         decl.typename = "map"
         i = i + 1
         decl.keys = t
         i, decl.values = parse_type(tokens, i, errs)
         decl.yend = tokens[i].y
         i = verify_tk(tokens, i, errs, "}")
      end
      return i, decl
   elseif tokens[i].tk == "`" then
      return parse_typevar_type(tokens, i, errs)
   elseif tokens[i].kind == "identifier" then
      local typ = new_type(tokens, i)
      typ.typename = "nominal"
      typ.names = { tokens[i].tk }
      i = i + 1
      while tokens[i].tk == "." do
         i = i + 1
         if tokens[i].kind == "identifier" then
            table.insert(typ.names, tokens[i].tk)
            i = i + 1
         else
            return fail(tokens, i, errs, "syntax error, expected identifier")
         end
      end

      if tokens[i].tk == "<" then
         i, typ.typevals = parse_typeval_list(tokens, i, errs)
      end
      return i, typ
   end
   return fail(tokens, i, errs)
end

parse_type = function(tokens: {Token}, i: number, errs: {ParseError}): number, Type, number
   local istart = i
   local bt: Type
   i, bt = parse_base_type(tokens, i, errs)
   if not bt then
      return i
   end
   if tokens[i].tk == "|" then
      local u = new_type(tokens, istart)
      u.typename = "union"
      u.types = { bt }
      while tokens[i].tk == "|" do
         i = i + 1
         i, bt = parse_base_type(tokens, i, errs)
         if not bt then
            return i
         end
         table.insert(u.types, bt)
      end
      return i, u
   else
      return i, bt
   end
end

parse_type_list = function(tokens: {Token}, i: number, errs: {ParseError}, open: string): number, Type
   local list = new_type(tokens, i)
   list.typename = "tuple"
   if tokens[i].tk == (open or ":") then
      i = i + 1
      local optional_paren = false
      if tokens[i - 1].tk == ":" then
         if tokens[i].tk == "(" then
            optional_paren = true
            i = i + 1
         end
      end
      i = parse_trying_list(tokens, i, errs, list, parse_type)
      if optional_paren then
         i = verify_tk(tokens, i, errs, ")")
      end
   end
   return i, list
end

local function parse_function_args_rets_body(tokens: {Token}, i: number, errs: {ParseError}, node: Node): number, Node
   if tokens[i].tk == "<" then
      i, node.typeargs = parse_typearg_list(tokens, i, errs)
   end
   i, node.args = parse_argument_list(tokens, i, errs)
   i, node.rets = parse_return_types(tokens, i, errs)
   i, node.body = parse_statements(tokens, i, errs)
   node.yend = tokens[i].y
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_function_value(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "function")
   i = verify_tk(tokens, i, errs, "function")
   return parse_function_args_rets_body(tokens, i, errs, node)
end

local function unquote(str: string): string
   local f = str:sub(1, 1)
   if f == '"' or f == "'" then
      return str:sub(2, -2)
   end
   f = str:match("^%[=*%[")
   local l = #f + 1
   return str:sub(l, -l)
end

local function parse_literal(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   if tokens[i].tk == "{" then
      return parse_table_literal(tokens, i, errs)
   elseif tokens[i].kind == "..." then
      return verify_kind(tokens, i, errs, "...")
   elseif tokens[i].kind == "string" then
      local tk = unquote(tokens[i].tk)
      local node: Node
      i, node = verify_kind(tokens, i, errs, "string")
      node.conststr = tk
      return i, node
   elseif tokens[i].kind == "identifier" then
      return verify_kind(tokens, i, errs, "identifier", "variable")
   elseif tokens[i].kind == "number" then
      local n = tonumber(tokens[i].tk)
      local node: Node
      i, node = verify_kind(tokens, i, errs, "number")
      node.constnum = n
      return i, node
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
         ["+"] = 8,
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

   local function new_operator(tk: Token, arity: number, op: string): Operator
      op = op or tk.tk
      return { y = tk.y, x = tk.x, arity = arity, op = op, prec = precedences[arity][op] }
   end

   local E: function({Token}, number, {ParseError}): number, Node

   local function P(tokens: {Token}, i: number, errs: {ParseError}): number, Node
      if tokens[i].kind == "$EOF$" then
         return i
      end
      local e1: Node
      local t1 = tokens[i]
      if precedences[1][tokens[i].tk] ~= nil then
         local op: Operator = new_operator(tokens[i], 1)
         i = i + 1
         i, e1 = P(tokens, i, errs)
         e1 = { y = t1.y, x = t1.x, kind = "op", op = op, e1 = e1 }
      elseif tokens[i].tk == "(" then
         i = i + 1
         i, e1 = parse_expression(tokens, i, errs)
         e1 = { y = t1.y, x = t1.x, kind = "paren", e1 = e1 }
         i = verify_tk(tokens, i, errs, ")")
      else
         i, e1 = parse_literal(tokens, i, errs)
      end

      while true do
         if tokens[i].kind == "string" or tokens[i].kind == "{" then
            local op: Operator = new_operator(tokens[i], 2, "@funcall")
            local args = new_node(tokens, i, "expression_list")
            local arg: Node
            if tokens[i].kind == "string" then
               arg = new_node(tokens, i)
               arg.conststr = unquote(tokens[i].tk)
               i = i + 1
            else
               i, arg = parse_table_literal(tokens, i, errs)
            end
            table.insert(args, arg)
            e1 = { y = t1.y, x = t1.x, kind = "op", op = op, e1 = e1, e2 = args }
         elseif tokens[i].tk == "(" then
            local op: Operator = new_operator(tokens[i], 2, "@funcall")

            local args = new_node(tokens, i, "expression_list")
            i, args = parse_bracket_list(tokens, i, errs, args, "(", ")", "sep", parse_expression)

            e1 = { y = t1.y, x = t1.x, kind = "op", op = op, e1 = e1, e2 = args }
         elseif tokens[i].tk == "[" then
            local op: Operator = new_operator(tokens[i], 2, "@index")

            local idx: Node
            i = i + 1
            i, idx = parse_expression(tokens, i, errs)
            i = verify_tk(tokens, i, errs, "]")

            e1 = { y = t1.y, x = t1.x, kind = "op", op = op, e1 = e1, e2 = idx }
         elseif tokens[i].tk == "." or tokens[i].tk == ":" then
            local op: Operator = new_operator(tokens[i], 2)

            local key: Node
            i = i + 1
            i, key = verify_kind(tokens, i, errs, "identifier")

            e1 = { y = t1.y, x = t1.x, kind = "op", op = op, e1 = e1, e2 = key }
         elseif tokens[i].tk == "as" or tokens[i].tk == "is" then
            local op: Operator = new_operator(tokens[i], 2, tokens[i].tk)

            i = i + 1
            local cast = new_node(tokens, i, "cast")
            i, cast.casttype = parse_type(tokens, i, errs)
            e1 = { y = t1.y, x = t1.x, kind = "op", op = op, e1 = e1, e2 = cast, conststr = e1.conststr }
         else
            break
         end
      end

      return i, e1
   end

   local function E(tokens: {Token}, i: number, errs: {ParseError}, lhs: Node, min_precedence: number): number, Node
      local lookahead = tokens[i].tk
      while precedences[2][lookahead] and precedences[2][lookahead] >= min_precedence do
         local t1 = tokens[i]
         local op: Operator = new_operator(t1, 2)
         i = i + 1
         local rhs: Node
         i, rhs = P(tokens, i, errs)
         lookahead = tokens[i].tk
         while precedences[2][lookahead] and ((precedences[2][lookahead] > (precedences[2][op.op]))
            or (is_right_assoc[lookahead] and (precedences[2][lookahead] == precedences[2][op.op]))) do
            i, rhs = E(tokens, i, errs, rhs, precedences[2][lookahead])
            lookahead = tokens[i].tk
         end
         lhs = { y = t1.y, x = t1.x, kind = "op", op = op, e1 = lhs, e2 = rhs, }
      end
      return i, lhs
   end

   parse_expression = function(tokens: {Token}, i: number, errs: {ParseError}): number, Node, number
      local lhs: Node
      i, lhs = P(tokens, i, errs)
      i, lhs = E(tokens, i, errs, lhs, 0)
      if lhs then
         return i, lhs, 0
      else
         return fail(tokens, i, errs, "expected an expression")
      end
   end
end

local function parse_variable(tokens: {Token}, i: number, errs: {ParseError}): number, Node, number
   if tokens[i].tk == "..." then
      return verify_kind(tokens, i, errs, "...")
   end
   return verify_kind(tokens, i, errs, "identifier", "variable")
end

local function parse_variable_name(tokens: {Token}, i: number, errs: {ParseError}): number, Node, number
   local is_const: boolean = false
   local node: Node
   i, node = verify_kind(tokens, i, errs, "identifier")
   if not node then
      return i
   end
   if tokens[i].tk == "<" then
      i = i + 1
      local annotation: Node
      i, annotation = verify_kind(tokens, i, errs, "identifier")
      if annotation and annotation.tk == "const" then
         is_const = true
      end
      i = verify_tk(tokens, i, errs, ">")
   end
   node.is_const = is_const
   return i, node
end

local function parse_argument(tokens: {Token}, i: number, errs: {ParseError}): number, Node, number
   local node: Node
   if tokens[i].tk == "..." then
      i, node = verify_kind(tokens, i, errs, "...")
   else
      i, node = verify_kind(tokens, i, errs, "identifier", "argument")
   end
   if tokens[i].tk == ":" then
      i = i + 1
      i, node.decltype = parse_type(tokens, i, errs)
   end
   return i, node, 0
end

parse_argument_list = function(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "argument_list")
   return parse_bracket_list(tokens, i, errs, node, "(", ")", "sep", parse_argument)
end

local function parse_argument_type(tokens: {Token}, i: number, errs: {ParseError}): number, Type, number
   local is_va = false
   if tokens[i].kind == "identifier" and tokens[i + 1].tk == ":" then
      i = i + 2
   elseif tokens[i].tk == "..." then
      if tokens[i + 1].tk == ":" then
         i = i + 2
         is_va = true
      else
         return fail(tokens, i, errs, "cannot have untyped '...' when declaring the type of an argument")
      end
   end

   local i, typ = parse_type(tokens, i, errs)
   if typ then
      typ.is_va = is_va
   end

   return i, typ, 0
end

parse_argument_type_list = function(tokens: {Token}, i: number, errs: {ParseError}): number, Type
   local list = new_type(tokens, i)
   list.typename = "tuple"
   return parse_bracket_list(tokens, i, errs, list, "(", ")", "sep", parse_argument_type)
end

local function parse_local_function(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "local_function")
   i = verify_tk(tokens, i, errs, "local")
   i = verify_tk(tokens, i, errs, "function")
   i, node.name = verify_kind(tokens, i, errs, "identifier")
   return parse_function_args_rets_body(tokens, i, errs, node)
end

local function parse_function(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local orig_i = i
   local fn = new_node(tokens, i, "global_function")
   local node = fn
   i = verify_tk(tokens, i, errs, "function")
   local names: {Node} = {}
   i, names[1] = verify_kind(tokens, i, errs, "identifier", "variable")
   while tokens[i].tk == "." do
      i = i + 1
      i, names[#names + 1] = verify_kind(tokens, i, errs, "identifier")
   end
   if tokens[i].tk == ":" then
      i = i + 1
      i, names[#names + 1] = verify_kind(tokens, i, errs, "identifier")
      fn.is_method = true
   end

   if #names > 1 then
      fn.kind = "record_function"
      local owner = names[1]
      for i = 2, #names - 1 do
         local dot = { y = names[i].y, x = names[i].x - 1, arity = 2, op = "." }
         names[i].kind = "identifier"
         local op = { y = names[i].y, x = names[i].x, kind = "op", op = dot, e1 = owner, e2 = names[i] }
         owner = op
      end
      fn.fn_owner = owner
   end
   fn.name = names[#names]

   local selfx, selfy = tokens[i].x, tokens[i].y
   i = parse_function_args_rets_body(tokens, i, errs, fn)
   if fn.is_method then
      table.insert(fn.args, 1, { x = selfx, y = selfy, tk = "self", kind = "variable" })
   end

   if not fn.name then
      return orig_i
   end

   return i, node
end

local function parse_if(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "if")
   i = verify_tk(tokens, i, errs, "if")
   i, node.exp = parse_expression(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "then")
   i, node.thenpart = parse_statements(tokens, i, errs)
   node.elseifs = {}
   local n = 0
   while tokens[i].tk == "elseif" do
      n = n + 1
      local subnode = new_node(tokens, i, "elseif")
      subnode.parent_if = node
      subnode.elseif_n = n
      i = i + 1
      i, subnode.exp = parse_expression(tokens, i, errs)
      i = verify_tk(tokens, i, errs, "then")
      i, subnode.thenpart = parse_statements(tokens, i, errs)
      table.insert(node.elseifs, subnode)
   end
   if tokens[i].tk == "else" then
      local subnode = new_node(tokens, i, "else")
      subnode.parent_if = node
      i = i + 1
      i, subnode.elsepart = parse_statements(tokens, i, errs)
      node.elsepart = subnode
   end
   node.yend = tokens[i].y
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_while(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "while")
   i = verify_tk(tokens, i, errs, "while")
   i, node.exp = parse_expression(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   node.yend = tokens[i].y
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_fornum(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "fornum")
   i = i + 1
   i, node.var = verify_kind(tokens, i, errs, "identifier")
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
   node.yend = tokens[i].y
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_forin(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "forin")
   i = i + 1
   node.vars = new_node(tokens, i, "variables")
   i, node.vars = parse_list(tokens, i, errs, node.vars, { ["in"] = true }, "sep", parse_variable_name)
   i = verify_tk(tokens, i, errs, "in")
   node.exps = new_node(tokens, i, "expression_list")
   i = parse_list(tokens, i, errs, node.exps, { ["do"] = true }, "sep", parse_expression)
   if #node.exps < 1 then
      return fail(tokens, i, errs, "missing iterator expression in generic for")
   elseif #node.exps > 3 then
      return fail(tokens, i, errs, "too many expressions in generic for")
   end
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   node.yend = tokens[i].y
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_for(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   if tokens[i+1].kind == "identifier" and tokens[i+2].tk == "=" then
      return parse_fornum(tokens, i, errs)
   else
      return parse_forin(tokens, i, errs)
   end
end

local function parse_repeat(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "repeat")
   i = verify_tk(tokens, i, errs, "repeat")
   i, node.body = parse_statements(tokens, i, errs)
   node.yend = tokens[i].y
   i = verify_tk(tokens, i, errs, "until")
   i, node.exp = parse_expression(tokens, i, errs)
   return i, node
end

local function parse_do(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "do")
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   node.yend = tokens[i].y
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_break(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "break")
   i = verify_tk(tokens, i, errs, "break")
   return i, node
end

local function parse_goto(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "goto")
   i = verify_tk(tokens, i, errs, "goto")
   node.label = tokens[i].tk
   i = verify_kind(tokens, i, errs, "identifier")
   return i, node
end

local function parse_label(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "label")
   i = verify_tk(tokens, i, errs, "::")
   node.label = tokens[i].tk
   i = verify_kind(tokens, i, errs, "identifier")
   i = verify_tk(tokens, i, errs, "::")
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

local function parse_return(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node = new_node(tokens, i, "return")
   i = verify_tk(tokens, i, errs, "return")
   node.exps = new_node(tokens, i, "expression_list")
   i = parse_list(tokens, i, errs, node.exps, stop_return_list, "sep", parse_expression)
   if tokens[i].kind == ";" then
      i = i + 1
   end
   return i, node
end

parse_newtype = function(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local node: Node = new_node(tokens, i, "newtype")
   node.newtype = new_type(tokens, i)
   node.newtype.typename = "typetype"
   if tokens[i].tk == "record" then
      local def = new_type(tokens, i)
      node.newtype.def = def
      def.typename = "record"
      def.fields = {}
      def.field_order = {}
      i = i + 1
      if tokens[i].tk == "<" then
         i, def.typeargs = parse_typearg_list(tokens, i, errs)
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
               node.yend = tokens[i].y
               i = verify_tk(tokens, i, errs, "}")
            else
               return fail(tokens, i, errs, "expected an array declaration")
            end
            def.typename = "arrayrecord"
            def.elements = t
         else
            local v: Node
            i, v = verify_kind(tokens, i, errs, "identifier", "variable")
            if not v then
               return fail(tokens, i, errs, "expected a variable name")
            end
            i = verify_tk(tokens, i, errs, ":")
            local t: Type
            i, t = parse_type(tokens, i, errs)
            if not t then
               return fail(tokens, i, errs, "expected a type")
            end
            if not def.fields[v.tk] then
               def.fields[v.tk] = t
               table.insert(def.field_order, v.tk)
            else
               local prev_t = def.fields[v.tk]
               if t.typename == "function" and prev_t.typename == "function" then
                  def.fields[v.tk] = a_type {
                     y = v.y,
                     x = v.x,
                     typename = "poly",
                     types = { prev_t, t }
                  }
               elseif t.typename == "function" and prev_t.typename == "poly" then
                  table.insert(prev_t.types, t)
               else
                  return fail(tokens, i, errs, "attempt to redeclare field '" .. v.tk .. "' (only functions can be overloaded)")
               end
            end
         end
      end
      node.yend = tokens[i].y
      i = verify_tk(tokens, i, errs, "end")
      return i, node
   elseif tokens[i].tk == "enum" then
      local def = new_type(tokens, i)
      node.newtype.def = def
      def.typename = "enum"
      def.enumset = {}
      i = i + 1
      while not ((not tokens[i]) or tokens[i].tk == "end") do
         local item: Node
         i, item = verify_kind(tokens, i, errs, "string", "enum_item")
         if item then
            table.insert(node, item)
            def.enumset[unquote(item.tk)] = true
         end
      end
      node.yend = tokens[i].y
      i = verify_tk(tokens, i, errs, "end")
      return i, node
   elseif tokens[i].tk == "functiontype" then
      i, node.newtype.def = parse_function_type(tokens, i, errs)
      return i, node
   end
   return fail(tokens, i, errs)
end

local function parse_call_or_assignment(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   local asgn: Node = new_node(tokens, i, "assignment")

   local tryi = i
   asgn.vars = new_node(tokens, i, "variables")
   i = parse_trying_list(tokens, i, errs, asgn.vars, parse_expression)
   if #asgn.vars < 1 then
      return fail(tokens, i, errs)
   end
   local lhs: Node = asgn.vars[1]

   if tokens[i].tk == "=" then
      asgn.exps = new_node(tokens, i, "values")
      repeat
         i = i + 1
         local val: Node
         i, val = parse_expression(tokens, i, errs)
         table.insert(asgn.exps, val)
      until tokens[i].tk ~= ","
      return i, asgn
   end
   if #asgn.vars > 1 then
      local expi = parse_expression(tokens, tryi, {})
      return fail(tokens, expi or i, errs)
   end
   if lhs.op and lhs.op.op == "@funcall" and #asgn.vars == 1 then
      return i, lhs
   end
   return fail(tokens, i, errs)
end

local function parse_variable_declarations(tokens: {Token}, i: number, errs: {ParseError}, node_name: NodeKind): number, Node
   local asgn: Node = new_node(tokens, i, node_name)

   asgn.vars = new_node(tokens, i, "variables")
   i = parse_trying_list(tokens, i, errs, asgn.vars, parse_variable_name)
   if #asgn.vars == 0 then
      return fail(tokens, i, errs, "expected a local variable definition")
   end
   local lhs: Node = asgn.vars[1]

   i, asgn.decltype = parse_type_list(tokens, i, errs)

   if tokens[i].tk == "=" then
      asgn.exps = new_node(tokens, i, "values")
      local v = 1
      repeat
         i = i + 1
         local val: Node
         if is_newtype[tokens[i].tk] then
            if #asgn.vars > 1 then
               return fail(tokens, i, errs, "cannot perform multiple assignment of type definitions")
            end
            i, val = parse_newtype(tokens, i, errs)
            if val then
               val.newtype.def.names = { asgn.vars[v].tk }
            else
               return i, val
            end
         else
            i, val = parse_expression(tokens, i, errs)
         end
         table.insert(asgn.exps, val)
         v = v + 1
      until tokens[i].tk ~= ","
   end
   return i, asgn
end

local function parse_statement(tokens: {Token}, i: number, errs: {ParseError}): number, Node
   if tokens[i].tk == "local" then
      if tokens[i+1].tk == "function" then
         return parse_local_function(tokens, i, errs)
      else
         i = i + 1
         return parse_variable_declarations(tokens, i, errs, "local_declaration")
      end
   elseif tokens[i].tk == "global" then
      i = i + 1
      if tokens[i].tk == "function" then
         return parse_function(tokens, i, errs)
      end
      return parse_variable_declarations(tokens, i, errs, "global_declaration")
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
   elseif tokens[i].tk == "goto" then
      return parse_goto(tokens, i, errs)
   elseif tokens[i].tk == "::" then
      return parse_label(tokens, i, errs)
   else
      return parse_call_or_assignment(tokens, i, errs)
   end
   return fail(tokens, i, errs)
end

parse_statements = function(tokens: {Token}, i: number, errs: {ParseError}, filename: string): number, Node
   local node = new_node(tokens, i, "statements")
   while true do
      while tokens[i].kind == ";" do
         i = i + 1
      end
      if tokens[i].kind == "$EOF$" then
         break
      end
      if stop_statement_list[tokens[i].tk] then
         break
      end
      local item: Node
      i, item = parse_statement(tokens, i, errs)
      if filename then
         for j = 1, #errs do
            if not errs[j].filename then
               errs[j].filename = filename
            end
         end
      end
      if not item then
         break
      end
      table.insert(node, item)
   end
   return i, node
end

function tl.parse_program(tokens: {Token}, errs: {ParseError}, filename: string): number, Node
   errs = errs or {}
   local last = tokens[#tokens] or { y = 1, x = 1, tk = "" }
   table.insert(tokens, { y = last.y, x = last.x + #last.tk, tk = "$EOF$", kind = "$EOF$" })
   return parse_statements(tokens, 1, errs, filename)
end

--------------------------------------------------------------------------------
-- AST traversal
--------------------------------------------------------------------------------

local VisitorCallbacks = record<`N, `T>
   before: function(`N, {`T})
   before_statements: function({`N}, {`T})
   before_e2: function({`N}, {`T})
   after: function(`N, {`T}, `T): `T
end

local Visitor = record<`K, `N, `T>
   cbs: {`K:VisitorCallbacks<`N, `T>}
   after: VisitorCallbacks<`N, `T>
end

local function visit_before<`K,`N,`T>(ast: `N, kind: `K, visit: Visitor<`K,`N,`T>): `T
   assert(visit.cbs[kind], "no visitor for " .. (kind as string))
   if visit.cbs[kind].before then
      visit.cbs[kind].before(ast)
   end
end

local function visit_after<`K,`N,`T>(ast: `N, kind: `K, visit: Visitor<`K, `N,`T>, xs: {`T}): `T
   if visit.after and visit.after.before then
      visit.after.before(ast, xs)
   end
   local ret: `T
   if visit.cbs[kind].after then
      ret = visit.cbs[kind].after(ast, xs)
   end
   if visit.after and visit.after.after then
      ret = visit.after.after(ast, xs, ret)
   end
   return ret
end

local function recurse_type<`T>(ast: Type, visit: Visitor<TypeName, Type, `T>): `T
   visit_before(ast, ast.typename, visit)
   local xs: {`T} = {}

   for i, child in ipairs(ast) do
      xs[i] = recurse_type(child, visit)
   end

   if ast.types then
      for i, child in ipairs(ast.types) do
         table.insert(xs, recurse_type(child, visit))
      end
   end
   if ast.def then
      table.insert(xs, recurse_type(ast.def, visit))
   end
   if ast.keys then
      table.insert(xs, recurse_type(ast.keys, visit))
   end
   if ast.values then
      table.insert(xs, recurse_type(ast.values, visit))
   end
   if ast.typeargs then
      for _, child in ipairs(ast.typeargs) do
         table.insert(xs, recurse_type(child, visit))
      end
   end
   if ast.elements then
      table.insert(xs, recurse_type(ast.elements, visit))
   end
   if ast.fields then
      for _, child in pairs(ast.fields) do
         table.insert(xs, recurse_type(child, visit))
      end
   end
   if ast.args then
      for _, child in ipairs(ast.args) do
         table.insert(xs, recurse_type(child, visit))
      end
   end
   if ast.rets then
      for _, child in ipairs(ast.rets) do
         table.insert(xs, recurse_type(child, visit))
      end
   end
   if ast.typevals then
      for _, child in ipairs(ast.typevals) do
         table.insert(xs, recurse_type(child, visit))
      end
   end
   if ast.ktype then
      table.insert(xs, recurse_type(ast.ktype, visit))
   end
   if ast.vtype then
      table.insert(xs, recurse_type(ast.vtype, visit))
   end

   return visit_after(ast, ast.typename, visit, xs)
end

local function recurse_node<`T>(ast: Node,
                                visit_node: Visitor<NodeKind, Node, `T>,
                                visit_type: Visitor<TypeName, Type, `T>): `T
   if not ast then
      -- parse error
      return
   end
   visit_before(ast, ast.kind, visit_node)
   local xs: {`T} = {}
   local cbs = visit_node.cbs[ast.kind]
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
          or ast.kind == "global_declaration"
          or ast.kind == "assignment" then
      xs[1] = recurse_node(ast.vars, visit_node, visit_type)
      if ast.exps then
         xs[2] = recurse_node(ast.exps, visit_node, visit_type)
      end
      if ast.decltype then
         xs[3] = recurse_type(ast.decltype, visit_type)
      end
   elseif ast.kind == "table_item" then
      xs[1] = recurse_node(ast.key, visit_node, visit_type)
      xs[2] = recurse_node(ast.value, visit_node, visit_type)
   elseif ast.kind == "if" then
      xs[1] = recurse_node(ast.exp, visit_node, visit_type)
      if cbs.before_statements then
         cbs.before_statements(ast, xs)
      end
      xs[2] = recurse_node(ast.thenpart, visit_node, visit_type)
      for i, e in ipairs(ast.elseifs) do
         table.insert(xs, recurse_node(e, visit_node, visit_type))
      end
      if ast.elsepart then
         table.insert(xs, recurse_node(ast.elsepart, visit_node, visit_type))
      end
   elseif ast.kind == "while" then
      xs[1] = recurse_node(ast.exp, visit_node, visit_type)
      if cbs.before_statements then
         cbs.before_statements(ast, xs)
      end
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
      xs[2] = recurse_node(ast.exps, visit_node, visit_type)
      if cbs.before_statements then
         cbs.before_statements(ast)
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
      if cbs.before_statements then
         cbs.before_statements(ast, xs)
      end
      xs[2] = recurse_node(ast.thenpart, visit_node, visit_type)
   elseif ast.kind == "else" then
      xs[1] = recurse_node(ast.elsepart, visit_node, visit_type)
   elseif ast.kind == "return" then
      xs[1] = recurse_node(ast.exps, visit_node, visit_type)
   elseif ast.kind == "do" then
      xs[1] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "cast" then
   elseif ast.kind == "local_function"
          or ast.kind == "global_function" then
      xs[1] = recurse_node(ast.name, visit_node, visit_type)
      xs[2] = recurse_node(ast.args, visit_node, visit_type)
      xs[3] = recurse_type(ast.rets, visit_type)
      xs[4] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "record_function" then
      xs[1] = recurse_node(ast.fn_owner, visit_node, visit_type)
      xs[2] = recurse_node(ast.name, visit_node, visit_type)
      xs[3] = recurse_node(ast.args, visit_node, visit_type)
      xs[4] = recurse_type(ast.rets, visit_type)
      if cbs.before_statements then
         cbs.before_statements(ast, xs)
      end
      xs[5] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "paren" then
      xs[1] = recurse_node(ast.e1, visit_node, visit_type)
   elseif ast.kind == "op" then
      xs[1] = recurse_node(ast.e1, visit_node, visit_type)
      local p1 = ast.e1.op and ast.e1.op.prec or nil
      if ast.op.op == ":" and ast.e1.kind == "string" then
         p1 = -999
      end
      xs[2] = p1 as `T
      if ast.op.arity == 2 then
         if cbs.before_e2 then
            cbs.before_e2(ast, xs)
         end
         if ast.op.op == "is" then
            xs[3] = recurse_type(ast.e2.casttype, visit_type)
         else
            xs[3] = recurse_node(ast.e2, visit_node, visit_type)
         end
         xs[4] = (ast.e2.op and ast.e2.op.prec) as `T
      end
   elseif ast.kind == "newtype" then
      xs[1] = recurse_type(ast.newtype, visit_type)
   elseif ast.kind == "variable"
          or ast.kind == "argument"
          or ast.kind == "identifier"
          or ast.kind == "string"
          or ast.kind == "number"
          or ast.kind == "break"
          or ast.kind == "goto"
          or ast.kind == "label"
          or ast.kind == "nil"
          or ast.kind == "..."
          or ast.kind == "boolean" then
      if ast.decltype then
         xs[1] = recurse_type(ast.decltype, visit_type)
      end
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

local tight_op: {number:{string:boolean}} = {
   [1] = {
      ["-"] = true,
      ["~"] = true,
      ["#"] = true,
   },
   [2] = {
      ["."] = true,
      [":"] = true,
   },
}

local spaced_op: {number:{string:boolean}} = {
   [1] = {
      ["not"] = true,
   },
   [2] = {
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
   },
}

function tl.pretty_print_ast(ast: Node, fast: boolean): string
   local indent = 0

   local Output = record
      {string}
      y: number
      h: number
   end

   local function increment_indent()
      indent = indent + 1
   end

   if fast then
      increment_indent = nil
   end

   local function add(out: Output, s: string)
      table.insert(out, s)
   end

   local function add_string(out: Output, s: string)
      table.insert(out, s)
      if string.find(s, "\n", 1, true) then
         for nl in s:gmatch("\n") do
            out.h = out.h + 1
         end
      end
   end

   local function add_child(out: Output, child: Output, space: string, indent: number): number
      if child.y < out.y then
         out.y = child.y
      end

      if child.y > out.y + out.h then
         local delta = child.y - (out.y + out.h)
         out.h = out.h + delta
         table.insert(out, ("\n"):rep(delta))
      else
         if space then
            table.insert(out, space)
            indent = nil
         end
      end
      if indent and (not fast) then
         table.insert(out, ("   "):rep(indent))
      end
      table.insert(out, child as string)
      out.h = out.h + child.h
   end

   local function concat_output(out: Output): string
      for i, s in ipairs(out) do
         if type(s) == "table" then
            out[i] = concat_output(s as Output)
         end
      end
      return table.concat(out)
   end

   local visit_node: Visitor<NodeKind, Node, Output> = {}

   visit_node.cbs = {
      ["statements"] = {
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            local space: string
            for i, child in ipairs(children) do
               add_child(out, children[i], space, indent)
               space = "; "
            end
            return out
         end
      },
      ["local_declaration"] = {
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "local")
            add_child(out, children[1], " ")
            if children[2] then
               table.insert(out, " =")
               add_child(out, children[2], " ")
            end
            return out
         end,
      },
      ["global_declaration"] = {
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if children[2] then
               add_child(out, children[1], " ")
               table.insert(out, " =")
               add_child(out, children[2], " ")
            end
            return out
         end,
      },
      ["assignment"] = {
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            add_child(out, children[1])
            table.insert(out, " =")
            add_child(out, children[2], " ")
            return out
         end,
      },
      ["if"] = {
         before = increment_indent,
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "if")
            add_child(out, children[1], " ")
            table.insert(out, " then")
            add_child(out, children[2], " ")
            indent = indent - 1
            for i = 3, #children do
               add_child(out, children[i], " ", indent)
            end
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["while"] = {
         before = increment_indent,
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "while")
            add_child(out, children[1], " ")
            table.insert(out, " do")
            add_child(out, children[2], " ")
            indent = indent - 1
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["repeat"] = {
         before = increment_indent,
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "repeat")
            add_child(out, children[1], " ")
            if not fast then
               indent = indent - 1
            end
            add_child(out, { y = node.yend, h = 0, [1] = "until " }, " ", indent)
            add_child(out, children[2])
            return out
         end,
      },
      ["do"] = {
         before = increment_indent,
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "do")
            add_child(out, children[1], " ")
            indent = indent - 1
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["forin"] = {
         before = increment_indent,
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "for")
            add_child(out, children[1], " ")
            table.insert(out, " in")
            add_child(out, children[2], " ")
            table.insert(out, " do")
            add_child(out, children[3], " ")
            indent = indent - 1
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["fornum"] = {
         before = increment_indent,
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "for")
            add_child(out, children[1], " ")
            table.insert(out, " =")
            add_child(out, children[2], " ")
            table.insert(out, ",")
            add_child(out, children[3], " ")
            if children[4] then
               table.insert(out, ",")
               add_child(out, children[4], " ")
            end
            table.insert(out, " do")
            add_child(out, children[5], " ")
            indent = indent - 1
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["return"] = {
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "return")
            if #children[1] > 0 then
               add_child(out, children[1], " ")
            end
            return out
         end,
      },
      ["break"] = {
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "break")
            return out
         end,
      },
      ["elseif"] = {
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "elseif")
            add_child(out, children[1], " ")
            table.insert(out, " then")
            add_child(out, children[2], " ")
            return out
         end,
      },
      ["else"] = {
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "else")
            add_child(out, children[1], " ")
            return out
         end,
      },
      ["variables"] = {
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            local space: string
            for i, child in ipairs(children) do
               if i > 1 then
                  table.insert(out, ",")
                  space = " "
               end
               add_child(out, child, space)
            end
            return out
         end,
      },
      ["table_literal"] = {
         before = increment_indent,
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if #children == 0 then
               indent = indent - 1
               table.insert(out, "{}")
               return out
            end
            table.insert(out, "{")
            for i, child in ipairs(children) do
               add_child(out, child, " ", child.y ~= node.y and indent)
               table.insert(out, ",")
            end
            indent = indent - 1
            add_child(out, { y = node.yend, h = 0, [1] = "}" }, " ", indent)
            return out
         end,
      },
      ["table_item"] = {
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "[")
            add_child(out, children[1])
            table.insert(out, "] = ")
            add_child(out, children[2])
            return out
         end,
      },
      ["local_function"] = {
         before = increment_indent,
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "local function")
            add_child(out, children[1], " ")
            table.insert(out, "(")
            add_child(out, children[2])
            table.insert(out, ")")
            add_child(out, children[4], " ")
            indent = indent - 1
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["global_function"] = {
         before = increment_indent,
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "function")
            add_child(out, children[1], " ")
            table.insert(out, "(")
            add_child(out, children[2])
            table.insert(out, ")")
            add_child(out, children[4], " ")
            indent = indent - 1
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["record_function"] = {
         before = increment_indent,
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "function")
            add_child(out, children[1], " ")
            table.insert(out, node.is_method and ":" or ".")
            add_child(out, children[2])
            table.insert(out, "(")
            if node.is_method then
               -- remove self
               table.remove(children[3], 1)
               if children[3][1] == "," then
                  table.remove(children[3], 1)
                  table.remove(children[3], 1)
               end
            end
            add_child(out, children[3])
            table.insert(out, ")")
            add_child(out, children[5], " ")
            indent = indent - 1
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["function"] = {
         before = increment_indent,
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "function(")
            add_child(out, children[1])
            table.insert(out, ")")
            add_child(out, children[3], " ")
            indent = indent - 1
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["cast"] = {
      },
      ["paren"] = {
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "(")
            add_child(out, children[1], "", indent)
            table.insert(out, ")")
            return out
         end,
      },
      ["op"] = {
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if node.op.op == "@funcall" then
               add_child(out, children[1], "", indent)
               table.insert(out, "(")
               add_child(out, children[3], "", indent)
               table.insert(out, ")")
            elseif node.op.op == "@index" then
               add_child(out, children[1], "", indent)
               table.insert(out, "[")
               add_child(out, children[3], "", indent)
               table.insert(out, "]")
            elseif node.op.op == "as" then
               add_child(out, children[1], "", indent)
            elseif node.op.op == "is" then
               table.insert(out, "type(")
               add_child(out, children[1], "", indent)
               table.insert(out, ") == \"")
               add_child(out, children[3], "", indent) -- FIXME table types should be "table"
               table.insert(out, "\"")
            elseif spaced_op[node.op.arity][node.op.op] or tight_op[node.op.arity][node.op.op] then
               local space = spaced_op[node.op.arity][node.op.op] and " " or ""
               if children[2] and node.op.prec > tonumber(children[2]) then
                  table.insert(children[1], 1, "(")
                  table.insert(children[1], ")")
               end
               if node.op.arity == 1 then
                  table.insert(out, node.op.op)
                  add_child(out, children[1], space, indent)
               elseif node.op.arity == 2 then
                  add_child(out, children[1], "", indent)
                  if space == " " then
                     table.insert(out, " ")
                  end
                  table.insert(out, node.op.op)
                  if children[4] and node.op.prec > tonumber(children[4]) then
                     table.insert(children[3], 1, "(")
                     table.insert(children[3], ")")
                  end
                  add_child(out, children[3], space, indent)
               end
            else
               error("unknown node op " .. node.op.op)
            end
            return out
         end,
      },
      ["variable"] = {
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            add_string(out, node.tk)
            return out
         end,
      },
      ["newtype"] = {
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "{}")
            return out
         end,
      },
      ["goto"] = {
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "goto ")
            table.insert(out, node.label)
            return out
         end,
      },
      ["label"] = {
         after = function(node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "::")
            table.insert(out, node.label)
            table.insert(out, "::")
            return out
         end,
      },
   }

   local primitive: {TypeName:string} = {
      ["function"] = "function",
      ["enum"] = "string",
      ["boolean"] = "boolean",
      ["string"] = "string",
      ["nil"] = "nil",
      ["number"] = "number",
   }

   local visit_type: Visitor<TypeName, Type, Output> = {}
   visit_type.cbs = {
      ["string"] = {
         after = function(typ: Type, children: {Output}): Output
            local out: Output = { y = typ.y, h = 0 }
            table.insert(out, primitive[typ.typename] or "table")
            return out
         end,
      },
   }
   visit_type.cbs["typetype"] = visit_type.cbs["string"]
   visit_type.cbs["typevar"] = visit_type.cbs["string"]
   visit_type.cbs["typearg"] = visit_type.cbs["string"]
   visit_type.cbs["function"] = visit_type.cbs["string"]
   visit_type.cbs["array"] = visit_type.cbs["string"]
   visit_type.cbs["map"] = visit_type.cbs["string"]
   visit_type.cbs["arrayrecord"] = visit_type.cbs["string"]
   visit_type.cbs["record"] = visit_type.cbs["string"]
   visit_type.cbs["enum"] = visit_type.cbs["string"]
   visit_type.cbs["boolean"] = visit_type.cbs["string"]
   visit_type.cbs["nil"] = visit_type.cbs["string"]
   visit_type.cbs["number"] = visit_type.cbs["string"]
   visit_type.cbs["union"] = visit_type.cbs["string"]
   visit_type.cbs["nominal"] = visit_type.cbs["string"]
   visit_type.cbs["bad_nominal"] = visit_type.cbs["string"]
   visit_type.cbs["emptytable"] = visit_type.cbs["string"]
   visit_type.cbs["table_item"] = visit_type.cbs["string"]
   visit_type.cbs["unknown_emptytable_value"] = visit_type.cbs["string"]
   visit_type.cbs["tuple"] = visit_type.cbs["string"]
   visit_type.cbs["poly"] = visit_type.cbs["string"]
   visit_type.cbs["any"] = visit_type.cbs["string"]
   visit_type.cbs["unknown"] = visit_type.cbs["string"]
   visit_type.cbs["invalid"] = visit_type.cbs["string"]
   visit_type.cbs["unresolved_labels"] = visit_type.cbs["string"]
   visit_type.cbs["none"] = visit_type.cbs["string"]

   visit_node.cbs["values"] = visit_node.cbs["variables"]
   visit_node.cbs["expression_list"] = visit_node.cbs["variables"]
   visit_node.cbs["argument_list"] = visit_node.cbs["variables"]
   visit_node.cbs["identifier"] = visit_node.cbs["variable"]
   visit_node.cbs["string"] = visit_node.cbs["variable"]
   visit_node.cbs["number"] = visit_node.cbs["variable"]
   visit_node.cbs["nil"] = visit_node.cbs["variable"]
   visit_node.cbs["boolean"] = visit_node.cbs["variable"]
   visit_node.cbs["..."] = visit_node.cbs["variable"]
   visit_node.cbs["argument"] = visit_node.cbs["variable"]

   local out = recurse_node(ast, visit_node, visit_type)
   return concat_output(out)
end

--------------------------------------------------------------------------------
-- Type check
--------------------------------------------------------------------------------

local ANY = a_type { typename = "any" }
local NONE = a_type { typename = "none" }

local NIL = a_type { typename = "nil" }
local NUMBER = a_type { typename = "number" }
local STRING = a_type { typename = "string" }
local OPT_NUMBER = a_type { typename = "number" }
local OPT_STRING = a_type { typename = "string" }
local VARARG_ANY = a_type { typename = "any", is_va = true }
local VARARG_STRING = a_type { typename = "string", is_va = true }
local VARARG_NUMBER = a_type { typename = "number", is_va = true }
local VARARG_UNKNOWN = a_type { typename = "unknown", is_va = true }
local BOOLEAN = a_type { typename = "boolean" }
local ARG_ALPHA = a_type { typename = "typearg", typearg = "`a" }
local ARG_BETA = a_type { typename = "typearg", typearg = "`b" }
local ALPHA = a_type { typename = "typevar", typevar = "`a" }
local BETA = a_type { typename = "typevar", typevar = "`b" }
local ARRAY_OF_ANY = a_type { typename = "array", elements = ANY }
local ARRAY_OF_STRING = a_type { typename = "array", elements = STRING }
local ARRAY_OF_ALPHA = a_type { typename = "array", elements = ALPHA }
local MAP_OF_ALPHA_TO_BETA = a_type { typename = "map", keys = ALPHA, values = BETA }
local TABLE = a_type { typename = "map", keys = ANY, values = ANY }
local FUNCTION = a_type { typename = "function", args = { a_type { typename = "any", is_va = true } }, rets = { a_type { typename = "any", is_va = true } } }
local INVALID = a_type { typename = "invalid" }
local UNKNOWN = a_type { typename = "unknown" }
local NOMINAL_FILE = a_type { typename = "nominal", names = {"FILE"} }
local METATABLE = a_type { typename = "nominal", names = {"METATABLE"} }

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
      ["emptytable"] = BOOLEAN,
      ["arrayrecord"] = BOOLEAN,
      ["record"] = BOOLEAN,
      ["nil"] = BOOLEAN,
   },
   ["array"] = {
      ["emptytable"] = BOOLEAN,
      ["arrayrecord"] = BOOLEAN,
      ["array"] = BOOLEAN,
      ["nil"] = BOOLEAN,
   },
   ["arrayrecord"] = {
      ["emptytable"] = BOOLEAN,
      ["arrayrecord"] = BOOLEAN,
      ["record"] = BOOLEAN,
      ["array"] = BOOLEAN,
      ["nil"] = BOOLEAN,
   },
   ["map"] = {
      ["emptytable"] = BOOLEAN,
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
      ["emptytable"] = NUMBER,
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
      ["emptytable"] = BOOLEAN,
   },
}

local binop_types: {string:{TypeName:{TypeName:Type}}} = {
   ["+"] = numeric_binop,
   ["-"] = {
      ["number"] = {
         ["number"] = NUMBER,
      }
   },
   ["*"] = numeric_binop,
   ["%"] = numeric_binop,
   ["/"] = numeric_binop,
   ["^"] = numeric_binop,
   ["&"] = numeric_binop,
   ["|"] = numeric_binop,
   ["<<"] = numeric_binop,
   [">>"] = numeric_binop,
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
         ["enum"] = STRING,
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
      ["enum"] = {
         ["string"] = STRING,
      },
   },
   [".."] = {
      ["string"] = {
         ["string"] = STRING,
         ["enum"] = STRING,
         ["number"] = STRING,
      },
      ["number"] = {
         ["number"] = STRING,
         ["string"] = STRING,
         ["enum"] = STRING,
      },
      ["enum"] = {
         ["number"] = STRING,
         ["string"] = STRING,
         ["enum"] = STRING,
      }
   },
}

local show_type: function(Type): string

local function is_unknown(t: Type): boolean
   return t.typename == "unknown"
       or t.typename == "unknown_emptytable_value"
end

local show_type: function(Type, {Type:boolean}): string

local function show_type_base(t: Type, seen: {Type:boolean}): string
   -- FIXME this is a control for recursively built types, which should in principle not exist
   if seen[t] then
      return "..."
   end
   seen[t] = true

   local function show(t: Type): string
      return show_type(t, seen)
   end

   if t.typename == "nominal" then
      if t.typevals then
         local out = { table.concat(t.names, "."), "<" }
         local vals: {string} = {}
         for _, v in ipairs(t.typevals) do
            table.insert(vals, show(v))
         end
         table.insert(out, table.concat(vals, ", "))
         table.insert(out, ">")
         return table.concat(out)
      else
         return table.concat(t.names, ".")
      end
   elseif t.typename == "tuple" then
      local out: {string} = {}
      for _, v in ipairs(t) do
         table.insert(out, show(v))
      end
      return "(" .. table.concat(out, ", ") .. ")"
   elseif t.typename == "poly" then
      local out: {string} = {}
      for _, v in ipairs(t.types) do
         table.insert(out, show(v))
      end
      return table.concat(out, " or ")
   elseif t.typename == "union" then
      local out: {string} = {}
      for _, v in ipairs(t.types) do
         table.insert(out, show(v))
      end
      return table.concat(out, " | ")
   elseif t.typename == "emptytable" then
      return "{}"
   elseif t.typename == "map" then
      return "{" .. show(t.keys) .. " : " .. show(t.values) .. "}"
   elseif t.typename == "array" then
      return "{" .. show(t.elements) .. "}"
   elseif t.typename == "enum" then
      return t.names and table.concat(t.names, ".") or "enum"
   elseif t.typename == "record" then
      local out: {string} = {}
      for _, k in ipairs(t.field_order) do
         local v = t.fields[k]
         table.insert(out, k .. ": " .. show(v))
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
            table.insert(args, show(v))
         end
      end
      table.insert(out, table.concat(args, ","))
      table.insert(out, ")")
      if #t.rets > 0 then
         table.insert(out, ":")
         local rets = {}
         for _, v in ipairs(t.rets) do
            table.insert(rets, show(v))
         end
         table.insert(out, table.concat(rets, ","))
      end
      return table.concat(out)
   elseif t.typename == "number"
       or t.typename == "boolean" then
      return t.typename
   elseif t.typename == "string" then
      return t.typename ..
             (t.tk and " " .. t.tk or "")
   elseif t.typename == "typevar" then
      return t.typevar
   elseif t.typename == "typearg" then
      return t.typearg
   elseif is_unknown(t) then
      return "<unknown type>"
   elseif t.typename == "invalid" then
      return "<invalid type>"
   elseif t.typename == "any" then
      return "<any type>"
   elseif t.typename == "nil" then
      return "nil"
   elseif t.typename == "typetype" then
      return "type " .. show(t.def)
   elseif t.typename == "bad_nominal" then
      return table.concat(t.names, ".") .. " (an unknown type)"
   else
      return inspect(t)
   end
end

show_type = function(t: Type, seen: {Type:boolean}): string
   local ret = show_type_base(t, seen or {})
   if t.inferred_at then
      ret = ret .. " (inferred at "..t.inferred_at_file..":"..t.inferred_at.y..":"..t.inferred_at.x..": )"
   end
   return ret
end

local Error = record
   y: number
   x: number
   msg: string
   filename: string
end

local Result = record
   ast: Node
   type: Type
   syntax_errors: {ParseError}
   type_errors: {Error}
   unknowns: {Error}
   env: Env
end

local function search_for(module_name: string, suffix: string, path: string, tried: {string}): string, FILE, {string}
   for entry in path:gmatch("[^;]+") do
      local slash_name = module_name:gsub("%.", "/")
      local filename = entry:gsub("?", slash_name)
      local tl_filename = filename:gsub("%.lua$", suffix)
      local fd = io.open(tl_filename, "r")
      if fd then
         return tl_filename, fd, tried
      end
      table.insert(tried, "no file '" .. tl_filename .. "'")
   end
   return nil, nil, tried
end

function tl.search_module(module_name: string, search_dtl: boolean): string, FILE, {string}
   local found: string
   local tried: {string} = {}
   local path = os.getenv("TL_PATH") or package.path
   if search_dtl then
      local found, fd, tried = search_for(module_name, ".d.tl", path, tried)
      if found then
         return found, fd
      end
   end
   local found, fd, tried = search_for(module_name, ".tl", path, tried)
   if found then
      return found, fd
   end
   local found, fd, tried = search_for(module_name, ".lua", path, tried)
   if found then
      return found, fd
   end
   return nil, nil, tried
end

local Variable = record
   t: Type
   is_const: boolean
   needs_compat53: boolean
   narrowed_from: Type
   is_narrowed: boolean
end

local function fill_field_order(t: Type)
   if t.typename == "record" then
      t.field_order = {}
      for k, v in pairs(t.fields) do
         table.insert(t.field_order, k)
      end
      table.sort(t.field_order)
   end
end

local function require_module(module_name: string, lax: boolean, env: Env, result: Result): Type
   local modules = env.modules

   if modules[module_name] then
      return modules[module_name]
   end
   modules[module_name] = UNKNOWN

   local found, fd, tried = tl.search_module(module_name, true)
   if found and (lax or found:match("tl$") as boolean) then
      fd:close()
      local _result, err: Result, string = tl.process(found, env, result)
      assert(_result, err)

      if not _result.type then
         _result.type = BOOLEAN
      end

      modules[module_name] = _result.type

      return _result.type
   end

   return UNKNOWN
end

local standard_library: {string:Type} = {
   ["..."] = a_type { typename = "tuple", STRING, STRING, STRING, STRING, STRING },
   ["@return"] = a_type { typename = "tuple", ANY },
   ["any"] = a_type { typename = "typetype", def = ANY },
   ["arg"] = ARRAY_OF_STRING,
   ["require"] = a_type { typename = "function", args = { STRING }, rets = {} },
   ["setmetatable"] = a_type { typeargs = { ARG_ALPHA }, typename = "function", args = { ALPHA, METATABLE }, rets = { ALPHA } },
   ["getmetatable"] = a_type { typename = "function", args = { ANY }, rets = { METATABLE } },
   ["rawget"] = a_type { typename = "function", args = { TABLE, ANY }, rets = { ANY } },
   ["rawset"] = a_type {
      typename = "poly",
      types = {
         a_type { typeargs = { ARG_ALPHA, ARG_BETA }, typename = "function", args = { MAP_OF_ALPHA_TO_BETA, ALPHA, BETA }, rets = {} },
         a_type { typeargs = { ARG_ALPHA }, typename = "function", args = { ARRAY_OF_ALPHA, NUMBER, ALPHA }, rets = {} },
         a_type { typename = "function", args = { TABLE, ANY, ANY }, rets = {} },
      }
   },
   ["next"] = a_type {
      typename = "poly",
      types = {
         a_type { typeargs = { ARG_ALPHA, ARG_BETA }, typename = "function", args = { MAP_OF_ALPHA_TO_BETA }, rets = { ALPHA, BETA } },
         a_type { typeargs = { ARG_ALPHA, ARG_BETA }, typename = "function", args = { MAP_OF_ALPHA_TO_BETA, ALPHA }, rets = { ALPHA, BETA } },
         a_type { typeargs = { ARG_ALPHA }, typename = "function", args = { ARRAY_OF_ALPHA }, rets = { NUMBER, ALPHA } },
         a_type { typeargs = { ARG_ALPHA }, typename = "function", args = { ARRAY_OF_ALPHA, ALPHA }, rets = { NUMBER, ALPHA } },
      },
   },
   ["load"] = a_type {
      typename = "poly",
      types = {
         a_type { typename = "function", args = { STRING }, rets = { FUNCTION } },
         a_type { typename = "function", args = { STRING, STRING }, rets = { FUNCTION } },
      },
   },
   ["FILE"] = a_type {
      typename = "typetype",
      def = a_type {
         typename = "record",
         fields = {
            ["read"] = a_type {
               typename = "poly",
               types = {
                  a_type { typename = "function", args = { NOMINAL_FILE, STRING }, rets = { STRING, STRING } },
                  a_type { typename = "function", args = { NOMINAL_FILE, NUMBER }, rets = { STRING, STRING } },
               }
            },
            ["write"] = a_type { typename = "function", args = { NOMINAL_FILE, VARARG_STRING }, rets = { NOMINAL_FILE, STRING } },
            ["close"] = a_type { typename = "function", args = { NOMINAL_FILE }, rets = { BOOLEAN, STRING} },
            ["flush"] = a_type { typename = "function", args = { NOMINAL_FILE }, rets = {} },
            -- TODO complete...
         },
      },
   },
   ["METATABLE"] = a_type {
      typename = "typetype",
      def = a_type {
         typename = "record",
         fields = {
            ["__index"] = ANY, -- FIXME
            ["__newindex"] = ANY, -- FIXME
            ["__tostring"] = a_type { typename = "function", args = { ANY }, rets = { STRING } },
            ["__mode"] = a_type { typename = "enum", enumset = { ["k"] = true, ["v"] = true, ["kv"] = true, } },
            ["__call"] = FUNCTION,
            ["__gc"] = a_type { typename = "function", args = { ANY }, rets = {} },
            ["__len"] = a_type { typename = "function", args = { ANY }, rets = { NUMBER } },
            ["__pairs"] = a_type { typeargs = { ARG_ALPHA, ARG_BETA }, typename = "function", args = { a_type { typename = "map", keys = ALPHA, values = BETA } }, rets = {
                  a_type { typename = "function", args = {}, rets = { ALPHA, BETA } },
            } },
            -- TODO complete...
         },
      },
   },
   ["io"] = a_type {
      typename = "record",
      fields = {
         ["stderr"] = NOMINAL_FILE,
         ["stdout"] = NOMINAL_FILE,
         ["open"] = a_type { typename = "function", args = { STRING, STRING }, rets = { NOMINAL_FILE, STRING } },
         ["popen"] = a_type { typename = "function", args = { STRING, STRING }, rets = { NOMINAL_FILE, STRING } },
         ["write"] = a_type { typename = "function", args = { VARARG_STRING }, rets = { NOMINAL_FILE, STRING } },
         ["flush"] = a_type { typename = "function", args = {}, rets = {} },
         ["type"] = a_type { typename = "function", args = { ANY }, rets = { STRING } },
      },
   },
   ["os"] = a_type {
      typename = "record",
      fields = {
         ["getenv"] = a_type { typename = "function", args = { STRING }, rets = { STRING } },
         ["execute"] = a_type { typename = "function", args = { STRING }, rets = { BOOLEAN, STRING, NUMBER } },
         ["remove"] = a_type { typename = "function", args = { STRING }, rets = { BOOLEAN, STRING } },
         ["time"] = a_type { typename = "function", args = {}, rets = { NUMBER } }, -- TODO table argument
         ["tmpname"] = a_type { typename = "function", args = {}, rets = { STRING } },
         ["clock"] = a_type { typename = "function", args = {}, rets = { NUMBER } },
         ["exit"] = a_type {
            typename = "poly",
            types = {
               a_type { typename = "function", args = { NUMBER, BOOLEAN }, rets = {} },
               a_type { typename = "function", args = { BOOLEAN, BOOLEAN }, rets = {} },
            }
         },
      },
   },
   ["package"] = a_type {
      typename = "record",
      fields = {
         ["path"] = STRING,
         ["config"] = STRING,
         ["loaded"] = a_type {
            typename = "map",
            keys = STRING,
            values = ANY,
         },
         ["searchers"] = a_type {
            typename = "array",
            elements = a_type { typename = "function", args = { STRING }, rets = { ANY } }
         },
         ["loaders"] = a_type {
            typename = "array",
            elements = a_type { typename = "function", args = { STRING }, rets = { ANY } }
         },
      },
   },
   ["table"] = a_type {
      typename = "record",
      fields = {
         ["pack"] = a_type { typename = "function", args = { VARARG_ANY }, rets = { TABLE } },
         ["unpack"] = a_type {
            typename = "function",
            needs_compat53 = true,
            typeargs = { ARG_ALPHA },
            args = { ARRAY_OF_ALPHA, NUMBER, NUMBER },
            rets = { a_type { typename = "typevar", typevar = "`a", is_va = true }
         } },
         ["move"] = a_type {
            typename = "poly",
            types = {
               a_type { typename = "function", typeargs = { ARG_ALPHA }, args = { ARRAY_OF_ALPHA, NUMBER, NUMBER, NUMBER }, rets = { ARRAY_OF_ALPHA } },
               a_type { typename = "function", typeargs = { ARG_ALPHA }, args = { ARRAY_OF_ALPHA, NUMBER, NUMBER, NUMBER, ARRAY_OF_ALPHA }, rets = { ARRAY_OF_ALPHA } },
            }
         },
         ["insert"] = a_type {
            typename = "poly",
            types = {
               a_type { typename = "function", typeargs = { ARG_ALPHA }, args = { ARRAY_OF_ALPHA, NUMBER, ALPHA }, rets = {} },
               a_type { typename = "function", typeargs = { ARG_ALPHA }, args = { ARRAY_OF_ALPHA, ALPHA }, rets = {} },
            }
         },
         ["remove"] = a_type { typename = "function", typeargs = { ARG_ALPHA }, args = { ARRAY_OF_ALPHA, OPT_NUMBER }, rets = { ALPHA } },
         ["concat"] = a_type { typename = "function", args = { ARRAY_OF_STRING, OPT_STRING, OPT_NUMBER, OPT_NUMBER }, rets = { STRING } },
         ["sort"] = a_type {
            typename = "poly",
            types = {
               a_type { typename = "function", typeargs = { ARG_ALPHA }, args = { ARRAY_OF_ALPHA }, rets = {} },
               a_type { typename = "function", typeargs = { ARG_ALPHA }, args = { ARRAY_OF_ALPHA, a_type { typename = "function", args = { ALPHA, ALPHA }, rets = { BOOLEAN } } }, rets = {} },
            }
         }
      },
   },
   ["string"] = a_type {
      typename = "record",
      fields = {
         ["sub"] = a_type { typename = "function", args = { STRING, NUMBER, NUMBER }, rets = { STRING } },
         ["match"] = a_type { typename = "function", args = { STRING, STRING, NUMBER }, rets = { VARARG_STRING } },
         ["rep"] = a_type { typename = "function", args = { STRING, NUMBER }, rets = { STRING } },
         ["lower"] = a_type { typename = "function", args = { STRING }, rets = { STRING } },
         ["upper"] = a_type { typename = "function", args = { STRING }, rets = { STRING } },
         ["gsub"] = a_type {
            typename = "poly",
            types = {
               a_type { typename = "function", args = { STRING, STRING, STRING, NUMBER }, rets = { STRING, NUMBER } },
               a_type { typename = "function", args = { STRING, STRING, a_type { typename = "map", keys = STRING, values = STRING }, NUMBER }, rets = { STRING, NUMBER } },
               a_type { typename = "function", args = { STRING, STRING, a_type { typename = "function", args = { VARARG_STRING }, rets = { STRING } } }, rets = { STRING, NUMBER } },
               -- FIXME any other modes
            }
         },
         ["gmatch"] = a_type { typename = "function", args = { STRING, STRING }, rets = {
            a_type { typename = "function", args = {}, rets = { STRING } },
         } },
         ["find"] = a_type {
            typename = "poly",
            types = {
               a_type { typename = "function", args = { STRING, STRING }, rets = { NUMBER, NUMBER, VARARG_STRING } },
               a_type { typename = "function", args = { STRING, STRING, NUMBER }, rets = { NUMBER, NUMBER, VARARG_STRING } },
               a_type { typename = "function", args = { STRING, STRING, NUMBER, BOOLEAN }, rets = { NUMBER, NUMBER, VARARG_STRING } },
               -- FIXME any other modes
            }
         },
         ["char"] = a_type { typename = "function", args = { VARARG_NUMBER }, rets = { STRING } },
         ["byte"] = a_type {
            typename = "poly",
            types = {
               a_type { typename = "function", args = { STRING }, rets = { NUMBER } },
               a_type { typename = "function", args = { STRING, NUMBER }, rets = { NUMBER } },
               a_type { typename = "function", args = { STRING, NUMBER, NUMBER }, rets = { VARARG_NUMBER } },
            }
         },
         ["format"] = a_type { typename = "function", args = { STRING, VARARG_ANY }, rets = { STRING } },
      },
   },
   ["math"] = a_type {
      typename = "record",
      fields = {
         ["max"] = a_type { typename = "function", args = { NUMBER, NUMBER }, rets = { NUMBER } },
         ["min"] = a_type { typename = "function", args = { NUMBER, NUMBER }, rets = { NUMBER } },
         ["floor"] = a_type { typename = "function", args = { NUMBER }, rets = { NUMBER } },
         ["randomseed"] = a_type { typename = "function", args = { NUMBER }, rets = {} },
         ["random"] = a_type { typename = "function", args = { NUMBER, NUMBER }, rets = { NUMBER } },
         ["huge"] = NUMBER,
      },
   },
   ["type"] = a_type { typename = "function", args = { ANY }, rets = { STRING } },
   ["utf8"] = a_type {
      typename = "record",
      fields = {
         ["len"] = a_type { typename = "function", args = { STRING, NUMBER, NUMBER }, rets = { NUMBER } },
         ["offset"] = a_type { typename = "function", args = { STRING, NUMBER, NUMBER }, rets = { NUMBER } },
      },
   },
   ["ipairs"] = a_type { typename = "function", typeargs = { ARG_ALPHA }, args = { ARRAY_OF_ALPHA }, rets = {
      a_type { typename = "function", args = {}, rets = { NUMBER, ALPHA } },
   } },
   ["pairs"] = a_type { typename = "function", typeargs = { ARG_ALPHA, ARG_BETA }, args = { a_type { typename = "map", keys = ALPHA, values = BETA } }, rets = {
      a_type { typename = "function", args = {}, rets = { ALPHA, BETA } },
   } },
   ["pcall"] = a_type { typename = "function", args = { VARARG_ANY }, rets = { BOOLEAN, ANY } },
   ["assert"] = a_type {
      typename = "poly",
      types = {
         a_type { typename = "function", typeargs = { ARG_ALPHA }, args = { ALPHA }, rets = { ALPHA } },
         a_type { typename = "function", typeargs = { ARG_ALPHA, ARG_BETA }, args = { ALPHA, BETA }, rets = { ALPHA } },
      }
   },
   ["select"] = a_type {
      typename = "poly",
      types = {
         a_type { typename = "function", typeargs = { ARG_ALPHA }, args = { NUMBER, ALPHA }, rets = { ALPHA } },
         a_type { typename = "function", args = { STRING, VARARG_ANY }, rets = { NUMBER } },
      }
   },
   ["print"] = a_type { typename = "function", args = { VARARG_ANY }, rets = {} },
   ["tostring"] = a_type { typename = "function", args = { ANY }, rets = { STRING } },
   ["tonumber"] = a_type { typename = "function", args = { ANY, NUMBER }, rets = { NUMBER } },
   ["error"] = a_type { typename = "function", args = { STRING, NUMBER }, rets = {} },
   ["debug"] = a_type {
      typename = "record",
      fields = {
         ["traceback"] = a_type { typename = "function", args = { STRING, NUMBER }, rets = { STRING } },
      },
   }
}

for _, t in pairs(standard_library) do
   fill_field_order(t)
   if t.typename == "typetype" then
      fill_field_order(t.def)
   end
end

local compat53_code_cache: {string:Node} = {}

local function add_compat53_entries(program: Node, used_set: {string: boolean})
   if not next(used_set) then
      return
   end

   local used_list: {string} = {}
   for name, _ in pairs(used_set) do
      table.insert(used_list, name)
   end
   table.sort(used_list)

   for i, name in ipairs(used_list) do
      local mod, fn = name:match("([^.]*)%.(.*)")
      local errs = {}
      local text: string
      local code: Node = compat53_code_cache[name]
      if not code then
         -- TODO generic support for individual functions
         if name == "table.unpack" then
            text = "local _tl_table_unpack = unpack or table.unpack"
         else
            text = ("local $NAME = require('compat53.module').$NAME or $NAME"):gsub("$NAME", name)
         end
         local tokens = tl.lex(text)
         local _: number
         _, code = tl.parse_program(tokens, {}, "@internal")
         tl.type_check(code, { lax = false, skip_compat53 = true })
         code = code[1]
         compat53_code_cache[name] = code
      end
      table.insert(program, i, code)
   end
   program.y = 1
end

local function get_stdlib_compat53(lax: boolean): {string:boolean}
   if lax then
      return {
         ["utf8"] = true,
      }
   else
      return {
         ["io"] = true,
         ["math"] = true,
         ["string"] = true,
         ["table"] = true,
         ["utf8"] = true,
         ["coroutine"] = true,
         ["os"] = true,
         ["package"] = true,
         ["debug"] = true,
         ["load"] = true,
         ["loadfile"] = true,
         ["assert"] = true,
         ["pairs"] = true,
         ["ipairs"] = true,
         ["pcall"] = true,
         ["xpcall"] = true,
         ["rawlen"] = true,
      }
   end
end

local function init_globals(lax: boolean): {string:Variable}
   local globals: {string:Variable} = {}
   local stdlib_compat53 = get_stdlib_compat53(lax)

   for name, typ in pairs(standard_library) do
      globals[name] = { t = typ, needs_compat53 = stdlib_compat53[name], is_const = true }
   end

   return globals
end

function tl.init_env(lax: boolean, skip_compat53: boolean): Env
   return {
      modules = {},
      globals = init_globals(lax),
      skip_compat53 = skip_compat53,
   }
end

function tl.type_check(ast: Node, opts: TypeCheckOptions): {Error}, {Error}, Type
   opts = opts or {}
   opts.env = opts.env or tl.init_env(opts.lax, opts.skip_compat53)
   local lax = opts.lax
   local filename = opts.filename
   local result = opts.result or {
      syntax_errors = {},
      type_errors = {},
      unknowns = {},
   }

   local stdlib_compat53 = get_stdlib_compat53(lax)

   local st: {{string:Variable}} = { opts.env.globals }

   local all_needs_compat53 = {}

   local errors: {Error} = result.type_errors or {}
   local unknowns: {Error} = result.unknowns or {}
   local module_type: Type

   local function find_var(name: string): Type, boolean
      if name == "_G" then
         -- this is a static approximation of _G
         local globals: {string:Type} = {}
         for k, v in pairs(st[1]) do
            globals[k] = v.t
         end
         local field_order: {string} = {}
         for k, _ in pairs(globals) do
            table.insert(field_order, k)
         end
         return a_type {
            typename = "record",
            field_order = field_order,
            fields = globals,
         }, false
      end
      for i = #st, 1, -1 do
         local scope = st[i]
         if scope[name] then
            if i == 1 and scope[name].needs_compat53 then
               all_needs_compat53[name] = true
            end
            local typ = scope[name].t

            return typ, scope[name].is_const
         end
      end
   end

   local function resolve_typevars(t: Type, seen: {Type:Type}): Type
      seen = seen or {}
      if seen[t] then
         return seen[t]
      end

      local orig_t = t
      local clear_tk = false
      if t.typename == "typevar" then
         local tv = find_var(t.typevar)
         if tv then
            t = tv
            clear_tk = true
         else
            t = UNKNOWN
         end
      end

      local copy: Type = {}
      seen[orig_t] = copy

      for k, v in pairs(t as {string:Type}) do
         local cp = copy as {string:Type}
         if type(v) == "table" then
            cp[k] = resolve_typevars(v, seen)
         else
            cp[k] = v
         end
      end

      if clear_tk then
         copy.tk = nil
      end

      return copy
   end

   local function find_type(names: {string}): Type
      local typ = find_var(names[1])
      if not typ then
         return nil
      end
      for i = 2, #names do
         if typ.fields then
            typ = typ.fields[names[i]]
            if typ == nil then
               return nil
            end
         else
            break
         end
      end
      if typ and typ.typename ~= "typetype" then
         return nil
      end
      return typ
   end

   local function infer_var(emptytable: Type, t: Type, node: Node)
      local is_global = (emptytable.declared_at and emptytable.declared_at.kind == "global_declaration")
      local nst = is_global and 1 or #st
      for i = nst, 1, -1 do
         local scope = st[i]
         if scope[emptytable.assigned_to] then
            scope[emptytable.assigned_to] = {
               t = t,
               is_const = false,
            }
            t.inferred_at = node
            t.inferred_at_file = filename
         end
      end
   end

   local function find_global(name: string): Type, boolean
      local scope = st[1]
      if scope[name] then
         return scope[name].t, scope[name].is_const
      end
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

   local function error_in_type(where: Type, msg: string, ...: Type): Error
      local n = select("#", ...)
      if n > 0 then
         local showt = {}
         for i = 1, n do
            local t = select(i, ...)
            if t.typename == "invalid" then
               return nil
            end
            showt[i] = show_type(t)
         end
         msg = msg:format(table.unpack(showt))
      end

      return {
         y = where.y,
         x = where.x,
         msg = msg,
         filename = filename,
      }
   end

   local function type_error(t: Type, msg: string, ...:Type): boolean
      local e = error_in_type(t, msg, ...)
      if e then
         table.insert(errors, e)
         return true
      else
         return false
      end
   end

   local function node_error(node: Node, msg: string, ...:Type): Type
      local ok = type_error(node as Type, msg, ...)
      node.type = INVALID
      return node.type
   end

   local function terr(t: Type, s: string, ...: Type): {Error}
      return { error_in_type(t, s, ...) }
   end

   local function add_unknown(node: Node, name: string)
      table.insert(unknowns, { y = node.y, x = node.x, msg = name, filename = filename })
   end

   local function add_var(node: Node, var: string, valtype: Type, is_const: boolean, is_narrowing: boolean)
      if lax and node and is_unknown(valtype) and (var ~= "self" and var ~= "...") then
         add_unknown(node, var)
      end
      if st[#st][var] and is_narrowing then
         if not st[#st][var].is_narrowed then
            st[#st][var].narrowed_from = st[#st][var].t
         end
         st[#st][var].is_narrowed = true
         st[#st][var].t = valtype
      else
         st[#st][var] = { t = valtype, is_const = is_const, is_narrowed = is_narrowing }
      end
   end

   local CompareTypes = functiontype(Type, Type, boolean): boolean, {Error}

   local function compare_typevars(t1: Type, t2: Type, comp: CompareTypes): boolean, {Error}
      local tv1 = find_var(t1.typevar)
      local tv2 = find_var(t2.typevar)
      if t1.typevar == t2.typevar then
         local has_t1 = not not tv1
         local has_t2 = not not tv2
         if has_t1 == has_t2 then
            return true
         end
      end
      local function cmp(k: string, v: Type, a: Type, b: Type): boolean, {Error}
         if find_var(k) then
            return comp(a, b)
         else
            add_var(nil, k, resolve_typevars(v))
            return true
         end
      end
      if t2.typename == "typevar" then
         return cmp(t2.typevar, t1, t1, tv2)
      else
         return cmp(t1.typevar, t2, tv1, t2)
      end
   end

   local function add_errs_prefixing(src: {Error}, dst: {Error}, prefix: string, node: Node)
      if not src then
         return
      end
      for i, err in ipairs(src) do
         err.msg = prefix .. err.msg
         -- node.y may be nil because of `typ as Node` casts and not all types have .y set
         if node and node.y and (not err.y or (node.y > err.y or (node.y == err.y and node.x > err.x))) then
            err.y = node.y
            err.x = node.x
         end
         table.insert(dst, err)
      end
   end

   local is_a: function(Type, Type, boolean): boolean, {Error}

   local TypeGetter = functiontype(string): Type

   local function match_record_fields(t1: Type, t2: TypeGetter, cmp: CompareTypes): boolean, {Error}
      cmp = cmp or is_a
      local fielderrs: {Error} = {}
      for _, k in ipairs(t1.field_order) do
         local f = t1.fields[k]
         local t2k = t2(k)
         if t2k == nil then
            if not lax then
               table.insert(fielderrs, error_in_type(f, "unknown field " .. k))
            end
         else
            local match, errs = is_a(f, t2k)
            add_errs_prefixing(errs, fielderrs, "record field doesn't match: " .. k .. ": ")
         end
      end
      if #fielderrs > 0 then
         return false, fielderrs
      end
      return true
   end

   local function match_fields_to_record(t1: Type, t2: Type, cmp: CompareTypes): boolean, {Error}
      return match_record_fields(t1, function(k: string): Type return t2.fields[k] end, cmp)
   end

   local function match_fields_to_map(t1: Type, t2: Type): boolean, {Error}
      if not match_record_fields(t1, function(_: string): Type return t2.values end) then
         return false, { error_in_type(t1, "not all fields have type %s", t2.values) }
      end
      return true
   end

   local function arg_check(cmp: CompareTypes, a: Type, b: Type, at: Node, n: number, errs: {Error}): boolean
      local matches, match_errs = cmp(a, b)
      if not matches then
         add_errs_prefixing(match_errs, errs, "argument " .. n .. ": ", at)
         return false
      end
      return true
   end

   -- only check names, not type variables
   local function same_names(t1: Type, t2: Type): boolean
      if t1.resolved and t2.resolved then
         return t1.resolved.typeid == t2.resolved.typeid
      end

      local ft1 = find_type(t1.names)
      local ft2 = find_type(t2.names)
      if ft1 and ft2 then
         return ft1 == ft2
      else
         if not ft1 then
            type_error(t1, "unknown type %s", t1)
         end
         if not ft2 then
            type_error(t2, "unknown type %s", t2)
         end
         return table.concat(t1.names, ".") == table.concat(t2.names, ".")
      end
   end

   local same_type: function(t1: Type, t2: Type): boolean, {Error}

   local function has_all_types_of(t1s: {Type}, t2s: {Type}): boolean
      for _, t1 in ipairs(t1s) do
         local found = false
         for _, t2 in ipairs(t2s) do
            if same_type(t1, t2) then
               found = true
               break
            end
         end
         if not found then
            return false
         end
      end
      return true
   end

   local function any_errors(all_errs: {Error}): boolean, {Error}
      if #all_errs == 0 then
         return true
      else
         return false, all_errs
      end
   end

   same_type = function(t1: Type, t2: Type): boolean, {Error}
      assert(type(t1) == "table")
      assert(type(t2) == "table")

      if t1.typename == "typevar" or t2.typename == "typevar" then
         return compare_typevars(t1, t2, same_type)
      end

      if t1.typename ~= t2.typename then
         return false, terr(t1, "got %s, expected %s", t1, t2)
      end
      if t1.typename == "array" then
         return same_type(t1.elements, t2.elements)
      elseif t1.typename == "map" then
         local all_errs = {}
         local k_ok, k_errs = same_type(t1.keys, t2.keys)
         if not k_ok then
            add_errs_prefixing(k_errs, all_errs, "keys", t1 as Node)
         end
         local v_ok, v_errs = same_type(t1.values, t2.values)
         if not v_ok then
            add_errs_prefixing(v_errs, all_errs, "values", t1 as Node)
         end
         return any_errors(all_errs)
      elseif t1.typename == "union" then
         if  has_all_types_of(t1.types, t2.types)
         and has_all_types_of(t2.types, t1.types) then
            return true
         else
            return false, terr(t1, "got %s, expected %s", t1, t2)
         end
      elseif t1.typename == "nominal" then
         return same_names(t1, t2)
      elseif t1.typename == "record" then
         return match_fields_to_record(t1, t2, same_type)
      elseif t1.typename == "function" then
         if #t1.args ~= #t2.args then
            return false, terr(t1, "different number of input arguments: got " .. #t1.args .. ", expected " .. #t2.args)
         end
         if #t1.rets ~= #t2.rets then
            return false, terr(t1, "different number of return values: got " .. #t1.args .. ", expected " .. #t2.args)
         end
         local all_errs = {}
         for i = 1, #t1.args do
            arg_check(same_type, t1.args[i], t2.args[i], t1 as Node, i, all_errs)
         end
         for i = 1, #t1.rets do
            local ok, errs = same_type(t1.rets[i], t2.rets[i])
            add_errs_prefixing(errs, all_errs, "return " .. i, t1 as Node)
         end
         return any_errors(all_errs)
      elseif t1.typename == "arrayrecord" then
         local ok, errs = same_type(t1.elements, t2.elements)
         if not ok then
            return ok, errs
         end
         return match_fields_to_record(t1, t2, same_type)
      end
      return true
   end

   local function is_vararg(t: Type): boolean
      return t.args and #t.args > 0 and t.args[#t.args].is_va
   end

   local function combine_errs(...: {Error}): boolean, {Error}
      local errs: {Error}
      for i = 1, select("#", ...) do
         local e = select(i, ...)
         if e then
            errs = errs or {}
            for _, err in ipairs(e) do
               table.insert(errs, err)
            end
         end
      end
      if not errs then
         return true
      else
         return false, errs
      end
   end

   local resolve_unary: function(t: Type): Type = nil

   is_a = function(t1: Type, t2: Type, for_equality: boolean): boolean, {Error}
      assert(type(t1) == "table")
      assert(type(t2) == "table")

      if lax and (is_unknown(t1) or is_unknown(t2)) then
         return true
      end

      if t1.typename == "nil" then -- TODO nilable
         return true
      end

      if t2.typename ~= "tuple" then
         t1 = resolve_tuple(t1)
      end
      if t2.typename == "tuple" and t1.typename ~= "tuple" then
         t1 = a_type {
            typename = "tuple",
            [1] = t1,
         }
      end

      if t1.typename == "typevar" or t2.typename == "typevar" then
         return compare_typevars(t1, t2, is_a)
      end

      if t2.typename == "any" then
         return true
      elseif t2.typename == "poly" then
         for _, t in ipairs(t2.types) do
            if is_a(t1, t, for_equality) then
               return true
            end
         end
         return false, terr(t1, "cannot match against any alternatives of the polymorphic type")
      elseif t1.typename == "union" and t2.typename == "union" then
         if has_all_types_of(t1.types, t2.types) then
            return true
         else
            return false, terr(t1, "got %s, expected %s", t1, t2)
         end
      elseif t2.typename == "union" then
         for _, t in ipairs(t2.types) do
            if is_a(t1, t, for_equality) then
               return true
            end
         end
      elseif t1.typename == "poly" then
         for _, t in ipairs(t1.types) do
            if is_a(t, t2, for_equality) then
               return true
            end
         end
         return false, terr(t1, "cannot match against any alternatives of the polymorphic type")
      elseif t1.typename == "nominal" and t2.typename == "nominal" and #t2.names == 1 and t2.names[1] == "any" then
         return true
      elseif t1.typename == "nominal" and t2.typename == "nominal" then
         if same_names(t1, t2) then
            if t1.typevals == nil and t2.typevals == nil then
               return true
            elseif t1.typevals and t2.typevals and #t1.typevals == #t2.typevals then
               local all_errs = {}
               for i = 1, #t1.typevals do
                  local ok, errs = same_type(t2.typevals[i], t1.typevals[i])
                  add_errs_prefixing(errs, all_errs, "type parameter <" .. show_type(t1.typevals[i]) .. ">: ", t1 as Node)
               end
               if #all_errs == 0 then
                  return true
               else
                  return false, all_errs
               end
            end
         end
         return false, terr(t1, "%s is not a %s", t1, t2)
      elseif t1.typename == "enum" and t2.typename == "string" then
         local ok: boolean
         if for_equality then
            ok = t2.tk and t1.enumset[unquote(t2.tk)]
         else
            ok = true
         end
         if ok then
            return true
         else
            return false, terr(t1, "enum is incompatible with %s", t2)
         end
      elseif t1.typename == "string" and t2.typename == "enum" then
         local ok = t1.tk and t2.enumset[unquote(t1.tk)]
         if ok then
            return true
         else
            if t1.tk then
               return false, terr(t1, "%s is not a member of %s", t1, t2)
            else
               return false, terr(t1, "string is not a %s", t2)
            end
         end
      elseif t1.typename == "nominal" or t2.typename == "nominal" then
         local t1u = resolve_unary(t1)
         local t2u = resolve_unary(t2)
         local ok, errs = is_a(t1u, t2u, for_equality)
         if errs and #errs == 1 then
            if errs[1].msg:match("^got ") then
               --local got = t1.typename == "nominal" and t1.name or show_type(t1)
               --local expected = t2.typename == "nominal" and t2.name or show_type(t2)
               errs = terr(t1, "got %s, expected %s", t1, t2)
            end
         end
         return ok, errs
      elseif t1.typename == "emptytable" and (t2.typename == "array" or t2.typename == "map" or t2.typename == "record" or t2.typename == "arrayrecord") then
         return true
      elseif t2.typename == "array" then
         if t1.typename == "array" or t1.typename == "arrayrecord" then
            return is_a(t1.elements, t2.elements)
         elseif t1.typename == "map" then
            local _, errs_keys = is_a(t1.keys, NUMBER)
            local _, errs_values = is_a(t1.values, t2.elements)
            return combine_errs(errs_keys, errs_values)
         end
      elseif t2.typename == "record" then
         if t1.typename == "record" or t1.typename == "arrayrecord" then
            return match_fields_to_record(t1, t2)
         elseif t1.typename == "map" then
            if not is_a(t1.keys, STRING) then
               return false, terr(t1, "map has non-string keys")
            end
            for _, fname in ipairs(t2.field_order) do
               local ftype = t2.fields[fname]
               if not is_a(t1.values, ftype) then
                  return false, terr(t1, "field " .. fname .. " is of type %s", ftype)
               end
            end
            return true
         end
      elseif t2.typename == "arrayrecord" then
         if t1.typename == "array" then
            return is_a(t1.elements, t2.elements)
         elseif t1.typename == "record" then
            return match_fields_to_record(t1, t2)
         elseif t1.typename == "arrayrecord" then
            if not is_a(t1.elements, t2.elements) then
               return false, terr(t1, "array parts have incompatible element types")
            end
            return match_fields_to_record(t1, t2)
         end
      elseif t2.typename == "map" then
         if t1.typename == "map" then
            local _, errs_keys = is_a(t1.keys, t2.keys)
            local _, errs_values = is_a(t2.values, t1.values)
            if t2.values.typename == "any" then -- special-case hack for {any:any}
               errs_values = {}
            end
            return combine_errs(errs_keys, errs_values)
         elseif t1.typename == "array" then
            local _, errs_keys = is_a(NUMBER, t2.keys)
            local _, errs_values = is_a(t1.elements, t2.values)
            return combine_errs(errs_keys, errs_values)
         elseif t1.typename == "record" or t1.typename == "arrayrecord" then -- FIXME
            if not is_a(t2.keys, STRING) then
               return false, terr(t1, "can't match a record to a map with non-string keys")
            end
            if t2.keys.typename == "enum" then
               for _, k in ipairs(t1.field_order) do
                  if not t2.keys.enumset[k] then
                     return false, terr(t1, "key is not an enum value: " .. k)
                  end
               end
            end
            return match_fields_to_map(t1, t2)
         end
      elseif t1.typename == "function" and t2.typename == "function" then
         local all_errs = {}
         if (not is_vararg(t2)) and #t1.args > #t2.args then
            table.insert(all_errs, error_in_type(t1, "incompatible number of arguments"))
         else
            for i = (t1.is_method and 2 or 1), #t1.args do
               arg_check(is_a, t1.args[i], t2.args[i] or ANY, nil, i, all_errs)
            end
         end
         local diff_by_va = #t2.rets - #t1.rets == 1 and t2.rets[#t2.rets].is_va
         if #t1.rets < #t2.rets and not diff_by_va then
            table.insert(all_errs, error_in_type(t1, "incompatible number of returns"))
         else
            local nrets = #t2.rets
            if diff_by_va then
               nrets = nrets - 1
            end
            for i = 1, nrets do
               local ok, errs = is_a(t1.rets[i], t2.rets[i])
               add_errs_prefixing(errs, all_errs, "return " .. i .. ": ")
            end
         end
         if #all_errs == 0 then
            return true
         else
            return false, all_errs
         end
      elseif lax and ((not for_equality) and t2.typename == "boolean") then
         -- in .lua files, all values can be used in a boolean context (but not in == or ~=)
         return true
      elseif t1.typename == t2.typename then
         return true
      end
      return false, terr(t1, "got %s, expected %s", t1, t2)
   end

   local function assert_is_a(node: Node, t1: Type, t2: Type, context: string, name: string)
      t1 = resolve_tuple(t1)
      t2 = resolve_tuple(t2)
      if lax and (is_unknown(t1) or is_unknown(t2)) then
         return
      end

      if t2.typename == "unknown_emptytable_value" then
         if same_type(t2.emptytable_type.keys, NUMBER) then
            infer_var(t2.emptytable_type, a_type { typename = "array", elements = t1 }, node)
         else
            infer_var(t2.emptytable_type, a_type { typename = "map", keys = t2.emptytable_type.keys, values = t1 }, node)
         end
         return
      elseif t2.typename == "emptytable" then
         if t1.typename == "array" or t1.typename == "map" or t1.typename == "record" or t1.typename == "arrayrecord" then
            infer_var(t2, t1, node)
         elseif t1.typename ~= "emptytable" then
            node_error(node, "in " .. context .. ": " .. (name and (name .. ": ") or "") .. "assigning %s to a variable declared with {}", t1)
         end
         return
      end

      local match, match_errs = is_a(t1, t2)
      add_errs_prefixing(match_errs, errors, "in " .. context .. ": ".. (name and (name .. ": ") or ""), node)
   end

   local function begin_scope()
      table.insert(st, {})
   end

   local function end_scope()
      local unresolved = st[#st]["@unresolved"]
      if unresolved then
         local upper = st[#st - 1]["@unresolved"]
         if upper then
            for name, nodes in pairs(unresolved.t.labels) do
               for _, node in ipairs(nodes) do
                  upper.t.labels[name] = upper.t.labels[name] or {}
                  table.insert(upper.t.labels[name], node)
               end
            end
         else
            st[#st - 1]["@unresolved"] = unresolved
         end
      end
      table.remove(st)
   end

   local type_check_function_call: function(Node, Type, {Type}, boolean, number): Type
   do
      local function try_match_func_args(node: Node, f: Type, args: {Type}, is_method: boolean, argdelta: number): Type, {Error}
         local ok = true
         local errs = {}

         if is_method then
            argdelta = -1
         elseif not argdelta then
            argdelta = 0
         end

         if f.is_method and not is_method and not is_a(args[1], f.args[1]) then
            table.insert(errs, { y = node.y, x = node.x, msg = "invoked method as a regular function: use ':' instead of '.'", filename = filename })
            return nil, errs
         end

         local va = is_vararg(f)
         local nargs = va
                       and math.max(#args, #f.args)
                       or math.min(#args, #f.args)

         for a = 1, nargs do
            local arg = args[a]
            local farg = f.args[a] or (va and f.args[#f.args])
            if arg == nil then
               if farg.is_va then
                  break
               end
               if not lax then
                  ok = false
                  table.insert(errs, { y = node.y, x = node.x, msg = "error in argument " .. (a + argdelta) .. ": missing argument of type " .. show_type(farg), filename = filename })
               end
            else
               local at = node.e2 and node.e2[a] or node
               if not arg_check(is_a, arg, farg, at, (a + argdelta), errs) then
                  ok = false
                  break
               end
            end
         end
         if ok == true then
            f.rets.typename = "tuple"
            return resolve_typevars(f.rets)
         end
         return nil, errs
      end

      local function revert_typeargs(func: Type)
         if func.typeargs then
            for _, arg in ipairs(func.typeargs) do
               if st[#st][arg.typearg] then
                  st[#st][arg.typearg] = nil
               end
            end
         end
      end

      local function check_call(node: Node, func: Type, args: {Type}, is_method: boolean, argdelta: number): Type
         assert(type(func) == "table")
         assert(type(args) == "table")

         if lax and is_unknown(func) then
            func = a_type { typename = "function", args = { VARARG_UNKNOWN }, rets = { VARARG_UNKNOWN } }
         end

         func = resolve_unary(func)

         args = args or {}
         local poly: Type = func.typename == "poly" and func or { types = { func } }
         local first_errs: {Error}
         local expects: {string} = {}
         -- try exact match first
         for _, f in ipairs(poly.types) do
            if f.typename ~= "function" then
               if lax and is_unknown(f) then
                  return UNKNOWN
               end
               return node_error(node, "not a function: %s", f)
            end
            table.insert(expects, tostring(#f.args or 0))
            local va = is_vararg(f)
            if #args == (#f.args or 0) or (va and #args > #f.args) then
               local matched, errs = try_match_func_args(node, f, args, is_method, argdelta)
               if matched then
                  return matched
               else
                  revert_typeargs(f)
               end
               first_errs = first_errs or errs
            end
         end
         -- now try adjusting with nils to missing arguments or using '...'
         for _, f in ipairs(poly.types) do
            if #args < (#f.args or 0) then
               local matched, errs = try_match_func_args(node, f, args, is_method, argdelta)
               if matched then
                  return matched
               else
                  revert_typeargs(f)
               end
               first_errs = first_errs or errs
            end
         end
         -- now try vararg functions
         for _, f in ipairs(poly.types) do
            if is_vararg(f) and #args > (#f.args or 0) then
               local matched, errs = try_match_func_args(node, f, args, is_method, argdelta)
               if matched then
                  return matched
               else
                  revert_typeargs(f)
               end
               first_errs = first_errs or errs
            end
         end

         if not first_errs then
            node_error(node, "wrong number of arguments (given " .. #args .. ", expects " .. table.concat(expects, " or ") .. ")")
         else
            for _, err in ipairs(first_errs) do
               table.insert(errors, err)
            end
         end

         poly.types[1].rets.typename = "tuple"
         return resolve_typevars(poly.types[1].rets)
      end

      type_check_function_call = function(node: Node, func: Type, args: {Type}, is_method: boolean, argdelta: number): Type
         begin_scope()
         local ret = check_call(node, func, args, is_method, argdelta)
         end_scope()
         return ret
      end
   end

   local unknown_dots: {string:boolean} = {}

   local function add_unknown_dot(node: Node, name: string)
      if not unknown_dots[name] then
         unknown_dots[name] = true
         add_unknown(node, name)
      end
   end

   local function get_self_type(t: Type): Type
      if t.typename == "typetype" then
         return t.def
      else
         return t
      end
   end

   local function match_record_key(node: Node, tbl: Type, key: Node, orig_tbl: Type): Type
      assert(type(tbl) == "table")
      assert(type(key) == "table")

      tbl = resolve_unary(tbl)
      local type_description = tbl.typename
      if tbl.typename == "string" then
         tbl = find_var("string") -- simulate string metatable
      end

      if lax and (is_unknown(tbl) or tbl.typename == "typevar") then
         if node.e1.kind == "variable" and node.op.op ~= "@funcall" then
            add_unknown_dot(node, node.e1.tk .. "." .. key.tk)
         end
         return UNKNOWN
      end

      tbl = get_self_type(tbl)

      if tbl.typename == "emptytable" then
      elseif tbl.typename == "record" or tbl.typename == "arrayrecord" then
         assert(tbl.fields, "record has no fields!?")

         if key.kind == "string" or key.kind == "identifier" then -- "identifier" is a plain atom (e.g 'insert' in 'table.insert')
            if tbl.fields[key.tk] then
               return tbl.fields[key.tk]
            end
         end
      else
         node_error(node, "cannot index something that is not a record: %s", tbl)
         return INVALID
      end

      if lax then
         if node.e1.kind == "variable" and node.op.op ~= "@funcall" then
            add_unknown_dot(node, node.e1.tk .. "." .. key.tk)
         end
         return UNKNOWN
      end

      local description: string
      if node.e1.kind == "variable" then
         description = type_description .. " '" .. node.e1.tk .. "'"
      else
         description = "type " .. show_type(resolve_tuple(orig_tbl))
      end

      return node_error(key, "invalid key '" .. key.tk .. "' in " .. description)
   end

   local function widen_in_scope(scope: {string:Variable}, var: string): boolean
      if scope[var].is_narrowed then
         if scope[var].narrowed_from then
            scope[var].t = scope[var].narrowed_from
            scope[var].narrowed_from = nil
            scope[var].is_narrowed = false
         else
            scope[var] = nil
         end
         return true
      end
      return false
   end

   local function widen_back_var(var: string): boolean
      local widened = false
      for i = #st, 1, -1 do
         if st[i][var] then
            if widen_in_scope(st[i], var) then
               widened = true
            else
               break
            end
         end
      end
      return widened
   end

   local function widen_all_unions()
      for i = #st, 1, -1 do
         for var, _ in pairs(st[i]) do
            widen_in_scope(st[i], var)
         end
      end
   end

   local function add_global(node: Node, var: string, valtype: Type, is_const: boolean)
      if lax and is_unknown(valtype) and (var ~= "self" and var ~= "...") then
         add_unknown(node, var)
      end
      st[1][var] = { t = valtype, is_const = is_const }
   end

   local check_typevars: function(node: Node, t: Type)

   local function check_all_typevars(node: Node, ts: {Type})
      if ts ~= nil then
         for _, arg in ipairs(ts) do
            check_typevars(node, arg)
         end
      end
   end

   check_typevars = function(node: Node, t: Type)
      if t == nil then
         return
      end
      if t.typename == "typevar" then
         if not find_var(t.typevar) then
            node_error(node, "unknown type variable " .. t.typevar)
         end
         return
      end
      check_typevars(node, t.elements)
      check_typevars(node, t.keys)
      check_typevars(node, t.values)
      check_all_typevars(node, t.typeargs)
      check_all_typevars(node, t.args)
      check_all_typevars(node, t.rets)
   end

   local function begin_function_scope(node: Node, recurse: boolean)
      begin_scope()
      local args = {}
      if node.typeargs then
         for i, arg in ipairs(node.typeargs) do
            add_var(nil, arg.typearg, arg)
         end
      end
      for i, arg in ipairs(node.args) do
         local t = arg.decltype
         if not t then
            t = a_type { typename = "unknown" }
         end
         if arg.tk == "..." then
            t.is_va = true
            if i ~= #node.args then
               node_error(node, "'...' can only be last argument")
            end
         end
         check_typevars(arg, t)
         table.insert(args, t)
         add_var(arg, arg.tk, t)
      end

      add_var(nil, "@return", node.rets or a_type { typename = "tuple" })
      if recurse then
         add_var(nil, node.name.tk, a_type {
            typename = "function",
            args = args,
            rets = node.rets,
         })
      end
   end

   local function fail_unresolved_labels()
      local unresolved = st[#st]["@unresolved"]
      if unresolved then
         st[#st]["@unresolved"] = nil
         for name, nodes in pairs(unresolved.t.labels) do
            for _, node in ipairs(nodes) do
               node_error(node, "no visible label '" .. name .. "' for goto")
            end
         end
      end
   end

   local function end_function_scope()
      fail_unresolved_labels()
      end_scope()
   end

   local function match_typevals(t: Type, def: Type): Type
      if t.typevals and def.typeargs then
         if #t.typevals ~= #def.typeargs then
            type_error(t, "mismatch in number of type arguments")
            return nil
         end

         begin_scope()
         for i, tt in ipairs(t.typevals) do
            add_var(nil, def.typeargs[i].typearg, tt)
         end
         local ret = resolve_typevars(def)
         end_scope()
         return ret
      elseif t.typevals then
         type_error(t, "spurious type arguments")
         return nil
      elseif def.typeargs then
         type_error(t, "missing type arguments in %s", def)
         return nil
      else
         return def
      end
   end

   local function resolve_nominal(t: Type): Type
      if t.resolved then
         return t.resolved
      end

      local resolved: Type

      local typetype = find_type(t.names)
      if not typetype then
         type_error(t, "unknown type %s", t)
      elseif typetype.typename == "typetype" then
         resolved = match_typevals(t, typetype.def)
      else
         type_error(t, table.concat(t.names, ".") .. " is not a type")
      end

      if not resolved then
         resolved = a_type { typename = "bad_nominal", names = t.names }
      end

      t.resolved = resolved
      return resolved
   end

   resolve_unary = function(t: Type): Type
      t = resolve_tuple(t)
      if t.typename == "nominal" then
         return resolve_nominal(t)
      end
      return t
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

   local function get_assignment_values(vals: {Type}, wanted: number): {Type}
      local ret: {Type} = {}
      if vals == nil then
         return ret
      end
      -- get all arguments except the last...
      for i = 1, #vals - 1 do
         ret[i] = vals[i]
      end
      local last = vals[#vals]
      -- ...if the last is a tuple, unpack it
      if last.typename == "tuple" then
         for _, v in ipairs(last) do
            table.insert(ret, v)
         end
      -- ...if the last is vararg, repeat its type until it matches the number of wanted args
      elseif last.is_va and #ret < wanted then
         while #ret < wanted do
            table.insert(ret, last)
         end
      -- ...otherwise simply get it
      else
         table.insert(ret, last)
      end
      return ret
   end

   local function get_rets(rets: {Type}): {Type}
      if lax and (#rets == 0) then
         return {a_type { typename = "unknown", is_va = true }}
      end
      return rets
   end

   local function match_all_record_field_names(node: Node, a: Type, field_names: {string}, errmsg: string): Type
      local t: Type
      for _, k in ipairs(field_names) do
         local f = a.fields[k]
         if not t then
            t = f
         else
            if not same_type(f, t) then
               t = nil
               break
            end
         end
      end
      if t then
         return t
      else
         return node_error(node, errmsg)
      end
   end

   local function type_check_index(node: Node, idxnode: Node, a: Type, b: Type): Type
      local orig_a = a
      local orig_b = b
      a = resolve_unary(a)
      b = resolve_unary(b)

      if a.typename == "array" or a.typename == "arrayrecord" and is_a(b, NUMBER) then
         return a.elements
      elseif a.typename == "emptytable" then
         if a.keys == nil then
            a.keys = b
            a.keys_inferred_at = node
            a.keys_inferred_at_file = filename
         else
            if not is_a(b, a.keys) then
               local inferred = " (type of keys inferred at " .. a.keys_inferred_at_file .. ":" .. a.keys_inferred_at.y .. ":" .. a.keys_inferred_at.x .. ": )"
               return node_error(idxnode, "inconsistent index type: %s, expected %s" .. inferred, b, a.keys)
            end
         end
         return a_type { y = node.y, x = node.x, typename = "unknown_emptytable_value", emptytable_type = a }
      elseif a.typename == "map" then
         if is_a(b, a.keys) then
            return a.values
         else
            return node_error(idxnode, "wrong index type: %s, expected %s", orig_b, a.keys)
         end
      elseif node.e2.kind == "string" then
         return match_record_key(node, a, { y = node.e2.y, x = node.e2.x, kind = "string", tk = assert(node.e2.conststr) }, orig_a)
      elseif (a.typename == "record" or a.typename == "arrayrecord") and b.typename == "enum" then
         local field_names: {string} = {}
         for k, _ in pairs(b.enumset) do
            table.insert(field_names, k)
         end
         table.sort(field_names)
         for _, k in ipairs(field_names) do
            if not a.fields[k] then
               return node_error(idxnode, "enum value '" .. k .. "' is not a field in %s", a)
            end
         end
         return match_all_record_field_names(idxnode, a, field_names,
                   "cannot index, not all enum values map to record fields of the same type")
     elseif (a.typename == "record" or a.typename == "arrayrecord") and is_a(b, STRING) then
         return match_all_record_field_names(idxnode, a, a.field_order,
                   "cannot index, not all fields in record have the same type")
      elseif lax and is_unknown(a) then
         return UNKNOWN
      else
         return node_error(idxnode, "cannot index object of type %s with %s", orig_a, orig_b)
      end
   end

   local function expand_type(old: Type, new: Type): Type
      if not old then
         return new
      else
         if not is_a(new, old) then
            if old.typename == "poly" then
               table.insert(old.types, new)
            else
               return a_type {
                  typename = "poly",
                  types = {
                     old,
                     new
                  }
               }
            end
         end
      end
      return old
   end

   local function find_in_scope(exp: Node): Type
      if exp.kind == "variable" then
         local name = exp.tk
         local parent_scope = st[#st - 1]
         local type_in_scope = parent_scope[name] and parent_scope[name].t
         if type_in_scope and type_in_scope.typename == "typetype" then
            type_in_scope = type_in_scope.def
         end
         return type_in_scope
      elseif exp.kind == "op" and exp.op.op == "." then
         local t = find_in_scope(exp.e1)
         if not t then
            return nil
         end
         while exp.e2.kind == "op" and exp.e2.op.op == "." do
            t = t.fields[exp.e2.e1.tk]
            if not t then
               return nil
            end
            exp = exp.e2
         end
         t = t.fields[exp.e2.tk]
         return t
      end
   end

   local facts_and: function(f1: {Fact}, f2: {Fact}, errnode: Node): {Fact}
   local facts_or:  function(f1: {Fact}, f2: {Fact}): {Fact}
   local facts_not: function(f1: {Fact}): {Fact}
   do
      local function join_facts(fss: {{Fact}}): {string:{Fact}}
         local vars: {string:{Fact}} = {}

         for _, fs in ipairs(fss) do
            for _, f in ipairs(fs) do
               if not vars[f.var] then
                  vars[f.var] = {}
               end
               table.insert(vars[f.var], f)
            end
         end
         return vars
      end

      local function intersect<`T>(xs: {`T}, ys: {`T}, same: function(`T, `T): boolean): {`T}
         local rs = {}
         for i = #xs, 1, -1 do
            local x = xs[i]
            for _, y in ipairs(ys) do
               if same(x, y) then
                  table.insert(rs, x)
                  break
               end
            end
         end
         return rs
      end

      local function same_type_for_intersect(t: Type, u: Type): boolean
         return (same_type(t, u))
      end

      local function intersect_facts(fs: {Fact}, errnode: Node): boolean, Type
         local all_is = true
         local types = {}
         for i, f in ipairs(fs) do
            if f.fact ~= "is" then
               all_is = false
               break
            end
            if f.typ.typename == "union" then
               if i == 1 then
                  types = f.typ.types
               else
                  types = intersect(types, f.typ.types, same_type_for_intersect)
               end
            else
               if i == 1 then
                  types = { f.typ }
               else
                  types = intersect(types, { f.typ }, same_type_for_intersect)
               end
            end
         end

         if #types == 0 then
            node_error(errnode, "branch is always false")
            return false
         end

         if all_is then
            if #types == 1 then
               return true, types[1]
            else
               return true, a_type {
                  typename = "union",
                  types = types,
               }
            end
         else
            return false
         end
      end

      local function sum_facts(fs: {Fact}): boolean, Type
         local all_is = true
         local types: {Type} = {}
         for _, f in ipairs(fs) do
            if f.fact ~= "is" then
               all_is = false
               break
            end
            table.insert(types, f.typ)
         end

         if all_is then
            if #types == 1 then
               return true, types[1]
            else
               return true, a_type {
                  typename = "union",
                  types = types,
               }
            end
         else
            return false
         end
      end

      local function subtract_types(u1: Type, u2: Type, errt: Type): Type
         local types: {Type} = {}
         for _, rt in ipairs(u1.types or { u1 }) do
            local not_present = true
            for _, ft in ipairs(u2.types or { u2 }) do
               if same_type(rt, ft) then
                  not_present = false
                  break
               end
            end
            if not_present then
               table.insert(types, rt)
            end
         end

         if #types == 0 then
            type_error(errt, "branch is always false")
            return INVALID
         end

         if #types == 1 then
            return types[1]
         else
            return a_type {
               typename = "union",
               types = types,
            }
         end
      end

      facts_and = function(f1: {Fact}, f2: {Fact}, errnode: Node): {Fact}
         if not f1 then
            return f2
         end
         if not f2 then
            return f1
         end

         local out: {Fact} = {}
         for v, fs in pairs(join_facts({f1, f2})) do
            local ok, u = intersect_facts(fs, errnode)

            if ok then
               table.insert(out, { fact = "is", var = v, typ = u })
            else
               -- FIXME handle non-"is" facts... when we have them
               for _, f in ipairs(fs) do
                  table.insert(out, f)
               end
            end
         end
         return out
      end

      facts_or = function(f1: {Fact}, f2: {Fact}): {Fact}
         if not f1 or not f2 then
            return nil
         end

         local out: {Fact} = {}
         for v, fs in pairs(join_facts({f1, f2})) do
            local ok, u = sum_facts(fs)
            if ok then
               table.insert(out, { fact = "is", var = v, typ = u })
            else
               -- FIXME handle non-"is" facts... when we have them
               for _, f in ipairs(fs) do
                  table.insert(out, f)
               end
            end
         end
         return out
      end

      facts_not = function(f1: {Fact}): {Fact}
         if not f1 then
            return nil
         end

         local out: {Fact} = {}
         for v, fs in pairs(join_facts({f1})) do
            local realtype = find_var(v)
            local ok, u = sum_facts(fs) -- is this correct?
            if ok then
               local not_typ = subtract_types(realtype, u, fs[1].typ)
               table.insert(out, { fact = "is", var = v, typ = not_typ })
            end
         end
         return out
      end
   end

   local function apply_facts(where: Node, facts: {Fact})
      if not facts then
         return
      end
      for _, f in ipairs(facts) do
         if f.fact == "is" then
            local t = resolve_typevars(f.typ) -- new type object
            t.inferred_at = where
            t.inferred_at_file = filename
            add_var(nil, f.var, t, nil, true)
         end
      end
   end

   local visit_node: Visitor<NodeKind, Node, Type> = {}

   visit_node.cbs = {
      ["statements"] = {
         before = function()
            begin_scope()
         end,
         after = function(node: Node, children: {Type}): Type
            -- if at the top level
            if #st == 2 then
               fail_unresolved_labels()
            end

            end_scope()
            -- TODO extract node type from `return`
            node.type = NONE
         end
      },
      ["local_declaration"] = {
         after = function(node: Node, children: {Type}): Type
            local vals: {Type} = get_assignment_values(children[2], #node.vars)
            for i, var in ipairs(node.vars) do
               local decltype = node.decltype and node.decltype[i]
               local infertype = vals and vals[i]
               if lax and infertype and infertype.typename == "nil" then
                  infertype = nil
               end
               if decltype and infertype then
                  assert_is_a(node.vars[i], infertype, decltype, "local declaration", var.tk)
               end
               local t = decltype or infertype
               if t == nil then
                  t = a_type { typename = "unknown" }
                  if not lax then
                     if node.exps then
                        node_error(node.vars[i], "assignment in declaration did not produce an initial value for variable '" .. var.tk .. "'")
                     else
                        node_error(node.vars[i], "variable '" .. var.tk .. "' has no type or initial value")
                     end
                  end
               elseif t.typename == "emptytable" then
                  t.declared_at = node
                  t.assigned_to = var.tk
               end
               assert(var)
               add_var(var, var.tk, t, var.is_const)
            end
            node.type = NONE
         end,
      },
      ["global_declaration"] = {
         after = function(node: Node, children: {Type}): Type
            local vals: {Type} = get_assignment_values(children[2], #node.vars)
            for i, var in ipairs(node.vars) do
               local decltype = node.decltype and node.decltype[i]
               local infertype = vals and vals[i]
               if lax and infertype and infertype.typename == "nil" then
                  infertype = nil
               end
               if decltype and infertype then
                  assert_is_a(node.vars[i], infertype, decltype, "global declaration", var.tk)
               end
               local t = decltype or infertype
               local existing, existing_is_const = find_global(var.tk)
               if existing then
                  if infertype and existing_is_const then
                     node_error(var, "cannot reassign to <const> global: " .. var.tk)
                  end
                  if existing_is_const == true and not var.is_const then
                     node_error(var, "global was previously declared as <const>: " .. var.tk)
                  end
                  if existing_is_const == false and var.is_const then
                     node_error(var, "global was previously declared as not <const>: " .. var.tk)
                  end
                  if not same_type(existing, t) then
                     node_error(var, "cannot redeclare global with a different type: previous type of " .. var.tk .. " is %s", existing)
                  end
               else
                  if t == nil then
                     t = a_type { typename = "unknown" }
                  elseif t.typename == "emptytable" then
                     t.declared_at = node
                     t.assigned_to = var.tk
                  end
                  add_global(var, var.tk, t, var.is_const)
               end
            end
            node.type = NONE
         end,
      },
      ["assignment"] = {
         after = function(node: Node, children: {Type}): Type
            local vals: {Type} = get_assignment_values(children[2], #children[1])
            local exps = flatten_list(vals)
            for i, vartype in ipairs(children[1]) do
               local varnode = node.vars[i]
               if varnode.is_const then
                  node_error(varnode, "cannot assign to <const> variable")
               end
               if varnode.kind == "variable" then
                  if widen_back_var(varnode.tk) then
                     vartype = find_var(varnode.tk)
                  end
               end
               if vartype then
                  local val = exps[i]
                  if val then
                     assert_is_a(varnode, val, vartype, "assignment")
                     if varnode.kind == "variable" and vartype.typename == "union" then
                        -- narrow union
                        add_var(varnode, varnode.tk, val, false, true)
                     end
                  else
                     node_error(varnode, "variable is not being assigned a value")
                  end
               else
                  node_error(varnode, "unknown variable")
               end
            end
            node.type = NONE
         end,
      },
      ["do"] = {
         after = function(node: Node, children: {Type}): Type
            node.type = NONE
         end,
      },
      ["if"] = {
         before_statements = function(node: Node)
            begin_scope()
            apply_facts(node.exp, node.exp.facts)
         end,
         after = function(node: Node, children: {Type}): Type
            end_scope()
            node.type = NONE
         end,
      },
      ["elseif"] = {
         before = function(node: Node)
            end_scope()
            begin_scope()
         end,
         before_statements = function(node: Node)
            local f = facts_not(node.parent_if.exp.facts)
            for e = 1, node.elseif_n - 1 do
               f = facts_and(f, facts_not(node.parent_if.elseifs[e].exp.facts), node)
            end
            f = facts_and(f, node.exp.facts, node)
            apply_facts(node.exp, f)
         end,
         after = function(node: Node, children: {Type}): Type
            node.type = NONE
         end,
      },
      ["else"] = {
         before = function(node: Node)
            end_scope()
            begin_scope()
            local f = facts_not(node.parent_if.exp.facts)
            for _, elseifnode in ipairs(node.parent_if.elseifs) do
               f = facts_and(f, facts_not(elseifnode.exp.facts), node)
            end
            apply_facts(node, f)
         end,
         after = function(node: Node, children: {Type}): Type
            node.type = NONE
         end,
      },
      ["while"] = {
         before = function()
            -- widen all narrowed variables because we don't calculate a fixpoint yet
            widen_all_unions()
         end,
         before_statements = function(node: Node)
            begin_scope()
            apply_facts(node.exp, node.exp.facts)
         end,
         after = function(node: Node, children: {Type}): Type
            end_scope()
            node.type = NONE
         end,
      },
      ["label"] = {
         before = function(node: Node)
            -- widen all narrowed variables because we don't calculate a fixpoint yet
            widen_all_unions()
            local label_id = "::" .. node.label .. "::"
            if st[#st][label_id] then
               node_error(node, "label '" .. node.label .. "' already defined at " .. filename )
            end
            local unresolved = st[#st]["@unresolved"]
            if unresolved then
               unresolved.t.labels[node.label] = nil
            end
            node.type = a_type { y = node.y, x = node.x, typename = "none", }
            add_var(node, label_id, node.type)
         end,
      },
      ["goto"] = {
         after = function(node: Node, children: {Type}): Type
            if not find_var("::" .. node.label .. "::") then
               local unresolved = find_var("@unresolved")
               if not unresolved then
                  unresolved = { typename = "unresolved_labels", labels = {} }
                  add_var(node, "@unresolved", unresolved)
               end
               unresolved.labels[node.label] = unresolved.labels[node.label] or {}
               table.insert(unresolved.labels[node.label], node)
            end
            node.type = NONE
         end,
      },
      ["repeat"] = {
         before = function()
            -- widen all narrowed variables because we don't calculate a fixpoint yet
            widen_all_unions()
         end,
         after = function(node: Node, children: {Type}): Type
            node.type = NONE
         end,
      },
      ["forin"] = {
         before = function()
            begin_scope()
         end,
         before_statements = function(node: Node)
            local exp1 = node.exps[1]
            local exp1type = resolve_tuple(exp1.type)
            if exp1type.typename == "function" then
               local r1 = exp1type.rets[1] or UNKNOWN
               local r2 = exp1type.rets[2] or UNKNOWN
               -- check common errors:
               if exp1.op and exp1.op.op == "@funcall" then
                  local t = resolve_unary(exp1.e2.type)
                  if exp1.e1.tk == "pairs" and not (t.typename == "map" or t.typename == "record") then
                     if not (lax and is_unknown(t)) then
                        node_error(exp1, "attempting pairs loop on something that's not a map or record: %s", exp1.e2.type)
                     end
                  elseif exp1.e1.tk == "ipairs" and not (t.typename == "array" or t.typename == "arrayrecord") then
                     if not (lax and (is_unknown(t) or t.typename == "emptytable")) then
                        node_error(exp1, "attempting ipairs loop on something that's not an array: %s", exp1.e2.type)
                     end
                  end
               end
               add_var(node.vars[1], node.vars[1].tk, r1)
               if node.vars[2] then
                  add_var(node.vars[2], node.vars[2].tk, r2)
               end
            else
               if not (lax and is_unknown(exp1type)) then
                  node_error(exp1, "expression in for loop does not return an iterator")
               end
            end
         end,
         after = function(node: Node, children: {Type}): Type
            end_scope()
            node.type = NONE
         end,
      },
      ["fornum"] = {
         before = function(node: Node)
            begin_scope()
            add_var(nil, node.var.tk, NUMBER)
         end,
         after = function(node: Node, children: {Type}): Type
            end_scope()
            node.type = NONE
         end,
      },
      ["return"] = {
         after = function(node: Node, children: {Type}): Type
            local rets = assert(find_var("@return"))
            local nrets = #rets
            local vatype: Type
            if nrets > 0 then
               vatype = rets[nrets].is_va and rets[nrets]
            end

            if #children[1] > nrets and (not lax) and not vatype then
               node_error(node, "excess return values, expected " .. #rets .. " got " .. #children[1])
            end

            for i = 1, #children[1] do
               local expected = rets[i] or vatype
               if expected then
                  assert_is_a(node.exps[i], children[1][i], expected, "return value")
               end
            end

            -- if at the toplevel
            if #st == 2 then
               module_type = resolve_unary(children[1])
            end

            node.type = NONE
         end,
      },
      ["variables"] = {
         after = function(node: Node, children: {Type}): Type
            node.type = children

            -- explode last tuple: (1, 2, (3, 4)) becomes (1, 2, 3, 4)
            local n = #children
            if n > 0 and children[n].typename == "tuple" then
               local tuple = children[n]
               for i, c in ipairs(tuple) do
                  children[n + i - 1] = c
               end
            end

            node.type.typename = "tuple"
         end,
      },
      ["table_literal"] = {
         after = function(node: Node, children: {Type}): Type
            node.type = a_type {
               y = node.y,
               x = node.x,
               typename = "emptytable",
            }
            local is_record = false
            local is_array = false
            local is_map = false
            for _, child in ipairs(children) do
               assert(child.typename == "table_item")
               if child.kname then
                  is_record = true
                  if not node.type.fields then
                     node.type.fields = {}
                     node.type.field_order = {}
                  end
                  node.type.fields[child.kname] = child.vtype
                  table.insert(node.type.field_order, child.kname)
               elseif child.ktype.typename == "number" then
                  is_array = true
                  node.type.elements = expand_type(node.type.elements, child.vtype)
               else
                  is_map = true
                  node.type.keys = expand_type(node.type.keys, child.ktype)
                  node.type.values = expand_type(node.type.values, child.vtype)
               end
            end
            if is_array and is_map then
               node_error(node, "cannot determine type of table literal")
            elseif is_record and is_array then
               node.type.typename = "arrayrecord"
            elseif is_record and is_map then
               if node.type.keys.typename == "string" then
                  node.type.typename = "map"
                  for _, ftype in pairs(node.type.fields) do
                     node.type.values = expand_type(node.type.values, ftype)
                  end
                  node.type.fields = nil
                  node.type.field_order = nil
               else
                  node_error(node, "cannot determine type of table literal")
               end
            elseif is_array then
               node.type.typename = "array"
            elseif is_record then
               node.type.typename = "record"
            elseif is_map then
               node.type.typename = "map"
            end
         end,
      },
      ["table_item"] = {
         after = function(node: Node, children: {Type}): Type
            local kname = node.key.conststr
            local ktype = children[1]
            local vtype = children[2]
            if node.decltype then
               vtype = node.decltype
               assert_is_a(node.value, children[2], node.decltype, "table item")
            end
            node.type = a_type {
               y = node.y,
               x = node.x,
               typename = "table_item",
               kname = kname,
               ktype = ktype,
               vtype = vtype,
            }
         end,
      },
      ["local_function"] = {
         before = function(node: Node)
            begin_function_scope(node, true)
         end,
         after = function(node: Node, children: {Type}): Type
            end_function_scope()
            add_var(nil, node.name.tk, a_type {
               typename = "function",
               args = children[2],
               rets = get_rets(children[3]),
            })
            node.type = NONE
         end,
      },
      ["global_function"] = {
         before = function(node: Node)
            begin_function_scope(node, true)
         end,
         after = function(node: Node, children: {Type}): Type
            end_function_scope()
            add_global(nil, node.name.tk, a_type {
               typename = "function",
               args = children[2],
               rets = get_rets(children[3]),
            })
            node.type = NONE
         end,
      },
      ["record_function"] = {
         before = function(node: Node)
            begin_function_scope(node)
         end,
         before_statements = function(node: Node, children: {Type})
            if node.is_method then
               local rtype = get_self_type(children[1])
               children[3][1] = rtype
               add_var(nil, "self", rtype)
            end

            local rtype = resolve_unary(get_self_type(children[1]))
            if rtype.typename == "emptytable" then
               rtype.typename = "record"
            end
            if (rtype.typename == "record" or rtype.typename == "arrayrecord") then
               local fn_type = a_type {
                  y = node.y,
                  x = node.x,
                  typename = "function",
                  is_method = node.is_method,
                  args = children[3],
                  rets = get_rets(children[4]),
               }

               local ok = false
               if lax then
                  ok = true
               elseif rtype.fields and rtype.fields[node.name.tk] and is_a(fn_type, rtype.fields[node.name.tk]) then
                  ok = true
               elseif find_in_scope(node.fn_owner) == rtype then
                  ok = true
               end

               if ok then
                  rtype.fields = rtype.fields or {}
                  rtype.field_order = rtype.field_order or {}
                  rtype.fields[node.name.tk] = fn_type
                  table.insert(rtype.field_order, node.name.tk)
               else
                  local name = tl.pretty_print_ast(node.fn_owner)
                  node_error(node, "cannot add undeclared function '" .. node.name.tk .. "' outside of the scope where '" .. name .. "' was originally declared")
               end
            else
               node_error(node, "not a module: %s", rtype)
            end
         end,
         after = function(node: Node, children: {Type}): Type
            end_function_scope()

            node.type = NONE
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
            node.type = a_type {
               y = node.y,
               x = node.x,
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
      ["paren"] = {
         after = function(node: Node, children: {Type}): Type
            node.type = resolve_unary(children[1])
         end,
      },
      ["op"] = {
         before = function(node: Node)
            begin_scope()
         end,
         before_e2 = function(node: Node)
            if node.op.op == "and" then
               apply_facts(node, node.e1.facts)
            elseif node.op.op == "or" then
               apply_facts(node, facts_not(node.e1.facts))
            end
         end,
         after = function(node: Node, children: {Type}): Type
            end_scope()

            local a: Type = children[1]
            local b: Type = children[3]
            local orig_a = a
            local orig_b = b
            local ua = a and resolve_unary(a)
            local ub = b and resolve_unary(b)
            if node.op.op == "@funcall" then
               if node.e1.tk == "rawget" then
                  if #b == 2 then
                     local b1 = resolve_unary(b[1])
                     local b2 = resolve_unary(b[2])
                     local knode = node.e2[2]
                     if b1.typename == "record" and knode.conststr then
                        node.type = match_record_key(node, b1, { y = knode.y, x = knode.x, kind = "string", tk = assert(knode.conststr) }, b1)
                     else
                        node.type = type_check_index(node, knode, b1, b2)
                     end
                  else
                     node_error(node, "rawget expects two arguments")
                  end
               elseif node.e1.tk == "print_type" then
                  print(show_type(b))
                  node.type = BOOLEAN
               elseif node.e1.tk == "require" then
                  if #b == 1 then
                     if node.e2[1].kind == "string" then
                        local module_name = assert(node.e2[1].conststr)
                        node.type = require_module(module_name, lax, opts.env, result)
                        if not node.type then
                           node.type = BOOLEAN
                        end
                        opts.env.modules[module_name] = node.type
                     else
                        node.type = UNKNOWN -- don't know how to resolve a dynamic require
                     end
                  else
                     node_error(node, "require expects one literal argument")
                  end
               elseif node.e1.tk == "pcall" then
                  local ftype = table.remove(b, 1)
                  local rets = type_check_function_call(node, ftype, b, false, 1)
                  if rets.typename ~= "tuple" then
                     rets = a_type { typename = "tuple", rets }
                  end
                  table.insert(rets, 1, BOOLEAN)
                  node.type = rets
               elseif node.e1.op and node.e1.op.op == ":" then
                  local func = node.e1.type
                  if func.typename == "function" or func.typename == "poly" then
                     table.insert(b, 1, node.e1.e1.type)
                     node.type = type_check_function_call(node, func, b, true)
                  else
                     if lax and (is_unknown(func)) then
                        if node.e1.e1.kind == "variable" then
                           add_unknown_dot(node, node.e1.e1.tk .. "." .. node.e1.e2.tk)
                        end
                        node.type = VARARG_UNKNOWN
                     else
                        node.type = INVALID
                     end
                  end
               else
                  node.type = type_check_function_call(node, a, b, false)
               end
            elseif node.op.op == "@index" then
               node.type = type_check_index(node, node.e2, a, b)
            elseif node.op.op == "as" then
               node.type = b
            elseif node.op.op == "is" then
               if node.e1.kind == "variable" then
                  node.facts = { { fact = "is", var = node.e1.tk, typ = b } }
               else
                  node_error(node, "can only use 'is' on variables")
               end
               node.type = BOOLEAN
            elseif node.op.op == "." then
               a = ua
               if a.typename == "map" then
                  if is_a(a.keys, STRING) or is_a(a.keys, ANY) then
                     node.type = a.values
                  else
                     node_error(node, "cannot use . index, expects keys of type %s", a.keys)
                  end
               else
                  node.type = match_record_key(node, a, { y = node.e2.y, x = node.e2.x, kind = "string", tk = node.e2.tk }, orig_a)
                  if node.type.needs_compat53 and not opts.skip_compat53 then
                     local key = node.e1.tk .. "." .. node.e2.tk
                     node.kind = "variable"
                     node.tk = "_tl_" .. node.e1.tk .. "_" .. node.e2.tk
                     all_needs_compat53[key] = true
                  end
               end
            elseif node.op.op == ":" then
               node.type = match_record_key(node, node.e1.type, node.e2, orig_a)
            elseif node.op.op == "not" then
               node.facts = facts_not(node.e1.facts)
               node.type = BOOLEAN
            elseif node.op.op == "and" then
               node.facts = facts_and(node.e1.facts, node.e2.facts, node)
               node.type = resolve_tuple(b)
            elseif node.op.op == "or" and b.typename == "emptytable" then
               node.facts = nil
               node.type = resolve_tuple(a)
            elseif node.op.op == "or" and same_type(ua, ub) then
               node.facts = facts_or(node.e1.facts, node.e2.facts)
               node.type = resolve_tuple(a)
            elseif node.op.op == "or" and b.typename == "nil" then
               node.facts = nil
               node.type = resolve_tuple(a)
            elseif node.op.op == "or"
                   and ((ua.typename == "enum" and ub.typename == "string" and is_a(ub, ua))
                    or  (ua.typename == "string" and ub.typename == "enum" and is_a(ua, ub))) then
               node.facts = nil
               node.type = (ua.typename == "enum" and ua or ub)
            elseif node.op.op == "or"
                   and (a.typename == "nominal" or a.typename == "map")
                   and (b.typename == "record" or b.typename == "arrayrecord")
                   and is_a(b, a) then
               node.facts = nil
               node.type = resolve_tuple(a)
            elseif node.op.op == "==" or node.op.op == "~=" then
               if is_a(a, b, true) or is_a(b, a, true) then
                  node.type = BOOLEAN
               else
                  if lax and (is_unknown(a) or is_unknown(b)) then
                     node.type = UNKNOWN
                  else
                     node_error(node, "types are not comparable for equality: %s and %s", a, b)
                  end
               end
            elseif node.op.arity == 1 and unop_types[node.op.op] then
               a = ua
               local types_op = unop_types[node.op.op]
               node.type = types_op[a.typename]
               if not node.type then
                  if lax and is_unknown(a) then
                     node.type = UNKNOWN
                  else
                     node_error(node, "cannot use operator '" .. node.op.op:gsub("%%", "%%%%") .. "' on type %s", orig_a)
                  end
               end
            elseif node.op.arity == 2 and binop_types[node.op.op] then
               if node.op.op == "or" then
                  node.facts = facts_or(node.e1.facts, node.e2.facts)
               end

               a = ua
               b = ub
               local types_op = binop_types[node.op.op]
               node.type = types_op[a.typename] and types_op[a.typename][b.typename]
               if not node.type then
                  if lax and (is_unknown(a) or is_unknown(b)) then
                     node.type = UNKNOWN
                  else
                     node_error(node, "cannot use operator '" .. node.op.op:gsub("%%", "%%%%") .. "' for types %s and %s", orig_a, orig_b)
                  end
               end
            else
               error("unknown node op " .. node.op.op)
            end
         end,
      },
      ["variable"] = {
         after = function(node: Node, children: {Type}): Type
            node.type, node.is_const = find_var(node.tk)
            if node.type == nil then
               node.type = a_type { typename = "unknown" }
               if lax then
                  add_unknown(node, node.tk)
               else
                  node_error(node, "unknown variable: " .. node.tk)
               end
            end
         end,
      },
      ["identifier"] = {
         after = function(node: Node, children: {Type}): Type
            node.type = NONE -- type is resolved elsewhere
         end,
      },
      ["newtype"] = {
         after = function(node: Node, children: {Type}): Type
            node.type = node.newtype
         end,
      }
   }

   visit_node.cbs["break"] = visit_node.cbs["do"]

   visit_node.cbs["values"] = visit_node.cbs["variables"]
   visit_node.cbs["expression_list"] = visit_node.cbs["variables"]
   visit_node.cbs["argument_list"] = visit_node.cbs["variables"]
   visit_node.cbs["argument"] = visit_node.cbs["variable"]

   visit_node.cbs["string"] = {
      after = function(node: Node, children: {Type}): Type
         node.type = a_type {
            y = node.y,
            x = node.x,
            typename = node.kind as TypeName,
            tk = node.tk,
         }
         return node.type
      end,
   }
   visit_node.cbs["number"] = visit_node.cbs["string"]
   visit_node.cbs["nil"] = visit_node.cbs["string"]
   visit_node.cbs["boolean"] = visit_node.cbs["string"]
   visit_node.cbs["..."] = visit_node.cbs["variable"]

   visit_node.after = {
      after = function(node: Node, children: {Type}): Type
         assert(type(node.type) == "table", node.kind .. " did not produce a type")
         assert(type(node.type.typename) == "string", node.kind .. " type does not have a typename")
         return node.type
      end
   }

   local visit_type: Visitor<TypeName,Type,Type> = {
      cbs = {
         ["string"] = {
            after = function(typ: Type, children: {Type}): Type
               return typ,
            end,
         },
         ["nominal"] = {
            after = function(typ: Type, children: {Type}): Type
               if not find_type(typ.names) then
                  --type_error(typ, "unknown type %s", typ)
               end
               return typ
            end,
         },
         ["union"] = {
            after = function(typ: Type, children: {Type}): Type
               -- check for limitations in our union support
               -- due to codegen limitations (we only check with type() so far)
               local n_table_types = 0
               local n_string_enum = 0
               for _, t in ipairs(typ.types) do
                  t = resolve_unary(t)
                  if table_types[t.typename] then
                     n_table_types = n_table_types + 1
                     if n_table_types > 1 then
                        type_error(typ, "cannot discriminate a union between multiple table types: %s", typ)
                        break
                     end
                  elseif t.typename == "string" or t.typename == "enum" then
                     n_string_enum = n_string_enum + 1
                     if n_string_enum > 1 then
                        type_error(typ, "cannot discriminate a union between multiple string/enum types: %s", typ)
                        break
                     end
                  end
               end
               return typ
            end,
         },
      },
      after = {
         after = function(typ: Type, children: {Type}, ret: Type): Type
            assert(type(ret) == "table", typ.typename .. " did not produce a type")
            assert(type(ret.typename) == "string", "type node does not have a typename")
            return ret
         end
      }
   }
   visit_type.cbs["typetype"] = visit_type.cbs["string"]
   visit_type.cbs["typevar"] = visit_type.cbs["string"]
   visit_type.cbs["typearg"] = visit_type.cbs["string"]
   visit_type.cbs["function"] = visit_type.cbs["string"]
   visit_type.cbs["array"] = visit_type.cbs["string"]
   visit_type.cbs["map"] = visit_type.cbs["string"]
   visit_type.cbs["arrayrecord"] = visit_type.cbs["string"]
   visit_type.cbs["record"] = visit_type.cbs["string"]
   visit_type.cbs["enum"] = visit_type.cbs["string"]
   visit_type.cbs["boolean"] = visit_type.cbs["string"]
   visit_type.cbs["nil"] = visit_type.cbs["string"]
   visit_type.cbs["number"] = visit_type.cbs["string"]
   visit_type.cbs["bad_nominal"] = visit_type.cbs["string"]
   visit_type.cbs["emptytable"] = visit_type.cbs["string"]
   visit_type.cbs["table_item"] = visit_type.cbs["string"]
   visit_type.cbs["unknown_emptytable_value"] = visit_type.cbs["string"]
   visit_type.cbs["tuple"] = visit_type.cbs["string"]
   visit_type.cbs["poly"] = visit_type.cbs["string"]
   visit_type.cbs["any"] = visit_type.cbs["string"]
   visit_type.cbs["unknown"] = visit_type.cbs["string"]
   visit_type.cbs["invalid"] = visit_type.cbs["string"]
   visit_type.cbs["unresolved_labels"] = visit_type.cbs["string"]
   visit_type.cbs["none"] = visit_type.cbs["string"]

   recurse_node(ast, visit_node, visit_type)

   local redundant: {number} = {}
   local lastx, lasty = 0, 0
   table.sort(errors, function(a: Error, b: Error): boolean
      return ((a.filename and b.filename) and a.filename < b.filename)
             or (a.filename == b.filename and ((a.y < b.y) or (a.y == b.y and a.x < b.x)))
   end)
   for i, err in ipairs(errors) do
      if err.x == lastx and err.y == lasty then
         table.insert(redundant, i)
      end
      lastx, lasty = err.x, err.y
   end
   for i = #redundant, 1, -1 do
      table.remove(errors, redundant[i])
   end

   if not opts.skip_compat53 then
      add_compat53_entries(ast, all_needs_compat53)
   end

   return errors, unknowns, module_type
end

local function init_modules(): {string:Type}
   local modules: {string:Type} = {
      tl = a_type {
         typename = "record",
         fields = {
            ["loader"] = a_type { typename = "function", args = {}, rets = {} },
         }
      }
   }
   fill_field_order(modules["tl"])
   for k, m in pairs(standard_library) do
      if m.typename == "record" then
         modules[k] = m
      end
   end
   return modules
end

function tl.process(filename: string, env: Env, result: Result, preload_modules: {string}): Result, string
   local fd, err = io.open(filename, "r")
   if not fd then
      return nil, "could not open " .. filename .. ": " .. err
   end

   local input, err = fd:read("*a")
   if not input then
      fd:close()
      return nil, "could not read " .. filename .. ": " .. err
   end

   local basename, extension = filename:match("(.*)%.([a-z]+)$")
   extension = extension and extension:lower()

   local is_lua: boolean
   if extension == "tl" then
      is_lua = false
   elseif extension == "lua" then
      is_lua = true
   else
      is_lua = input:match("^#![^\n]*lua[^\n]*\n") as boolean
   end

   env = env or tl.init_env(is_lua)
   result = result or {
      syntax_errors = {},
      type_errors = {},
      unknowns = {},
   }
   preload_modules = preload_modules or {}

   local tokens, errs = tl.lex(input)
   if errs then
      for i, err in ipairs(errs) do
         table.insert(result.syntax_errors, {
            y = err.y,
            x = err.x,
            msg = "invalid token '" .. err.tk .. "'",
            filename = filename,
         })
      end
   end

   local i, program = tl.parse_program(tokens, result.syntax_errors, filename)
   if #result.syntax_errors > 0 then
      return result
   end

   -- Preload modules
   for _, name in ipairs(preload_modules) do
      local module_type = require_module(name, is_lua, env, result)

      if module_type == UNKNOWN then
         return nil, string.format("Error: could not preload module '%s'", name)
      end
   end

   local error, unknown: {Error}, {Error}
   local opts: TypeCheckOptions = {
      lax = is_lua,
      filename = filename,
      env = env,
      result = result,
      skip_compat53 = env.skip_compat53,
   }
   error, unknown, result.type = tl.type_check(program, opts)

   result.ast = program
   result.env = env

   return result
end

local function tl_package_loader(module_name: string): any
   local found_filename, fd, tried = tl.search_module(module_name, false)
   if found_filename then
      local input = fd:read("*a")
      fd:close()
      local tokens = tl.lex(input)
      local errs = {}
      local i, program = tl.parse_program(tokens, errs, found_filename)
      local code = tl.pretty_print_ast(program, true)
      local chunk = load(code, found_filename)
      if chunk then
         return function(): any
            local ret = chunk()
            package.loaded[module_name] = ret
            return ret
         end
      end
   end
   return table.concat(tried, "\n\t")
end

function tl.loader()
   if package.searchers then
      table.insert(package.searchers, 2, tl_package_loader)
   else
      table.insert(package.loaders, 2, tl_package_loader)
   end
end

return tl

