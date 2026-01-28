local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table
local reader = require("teal.reader_api")


local errors = require("teal.errors")



local types = require("teal.types")
























local a_type = types.a_type
local raw_type = types.raw_type
local simple_types = types.simple_types

local lexer = require("teal.lexer")





























































local parse_type
local parse_type_list
local parse_typeargs_if_any







































































































































local parser = {}













local attributes = {
   ["const"] = true,
   ["close"] = true,
   ["total"] = true,
}
local is_attribute = attributes

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




local op_kinds = {
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













local node_mt = {
   __tostring = function(n)
      return n.f .. ":" .. n.y .. ":" .. n.x .. " " .. n.kind
   end,
}

function parser.lang_heuristic(filename, input)
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


local function end_at(node, block)
   if block then
      if block.yend then
         node.yend = block.yend
      end
      if block.xend then
         node.xend = block.xend
      end
   end
end

local function unquote_string_literal(str)
   local f = str:sub(1, 1)
   if f == '"' or f == "'" then
      return str:sub(2, -2), false
   end
   local long_start = str:match("^%[=*%[")
   if not long_start then
      return str, false
   end
   local l = #long_start + 1
   return str:sub(l, -l), true
end

local function block_string_value(b)
   if b and b.kind == "string" and b.tk then
      local text
      local _is_long
      text, _is_long = unquote_string_literal(b.tk)
      return text
   end
   return nil
end

local function block_number_value(b)
   if b and (b.kind == "integer" or b.kind == "number") then
      return tonumber(b.tk)
   end
   return nil
end

local function new_node(state, block, kind)
   if not block then
      return nil
   end

   local bkind = block.kind
   if bkind == "error_block" then
      bkind = "error_node"
   end

   local node = setmetatable({
      f = state.filename,
      y = block.y,
      x = block.x,
      tk = block.tk,
      kind = kind or (bkind),
   }, node_mt)
   end_at(node, block)
   return node
end

local function fail(state, block, msg)
   table.insert(state.errs, {
      filename = state.filename,
      y = block and block.y or 1,
      x = block and block.x or 1,
      msg = assert(msg, "syntax error, but no error message provided"),
   })
   return false
end

local parse_block
local parse_expression

local function parse_list(state, block, node, parse_fn)
   if not block then return node end
   for _, item_block in ipairs(block) do
      local parsed_item = parse_fn(state, item_block)
      if parsed_item then
         table.insert(node, parsed_item)
      end
   end
   return node
end

local function parse_expression_list(state, block)
   if not block then

      local dummy_block = { kind = "expression_list", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      return new_node(state, dummy_block, "expression_list")
   end
   local node = new_node(state, block, "expression_list")
   if not node then
      local dummy_block = { kind = "expression_list", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "expression_list")
   end
   return parse_list(state, block, node, parse_expression)
end

local function parse_variable_list(state, block, as_expression)
   if not block then

      local dummy_block = { kind = "variable_list", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      return new_node(state, dummy_block, "variable_list")
   end
   local node = new_node(state, block, "variable_list")
   if not node then
      local dummy_block = { kind = "variable_list", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "variable_list")
   end
   for _, var_block in ipairs(block) do
      local var_node
      if not as_expression and (var_block.kind == "identifier" or var_block.kind == "variable") then
         local ident_block = var_block
         if var_block.kind == "variable" then
            ident_block = { y = var_block.y, x = var_block.x, tk = var_block.tk, kind = "identifier" }
         end
         var_node = new_node(state, ident_block)
         if ident_block[reader.BLOCK_INDEXES.VARIABLE.ANNOTATION] then
            local annotation = ident_block[reader.BLOCK_INDEXES.VARIABLE.ANNOTATION]
            if is_attribute[annotation.tk] and var_node then
               var_node.attribute = annotation.tk
            end
         end
      else

         var_node = parse_expression(state, var_block)
      end

      if var_node then
         table.insert(node, var_node)
      end
   end
   return node
end

local function parse_argument_list(state, block)
   if not block then
      local dummy_block = { kind = "argument_list", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      return new_node(state, dummy_block, "argument_list")
   end

   local node = new_node(state, block, "argument_list")
   if not node then
      local dummy_block = { kind = "argument_list", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
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
         local type_block = arg_block[reader.BLOCK_INDEXES.ARGUMENT.ANNOTATION]
         if type(type_block) == "table" and type_block.kind then
            arg_node.argtype = parse_type(state, type_block)
         end

         local is_optional = false
         for _, child in ipairs(arg_block) do
            if type(child) == "table" and child.kind == "question" then
               is_optional = true
               break
            end
         end

         if arg_node.tk == "..." then



            has_varargs = true
            is_optional = true
         else
            if is_optional then
               has_optional = true


            end

            if not is_optional and not has_varargs then
               min_arity = min_arity + 1
            end
         end

         arg_node.opt = is_optional

         table.insert(node, arg_node)
      end
   end

   return node, min_arity
end

local comment_node_kinds = {
   ["local_declaration"] = true,
   ["global_declaration"] = true,
   ["local_function"] = true,
   ["global_function"] = true,
   ["record_function"] = true,
   ["local_type"] = true,
   ["global_type"] = true,
   ["local_macroexp"] = true,
   ["local_macro"] = true,
}

local function comment_block_to_comment(cb)
   return {
      x = cb.x,
      y = cb.y,
      text = cb.tk or "",
   }
end

local function comment_block_end_y(cb)
   if cb.yend then
      return cb.yend
   end
   local text = cb.tk or ""
   local _, newlines = string.gsub(text, "\n", "")
   return cb.y + newlines
end

local function is_long_comment_block(cb)
   local text = cb.tk or ""
   return text:match("^%-%-%[(=*)%[") ~= nil
end

local function extract_attached_comments(pending, target)
   if #pending == 0 then
      return nil
   end

   local last = pending[#pending]
   local diff_y = target.y - comment_block_end_y(last)
   if is_long_comment_block(last) then
      if diff_y >= 0 and diff_y <= 1 then
         table.remove(pending, #pending)
         return { comment_block_to_comment(last) }
      else
         return nil
      end
   end

   if diff_y < 0 or diff_y > 1 then
      return nil
   end

   local first = #pending
   for i = #pending - 1, 1, -1 do
      local prev = pending[i]
      if is_long_comment_block(prev) then
         first = i + 1
         break
      end
      local gap = pending[i + 1].y - comment_block_end_y(prev)
      if gap > 1 then
         first = i + 1
         break
      end
      first = i
   end

   local attached_blocks = {}
   for i = first, #pending do
      table.insert(attached_blocks, pending[i])
   end
   for i = #pending, first, -1 do
      table.remove(pending, i)
   end

   local comments = {}
   for _, cb in ipairs(attached_blocks) do
      table.insert(comments, comment_block_to_comment(cb))
   end
   return comments
end

local function flush_unattached_comments(node, pending)
   if #pending == 0 then
      return
   end
   if not node.unattached_comments then
      node.unattached_comments = {}
   end
   for _, cb in ipairs(pending) do
      table.insert(node.unattached_comments, comment_block_to_comment(cb))
   end
   for i = #pending, 1, -1 do
      table.remove(pending, i)
   end
end

local function parse_statements(state, block, toplevel)
   if not block then
      local dummy_block = { kind = "statements", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      return new_node(state, dummy_block, "statements")
   end

   local node = new_node(state, block, "statements")
   local pending_comments = {}

   if block[1] and block[1].kind == "hashbang" then
      node.hashbang = block[1].tk
   end

   for _, item_block in ipairs(block) do
      if item_block.kind == "comment" then
         table.insert(pending_comments, item_block)
      elseif item_block.kind ~= "hashbang" then

         local parsed_item = parse_block(state, item_block)
         if parsed_item then
            if comment_node_kinds[item_block.kind] then
               local attached = extract_attached_comments(pending_comments, item_block)
               if attached then
                  parsed_item.comments = attached
               end
            end

            if toplevel and #pending_comments > 0 then
               flush_unattached_comments(node, pending_comments)
            else
               for i = #pending_comments, 1, -1 do
                  table.remove(pending_comments, i)
               end
            end

            for _, child in ipairs(item_block) do
               if child.kind == ";" then
                  parsed_item.semicolon = true
                  break
               end
            end
            if parsed_item.kind == "statements" then
               for _, c in ipairs(parsed_item) do
                  table.insert(node, c)
               end
            else
               table.insert(node, parsed_item)
            end
         end
      end
   end

   if toplevel and #pending_comments > 0 then
      flush_unattached_comments(node, pending_comments)
   end

   return node
end

local function parse_forin(state, block)
   local node = new_node(state, block, "forin")
   node.vars = parse_variable_list(state, block[reader.BLOCK_INDEXES.FORIN.VARS], false)
   node.exps = parse_expression_list(state, block[reader.BLOCK_INDEXES.FORIN.EXPS])
   if #node.exps < 1 then
      fail(state, block[reader.BLOCK_INDEXES.FORIN.EXPS], "missing iterator expression in generic for")
   elseif #node.exps > 3 then
      fail(state, block[reader.BLOCK_INDEXES.FORIN.EXPS], "too many expressions in generic for")
   end
   node.body = parse_statements(state, block[reader.BLOCK_INDEXES.FORIN.BODY])
   return node
end

local function node_is_require_call(n)
   if n.kind == "op" and n.op.op == "." then

      return node_is_require_call(n.e1)
   elseif n.kind == "op" and n.op.op == "@funcall" and
      n.e1.kind == "variable" and n.e1.tk == "require" and
      n.e2.kind == "expression_list" and #n.e2 == 1 and
      n.e2[reader.BLOCK_INDEXES.EXPRESSION_LIST.FIRST].kind == "string" then


      return n.e2[reader.BLOCK_INDEXES.EXPRESSION_LIST.FIRST].conststr
   end
   return nil
end

local block_to_constructor

parse_expression = function(state, block)
   if not block then return nil end

   local kind = block.kind
   local op_info = op_kinds[kind]

   if op_info then
      local node = new_node(state, block, "op")
      node.tk = nil
      node.op = {
         y = block.y,
         x = block.x,
         arity = op_info.arity,
         op = op_info.op,
         prec = precedences[op_info.arity][op_info.op],
      }
      node.e1 = parse_expression(state, block[reader.BLOCK_INDEXES.OP.E1])
      if not node.e1 then

         local dummy_block = { kind = nil, y = block.y or 1, x = block.x or 1, tk = "", yend = block.yend or 1, xend = block.xend or 1 }
         node.e1 = new_node(state, dummy_block, "error_node")
      end
      if op_info.arity == 2 then
         if op_info.op == "@funcall" then
            node.e2 = parse_expression_list(state, block[reader.BLOCK_INDEXES.OP.E2])
            local r = node_is_require_call(node)
            if not r and node.kind == "op" and node.op and node.e1.kind == "variable" and node.e1.tk == "pcall" then
               if node.e2 and #node.e2 == 2 then
                  local arg1 = node.e2[reader.BLOCK_INDEXES.EXPRESSION_LIST.FIRST]
                  local arg2 = node.e2[reader.BLOCK_INDEXES.EXPRESSION_LIST.SECOND]
                  if arg1.kind == "variable" and arg1.tk == "require" and arg2.kind == "string" and arg2.conststr then
                     r = arg2.conststr
                  end
               end
            end
            if r then
               table.insert(state.required_modules, r)
            end
         elseif op_info.op == "as" or op_info.op == "is" then
            node.e2 = new_node(state, block[reader.BLOCK_INDEXES.OP.E2], "cast")
            if node.e2 and block[reader.BLOCK_INDEXES.OP.E2] and block[reader.BLOCK_INDEXES.OP.E2][reader.BLOCK_INDEXES.CAST.TYPE] then
               local ct_block = block[reader.BLOCK_INDEXES.OP.E2][reader.BLOCK_INDEXES.CAST.TYPE]
               if ct_block.kind == "tuple_type" then
                  local ct
                  ct = parse_type_list(state, ct_block, "casttype")
                  node.e2.casttype = ct
               else
                  node.e2.casttype = parse_type(state, ct_block)
               end
            end
         elseif op_info.op == "." or op_info.op == ":" then

            node.e2 = new_node(state, block[reader.BLOCK_INDEXES.OP.E2], "identifier")
            if not node.e2 then
               local dummy_block = { kind = "identifier", y = block.y or 1, x = block.x or 1, tk = "", yend = block.yend or 1, xend = block.xend or 1 }
               node.e2 = new_node(state, dummy_block, "identifier")
            end
         else
            node.e2 = parse_expression(state, block[reader.BLOCK_INDEXES.OP.E2])
            if not node.e2 then
               local dummy_block = { kind = nil, y = block.y or 1, x = block.x or 1, tk = "", yend = block.yend or 1, xend = block.xend or 1 }
               node.e2 = new_node(state, dummy_block, "error_node")
            end
         end
      end
      return node
   end

   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = nil, y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "error_node")
   end

   if kind == "string" then
      node.conststr = block_string_value(block)
      if block.is_longstring ~= nil then
         node.is_longstring = block.is_longstring
      elseif block.tk then
         node.is_longstring = not not block.tk:match("^%[%=*%[")
      else
         node.is_longstring = false
      end
   elseif kind == "number" or kind == "integer" then
      node.kind = kind
      node.constnum = block_number_value(block)
   elseif kind == "boolean" then
      node.kind = kind
   elseif kind == "identifier" or kind == "variable" then
      node.kind = "variable"
   elseif kind == "macro_var" then
      if not state.in_macro_quote then
         fail(state, block, "macro variables can only appear in macro quotes")
      end
      node.kind = "macro_var"
   elseif kind == "paren" then
      node.e1 = parse_expression(state, block[reader.BLOCK_INDEXES.PAREN.EXP])
   elseif kind == "literal_table" then
      for _, item_block in ipairs(block) do
         local item_node = new_node(state, item_block, "literal_table_item")
         if item_node then
            if item_block.tk == "[" then
               item_node.key_parsed = "long"
               item_node.key = parse_expression(state, item_block[reader.BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY])
               item_node.value = parse_expression(state, item_block[reader.BLOCK_INDEXES.LITERAL_TABLE_ITEM.VALUE])
            elseif item_block.tk == "..." then
               item_node.key_parsed = "implicit"
               item_node.key = parse_expression(state, item_block[reader.BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY])
               item_node.value = parse_expression(state, item_block[reader.BLOCK_INDEXES.LITERAL_TABLE_ITEM.VALUE])
            else
               if item_block[reader.BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY] and item_block[reader.BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY].kind == "integer" then
                  item_node.key_parsed = "implicit"
                  item_node.key = parse_expression(state, item_block[reader.BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY])
                  item_node.value = parse_expression(state, item_block[reader.BLOCK_INDEXES.LITERAL_TABLE_ITEM.VALUE])
               else
                  item_node.key_parsed = "short"
                  item_node.key = parse_expression(state, item_block[reader.BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY])
                  if item_block[reader.BLOCK_INDEXES.LITERAL_TABLE_ITEM.TYPED_VALUE] then
                     item_node.itemtype = parse_type(state, item_block[reader.BLOCK_INDEXES.LITERAL_TABLE_ITEM.VALUE])
                     item_node.value = parse_expression(state, item_block[reader.BLOCK_INDEXES.LITERAL_TABLE_ITEM.TYPED_VALUE])
                  else
                     item_node.value = parse_expression(state, item_block[reader.BLOCK_INDEXES.LITERAL_TABLE_ITEM.VALUE])
                  end
               end
            end
            table.insert(node, item_node)
         end
      end
   elseif kind == "function" then
      node.typeargs = parse_typeargs_if_any(state, block[reader.BLOCK_INDEXES.FUNCTION.TYPEARGS])
      local args, min_arity = parse_argument_list(state, block[reader.BLOCK_INDEXES.FUNCTION.ARGS])
      node.args = args
      node.min_arity = min_arity
      local r = parse_type_list(state, block[reader.BLOCK_INDEXES.FUNCTION.RETS], "rets")
      node.rets = r
      node.body = parse_statements(state, block[reader.BLOCK_INDEXES.FUNCTION.BODY])
   elseif kind == "macro_invocation" then
      if state.in_local_macro then
         fail(state, block, "macro invocations cannot appear inside local macros")
      end
      node.e1 = parse_expression(state, block[reader.BLOCK_INDEXES.MACRO_INVOCATION.MACRO])
      node.args = parse_expression_list(state, block[reader.BLOCK_INDEXES.MACRO_INVOCATION.ARGS])
   elseif kind == "macro_quote" then
      if state.in_macro_quote then
         fail(state, block, "cannot nest macro quotes")
      end
      if not block[reader.BLOCK_INDEXES.MACRO_QUOTE.BLOCK] then
         return new_node(state, block, "literal_table")
      end
      local inner = block[reader.BLOCK_INDEXES.MACRO_QUOTE.BLOCK]






      local res = block_to_constructor(state, inner)
      state.in_macro_quote = false
      return res
   end
   return node
end

local function new_type(state, block, typename)
   return raw_type(state.filename, block.y, block.x, typename)
end

local function new_typedecl(state, block, def)
   local t = new_type(state, block, "typedecl")
   t.def = def
   return t
end

local function set_declname(def, declname)
   if def.typename == "generic" then
      def = def.t
   end

   if def.typename == "record" or def.typename == "interface" or def.typename == "enum" then
      if not def.declname then
         def.declname = declname
      end
   end
end

local function parse_newtype(state, block)
   local node = new_node(state, block, "newtype")
   if not node then
      local dummy_block = { kind = "newtype", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "newtype")
   end


   local default_type = new_type(state, block, "any")
   node.newtype = new_typedecl(state, block, default_type)


   if block[reader.BLOCK_INDEXES.NEWTYPE.TYPEDECL] then
      local def_block = block[reader.BLOCK_INDEXES.NEWTYPE.TYPEDECL]
      if def_block.kind == "typedecl" and def_block[reader.BLOCK_INDEXES.TYPEDECL.TYPE] then

         local inner_type = def_block[reader.BLOCK_INDEXES.TYPEDECL.TYPE]
         local typename = inner_type.kind
         if typename == "enum" then
            local enum_type = new_type(state, inner_type, "enum")
            enum_type.enumset = {}
            enum_type.value_comments = {}
            local pending_comments = {}
            for _, value_block in ipairs(inner_type) do
               if value_block.kind == "comment" then
                  table.insert(pending_comments, value_block)
               elseif value_block and value_block.tk then
                  local value_str = value_block.tk
                  if value_block.kind == "string" then
                     value_str = block_string_value(value_block) or value_str
                  elseif value_str:match('^".*"$') or value_str:match("^'.*'$") then
                     value_str = value_str:sub(2, -2)
                  end
                  enum_type.enumset[value_str] = true
                  local comments = extract_attached_comments(pending_comments, value_block)
                  if comments then
                     enum_type.value_comments[value_str] = comments
                  else
                     for i = #pending_comments, 1, -1 do
                        table.remove(pending_comments, i)
                     end
                  end
               end
            end
            node.newtype = new_typedecl(state, def_block, enum_type)
         else
            local type_node = parse_type(state, inner_type)
            if type_node then
               node.newtype = new_typedecl(state, def_block, type_node)
               if type_node.typename == "nominal" then
                  node.newtype.is_alias = true
               elseif type_node.typename == "generic" then
                  local deft = (type_node).t
                  if deft and deft.typename == "nominal" then
                     node.newtype.is_alias = true
                  end
               end
            end
         end
      else
         local type_node = parse_type(state, def_block)
         if type_node then
            node.newtype = new_typedecl(state, block, type_node)
            if type_node.typename == "nominal" then
               node.newtype.is_alias = true
            elseif type_node.typename == "generic" then
               local deft = (type_node).t
               if deft and deft.typename == "nominal" then
                  node.newtype.is_alias = true
               end
            end
         end
      end
   end

   return node
end


local parse_fns = {}

parse_fns.local_declaration = function(state, block)
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "local_declaration", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "local_declaration")
   end
   node.vars = parse_variable_list(state, block[reader.BLOCK_INDEXES.LOCAL_DECLARATION.VARS], false)

   if node.vars then
      for _, var_node in ipairs(node.vars) do
         if var_node.kind == "variable" then
            var_node.is_lvalue = true
         elseif var_node.kind == "op" and var_node.op and (var_node.op.op == "@index" or var_node.op.op == ".") then
            var_node.is_lvalue = true
         end
      end
   end
   local next_child = reader.BLOCK_INDEXES.LOCAL_DECLARATION.DECL
   if block[next_child] and block[next_child].kind == "tuple_type" then
      local dt
      dt = parse_type_list(state, block[next_child], "decltuple")
      node.decltuple = dt
      next_child = reader.BLOCK_INDEXES.LOCAL_DECLARATION.EXPS
   else


      local dummy_block = { kind = "tuple_type", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      dummy_block[reader.BLOCK_INDEXES.TUPLE_TYPE.FIRST] = { kind = "typelist", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      local dt
      dt = parse_type_list(state, dummy_block, "decltuple")
      node.decltuple = dt

      next_child = reader.BLOCK_INDEXES.LOCAL_DECLARATION.EXPS
   end
   if block[next_child] and block[next_child].kind == "expression_list" then
      node.exps = parse_expression_list(state, block[next_child])
   end
   return node
end
parse_fns.global_declaration = parse_fns.local_declaration

parse_fns.assignment = function(state, block)
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "assignment", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "assignment")
   end
   node.vars = parse_variable_list(state, block[reader.BLOCK_INDEXES.ASSIGNMENT.VARS], true)
   if block[reader.BLOCK_INDEXES.ASSIGNMENT.EXPS] and block[reader.BLOCK_INDEXES.ASSIGNMENT.EXPS].kind == "expression_list" then
      node.exps = parse_expression_list(state, block[reader.BLOCK_INDEXES.ASSIGNMENT.EXPS])
   end

   if node.vars then
      for _, var_node in ipairs(node.vars) do
         if var_node.kind == "variable" then
            var_node.is_lvalue = true
         elseif var_node.kind == "op" and var_node.op and (var_node.op.op == "@index" or var_node.op.op == ".") then
            var_node.is_lvalue = true
         end
      end
   end
   return node
end

parse_fns["if"] = function(state, block)
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "if", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "if")
   end

   node.if_blocks = {}






   local if_blocks_container = block[reader.BLOCK_INDEXES.IF.BLOCKS]
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

            if_block_node.exp = parse_expression(state, if_block_block[reader.BLOCK_INDEXES.IF_BLOCK.COND])
            if not if_block_node.exp then
               fail(state, if_block_block[reader.BLOCK_INDEXES.IF_BLOCK.COND], "invalid condition expression")
            end
            if_block_node.body = parse_statements(state, if_block_block[reader.BLOCK_INDEXES.IF_BLOCK.BODY])
         else

            if_block_node.body = parse_statements(state, if_block_block[reader.BLOCK_INDEXES.IF_BLOCK.BODY])
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

parse_fns["while"] = function(state, block)
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "while", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "while")
   end

   if not block[reader.BLOCK_INDEXES.WHILE.COND] then
      fail(state, block, "while statement missing condition")
      return node
   end
   if not block[reader.BLOCK_INDEXES.WHILE.BODY] then
      fail(state, block, "while statement missing body")
      return node
   end

   node.exp = parse_expression(state, block[reader.BLOCK_INDEXES.WHILE.COND])
   if not node.exp then
      fail(state, block[reader.BLOCK_INDEXES.WHILE.COND], "invalid while condition")
   end

   node.body = parse_statements(state, block[reader.BLOCK_INDEXES.WHILE.BODY])
   if not node.body then
      fail(state, block[reader.BLOCK_INDEXES.WHILE.BODY], "invalid while body")
   end

   return node
end

parse_fns.fornum = function(state, block)
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "fornum", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "fornum")
   end







   node.var = new_node(state, block[reader.BLOCK_INDEXES.FORNUM.VAR], "identifier")

   node.from = parse_expression(state, block[reader.BLOCK_INDEXES.FORNUM.FROM])
   node.to = parse_expression(state, block[reader.BLOCK_INDEXES.FORNUM.TO])

   if block[reader.BLOCK_INDEXES.FORNUM.BODY] then

      node.step = parse_expression(state, block[reader.BLOCK_INDEXES.FORNUM.STEP])
      node.body = parse_statements(state, block[reader.BLOCK_INDEXES.FORNUM.BODY])
   else

      node.body = parse_statements(state, block[reader.BLOCK_INDEXES.FORNUM.STEP])
   end

   return node
end

parse_fns.forin = function(state, block)
   local node = new_node(state, block, "forin")
   if not node then
      local dummy_block = { kind = "forin", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "forin")
   end
   node.vars = parse_variable_list(state, block[reader.BLOCK_INDEXES.FORIN.VARS], false)
   node.exps = parse_expression_list(state, block[reader.BLOCK_INDEXES.FORIN.EXPS])
   if node.exps and #node.exps < 1 then
      fail(state, block[reader.BLOCK_INDEXES.FORIN.EXPS], "missing iterator expression in generic for")
   elseif node.exps and #node.exps > 3 then
      fail(state, block[reader.BLOCK_INDEXES.FORIN.EXPS], "too many expressions in generic for")
   end
   node.body = parse_statements(state, block[reader.BLOCK_INDEXES.FORIN.BODY])
   return node
end

parse_fns["repeat"] = function(state, block)
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "repeat", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "repeat")
   end
   node.body = parse_statements(state, block[reader.BLOCK_INDEXES.REPEAT.BODY])
   if node.body then
      node.body.is_repeat = true
   end
   node.exp = parse_expression(state, block[reader.BLOCK_INDEXES.REPEAT.COND])
   return node
end

parse_fns["do"] = function(state, block)
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "do", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "do")
   end
   node.body = parse_statements(state, block[reader.BLOCK_INDEXES.DO.BODY])
   return node
end

parse_fns["return"] = function(state, block)
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "return", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "return")
   end
   node.exps = parse_expression_list(state, block[reader.BLOCK_INDEXES.RETURN.EXPS])
   return node
end

parse_fns["break"] = function(state, block)
   return new_node(state, block)
end

parse_fns["goto"] = function(state, block)
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "goto", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "goto")
   end
   if block[reader.BLOCK_INDEXES.GOTO.LABEL] then
      node.label = block[reader.BLOCK_INDEXES.GOTO.LABEL].tk
   end
   return node
