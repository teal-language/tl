local block = require("teal.block")
local type Block = block.Block
local type BlockLang = block.BlockLang
local BLOCK_INDEXES = block.BLOCK_INDEXES

local errors = require("teal.errors")
local type Error = errors.Error
local type Where = errors.Where
local ast = require("teal.ast")
local type ParserNode = ast.Node

local record macro_eval
   new_env: function(errs: {Error}): MacroEnv
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

   sandbox: {string:any}
end

local macroexp HIGHEST_PREDEFINED_INDEX(): integer
   return 5
end

local function children_iter(b: Block, at: integer): integer, Block
   while true do
      at = at + 1
      local val = b[at]
      if val then
         return at, val
      elseif at > HIGHEST_PREDEFINED_INDEX() then
         return
      end
   end
end

local function children(b: Block): function(Block, integer): (integer, Block), Block, integer
   return children_iter, b, 0
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
      is_longstring = v.is_longstring,
   }
   for idx, child in children(v) do
      out[idx] = clone_value(child)
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

   for idx, child in children(b) do
      reanchor_block_positions(child, where_y, where_x, seen_blocks)
   end
end

function macro_eval.new_env(errs: {Error}): MacroEnv
   local env: MacroEnv = {
      macros = {},
      signatures = {},
      where = { f = "@macro", y = 1, x = 1 },
      sandbox = {
         block = function(_: block.BlockKind): Block
            return { kind = "statements", f = "@macro", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
         end,
         expect = function(_: MacroValue, _: string): Block
            error("macro env not initialized")
            return nil
         end,
         clone = clone_value,

         BLOCK_INDEXES = BLOCK_INDEXES,

         math = math,
         string = string,
         table = table,
         pairs = pairs,
         ipairs = ipairs,
         tostring = tostring,
         tonumber = tonumber,
         type = type,
         error = error,
         pcall = pcall,
         unpack = (_G as {string:any}).unpack,
         select = select,
         coroutine = coroutine,
         assert = assert,

         next = next,
         xpcall = xpcall,
         print = print,
         _VERSION = _VERSION,

         getmetatable = getmetatable,
         setmetatable = setmetatable,

         rawget = rawget,
         rawset = rawset,
         rawequal = rawequal,
         rawlen = rawlen,

         utf8 = utf8,
         bit = (_G as {string:any}).bit,

         os = {
            clock = os.clock,
            date = os.date,
            difftime = os.difftime,
            time = os.time,
         }
         -- FORBIDDEN --
         -- os = nil,
         -- io = nil,
         -- debug = nil,
         -- package = nil,
         -- loadfile = nil,
         -- dofile = nil,
         -- require = nil,
         -- load = nil,
      }
   }
   env.sandbox.block = function(kind: block.BlockKind): Block
      local w = env.where
      if not block.BLOCK_KINDS[kind] then
         table.insert(errs, { filename = w.f, y = w.y, x = w.x, msg = "unknown block kind: " .. tostring(kind) })
      end
      return { kind = kind, f = w.f, y = w.y, x = w.x, tk = "", yend = w.y, xend = w.x }
   end
   env.sandbox.expect = function(b: Block, k: block.BlockKind): Block
      if b and b.kind == k then
         return b
      end
      table.insert(errs, { filename = env.where.f, y = env.where.y, x = env.where.x, msg = "expected " .. k .. ", got " .. (b and b.kind or "nil") })
      return nil
   end

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
   local mast, perrs = ast.parse_blocks(single, filename, read_lang)
   if #perrs > 0 then
      for _, e in ipairs(perrs) do table.insert(errs, e) end
      return
   end

   local code = lua_generator.generate(mast as ParserNode, "5.1", lua_generator.fast_opts)
   local chunk, load_err = load(code .. "\nreturn " .. name, name, "t", env.sandbox)
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

local traverse_invoking_macros: function(b: Block, filename: string, env: MacroEnv, errs: {Error}, context: string): Block
local eval_macro_invocation: function(b: Block, filename: string, env: MacroEnv, errs: {Error}, context: string): Block

eval_macro_invocation = function(b: Block, filename: string, env: MacroEnv, errs: {Error}, context: string): Block
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
         return traverse_invoking_macros(res[1], filename, env, errs, "expr")
      end
      table.insert(errs, { filename = filename, y = b.y, x = b.x, msg = "macro '" .. mname .. "' returned statements in an expression context" })
      return b
   end

   return traverse_invoking_macros(res, filename, env, errs, context)
end

traverse_invoking_macros = function(b: Block, filename: string, env: MacroEnv, errs: {Error}, context: string): Block
   -- FIXME Why do we need this? Blocks must form a tree, not a DAG, much less a cyclic graph.
   if seen and seen[b] then return b end
   if seen then seen[b] = true end

   local patches: {integer:Block}
   for i, child in children(b) do
      local ret: Block
      if child.kind == "macro_invocation" then
         ret = eval_macro_invocation(child, filename, env, errs, b.kind == "statements" and "stmt" or "expr")
         if ret.kind == "statements" then
            patches = patches or {}
            patches[i] = ret
         else
            b[i] = ret
         end
      else
         traverse_invoking_macros(child, filename, env, errs, context)
      end
   end

   if patches then
      for i = #b, 1, -1 do
         local patch = patches[i]
         if patch then
            table.remove(b, i)
            for j = 1, #patch do
               table.insert(b, i+j-1, patch[j])
            end
         end
      end
   end

   return b
end

function macro_eval.compile_all_and_expand(node: Block, filename: string, read_lang: BlockLang, errs: {Error}): Block
   seen = setmetatable({}, { __mode = "k" })
   local env = macro_eval.new_env(errs)

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

   return traverse_invoking_macros(node, filename, env, errs, "stmt")
end

return macro_eval
