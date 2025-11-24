local block = require("teal.block")
local type Block = block.Block
local type BlockLang = block.BlockLang
local BLOCK_INDEXES = block.BLOCK_INDEXES

local errors = require("teal.errors")
local type Error = errors.Error
local type Where = errors.Where
local parser = require("teal.parser")
local type ParserNode = parser.Node

local record macro_eval
   new_env: function(): MacroEnv
   compile_all_and_expand: function(node: Block, filename: string, read_lang: BlockLang, errs: {Error}): Block
end

local record MacroSig
   kinds: {string}
   vararg: string
end

local type MacroFunction = function(...: Block): Block
   
local type MacroValue = nil | boolean | number | string | MacroFunction | Block

local record MacroEnv
   macros: {string: MacroFunction}
   signatures: {string: MacroSig}
   where: Where
   block: function(kind: block.BlockKind): Block
   expect: function(v: MacroValue, k: string): Block
   clone: function(v: Block): Block
end

local function numeric_child_keys(b: Block): {integer}
   local keys: {integer} = {}
   for k, child in pairs(b as {string|integer: Block | nil}) do
      if k is integer and child then
         table.insert(keys, k)
      end
   end
   table.sort(keys)
   return keys
end

local function clone_value(v: Block): Block
   local out: Block = {
      kind = v.kind,
      f = v.f,
      y = v.y,
      x = v.x,
      tk = v.tk,
      yend = v.yend,
      xend = v.xend,
      constnum = v.constnum,
      conststr = v.conststr,
      is_longstring = v.is_longstring,
   }
   for _, idx in ipairs(numeric_child_keys(v)) do
      local child = v[idx]
      if child then
         out[idx] = clone_value(child)
      end
   end
   return out
end

local function reanchor_block_positions(b: Block, where_y: integer | nil, where_x: integer | nil, seen_blocks: {Block:boolean})
   if seen_blocks[b] then
      return
   end
   seen_blocks[b] = true

   if where_y then
      b.y = where_y
      b.yend = where_y
   end
   if where_x then
      b.x = where_x
      b.xend = where_x
   end

   for _, idx in ipairs(numeric_child_keys(b)) do
      local child = b[idx]
      if child then
         reanchor_block_positions(child, where_y, where_x, seen_blocks)
      end
   end
end