end

parse_fns.label = function(state, block)
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "label", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "label")
   end
   if block[reader.BLOCK_INDEXES.LABEL.NAME] then
      node.label = block[reader.BLOCK_INDEXES.LABEL.NAME].tk
   end
   return node
end

parse_fns.local_function = function(state, block)
   local node = new_node(state, block, "local_function")
   if not node then
      local dummy_block = { kind = "local_function", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "local_function")
   end

   if not block[reader.BLOCK_INDEXES.LOCAL_FUNCTION.NAME] then
      fail(state, block, "local function missing name")
      return node
   end
   if not block[reader.BLOCK_INDEXES.LOCAL_FUNCTION.ARGS] then
      fail(state, block, "local function missing argument list")
      return node
   end
   if not block[reader.BLOCK_INDEXES.LOCAL_FUNCTION.BODY] then
      fail(state, block, "local function missing body")
      return node
   end

   node.name = new_node(state, block[reader.BLOCK_INDEXES.LOCAL_FUNCTION.NAME], "identifier")
   if not node.name then
      fail(state, block[reader.BLOCK_INDEXES.LOCAL_FUNCTION.NAME], "invalid function name")
      return node
   end

   node.typeargs = parse_typeargs_if_any(state, block[reader.BLOCK_INDEXES.LOCAL_FUNCTION.TYPEARGS])
   local args, min_arity = parse_argument_list(state, block[reader.BLOCK_INDEXES.LOCAL_FUNCTION.ARGS])
   node.args = args
   node.min_arity = min_arity
   local r
   r = parse_type_list(state, block[reader.BLOCK_INDEXES.LOCAL_FUNCTION.RETS], "rets")
   node.rets = r
   node.body = parse_statements(state, block[reader.BLOCK_INDEXES.LOCAL_FUNCTION.BODY])

   if not node.body then
      fail(state, block[reader.BLOCK_INDEXES.LOCAL_FUNCTION.BODY], "invalid function body")
   end

   return node
