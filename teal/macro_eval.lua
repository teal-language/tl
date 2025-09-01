local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local load = _tl_compat and _tl_compat.load or load; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack; local block = require("teal.block")


local BLOCK_INDEXES = block.BLOCK_INDEXES

local errors = require("teal.errors")



local macro_eval = {}




local function clone_value(v)
   if type(v) ~= "table" then
      return v
   end
   local out = {}
   for k, vv in pairs(v) do
      out[k] = clone_value(vv)
   end
   return out
end

function macro_eval.new_env()
   local env = {}
   setmetatable(env, { __index = _G })
   env.block = function(kind)
      return { kind = kind, y = 1, x = 1, tk = "", yend = 1, xend = 1 }
   end
   env.expect = function(b, k)
      if type(b) ~= "table" or (b).kind ~= k then
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

local function is_statement_kind(k)
   return k == "assignment" or k == "local_declaration" or k == "global_declaration" or
   k == "return" or k == "if" or k == "while" or k == "fornum" or k == "forin" or
   k == "do" or k == "repeat" or k == "local_function" or k == "global_function" or
   k == "record_function" or k == "newtype" or k == "pragma"
end

local function compile_local_macro(mb, filename, read_lang, env, errs)
   local name_block = mb[BLOCK_INDEXES.LOCAL_MACRO.NAME]
   if not name_block or name_block.kind ~= "identifier" then
      return
   end
   local name = name_block.tk


   local parser_any = require("teal.parser")
   local lua_generator = require("teal.gen.lua_generator")
   local single = { kind = "statements", y = mb.y, x = mb.x, tk = mb.tk, yend = mb.yend, xend = mb.xend }
   single[1] = mb
   local mast, perrs = parser_any.parse(single, filename, read_lang)
   if #perrs > 0 then
      for _, e in ipairs(perrs) do table.insert(errs, e) end
      return
   end

   local code, gerr = lua_generator.generate(mast, "5.4", lua_generator.fast_opts, env)
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
end

local function expand_in_node(b, filename, env, errs, context)
   if not b then return b end
   if b.kind == "macro_invocation" then
      local mexp = b
      local mname_block = mexp[BLOCK_INDEXES.MACRO_INVOCATION.MACRO]
      if not mname_block or (mname_block.kind ~= "variable" and mname_block.kind ~= "identifier") then
         table.insert(errs, { filename = filename, y = b.y, x = b.x, msg = "invalid macro invocation target" })
         return b
      end
      local mname = mname_block.tk
      local fn = (env)[mname]
      if not fn then
         table.insert(errs, { filename = filename, y = b.y, x = b.x, msg = "unknown macro '" .. mname .. "'" })
         return b
      end
      local argv = {}
      local args = mexp[BLOCK_INDEXES.MACRO_INVOCATION.ARGS]
      if args then
         for _, ab in ipairs(args) do
            table.insert(argv, ab)
         end
      end
      local ok, res = (pcall)(fn, _tl_table_unpack(argv))
      if not ok then
         table.insert(errs, { filename = filename, y = b.y, x = b.x, msg = tostring(res) })
         return b
      end
      if type(res) ~= "table" or not (res).kind then
         table.insert(errs, { filename = filename, y = b.y, x = b.x, msg = "macro '" .. mname .. "' did not return a Block" })
         return b
      end
      local rb = res
      if context == "expr" and rb.kind == "statements" then
         if #rb == 1 and not is_statement_kind(rb[1].kind) then
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
   end
   return b
end

function macro_eval.compile_all_and_expand(node, filename, read_lang, errs)
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
