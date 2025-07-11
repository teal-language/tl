local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local errors = require("teal.errors")


local types = require("teal.types")

local errors = require("teal.errors")


local lexer = require("teal.lexer")

































































































































local reader = {}








local attributes = {
   ["const"] = true,
   ["close"] = true,
   ["total"] = true,
}
local is_attribute = attributes

function reader.node_is_require_call(n)
   if not (n[1] and n[2]) then
      return nil
   end
   if n.kind == "op_dot" then

      return reader.node_is_require_call(n[1])
   elseif n[1].kind == "variable" and n[1].tk == "require" and
      n[2].kind == "expression_list" and #n[2] == 1 and
      n[2][1].kind == "string" then


      return n[2][1].conststr
   end
   return nil
end

function reader.node_is_funcall(node)
   return node.kind == "op_funcall"
end

















local read_type_list
local read_typeargs_if_any
local read_expression
local read_expression_and_tk
local read_statements
local read_argument_list
local read_argument_type_list
local read_type
local read_type_declaration
local read_interface_name


local read_enum_body
local read_record_body
local read_type_body_fns

local function fail(ps, i, msg)
   if not ps.tokens[i] then
      local eof = ps.tokens[#ps.tokens]
      table.insert(ps.errs, { filename = ps.filename, y = eof.y, x = eof.x, msg = msg or "unexpected end of file" })
      return #ps.tokens
   end
   table.insert(ps.errs, { filename = ps.filename, y = ps.tokens[i].y, x = ps.tokens[i].x, msg = assert(msg, "syntax error, but no error message provided") })
   return math.min(#ps.tokens, i + 1)
end

local function end_at(node, tk)
   node.yend = tk.y
   node.xend = tk.x + #tk.tk - 1
end

local function verify_tk(ps, i, tk)
   if ps.tokens[i].tk == tk then
      return i + 1
   end
   return fail(ps, i, "syntax error, expected '" .. tk .. "'")
end

local function verify_end(ps, i, istart, node)
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

local node_mt = {
   __tostring = function(n)
      return n.f .. ":" .. n.y .. ":" .. n.x .. " " .. n.kind
   end,
}

local function new_block(ps, i, kind)
   local t = ps.tokens[i]
   return setmetatable({ f = ps.filename, y = t.y, x = t.x, tk = t.tk, kind = kind or (t.kind) }, node_mt)
end


local function new_type(ps, i, typename)
   local token = ps.tokens[i]
   return setmetatable({
      f = ps.filename,
      y = token.y,
      x = token.x,
      tk = token.tk,
      kind = typename,
      yend = token.y,
      xend = token.x + #token.tk - 1,
   }, node_mt)
end

local function new_generic(ps, i, typeargs, typ)
   local gt = new_type(ps, i, "generic_type")
   gt[1] = typeargs
   gt[2] = typ
   return gt
end

local function new_typedecl(ps, i, def)
   local t = new_type(ps, i, "typedecl")
   t[1] = def
   return t
end

local function new_tuple(ps, i, typelist, is_va)
   local t = new_type(ps, i, "tuple_type")
   if is_va then
      t[1] = new_block(ps, i, "...")
      t[2] = typelist or new_block(ps, i, "typelist")
      return t, t[2]
   else
      t[1] = typelist or new_block(ps, i, "typelist")
      return t, t[1]
   end
end

local function new_nominal(ps, i, name)
   local t = new_type(ps, i, "nominal_type")
   if name then
      t[1] = new_block(ps, i, "identifier")
      t[1].tk = name
   end
   return t
end

local function verify_kind(ps, i, kind, node_kind)
   if ps.tokens[i].kind == kind then
      return i + 1, new_block(ps, i, node_kind)
   end
   return fail(ps, i, "syntax error, expected " .. kind)
end



local function skip(ps, i, skip_fn)
   local err_ps = {
      filename = ps.filename,
      tokens = ps.tokens,
      errs = {},
      required_modules = {},
      read_lang = ps.read_lang,
   }
   return skip_fn(err_ps, i)
end

local function failskip(ps, i, msg, skip_fn, starti)
   local skip_i = skip(ps, starti or i, skip_fn)
   fail(ps, i, msg)
   return skip_i
end

local function read_type_body(ps, i, istart, node, tn)
   local typeargs
   local def
   i, typeargs = read_typeargs_if_any(ps, i)

   def = new_type(ps, istart, tn)

   local ok
   i, ok = read_type_body_fns[tn](ps, i, def)
   if not ok then
      return fail(ps, i, "expected a type")
   end

   i = verify_end(ps, i, istart, node)

   if typeargs then
      return i, new_generic(ps, istart, typeargs, def)
   end

   return i, def
end

local function skip_type_body(ps, i)
   local tn = ps.tokens[i].tk
   i = i + 1
   assert(read_type_body_fns[tn], tn .. " has no parse body function")
   local ii, tt = read_type_body(ps, i, i - 1, {}, tn)
   return ii, not not tt
end

local function read_table_value(ps, i)
   local next_word = ps.tokens[i].tk
   if next_word == "record" or next_word == "interface" then
      local skip_i, e = skip(ps, i, skip_type_body)
      if e then
         fail(ps, i, next_word == "record" and
         "syntax error: this syntax is no longer valid; declare nested record inside a record" or
         "syntax error: cannot declare interface inside a table; use a statement")
         return skip_i, new_block(ps, i, "error_block")
      end
   elseif next_word == "enum" and ps.tokens[i + 1].kind == "string" then
      i = failskip(ps, i, "syntax error: this syntax is no longer valid; declare nested enum inside a record", skip_type_body)
      return i, new_block(ps, i - 1, "error_block")
   end

   local e
   i, e = read_expression(ps, i)
   if not e then
      e = new_block(ps, i - 1, "error_block")
   end
   return i, e
end

local function read_table_item(ps, i, n)
   local node = new_block(ps, i, "literal_table_item")
   if ps.tokens[i].kind == "$EOF$" then
      return fail(ps, i, "unexpected eof")
   end

   if ps.tokens[i].tk == "[" then
      i = i + 1
      i, node[1] = read_expression_and_tk(ps, i, "]")
      i = verify_tk(ps, i, "=")
      i, node[2] = read_table_value(ps, i)
      return i, node, n
   elseif ps.tokens[i].kind == "identifier" then
      if ps.tokens[i + 1].tk == "=" then
         i, node[1] = verify_kind(ps, i, "identifier", "string")
         node[1].conststr = node[1].tk
         node[1].tk = '"' .. node[1].tk .. '"'
         i = verify_tk(ps, i, "=")
         i, node[2] = read_table_value(ps, i)
         return i, node, n
      elseif ps.tokens[i + 1].tk == ":" then
         local orig_i = i
         local try_ps = {
            filename = ps.filename,
            tokens = ps.tokens,
            errs = {},
            required_modules = ps.required_modules,
            read_lang = ps.read_lang,
         }
         i, node[1] = verify_kind(try_ps, i, "identifier", "string")
         node[1].conststr = node[1].tk
         node[1].tk = '"' .. node[1].tk .. '"'
         i = verify_tk(try_ps, i, ":")
         i, node[2] = read_type(try_ps, i)
         if node[2] and ps.tokens[i].tk == "=" then
            i = verify_tk(try_ps, i, "=")
            i, node[3] = read_table_value(try_ps, i)
            if node[3] then
               for _, e in ipairs(try_ps.errs) do
                  table.insert(ps.errs, e)
               end
               return i, node, n
            end
         end

         table.remove(node, 2)
         i = orig_i
      end
   end

   node[1] = new_block(ps, i, "integer")
   node[1].constnum = n
   node[1].tk = tostring(n)
   i, node[2] = read_expression(ps, i)
   if not node[2] then
      return fail(ps, i, "expected an expression")
   end
   return i, node, n + 1
end








local function read_list(ps, i, list, close, sep, read_item)
   local n = 1
   while ps.tokens[i].kind ~= "$EOF$" do
      if close[ps.tokens[i].tk] then
         end_at(list, ps.tokens[i])
         break
      end
      local item
      local oldn = n
      i, item, n = read_item(ps, i, n)
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
         local msg

         if first == ")" and ps.tokens[i].tk == "=" then
            msg = "syntax error, cannot perform an assignment here (did you mean '=='?)"
            i = failskip(ps, i, msg, read_expression, i + 1)
         else
            table.insert(options, "','")
            msg = "syntax error, expected one of: " .. table.concat(options, ", ")
            fail(ps, i, msg)
         end



         if first ~= "}" and ps.tokens[i].y ~= ps.tokens[i - 1].y then

            table.insert(ps.tokens, i, { tk = first, y = ps.tokens[i - 1].y, x = ps.tokens[i - 1].x + 1, kind = "keyword" })
            return i, list
         end
      end
   end
   return i, list
end

local function read_bracket_list(ps, i, list, open, close, sep, read_item)
   i = verify_tk(ps, i, open)
   i = read_list(ps, i, list, { [close] = true }, sep, read_item)
   i = verify_tk(ps, i, close)
   return i, list
end

local function read_table_literal(ps, i)
   local node = new_block(ps, i, "literal_table")
   return read_bracket_list(ps, i, node, "{", "}", "term", read_table_item)
end

local function read_trying_list(ps, i, list, read_item, ret_lookahead)
   local try_ps = {
      filename = ps.filename,
      tokens = ps.tokens,
      errs = {},
      required_modules = ps.required_modules,
      read_lang = ps.read_lang,
   }
   local tryi, item = read_item(try_ps, i)
   if not item then
      return i, list
   end
   for _, e in ipairs(try_ps.errs) do
      table.insert(ps.errs, e)
   end
   i = tryi
   table.insert(list, item)
   while ps.tokens[i].tk == "," and
      (not ret_lookahead or
      (not (ps.tokens[i + 1].kind == "identifier" and
      ps.tokens[i + 2] and ps.tokens[i + 2].tk == ":"))) do

      i = i + 1
      i, item = read_item(ps, i)
      table.insert(list, item)
   end
   return i, list
end

local function read_anglebracket_list(ps, i, read_item)
   local second = ps.tokens[i + 1]
   if second.tk == ">" then
      return fail(ps, i + 1, "type argument list cannot be empty")
   elseif second.tk == ">>" then

      second.tk = ">"
      fail(ps, i + 1, "type argument list cannot be empty")
      return i + 1
   end

   local typelist = new_type(ps, i, "typelist")
   i = verify_tk(ps, i, "<")
   i = read_list(ps, i, typelist, { [">"] = true, [">>"] = true }, "sep", read_item)
   if ps.tokens[i].tk == ">" then
      i = i + 1
   elseif ps.tokens[i].tk == ">>" then

      ps.tokens[i].tk = ">"
   else
      return fail(ps, i, "syntax error, expected '>'")
   end
   return i, typelist
end

local function read_typearg(ps, i)
   local name = ps.tokens[i].tk
   local constraint
   local t = new_type(ps, i, "typeargs")
   i = verify_kind(ps, i, "identifier")
   if ps.tokens[i].tk == "is" then
      i = i + 1
      i, constraint = read_interface_name(ps, i)
   end
   t[1] = new_block(ps, i, "identifier")
   t[1].tk = name
   t[2] = constraint
   return i, t
end

local function read_return_types(ps, i)
   local iprev = i - 1
   local t

   i, t = read_type_list(ps, i, "rets")
   local list = t[2] or t[1]
   if list and #list == 0 then
      t.x = ps.tokens[iprev].x
      t.y = ps.tokens[iprev].y
   end
   return i, t
end

read_typeargs_if_any = function(ps, i)
   if ps.tokens[i].tk == "<" then
      return read_anglebracket_list(ps, i, read_typearg)
   end
   return i
end

local function read_function_type(ps, i)
   local typeargs
   local typ = new_type(ps, i, "function")
   i = i + 1

   i, typeargs = read_typeargs_if_any(ps, i)
   if ps.tokens[i].tk == "(" then
      i, typ[1] = read_argument_type_list(ps, i)
      i, typ[2] = read_return_types(ps, i)
   else
      local any = new_type(ps, i, "nominal_type")
      any.tk = "any"
      local args_typelist = new_block(ps, i, "typelist")
      args_typelist[1] = any
      typ[1] = new_tuple(ps, i, args_typelist, true)

      local rets_typelist = new_block(ps, i, "typelist")
      rets_typelist[1] = any
      typ[2] = new_tuple(ps, i, rets_typelist, true)
   end

   if typeargs then
      return i, new_generic(ps, i, typeargs, typ)
   end

   return i, typ
end

local function read_simple_type_or_nominal(ps, i)
   local tk = ps.tokens[i].tk
   if tk == "table" and ps.tokens[i + 1].tk ~= "." then
      local typ = new_type(ps, i, "map_type")
      local any = new_type(ps, i, "nominal_type")
      any.tk = "any"
      typ[1] = any
      typ[2] = any
      return i + 1, typ
   end

   local typ = new_nominal(ps, i, tk)
   i = i + 1
   while ps.tokens[i].tk == "." do
      i = i + 1
      if ps.tokens[i].kind == "identifier" then
         local nom = new_block(ps, i, "identifier")
         nom.tk = ps.tokens[i].tk
         table.insert(typ, nom)
         i = i + 1
      else
         return fail(ps, i, "syntax error, expected identifier")
      end
   end

   if ps.tokens[i].tk == "<" then
      local t
      i, t = read_anglebracket_list(ps, i, read_type)
      table.insert(typ, t)
   end
   return i, typ
end

local function read_base_type(ps, i)
   local tk = ps.tokens[i].tk
   if ps.tokens[i].kind == "identifier" then
      return read_simple_type_or_nominal(ps, i)
   elseif tk == "{" then
      local istart = i
      i = i + 1
      local t
      i, t = read_type(ps, i)
      if not t then
         return i
      end
      if ps.tokens[i].tk == "}" then
         local decl = new_type(ps, istart, "array_type")
         decl[1] = t
         end_at(decl, ps.tokens[i])
         i = verify_tk(ps, i, "}")
         return i, decl
      elseif ps.tokens[i].tk == "," then
         local decl = new_type(ps, istart, "typelist")
         decl[1] = t
         local n = 2
         repeat
            i = i + 1
            i, decl[n] = read_type(ps, i)
            if not decl[n] then
               break
            end
            n = n + 1
         until ps.tokens[i].tk ~= ","
         end_at(decl, ps.tokens[i])
         i = verify_tk(ps, i, "}")
         return i, decl
      elseif ps.tokens[i].tk == ":" then
         local decl = new_type(ps, istart, "map_type")
         i = i + 1
         decl[1] = t
         i, decl[2] = read_type(ps, i)
         if not decl[2] then
            return i
         end
         end_at(decl, ps.tokens[i])
         i = verify_tk(ps, i, "}")
         return i, decl
      end
      return fail(ps, i, "syntax error; did you forget a '}'?")
   elseif tk == "function" then
      return read_function_type(ps, i)
   elseif tk == "nil" then
      return i + 1, new_type(ps, i, "nil")
   end
   return fail(ps, i, "expected a type")
end

read_type = function(ps, i)
   if ps.tokens[i].tk == "(" then
      i = i + 1
      local t
      i, t = read_type(ps, i)
      i = verify_tk(ps, i, ")")
      return i, t
   end

   local bt
   local istart = i
   i, bt = read_base_type(ps, i)
   if not bt then
      return i
   end
   if ps.tokens[i].tk == "|" then
      local u = new_type(ps, istart, "union_type")
      u[1] = bt
      while ps.tokens[i].tk == "|" do
         i = i + 1
         i, bt = read_base_type(ps, i)
         if not bt then
            return i
         end
         table.insert(u, bt)
      end
      bt = u
   end
   return i, bt
end

read_type_list = function(ps, i, mode)
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
   i = read_trying_list(ps, i, list, read_type, mode == "rets")
   if i == prev_i and ps.tokens[i].tk ~= ")" then
      fail(ps, i - 1, "expected a type list")
   end

   if mode == "rets" and ps.tokens[i].tk == "..." then
      i = i + 1
      local nrets = #list
      if nrets > 0 then
         table.insert(t, new_block(ps, i - 1, "..."))
      else
         fail(ps, i, "unexpected '...'")
      end
   end

   if optional_paren then
      i = verify_tk(ps, i, ")")
   end

   return i, t
end

local function read_function_args_rets_body(ps, i, node)
   local istart = i - 1

   i, node[2] = read_typeargs_if_any(ps, i)

   i, node[3] = read_argument_list(ps, i)
   i, node[4] = read_return_types(ps, i)

   i, node[5] = read_statements(ps, i)
   end_at(node, ps.tokens[i])
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function read_function_value(ps, i)
   local node = new_block(ps, i, "function")
   i = verify_tk(ps, i, "function")
   return read_function_args_rets_body(ps, i, node)
end

local function unquote(str)
   local f = str:sub(1, 1)
   if f == '"' or f == "'" then
      return str:sub(2, -2), false
   end
   f = str:match("^%[=*%[")
   local l = #f + 1
   return str:sub(l, -l), true
end

local function read_literal(ps, i)
   local tk = ps.tokens[i].tk
   local kind = ps.tokens[i].kind
   if kind == "identifier" then
      return verify_kind(ps, i, "identifier", "variable")
   elseif kind == "string" then
      local node = new_block(ps, i, "string")
      node.conststr = unquote(tk)
      return i + 1, node
   elseif kind == "number" or kind == "integer" then
      local n = tonumber(tk)
      local node
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
      return read_function_value(ps, i)
   elseif tk == "{" then
      return read_table_literal(ps, i)
   elseif kind == "..." then
      return verify_kind(ps, i, "...")
   elseif kind == "$ERR$" then
      return fail(ps, i, "invalid token")
   end
   return fail(ps, i, "syntax error")
end

local function node_is_require_call_or_pcall(n)
   local r = reader.node_is_require_call(n)
   if r then
      return r
   end
   if reader.node_is_funcall(n) and
      n[1] and n[1].tk == "pcall" and
      n[2] and #n[2] == 2 and
      n[2][1].kind == "variable" and n[2][1].tk == "require" and
      n[2][2].kind == "string" and n[2][2].conststr then


      return n[2][2].conststr
   end
   return nil
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

   local is_right_assoc = {
      ["^"] = true,
      [".."] = true,
   }

   local op_map = {
      [1] = {
         ["not"] = "op_not",
         ["#"] = "op_len",
         ["-"] = "op_unm",
         ["~"] = "op_bnot",
      },
      [2] = {
         ["or"] = "op_or",
         ["and"] = "op_and",
         ["is"] = "op_is",
         ["<"] = "op_lt",
         [">"] = "op_gt",
         ["<="] = "op_le",
         [">="] = "op_ge",
         ["~="] = "op_ne",
         ["=="] = "op_eq",
         ["|"] = "op_bor",
         ["~"] = "op_bxor",
         ["&"] = "op_band",
         ["<<"] = "op_shl",
         [">>"] = "op_shr",
         [".."] = "op_concat",
         ["+"] = "op_add",
         ["-"] = "op_sub",
         ["*"] = "op_mul",
         ["/"] = "op_div",
         ["//"] = "op_idiv",
         ["%"] = "op_mod",
         ["^"] = "op_pow",
         ["as"] = "op_as",
         ["@funcall"] = "op_funcall",
         ["@index"] = "op_index",
         ["."] = "op_dot",
         [":"] = "op_colon",
      },
   }

   local args_starters = {
      ["("] = true,
      ["{"] = true,
      ["string"] = true,
   }

   local E

   local function after_valid_prefixexp(ps, prevnode, i)
      return ps.tokens[i - 1].kind == ")" or
      prevnode.kind == "op_funcall" or
      prevnode.kind == "op_index" or
      prevnode.kind == "op_dot" or
      prevnode.kind == "op_colon" or
      prevnode.kind == "identifier" or
      prevnode.kind == "variable"
   end



   local function failstore(ps, tkop, e1)
      return { f = ps.filename, y = tkop.y, x = tkop.x, kind = "paren", [1] = e1 }
   end

   local function P(ps, i)
      if ps.tokens[i].kind == "$EOF$" then
         return i
      end
      local e1
      local t1 = ps.tokens[i]
      if precedences[1][t1.tk] ~= nil then
         local op_kind = op_map[1][t1.tk]
         local op_i = i
         i = i + 1
         local prev_i = i
         i, e1 = P(ps, i)
         if not e1 then
            fail(ps, prev_i, "expected an expression")
            return i
         end
         e1 = { f = ps.filename, y = t1.y, x = t1.x, kind = op_kind, [1] = e1, tk = t1.tk }
      elseif ps.tokens[i].tk == "(" then
         i = i + 1
         local prev_i = i
         i, e1 = read_expression_and_tk(ps, i, ")")
         if not e1 then
            fail(ps, prev_i, "expected an expression")
            return i
         end
         e1 = { f = ps.filename, y = t1.y, x = t1.x, kind = "paren", [1] = e1 }
      else
         i, e1 = read_literal(ps, i)
      end

      if not e1 then
         return i
      end

      while true do
         local tkop = ps.tokens[i]
         if tkop.kind == "," or tkop.kind == ")" then
            break
         end
         if tkop.tk == "." or tkop.tk == ":" then
            local op_kind = op_map[2][tkop.tk]

            local prev_i = i

            local key
            i = i + 1
            if ps.tokens[i].kind ~= "identifier" then
               local skipped = skip(ps, i, read_type)
               if skipped > i + 1 then
                  fail(ps, i, "syntax error, cannot declare a type here (missing 'local' or 'global'?)")
                  return skipped, failstore(ps, tkop, e1)
               end
            end
            i, key = verify_kind(ps, i, "identifier")
            if not key then
               return i, failstore(ps, tkop, e1)
            end

            if op_kind == "op_colon" then
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

            e1 = { f = ps.filename, y = tkop.y, x = tkop.x, kind = op_kind, [1] = e1, [2] = key, tk = tkop.tk }
         elseif tkop.tk == "(" then
            local prev_tk = ps.tokens[i - 1]
            if tkop.y > prev_tk.y and ps.read_lang ~= "lua" then
               table.insert(ps.tokens, i, { y = prev_tk.y, x = prev_tk.x + #prev_tk.tk, tk = ";", kind = ";" })
               break
            end

            local op_kind = op_map[2]["@funcall"]

            local prev_i = i

            local args = new_block(ps, i, "expression_list")
            i, args = read_bracket_list(ps, i, args, "(", ")", "sep", read_expression)

            if not after_valid_prefixexp(ps, e1, prev_i) then
               fail(ps, prev_i, "cannot call this expression")
               return i, failstore(ps, tkop, e1)
            end

            e1 = { f = ps.filename, y = args.y, x = args.x, kind = op_kind, [1] = e1, [2] = args, tk = tkop.tk }

            table.insert(ps.required_modules, node_is_require_call_or_pcall(e1))
         elseif tkop.tk == "[" then
            local op_kind = op_map[2]["@index"]

            local prev_i = i

            local idx
            i = i + 1
            i, idx = read_expression_and_tk(ps, i, "]")

            if not after_valid_prefixexp(ps, e1, prev_i) then
               fail(ps, prev_i, "cannot index this expression")
               return i, failstore(ps, tkop, e1)
            end

            e1 = { f = ps.filename, y = tkop.y, x = tkop.x, kind = op_kind, [1] = e1, [2] = idx, tk = tkop.tk }
         elseif tkop.kind == "string" or tkop.kind == "{" then
            local op_kind = op_map[2]["@funcall"]

            local prev_i = i

            local args = new_block(ps, i, "expression_list")
            local argument
            if tkop.kind == "string" then
               argument = new_block(ps, i)
               argument.conststr = unquote(tkop.tk)
               i = i + 1
            else
               i, argument = read_table_literal(ps, i)
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
            e1 = { f = ps.filename, y = args.y, x = args.x, kind = op_kind, [1] = e1, [2] = args, tk = tkop.tk }

            table.insert(ps.required_modules, node_is_require_call_or_pcall(e1))
         elseif tkop.tk == "as" or tkop.tk == "is" then
            local op_kind = op_map[2][tkop.tk]

            i = i + 1
            local cast = new_block(ps, i, "cast")
            if ps.tokens[i].tk == "(" then
               i, cast[1] = read_type_list(ps, i, "casttype")
            else
               i, cast[1] = read_type(ps, i)
            end
            if not cast[1] then
               return i, failstore(ps, tkop, e1)
            end
            e1 = { f = ps.filename, y = tkop.y, x = tkop.x, kind = op_kind, [1] = e1, [2] = cast, conststr = e1.conststr, tk = tkop.tk }
         else
            break
         end
      end

      return i, e1
   end

   E = function(ps, i, lhs, min_precedence)
      local lookahead = ps.tokens[i].tk
      while precedences[2][lookahead] and precedences[2][lookahead] >= min_precedence do
         local op_tk = ps.tokens[i]
         local op_kind = op_map[2][op_tk.tk]
         local op_prec = precedences[2][op_tk.tk]
         i = i + 1
         local rhs
         i, rhs = P(ps, i)
         if not rhs then
            fail(ps, i, "expected an expression")
            return i
         end
         lookahead = ps.tokens[i].tk
         while precedences[2][lookahead] and ((precedences[2][lookahead] > op_prec) or
            (is_right_assoc[lookahead] and (precedences[2][lookahead] == op_prec))) do
            i, rhs = E(ps, i, rhs, precedences[2][lookahead])
            if not rhs then
               fail(ps, i, "expected an expression")
               return i
            end
            lookahead = ps.tokens[i].tk
         end
         lhs = { f = ps.filename, y = op_tk.y, x = op_tk.x, kind = op_kind, [1] = lhs, [2] = rhs, tk = op_tk.tk }
      end
      return i, lhs
   end

   read_expression = function(ps, i)
      local lhs
      local istart = i
      i, lhs = P(ps, i)
      if lhs then
         i, lhs = E(ps, i, lhs, 0)
      end
      if lhs then
         return i, lhs, 0
      end

      if i == istart then
         i = fail(ps, i, "expected an expression")
      end
      return i
   end
end

read_expression_and_tk = function(ps, i, tk)
   local e
   i, e = read_expression(ps, i)
   if not e then
      e = new_block(ps, i - 1, "error_block")
   end
   if ps.tokens[i].tk == tk then
      i = i + 1
   else
      local msg = "syntax error, expected '" .. tk .. "'"
      if ps.tokens[i].tk == "=" then
         msg = "syntax error, cannot perform an assignment here (did you mean '=='?)"
      end


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

local function read_variable_name(ps, i)
   local node
   i, node = verify_kind(ps, i, "identifier")
   if not node then
      return i
   end
   if ps.tokens[i].tk == "<" then
      i = i + 1
      local annotation
      i, annotation = verify_kind(ps, i, "identifier")
      if annotation then
         if not is_attribute[annotation.tk] then
            fail(ps, i, "unknown variable annotation: " .. annotation.tk)
         end
         table.insert(node, annotation)
      else
         fail(ps, i, "expected a variable annotation")
      end
      i = verify_tk(ps, i, ">")
   end
   return i, node
end

local function read_argument(ps, i)
   local node
   if ps.tokens[i].tk == "..." then
      i, node = verify_kind(ps, i, "...", "argument")
   else
      i, node = verify_kind(ps, i, "identifier", "argument")
   end
   if ps.tokens[i].tk == "..." then
      fail(ps, i, "'...' needs to be declared as a typed argument")
   end
   local has_question = false
   local q_i = i
   if ps.tokens[i].tk == "?" then
      has_question = true
      q_i = i
      i = i + 1
   end
   if ps.tokens[i].tk == ":" then
      i = i + 1
      local argtype

      i, argtype = read_type(ps, i)

      if node then
         table.insert(node, argtype)
      end
   end
   if has_question then
      table.insert(node, new_block(ps, q_i, "question"))
   end
   return i, node, 0
end

read_argument_list = function(ps, i)
   local node = new_block(ps, i, "argument_list")
   i, node = read_bracket_list(ps, i, node, "(", ")", "sep", read_argument)
   local opts = false
   local min_arity = 0
   for a, fnarg in ipairs(node) do
      if fnarg.tk == "..." then
         if a ~= #node then
            fail(ps, i, "'...' can only be last argument")
            break
         end
      elseif opts then
         return fail(ps, i, "non-optional arguments cannot follow optional arguments")
      else
         min_arity = min_arity + 1
      end
   end
   return i, node, min_arity
end

local function read_argument_type(ps, i)
   local opt = 0
   local is_va = false
   local argument_name = nil

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

   local typ; i, typ = read_type(ps, i)
   if typ then
      if not is_va and ps.tokens[i].tk == "..." then
         i = i + 1
         is_va = true
         if opt > 0 then
            fail(ps, opt, "cannot mix '?' and '...' in a declaration; '...' already implies optional")
         end
      end
   end

   local t = new_type(ps, i, "argument_type")
   local idx = 1
   if argument_name then
      local name_block = new_block(ps, i, "identifier")
      name_block.tk = argument_name
      t[idx] = name_block
      idx = idx + 1
   end
   t[idx] = typ
   if is_va then t[idx + 1] = new_block(ps, i, "...") end
   if opt > 0 then t[#t + 1] = new_block(ps, opt, "question") end

   return i, t, 0
end

read_argument_type_list = function(ps, i)
   local ars = {}
   i = read_bracket_list(ps, i, ars, "(", ")", "sep", read_argument_type)
   local t, list = new_tuple(ps, i)

   local min_arity = 0
   for l, ar in ipairs(ars) do
      list[l] = ar
   end
   return i, t, min_arity
end

local function read_identifier(ps, i)
   if ps.tokens[i].kind == "identifier" then
      return i + 1, new_block(ps, i, "identifier")
   end
   i = fail(ps, i, "syntax error, expected identifier")
   return i, new_block(ps, i, "error_block")
end

local function read_local_function(ps, i)
   i = verify_tk(ps, i, "local")
   i = verify_tk(ps, i, "function")
   local node = new_block(ps, i - 2, "local_function")
   i, node[1] = read_identifier(ps, i)
   return read_function_args_rets_body(ps, i, node)
end

local function read_if_block(ps, i, node, is_else)
   local block = new_block(ps, i, "if_block")
   i = i + 1
   if not is_else then
      i, block[1] = read_expression_and_tk(ps, i, "then")
      if not block[1] then
         return i
      end
      i, block[2] = read_statements(ps, i)
      if not block[2] then
         return i
      end
   else
      i, block[1] = read_statements(ps, i)
      if not block[1] then
         return i
      end
   end
   block.yend, block.xend = (block[2] or block[1]).yend, (block[2] or block[1]).xend
   table.insert(node[1], block)
   return i, node
end

local function read_if(ps, i)
   local istart = i
   local node = new_block(ps, i, "if")
   node[1] = {}
   i, node = read_if_block(ps, i, node)
   if not node then
      return i
   end
   while ps.tokens[i].tk == "elseif" do
      i, node = read_if_block(ps, i, node)
      if not node then
         return i
      end
   end
   if ps.tokens[i].tk == "else" then
      i, node = read_if_block(ps, i, node, true)
      if not node then
         return i
      end
   end
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function read_while(ps, i)
   local istart = i
   local node = new_block(ps, i, "while")
   i = verify_tk(ps, i, "while")
   i, node[1] = read_expression_and_tk(ps, i, "do")
   i, node[2] = read_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function read_fornum(ps, i)
   local istart = i
   local node = new_block(ps, i, "fornum")
   i = i + 1
   i, node[1] = read_identifier(ps, i)
   i = verify_tk(ps, i, "=")
   i, node[2] = read_expression_and_tk(ps, i, ",")
   i, node[3] = read_expression(ps, i)
   if ps.tokens[i].tk == "," then
      i = i + 1
      i, node[4] = read_expression_and_tk(ps, i, "do")
   else
      i = verify_tk(ps, i, "do")
   end
   i, node[5] = read_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function read_forin(ps, i)
   local istart = i
   local node = new_block(ps, i, "forin")
   i = i + 1
   node[1] = new_block(ps, i, "variable_list")
   i, node[1] = read_list(ps, i, node[1], { ["in"] = true }, "sep", read_identifier)
   i = verify_tk(ps, i, "in")
   node[2] = new_block(ps, i, "expression_list")
   i = read_list(ps, i, node[2], { ["do"] = true }, "sep", read_expression)
   if #node[2] < 1 then
      return fail(ps, i, "missing iterator expression in generic for")
   elseif #node[2] > 3 then
      return fail(ps, i, "too many expressions in generic for")
   end
   i = verify_tk(ps, i, "do")
   i, node[3] = read_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function read_for(ps, i)
   if ps.tokens[i + 1].kind == "identifier" and ps.tokens[i + 2].tk == "=" then
      return read_fornum(ps, i)
   else
      return read_forin(ps, i)
   end
end

local function read_repeat(ps, i)
   local node = new_block(ps, i, "repeat")
   i = verify_tk(ps, i, "repeat")
   i, node[1] = read_statements(ps, i)
   i = verify_tk(ps, i, "until")
   i, node[2] = read_expression(ps, i)
   end_at(node, ps.tokens[i - 1])
   return i, node
end

local function read_do(ps, i)
   local istart = i
   local node = new_block(ps, i, "do")
   i = verify_tk(ps, i, "do")
   i, node[1] = read_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function read_break(ps, i)
   local node = new_block(ps, i, "break")
   i = verify_tk(ps, i, "break")
   return i, node
end

local function read_goto(ps, i)
   local node = new_block(ps, i, "goto")
   i = verify_tk(ps, i, "goto")
   node[1] = new_block(ps, i, "identifier")
   node[1].tk = ps.tokens[i].tk
   i = verify_kind(ps, i, "identifier")
   return i, node
end

local function read_label(ps, i)
   local node = new_block(ps, i, "label")
   i = verify_tk(ps, i, "::")
   node[1] = new_block(ps, i, "identifier")
   node[1].tk = ps.tokens[i].tk
   i = verify_kind(ps, i, "identifier")
   i = verify_tk(ps, i, "::")
   return i, node
end

local stop_statement_list = {
   ["end"] = true,
   ["else"] = true,
   ["elseif"] = true,
   ["until"] = true,
}

local stop_return_list = {
   [";"] = true,
   ["$EOF$"] = true,
}

for k, v in pairs(stop_statement_list) do
   stop_return_list[k] = v
end

local function read_return(ps, i)
   local node = new_block(ps, i, "return")
   i = verify_tk(ps, i, "return")
   node[1] = new_block(ps, i, "expression_list")
   i = read_list(ps, i, node[1], stop_return_list, "sep", read_expression)
   if ps.tokens[i].kind == ";" then
      i = i + 1
      if ps.tokens[i].kind ~= "$EOF$" and not stop_statement_list[ps.tokens[i].kind] then
         return fail(ps, i, "return must be the last statement of its block")
      end
   end
   return i, node
end

local function read_nested_type(ps, i, tn)
   local istart = i
   i = i + 1

   local v
   i, v = verify_kind(ps, i, "identifier", "type_identifier")
   if not v then
      return fail(ps, i, "expected a variable name")
   end

   local nt = new_block(ps, istart, "newtype")

   local ndef
   i, ndef = read_type_body(ps, i, istart, nt, tn)
   if not ndef then
      return i
   end

   table.insert(nt, new_typedecl(ps, istart, ndef))
   local asgn = new_block(ps, istart, "local_type")
   asgn[1] = v
   asgn[2] = nt
   return i, asgn
end

read_enum_body = function(ps, i, def)
   while ps.tokens[i].tk ~= "$EOF$" and ps.tokens[i].tk ~= "end" do
      local item
      i, item = verify_kind(ps, i, "string", "string")
      if item then
         table.insert(def, item)
      end
   end
   return i, true
end

local metamethod_names = {
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

local function read_macroexp(ps, istart, iargs)
   local node = new_block(ps, istart, "macroexp")

   local i
   if ps.tokens[istart + 1].tk == "<" then
      i, node[1] = read_anglebracket_list(ps, istart + 1, read_typearg)
   else
      i = iargs
   end

   i, node[2] = read_argument_list(ps, i)
   i, node[3] = read_return_types(ps, i)
   i = verify_tk(ps, i, "return")
   i, node[4] = read_expression(ps, i)
   end_at(node, ps.tokens[i])
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function read_where_clause(ps, i, def)
   local node = new_block(ps, i, "macroexp")

   node[1] = new_block(ps, i, "argument_list")
   node[1][1] = new_block(ps, i, "argument")
   node[1][1].tk = "self"
   node[1][1][1] = new_type(ps, i, "nominal_type")
   node[1][1][1].tk = "self"
   node[1][1][1][1] = def
   node[2] = new_tuple(ps, i)
   node[2][1] = new_type(ps, i, "boolean")
   i, node[3] = read_expression(ps, i)
   end_at(node, ps.tokens[i - 1])
   return i, node
end

read_interface_name = function(ps, i)
   local istart = i
   local typ


   i, typ = read_simple_type_or_nominal(ps, i)
   if typ.kind ~= "nominal_type" then
      return fail(ps, istart, "expected an interface")
   end

   return i, typ

end

local function read_array_interface_type(ps, i)
   local t
   i, t = read_base_type(ps, i)
   if not t then
      return i
   end
   if t.kind ~= "array_type" then
      fail(ps, i, "expected an array declaration")
      return i
   end
   return i, t
end

local function extract_userdata_from_interface_list(ps, i, interface_list)
   if not interface_list then
      return false
   end
   local is_userdata = false
   for j = #interface_list, 1, -1 do
      local iface = interface_list[j]
      if iface.kind == "nominal_type" and #iface == 1 and iface[1].tk == "userdata" then
         table.remove(interface_list, j)
         if is_userdata then
            fail(ps, i, "duplicated 'userdata' declaration")
         end
         is_userdata = true
      end
   end
   return is_userdata
end

read_record_body = function(ps, i, def)






   if ps.tokens[i].tk == "{" then
      local atype
      i, atype = read_array_interface_type(ps, i)
      if atype then
         def[1] = atype
      end
   end

   if ps.tokens[i].tk == "is" then
      i = i + 1

      if ps.tokens[i].tk == "{" then
         if def[1] then
            return failskip(ps, i, "duplicated declaration of array element type", read_type)
         end
         local atype
         i, atype = read_array_interface_type(ps, i)
         if atype then
            def[1] = atype
         end
         if ps.tokens[i].tk == "," then
            i = i + 1
            def[2] = new_block(ps, i, "interface_list")
            i, def[2] = read_trying_list(ps, i, def[2], read_interface_name)
         else
            def[2] = new_block(ps, i, "interface_list")
         end
      else
         def[2] = new_block(ps, i, "interface_list")
         i, def[2] = read_trying_list(ps, i, def[2], read_interface_name)
      end

      if def[2] and extract_userdata_from_interface_list(ps, i, def[2]) then
         table.insert(def, new_block(ps, i, "userdata"))
      end
   end

   if ps.tokens[i].tk == "where" then
      i = i + 1
      i, def[5] = read_where_clause(ps, i, def)
   end

   local fields = new_block(ps, i, "record_body")
   def[3] = fields
   local meta_fields

   while not (ps.tokens[i].kind == "$EOF$" or ps.tokens[i].tk == "end") do
      local tn = ps.tokens[i].tk
      if ps.tokens[i].tk == "userdata" and ps.tokens[i + 1].tk ~= ":" then
         table.insert(def, new_block(ps, i, "userdata"))
         i = i + 1
      elseif ps.tokens[i].tk == "{" then
         return fail(ps, i, "syntax error: this syntax is no longer valid; declare array interface at the top with 'is {...}'")
      elseif ps.tokens[i].tk == "type" and ps.tokens[i + 1].tk ~= ":" then
         i = i + 1

         local lt
         i, lt = read_type_declaration(ps, i, "local_type")
         if not lt then
            return fail(ps, i, "expected a type definition")
         end

         table.insert(fields, lt)
      elseif read_type_body_fns[tn] and ps.tokens[i + 1].tk ~= ":" then
         if def.kind == ("interface") and tn == "record" then
            i = failskip(ps, i, "interfaces cannot contain record definitions", skip_type_body)
         else
            local lt
            i, lt = read_nested_type(ps, i, tn)
            if lt then
               table.insert(fields, lt)
            end
         end
      else
         local is_metamethod = false
         if ps.tokens[i].tk == "metamethod" and ps.tokens[i + 1].tk ~= ":" then
            is_metamethod = true
            i = i + 1
         end

         local v
         if ps.tokens[i].tk == "[" then
            i = i + 1
            i, v = read_literal(ps, i)
            if v and not v.conststr then
               return fail(ps, i, "expected a string literal")
            end
            i = verify_tk(ps, i, "]")
         else
            i, v = verify_kind(ps, i, "identifier", "variable")
         end
         if not v then
            return fail(ps, i, "expected a variable name")
         end

         if ps.tokens[i].tk == ":" then
            i = i + 1
            local t
            i, t = read_type(ps, i)
            if not t then
               return fail(ps, i, "expected a type")
            end

            local field_name = v.conststr or v.tk
            local current_fields = fields
            if is_metamethod then
               if not meta_fields then
                  meta_fields = new_block(ps, i, "record_body")
                  def[4] = meta_fields
               end
               current_fields = meta_fields
               if not metamethod_names[field_name] then
                  fail(ps, i - 1, "not a valid metamethod: " .. field_name)
               end
            end

            if ps.tokens[i].tk == "=" and ps.tokens[i + 1].tk == "macroexp" then
               local tt = t.kind == "generic_type" and t[2] or t

               if tt.kind == "function" then
                  i, tt[4] = read_macroexp(ps, i + 1, i + 2)
               else
                  fail(ps, i + 1, "macroexp must have a function type")
               end
            end

            local field = new_block(ps, i, "record_field")
            field[1] = v
            field[2] = t
            table.insert(current_fields, field)
         elseif ps.tokens[i].tk == "=" then
            local next_word = ps.tokens[i + 1].tk
            if next_word == "record" or next_word == "enum" then
               return fail(ps, i, "syntax error: this syntax is no longer valid; use '" .. next_word .. " " .. v.tk .. "'")
            elseif next_word == "functiontype" then
               return fail(ps, i, "syntax error: this syntax is no longer valid; use 'type " .. v.tk .. " = function(...")
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

read_type_body_fns = {
   ["interface"] = read_record_body,
   ["record"] = read_record_body,
   ["enum"] = read_enum_body,
}

local function read_newtype(ps, i)
   local node = new_block(ps, i, "newtype")
   local def
   local tn = ps.tokens[i].tk
   local istart = i

   if read_type_body_fns[tn] then
      i, def = read_type_body(ps, i + 1, istart, node, tn)
   else
      i, def = read_type(ps, i)
   end
   if not def then
      return fail(ps, i, "expected a type")
   end

   table.insert(node, new_typedecl(ps, istart, def))

   return i, node
end

local function read_assignment_expression_list(ps, i, asgn)
   asgn[3] = new_block(ps, i, "expression_list")
   repeat
      i = i + 1
      local val
      i, val = read_expression(ps, i)
      if not val then
         if #asgn[3] == 0 then
            asgn[3] = nil
         end
         return i
      end
      table.insert(asgn[3], val)
   until ps.tokens[i].tk ~= ","
   return i, asgn
end

local read_call_or_assignment
do
   local function read_variable(ps, i)
      local node
      i, node = read_expression(ps, i)
      return i, node
   end

   read_call_or_assignment = function(ps, i)
      local exp
      local istart = i
      i, exp = read_expression(ps, i)
      if not exp then
         return i
      end

      if reader.node_is_funcall(exp) then
         return i, exp
      end

      local asgn = new_block(ps, istart, "assignment")
      asgn[1] = new_block(ps, istart, "variable_list")
      asgn[1][1] = exp
      if ps.tokens[i].tk == "," then
         i = i + 1
         i = read_trying_list(ps, i, asgn[1], read_variable)
         if #asgn[1] < 2 then
            return fail(ps, i, "syntax error")
         end
      end

      if ps.tokens[i].tk ~= "=" then
         verify_tk(ps, i, "=")
         return i
      end

      i, asgn = read_assignment_expression_list(ps, i, asgn)
      return i, asgn
   end
end

local function read_variable_declarations(ps, i, node_name)
   local asgn = new_block(ps, i, node_name)

   asgn[1] = new_block(ps, i, "variable_list")
   i = read_trying_list(ps, i, asgn[1], read_variable_name)
   if #asgn[1] == 0 then
      return fail(ps, i, "expected a local variable definition")
   end

   i, asgn[2] = read_type_list(ps, i, "decltuple")

   if ps.tokens[i].tk == "=" then

      local next_word = ps.tokens[i + 1].tk
      local tn = next_word
      if read_type_body_fns[tn] then
         local scope = node_name == "local_declaration" and "local" or "global"
         return failskip(ps, i + 1, "syntax error: this syntax is no longer valid; use '" .. scope .. " " .. next_word .. " " .. asgn[1][1].tk .. "'", skip_type_body)
      elseif next_word == "functiontype" then
         local scope = node_name == "local_declaration" and "local" or "global"
         return failskip(ps, i + 1, "syntax error: this syntax is no longer valid; use '" .. scope .. " type " .. asgn[1][1].tk .. " = function('...", read_function_type)
      end

      i, asgn = read_assignment_expression_list(ps, i, asgn)
   end
   return i, asgn
end

local function read_type_require(ps, i, asgn)
   local istart = i
   i, asgn[2] = read_expression(ps, i)
   if not asgn[2] then
      return i
   end
   if asgn[2].kind ~= "op_funcall" and asgn[2].kind ~= "op_dot" and asgn[2].kind ~= "variable" then
      fail(ps, istart, "require() in type declarations cannot be part of larger expressions")
      return i
   end
   if not reader.node_is_require_call(asgn[2]) then
      fail(ps, istart, "require() for type declarations must have a literal argument")
      return i
   end
   return i, asgn
end

local function read_special_type_declaration(ps, i, asgn)
   if ps.tokens[i].tk == "require" then
      return true, read_type_require(ps, i, asgn)
   elseif ps.tokens[i].tk == "pcall" then
      fail(ps, i, "pcall() cannot be used in type declarations")
      return true, i
   end
   return false, i, asgn
end

read_type_declaration = function(ps, i, node_name)
   local asgn = new_block(ps, i, node_name)
   local var

   i, var = verify_kind(ps, i, "identifier")
   if not var then
      return fail(ps, i, "expected a type name")
   end
   local typeargs
   local itypeargs = i
   i, typeargs = read_typeargs_if_any(ps, i)

   asgn[1] = var

   if node_name == "global_type" and ps.tokens[i].tk ~= "=" then
      return i, asgn
   end

   i = verify_tk(ps, i, "=")
   local istart = i

   if ps.tokens[i].kind == "identifier" then
      local is_done
      is_done, i, asgn = read_special_type_declaration(ps, i, asgn)
      if is_done then
         return i, asgn
      end
   end

   i, asgn[2] = read_newtype(ps, i)
   if not asgn[2] then
      return i
   end

   if typeargs and asgn[2][1] and asgn[2][1][1] then
      asgn[2][1][1] = new_generic(ps, itypeargs, typeargs, asgn[2][1][1])
   end

   return i, asgn
end

local function read_type_constructor(ps, i, node_name, tn)
   local asgn = new_block(ps, i, node_name)
   local nt = new_block(ps, i, "newtype")
   asgn[2] = nt
   local istart = i
   local def

   i = i + 2

   i, asgn[1] = verify_kind(ps, i, "identifier")
   if not asgn[1] then
      return fail(ps, i, "expected a type name")
   end

   i, def = read_type_body(ps, i, istart, nt, tn)
   if not def then
      return i
   end

   table.insert(nt, new_typedecl(ps, istart, def))

   return i, asgn
end

local function skip_type_declaration(ps, i)
   return read_type_declaration(ps, i + 1, "local_type")
end

local function read_local_macroexp(ps, i)
   local istart = i
   i = i + 2
   local node = new_block(ps, i, "local_macroexp")
   i, node[1] = read_identifier(ps, i)
   i, node[2] = read_macroexp(ps, istart, i)
   end_at(node, ps.tokens[i - 1])
   return i, node
end

local function read_local(ps, i)
   local ntk = ps.tokens[i + 1].tk
   if ntk == "function" then
      return read_local_function(ps, i)
   elseif ntk == "type" and ps.tokens[i + 2].kind == "identifier" then
      return read_type_declaration(ps, i + 2, "local_type")
   elseif ntk == "macroexp" and ps.tokens[i + 2].kind == "identifier" then
      return read_local_macroexp(ps, i)
   elseif read_type_body_fns[ntk] and ps.tokens[i + 2].kind == "identifier" then
      return read_type_constructor(ps, i, "local_type", ntk)
   end
   return read_variable_declarations(ps, i + 1, "local_declaration")
end

local function read_global(ps, i)
   local ntk = ps.tokens[i + 1].tk
   if ntk == "function" then
      i = verify_tk(ps, i, "global")
      i = verify_tk(ps, i, "function")
      local fn = new_block(ps, i - 2, "global_function")
      i, fn[1] = read_identifier(ps, i)
      return read_function_args_rets_body(ps, i, fn)
   elseif ntk == "type" and ps.tokens[i + 2].kind == "identifier" then
      return read_type_declaration(ps, i + 2, "global_type")
   elseif read_type_body_fns[ntk] and ps.tokens[i + 2].kind == "identifier" then
      return read_type_constructor(ps, i, "global_type", ntk)
   elseif ps.tokens[i + 1].kind == "identifier" then
      return read_variable_declarations(ps, i + 1, "global_declaration")
   end
   return read_call_or_assignment(ps, i)
end

local function read_record_function(ps, i)
   i = verify_tk(ps, i, "function")

   local fn = new_block(ps, i - 1, "record_function")

   local names = {}
   local dot_pos = {}

   i, names[1] = read_identifier(ps, i)

   while ps.tokens[i] and ps.tokens[i].tk == "." do
      table.insert(dot_pos, i)
      i = i + 1
      i, names[#names + 1] = read_identifier(ps, i)
   end

   if ps.tokens[i] and ps.tokens[i].tk == ":" then
      fn.tk = ":"
      i = i + 1
      i, names[#names + 1] = read_identifier(ps, i)
   end

   if #names > 1 or fn.tk == ":" then
      local owner = names[1]
      for n = 2, #names - 1 do
         local dot_block = new_block(ps, dot_pos[n - 1], "op_dot")
         dot_block[1] = owner
         dot_block[2] = names[n]
         owner = dot_block
      end
      fn[1] = owner
      fn[2] = names[#names]
   else
      fn[1] = names[1]
   end

   local istart = i - 1
   i, fn[3] = read_typeargs_if_any(ps, i)
   i, fn[4] = read_argument_list(ps, i)
   i, fn[5] = read_return_types(ps, i)
   i, fn[6] = read_statements(ps, i)

   end_at(fn, ps.tokens[i])
   i = verify_end(ps, i, istart, fn)
   return i, fn
end

local function read_pragma(ps, i)
   i = i + 1
   local pragma = new_block(ps, i, "pragma")

   if ps.tokens[i].kind ~= "pragma_identifier" then
      return fail(ps, i, "expected pragma name")
   end
   pragma[1] = new_block(ps, i, "identifier")
   pragma[1].tk = ps.tokens[i].tk
   i = i + 1

   if ps.tokens[i].kind ~= "pragma_identifier" then
      return fail(ps, i, "expected pragma value")
   end
   pragma[2] = new_block(ps, i, "identifier")
   pragma[2].tk = ps.tokens[i].tk
   i = i + 1

   return i, pragma
end

local read_statement_fns = {
   ["--#pragma"] = read_pragma,
   ["::"] = read_label,
   ["do"] = read_do,
   ["if"] = read_if,
   ["for"] = read_for,
   ["goto"] = read_goto,
   ["local"] = read_local,
   ["while"] = read_while,
   ["break"] = read_break,
   ["global"] = read_global,
   ["repeat"] = read_repeat,
   ["return"] = read_return,
   ["function"] = read_record_function,
}

local function type_needs_local_or_global(ps, i)
   local tk = ps.tokens[i].tk
   return failskip(ps, i, ("%s needs to be declared with 'local %s' or 'global %s'"):format(tk, tk, tk), skip_type_body)
end

local needs_local_or_global = {
   ["type"] = function(ps, i)
      return failskip(ps, i, "types need to be declared with 'local type' or 'global type'", skip_type_declaration)
   end,
   ["record"] = type_needs_local_or_global,
   ["enum"] = type_needs_local_or_global,
}

read_statements = function(ps, i, toplevel)
   local node = new_block(ps, i, "statements")
   local item
   while true do
      while ps.tokens[i].kind == ";" do
         i = i + 1
         if item then
            table.insert(item, new_block(ps, i - 1, ";"))
         end
      end

      if ps.tokens[i].kind == "$EOF$" then
         break
      end
      local tk = ps.tokens[i].tk
      if (not toplevel) and stop_statement_list[tk] then
         break
      end

      local fn = read_statement_fns[tk]
      if not fn then
         local skip_fn = needs_local_or_global[tk]
         if skip_fn and ps.tokens[i + 1].kind == "identifier" then
            fn = skip_fn
         else
            fn = read_call_or_assignment
         end
      end

      i, item = fn(ps, i)

      if item then
         table.insert(node, item)
      elseif i > 1 then

         local lasty = ps.tokens[i - 1].y
         while ps.tokens[i].kind ~= "$EOF$" and ps.tokens[i].y == lasty do
            i = i + 1
         end
      end
   end

   end_at(node, ps.tokens[i])
   return i, node
end

function reader.read_program(tokens, errs, filename, read_lang)
   errs = errs or {}
   local ps = {
      tokens = tokens,
      errs = errs,
      filename = filename or "",
      required_modules = {},
      read_lang = read_lang,
   }
   local i = 1
   local hashbang
   if ps.tokens[i].kind == "hashbang" then
      hashbang = ps.tokens[i].tk
      i = i + 1
   end
   local _, node = read_statements(ps, i, true)
   if hashbang then
      table.insert(node, 1, new_block(ps, 1, "hashbang"))
   end

   errors.clear_redundant_errors(errs)
   return node, ps.required_modules
end

function reader.read(input, filename, read_lang)
   local tokens, errs = lexer.lex(input, filename)
   local node, required_modules = reader.read_program(tokens, errs, filename, read_lang)
   return node, errs, required_modules
end

return reader
