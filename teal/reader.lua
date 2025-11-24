local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local errors = require("teal.errors")




local lexer = require("teal.lexer")




local block = require("teal.block")



local macro_eval = require("teal.macro_eval")












local reader = {}










local BLOCK_INDEXES = block.BLOCK_INDEXES

reader.BLOCK_INDEXES = BLOCK_INDEXES

local function lang_heuristic(filename, input)
   if filename then
      local pattern = "(.*)%.([a-z]+)$"
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

local function normalize_macro_tokens(tokens, errs)
   local filtered = {}
   for _, e in ipairs(errs or {}) do
      local msg = e.msg or ""
      if not (msg:find("invalid token '!'") or msg:find("invalid token '`'") or msg:find("invalid token '$'")) then
         table.insert(filtered, e)
      end
   end

   for _, t in ipairs(tokens) do
      if t.kind == "$ERR$" then
         if t.tk == "!" then
            t.kind = "op"
         elseif t.tk:sub(1, 1) == "`" then
            t.kind = "op"
         elseif t.tk == "$" then
            t.kind = "identifier"
         end
      end
   end
   if errs then
      for i = #errs, 1, -1 do
         errs[i] = nil
      end
      for i = 1, #filtered do
         errs[i] = filtered[i]
      end
      return errs
   end
   return filtered
end

local function is_macro_quote_token(t)
   return t.kind == "`" or t.tk:sub(1, 1) == "`"
end

local attributes = {
   ["const"] = true,
   ["close"] = true,
   ["total"] = true,
}
local is_attribute = attributes

function reader.node_is_require_call(n)
   if not (n[BLOCK_INDEXES.OP.E1] and n[BLOCK_INDEXES.OP.E2]) then
      return nil
   end
   if n.kind == "op_dot" then

      return reader.node_is_require_call(n[BLOCK_INDEXES.OP.E1])
   elseif n[BLOCK_INDEXES.OP.E1].kind == "variable" and n[BLOCK_INDEXES.OP.E1].tk == "require" and
      n[BLOCK_INDEXES.OP.E2].kind == "expression_list" and #n[BLOCK_INDEXES.OP.E2] == 1 and
      n[BLOCK_INDEXES.OP.E2][BLOCK_INDEXES.EXPRESSION_LIST.FIRST].kind == "string" then


      return n[BLOCK_INDEXES.OP.E2][BLOCK_INDEXES.EXPRESSION_LIST.FIRST].conststr
   end
   return nil
end

function reader.node_is_funcall(node)
   if node.kind == "paren" and node[BLOCK_INDEXES.PAREN.EXP] then
      return reader.node_is_funcall(node[BLOCK_INDEXES.PAREN.EXP])
   end
   return node.kind == "op_funcall" or node.kind == "macro_invocation"
end




















local read_type_list
local read_typeargs_if_any
local read_expression
local read_expression_and_tk
local read_statements
local read_argument_list
local read_argument_type_list
local read_macro_quote
local read_type
local read_type_declaration
local read_interface_name
local read_statement_argblock
local read_statement_fns
local needs_local_or_global
local read_nested_type
local read_call_or_assignment
local read_record_function


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

local function make_comment_block(ps, c)
   local text = c.text
   local _, newlines = string.gsub(text, "\n", "")
   local last_line = text:match("([^\n]*)$") or ""
   local cb = {
      f = ps.filename,
      y = c.y,
      x = c.x,
      tk = text,
      conststr = text,
      kind = "comment",
      yend = c.y + newlines,
      xend = newlines > 0 and #last_line or (c.x + #text - 1),
   }
   return setmetatable(cb, node_mt)
end

local function collect_comment_blocks(ps, i)
   local t = ps.tokens[i]
   if not (t and t.comments) then
      return {}
   end
   local out = {}
   for _, c in ipairs(t.comments) do
      table.insert(out, make_comment_block(ps, c))
   end
   return out
end

local function new_generic(ps, i, typeargs, typ)
   local gt = new_type(ps, i, "generic_type")
   gt[BLOCK_INDEXES.GENERIC_TYPE.TYPEARGS] = typeargs
   gt[BLOCK_INDEXES.GENERIC_TYPE.BASE] = typ
   return gt
end

local function new_typedecl(ps, i, def)
   local t = new_type(ps, i, "typedecl")
   t[BLOCK_INDEXES.TYPEDECL.TYPE] = def
   return t
end

local function new_tuple(ps, i, typelist, is_va)
   local t = new_type(ps, i, "tuple_type")
   if is_va then
      t[BLOCK_INDEXES.TUPLE_TYPE.FIRST] = new_block(ps, i, "...")
      t[BLOCK_INDEXES.TUPLE_TYPE.SECOND] = typelist or new_block(ps, i, "typelist")
      return t, t[BLOCK_INDEXES.TUPLE_TYPE.SECOND]
   else
      t[BLOCK_INDEXES.TUPLE_TYPE.FIRST] = typelist or new_block(ps, i, "typelist")
      return t, t[BLOCK_INDEXES.TUPLE_TYPE.FIRST]
   end
end

local function new_nominal(ps, i, name)
   local t = new_type(ps, i, "nominal_type")
   if name then
      t[BLOCK_INDEXES.NOMINAL_TYPE.NAME] = new_block(ps, i, "identifier")
      t[BLOCK_INDEXES.NOMINAL_TYPE.NAME].tk = name
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
      i, node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY] = read_expression_and_tk(ps, i, "]")
      i = verify_tk(ps, i, "=")
      i, node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.VALUE] = read_table_value(ps, i)
      return i, node, n
   elseif ps.tokens[i].kind == "identifier" then
      if ps.tokens[i + 1].tk == "=" then
         i, node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY] = verify_kind(ps, i, "identifier", "string")
         node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY].conststr = node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY].tk
         node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY].tk = '"' .. node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY].tk .. '"'
         i = verify_tk(ps, i, "=")
         i, node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.VALUE] = read_table_value(ps, i)
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
         i, node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY] = verify_kind(try_ps, i, "identifier", "string")
         node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY].conststr = node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY].tk
         node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY].tk = '"' .. node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY].tk .. '"'
         i = verify_tk(try_ps, i, ":")
         i, node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.VALUE] = read_type(try_ps, i)
         if node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.VALUE] and ps.tokens[i].tk == "=" then
            i = verify_tk(try_ps, i, "=")
            i, node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.TYPED_VALUE] = read_table_value(try_ps, i)
            if node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.TYPED_VALUE] then
               for _, e in ipairs(try_ps.errs) do
                  table.insert(ps.errs, e)
               end
               return i, node, n
            end
         end

         table.remove(node, BLOCK_INDEXES.LITERAL_TABLE_ITEM.VALUE)
         i = orig_i
      end
   end

   node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY] = new_block(ps, i, "integer")
   node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY].constnum = n
   node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY].tk = tostring(n)
   i, node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.VALUE] = read_expression(ps, i)
   if not node[BLOCK_INDEXES.LITERAL_TABLE_ITEM.VALUE] then
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