end

parse_fns.local_macro = function(state, block)
   if not block[reader.BLOCK_INDEXES.LOCAL_MACRO.NAME] then
      fail(state, block, "local macro missing name")
      local dummy_block = { kind = "local_function", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      return new_node(state, dummy_block, "local_function")
   end
   if not block[reader.BLOCK_INDEXES.LOCAL_MACRO.ARGS] then
      fail(state, block, "local macro missing argument list")
      local dummy_block = { kind = "local_function", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      return new_node(state, dummy_block, "local_function")
   end
   if not block[reader.BLOCK_INDEXES.LOCAL_MACRO.BODY] then
      fail(state, block, "local macro missing body")
      local dummy_block = { kind = "local_function", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      return new_node(state, dummy_block, "local_function")
   end

   local name_node = new_node(state, block[reader.BLOCK_INDEXES.LOCAL_MACRO.NAME], "identifier")
   local typeargs = parse_typeargs_if_any(state, block[reader.BLOCK_INDEXES.LOCAL_MACRO.TYPEARGS])
   local args, min_arity = parse_argument_list(state, block[reader.BLOCK_INDEXES.LOCAL_MACRO.ARGS])
   local r
   r = parse_type_list(state, block[reader.BLOCK_INDEXES.LOCAL_MACRO.RETS], "rets")
   local prev_local = state.in_local_macro
   local prev_quote = state.in_macro_quote
   state.in_local_macro = true
   state.in_macro_quote = false
   local body_stmts = parse_statements(state, block[reader.BLOCK_INDEXES.LOCAL_MACRO.BODY])
   state.in_local_macro = prev_local
   state.in_macro_quote = prev_quote
   local fn = new_node(state, block, "local_function")
   fn.name = name_node
   fn.typeargs = typeargs
   fn.args = args
   fn.min_arity = min_arity
   fn.rets = r
   fn.body = body_stmts
   fn[1] = body_stmts[1]
   return fn
end

function block_to_constructor(state, block)
   if not block then return nil end

   if block.kind == "macro_var" then
      local call = new_node(state, block, "op")
      call.tk = nil
      call.op = {
         y = block.y,
         x = block.x,
         arity = 2,
         op = "@funcall",
         prec = precedences[2]["@funcall"],
      }
      call.e1 = new_node(state, block, "variable")
      call.e1.tk = "clone"
      call.e2 = new_node(state, block, "expression_list")
      call.e2[reader.BLOCK_INDEXES.EXPRESSION_LIST.FIRST] = new_node(state, block[reader.BLOCK_INDEXES.MACRO_VAR.NAME], "variable")
      call.e2[reader.BLOCK_INDEXES.EXPRESSION_LIST.FIRST].tk = block[reader.BLOCK_INDEXES.MACRO_VAR.NAME] and block[reader.BLOCK_INDEXES.MACRO_VAR.NAME].tk or ""
      return call
   end

   local function add_string_field(tbl, owner, keyname, value)
      local it = new_node(state, owner, "literal_table_item")
      it.key_parsed = "short"
      it.key = new_node(state, owner, "identifier")
      it.key.tk = string.format("%q", keyname)
      it.value = new_node(state, owner, "string")
      it.value.tk = string.format("%q", value)
      it.value.conststr = value
      table.insert(tbl, it)
   end

   local function add_number_field(tbl, owner, keyname, value)
      local it = new_node(state, owner, "literal_table_item")
      it.key_parsed = "short"
      it.key = new_node(state, owner, "identifier")
      it.key.tk = string.format("%q", keyname)
      it.value = new_node(state, owner, "number")
      it.value.tk = tostring(value)
      it.value.constnum = value
      table.insert(tbl, it)
   end

   local node = new_node(state, block, "literal_table")
   if not node.yend then
      node.yend = block.yend or block.y
   end

   add_string_field(node, block, "kind", block.kind)

   if block.tk and block.tk ~= "" then
      add_string_field(node, block, "tk", block.tk)
   end

   if block.y then
      add_number_field(node, block, "y", block.y)
   end
   if block.x then
      add_number_field(node, block, "x", block.x)
   end
   if block.yend then
      add_number_field(node, block, "yend", block.yend)
   end
   if block.xend then
      add_number_field(node, block, "xend", block.xend)
   end

   if block.kind == "string" then
      add_string_field(node, block, "conststr", block_string_value(block) or block.tk or "")
   end

   local numeric_keys = {}
   for k, v in pairs(block) do
      if math.type(k) == "integer" and v and v.kind ~= nil then
         table.insert(numeric_keys, k)
      end
   end
   table.sort(numeric_keys)
   for _, i in ipairs(numeric_keys) do
      local child = block[i]
      local item = new_node(state, child, "literal_table_item")
      item.key_parsed = "long"
      item.key = new_node(state, child, "integer")
      item.key.tk = tostring(i)
      item.key.constnum = i
      item.value = block_to_constructor(state, child)
      table.insert(node, item)
   end

   return node
end

parse_fns.macro_var = function(state, block)
   if not state.in_macro_quote then
      fail(state, block, "macro variables can only appear in macro quotes")
   end
   local node = new_node(state, block, "macro_var")
   if block[reader.BLOCK_INDEXES.MACRO_VAR.NAME] then
      node.name = new_node(state, block[reader.BLOCK_INDEXES.MACRO_VAR.NAME], "identifier")
   end
   return node
end

parse_fns.global_function = function(state, block)
   local node = new_node(state, block, "global_function")
   if not node then
      local dummy_block = { kind = "global_function", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "global_function")
   end

   if not block[reader.BLOCK_INDEXES.GLOBAL_FUNCTION.NAME] then
      fail(state, block, "global function missing name")
      return node
   end
   if not block[reader.BLOCK_INDEXES.GLOBAL_FUNCTION.ARGS] then
      fail(state, block, "global function missing argument list")
      return node
   end
   if not block[reader.BLOCK_INDEXES.GLOBAL_FUNCTION.BODY] then
      fail(state, block, "global function missing body")
      return node
   end

   node.name = new_node(state, block[reader.BLOCK_INDEXES.GLOBAL_FUNCTION.NAME], "identifier")
   if not node.name then
      fail(state, block[reader.BLOCK_INDEXES.GLOBAL_FUNCTION.NAME], "invalid function name")
      return node
   end

   node.typeargs = parse_typeargs_if_any(state, block[reader.BLOCK_INDEXES.GLOBAL_FUNCTION.TYPEARGS])
   local args, min_arity = parse_argument_list(state, block[reader.BLOCK_INDEXES.GLOBAL_FUNCTION.ARGS])
   node.args = args
   node.min_arity = min_arity
   local r
   r = parse_type_list(state, block[reader.BLOCK_INDEXES.GLOBAL_FUNCTION.RETS], "rets")
   node.rets = r
   node.body = parse_statements(state, block[reader.BLOCK_INDEXES.GLOBAL_FUNCTION.BODY])

   if not node.body then
      fail(state, block[reader.BLOCK_INDEXES.GLOBAL_FUNCTION.BODY], "invalid function body")
   end

   return node
end

parse_fns.record_function = function(state, block)
   local node = new_node(state, block, "record_function")
   if node then
      node.tk = "function"
   end
   if not node then
      local dummy_block = { kind = "record_function", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "record_function")
   end
   if node then
      node.tk = "function"
   end

   if not block[reader.BLOCK_INDEXES.RECORD_FUNCTION.OWNER] then
      fail(state, block, "record function missing owner")
      return node
   end
   if not block[reader.BLOCK_INDEXES.RECORD_FUNCTION.NAME] then
      local gblock = {
         kind = "global_function",
         tk = block.tk,
         y = block.y,
         x = block.x,
         yend = block.yend,
         xend = block.xend,
         [reader.BLOCK_INDEXES.GLOBAL_FUNCTION.NAME] = block[reader.BLOCK_INDEXES.RECORD_FUNCTION.OWNER],
         [reader.BLOCK_INDEXES.GLOBAL_FUNCTION.TYPEARGS] = block[reader.BLOCK_INDEXES.RECORD_FUNCTION.TYPEARGS],
         [reader.BLOCK_INDEXES.GLOBAL_FUNCTION.ARGS] = block[reader.BLOCK_INDEXES.RECORD_FUNCTION.ARGS],
         [reader.BLOCK_INDEXES.GLOBAL_FUNCTION.RETS] = block[reader.BLOCK_INDEXES.RECORD_FUNCTION.RETS],
         [reader.BLOCK_INDEXES.GLOBAL_FUNCTION.BODY] = block[reader.BLOCK_INDEXES.RECORD_FUNCTION.BODY],
      }
      local gnode = parse_fns.global_function(state, gblock)
      gnode.implicit_global_function = true
      return gnode
   end
   if not block[reader.BLOCK_INDEXES.RECORD_FUNCTION.ARGS] then
      fail(state, block, "record function missing argument list")
      return node
   end
   if not block[reader.BLOCK_INDEXES.RECORD_FUNCTION.BODY] then
      fail(state, block, "record function missing body")
      return node
   end

   local owner_block = block[reader.BLOCK_INDEXES.RECORD_FUNCTION.OWNER]
   local name_block = block[reader.BLOCK_INDEXES.RECORD_FUNCTION.NAME]

   node.fn_owner = parse_expression(state, owner_block)
   if not node.fn_owner then
      fail(state, owner_block, "invalid function owner")
      return node
   end


   local left = node.fn_owner
   while left.kind == "op" and left.op.op == "." do
      left = left.e1
   end
   if left and left.kind == "variable" then
      left.kind = "type_identifier"
   end

   node.name = new_node(state, name_block, "identifier")
   if not node.name then
      fail(state, name_block, "invalid function name")
      return node
   end

   node.typeargs = parse_typeargs_if_any(state, block[reader.BLOCK_INDEXES.RECORD_FUNCTION.TYPEARGS])

   node.is_method = block.tk == ":"
   local args, min_arity = parse_argument_list(state, block[reader.BLOCK_INDEXES.RECORD_FUNCTION.ARGS])
   node.args = args
   node.min_arity = min_arity
   if node.is_method and node.args then
      local self_node = new_node(state, block[reader.BLOCK_INDEXES.RECORD_FUNCTION.ARGS], "identifier")
      if self_node then
         self_node.tk = "self"
         self_node.is_self = true
         table.insert(node.args, 1, self_node)
         node.min_arity = node.min_arity + 1
      end
   end
   local r
   r = parse_type_list(state, block[reader.BLOCK_INDEXES.RECORD_FUNCTION.RETS], "rets")
   node.rets = r
   node.body = parse_statements(state, block[reader.BLOCK_INDEXES.RECORD_FUNCTION.BODY])

   if not node.body then
      fail(state, block[reader.BLOCK_INDEXES.RECORD_FUNCTION.BODY], "invalid function body")
   end

   return node
end

parse_fns.pragma = function(state, block)
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "pragma", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "pragma")
   end
   if block[reader.BLOCK_INDEXES.PRAGMA.KEY] then
      node.pkey = block[reader.BLOCK_INDEXES.PRAGMA.KEY].tk
   end
   if block[reader.BLOCK_INDEXES.PRAGMA.VALUE] then
      node.pvalue = block[reader.BLOCK_INDEXES.PRAGMA.VALUE].tk
   end
   return node
end

parse_fns.local_type = function(state, block)
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "local_type", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "local_type")
   end
   if block[reader.BLOCK_INDEXES.LOCAL_TYPE.VAR] then
      node.var = new_node(state, block[reader.BLOCK_INDEXES.LOCAL_TYPE.VAR])
   end
   if block[reader.BLOCK_INDEXES.LOCAL_TYPE.VALUE] then
      if block[reader.BLOCK_INDEXES.LOCAL_TYPE.VALUE].kind == "newtype" then
         node.value = parse_newtype(state, block[reader.BLOCK_INDEXES.LOCAL_TYPE.VALUE])
         if node.value and node.value.newtype and node.var and node.var.tk then
            local def = node.value.newtype.def
            if def and def.typename == "generic" and def.t.typename == "generic" then
               fail(state, block[reader.BLOCK_INDEXES.LOCAL_TYPE.VALUE], "cannot declare type arguments twice in type declaration")
            end
            set_declname(node.value.newtype.def, node.var.tk)
         end
      else
         node.value = parse_expression(state, block[reader.BLOCK_INDEXES.LOCAL_TYPE.VALUE])
      end
   end
   return node
end
parse_fns.global_type = function(state, block)
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "global_type", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "global_type")
   end
   if block[reader.BLOCK_INDEXES.GLOBAL_TYPE.VAR] then
      node.var = new_node(state, block[reader.BLOCK_INDEXES.GLOBAL_TYPE.VAR])
   end
   if block[reader.BLOCK_INDEXES.GLOBAL_TYPE.VALUE] then
      if block[reader.BLOCK_INDEXES.GLOBAL_TYPE.VALUE].kind == "newtype" then
         node.value = parse_newtype(state, block[reader.BLOCK_INDEXES.GLOBAL_TYPE.VALUE])
         if node.value and node.value.newtype and node.var and node.var.tk then
            local def = node.value.newtype.def
            if def and def.typename == "generic" and (def).t and (def).t.typename == "generic" then
               fail(state, block[reader.BLOCK_INDEXES.GLOBAL_TYPE.VALUE], "cannot declare type arguments twice in type declaration")
            end
            set_declname(node.value.newtype.def, node.var.tk)
         end
      else
         node.value = parse_expression(state, block[reader.BLOCK_INDEXES.GLOBAL_TYPE.VALUE])
      end
   end
   return node
