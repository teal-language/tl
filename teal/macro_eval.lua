local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local coroutine = _tl_compat and _tl_compat.coroutine or coroutine; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local load = _tl_compat and _tl_compat.load or load; local math = _tl_compat and _tl_compat.math or math; local os = _tl_compat and _tl_compat.os or os; local pairs = _tl_compat and _tl_compat.pairs or pairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local rawlen = _tl_compat and _tl_compat.rawlen or rawlen; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack; local type = type; local utf8 = _tl_compat and _tl_compat.utf8 or utf8; local xpcall = _tl_compat and _tl_compat.xpcall or xpcall; local block = require("teal.block")


local BLOCK_INDEXES = block.BLOCK_INDEXES

local errors = require("teal.errors")


local ast = require("teal.ast")







local macro_eval = {}

























local module_cache = {}
local module_failed = {}
local module_loading = {}










local dynamic_require = (_G).require

function macro_eval.reset_module_cache()
   module_cache = {}
   module_failed = {}
   module_loading = {}
end

local function numeric_child_keys(b)
   local keys = {}
   for k, child in pairs(b) do
      if math.type(k) == "integer" and child then
         table.insert(keys, k)
      end
   end
   table.sort(keys)
   return keys
end

local function clone_value(v)
   local out = {
      kind = v.kind,
      f = v.f,
      y = v.y,
      x = v.x,
      tk = v.tk,
      yend = v.yend,
      xend = v.xend,
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

local function reanchor_block_positions(b, where_y, where_x, seen_blocks)
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

local function append_errors(dst, src)
   for _, e in ipairs(src) do
      table.insert(dst, e)
   end
end

local function add_error_at(errs, where, msg)
   table.insert(errs, {
      filename = where.f,
      y = where.y,
      x = where.x,
      msg = msg,
   })
end

local function macro_target_name(node)
   if not node then
      return nil
   end
   if node.kind == "variable" or node.kind == "identifier" then
      return node.tk
   end
   if node.kind == "op_dot" then
      local lhs = macro_target_name(node[BLOCK_INDEXES.OP.E1])
      local rhs = macro_target_name(node[BLOCK_INDEXES.OP.E2])
      if lhs and rhs then
         return lhs .. "." .. rhs
      end
   end
   return nil
end

local function unquote_string(str)
   local first = str:sub(1, 1)
   if first == '"' or first == "'" then
      return str:sub(2, -2)
   end
   local long_start = str:match("^%[=*%[")
   if not long_start then
      return str
   end
   local l = #long_start + 1
   return str:sub(l, -l)
end

local function comptime_initializer_value(item)
   return item[BLOCK_INDEXES.LITERAL_TABLE_ITEM.TYPED_VALUE] or item[BLOCK_INDEXES.LITERAL_TABLE_ITEM.VALUE]
end

local function is_primitive_literal(exp)
   return exp.kind == "nil" or
   exp.kind == "boolean" or
   exp.kind == "number" or
   exp.kind == "integer" or
   exp.kind == "string"
end

local function is_literal_table(exp)
   return exp and exp.kind == "literal_table"
end

local function validate_comptime_literal(exp, errs, where)
   if is_primitive_literal(exp) then
      return true
   end

   if not is_literal_table(exp) then
      add_error_at(errs, where, "attribute <comptime> only supports primitive literals, literal tables, or require(\"module\")")
      return false
   end

   local ok = true
   for _, item in ipairs(exp) do
      if not (item and item.kind == "literal_table_item") then
         add_error_at(errs, where, "attribute <comptime> only supports literal tables with literal keys and values")
         ok = false
      else
         local key = item[BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY]
         if key and not is_primitive_literal(key) then
            add_error_at(errs, key, "attribute <comptime> table keys must be literals")
            ok = false
         end

         local value = comptime_initializer_value(item)
         if value and value.kind == "literal_table" then
            if not validate_comptime_literal(value, errs, value) then
               ok = false
            end
         elseif not value or not is_primitive_literal(value) then
            add_error_at(errs, item, "attribute <comptime> table values must be literals")
            ok = false
         end
      end
   end

   return ok
end

local function child_replacement_allowed(parent, idx, allowed)
   if not allowed then
      return false
   end

   if parent.kind == "local_declaration" then
      return idx == BLOCK_INDEXES.LOCAL_DECLARATION.EXPS
   elseif parent.kind == "global_declaration" then
      return idx == BLOCK_INDEXES.GLOBAL_DECLARATION.EXPS
   elseif parent.kind == "assignment" then
      return idx == BLOCK_INDEXES.ASSIGNMENT.EXPS
   elseif parent.kind == "local_function" then
      return idx == BLOCK_INDEXES.LOCAL_FUNCTION.BODY
   elseif parent.kind == "global_function" then
      return idx == BLOCK_INDEXES.GLOBAL_FUNCTION.BODY
   elseif parent.kind == "record_function" then
      return idx == BLOCK_INDEXES.RECORD_FUNCTION.BODY
   elseif parent.kind == "function" then
      return idx == BLOCK_INDEXES.FUNCTION.BODY
   elseif parent.kind == "local_macro" then
      return idx == BLOCK_INDEXES.LOCAL_MACRO.BODY
   elseif parent.kind == "variable_list" or parent.kind == "argument_list" then
      return false
   elseif parent.kind == "argument" then
      return false
   elseif parent.kind == "local_type" or
      parent.kind == "global_type" or
      parent.kind == "newtype" or
      parent.kind == "typedecl" or
      parent.kind == "typeargs" or
      parent.kind == "typelist" or
      parent.kind == "generic_type" or
      parent.kind == "tuple_type" or
      parent.kind == "nominal_type" or
      parent.kind == "map_type" or
      parent.kind == "array_type" or
      parent.kind == "union_type" or
      parent.kind == "argument_type" or
      parent.kind == "interface_list" or
      parent.kind == "record_body" or
      parent.kind == "record_field" or
      parent.kind == "question" then

      return false
   end

   return true
end

local function inline_comptime_literals(root, literals)
   if not next(literals) then
      return
   end

   local seen_rewrite = setmetatable({}, { __mode = "k" })

   local function rewrite(node, allowed)
      if not node then
         return node
      end
      if seen_rewrite[node] then
         return node
      end
      seen_rewrite[node] = true

      if allowed and node.kind == "variable" and literals[node.tk] then
         local repl = clone_value(literals[node.tk])
         reanchor_block_positions(repl, node.y, node.x, setmetatable({}, { __mode = "k" }))
         return repl
      end
      if allowed and node.kind == "macro_var" then
         local ident = node[BLOCK_INDEXES.MACRO_VAR.NAME]
         local name = ident and ident.tk
         if name and literals[name] then
            local repl = clone_value(literals[name])
            reanchor_block_positions(repl, node.y, node.x, setmetatable({}, { __mode = "k" }))
            return repl
         end
      end

      for _, idx in ipairs(numeric_child_keys(node)) do
         local child = node[idx]
         if child then
            local child_allowed = child_replacement_allowed(node, idx, allowed)
            local rewritten = rewrite(child, child_allowed)
            if rewritten ~= child then
               node[idx] = rewritten
            end
         end
      end

      return node
   end

   rewrite(root, true)
end

function macro_eval.new_env(errs)
   local env = {
      macros = {},
      signatures = {},
      where = { f = "@macro", y = 1, x = 1 },
      sandbox = {
         block = function(_)
            return { kind = "statements", f = "@macro", y = 1, x = 1, tk = "", yend = 1, xend = 1 }
         end,
         expect = function(_, _)
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
         unpack = (_G).unpack,
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
         bit = (_G).bit,

         os = {
            clock = os.clock,
            date = os.date,
            difftime = os.difftime,
            time = os.time,
         },









      },
   }
   env.sandbox.block = function(kind)
      local w = env.where
      if not block.BLOCK_KINDS[kind] then
         table.insert(errs, { filename = w.f, y = w.y, x = w.x, msg = "unknown block kind: " .. tostring(kind) })
      end
      return { kind = kind, f = w.f, y = w.y, x = w.x, tk = "", yend = w.y, xend = w.x }
   end
   env.sandbox.expect = function(b, k)
      if b and b.kind == k then
         return b
      end
      table.insert(errs, { filename = env.where.f, y = env.where.y, x = env.where.x, msg = "expected " .. k .. ", got " .. (b and b.kind or "nil") })
      return nil
   end

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

   local sig = { kinds = {}, vararg = "" }
   local args = mb[BLOCK_INDEXES.LOCAL_MACRO.ARGS]
   if args then
      local idx = 1
      for _, ab in ipairs(args) do
         local expected
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
   local single = { kind = "statements", y = mb.y, x = mb.x, tk = mb.tk, yend = mb.yend, xend = mb.xend }
   single[1] = mb
   local mast, perrs = ast.parse_blocks(single, filename, read_lang)
   if #perrs > 0 then
      for _, e in ipairs(perrs) do table.insert(errs, e) end
      return
   end

   local code = lua_generator.generate(mast, "5.1", lua_generator.fast_opts)
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
   if type(fn_raw) == "function" then
      env.macros[name] = fn_raw
   else
      table.insert(errs, { filename = filename, y = mb.y, x = mb.x, msg = "macro '" .. name .. "' did not compile to a function" })
      return
   end
   env.signatures[name] = sig
end

local reader_runtime
local require_file_runtime

local function get_reader_runtime()
   if not reader_runtime then
      reader_runtime = dynamic_require("teal.reader")
   end
   return reader_runtime
end

local function get_require_file_runtime()
   if not require_file_runtime then
      require_file_runtime = dynamic_require("teal.check.require_file")
   end
   return require_file_runtime
end

local function find_macro_exports_return(module_ast)
   for _, stmt in ipairs(module_ast) do
      if stmt.kind == "return" then
         local exps = stmt[BLOCK_INDEXES.RETURN.EXPS]
         if exps and #exps == 1 and exps[1] and exps[1].kind == "literal_table" then
            return exps[1], stmt
         end
         return nil, stmt
      end
   end
   return nil, nil
end

local function parse_export_name(item)
   local key = item[BLOCK_INDEXES.LITERAL_TABLE_ITEM.KEY]
   if not key then
      return nil
   end
   if key.kind == "string" then
      return unquote_string(key.tk)
   end
   if key.kind == "identifier" or key.kind == "variable" then
      return unquote_string(key.tk)
   end
   return nil
end

local function load_macro_module(module_name, where, errs)
   local cached = module_cache[module_name]
   if cached then
      return cached
   end
   if module_failed[module_name] then
      return nil
   end
   if module_loading[module_name] then
      add_error_at(errs, where, "circular macro module require: '" .. module_name .. "'")
      return nil
   end

   module_loading[module_name] = true

   local function fail()
      module_failed[module_name] = true
      module_loading[module_name] = nil
      return nil
   end

   local require_file = get_require_file_runtime()
   local found_filename, code, tried = require_file.search_module(module_name, { [".m.tl"] = true })
   if not found_filename or not code then
      local msg = "macro module not found: '" .. module_name .. "'"
      if tried and #tried > 0 then
         msg = msg .. "\n\t" .. table.concat(tried, "\n\t")
      end
      add_error_at(errs, where, msg)
      return fail()
   end

   local reader = get_reader_runtime()
   local module_ast, read_errs = reader.read(code, found_filename, "tl", true, true)
   if #read_errs > 0 then
      append_errors(errs, read_errs)
      return fail()
   end

   local env = macro_eval.new_env(errs)

   local function process_comptime_declarations(node)
      local literals = {}
      local i = 1
      while i <= #node do
         local stmt = node[i]
         if stmt and stmt.kind == "local_declaration" then
            local vars = stmt[BLOCK_INDEXES.LOCAL_DECLARATION.VARS]
            local exps = stmt[BLOCK_INDEXES.LOCAL_DECLARATION.EXPS]
            local has_comptime = false
            local var = vars and vars[1]
            local annot = var and var[BLOCK_INDEXES.VARIABLE.ANNOTATION]
            if annot and annot.kind == "identifier" and annot.tk == "comptime" then
               has_comptime = true
            end

            if has_comptime then
               if not (vars and #vars == 1 and exps and #exps == 1) then
                  add_error_at(errs, stmt, "attribute <comptime> requires exactly one declared variable with one initializer")
               else
                  local init = exps[1]
                  local modname
                  if init.kind == "op_funcall" then
                     modname = reader.node_is_require_call(init)
                  end
                  if modname then
                     local loaded = load_macro_module(modname, var, errs)
                     if loaded then
                        local loaded_module = loaded
                        for export_name, fn in pairs(loaded_module.macros) do
                           local fullname = var.tk .. "." .. export_name
                           env.macros[fullname] = fn
                           local sig = loaded_module.signatures[export_name]
                           if sig then
                              env.signatures[fullname] = sig
                           end
                        end
                     end
                  else
                     if validate_comptime_literal(init, errs, init) then
                        literals[var.tk] = clone_value(init)
                     end
                  end
               end
               table.remove(node, i)
            else
               i = i + 1
            end
         else
            i = i + 1
         end
      end

      inline_comptime_literals(node, literals)
   end

   process_comptime_declarations(module_ast)

   for _, stmt in ipairs(module_ast) do
      if stmt and stmt.kind == "local_macro" then
         compile_local_macro(stmt, found_filename, "tl", env, errs)
      end
   end

   local exports_table, return_stmt = find_macro_exports_return(module_ast)
   if not exports_table then
      local at = return_stmt or where
      add_error_at(errs, at, "macro module '" .. module_name .. "' must return a literal table of exported macros")
      return fail()
   end

   local exports = exports_table
   local macros = {}
   local signatures = {}
   for _, item in ipairs(exports) do
      local export_name = parse_export_name(item)
      if not export_name then
         add_error_at(errs, item, "invalid macro export key; expected a string or identifier")
      else
         local value = item[BLOCK_INDEXES.LITERAL_TABLE_ITEM.VALUE]
         if not value or (value.kind ~= "variable" and value.kind ~= "identifier") then
            add_error_at(errs, item, "macro export '" .. export_name .. "' must reference a local macro identifier")
         else
            local local_name = value.tk
            if not env.macros[local_name] then
               add_error_at(errs, value, "exported macro '" .. export_name .. "' refers to unknown local macro '" .. local_name .. "'")
            else
               local macro_fn = env.macros[local_name]
               local sig = env.signatures[local_name]
               if macro_fn and sig then
                  macros[export_name] = macro_fn
                  signatures[export_name] = sig
               else
                  add_error_at(errs, value, "exported macro '" .. export_name .. "' refers to unknown local macro '" .. local_name .. "'")
               end
            end
         end
      end
   end

   local loaded = {
      found_filename = found_filename,
      macros = macros,
      signatures = signatures,
   }

   module_cache[module_name] = loaded
   module_failed[module_name] = nil
   module_loading[module_name] = nil
   return loaded
end

function macro_eval.load_module_signatures(module_name, where, errs)
   local loaded = load_macro_module(module_name, where, errs)
   if not loaded then
      return {}
   end
   local loaded_module = loaded
   return loaded_module.signatures
end

local function load_comptime_declarations(node, env, errs)
   local reader = get_reader_runtime()
   local literals = {}

   local i = 1
   while i <= #node do
      local stmt = node[i]
      if stmt and stmt.kind == "local_declaration" then
         local vars = stmt[BLOCK_INDEXES.LOCAL_DECLARATION.VARS]
         local exps = stmt[BLOCK_INDEXES.LOCAL_DECLARATION.EXPS]
         local var = vars and vars[1]
         local annot = var and var[BLOCK_INDEXES.VARIABLE.ANNOTATION]
         local is_comptime = annot and annot.kind == "identifier" and annot.tk == "comptime"

         if is_comptime then
            if not (vars and #vars == 1 and exps and #exps == 1) then
               add_error_at(errs, stmt, "attribute <comptime> requires exactly one declared variable with one initializer")
            else
               local init = exps[1]
               local module_name
               if init.kind == "op_funcall" then
                  module_name = reader.node_is_require_call(init)
               end
               if module_name then
                  local loaded = load_macro_module(module_name, var, errs)
                  if loaded then
                     local loaded_module = loaded
                     for export_name, fn in pairs(loaded_module.macros) do
                        local fullname = var.tk .. "." .. export_name
                        env.macros[fullname] = fn
                        local sig = loaded_module.signatures[export_name]
                        if sig then
                           env.signatures[fullname] = sig
                        end
                     end
                  end
               else
                  if validate_comptime_literal(init, errs, init) then
                     literals[var.tk] = clone_value(init)
                  end
               end
            end

            table.remove(node, i)
         else
            i = i + 1
         end
      else
         i = i + 1
      end
   end

   inline_comptime_literals(node, literals)
end

local seen

local function expand_in_node(b, filename, env, errs, context)
   if not b then return b end
   if seen and seen[b] then return b end
   if seen then seen[b] = true end
   if b.kind == "macro_invocation" then
      local mexp = b
      local mname_block = mexp[BLOCK_INDEXES.MACRO_INVOCATION.MACRO]
      local mname = macro_target_name(mname_block)
      if not mname then
         table.insert(errs, { filename = filename, y = b.y, x = b.x, msg = "invalid macro invocation target" })
         return b
      end
      local fn = env.macros[mname]
      if not fn then
         table.insert(errs, { filename = filename, y = b.y, x = b.x, msg = "unknown macro '" .. mname .. "'" })
         return b
      end
      local argv = {}
      local sig = env.signatures[mname]
      local args = mexp[BLOCK_INDEXES.MACRO_INVOCATION.ARGS]

      if sig then
         local provided = args and #args or 0
         local required = #sig.kinds
         local has_vararg = sig.vararg ~= ""
         if provided < required or ((not has_vararg) and provided > required) then
            table.insert(errs, {
               filename = filename,
               y = mname_block and mname_block.y or b.y,
               x = mname_block and mname_block.x or b.x,
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
            local expected
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
      local current_where = { f = filename, y = mname_block and mname_block.y or b.y, x = mname_block and mname_block.x or b.x }
      env.where = current_where
      local function invoke_macro()
         return fn(_tl_table_unpack(argv, 1, #argv))
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

   for _, i in ipairs(numeric_child_keys(b)) do
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

function macro_eval.compile_all_and_expand(node, filename, read_lang, errs)
   seen = setmetatable({}, { __mode = "k" })
   local env = macro_eval.new_env(errs)

   load_comptime_declarations(node, env, errs)

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