local function read_macro_args_with_sig(ps, i, sig, mname)
   local node = new_block(ps, i, "expression_list")
   local function read_item(ps2, ii, n)
      local expected
      if sig then
         expected = sig.kinds[n] or (sig.vararg ~= "" and sig.vararg or nil)
      end
      if expected == "stmt" then
         if is_macro_quote_token(ps2.tokens[ii]) then
            local ni, q = read_macro_quote(ps2, ii)
            return ni, q, n + 1
         else
            local tk0 = ps2.tokens[ii].tk
            local curr_i = ii
            local sblk
            while read_type_body_fns[tk0] and ps2.tokens[curr_i + 1] and ps2.tokens[curr_i + 1].kind == "identifier" do
               local ni
               local lt
               ni, lt = read_nested_type(ps2, curr_i, tk0)
               if not sblk then sblk = new_block(ps2, curr_i, "statements") end
               table.insert(sblk, lt)
               curr_i = ni
               tk0 = ps2.tokens[curr_i].tk
            end

            local j = sblk and curr_i or ii
            local paren_depth = 0
            local seen_top_level_comma = false
            local best_j
            local best_block
            local need_do_end_error = false
            local can_split_on_comma = false
            if sig then
               local fixed = #sig.kinds
               local has_vararg_stmt = sig.vararg == "stmt"
               if (n <= fixed - 1) or has_vararg_stmt then
                  can_split_on_comma = true
               end
            end

            local function try_parse_until(jend)
               local slice = {}
               local nt = 0
               for k = ii, jend - 1 do
                  nt = nt + 1
                  slice[nt] = ps2.tokens[k]
               end
               nt = nt + 1
               local eof_prev = ps2.tokens[math.max(ii, jend - 1)]
               slice[nt] = { x = eof_prev.x, y = eof_prev.y, tk = "$EOF$", kind = "$EOF$" }
               local errs2 = {}
               local block, _req = reader.read_program(slice, errs2, ps2.filename, ps2.read_lang, true)
               if #errs2 == 0 and block then
                  best_j = jend
                  best_block = block
                  return true
               end
               return false
            end

            while ps2.tokens[j].kind ~= "$EOF$" do
               local t = ps2.tokens[j].tk
               if t == "(" then
                  paren_depth = paren_depth + 1
               elseif t == ")" then
                  if paren_depth == 0 then
                     if try_parse_until(j) then
                        break
                     end
                     break
                  end
                  paren_depth = paren_depth - 1
               elseif t == "," and paren_depth == 0 then
                  seen_top_level_comma = true
                  if can_split_on_comma then
                     if try_parse_until(j) then
                        best_j = j
                     end
                  end
               end
               j = j + 1
            end

            if not best_block then

               local slice = {}
               local nt = 0
               for k = (sblk and curr_i or ii), j - 1 do
                  nt = nt + 1
                  slice[nt] = ps2.tokens[k]
               end
               nt = nt + 1
               local eof_prev = ps2.tokens[math.max(ii, j - 1)]
               slice[nt] = { x = eof_prev.x, y = eof_prev.y, tk = "$EOF$", kind = "$EOF$" }
               local errs2 = {}
               local block_fallback, _req = reader.read_program(slice, errs2, ps2.filename, ps2.read_lang, true)
               for _, e in ipairs(errs2) do table.insert(ps2.errs, e) end
               best_block = block_fallback
               best_j = j
            end


            if best_block and best_block.kind == "statements" and #best_block == 1 then
               local st = best_block[1]
               if st and st.kind == "local_declaration" then
                  local BIDX = BLOCK_INDEXES
                  local vlist = st[BIDX.LOCAL_DECLARATION.VARS]
                  local exps = st[BIDX.LOCAL_DECLARATION.EXPS]
                  local has_top_level_comma = false
                  if vlist and #vlist > 1 then has_top_level_comma = true end
                  if exps and #exps > 1 then has_top_level_comma = true end
                  if has_top_level_comma then
                     need_do_end_error = true
                  end
               end
            end

            if need_do_end_error then
               local st = best_block and best_block[1]
               local basey = ps2.tokens[ii].y
               local ey = basey - 1
               if ey < 1 then ey = (st and st.y) or basey end
               table.insert(ps2.errs, { filename = ps2.filename, y = ey, x = 0, msg = "wrap the statement in 'do ... end'" })
            end

            if sblk and best_block and best_block.kind == "statements" then
               for idx = 1, #best_block do
                  table.insert(sblk, best_block[idx])
               end
               end_at(sblk, ps2.tokens[best_j])
               return best_j, sblk, n + 1
            else
               return best_j, best_block, n + 1
            end
         end
      else
         local ni, e = read_expression(ps2, ii)
         return ni, e, n + 1
      end
   end
   i, node = read_bracket_list(ps, i, node, "(", ")", "sep", read_item)
   return i, node
end

