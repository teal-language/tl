local block = require("teal.block")
local type Block = block.Block
local type BlockLang = block.BlockLang
local BLOCK_INDEXES = block.BLOCK_INDEXES

local errors = require("teal.errors")
local type Error = errors.Error
local type types = require("teal.types")

local record macro_eval
   new_env: function(): {string:any}
   compile_all_and_expand: function(node: Block, filename: string, read_lang: BlockLang, errs: {Error}): Block
end

local record MacroSig
   kinds: {string}
   vararg: string
end

local function clone_value(v: any): any
   if type(v) ~= "table" then
      return v
   end
   local out: {any:any} = {}
   for k, vv in pairs(v as {any:any}) do
      out[k] = clone_value(vv)
   end
   return out
end

function macro_eval.new_env(): {string:any}
   local env: {string:any} = {}
   setmetatable(env, { __index = _G })
   -- macro signatures: name -> { kinds = {"stmt"|"expr"...}, vararg?: "stmt"|"expr" }
   env.__macro_sig = {}
   env.block = function(kind: string): {string:any}
      return { kind = kind, y = 1, x = 1, tk = "", yend = 1, xend = 1 }
   end
   env.expect = function(b: any, k: string): any
      if type(b) ~= "table" or (b as {string:any}).kind ~= k then
         error("expected " .. k)
      end
      return b
   end
   env.clone = clone_value
   env.pairs = pairs
   env.ipairs = ipairs
   env.select = select
   env.tostring = tostring
   env.tonumber = tonumber
   env.type = type
   env.table = table
   env.string = string
   env.math = math
   env.require = require
   return env
end

local function is_statement_kind(k: string): boolean
   return k == "assignment" or k == "local_declaration" or k == "global_declaration" or
          k == "return" or k == "if" or k == "while" or k == "fornum" or k == "forin" or
          k == "do" or k == "repeat" or k == "local_function" or k == "global_function" or
          k == "record_function" or k == "newtype" or k == "pragma"
end

local function compile_local_macro(mb: Block, filename: string, read_lang: BlockLang, env: {string:any}, errs: {Error})
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

   --has to be any to avoid circ deps
   --TODO: must be better way to do this...
   local parser_any: any = require("teal.parser")
   local lua_generator = require("teal.gen.lua_generator")
   local single: Block = { kind = "statements", y = mb.y, x = mb.x, tk = mb.tk, yend = mb.yend, xend = mb.xend } as Block
   single[1] = mb
   local mast, perrs = parser_any.parse(single, filename, read_lang)
   if #perrs > 0 then
      for _, e in ipairs(perrs) do table.insert(errs, e) end
      return
   end
   
   local code, gerr = lua_generator.generate(mast as types.Node, "5.4", lua_generator.fast_opts, env)
   if gerr then
      table.insert(errs, { filename = filename, y = mb.y, x = mb.x, msg = gerr })
      return
   end
   local chunk, load_err = load(code .. "\nreturn " .. name, name, "t", env)
   if not chunk then
      table.insert(errs, { filename = filename, y = mb.y, x = mb.x, msg = load_err })
      return
   end
   local ok, fn = pcall(chunk)
   if not ok then
      table.insert(errs, { filename = filename, y = mb.y, x = mb.x, msg = tostring(fn) })
      return
   end
   env[name] = fn
   (env.__macro_sig as {string:MacroSig})[name] = sig
end

local function expand_in_node(b: Block, filename: string, env: {string:any}, errs: {Error}, context: string): Block
   if not b then return b end
   if b.kind == "macro_invocation" then
      local mexp = b
      local mname_block = mexp[BLOCK_INDEXES.MACRO_INVOCATION.MACRO]
      if not mname_block or (mname_block.kind ~= "variable" and mname_block.kind ~= "identifier") then
         table.insert(errs, { filename = filename, y = b.y, x = b.x, msg = "invalid macro invocation target" })
         return b
      end
      local mname = mname_block.tk
      local fn = (env as {string:any})[mname]
      if not fn then
         table.insert(errs, { filename = filename, y = b.y, x = b.x, msg = "unknown macro '" .. mname .. "'" })
         return b
      end
      local argv: {any} = {}
      local sig: MacroSig = (env.__macro_sig as {string:MacroSig})[mname]
      local args = mexp[BLOCK_INDEXES.MACRO_INVOCATION.ARGS]
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
                  if #ab == 1 and not is_statement_kind(ab[1].kind as string) then
                     ab = ab[1]
                  else
                     table.insert(errs, { filename = filename, y = ab.y, x = ab.x, msg = "macro '" .. mname .. "' argument " .. tostring(i) .. " must be an Expression" })
                  end
               end
            end
            table.insert(argv, ab)
         end
      end
      local ok, res = (pcall as function(any, ...: any): (boolean, any))(fn, table.unpack(argv))
      if not ok then
         table.insert(errs, { filename = filename, y = b.y, x = b.x, msg = tostring(res) })
         return b
      end
      if type(res) ~= "table" or not (res as {string:any}).kind then
         table.insert(errs, { filename = filename, y = b.y, x = b.x, msg = "macro '" .. mname .. "' did not return a Block" })
         return b
      end
      local rb = res as Block
      if context == "expr" and rb.kind == "statements" then
         if #rb == 1 and not is_statement_kind(rb[1].kind as string) then
            return expand_in_node(rb[1], filename, env, errs, "expr")
         end
         table.insert(errs, { filename = filename, y = b.y, x = b.x, msg = "macro '" .. mname .. "' returned statements in an expression context" })
         return b
      end
      
      return expand_in_node(rb, filename, env, errs, context)
   end

   for i = 1, #b do
      local child = b[i]
      if type(child) == "table" and child.kind then
         if child.kind == "statements" then
            local expanded = child
            local j = 1
            while j <= #expanded do
               local s = expanded[j]
               if type(s) == "table" and s.kind then
                  if s.kind == "macro_invocation" then
                     local repl = expand_in_node(s, filename, env, errs, "stmt")
                     if repl and repl.kind == "statements" then
                        table.remove(expanded, j)
                        local rr = expand_in_node(repl, filename, env, errs, "stmt") as Block
                        for k = 1, #rr do
                           table.insert(expanded, j + k - 1, rr[k])
                        end
                        j = j + #repl
                     else
                        expanded[j] = expand_in_node(repl or s, filename, env, errs, "stmt")
                        j = j + 1
                     end
                  else
                     expanded[j] = expand_in_node(s, filename, env, errs, is_statement_kind(s.kind as string) and "stmt" or "expr")
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
   end
   return b
end

function macro_eval.compile_all_and_expand(node: Block, filename: string, read_lang: BlockLang, errs: {Error}): Block
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
            local rr = expand_in_node(repl, filename, env, errs, "stmt") as Block
            for k = 1, #rr do
               table.insert(node, j + k - 1, rr[k])
            end
            j = j + #repl
         else
            node[j] = expand_in_node(repl or s, filename, env, errs, "stmt")
            j = j + 1
         end
      else
         node[j] = expand_in_node(s, filename, env, errs, is_statement_kind(s.kind as string) and "stmt" or "expr")
         j = j + 1
      end
   end

   return node
end

return macro_eval
