local tl = {}
local inspect = require("inspect")
local keywords = {
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
function tl.number()

end
function tl.string()

end
function tl.boolean()

end
function tl.nominal()

end
function tl.record()

end
function tl.array()

end
function tl.map(k, v)

end
function tl.fun()

end
local Token = tl.record({
   ["x"] = tl.number,
   ["y"] = tl.number,
   ["i"] = tl.number,
   ["tk"] = tl.string,
   ["kind"] = tl.string,
})
function tl.lex(input)
   local tokens = {}
   local state = "any"
   local fwd = true
   local y = 1
   local x = 0
   local i = 0
   local function begin_token()
      table.insert(tokens, {
         ["x"] = x,
         ["y"] = y,
         ["i"] = i,
      })
   end
   local function drop_token()
      table.remove(tokens)
   end
   local function end_token(kind, t, last)
      assert(type(kind) == "string")
      local token = tokens[#tokens]
      token.tk = t or input:sub(token.i, last or i)
      if keywords[token.tk] then
         kind = "keyword"
      end
      token.kind = kind
   end
   while i <=#input do
      if fwd then
         i = i + 1
      end
      if i >#input then
         break
      end
      local c = input:sub(i, i)
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
         elseif c:match("[a-zA-Z_]") then
            state = "word"
            begin_token()
         elseif c:match("[0-9]") then
            state = "number"
            begin_token()
         elseif c:match("[<>=~]") then
            state = "maybeequals"
            begin_token()
         elseif c:match("[][(){},:#]") then
            begin_token()
            end_token(c, nil, nil)
         elseif c:match("[+*/]") then
            begin_token()
            end_token("op", nil, nil)
         end
      elseif state == "maybecomment" then
         if c == "-" then
            state = "comment"
            drop_token()
         else
            end_token("op", "-")
            fwd = false
            state = "any"
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
      elseif state == "maybeequals" then
         if c == "=" then
            end_token("op")
            state = "any"
         else
            end_token("=", nil, i - 1)
            fwd = false
            state = "any"
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
local add_space = {
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
local should_unindent = {
   ["end"] = true,
   ["elseif"] = true,
   ["else"] = true,
   ["}"] = true,
}
local should_indent = {
   ["for"] = true,
   ["if"] = true,
   ["while"] = true,
   ["elseif"] = true,
   ["else"] = true,
   ["function"] = true,
}
function tl.pretty_print_tokens(tokens)
   local y = 1
   local out = {}
   local kind = nil
   local indent = 0
   local bracket = false
   for _, t in ipairs(tokens) do
      while t.y > y do
         if bracket then
            indent = indent + 1
            bracket = false
         end
         table.insert(out, "\n")
         y = y + 1
         kind = nil
      end
      if kind == nil then
         if should_unindent[t.tk] then
            indent = indent - 1
         end
         if indent < 0 then
            indent = 0
         end
         for _ = 1, indent do
            table.insert(out, "   ")
         end
         if should_indent[t.tk] or t.tk == "local" and tokens[_ + 1].tk == "function" then
            indent = indent + 1
         end
      end
      if add_space[(kind or "") .. ":" .. t.kind] then
         table.insert(out, " ")
      end
      table.insert(out, t.tk)
      kind = t.kind
      bracket = t.tk == "{"
   end
   return table.concat(out)
end
local ParseError = tl.record({
   ["y"] = tl.number,
   ["x"] = tl.number,
   ["msg"] = tl.string,
})
local Type = tl.record({
   ["kind"] = tl.string,
   ["typename"] = tl.string,
   ["poly"] = tl.array(tl.nominal("Type")),
   ["tk"] = tl.string,
   ["keys"] = tl.nominal("Type"),
   ["values"] = tl.nominal("Type"),
   ["fields"] = tl.map(tl.string, tl.nominal("Type")),
   ["elements"] = tl.nominal("Type"),
   ["args"] = tl.nominal("Node"),
   ["rets"] = tl.nominal("Node"),
   ["vararg"] = tl.boolean,
})
local Operator = tl.record({
   ["y"] = tl.number,
   ["x"] = tl.number,
   ["arity"] = tl.number,
   ["op"] = tl.string,
   ["prec"] = tl.number,
})
local Node = tl.record({
   ["y"] = tl.number,
   ["x"] = tl.number,
   ["tk"] = tl.string,
   ["kind"] = tl.string,
   ["key"] = tl.nominal("Node"),
   ["value"] = tl.nominal("Node"),
   ["args"] = tl.nominal("Node"),
   ["rets"] = tl.nominal("Node"),
   ["body"] = tl.nominal("Node"),
   ["vararg"] = tl.boolean,
   ["name"] = tl.nominal("Node"),
   ["module"] = tl.nominal("Node"),
   ["exp"] = tl.nominal("Node"),
   ["thenpart"] = tl.nominal("Node"),
   ["elseifs"] = tl.nominal("Node"),
   ["elsepart"] = tl.nominal("Node"),
   ["var"] = tl.nominal("Node"),
   ["from"] = tl.nominal("Node"),
   ["to"] = tl.nominal("Node"),
   ["step"] = tl.nominal("Node"),
   ["vars"] = tl.nominal("Node"),
   ["exps"] = tl.nominal("Node"),
   ["op"] = tl.nominal("Operator"),
   ["e1"] = tl.nominal("Node"),
   ["e2"] = tl.nominal("Node"),
   ["typename"] = tl.string,
   ["type"] = tl.nominal("Type"),
   ["decltype"] = tl.nominal("Type"),
})
local parse_expression
local parse_statements
local parse_argument_list
local function fail(tokens, i, errs)
   local tks = {}
   for x = i, i + 10 do
      if tokens[x] then
         table.insert(tks, tokens[x].tk)
      end
   end
   if not tokens[i] then
      table.insert(errs, {
         ["y"] =- 1,
         ["x"] =- 1,
         ["msg"] = "$EOF$",
      })
      return i + 1
   end
   table.insert(errs, {
      ["y"] = tokens[i].y,
      ["x"] = tokens[i].x,
      ["msg"] = table.concat(tks, " "),
   })
   return i + 1
end
local function verify_tk(tokens, i, errs, tk)
   if tokens[i] and tokens[i].tk == tk then
      return i + 1
   end
   return fail(tokens, i, errs)
end
local function new_node(tokens, i, kind)
   local t = tokens[i]
   return {
      ["y"] = t.y,
      ["x"] = t.x,
      ["tk"] = t.tk,
      ["kind"] = kind or t.kind,
   }
end
local function verify_kind(tokens, i, errs, kind, node_kind)
   if tokens[i].kind == kind then
      return i + 1, new_node(tokens, i, node_kind)
   end
   return fail(tokens, i, errs)
end
local function parse_table_item(tokens, i, errs, n)
   local node = new_node(tokens, i, "table_item")
   if not tokens[i] then
      return fail(tokens, i, errs)
   end
   if tokens[i].tk == "[" then
      i = i + 1
      i, node.key = parse_expression(tokens, i, errs)
      i = verify_tk(tokens, i, errs, "]")
      i = verify_tk(tokens, i, errs, "=")
      i, node.value = parse_expression(tokens, i, errs)
      return i, node, n
   elseif tokens[i].kind == "word" and tokens[i + 1] and tokens[i + 1].tk == "=" then
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
local ParseItem = tl.fun({
   [1] = tl.array(tl.nominal("Token")),
   [2] = tl.number,
   [3] = tl.array(tl.nominal("ParseError")),
   [4] = tl.number,
}, {
   [1] = tl.number,
   [2] = tl.nominal("Node"),
   [3] = tl.number,
})
local function parse_list(tokens, i, errs, node, close, is_sep, parse_item)
   local n = 1
   while tokens[i] do
      if close[tokens[i].tk] then
         break
      end
      local item
      i, item, n = parse_item(tokens, i, errs, n)
      table.insert(node, item)
      if tokens[i] and tokens[i].tk == "," then
         i = i + 1
         if is_sep and close[tokens[i].tk] then
            return fail(tokens, i, errs)
         end
      end
   end
   return i, node
end
local function parse_bracket_list(tokens, i, errs, node_kind, open, close, is_sep, parse_item)
   local node = new_node(tokens, i, node_kind)
   i = verify_tk(tokens, i, errs, open)
   i = parse_list(tokens, i, errs, node, {
      [close] = true,
   }, is_sep, parse_item)
   i = i + 1
   return i, node
end
local function parse_table_literal(tokens, i, errs)
   return parse_bracket_list(tokens, i, errs, "table_literal", "{", "}", false, parse_table_item)
end
local function parse_trying_list(tokens, i, errs, node, parse_item)
   local item
   i, item = parse_item(tokens, i, errs)
   table.insert(node, item)
   if tokens[i] and tokens[i].tk == "," then
      while tokens[i].tk == "," do
         i = i + 1
         i, item = parse_item(tokens, i, errs)
         table.insert(node, item)
      end
   end
   return i, node
end
local parse_type_list
local function parse_type(tokens, i, errs)
   if tokens[i].tk == "string" or tokens[i].tk == "boolean" or tokens[i].tk == "number" then
      return i + 1, {
         ["kind"] = "typedecl",
         ["typename"] = tokens[i].tk,
      }
   elseif tokens[i].tk == "table" then
      return i + 1, {
         ["kind"] = "typedecl",
         ["typename"] = "map",
         ["keys"] = {
            ["typename"] = "any",
         },
         ["values"] = {
            ["typename"] = "any",
         },
      }
   elseif tokens[i].tk == "function" then
      i = i + 1
      local node = {
         ["kind"] = "typedecl",
         ["typename"] = "function",
         ["args"] = {},
         ["rets"] = {},
      }
      if tokens[i].tk == "(" then
         i, node.args = parse_type_list(tokens, i, errs, "(")
         i = verify_tk(tokens, i, errs, ")")
         i, node.rets = parse_type_list(tokens, i, errs)
      else
         node.vararg = true
      end
      return i, node
   elseif tokens[i].tk == "{" then
      i = i + 1
      local node = new_node(tokens, i, "typedecl")
      local t
      i, t = parse_type(tokens, i, errs)
      if tokens[i].tk == "}" then
         node.typename = "array"
         node.elements = t
         i = verify_tk(tokens, i, errs, "}")
      elseif tokens[i].tk == ":" then
         node.typename = "map"
         i = i + 1
         node.keys = t
         i, node.values = parse_type(tokens, i, errs)
         i = verify_tk(tokens, i, errs, "}")
      end
      return i, node
   elseif tokens[i].kind == "word" then
      return i + 1, {
         ["kind"] = "typedecl",
         ["typename"] = "nominal",
         ["name"] = tokens[i].tk,
      }
   end
   return fail(tokens, i, errs)
end
parse_type_list = function (tokens, i, errs, open)
local node = new_node(tokens, i, "type_list")
if tokens[i].tk == (open or ":") then
   i = i + 1
   i = parse_trying_list(tokens, i, errs, node, parse_type)
end
return i, node
end
local function parse_function_value(tokens, i, errs)
   local node = new_node(tokens, i, "function")
   i = verify_tk(tokens, i, errs, "function")
   i, node.args = parse_argument_list(tokens, i, errs)
   i, node.rets = parse_type_list(tokens, i, errs)
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end
local function parse_literal(tokens, i, errs)
   if tokens[i].tk == "{" then
      return parse_table_literal(tokens, i, errs)
   elseif tokens[i].kind == "..." then
      return verify_kind(tokens, i, errs, "...")
   elseif tokens[i].kind == "string" then
      return verify_kind(tokens, i, errs, "string")
   elseif tokens[i].kind == "word" then
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
do
local precedences = {
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
local sentinel = {
   ["op"] = "sentinel",
}
local function is_unop(token)
   return precedences[1][token.tk] ~= nil
end
local function is_binop(token)
   return precedences[2][token.tk] ~= nil
end
local function prec(op)
   if op == sentinel then
      return - 9999
   end
   return precedences[op.arity][op.op]
end
local function pop_operator(operators, operands)
   if operators[#operators].arity == 2 then
      local t2 = table.remove(operands)
      local t1 = table.remove(operands)
      if not t1 or not t2 then
         return false
      end
      local operator = table.remove(operators)
      if operator.op == "@funcall" and t1.op and t1.op.op == ":" then
         operator.op = "@methcall"
         table.insert(operands, {
            ["y"] = t1.y,
            ["x"] = t1.x,
            ["kind"] = "op",
            ["op"] = operator,
            ["e1"] = t1.e1,
            ["method"] = t1.e2,
            ["e2"] = t2,
         })
      else
         table.insert(operands, {
            ["y"] = t1.y,
            ["x"] = t1.x,
            ["kind"] = "op",
            ["op"] = operator,
            ["e1"] = t1,
            ["e2"] = t2,
         })
      end
   else
      local t1 = table.remove(operands)
      table.insert(operands, {
         ["y"] = t1.y,
         ["x"] = t1.x,
         ["kind"] = "op",
         ["op"] = table.remove(operators),
         ["e1"] = t1,
      })
   end
   return true
end
local function push_operator(op, operators, operands)
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
local P
local E
P = function (tokens, i, errs, operators, operands)
if is_unop(tokens[i]) then
   local ok = push_operator({
      ["y"] = tokens[i].y,
      ["x"] = tokens[i].x,
      ["arity"] = 1,
      ["op"] = tokens[i].tk,
   }, operators, operands)
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
   local leaf
   i, leaf = parse_literal(tokens, i, errs)
   if leaf then
      table.insert(operands, leaf)
   end
   return i
end
end
local function push_arguments(tokens, i, errs, operands)
   local args
   i, args = parse_bracket_list(tokens, i, errs, "expression_list", "(", ")", true, parse_expression)
   table.insert(operands, args)
   return i
end
local function push_index(tokens, i, errs, operands)
   local arg
   i = verify_tk(tokens, i, errs, "[")
   i, arg = parse_expression(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "]")
   table.insert(operands, arg)
   return i
end
E = function (tokens, i, errs, operators, operands)
i = P(tokens, i, errs, operators, operands)
while tokens[i] do
   if tokens[i].kind == "string" or tokens[i].kind == "{" then
      local ok = push_operator({
         ["y"] = tokens[i].y,
         ["x"] = tokens[i].x,
         ["arity"] = 2,
         ["op"] = "@funcall",
      }, operators, operands)
      if not ok then
         return fail(tokens, i, errs)
      end
      local arglist = new_node(tokens, i, "argument_list")
      local arg
      if tokens[i].kind == "string" then
         arg = new_node(tokens, i)
         i = i + 1
      else
         i, arg = parse_table_literal(tokens, i, errs)
      end
      table.insert(arglist, arg)
      table.insert(operands, arglist)
   elseif tokens[i].tk == "(" then
      local ok = push_operator({
         ["y"] = tokens[i].y,
         ["x"] = tokens[i].x,
         ["arity"] = 2,
         ["op"] = "@funcall",
      }, operators, operands)
      if not ok then
         return fail(tokens, i, errs)
      end
      i = push_arguments(tokens, i, errs, operands)
   elseif tokens[i].tk == "[" then
      local ok = push_operator({
         ["y"] = tokens[i].y,
         ["x"] = tokens[i].x,
         ["arity"] = 2,
         ["op"] = "@index",
      }, operators, operands)
      if not ok then
         return fail(tokens, i, errs)
      end
      i = push_index(tokens, i, errs, operands)
   elseif is_binop(tokens[i]) then
      local ok = push_operator({
         ["y"] = tokens[i].y,
         ["x"] = tokens[i].x,
         ["arity"] = 2,
         ["op"] = tokens[i].tk,
      }, operators, operands)
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
parse_expression = function (tokens, i, errs)
local operands = {}
local operators = {}
table.insert(operators, sentinel)
i = E(tokens, i, errs, operators, operands)
return i, operands[#operands],0
end
end
local function parse_variable(tokens, i, errs)
   if tokens[i].tk == "..." then
      return verify_kind(tokens, i, errs, "...")
   end
   return verify_kind(tokens, i, errs, "word", "variable")
end
local function parse_argument(tokens, i, errs)
   if tokens[i].tk == "..." then
      return verify_kind(tokens, i, errs, "...")
   end
   local node
   i, node = verify_kind(tokens, i, errs, "word", "variable")
   if tokens[i].tk == ":" then
      i = i + 1
      i, node.decltype = parse_type(tokens, i, errs)
   end
   return i, node,0
end
parse_argument_list = function (tokens, i, errs)
return parse_bracket_list(tokens, i, errs, "argument_list", "(", ")", true, parse_argument)
end
local function parse_local_function(tokens, i, errs)
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
local function parse_function(tokens, i, errs)
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
local function parse_if(tokens, i, errs)
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
      i, node.elsepart = parse_statements(tokens, i, errs)
   end
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end
local function parse_while(tokens, i, errs)
   local node = new_node(tokens, i, "while")
   i = verify_tk(tokens, i, errs, "while")
   i, node.exp = parse_expression(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end
local function parse_fornum(tokens, i, errs)
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
local function parse_forin(tokens, i, errs)
   local node = new_node(tokens, i, "forin")
   i = i + 1
   node.vars = new_node(tokens, i, "variables")
   i, node.vars = parse_list(tokens, i, errs, node.vars, {
      ["in"] = true,
   }, true, parse_variable)
   i = verify_tk(tokens, i, errs, "in")
   i, node.exp = parse_expression(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end
local function parse_for(tokens, i, errs)
   if tokens[i + 2].tk == "=" then
      return parse_fornum(tokens, i, errs)
   else
      return parse_forin(tokens, i, errs)
   end
end
local function parse_repeat(tokens, i, errs)
   local node = new_node(tokens, i, "repeat")
   i = verify_tk(tokens, i, errs, "repeat")
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "until")
   i, node.exp = parse_expression(tokens, i, errs)
   return i, node
end
local function parse_do(tokens, i, errs)
   local node = new_node(tokens, i, "do")
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end
local function parse_break(tokens, i, errs)
   local node = new_node(tokens, i, "break")
   i = verify_tk(tokens, i, errs, "break")
   return i, node
end
local stop_statement_list = {
   ["end"] = true,
   ["else"] = true,
   ["elseif"] = true,
   ["until"] = true,
}
local function parse_return(tokens, i, errs)
   local node = new_node(tokens, i, "return")
   i = verify_tk(tokens, i, errs, "return")
   node.exps = new_node(tokens, i, "expression_list")
   i = parse_list(tokens, i, errs, node.exps, stop_statement_list, true, parse_expression)
   return i, node
end
local function parse_call_or_assignment(tokens, i, errs, is_local)
   local asgn = new_node(tokens, i, "assignment")
   if is_local then
      asgn.kind = "local_declaration"
   end
   asgn.vars = new_node(tokens, i, "variables")
   i = parse_trying_list(tokens, i, errs, asgn.vars, is_local and parse_variable or parse_expression)
   assert(#asgn.vars >= 1)
   local lhs = asgn.vars[1]
   if is_local then
      i, asgn.decltype = parse_type_list(tokens, i, errs)
   end
   if tokens[i] and tokens[i].tk == "=" then
      asgn.exps = new_node(tokens, i, "values")
      repeat
      i = i + 1
      local val
      i, val = parse_expression(tokens, i, errs)
      table.insert(asgn.exps, val)
      until not tokens[i] or tokens[i].tk ~= ","
      return i, asgn
   elseif is_local then
      return i, asgn
   end
   if lhs.op and (lhs.op.op == "@funcall" or lhs.op.op == "@methcall") then
      return i, lhs
   end
   return fail(tokens, i, errs)
end
local function parse_statement(tokens, i, errs)
   if tokens[i].tk == "local" then
      if tokens[i + 1].tk == "function" then
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
parse_statements = function (tokens, i, errs)
local node = new_node(tokens, i, "statements")
while tokens[i] do
   if stop_statement_list[tokens[i].tk] then
      break
   end
   local item
   i, item = parse_statement(tokens, i, errs)
   if not item then
      break
   end
   table.insert(node, item)
end
return i, node
end
function tl.parse_program(tokens, errs)
   return parse_statements(tokens,1, errs)
end
local VisitorCallbacks = tl.record({
   ["before"] = tl.fun({
      [1] = tl.nominal("Node"),
   }, {}),
   ["before_statement"] = tl.fun({
      [1] = tl.nominal("Node"),
   }, {}),
   ["after"] = tl.fun({
      [1] = tl.nominal("Node"),
      [2] = tl.array(tl.nominal("Node")),
   }, {}),
})
local function recurse_ast(ast, visitor)
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
   local xs = {}
   if ast.kind == "statements" or ast.kind == "variables" or ast.kind == "values" or ast.kind == "argument_list" or ast.kind == "expression_list" or ast.kind == "type_list" or ast.kind == "table_literal" then
      for _, child in ipairs(ast) do
         table.insert(xs, recurse_ast(child, visitor) or false)
      end
   elseif ast.kind == "local_declaration" or ast.kind == "assignment" then
      table.insert(xs, recurse_ast(ast.vars, visitor) or false)
      if ast.exps then
         table.insert(xs, recurse_ast(ast.exps, visitor) or false)
      end
   elseif ast.kind == "table_item" then
      table.insert(xs, recurse_ast(ast.key, visitor) or false)
      table.insert(xs, recurse_ast(ast.value, visitor) or false)
   elseif ast.kind == "if" then
      table.insert(xs, recurse_ast(ast.exp, visitor) or false)
      table.insert(xs, recurse_ast(ast.thenpart, visitor) or false)
      local elseifs = {}
      for _, e in ipairs(ast.elseifs) do
         table.insert(elseifs, recurse_ast(e, visitor) or false)
      end
      table.insert(xs, elseifs)
      if ast.elsepart then
         table.insert(xs, recurse_ast(ast.elsepart, visitor) or false)
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
         visitor["forin"].before_statements(ast, xs)
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
   elseif ast.kind == "return" then
      table.insert(xs, recurse_ast(ast.exps, visitor) or false)
   elseif ast.kind == "do" then
      table.insert(xs, recurse_ast(ast.body, visitor) or false)
   elseif ast.kind == "local_function" or ast.kind == "global_function" then
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
         p1 =- 999
      end
      table.insert(xs, p1)
      if ast.op.arity == 2 then
         table.insert(xs, recurse_ast(ast.e2, visitor) or false)
         table.insert(xs, ast.e2.op and ast.e2.op.prec or false)
      end
   elseif ast.kind == "variable" or ast.kind == "word" or ast.kind == "string" or ast.kind == "number" or ast.kind == "break" or ast.kind == "nil" or ast.kind == "..." or ast.kind == "typedecl" or ast.kind == "boolean" then

   else
      if not ast.kind then
         error("wat: " .. inspect(ast))
      end
      error("unknown node kind " .. ast.kind)
   end
   if visitor["@after"] and visitor["@after"].before then
      visitor["@after"].before(ast, xs)
   end
   local ret
   if visitor[ast.kind].after then
      ret = visitor[ast.kind].after(ast, xs)
   end
   if visitor["@after"] and visitor["@after"].after then
      ret = visitor["@after"].after(ast, xs)
   end
   return ret
end
local tight_op = {
   ["."] = true,
   ["-"] = true,
   ["~"] = true,
   ["#"] = true,
}
local spaced_op = {
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
function tl.pretty_print_ast(ast)
   local indent = 0
   local visit = {
      ["statements"] = {
         ["after"] = function (node, children)
         local out = {}
         for _, child in ipairs(children) do
            table.insert(out,("   "):rep(indent))
            table.insert(out, child)
            table.insert(out, "\n")
         end
         if #children == 0 then
            table.insert(out, "\n")
         end
         return table.concat(out)
      end,
   },
   ["local_declaration"] = {
      ["after"] = function (node, children)
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
   ["after"] = function (node, children)
   local out = {}
   table.insert(out, children[1])
   table.insert(out, " = ")
   table.insert(out, children[2])
   return table.concat(out)
end,
},
["if"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
table.insert(out, "if ")
table.insert(out, children[1])
table.insert(out, " then\n")
table.insert(out, children[2])
indent = indent - 1
for _, e in ipairs(children[3]) do
   table.insert(out,("   "):rep(indent))
   table.insert(out, "elseif ")
   table.insert(out, e)
end
if children[4] then
   table.insert(out,("   "):rep(indent))
   table.insert(out, "else\n")
   table.insert(out, children[4])
end
table.insert(out,("   "):rep(indent))
table.insert(out, "end")
return table.concat(out)
end,
},
["while"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
table.insert(out, "while ")
table.insert(out, children[1])
table.insert(out, " do\n")
table.insert(out, children[2])
indent = indent - 1
table.insert(out,("   "):rep(indent))
table.insert(out, "end")
return table.concat(out)
end,
},
["repeat"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
table.insert(out, "repeat\n")
table.insert(out, children[1])
indent = indent - 1
table.insert(out,("   "):rep(indent))
table.insert(out, "until ")
table.insert(out, children[2])
return table.concat(out)
end,
},
["do"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
table.insert(out, "do\n")
table.insert(out, children[1])
indent = indent - 1
table.insert(out,("   "):rep(indent))
table.insert(out, "end")
return table.concat(out)
end,
},
["forin"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
table.insert(out, "for ")
table.insert(out, children[1])
table.insert(out, " in ")
table.insert(out, children[2])
table.insert(out, " do\n")
table.insert(out, children[3])
indent = indent - 1
table.insert(out,("   "):rep(indent))
table.insert(out, "end")
return table.concat(out)
end,
},
["fornum"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
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
table.insert(out,("   "):rep(indent))
table.insert(out, "end")
return table.concat(out)
end,
},
["return"] = {
   ["after"] = function (node, children)
   local out = {}
   table.insert(out, "return ")
   table.insert(out, children[1])
   return table.concat(out)
end,
},
["break"] = {
   ["after"] = function (node, children)
   local out = {}
   table.insert(out, "break")
   return table.concat(out)
end,
},
["elseif"] = {
   ["after"] = function (node, children)
   local out = {}
   table.insert(out, children[1])
   table.insert(out, " then\n")
   table.insert(out, children[2])
   return table.concat(out)
end,
},
["variables"] = {
   ["after"] = function (node, children)
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
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
if #children == 0 then
   indent = indent - 1
   return "{}"
end
table.insert(out, "{\n")
for _, child in ipairs(children) do
   table.insert(out,("   "):rep(indent))
   table.insert(out, child)
   table.insert(out, "\n")
end
indent = indent - 1
table.insert(out,("   "):rep(indent))
table.insert(out, "}")
return table.concat(out)
end,
},
["table_item"] = {
   ["after"] = function (node, children)
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
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
table.insert(out, "local function ")
table.insert(out, children[1])
table.insert(out, "(")
table.insert(out, children[2])
table.insert(out, ")\n")
table.insert(out, children[4])
indent = indent - 1
table.insert(out,("   "):rep(indent))
table.insert(out, "end")
return table.concat(out)
end,
},
["global_function"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
table.insert(out, "function ")
table.insert(out, children[1])
table.insert(out, "(")
table.insert(out, children[2])
table.insert(out, ")\n")
table.insert(out, children[4])
indent = indent - 1
table.insert(out,("   "):rep(indent))
table.insert(out, "end")
return table.concat(out)
end,
},
["module_function"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
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
table.insert(out,("   "):rep(indent))
table.insert(out, "end")
return table.concat(out)
end,
},
["function"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
table.insert(out, "function(")
table.insert(out, children[1])
table.insert(out, ")\n")
table.insert(out, children[3])
indent = indent - 1
table.insert(out,("   "):rep(indent))
table.insert(out, "end")
return table.concat(out)
end,
},
["op"] = {
   ["after"] = function (node, children)
   local out = {}
   if node.op.op == "@funcall" then
      table.insert(out, children[1])
      table.insert(out, "(")
      table.insert(out, children[3])
      table.insert(out, ")")
   elseif node.op.op == "@methcall" then
      if children[2] and node.op.prec > children[2] then
         table.insert(out, "(")
      end
      table.insert(out, children[1])
      if children[2] and node.op.prec > children[2] then
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
      if children[2] and node.op.prec > children[2] then
         table.insert(out, "(")
      end
      table.insert(out, children[1])
      if children[2] and node.op.prec > children[2] then
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
         if children[4] and node.op.prec > children[4] then
            table.insert(out, "(")
         end
         table.insert(out, children[3])
         if children[4] and node.op.prec > children[4] then
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
   ["after"] = function (node, children)
   local out = {}
   table.insert(out, node.tk)
   return table.concat(out)
end,
},
["type_list"] = {
   ["after"] = function ()
   return ""
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
local ANY = {
   ["typename"] = "any",
}
local NIL = {
   ["typename"] = "nil",
}
local ARRAY_OF_ANY = {
   ["typename"] = "array",
   ["elements"] = ANY,
}
local NUMBER = {
   ["typename"] = "number",
}
local STRING = {
   ["typename"] = "string",
}
local BOOLEAN = {
   ["typename"] = "boolean",
}
local FUNCTION = {
   ["typename"] = "function",
   ["vararg"] = true,
   ["args"] = {},
   ["rets"] = {},
}
local INVALID = {
   ["typename"] = "invalid",
}
local numeric_binop = {
   [2] = {
      ["number"] = {
         ["number"] = NUMBER,
      },
   },
}
local relational_binop = {
   [2] = {
      ["number"] = {
         ["number"] = BOOLEAN,
      },
      ["string"] = {
         ["string"] = BOOLEAN,
      },
      ["boolean"] = {
         ["boolean"] = BOOLEAN,
      },
   },
}
local equality_binop = {
   [2] = {
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
         ["record"] = BOOLEAN,
         ["nil"] = BOOLEAN,
      },
      ["array"] = {
         ["array"] = BOOLEAN,
         ["nil"] = BOOLEAN,
      },
      ["map"] = {
         ["map"] = BOOLEAN,
         ["nil"] = BOOLEAN,
      },
   },
}
local boolean_binop = {
   [2] = {
      ["boolean"] = {
         ["boolean"] = BOOLEAN,
         ["function"] = FUNCTION,
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
      ["record"] = {
         ["boolean"] = BOOLEAN,
      },
      ["map"] = {
         ["boolean"] = BOOLEAN,
      },
   },
}
local op_types = {
   ["#"] = {
      [1] = {
         ["string"] = NUMBER,
         ["array"] = NUMBER,
         ["map"] = NUMBER,
      },
   },
   ["+"] = numeric_binop,
   ["-"] = {
      [1] = {
         ["number"] = NUMBER,
      },
      [2] = {
         ["number"] = {
            ["number"] = NUMBER,
         },
      },
   },
   ["*"] = numeric_binop,
   ["/"] = numeric_binop,
   ["=="] = equality_binop,
   ["~="] = equality_binop,
   ["<="] = relational_binop,
   [">="] = relational_binop,
   ["<"] = relational_binop,
   [">"] = relational_binop,
   ["not"] = {
      [1] = {
         ["string"] = BOOLEAN,
         ["boolean"] = BOOLEAN,
         ["record"] = BOOLEAN,
         ["array"] = BOOLEAN,
         ["map"] = BOOLEAN,
      },
   },
   ["or"] = boolean_binop,
   ["and"] = boolean_binop,
   [".."] = {
      [2] = {
         ["string"] = {
            ["string"] = STRING,
            ["number"] = STRING,
         },
         ["number"] = {
            ["number"] = STRING,
            ["string"] = STRING,
         },
      },
   },
}
local tl_type_declarators = {
   ["boolean"] = "boolean",
   ["record"] = "record",
   ["number"] = "number",
   ["string"] = "string",
   ["nominal"] = "nominal",
   ["array"] = "array",
   ["map"] = "map",
   ["fun"] = "function",
}
function tl.type_check(ast)
   local st = {
      [1] = {
         ["require"] = {
            ["typename"] = "function",
            ["args"] = {
               [1] = STRING,
            },
            ["rets"] = {},
         },
         ["table"] = {
            ["typename"] = "record",
            ["fields"] = {
               ["insert"] = {
                  ["typename"] = "poly",
                  ["poly"] = {
                     [1] = {
                        ["typename"] = "function",
                        ["args"] = {
                           [1] = ARRAY_OF_ANY,
                           [2] = NUMBER,
                           [3] = ANY,
                        },
                        ["rets"] = {},
                     },
                     [2] = {
                        ["typename"] = "function",
                        ["args"] = {
                           [1] = ARRAY_OF_ANY,
                           [2] = ANY,
                        },
                        ["rets"] = {},
                     },
                  },
               },
               ["remove"] = {
                  ["typename"] = "poly",
                  ["poly"] = {
                     [1] = {
                        ["typename"] = "function",
                        ["args"] = {
                           [1] = ARRAY_OF_ANY,
                           [2] = NUMBER,
                        },
                        ["rets"] = {
                           [1] = ANY,
                        },
                     },
                     [2] = {
                        ["typename"] = "function",
                        ["args"] = {
                           [1] = ARRAY_OF_ANY,
                        },
                        ["rets"] = {
                           [1] = ANY,
                        },
                     },
                  },
               },
               ["concat"] = {
                  ["typename"] = "poly",
                  ["poly"] = {
                     [1] = {
                        ["typename"] = "function",
                        ["args"] = {
                           [1] = ARRAY_OF_ANY,
                           [2] = STRING,
                        },
                        ["rets"] = {
                           [1] = STRING,
                        },
                     },
                     [2] = {
                        ["typename"] = "function",
                        ["args"] = {
                           [1] = ARRAY_OF_ANY,
                        },
                        ["rets"] = {
                           [1] = STRING,
                        },
                     },
                  },
               },
            },
         },
         ["string"] = {
            ["typename"] = "record",
            ["fields"] = {
               ["sub"] = {
                  ["typename"] = "function",
                  ["args"] = {
                     [1] = STRING,
                     [2] = NUMBER,
                     [3] = NUMBER,
                  },
                  ["rets"] = {
                     [1] = STRING,
                  },
               },
               ["match"] = {
                  ["typename"] = "function",
                  ["args"] = {
                     [1] = STRING,
                     [2] = STRING,
                  },
                  ["rets"] = {
                     [1] = STRING,
                  },
               },
               ["rep"] = {
                  ["typename"] = "function",
                  ["args"] = {
                     [1] = STRING,
                     [2] = NUMBER,
                  },
                  ["rets"] = {
                     [1] = STRING,
                  },
               },
            },
         },
         ["type"] = {
            ["typename"] = "function",
            ["args"] = {
               [1] = ANY,
            },
            ["rets"] = {
               [1] = STRING,
            },
         },
         ["ipairs"] = {
            ["typename"] = "function",
            ["args"] = {
               [1] = ARRAY_OF_ANY,
            },
            ["rets"] = {},
         },
         ["assert"] = {
            ["typename"] = "poly",
            ["poly"] = {
               [1] = {
                  ["typename"] = "function",
                  ["args"] = {
                     [1] = BOOLEAN,
                  },
                  ["rets"] = {},
               },
               [2] = {
                  ["typename"] = "function",
                  ["args"] = {
                     [1] = BOOLEAN,
                     [2] = STRING,
                  },
                  ["rets"] = {},
               },
            },
         },
         ["print"] = {
            ["typename"] = "poly",
            ["poly"] = {
               [1] = {
                  ["typename"] = "function",
                  ["args"] = {
                     [1] = ANY,
                  },
                  ["rets"] = {},
               },
               [2] = {
                  ["typename"] = "function",
                  ["args"] = {
                     [1] = ANY,
                     [2] = ANY,
                  },
                  ["rets"] = {},
               },
               [3] = {
                  ["typename"] = "function",
                  ["args"] = {
                     [1] = ANY,
                     [2] = ANY,
                     [3] = ANY,
                  },
                  ["rets"] = {},
               },
               [4] = {
                  ["typename"] = "function",
                  ["args"] = {
                     [1] = ANY,
                     [2] = ANY,
                     [3] = ANY,
                     [4] = ANY,
                  },
                  ["rets"] = {},
               },
               [5] = {
                  ["typename"] = "function",
                  ["args"] = {
                     [1] = ANY,
                     [2] = ANY,
                     [3] = ANY,
                     [4] = ANY,
                     [5] = ANY,
                  },
                  ["rets"] = {},
               },
            },
         },
         ["tostring"] = {
            ["typename"] = "function",
            ["args"] = {
               [1] = ANY,
            },
            ["rets"] = {
               [1] = STRING,
            },
         },
         ["tonumber"] = {
            ["typename"] = "function",
            ["args"] = {
               [1] = ANY,
            },
            ["rets"] = {
               [1] = NUMBER,
            },
         },
         ["error"] = {
            ["typename"] = "function",
            ["args"] = {
               [1] = STRING,
            },
            ["rets"] = {},
         },
         ["debug"] = {
            ["typename"] = "record",
            ["fields"] = {
               ["traceback"] = {
                  ["typename"] = "function",
                  ["args"] = {},
                  ["rets"] = {
                     [1] = STRING,
                  },
               },
            },
         },
      },
   }
   local errors = {}
   local function find_var(name)
      for i =#st,1,- 1 do
         local scope = st[i]
         if scope[name] then
            return scope[name]
         end
      end
      return {
         ["typename"] = "unknown",
         ["tk"] = name,
      }
   end
   local function resolve_tuple(t)
      if t.typename == "tuple" then
         t = t[1]
      end
      if t == nil then
         return NIL
      end
      return t
   end
   local function resolve_unary(t)
      t = resolve_tuple(t)
      if t.typename == "nominal" then
         local typetype = find_var(t.name)
         if typetype.typename == "typetype" then
            return typetype.type
         else
            return {
               ["typename"] = "bad_nominal",
               ["name"] = t.name,
            }
         end
      end
      return t
   end
   local function same_type(t1, t2)
      assert(type(t1) == "table")
      assert(type(t2) == "table")
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
   local function is_empty_table(t)
      return t.typename == "record" and #t.fields == 0
   end
   local function is_a(t1, t2)
      assert(type(t1) == "table")
      assert(type(t2) == "table")
      if t2.typename ~= "tuple" then
         t1 = resolve_tuple(t1)
      end
      if t2.typename == "any" then
         return true
      elseif t1.typename == "nil" then
         return true
      elseif t1.typename == "nominal" and t2.typename == "nominal" then
         return t1.name == t2.name
      elseif t1.typename == "nominal" or t2.typename == "nominal" then
         t1 = resolve_unary(t1)
         t2 = resolve_unary(t2)
         return is_a(t1, t2)
      elseif is_empty_table(t1) and (t2.typename == "array" or t2.typename == "map") then
         return true
      elseif t1.typename == "array" and t2.typename == "array" then
         return is_a(t1.elements, t2.elements)
      elseif t1.typename == "array" and t2.typename == "map" then
         return is_a(NUMBER, t2.keys) and is_a(t1.elements, t2.values)
      elseif t1.typename == "map" and t2.typename == "array" then
         return is_a(t1.keys, NUMBER) and is_a(t1.values, t2.elements)
      elseif t1.typename == "record" and t2.typename == "map" then
         if not is_a(STRING, t2.keys) then
            return false
         end
         for _, f in ipairs(t1.fields) do
            if not is_a(f, t2.values) then
               return false
            end
         end
         return true
      elseif t1.typename == "map" and t2.typename == "record" then
         if not is_a(t1.keys, STRING) then
            return false
         end
         for _, f in ipairs(t2.fields) do
            if not is_a(t1.values, f) then
               return false
            end
         end
         return true
      elseif t1.typename == "map" and t2.typename == "map" then
         return same_type(t1.values, t2.values)
      elseif t1.typename == "function" and t2.typename == "function" then
         if not t2.vararg and #t1.args >#t2.args then
            return false, "failed on number of arguments"
         end
         if #t1.rets <#t2.rets then
            return false, "failed on number of returns"
         end
         for i = 1,#t1.args do
            if not is_a(t1.args[i], t2.args[i] or ANY) then
               return false, "failed on argument " .. i
            end
         end
         for i = 1,#t2.rets do
            if not same_type(t1.rets[i], t2.rets[i]) then
               return false, "failed on return " .. i
            end
         end
         return true
      elseif t2.typename == "boolean" then
         return true
      elseif t1.typename ~= t2.typename then
         return false
      end
      return true
   end
   local function assert_is_a(node, t1, t2)
      if not is_a(t1, t2) then
         table.insert(errors, {
            ["y"] = node.y,
            ["x"] = node.x,
            ["err"] = "mismatch: " .. (node.tk or node.op.op) .. ": " .. inspect(t1) .. " is not a " .. inspect(t2),
         })
      end
   end
   local function match_func_args(node, func, args, is_method)
      assert(type(func) == "table")
      assert(type(args) == "table")
      func = resolve_unary(func)
      args = args or {}
      local poly = func.typename == "poly" and func or {
         ["poly"] = {
            [1] = func,
         },
      }
      local polyerrs = {}
      local expects = {}
      for p, f in ipairs(poly.poly) do
         if f.typename ~= "function" then
            table.insert(errors, {
               ["y"] = node.y,
               ["x"] = node.x,
               ["err"] = "not a function: " .. inspect(f),
            })
            return INVALID
         end
         table.insert(expects, tostring(#f.args or 0))
         if #args == (#f.args or 0) then
            local ok = true
            for a, arg in ipairs(args) do
               local matches, why_not = is_a(arg, f.args[a])
               if not matches then
                  polyerrs[p] = polyerrs[p] or {}
                  local at = node.e2 and node.e2[a] or node
                  table.insert(polyerrs[p], {
                     ["y"] = at.y,
                     ["x"] = at.x,
                     ["err"] = "error in argument " .. (is_method and a - 1 or a) .. ": " .. inspect(arg) .. " is not a " .. inspect(f.args[a]) .. ": " .. (why_not or ""),
                  })
                  ok = false
                  break
               end
            end
            if ok == true then
               f.rets.typename = "tuple"
               return f.rets
            end
         end
         if #args < (#f.args or 0) then
            local ok = true
            for a, arg in ipairs(args) do
               if not is_a(arg, f.args[a]) then
                  polyerrs[p] = polyerrs[p] or {}
                  table.insert(polyerrs[p], {
                     ["y"] = node.y,
                     ["x"] = node.x,
                     ["err"] = "error in argument " .. (is_method and a - 1 or a) .. ": " .. inspect(arg) .. " is not a " .. inspect(f.args[a]),
                  })
                  ok = false
                  break
               end
            end
            if ok == true then
               f.rets.typename = "tuple"
               return f.rets
            end
         end
         if f.vararg and #args > (#f.args or 0) then
            local ok = true
            for a = 1,#f.args do
               local arg = args[a]
               if not is_a(arg, f.args[a]) then
                  polyerrs[p] = polyerrs[p] or {}
                  table.insert(polyerrs[p], {
                     ["y"] = node.y,
                     ["x"] = node.x,
                     ["err"] = "error in argument " .. (is_method and a - 1 or a) .. ": " .. inspect(arg) .. " is not a " .. inspect(f.args[a]),
                  })
                  ok = false
                  break
               end
            end
            if ok == true then
               f.rets.typename = "tuple"
               return f.rets
            end
         end
      end
      if not next(polyerrs) then
         table.insert(errors, {
            ["y"] = node.y,
            ["x"] = node.x,
            ["err"] = "wrong number of arguments (given " ..#args .. ", expects " .. table.concat(expects, " or ") .. ") => " .. debug.traceback(),
         })
      else
         for _, err in ipairs(polyerrs[next(polyerrs)]) do
            table.insert(errors, err)
         end
      end
      poly.poly[1].rets.typename = "tuple"
      return poly.poly[1].rets
   end
   local function match_record_key(node, tbl, key, orig_tbl)
      assert(type(tbl) == "table")
      assert(type(key) == "table")
      if tbl.typename ~= "record" then
         table.insert(errors, {
            ["y"] = node.y,
            ["x"] = node.x,
            ["err"] = "not a table: " .. inspect(tbl),
         })
         return INVALID
      end
      assert(tbl.fields, "record has no fields!? " .. inspect(tbl))
      if key.typename == "string" or key.typename == "unknown" or key.kind == "variable" then
         if tbl.fields[key.tk] then
            return tbl.fields[key.tk]
         end
      end
      table.insert(errors, {
         ["y"] = node.y,
         ["x"] = node.x,
         ["err"] = "failed indexing record " .. inspect(orig_tbl) .. " with key " .. inspect(key),
      })
      return INVALID
   end
   local function add_var(var, valtype)
      st[#st][var] = valtype
   end
   local function add_global(var, valtype)
      st[1][var] = valtype
   end
   local function begin_function_scope(node)
      table.insert(st, {})
      local args = {}
      for _, arg in ipairs(node.args) do
         local t = arg.decltype or {
            ["typename"] = "unknown",
         }
         table.insert(args, t)
         add_var(arg.tk, t)
      end
      if node.name then
         add_var(node.name.tk, {
            ["typename"] = "function",
            ["args"] = args,
            ["rets"] = node.rets,
         })
      end
   end
   local function end_function_scope()
      table.remove(st)
   end
   local function flatten_list(list)
      local exps = {}
      for i = 1,#list - 1 do
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
   local function extract_type_fields(node, fields)
      local ret = {}
      for k, v in pairs(fields) do
         if v.typename == "typetype" then
            ret[k] = v.type
         else
            table.insert(errors, {
               ["y"] = node.y,
               ["x"] = node.x,
               ["err"] = "expected type declaration in record: " .. k .. "; got " .. inspect(v),
            })
            ret[k] = INVALID
         end
      end
      return ret
   end
   local function extract_type_list(node, types, name)
      local ret = {}
      for i, t in ipairs(types) do
         if t.typename == "typetype" then
            ret[i] = t.type
         else
            table.insert(errors, {
               ["y"] = node.y,
               ["x"] = node.x,
               ["err"] = "expected type declaration in list: " .. i .. "; got " .. inspect(t),
            })
            ret[i] = INVALID
         end
      end
      return ret
   end
   local function declare_tl_type(node, ctor, args)
      if ctor.type.typename == "nominal" and args[1].typename == "string" then
         return {
            ["typename"] = "typetype",
            ["type"] = {
               ["typename"] = "nominal",
               ["name"] = args[1].tk:sub(2,- 2),
            },
         }
      elseif ctor.type.typename == "function" then
         return {
            ["typename"] = "typetype",
            ["type"] = {
               ["typename"] = "function",
               ["args"] = extract_type_list(node, args[1].items or {}, "args"),
               ["rets"] = extract_type_list(node, args[2].items or {}, "rets"),
            },
         }
      elseif ctor.type.typename == "array" and args[1].typename == "typetype" then
         return {
            ["typename"] = "typetype",
            ["type"] = {
               ["typename"] = "array",
               ["elements"] = args[1].type,
            },
         }
      elseif ctor.type.typename == "map" and args[1].typename == "typetype" and args[2].typename == "typetype" then
         return {
            ["typename"] = "typetype",
            ["type"] = {
               ["typename"] = "map",
               ["keys"] = args[1].type,
               ["values"] = args[2].type,
            },
         }
      elseif ctor.type.typename == "record" and args[1].typename == "record" then
         return {
            ["typename"] = "typetype",
            ["type"] = {
               ["typename"] = "record",
               ["fields"] = extract_type_fields(node, args[1].fields),
            },
         }
      end
      return INVALID
   end
   local visit = {
      ["statements"] = {
         ["before"] = function ()
         table.insert(st, {})
      end,
      ["after"] = function (node, children)
      table.remove(st)
      node.type = {
         ["typename"] = "none",
      }
   end,
},
["local_declaration"] = {
   ["after"] = function (node, children)
   for i, var in ipairs(node.vars) do
      local decltype = node.decltype and node.decltype[i]
      local infertype = children[2] and children[2][i]
      if decltype and infertype then
         assert_is_a(node.vars[i], infertype, decltype)
      end
      local t = decltype or infertype or {
         ["typename"] = "unknown",
      }
      add_var(var.tk, t)
   end
   node.type = {
      ["typename"] = "none",
   }
end,
},
["assignment"] = {
   ["after"] = function (node, children)
   local exps = flatten_list(children[2])
   for i, var in ipairs(children[1]) do
      if var then
         local val = exps[i] or NIL
         assert_is_a(node.vars[i], val, var)
      else
         table.insert(errors, {
            ["y"] = node.y,
            ["x"] = node.x,
            ["err"] = "unknown variable",
         })
      end
   end
   node.type = {
      ["typename"] = "none",
   }
end,
},
["if"] = {
   ["after"] = function (node, children)
   node.type = {
      ["typename"] = "none",
   }
end,
},
["while"] = {
   ["after"] = function (node, children)
   node.type = {
      ["typename"] = "none",
   }
end,
},
["repeat"] = {
   ["after"] = function (node, children)
   node.type = {
      ["typename"] = "none",
   }
end,
},
["do"] = {
   ["after"] = function (node)
   node.type = {
      ["typename"] = "none",
   }
end,
},
["forin"] = {
   ["before"] = function ()
   table.insert(st, {})
end,
["before_statements"] = function (node, children)
if node.exp.kind == "op" and node.exp.op.op == "@funcall" and node.exp.e1.tk == "ipairs" then
   local t = resolve_unary(node.exp.e2.type)
   if t.typename == "array" then
      add_var(node.vars[1].tk, NUMBER)
      add_var(node.vars[2].tk, t.elements)
   else
      table.insert(errors, {
         ["y"] = node.y,
         ["x"] = node.x,
         ["err"] = "attempting ipairs loop on something that's not an array: " .. inspect(node.exp.e2.type),
      })
   end
end
end,
["after"] = function (node, children)
table.remove(st)
node.type = {
   ["typename"] = "none",
}
end,
},
["fornum"] = {
   ["before"] = function (node)
   table.insert(st, {})
   add_var(node.var.tk, NUMBER)
end,
["after"] = function (node, children)
table.remove(st)
node.type = {
   ["typename"] = "none",
}
end,
},
["return"] = {
   ["after"] = function (node, children)
   node.type = children[1]
end,
},
["break"] = {
   ["after"] = function (node, children)
   node.type = {
      ["typename"] = "none",
   }
end,
},
["elseif"] = {
   ["after"] = function (node, children)
   node.type = {
      ["typename"] = "none",
   }
end,
},
["variables"] = {
   ["after"] = function (node, children)
   node.type = children
   children.typename = "tuple"
end,
},
["table_literal"] = {
   ["after"] = function (node, children)
   if children[1] and children[1].typename == "iv" then
      node.type = {
         ["typename"] = "array",
         ["items"] = {},
      }
      for _, child in ipairs(children) do
         if child.typename == "iv" then
            if child.i then
               if node.type.elements then
                  if child.v.typename ~= "typetype" and not is_a(child.v, node.type.elements) then
                     table.insert(errors, {
                        ["y"] = node.y,
                        ["x"] = node.x,
                        ["err"] = "type mismatch in array elements",
                     })
                  end
               else
                  node.type.elements = child.v
               end
               node.type.items[tonumber(child.i)] = child.v
            else

            end
         else
            table.insert(errors, {
               ["y"] = node.y,
               ["x"] = node.x,
               ["err"] = "mixing record fields in an array",
            })
         end
      end
   else
      node.type = {
         ["typename"] = "record",
         ["fields"] = {},
      }
      for _, child in ipairs(children) do
         if child.typename == "kv" then
            node.type.fields[child.k] = child.v
         else
            table.insert(errors, {
               ["y"] = node.y,
               ["x"] = node.x,
               ["err"] = "mixing array fields in a record",
            })
         end
      end
   end
end,
},
["table_item"] = {
   ["after"] = function (node, children)
   local key = node.key.tk
   if children[1].typename == "number" then
      node.type = {
         ["typename"] = "iv",
         ["i"] = key,
         ["v"] = children[2],
      }
      return
   end
   if node.key.kind == "string" then
      key = key:sub(2,- 2)
   end
   node.type = {
      ["typename"] = "kv",
      ["k"] = key,
      ["v"] = children[2],
   }
end,
},
["local_function"] = {
   ["before"] = function (node)
   begin_function_scope(node)
end,
["after"] = function (node, children)
end_function_scope()
add_var(node.name.tk, {
   ["typename"] = "function",
   ["args"] = children[2],
   ["rets"] = children[3],
})
node.type = {
   ["typename"] = "none",
}
end,
},
["global_function"] = {
   ["before"] = function ()
   begin_function_scope(node)
end,
["after"] = function (node, children)
end_function_scope()
add_global(node.name.tk, {
   ["typename"] = "function",
   ["args"] = children[2],
   ["rets"] = children[3],
})
node.type = {
   ["typename"] = "none",
}
end,
},
["module_function"] = {
   ["before"] = function (node)
   begin_function_scope(node)
end,
["after"] = function (node, children)
end_function_scope()
local var = find_var(node.module.tk)
if var.typename == "record" then
   var.fields[node.name.tk] = {
      ["typename"] = "function",
      ["args"] = children[3],
      ["rets"] = children[4],
   }
else
   table.insert(errors, {
      ["y"] = node.y,
      ["x"] = node.x,
      ["err"] = "not a module: " .. node.module.tk,
   })
end
node.type = {
   ["typename"] = "none",
}
end,
},
["function"] = {
   ["before"] = function (node)
   begin_function_scope(node)
end,
["after"] = function (node, children)
end_function_scope()
node.type = {
   ["typename"] = "function",
   ["args"] = children[1],
   ["rets"] = children[2],
}
end,
},
["op"] = {
   ["after"] = function (node, children)
   local a = children[1]
   local b = children[3]
   local orig_a = a
   if node.op.op == "@funcall" then
      if a.typename == "typetype" then
         node.type = declare_tl_type(node, a, b)
      else
         node.type = match_func_args(node, a, b, false)
      end
   elseif node.op.op == "@methcall" then
      local obj = a
      if obj.typename == "string" then
         obj = find_var("string")
      end
      local func = match_record_key(node, obj, node.method, orig_a)
      if func.typename == "function" then
         table.insert(b,1, a)
         node.type = match_func_args(node, func, b, true)
      else
         table.insert(errors, {
            ["y"] = node.y,
            ["x"] = node.x,
            ["err"] = "method not found: " .. inspect(node),
         })
         node.type = INVALID
      end
   elseif node.op.op == "@index" then
      a = resolve_unary(a)
      b = resolve_unary(b)
      if a.typename == "array" then
         if is_a(b, NUMBER) then
            node.type = a.elements
         else
            table.insert(errors, {
               ["y"] = node.y,
               ["x"] = node.x,
               ["err"] = "wrong index type: " .. inspect(b) .. ", expected number",
            })
            node.type = INVALID
         end
      elseif a.typename == "map" then
         if is_a(b, a.keys) then
            node.type = a.values
         else
            table.insert(errors, {
               ["y"] = node.y,
               ["x"] = node.x,
               ["err"] = "wrong index type: " .. inspect(b) .. ", expected " .. inspect(a.keys),
            })
            node.type = INVALID
         end
      else
         node.type = match_record_key(node, a, b, orig_a)
      end
   elseif node.op.op == "." then
      if node.e1.tk == "tl" and tl_type_declarators[node.e2.tk] then
         node.type = {
            ["typename"] = "typetype",
            ["type"] = {
               ["typename"] = tl_type_declarators[node.e2.tk],
            },
         }
         return
      end
      a = resolve_unary(a)
      if a.typename == "map" and is_a(STRING, a.keys) then
         if is_a(STRING, a.keys) then
            node.type = a.values
         else
            table.insert(errors, {
               ["y"] = node.y,
               ["x"] = node.x,
               ["err"] = "cannot use . index, expects keys of type " .. inspect(a.keys),
            })
            node.type = INVALID
         end
      else
         node.type = match_record_key(node, a, {
            ["typename"] = "string",
            ["tk"] = node.e2.tk,
         }, orig_a)
      end
   elseif op_types[node.op.op] then
      a = resolve_unary(a)
      local types_op = op_types[node.op.op][node.op.arity]
      if node.op.arity == 1 then
         node.type = types_op[a.typename]
         if not node.type then
            table.insert(errors, {
               ["y"] = node.y,
               ["x"] = node.x,
               ["err"] = "unop mismatch: " .. node.op.op .. " " .. a.typename,
            })
            node.type = INVALID
         end
      elseif node.op.arity == 2 then
         b = resolve_unary(b)
         node.type = types_op[a.typename] and types_op[a.typename][b.typename]
         if not node.type then
            table.insert(errors, {
               ["y"] = node.y,
               ["x"] = node.x,
               ["err"] = "binop mismatch: " .. node.op.op .. " " .. a.typename .. " " .. b.typename,
            })
            node.type = INVALID
         end
      end
   else
      error("unknown node op " .. node.op.op)
   end
end,
},
["variable"] = {
   ["after"] = function (node)
   node.type = find_var(node.tk)
end,
},
["typedecl"] = {
   ["after"] = function (node)
   node.type = node
end,
},
}
visit["values"] = visit["variables"]
visit["expression_list"] = visit["variables"]
visit["argument_list"] = visit["variables"]
visit["type_list"] = visit["variables"]
visit["word"] = visit["variable"]
visit["string"] = {
   ["after"] = function (node)
   node.type = {
      ["typename"] = node.kind,
      ["tk"] = node.tk,
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
   ["after"] = function (node)
   assert(type(node.type) == "table", node.kind .. " did not produce a type")
   assert(type(node.type.typename) == "string", node.kind .. " type does not have a typename")
   return node.type
end,
}
recurse_ast(ast, visit)
return errors
end
return tl