function macro_eval.new_env(): MacroEnv
   local env: MacroEnv = {
      macros = {},
      signatures = {},
      where = { f = "@macro", y = 1, x = 1 },
      block = function(_: block.BlockKind): Block
         return { kind = "statements", f = "@macro", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
      end,
      expect = function(_: MacroValue, _: string): Block
         error("macro env not initialized")
         return nil
      end,
      clone = clone_value,
   }
   env.block = function(kind: block.BlockKind): Block
      local w = env.where
      return { kind = kind, f = w.f, y = w.y, x = w.x, tk = "", yend = w.y, xend = w.x }
   end
   env.expect = function(b: Block, k: block.BlockKind): Block
      if b and b.kind == k then
         return b
      end
      error("expected " .. k .. ", got " .. (b and b.kind or "nil"))
      return nil
   end

   --todo: restrict
   setmetatable(env, { __index = _G })
   -- macro signatures: name -> { kinds = {"stmt"|"expr"...}, vararg?: "stmt"|"expr" }
   return env
end

local function is_statement_kind(k: block.BlockKind): boolean
   return k == "assignment" or k == "local_declaration" or k == "global_declaration" or
          k == "return" or k == "if" or k == "while" or k == "fornum" or k == "forin" or
          k == "do" or k == "repeat" or k == "local_function" or k == "global_function" or
          k == "record_function" or k == "newtype" or k == "pragma"
end

local function compile_local_macro(mb: Block, filename: string, read_lang: BlockLang, env: MacroEnv, errs: {Error})
   local name_block = mb[BLOCK_INDEXES.LOCAL_MACRO.NAME]
   if not name_block or name_block.kind ~= "identifier" then
      return
   end
   local name = name_block.tk

   local sig: MacroSig = { kinds = {}, vararg = "" }
   local args = mb[BLOCK_INDEXES.LOCAL_MACRO.ARGS]
   if args then
      local idx = 1
      for _, ab in ipairs(args) do
         local expected: string
         local annot = ab[BLOCK_INDEXES.ARGUMENT.ANNOTATION]
         if not annot then
            table.insert(errs, { filename = filename, y = ab.y, x = ab.x, msg = "macro '" .. name .. "' argument missing type; expected 'Statement' or 'Expression'" })
         else
            if annot.kind == "nominal_type" and annot[BLOCK_INDEXES.NOMINAL_TYPE.NAME] and annot[BLOCK_INDEXES.NOMINAL_TYPE.NAME].kind == "identifier" then
               local tname = annot[BLOCK_INDEXES.NOMINAL_TYPE.NAME].tk
               if tname == "Statement" then
                  expected = "stmt"
               elseif tname == "Expression" then
                  expected = "expr"
               else
                  table.insert(errs, { filename = filename, y = annot.y, x = annot.x, msg = "macro '" .. name .. "' argument type must be 'Statement' or 'Expression'" })
               end
            else
               table.insert(errs, { filename = filename, y = annot.y, x = annot.x, msg = "macro '" .. name .. "' argument type must be 'Statement' or 'Expression'" })
            end
         end
         if ab.tk == "..." then
            sig.vararg = expected or "expr"
         else
            sig.kinds[idx] = expected or "expr"
            idx = idx + 1
         end
      end
   end

   local lua_generator = require("teal.gen.lua_generator")
   local single: Block = { kind = "statements", y = mb.y, x = mb.x, tk = mb.tk, yend = mb.yend, xend = mb.xend }
   single[1] = mb
   local mast, perrs = parser.parse(single, filename, read_lang)
   if #perrs > 0 then
      for _, e in ipairs(perrs) do table.insert(errs, e) end
      return
   end
   
   local code = lua_generator.generate(mast as ParserNode, "5.4", lua_generator.fast_opts)
   local chunk, load_err = load(code .. "\nreturn " .. name, name, "t", env as table)
   if not chunk then
      table.insert(errs, { filename = filename, y = mb.y, x = mb.x, msg = load_err })
      return
   end
   local ok, fn_raw = pcall(chunk)
   if not ok then
      table.insert(errs, { filename = filename, y = mb.y, x = mb.x, msg = tostring(fn_raw) })
      return
   end
   if fn_raw is MacroFunction then
      env.macros[name] = fn_raw
   else
      table.insert(errs, { filename = filename, y = mb.y, x = mb.x, msg = "macro '" .. name .. "' did not compile to a function" })
      return
   end
   env.signatures[name] = sig
end

local seen: {Block:boolean}

local function expand_in_node(b: Block, filename: string, env: MacroEnv, errs: {Error}, context: string): Block
   if not b then return b end
   if seen and seen[b] then return b end
   if seen then seen[b] = true end
   if b.kind == "macro_invocation" then
      local mexp = b
      local mname_block = mexp[BLOCK_INDEXES.MACRO_INVOCATION.MACRO]
      if not mname_block or (mname_block.kind ~= "variable" and mname_block.kind ~= "identifier") then
         table.insert(errs, { filename = filename, y = b.y, x = b.x, msg = "invalid macro invocation target" })
         return b
      end
      local mname = mname_block.tk
      local fn = env.macros[mname]
      if not fn then
         table.insert(errs, { filename = filename, y = b.y, x = b.x, msg = "unknown macro '" .. mname .. "'" })
         return b
      end
      local argv: {Block} = {}
      local sig = env.signatures[mname]
      local args = mexp[BLOCK_INDEXES.MACRO_INVOCATION.ARGS]

      if sig then
         local provided = args and #args or 0
         local required = #sig.kinds
         local has_vararg = sig.vararg ~= ""
         if provided < required or ((not has_vararg) and provided > required) then
            table.insert(errs, {
               filename = filename,
               y = mname_block.y,
               x = mname_block.x,
               msg = "macro '" .. mname .. "' expects " .. tostring(required) .. (required == 1 and " argument" or " arguments") .. ", got " .. tostring(provided),
            })
            return b
         end
      end
      if args then
         for i, ab in ipairs(args) do
            if ab.kind == "macro_quote" and ab[BLOCK_INDEXES.MACRO_QUOTE.BLOCK] then
               ab = ab[BLOCK_INDEXES.MACRO_QUOTE.BLOCK]
            end
            local expected: string
            if sig then
               expected = sig.kinds and sig.kinds[i] or (sig.vararg ~= "" and sig.vararg or nil)
            end
            if expected == "stmt" then
               if not ab or ab.kind ~= "statements" then
                  table.insert(errs, { filename = filename, y = ab and ab.y or b.y, x = ab and ab.x or b.x, msg = "macro '" .. mname .. "' argument " .. tostring(i) .. " must be a Statement" })
               end
            elseif expected == "expr" then
               if ab and ab.kind == "statements" then
                  if #ab == 1 and not is_statement_kind(ab[1].kind) then
                     ab = ab[1]
                  else
                     table.insert(errs, { filename = filename, y = ab.y, x = ab.x, msg = "macro '" .. mname .. "' argument " .. tostring(i) .. " must be an Expression" })
                  end
               end
            end
            if ab then
               table.insert(argv, ab)
            end
         end
      end
      local prev_where = env.where
      local current_where = { f = filename, y = mname_block.y, x = mname_block.x }
      env.where = current_where
      local function invoke_macro(): Block
         return fn(table.unpack(argv, 1, #argv))
      end
      local ok, res = pcall(invoke_macro)
      env.where = prev_where
      if not ok then
         table.insert(errs, { filename = filename, y = b.y, x = b.x, msg = tostring(res) })
         return b
      end
      if not (res and res.kind) then
         table.insert(errs, { filename = filename, y = b.y, x = b.x, msg = "macro '" .. mname .. "' did not return a Block" })
         return b
      end
      local wy = current_where.y
      local wx = current_where.x
      reanchor_block_positions(res, wy, wx, setmetatable({}, { __mode = "k" }))
      if context == "expr" and res.kind == "statements" then
         if #res == 1 and not is_statement_kind(res[1].kind) then
            return expand_in_node(res[1], filename, env, errs, "expr")
         end
         table.insert(errs, { filename = filename, y = b.y, x = b.x, msg = "macro '" .. mname .. "' returned statements in an expression context" })
         return b
      end
      
      return expand_in_node(res, filename, env, errs, context)
   end

   for i = 1, #b do
      local child = b[i]
      if child and child.kind == "statements" then
         local expanded = child
         local j = 1
         while j <= #expanded do
            local s = expanded[j]
            if s then
               if s.kind == "macro_invocation" then
                  local repl = expand_in_node(s, filename, env, errs, "stmt")
                  if repl and repl.kind == "statements" then
                     table.remove(expanded, j)
                     local rr = expand_in_node(repl, filename, env, errs, "stmt")
                     for k = 1, #rr do
                        table.insert(expanded, j + k - 1, rr[k])
                     end
                     j = j + #repl
                  else
                     expanded[j] = expand_in_node(repl or s, filename, env, errs, "stmt")
                     j = j + 1
                  end
               else
                  expanded[j] = expand_in_node(s, filename, env, errs, is_statement_kind(s.kind) and "stmt" or "expr")
                  j = j + 1
               end
            else
               j = j + 1
            end
         end
      else
         b[i] = expand_in_node(child, filename, env, errs, "expr")
      end
   end
   return b
end

function macro_eval.compile_all_and_expand(node: Block, filename: string, read_lang: BlockLang, errs: {Error}): Block
   seen = setmetatable({}, { __mode = "k" })
   local env = macro_eval.new_env()

   local i = 1
   while i <= #node do
      local it = node[i]
      if it and it.kind == "local_macro" then
         compile_local_macro(it, filename, read_lang, env, errs)
         table.remove(node, i)
      else
         i = i + 1
      end
   end

   local j = 1
   while j <= #node do
      local s = node[j]
      if s.kind == "macro_invocation" then
         local repl = expand_in_node(s, filename, env, errs, "stmt")
         if repl and repl.kind == "statements" then
            table.remove(node, j)
            local rr = expand_in_node(repl, filename, env, errs, "stmt")
            for k = 1, #rr do
               table.insert(node, j + k - 1, rr[k])
            end
            j = j + #repl
         else
            node[j] = expand_in_node(repl or s, filename, env, errs, "stmt")
            j = j + 1
         end
      else
         node[j] = expand_in_node(s, filename, env, errs, is_statement_kind(s.kind) and "stmt" or "expr")
         j = j + 1
      end
   end

   return node
end

return macro_eval