local function read_trying_list(ps, i, list, read_item, ret_lookahead)
   local try_ps = {
      filename = ps.filename,
      tokens = ps.tokens,
      errs = {},
      required_modules = ps.required_modules,
      read_lang = ps.read_lang,
      allow_macro_vars = ps.allow_macro_vars,
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
   t[BLOCK_INDEXES.TYPEARG.NAME] = new_block(ps, i, "identifier")
   t[BLOCK_INDEXES.TYPEARG.NAME].tk = name
   t[BLOCK_INDEXES.TYPEARG.CONSTRAINT] = constraint
   return i, t
end

local function read_return_types(ps, i)
   local iprev = i - 1
   local t

   i, t = read_type_list(ps, i, "rets")
   local list = t[BLOCK_INDEXES.TUPLE_TYPE.SECOND] or t[BLOCK_INDEXES.TUPLE_TYPE.FIRST]
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
      i, typ[BLOCK_INDEXES.FUNCTION_TYPE.ARGS] = read_argument_type_list(ps, i)
      i, typ[BLOCK_INDEXES.FUNCTION_TYPE.RETS] = read_return_types(ps, i)
   else
      local any = new_type(ps, i, "nominal_type")
      any.tk = "any"
      local args_typelist = new_block(ps, i, "typelist")
      args_typelist[BLOCK_INDEXES.TYPELIST.FIRST] = any
      typ[BLOCK_INDEXES.FUNCTION_TYPE.ARGS] = new_tuple(ps, i, args_typelist, true)

      local rets_typelist = new_block(ps, i, "typelist")
      rets_typelist[BLOCK_INDEXES.TYPELIST.FIRST] = any
      typ[BLOCK_INDEXES.FUNCTION_TYPE.RETS] = new_tuple(ps, i, rets_typelist, true)
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
      typ[BLOCK_INDEXES.MAP_TYPE.KEYS] = any
      typ[BLOCK_INDEXES.MAP_TYPE.VALUES] = any
      return i + 1, typ
   end

   local typ
   if ps.allow_macro_vars and tk == "$" then
      local dtk = ps.tokens[i]
      i = i + 1
      local ident
      i, ident = verify_kind(ps, i, "identifier")
      if not ident then
         return fail(ps, i, "syntax error, expected identifier")
      end
      typ = new_nominal(ps, i - 1, nil)
      typ[BLOCK_INDEXES.NOMINAL_TYPE.NAME] = { f = ps.filename, y = dtk.y, x = dtk.x, kind = "macro_var", [BLOCK_INDEXES.MACRO_VAR.NAME] = ident, tk = "$" }
   else
      typ = new_nominal(ps, i, tk)
      i = i + 1
   end

   while ps.tokens[i].tk == "." do
      i = i + 1
      if ps.tokens[i].kind == "identifier" then
         local nom = new_block(ps, i, "identifier")
         nom.tk = ps.tokens[i].tk
         table.insert(typ, nom)
         i = i + 1
      elseif ps.allow_macro_vars and ps.tokens[i].tk == "$" then
         local dtk = ps.tokens[i]
         i = i + 1
         local ident
         i, ident = verify_kind(ps, i, "identifier")
         if not ident then
            return fail(ps, i, "syntax error, expected identifier")
         end
         local nom = { f = ps.filename, y = dtk.y, x = dtk.x, kind = "macro_var", [BLOCK_INDEXES.MACRO_VAR.NAME] = ident, tk = "$" }
         table.insert(typ, nom)
         i = i + 0
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
   if ps.tokens[i].kind == "identifier" or (ps.allow_macro_vars and ps.tokens[i].tk == "$") then
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
         decl[BLOCK_INDEXES.ARRAY_TYPE.ELEMENT] = t
         end_at(decl, ps.tokens[i])
         i = verify_tk(ps, i, "}")
         return i, decl
      elseif ps.tokens[i].tk == "," then
         local decl = new_type(ps, istart, "typelist")
         decl[BLOCK_INDEXES.TYPELIST.FIRST] = t
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
         decl[BLOCK_INDEXES.MAP_TYPE.KEYS] = t
         i, decl[BLOCK_INDEXES.MAP_TYPE.VALUES] = read_type(ps, i)
         if not decl[BLOCK_INDEXES.MAP_TYPE.VALUES] then
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
      u[BLOCK_INDEXES.UNION_TYPE.FIRST] = bt
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

   i, node[BLOCK_INDEXES.FUNCTION.TYPEARGS] = read_typeargs_if_any(ps, i)

   i, node[BLOCK_INDEXES.FUNCTION.ARGS] = read_argument_list(ps, i)
   i, node[BLOCK_INDEXES.FUNCTION.RETS] = read_return_types(ps, i)

   i, node[BLOCK_INDEXES.FUNCTION.BODY] = read_statements(ps, i)
   end_at(node, ps.tokens[i])
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function read_function_value(ps, i)
   local node = new_block(ps, i, "function")
   i = verify_tk(ps, i, "function")
   return read_function_args_rets_body(ps, i, node)
end

local function skip_any_function(ps, i)
   i = verify_tk(ps, i, "function")

   while ps.tokens[i] and (ps.tokens[i].kind == "identifier" or ps.tokens[i].tk == "." or ps.tokens[i].tk == ":") do
      i = i + 1
   end
   local dummy = new_block(ps, i, "function")
   return read_function_args_rets_body(ps, i, dummy)
end

local function read_macro_quote(ps, i)
   if not ps.in_local_macro then
      return fail(ps, i, "macro quotes can only be used inside macro statements")
   end
   local token = ps.tokens[i]
   local node = new_block(ps, i, "macro_quote")
   local tk = token.tk

   local triple = tk:sub(1, 3) == "```"
   local delim = triple and 3 or 1
   local code = tk:sub(delim + 1, -(delim + 1))
   if code:match("^%s*$") then
      return fail(ps, i, "macro quotes cannot be empty")
   end

   local block
   local errs

   if triple then









      local splices = {}
      local kept_lines = {}
      local line_index = 1
      for line in (code .. "\n"):gmatch("([^\n]*)\n") do
         local ident = line:match("^%s*%$([%a_][%w_]*)%s*;?%s*$")
         if ident then
            local y = token.y + (line_index - 1)
            local x = token.x + delim
            local ident_block = { f = ps.filename, y = y, x = x + 1, kind = "identifier", tk = ident }
            local mv = { f = ps.filename, y = y, x = x, kind = "macro_var", [BLOCK_INDEXES.MACRO_VAR.NAME] = ident_block, tk = "$" }
            table.insert(splices, { idx = line_index, blk = mv })

         else
            table.insert(kept_lines, line)
         end
         line_index = line_index + 1
      end

      local kept_code = table.concat(kept_lines, "\n")
      local parsed_block
      parsed_block, errs = reader.read(kept_code, ps.filename, ps.read_lang, true)


      if #splices > 0 and parsed_block and parsed_block.kind == "statements" then
         local combined = { f = ps.filename, y = token.y, x = token.x + delim, kind = "statements" }
         for _, s in ipairs(splices) do
            table.insert(combined, s.blk)
         end
         for _, stmt in ipairs(parsed_block) do
            table.insert(combined, stmt)
         end
         block = combined
      else
         block = parsed_block
      end
   else

      local wrapped, werrs = reader.read("return " .. code, ps.filename, ps.read_lang, true)
      if #werrs == 0 then
         local ret = wrapped[1]
         if ret and ret.kind == "return" and ret[BLOCK_INDEXES.RETURN.EXPS] then
            local exp = ret[BLOCK_INDEXES.RETURN.EXPS][BLOCK_INDEXES.EXPRESSION_LIST.FIRST]
            block = exp
            errs = {}
         else
            errs = werrs
         end
      else
         errs = werrs
      end
   end


   if errs and #errs > 0 then
      local x0 = token.x + delim
      local y0 = token.y
      local ret_prefix = not triple and #("return ") or 0
      for _, e in ipairs(errs) do
         local ey = e.y or 1
         local ex = e.x or 1
         local ny = y0 + (ey - 1)
         local nx
         if ey == 1 then
            local ex_unwrapped = ex - ret_prefix
            if ex_unwrapped < 1 then ex_unwrapped = 1 end
            nx = x0 + (ex_unwrapped - 1)
         else
            nx = ex
         end
         local msg = (e.msg and ("macro quote error: " .. e.msg)) or "macro quote error"
         table.insert(ps.errs, { filename = ps.filename, y = ny, x = nx, msg = msg .. " (quote starts at " .. ps.filename .. ":" .. token.y .. ":" .. token.x .. ")" })
      end
   end

   node[BLOCK_INDEXES.MACRO_QUOTE.BLOCK] = block
   end_at(node, token)
   return i + 1, node
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
      node.conststr, node.is_longstring = unquote(tk)
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
   elseif is_macro_quote_token(ps.tokens[i]) then
      if not ps.in_local_macro then
         return fail(ps, i, "macro quotes can only be used inside macro statements")
      end
      return read_macro_quote(ps, i)
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
      n[BLOCK_INDEXES.OP.E1] and n[BLOCK_INDEXES.OP.E1].tk == "pcall" and
      n[BLOCK_INDEXES.OP.E2] and #n[BLOCK_INDEXES.OP.E2] == 2 and
      n[BLOCK_INDEXES.OP.E2][BLOCK_INDEXES.EXPRESSION_LIST.FIRST].kind == "variable" and n[BLOCK_INDEXES.OP.E2][BLOCK_INDEXES.EXPRESSION_LIST.FIRST].tk == "require" and
      n[BLOCK_INDEXES.OP.E2][BLOCK_INDEXES.EXPRESSION_LIST.SECOND].kind == "string" and n[BLOCK_INDEXES.OP.E2][BLOCK_INDEXES.EXPRESSION_LIST.SECOND].conststr then


      return n[BLOCK_INDEXES.OP.E2][BLOCK_INDEXES.EXPRESSION_LIST.SECOND].conststr
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
      return { f = ps.filename, y = tkop.y, x = tkop.x, kind = "paren", [BLOCK_INDEXES.PAREN.EXP] = e1 }
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
         e1 = { f = ps.filename, y = t1.y, x = t1.x, kind = op_kind, [BLOCK_INDEXES.OP.E1] = e1, tk = t1.tk }
      elseif ps.allow_macro_vars and ps.tokens[i].tk == "$" then
         local dtk = ps.tokens[i]
         i = i + 1
         local ident
         i, ident = verify_kind(ps, i, "identifier")
         if not ident then
            return i
         end
         e1 = { f = ps.filename, y = dtk.y, x = dtk.x, kind = "macro_var", [1] = ident, tk = "$" }
      elseif ps.tokens[i].tk == "(" then
         i = i + 1
         local prev_i = i
         i, e1 = read_expression_and_tk(ps, i, ")")
         if not e1 then
            fail(ps, prev_i, "expected an expression")
            return i
         end
         e1 = { f = ps.filename, y = t1.y, x = t1.x, kind = "paren", [BLOCK_INDEXES.PAREN.EXP] = e1 }
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
            if ps.allow_macro_vars and ps.tokens[i].tk == "$" then
               local dtk = ps.tokens[i]
               i = i + 1
               local ident
               i, ident = verify_kind(ps, i, "identifier")
               if not ident then
                  return i, failstore(ps, tkop, e1)
               end
               key = { f = ps.filename, y = dtk.y, x = dtk.x, kind = "macro_var", [1] = ident, tk = "$" }
            else
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

            e1 = { f = ps.filename, y = tkop.y, x = tkop.x, kind = op_kind, [BLOCK_INDEXES.OP.E1] = e1, [BLOCK_INDEXES.OP.E2] = key, tk = tkop.tk }
         elseif tkop.tk == "!" then
            local prev_i = i
            i = i + 1
            local next_tk = ps.tokens[i]
            local args = new_block(ps, i, "expression_list")
            local argument
            if next_tk.tk == "(" then
               local mname
               if e1 and (e1.kind == "variable" or e1.kind == "identifier") then
                  mname = e1.tk
               end
               local sig = mname and ps.macro_sigs[mname]
               if sig then
                  i, args = read_macro_args_with_sig(ps, i, sig, mname)
               else
                  i, args = read_bracket_list(ps, i, args, "(", ")", "sep", read_expression)
               end
            elseif next_tk.kind == "string" or next_tk.kind == "{" then
               if next_tk.kind == "string" then
                  argument = new_block(ps, i)
                  argument.conststr, argument.is_longstring = unquote(next_tk.tk)
                  i = i + 1
               else
                  i, argument = read_table_literal(ps, i)
               end
               table.insert(args, argument)
            elseif is_macro_quote_token(next_tk) then
               local qi, q = read_macro_quote(ps, i)
               i = qi
               table.insert(args, q)
            else
               if next_tk.tk == "=" then
                  fail(ps, i, "syntax error, cannot perform an assignment here (missing 'local' or 'global'?)")
               else
                  fail(ps, i, "expected macro arguments")
               end
               return i, failstore(ps, tkop, e1)
            end

            if not after_valid_prefixexp(ps, e1, prev_i) then
               fail(ps, prev_i, "cannot call this expression")
               return i, failstore(ps, tkop, e1)
            end

            e1 = { f = ps.filename, y = args.y, x = args.x, kind = "macro_invocation", [BLOCK_INDEXES.MACRO_INVOCATION.MACRO] = e1, [BLOCK_INDEXES.MACRO_INVOCATION.ARGS] = args, tk = tkop.tk }
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

            e1 = { f = ps.filename, y = args.y, x = args.x, kind = op_kind, [BLOCK_INDEXES.OP.E1] = e1, [BLOCK_INDEXES.OP.E2] = args, tk = tkop.tk }
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

            e1 = { f = ps.filename, y = tkop.y, x = tkop.x, kind = op_kind, [BLOCK_INDEXES.OP.E1] = e1, [BLOCK_INDEXES.OP.E2] = idx, tk = tkop.tk }
         elseif tkop.kind == "string" or tkop.kind == "{" then
            local op_kind = op_map[2]["@funcall"]

            local prev_i = i

            local args = new_block(ps, i, "expression_list")
            local argument
            if tkop.kind == "string" then
               argument = new_block(ps, i)
               argument.conststr, argument.is_longstring = unquote(tkop.tk)
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
            e1 = { f = ps.filename, y = args.y, x = args.x, kind = op_kind, [BLOCK_INDEXES.OP.E1] = e1, [BLOCK_INDEXES.OP.E2] = args, tk = tkop.tk }
         elseif tkop.tk == "as" or tkop.tk == "is" then
            local op_kind = op_map[2][tkop.tk]

            i = i + 1
            local cast = new_block(ps, i, "cast")
            if ps.tokens[i].tk == "(" then
               i, cast[BLOCK_INDEXES.CAST.TYPE] = read_type_list(ps, i, "casttype")
            else
               i, cast[BLOCK_INDEXES.CAST.TYPE] = read_type(ps, i)
            end
            if not cast[BLOCK_INDEXES.CAST.TYPE] then
               return i, failstore(ps, tkop, e1)
            end
            e1 = { f = ps.filename, y = tkop.y, x = tkop.x, kind = op_kind, [BLOCK_INDEXES.OP.E1] = e1, [BLOCK_INDEXES.OP.E2] = cast, conststr = e1.conststr, tk = tkop.tk }
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
         lhs = { f = ps.filename, y = op_tk.y, x = op_tk.x, kind = op_kind, [BLOCK_INDEXES.OP.E1] = lhs, [BLOCK_INDEXES.OP.E2] = rhs, tk = op_tk.tk }
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
   if ps.allow_macro_vars and ps.tokens[i].tk == "$" then
      local dtk = ps.tokens[i]
      i = i + 1
      local ident
      i, ident = verify_kind(ps, i, "identifier")
      if not ident then
         return i
      end
      node = new_block(ps, i - 1, "macro_var")
      node[BLOCK_INDEXES.MACRO_VAR.NAME] = ident
      end_at(node, ps.tokens[i - 1])
   else
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
   i, node[BLOCK_INDEXES.LOCAL_FUNCTION.NAME] = read_identifier(ps, i)
   return read_function_args_rets_body(ps, i, node)
end

local function read_if_block(ps, i, node, is_else)
   local block = new_block(ps, i, "if_block")
   i = i + 1
   if not is_else then
      i, block[BLOCK_INDEXES.IF_BLOCK.COND] = read_expression_and_tk(ps, i, "then")
      if not block[BLOCK_INDEXES.IF_BLOCK.COND] then
         return i
      end
      i, block[BLOCK_INDEXES.IF_BLOCK.BODY] = read_statements(ps, i)
      if not block[BLOCK_INDEXES.IF_BLOCK.BODY] then
         return i
      end
   else
      i, block[BLOCK_INDEXES.IF_BLOCK.BODY] = read_statements(ps, i)
      if not block[BLOCK_INDEXES.IF_BLOCK.BODY] then
         return i
      end
   end
   block.yend, block.xend = (block[BLOCK_INDEXES.IF_BLOCK.BODY] or block[BLOCK_INDEXES.IF_BLOCK.COND]).yend, (block[BLOCK_INDEXES.IF_BLOCK.BODY] or block[BLOCK_INDEXES.IF_BLOCK.COND]).xend
   table.insert(node[BLOCK_INDEXES.IF.BLOCKS], block)
   return i, node
end

local function read_if(ps, i)
   local istart = i
   local node = new_block(ps, i, "if")
   node[BLOCK_INDEXES.IF.BLOCKS] = {}
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
   i, node[BLOCK_INDEXES.WHILE.COND] = read_expression_and_tk(ps, i, "do")
   i, node[BLOCK_INDEXES.WHILE.BODY] = read_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function read_fornum(ps, i)
   local istart = i
   local node = new_block(ps, i, "fornum")
   i = i + 1
   i, node[BLOCK_INDEXES.FORNUM.VAR] = read_identifier(ps, i)
   i = verify_tk(ps, i, "=")
   i, node[BLOCK_INDEXES.FORNUM.FROM] = read_expression_and_tk(ps, i, ",")
   i, node[BLOCK_INDEXES.FORNUM.TO] = read_expression(ps, i)
   if ps.tokens[i].tk == "," then
      i = i + 1
      i, node[BLOCK_INDEXES.FORNUM.STEP] = read_expression_and_tk(ps, i, "do")
   else
      i = verify_tk(ps, i, "do")
   end
   i, node[BLOCK_INDEXES.FORNUM.BODY] = read_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function read_forin(ps, i)
   local istart = i
   local node = new_block(ps, i, "forin")
   i = i + 1
   node[BLOCK_INDEXES.FORIN.VARS] = new_block(ps, i, "variable_list")
   i, node[BLOCK_INDEXES.FORIN.VARS] = read_list(ps, i, node[BLOCK_INDEXES.FORIN.VARS], { ["in"] = true }, "sep", read_identifier)
   i = verify_tk(ps, i, "in")
   node[BLOCK_INDEXES.FORIN.EXPS] = new_block(ps, i, "expression_list")
   i = read_list(ps, i, node[BLOCK_INDEXES.FORIN.EXPS], { ["do"] = true }, "sep", read_expression)
   if #node[BLOCK_INDEXES.FORIN.EXPS] < 1 then
      return fail(ps, i, "missing iterator expression in generic for")
   elseif #node[BLOCK_INDEXES.FORIN.EXPS] > 3 then
      return fail(ps, i, "too many expressions in generic for")
   end
   i = verify_tk(ps, i, "do")
   i, node[BLOCK_INDEXES.FORIN.BODY] = read_statements(ps, i)
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
   i, node[BLOCK_INDEXES.REPEAT.BODY] = read_statements(ps, i)
   i = verify_tk(ps, i, "until")
   i, node[BLOCK_INDEXES.REPEAT.COND] = read_expression(ps, i)
   end_at(node, ps.tokens[i - 1])
   return i, node
end

local function read_do(ps, i)
   local istart = i
   local node = new_block(ps, i, "do")
   i = verify_tk(ps, i, "do")
   i, node[BLOCK_INDEXES.DO.BODY] = read_statements(ps, i)
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
   node[BLOCK_INDEXES.GOTO.LABEL] = new_block(ps, i, "identifier")
   node[BLOCK_INDEXES.GOTO.LABEL].tk = ps.tokens[i].tk
   i = verify_kind(ps, i, "identifier")
   return i, node
end

read_statement_argblock = function(ps, i)
   local node = new_block(ps, i, "statements")
   local item
   while true do
      while ps.tokens[i].kind == ";" do
         i = i + 1
      end
      if ps.tokens[i].kind == "$EOF$" then
         break
      end
      local tk = ps.tokens[i].tk
      if tk == ")" or tk == "," then
         break
      end

      local fn = read_statement_fns[tk]
      if not fn then
         if read_type_body_fns[tk] and ps.tokens[i + 1].kind == "identifier" then
            local lt
            i, lt = read_nested_type(ps, i, tk)
            item = lt
         else
            local skip_fn = needs_local_or_global[tk]
            if skip_fn and ps.tokens[i + 1].kind == "identifier" then
               fn = skip_fn
            else
               fn = read_call_or_assignment
            end
         end
      end

      if not item and fn then
         i, item = fn(ps, i)
      end

      if item then
         table.insert(node, item)
         item = nil
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

local function read_label(ps, i)
   local node = new_block(ps, i, "label")
   i = verify_tk(ps, i, "::")
   node[BLOCK_INDEXES.LABEL.NAME] = new_block(ps, i, "identifier")
   node[BLOCK_INDEXES.LABEL.NAME].tk = ps.tokens[i].tk
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
   node[BLOCK_INDEXES.RETURN.EXPS] = new_block(ps, i, "expression_list")
   i = read_list(ps, i, node[BLOCK_INDEXES.RETURN.EXPS], stop_return_list, "sep", read_expression)
   if ps.tokens[i].kind == ";" then
      i = i + 1
      if ps.tokens[i].kind ~= "$EOF$" and not stop_statement_list[ps.tokens[i].kind] then
         return fail(ps, i, "return must be the last statement of its block")
      end
   end
   return i, node
end

read_nested_type = function(ps, i, tn)
   local istart = i
   i = i + 1

   local v
   if ps.allow_macro_vars and ps.tokens[i].tk == "$" then
      local dtk = ps.tokens[i]
      i = i + 1
      local ident
      i, ident = verify_kind(ps, i, "identifier")
      if not ident then
         return fail(ps, i, "expected a variable name")
      end
      v = { f = ps.filename, y = dtk.y, x = dtk.x, kind = "macro_var", [1] = ident, tk = "$" }
   else
      i, v = verify_kind(ps, i, "identifier", "type_identifier")
      if not v then
         return fail(ps, i, "expected a variable name")
      end
   end

   local nt = new_block(ps, istart, "newtype")

   local ndef
   i, ndef = read_type_body(ps, i, istart, nt, tn)
   if not ndef then
      return i
   end

   table.insert(nt, new_typedecl(ps, istart, ndef))
   local asgn = new_block(ps, istart, "local_type")
   asgn[BLOCK_INDEXES.LOCAL_TYPE.VAR] = v
   asgn[BLOCK_INDEXES.LOCAL_TYPE.VALUE] = nt
   return i, asgn
end

read_enum_body = function(ps, i, def)
   while ps.tokens[i].tk ~= "$EOF$" and ps.tokens[i].tk ~= "end" do
      local comment_blocks = collect_comment_blocks(ps, i)
      local item
      i, item = verify_kind(ps, i, "string", "string")
      if item then
         for _, cb in ipairs(comment_blocks) do
            table.insert(def, cb)
         end
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
   local idx = 1
   if ps.tokens[istart + 1].tk == "<" then
      i, node[idx] = read_anglebracket_list(ps, istart + 1, read_typearg)
      idx = idx + 1
   else
      i = iargs
   end

   i, node[idx] = read_argument_list(ps, i)
   idx = idx + 1
   i, node[idx] = read_return_types(ps, i)
   idx = idx + 1
   i = verify_tk(ps, i, "return")
   i, node[idx] = read_expression(ps, i)
   end_at(node, ps.tokens[i])
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function read_where_clause(ps, i, def)
   local node = new_block(ps, i, "macroexp")

   node[BLOCK_INDEXES.MACROEXP.ARGS] = new_block(ps, i, "argument_list")
   node[BLOCK_INDEXES.MACROEXP.ARGS][BLOCK_INDEXES.ARGUMENT_LIST.FIRST] = new_block(ps, i, "argument")
   node[BLOCK_INDEXES.MACROEXP.ARGS][BLOCK_INDEXES.ARGUMENT_LIST.FIRST].tk = "self"
   node[BLOCK_INDEXES.MACROEXP.ARGS][BLOCK_INDEXES.ARGUMENT_LIST.FIRST][BLOCK_INDEXES.ARGUMENT.ANNOTATION] = new_type(ps, i, "nominal_type")
   node[BLOCK_INDEXES.MACROEXP.ARGS][BLOCK_INDEXES.ARGUMENT_LIST.FIRST][BLOCK_INDEXES.ARGUMENT.ANNOTATION].tk = "self"
   node[BLOCK_INDEXES.MACROEXP.ARGS][BLOCK_INDEXES.ARGUMENT_LIST.FIRST][BLOCK_INDEXES.ARGUMENT.ANNOTATION][BLOCK_INDEXES.NOMINAL_TYPE.NAME] = def
   node[BLOCK_INDEXES.MACROEXP.RETS] = new_tuple(ps, i)
   node[BLOCK_INDEXES.MACROEXP.RETS][BLOCK_INDEXES.TUPLE_TYPE.FIRST] = new_type(ps, i, "boolean")
   i, node[BLOCK_INDEXES.MACROEXP.EXP] = read_expression(ps, i)
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
      if iface.kind == "nominal_type" and #iface == 1 and iface[BLOCK_INDEXES.NOMINAL_TYPE.NAME].tk == "userdata" then
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
         def[BLOCK_INDEXES.RECORD.ARRAY_TYPE] = atype
      end
   end

   if ps.tokens[i].tk == "is" then
      i = i + 1

      if ps.tokens[i].tk == "{" then
         if def[BLOCK_INDEXES.RECORD.ARRAY_TYPE] then
            return failskip(ps, i, "duplicated declaration of array element type", read_type)
         end
         local atype
         i, atype = read_array_interface_type(ps, i)
         if atype then
            def[BLOCK_INDEXES.RECORD.ARRAY_TYPE] = atype
         end
         if ps.tokens[i].tk == "," then
            i = i + 1
            def[BLOCK_INDEXES.RECORD.INTERFACES] = new_block(ps, i, "interface_list")
            i, def[BLOCK_INDEXES.RECORD.INTERFACES] = read_trying_list(ps, i, def[BLOCK_INDEXES.RECORD.INTERFACES], read_interface_name)
         else
            def[BLOCK_INDEXES.RECORD.INTERFACES] = new_block(ps, i, "interface_list")
         end
      else
         def[BLOCK_INDEXES.RECORD.INTERFACES] = new_block(ps, i, "interface_list")
         i, def[BLOCK_INDEXES.RECORD.INTERFACES] = read_trying_list(ps, i, def[BLOCK_INDEXES.RECORD.INTERFACES], read_interface_name)
      end

      if def[BLOCK_INDEXES.RECORD.INTERFACES] and extract_userdata_from_interface_list(ps, i, def[BLOCK_INDEXES.RECORD.INTERFACES]) then
         table.insert(def, new_block(ps, i, "userdata"))
      end
   end

   if ps.tokens[i].tk == "where" then
      i = i + 1
      i, def[BLOCK_INDEXES.RECORD.WHERE_CLAUSE] = read_where_clause(ps, i, def)
   end

   local fields = new_block(ps, i, "record_body")
   def[BLOCK_INDEXES.RECORD.FIELDS] = fields
   local meta_fields

   while not (ps.tokens[i].kind == "$EOF$" or ps.tokens[i].tk == "end") do
      local comment_blocks = collect_comment_blocks(ps, i)
      local tn = ps.tokens[i].tk
      if ps.tokens[i].tk == "userdata" and ps.tokens[i + 1].tk ~= ":" then
         for _, cb in ipairs(comment_blocks) do
            table.insert(def, cb)
         end
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

         for _, cb in ipairs(comment_blocks) do
            table.insert(fields, cb)
         end
         table.insert(fields, lt)
      elseif read_type_body_fns[tn] and ps.tokens[i + 1].tk ~= ":" then
         if def.kind == "interface" and tn == "record" then
            i = failskip(ps, i, "interfaces cannot contain record definitions", skip_type_body)
         else
            local lt
            i, lt = read_nested_type(ps, i, tn)
            if lt then
               for _, cb in ipairs(comment_blocks) do
                  table.insert(fields, cb)
               end
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
                  def[BLOCK_INDEXES.RECORD.META_FIELDS] = meta_fields
               end
               current_fields = meta_fields
               if not metamethod_names[field_name] then
                  fail(ps, i - 1, "not a valid metamethod: " .. field_name)
               end
            end

            for _, cb in ipairs(comment_blocks) do
               table.insert(current_fields, cb)
            end

            if ps.tokens[i].tk == "=" and ps.tokens[i + 1].tk == "macroexp" then
               local tt = t.kind == "generic_type" and t[BLOCK_INDEXES.GENERIC_TYPE.BASE] or t

               if tt.kind == "function" then
                  i, tt[BLOCK_INDEXES.FUNCTION_TYPE.MACROEXP] = read_macroexp(ps, i + 1, i + 2)
               else
                  fail(ps, i + 1, "macroexp must have a function type")
               end
            end

            local field = new_block(ps, i, "record_field")
            field[BLOCK_INDEXES.RECORD_FIELD.NAME] = v
            field[BLOCK_INDEXES.RECORD_FIELD.TYPE] = t
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

   node[BLOCK_INDEXES.NEWTYPE.TYPEDECL] = new_typedecl(ps, istart, def)

   return i, node
end

local function read_assignment_expression_list(ps, i, asgn)
   asgn[BLOCK_INDEXES.ASSIGNMENT.EXPS] = new_block(ps, i, "expression_list")
   repeat
      i = i + 1
      local val
      i, val = read_expression(ps, i)
      if not val then
         if #asgn[BLOCK_INDEXES.ASSIGNMENT.EXPS] == 0 then
            asgn[BLOCK_INDEXES.ASSIGNMENT.EXPS] = nil
         end
         return i
      end
      table.insert(asgn[BLOCK_INDEXES.ASSIGNMENT.EXPS], val)
   until ps.tokens[i].tk ~= ","
   end_at(asgn[BLOCK_INDEXES.ASSIGNMENT.EXPS], ps.tokens[i - 1])
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

      if exp.kind == "macro_var" then
         return i, exp
      end

      if exp.kind ~= "variable" and exp.kind ~= "op_index" and exp.kind ~= "op_dot" then
         return fail(ps, i, "syntax error")
      end

      local asgn = new_block(ps, istart, "assignment")
      asgn[BLOCK_INDEXES.ASSIGNMENT.VARS] = new_block(ps, istart, "variable_list")
      asgn[BLOCK_INDEXES.ASSIGNMENT.VARS][BLOCK_INDEXES.VARIABLE_LIST.FIRST] = exp
      if ps.tokens[i].tk == "," then
         i = i + 1
         i = read_trying_list(ps, i, asgn[BLOCK_INDEXES.ASSIGNMENT.VARS], read_variable)
         if #asgn[BLOCK_INDEXES.ASSIGNMENT.VARS] < 2 then
            return fail(ps, i, "syntax error")
         end
      end

      end_at(asgn[BLOCK_INDEXES.ASSIGNMENT.VARS], ps.tokens[i - 1])

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

   asgn[BLOCK_INDEXES.LOCAL_DECLARATION.VARS] = new_block(ps, i, "variable_list")
   i = read_trying_list(ps, i, asgn[BLOCK_INDEXES.LOCAL_DECLARATION.VARS], read_variable_name)
   if #asgn[BLOCK_INDEXES.LOCAL_DECLARATION.VARS] == 0 then
      return fail(ps, i, "expected a local variable definition")
   end

   end_at(asgn[BLOCK_INDEXES.LOCAL_DECLARATION.VARS], ps.tokens[i - 1])

   i, asgn[BLOCK_INDEXES.LOCAL_DECLARATION.DECL] = read_type_list(ps, i, "decltuple")

   if ps.tokens[i].tk == "=" then

      local next_word = ps.tokens[i + 1].tk
      local tn = next_word
      if read_type_body_fns[tn] then
         local scope = node_name == "local_declaration" and "local" or "global"
         return failskip(ps, i + 1, "syntax error: this syntax is no longer valid; use '" .. scope .. " " .. next_word .. " " .. asgn[BLOCK_INDEXES.LOCAL_DECLARATION.VARS][BLOCK_INDEXES.VARIABLE_LIST.FIRST].tk .. "'", skip_type_body)
      elseif next_word == "functiontype" then
         local scope = node_name == "local_declaration" and "local" or "global"
         return failskip(ps, i + 1, "syntax error: this syntax is no longer valid; use '" .. scope .. " type " .. asgn[BLOCK_INDEXES.LOCAL_DECLARATION.VARS][BLOCK_INDEXES.VARIABLE_LIST.FIRST].tk .. " = function('...", read_function_type)
      end

      i, asgn = read_assignment_expression_list(ps, i, asgn)
   end
   return i, asgn
end

local function read_type_require(ps, i, asgn)
   local istart = i
   local BIDX = asgn.kind == "local_type" and BLOCK_INDEXES.LOCAL_TYPE or BLOCK_INDEXES.GLOBAL_TYPE
   i, asgn[BIDX.VALUE] = read_expression(ps, i)
   if not asgn[BIDX.VALUE] then
      return i
   end
   if asgn[BIDX.VALUE].kind ~= "op_funcall" and asgn[BIDX.VALUE].kind ~= "op_dot" and asgn[BIDX.VALUE].kind ~= "variable" then
      fail(ps, istart, "require() in type declarations cannot be part of larger expressions")
      return i
   end
   if not reader.node_is_require_call(asgn[BIDX.VALUE]) then
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
   local BIDX = node_name == "local_type" and BLOCK_INDEXES.LOCAL_TYPE or BLOCK_INDEXES.GLOBAL_TYPE

   if ps.allow_macro_vars and ps.tokens[i].tk == "$" then
      local dtk = ps.tokens[i]
      i = i + 1
      local ident
      i, ident = verify_kind(ps, i, "identifier")
      if not ident then
         return fail(ps, i, "expected a type name")
      end
      var = { f = ps.filename, y = dtk.y, x = dtk.x, kind = "macro_var", [1] = ident, tk = "$" }
   else
      i, var = verify_kind(ps, i, "identifier")
      if not var then
         return fail(ps, i, "expected a type name")
      end
   end
   local typeargs
   local itypeargs = i
   i, typeargs = read_typeargs_if_any(ps, i)

   asgn[BIDX.VAR] = var

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

   i, asgn[BIDX.VALUE] = read_newtype(ps, i)
   if not asgn[BIDX.VALUE] then
      return i
   end

   if typeargs and asgn[BIDX.VALUE][BLOCK_INDEXES.NEWTYPE.TYPEDECL] and asgn[BIDX.VALUE][BLOCK_INDEXES.NEWTYPE.TYPEDECL][BLOCK_INDEXES.TYPEDECL.TYPE] then
      asgn[BIDX.VALUE][BLOCK_INDEXES.NEWTYPE.TYPEDECL][BLOCK_INDEXES.TYPEDECL.TYPE] = new_generic(ps, itypeargs, typeargs, asgn[BIDX.VALUE][BLOCK_INDEXES.NEWTYPE.TYPEDECL][BLOCK_INDEXES.TYPEDECL.TYPE])
   end

   return i, asgn
end

local function read_type_constructor(ps, i, node_name, tn)
   local asgn = new_block(ps, i, node_name)
   local nt = new_block(ps, i, "newtype")
   local BIDX = node_name == "local_type" and BLOCK_INDEXES.LOCAL_TYPE or BLOCK_INDEXES.GLOBAL_TYPE
   asgn[BIDX.VALUE] = nt
   local istart = i
   local def

   i = i + 2

   if ps.allow_macro_vars and ps.tokens[i].tk == "$" then
      local dtk = ps.tokens[i]
      i = i + 1
      local ident
      i, ident = verify_kind(ps, i, "identifier")
      if not ident then
         return fail(ps, i, "expected a type name")
      end
      asgn[BIDX.VAR] = { f = ps.filename, y = dtk.y, x = dtk.x, kind = "macro_var", [1] = ident, tk = "$" }
   else
      i, asgn[BIDX.VAR] = verify_kind(ps, i, "identifier")
      if not asgn[BIDX.VAR] then
         return fail(ps, i, "expected a type name")
      end
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
   i, node[BLOCK_INDEXES.LOCAL_MACROEXP.NAME] = read_identifier(ps, i)
   i, node[BLOCK_INDEXES.LOCAL_MACROEXP.EXP] = read_macroexp(ps, istart, i)
   end_at(node, ps.tokens[i - 1])
   return i, node
end

local function read_local_macro(ps, i)
   local istart = i
   i = verify_tk(ps, i, "local")
   i = verify_tk(ps, i, "macro")
   local node = new_block(ps, istart, "local_macro")
   i, node[BLOCK_INDEXES.LOCAL_MACRO.NAME] = read_identifier(ps, i)
   i = verify_tk(ps, i, "!")
   local old_in_macro = ps.in_local_macro
   local old_allow = ps.allow_macro_vars
   ps.in_local_macro = true
   ps.allow_macro_vars = false
   i, node = read_function_args_rets_body(ps, i, node)
   ps.in_local_macro = old_in_macro
   ps.allow_macro_vars = old_allow
   local args = node[BLOCK_INDEXES.LOCAL_MACRO.ARGS]
   if args then
      local sig = { kinds = {}, vararg = "" }
      local idx = 1
      for _, ab in ipairs(args) do
         local annot = ab and ab[BLOCK_INDEXES.ARGUMENT.ANNOTATION]
         local ok = false
         local mode
         if annot and annot.kind == "nominal_type" and annot[BLOCK_INDEXES.NOMINAL_TYPE.NAME] and annot[BLOCK_INDEXES.NOMINAL_TYPE.NAME].kind == "identifier" then
            local tname = annot[BLOCK_INDEXES.NOMINAL_TYPE.NAME].tk
            if tname == "Statement" then ok = true; mode = "stmt"
            elseif tname == "Expression" then ok = true; mode = "expr" end
         end
         if not ok then
            table.insert(ps.errs, { filename = ps.filename, y = (annot and annot.y) or ab.y, x = (annot and annot.x) or ab.x, msg = "macro argument type must be 'Statement' or 'Expression'" })
         else
            if ab.tk == "..." then
               sig.vararg = mode or "expr"
            else
               sig.kinds[idx] = mode or "expr"
               idx = idx + 1
            end
         end
      end
      if node[BLOCK_INDEXES.LOCAL_MACRO.NAME] and node[BLOCK_INDEXES.LOCAL_MACRO.NAME].kind == "identifier" then
         ps.macro_sigs[node[BLOCK_INDEXES.LOCAL_MACRO.NAME].tk] = sig
      end
   end
   return i, node
end

local function read_local(ps, i)
   local ntk = ps.tokens[i + 1].tk
   if ntk == "function" then
      return read_local_function(ps, i)
   elseif ntk == "type" and (ps.tokens[i + 2].kind == "identifier" or (ps.allow_macro_vars and ps.tokens[i + 2].tk == "$")) then
      return read_type_declaration(ps, i + 2, "local_type")
   elseif ntk == "macro" and ps.tokens[i + 2].kind == "identifier" then
      return read_local_macro(ps, i)
   elseif ntk == "macroexp" and ps.tokens[i + 2].kind == "identifier" then
      return read_local_macroexp(ps, i)
   elseif read_type_body_fns[ntk] and (ps.tokens[i + 2].kind == "identifier" or (ps.allow_macro_vars and ps.tokens[i + 2].tk == "$")) then
      return read_type_constructor(ps, i, "local_type", ntk)
   end
   return read_variable_declarations(ps, i + 1, "local_declaration")
end

local function read_global(ps, i)
   local ntk = ps.tokens[i + 1].tk
   if ntk == "function" then
      i = verify_tk(ps, i, "global")
      i = verify_tk(ps, i, "function")
      local func_start = i - 1
      local fn = new_block(ps, i - 2, "global_function")
      i, fn[BLOCK_INDEXES.GLOBAL_FUNCTION.NAME] = read_identifier(ps, i)
      if ps.tokens[i].tk == "." or ps.tokens[i].tk == ":" then
         local ni = skip_any_function(ps, func_start)
         fail(ps, func_start, "record functions cannot be annotated as 'global'")
         return ni
      end
      return read_function_args_rets_body(ps, i, fn)
   elseif ntk == "type" and ps.tokens[i + 2].kind == "identifier" then
      return read_type_declaration(ps, i + 2, "global_type")
   elseif read_type_body_fns[ntk] and (ps.tokens[i + 2].kind == "identifier" or (ps.allow_macro_vars and ps.tokens[i + 2].tk == "$")) then
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

   local function read_name_piece(ps2, ii)
      if ps2.allow_macro_vars and ps2.tokens[ii].tk == "$" then
         local dtk = ps2.tokens[ii]
         ii = ii + 1
         local ident
         ii, ident = read_identifier(ps2, ii)
         if not ident then
            return fail(ps2, ii, "syntax error, expected identifier")
         end
         return ii, { f = ps2.filename, y = dtk.y, x = dtk.x, kind = "macro_var", [1] = ident, tk = "$" }
      end
      local nii
      local nb
      nii, nb = read_identifier(ps2, ii)
      return nii, nb
   end

   i, names[1] = read_name_piece(ps, i)

   while ps.tokens[i] and ps.tokens[i].tk == "." do
      table.insert(dot_pos, i)
      i = i + 1
      i, names[#names + 1] = read_name_piece(ps, i)
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
         dot_block[BLOCK_INDEXES.OP.E1] = owner
         dot_block[BLOCK_INDEXES.OP.E2] = names[n]
         owner = dot_block
      end
      fn[BLOCK_INDEXES.RECORD_FUNCTION.OWNER] = owner
      fn[BLOCK_INDEXES.RECORD_FUNCTION.NAME] = names[#names]
   else
      fn[BLOCK_INDEXES.RECORD_FUNCTION.OWNER] = names[1]
   end

   local istart = i - 1
   i, fn[BLOCK_INDEXES.RECORD_FUNCTION.TYPEARGS] = read_typeargs_if_any(ps, i)
   i, fn[BLOCK_INDEXES.RECORD_FUNCTION.ARGS] = read_argument_list(ps, i)
   i, fn[BLOCK_INDEXES.RECORD_FUNCTION.RETS] = read_return_types(ps, i)
   i, fn[BLOCK_INDEXES.RECORD_FUNCTION.BODY] = read_statements(ps, i)

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
   pragma[BLOCK_INDEXES.PRAGMA.KEY] = new_block(ps, i, "identifier")
   pragma[BLOCK_INDEXES.PRAGMA.KEY].tk = ps.tokens[i].tk
   i = i + 1

   if ps.tokens[i].kind ~= "pragma_identifier" then
      return fail(ps, i, "expected pragma value")
   end
   pragma[BLOCK_INDEXES.PRAGMA.VALUE] = new_block(ps, i, "identifier")
   pragma[BLOCK_INDEXES.PRAGMA.VALUE].tk = ps.tokens[i].tk
   i = i + 1

   return i, pragma
end

read_statement_fns = {
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

needs_local_or_global = {
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
      local comment_blocks = collect_comment_blocks(ps, i)
      for _, cb in ipairs(comment_blocks) do
         table.insert(node, cb)
      end

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

function reader.read_program(tokens, errs, filename, read_lang, allow_macro_vars)
   errs = errs or {}
   filename = filename or "input"
   errs = normalize_macro_tokens(tokens, errs)
   read_lang = read_lang or lang_heuristic(filename)
   if allow_macro_vars == nil then
      allow_macro_vars = true
   end
   local ps = {
      tokens = tokens,
      errs = errs,
      filename = filename,
      required_modules = {},
      read_lang = read_lang,
      allow_macro_vars = allow_macro_vars or false,
      in_local_macro = false,
      macro_sigs = {},
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

   local seen = setmetatable({}, { __mode = "k" })

   local function check_macro_arity(b)
      if seen[b] then return end
      seen[b] = true
      if b.kind == "macro_invocation" then
         local m = b[BLOCK_INDEXES.MACRO_INVOCATION.MACRO]
         local args = b[BLOCK_INDEXES.MACRO_INVOCATION.ARGS]
         if m and (m.kind == "variable" or m.kind == "identifier") then
            local name = m.tk
            local sig = ps.macro_sigs[name]
            if sig then
               local provided = args and #args or 0
               local required = #sig.kinds
               local has_vararg = sig.vararg ~= ""
               if provided < required or ((not has_vararg) and provided > required) then
                  local msg = "macro '" .. name .. "' expects " .. tostring(required) .. (required == 1 and " argument" or " arguments") .. ", got " .. tostring(provided)
                  table.insert(ps.errs, { filename = ps.filename, y = m.y, x = m.x, msg = msg })
               end
            end
         end
      end
      for i2 = 1, #b do
         local child = b[i2]
         if child then
            check_macro_arity(child)
         end
      end
   end

   check_macro_arity(node)

   local lang = read_lang or "tl"
   node = macro_eval.compile_all_and_expand(node, filename, lang, errs)

   errors.clear_redundant_errors(errs)
   return node, ps.required_modules
end

function reader.read(input, filename, read_lang, allow_macro_vars)
   filename = filename or "input"
   read_lang = read_lang or lang_heuristic(filename, input)
   local tokens, errs = lexer.lex(input, filename)
   local node, required_modules = reader.read_program(tokens, errs, filename, read_lang, allow_macro_vars)
   return node, errs, required_modules
end

return reader