end
parse_fns.interface = function(state, block)
   local node = new_node(state, block)
   if not node then
      local dummy_block = { kind = "interface", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "interface")
   end
   return node
end
parse_fns.local_macroexp = function(state, block)
   local node = new_node(state, block, "local_macroexp")
   if not node then
      local dummy_block = { kind = "local_macroexp", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "local_macroexp")
   end

   if block[reader.BLOCK_INDEXES.LOCAL_MACROEXP.NAME] then
      node.name = new_node(state, block[reader.BLOCK_INDEXES.LOCAL_MACROEXP.NAME], "identifier")
   end

   if block[reader.BLOCK_INDEXES.LOCAL_MACROEXP.EXP] then
      node.macrodef = parse_fns.macroexp(state, block[reader.BLOCK_INDEXES.LOCAL_MACROEXP.EXP])
   end

   return node
end
parse_fns.macroexp = function(state, block)
   local node = new_node(state, block, "macroexp")
   if not node then
      local dummy_block = { kind = "macroexp", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      node = new_node(state, dummy_block, "macroexp")
   end

   local idx = 1
   if block[idx] and block[idx].kind == "typelist" then
      node.typeargs = parse_typeargs_if_any(state, block[idx])
      idx = idx + 1
   end

   node.args, node.min_arity = parse_argument_list(state, block[idx])
   local r
   r = parse_type_list(state, block[idx + 1], "rets")
   node.rets = r
   node.exp = parse_expression(state, block[idx + 2])

   return node
end




parse_block = function(state, block)
   if not block then return nil end

   local kind = block.kind
   if kind == "forin" then
      return parse_forin(state, block)
   elseif kind == "interface" then
      local node = new_node(state, block, "interface")
      if not node then
         local dummy_block = { kind = "interface", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
         node = new_node(state, dummy_block, "interface")
      end
      return node
   elseif kind == "statements" then
      return parse_statements(state, block)
   end
   local f = parse_fns[block.kind]
   if f then
      return f(state, block)
   else
      return parse_expression(state, block)
   end
end

function parser.parse(input, filename, parse_lang)
   filename = filename or "input"
   if not input then
      return nil, { { filename = filename, y = 1, x = 1, msg = "input is nil" } }, {}
   end

   local state = {
      block = input,
      errs = {},
      filename = filename,
      end_alignment_hint = nil,
      required_modules = {},
      parse_lang = parse_lang or "tl",
      in_local_macro = false,
      in_macro_quote = false,
   }

   local nodes = parse_statements(state, input, true)

   errors.clear_redundant_errors(state.errs)
   return nodes, state.errs, state.required_modules
end


function parser.parse_program(tokens, errs, filename, parse_lang)
   errors.clear_redundant_errors(errs or {})
   return nil, {}
end

local function new_generic(state, block, typeargs, typ)
   local gt = new_type(state, block, "generic")
   gt.typeargs = typeargs
   gt.t = typ
   return gt
end

local function new_tuple(state, block, typelist, is_va)
   local t = new_type(state, block, "tuple")
   t.is_va = is_va
   t.tuple = typelist or {}
   return t, t.tuple
end

local function new_nominal(state, block, name)
   local t = new_type(state, block, "nominal")
   if name then
      t.names = { name }
   end
   return t
end

local parse_base_type
local parse_simple_type_or_nominal
local parse_function_type
local parse_record_like_type
local parse_where_clause

parse_typeargs_if_any = function(state, block)
   if not block or block.kind ~= "typelist" then
      return nil
   end

   local out = {}

   for _, ta_block_item in ipairs(block) do
      if ta_block_item.kind == "typeargs" then
         local ta = new_type(state, ta_block_item, "typearg")
         local ok = true

         local name_block = ta_block_item[reader.BLOCK_INDEXES.TYPEARG.NAME]
         if name_block and name_block.kind == "identifier" then
            ta.typearg = name_block.tk
         else
            fail(state, ta_block_item, "expected type argument name")
            ok = false
         end

         if ok then
            local constraint_block = ta_block_item[reader.BLOCK_INDEXES.TYPEARG.CONSTRAINT]
            if constraint_block then
               local constraint_type = parse_type(state, constraint_block)
               if constraint_type then
                  ta.constraint = constraint_type
               else
                  fail(state, constraint_block, "invalid type constraint")

               end
            end

            table.insert(out, ta)
         end
      end
   end

   return out
end

parse_function_type = function(state, block)
   local typ = new_type(state, block, "function")

   local args, maybemet, min_arity = parse_type_list(state, block[reader.BLOCK_INDEXES.FUNCTION_TYPE.ARGS], "decltuple")
   typ.args = args
   typ.maybe_method = maybemet
   typ.min_arity = min_arity
   local rets
   rets = parse_type_list(state, block[reader.BLOCK_INDEXES.FUNCTION_TYPE.RETS], "rets")
   typ.rets = rets
   typ.is_method = false

   if block[reader.BLOCK_INDEXES.FUNCTION_TYPE.MACROEXP] then
      typ.macroexp = parse_fns.macroexp(state, block[reader.BLOCK_INDEXES.FUNCTION_TYPE.MACROEXP])
   end

   return typ
end

parse_where_clause = function(state, block, def)
   local node = new_node(state, block, "macroexp")
   node.is_method = true
   node.args = new_node(state, block[reader.BLOCK_INDEXES.MACROEXP.ARGS] or block, "argument_list")
   node.args[reader.BLOCK_INDEXES.ARGUMENT_LIST.FIRST] = new_node(state, block[reader.BLOCK_INDEXES.MACROEXP.ARGS] and block[reader.BLOCK_INDEXES.MACROEXP.ARGS][reader.BLOCK_INDEXES.ARGUMENT_LIST.FIRST] or block, "argument")
   node.args[reader.BLOCK_INDEXES.ARGUMENT_LIST.FIRST].tk = "self"
   local selftype = new_type(state, block, "self")
   selftype.display_type = def
   node.args[reader.BLOCK_INDEXES.ARGUMENT_LIST.FIRST].argtype = selftype
   node.min_arity = 1
   local ret_tuple = new_tuple(state, block, { new_type(state, block, "boolean") })
   node.rets = ret_tuple
   node.exp = parse_expression(state, block[reader.BLOCK_INDEXES.MACROEXP.EXP])
   return node
end

local function store_field_in_record(state, block, name, newt, def, meta, comments)
   local fields
   local order
   local field_comments
   if meta then
      if not def.meta_fields then
         def.meta_fields = {}
         def.meta_field_order = {}
      end
      fields = def.meta_fields
      order = def.meta_field_order
      field_comments = def.meta_field_comments
      if not field_comments then
         field_comments = {}
         def.meta_field_comments = field_comments
      end
   else
      if not def.field_comments then
         def.field_comments = {}
      end
      fields = def.fields
      order = def.field_order
      field_comments = def.field_comments
   end

   if comments and not field_comments then
      field_comments = {}
      if meta then
         def.meta_field_comments = field_comments
      else
         def.field_comments = field_comments
      end
   end

   if not fields[name] then
      if newt.typename == "typedecl" then
         set_declname(newt.def, name)
      end
      fields[name] = newt
      field_comments[name] = field_comments[name] or {}
      if comments then
         field_comments[name] = { comments }
      end
      table.insert(order, name)
      return
   end

   local oldt = fields[name]
   local function basetype(t)
      if t.typename == "generic" then
         return t.t
      else
         return t
      end
   end
   local oldf = basetype(oldt)
   local newf = basetype(newt)

   local function store_comment_for_poly(poly)
      if not field_comments then
         return
      end
      if comments then
         if not field_comments[name] then
            field_comments[name] = {}
         end
         while #field_comments[name] < (#poly.types - 1) do
            table.insert(field_comments[name], {})
         end
         table.insert(field_comments[name], comments)
      elseif field_comments and field_comments[name] then
         table.insert(field_comments[name], {})
      end
   end

   if newf.typename == "function" then
      if oldf.typename == "function" then
         local p = new_type(state, block, "poly")
         p.types = { oldt, newt }
         fields[name] = p
         store_comment_for_poly(p)
      elseif oldt.typename == "poly" then
         table.insert((oldt).types, newt)
         store_comment_for_poly(oldt)
      else
         fail(state, block, "attempt to redeclare field '" .. name .. "' (only functions can be overloaded)")
      end
   else
      fail(state, block, "attempt to redeclare field '" .. name .. "' (only functions can be overloaded)")
   end
end

parse_record_like_type = function(state, block, typename)
   local decl = new_type(state, block, typename)
   decl.fields = {}
   decl.field_order = {}
   decl.field_comments = {}
   decl.meta_field_comments = {}

   if typename == "interface" then
      decl.interface_list = {}
   end

   if block[reader.BLOCK_INDEXES.RECORD.ARRAY_TYPE] and block[reader.BLOCK_INDEXES.RECORD.ARRAY_TYPE].kind == "array_type" then
      local atype = parse_base_type(state, block[reader.BLOCK_INDEXES.RECORD.ARRAY_TYPE])
      decl.elements = atype.elements
      decl.interface_list = { atype }
   end

   if block[reader.BLOCK_INDEXES.RECORD.INTERFACES] and block[reader.BLOCK_INDEXES.RECORD.INTERFACES].kind == "interface_list" then
      decl.interface_list = decl.interface_list or {}
      for _, iface in ipairs(block[reader.BLOCK_INDEXES.RECORD.INTERFACES]) do
         table.insert(decl.interface_list, parse_type(state, iface))
      end
   end

   local userdata_seen = false
   for _, child in ipairs(block) do
      if child.kind == "userdata" then
         if userdata_seen then
            fail(state, child, "duplicated 'userdata' declaration")
         end
         decl.is_userdata = true
         userdata_seen = true
      end
   end

   local function parse_field_list(list_block, meta)
      if not list_block then return end
      local pending_field_comments = {}
      for _, fld in ipairs(list_block) do
         if fld.kind == "comment" then
            table.insert(pending_field_comments, fld)
         elseif fld.kind == "record_field" then
            local name_node = fld[reader.BLOCK_INDEXES.RECORD_FIELD.NAME]
            local comments = extract_attached_comments(pending_field_comments, name_node or fld)
            local field_name
            if name_node and name_node.kind == "string" then
               field_name = block_string_value(name_node) or name_node.tk or ""
            else
               field_name = name_node and name_node.tk or ""
            end
            local t = parse_type(state, fld[reader.BLOCK_INDEXES.RECORD_FIELD.TYPE])
            if t.typename == "function" and t.maybe_method then
               t.is_method = true
            end
            store_field_in_record(state, fld, field_name, t, decl, meta, comments)
            for i = #pending_field_comments, 1, -1 do
               table.remove(pending_field_comments, i)
            end
         elseif fld.kind == "local_type" then
            local target = fld[reader.BLOCK_INDEXES.LOCAL_TYPE.VAR] or fld
            local comments = extract_attached_comments(pending_field_comments, target)
            if fld[reader.BLOCK_INDEXES.LOCAL_TYPE.VAR] and fld[reader.BLOCK_INDEXES.LOCAL_TYPE.VALUE] then
               local vname = fld[reader.BLOCK_INDEXES.LOCAL_TYPE.VAR].tk
               local nt_node = parse_newtype(state, fld[reader.BLOCK_INDEXES.LOCAL_TYPE.VALUE])
               if nt_node and nt_node.newtype then
                  store_field_in_record(state, fld, vname, nt_node.newtype, decl, meta, comments)
               end
            end
            for i = #pending_field_comments, 1, -1 do
               table.remove(pending_field_comments, i)
            end
         else
            for i = #pending_field_comments, 1, -1 do
               table.remove(pending_field_comments, i)
            end
         end
      end
   end

   parse_field_list(block[reader.BLOCK_INDEXES.RECORD.FIELDS], false)
   parse_field_list(block[reader.BLOCK_INDEXES.RECORD.META_FIELDS], true)

   if block[reader.BLOCK_INDEXES.RECORD.WHERE_CLAUSE] then
      local where_macroexp = parse_where_clause(state, block[reader.BLOCK_INDEXES.RECORD.WHERE_CLAUSE], decl)
      local typ = new_type(state, block[reader.BLOCK_INDEXES.RECORD.WHERE_CLAUSE], "function")
      typ.is_method = true
      typ.min_arity = 1
      local arg = a_type(where_macroexp, "self", { display_type = decl })
      typ.args = new_tuple(state, block[reader.BLOCK_INDEXES.RECORD.WHERE_CLAUSE], { arg })
      typ.rets = new_tuple(state, block[reader.BLOCK_INDEXES.RECORD.WHERE_CLAUSE], { new_type(state, block[reader.BLOCK_INDEXES.RECORD.WHERE_CLAUSE], "boolean") })
      typ.macroexp = where_macroexp
      store_field_in_record(state, block[reader.BLOCK_INDEXES.RECORD.WHERE_CLAUSE], "__is", typ, decl, true)
   end

   return decl
end

parse_simple_type_or_nominal = function(state, block)
   local tk = block.tk
   local st = simple_types[tk]
   if st then
      return new_type(state, block, tk)
   elseif tk == "table" then
      local typ = new_type(state, block, "map")
      typ.keys = new_type(state, block, "any")
      typ.values = new_type(state, block, "any")
      return typ
   end

   if block.kind == "nominal_type" then
      local name_block = block[reader.BLOCK_INDEXES.NOMINAL_TYPE.NAME] or block[1]
      if name_block and name_block.kind == "nominal_type" then
         return parse_simple_type_or_nominal(state, name_block)
      end

      local typ = new_nominal(state, block)
      typ.names = {}
      local current_block_idx = 1

      if block[current_block_idx] and block[current_block_idx].kind == "identifier" then
         table.insert(typ.names, block[current_block_idx].tk)
         current_block_idx = current_block_idx + 1
      elseif block.tk and block.tk ~= "" then
         table.insert(typ.names, block.tk)
      else
         if name_block and name_block.kind == "identifier" then
            table.insert(typ.names, name_block.tk)
            if block[1] == name_block then
               current_block_idx = current_block_idx + 1
            end
         else
            fail(state, block, "Nominal type block has no initial name part in tk or first child.")
            table.insert(typ.names, "unknown_nominal_type")
            return typ
         end
      end


      while block[current_block_idx] and block[current_block_idx].kind == "identifier" do
         table.insert(typ.names, block[current_block_idx].tk)
         current_block_idx = current_block_idx + 1
      end


      if block[current_block_idx] and block[current_block_idx].kind == "typelist" then
         typ.typevals = {}
         for _, tv_block in ipairs(block[current_block_idx]) do
            local parsed_tv = parse_type(state, tv_block)
            if parsed_tv then
               table.insert(typ.typevals, parsed_tv)
            else
               fail(state, tv_block, "Invalid type argument in nominal type.")
            end
         end
      end
      if #typ.names == 0 then
         fail(state, block, "Nominal type ended up with no name parts.")
         table.insert(typ.names, block.tk or "unknown_nominal_final")
      end
      return typ
   end

   return new_nominal(state, block, tk)
end

parse_base_type = function(state, block)
   if not block then
      fail(state, { y = 1, x = 1 }, "expected a type")
      return new_type(state, { y = 1, x = 1 }, "any")
   end

   local tk = block.tk

   if block.kind == "identifier" or block.kind == "nominal_type" or simple_types[tk] then
      return parse_simple_type_or_nominal(state, block)
   elseif block.kind == "function" then
      return parse_function_type(state, block)
   elseif block.kind == "generic_type" then
      local typeargs = parse_typeargs_if_any(state, block[reader.BLOCK_INDEXES.GENERIC_TYPE.TYPEARGS])
      local base = parse_base_type(state, block[reader.BLOCK_INDEXES.GENERIC_TYPE.BASE])
      return new_generic(state, block, typeargs, base)
   elseif block.kind == "record" then
      return parse_record_like_type(state, block, "record")
   elseif block.kind == "interface" then
      return parse_record_like_type(state, block, "interface")
   elseif block.kind == "array_type" then
      local decl = new_type(state, block, "array")
      decl.elements = parse_type(state, block[reader.BLOCK_INDEXES.ARRAY_TYPE.ELEMENT])
      end_at(decl, block)
      return decl
   elseif block.kind == "map_type" then
      local decl = new_type(state, block, "map")
      decl.keys = parse_type(state, block[reader.BLOCK_INDEXES.MAP_TYPE.KEYS])
      decl.values = parse_type(state, block[reader.BLOCK_INDEXES.MAP_TYPE.VALUES])
      end_at(decl, block)
      return decl
   elseif block.kind == "typelist" and block.tk == "{" then
      local decl = new_type(state, block, "tupletable")
      decl.types = {}
      for _, t in ipairs(block) do
         table.insert(decl.types, parse_type(state, t))
      end
      end_at(decl, block)
      return decl
   elseif block.kind == "union_type" then
      local u = new_type(state, block, "union")
      u.types = {}
      for _, t in ipairs(block) do
         table.insert(u.types, parse_type(state, t))
      end
      end_at(u, block)
      return u
   elseif block.kind == "nil" then
      return new_type(state, block, "nil")
   end

   fail(state, block, "expected a type")
   return new_type(state, block, "any")
end

parse_type = function(state, block)
   if not block then
      return new_type(state, { y = 1, x = 1 }, "any")
   end

   if block.kind == "paren" then
      if not block[reader.BLOCK_INDEXES.PAREN.EXP] then
         fail(state, block, "empty parentheses in type")
         return new_type(state, block, "any")
      end
      return parse_type(state, block[reader.BLOCK_INDEXES.PAREN.EXP])
   end

   if block.kind == "union_type" then
      local u = new_type(state, block, "union")
      u.types = {}
      for _, t in ipairs(block) do
         table.insert(u.types, parse_base_type(state, t))
      end
      return u
   end

   if block.kind == "typelist" and block.tk == "{" then
      return parse_base_type(state, block)
   end

   local bt = parse_base_type(state, block)
   if not bt then
      fail(state, block, "failed to parse type")
      return new_type(state, block, "any")
   end

   return bt
end

parse_type_list = function(state, block, mode)
   local t, list = new_tuple(state, block or { y = 1, x = 1, tk = "", kind = "typelist" })
   local maybe_method = false
   local min_arity = 0

   if not block or block.kind ~= "tuple_type" then

      if not block then
         return t, maybe_method, min_arity
      end


      if block.kind == "typelist" then
         for _, tb in ipairs(block) do
            local ty = parse_type(state, tb)
            if ty then
               table.insert(list, ty)
            end
         end
         return t, maybe_method, min_arity
      end


      local single_type = parse_type(state, block)
      if single_type then
         table.insert(list, single_type)
      end
      return t, maybe_method, min_arity
   end


   local type_container_block = block[reader.BLOCK_INDEXES.TUPLE_TYPE.FIRST]
   local is_va_from_block = false

   if type_container_block and type_container_block.kind == "..." then
      t.is_va = true
      is_va_from_block = true
      type_container_block = block[reader.BLOCK_INDEXES.TUPLE_TYPE.SECOND]
   end

   if type_container_block and type_container_block.kind == "typelist" then
      for idx, type_block_item in ipairs(type_container_block) do
         if type_block_item.kind == "argument_type" then
            local arg_idx = 1
            if type_block_item[reader.BLOCK_INDEXES.ARGUMENT_TYPE.NAME] and type_block_item[reader.BLOCK_INDEXES.ARGUMENT_TYPE.NAME].kind == "identifier" then
               if arg_idx == 1 and type_block_item[reader.BLOCK_INDEXES.ARGUMENT_TYPE.NAME].tk == "self" and #list == 0 then
                  maybe_method = true
               end
               arg_idx = 2
            end

            local is_va = false
            local is_optional = false

            while type_block_item[arg_idx] and type_block_item[arg_idx].kind == "question" do
               is_optional = true
               arg_idx = arg_idx + 1
            end

            if type_block_item[arg_idx] and type_block_item[arg_idx].kind == "..." then
               is_va = true
               arg_idx = arg_idx + 1
            end

            local arg_type_node = parse_type(state, type_block_item[arg_idx])
            if arg_type_node then
               table.insert(list, arg_type_node)
               for j = arg_idx + 1, #type_block_item do
                  local child = type_block_item[j]
                  if child.kind == "..." then
                     is_va = true
                  elseif child.kind == "question" then
                     is_optional = true
                  end
               end
            else
               fail(state, type_block_item, "invalid type in list")
            end

            if is_va and idx < #type_container_block then
               local msg = "'...' can only be last in a type list"
               if mode == "decltuple" then
                  msg = "'...' can only be last argument"
               end
               fail(state, type_block_item, msg)
            end

            if is_va then
               t.is_va = true
            end
            if not is_optional and not is_va then
               min_arity = min_arity + 1
            end
         elseif type_block_item.kind == "..." then
            if idx == #type_container_block then
               t.is_va = true
            else
               local msg = "'...' can only be last in a type list"
               if mode == "decltuple" then
                  msg = "'...' can only be last argument"
               end
               fail(state, type_block_item, msg)
            end
         else
            local parsed_type = parse_type(state, type_block_item)
            if parsed_type then
               table.insert(list, parsed_type)
            else
               fail(state, type_block_item, "invalid type in list")
            end
         end
      end
   elseif type_container_block then
      local parsed_type = parse_type(state, type_container_block)
      if parsed_type then
         table.insert(list, parsed_type)
      else
         fail(state, type_container_block, "invalid type in tuple")
      end
   end


   if not is_va_from_block then

      if block and block[reader.BLOCK_INDEXES.TUPLE_TYPE.SECOND] and block[reader.BLOCK_INDEXES.TUPLE_TYPE.SECOND].kind == "..." then
         if #list > 0 then
            t.is_va = true
         else
            fail(state, block[reader.BLOCK_INDEXES.TUPLE_TYPE.SECOND], "unexpected '...'")
         end
      elseif #list > 0 then

         local last_block_in_list = type_container_block and type_container_block[#type_container_block]
         if last_block_in_list and last_block_in_list.kind == "..." then
            if #list > 0 then
               t.is_va = true

               table.remove(list, #list)
            else
               fail(state, last_block_in_list, "unexpected '...'")
            end
         end
      end
   end

   return t, maybe_method, min_arity
end

function parser.parse_type(state, block)
   return parse_type(state, block)
end

function parser.parse_type_list(state, block, mode)
   return parse_type_list(state, block, mode)
end

function parser.operator(node, arity, op)
   return { y = node.y, x = node.x, arity = arity, op = op, prec = precedences[arity][op] }
end

function parser.node_is_funcall(node)
   return node.kind == "op" and node.op.op == "@funcall"
end

function parser.node_is_require_call(n)
   if n.kind == "op" and n.op.op == "." then

      return parser.node_is_require_call(n.e1)
   elseif n.kind == "op" and n.op.op == "@funcall" and
      n.e1.kind == "variable" and n.e1.tk == "require" and
      n.e2.kind == "expression_list" and #n.e2 == 1 and
      n.e2[reader.BLOCK_INDEXES.EXPRESSION_LIST.FIRST].kind == "string" then


      return n.e2[reader.BLOCK_INDEXES.EXPRESSION_LIST.FIRST].conststr
   end
   return nil
end

function parser.node_at(w, n)
   n.f = assert(w.f)
   n.x = w.x
   n.y = w.y
   return n
end

return parser
