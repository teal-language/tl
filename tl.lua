local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local load = _tl_compat and _tl_compat.load or load; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type
local VERSION = "0.24.7+dev"

local errors = require("teal.errors")

local file_checker = require("teal.checker.file_checker")

local lexer = require("teal.lexer")

local types = require("teal.types")

local a_type = types.a_type

local parser = require("teal.parser")



local lua_generator = require("teal.gen.lua_generator")

local require_file = require("teal.checker.require_file")

local string_checker = require("teal.checker.string_checker")

local type_checker = require("teal.checker.type_checker")

local type_reporter = require("teal.type_reporter")



local util = require("teal.util")
local read_file_skipping_bom = util.read_file_skipping_bom

local environment = require("teal.environment")






local tl = { EnvOptions = {}, TypeCheckOptions = {} }




























































































tl.check = type_checker.check
tl.search_module = require_file.search_module
tl.warning_kinds = errors.warning_kinds
tl.lex = lexer.lex
tl.generate = lua_generator.generate
tl.get_token_at = lexer.get_token_at
tl.parse = parser.parse
tl.parse_program = parser.parse_program
tl.symbols_in_scope = type_reporter.symbols_in_scope
tl.target_from_lua_version = lua_generator.target_from_lua_version

environment.set_require_module_fn(require_file.require_module)












tl.check_file = function(filename, env, fd)
   env = env or environment.new()
   return file_checker.check(env, filename, fd)
end

tl.check_string = function(input, env, filename, parse_lang)
   env = env or environment.new()
   env.defaults.feat_lax = parse_lang == "lua" and "on" or "off"
   return string_checker.check(env, input, filename)
end

tl.new_env = function(opts)
   local env, err = environment.new(opts and opts.defaults)
   if not env then
      return nil, err
   end

   if opts.predefined_modules then
      local ok
      ok, err = environment.predefine(env, opts.predefined_modules)
      if not ok then
         return nil, err
      end
   end

   return env
end

tl.gen = function(input, env, opts, parse_lang)
   env = env or environment.new()
   env.defaults.feat_lax = parse_lang == "lua" and "on" or "off"
   local result = string_checker.check(env, input)

   if (not result.ast) or #result.syntax_errors > 0 then
      return nil, result
   end

   local code
   code, result.gen_error = lua_generator.generate(result.ast, env.defaults.gen_target, opts)
   return code, result
end

local function tl_package_loader(module_name)
   local found_filename, fd, tried = tl.search_module(module_name, false)
   if found_filename then
      local parse_lang = parser.lang_heuristic(found_filename)
      local input = read_file_skipping_bom(fd)
      if not input then
         return table.concat(tried, "\n\t")
      end
      fd:close()
      local program, errs = tl.parse(input, found_filename, parse_lang)
      if #errs > 0 then
         error(found_filename .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg)
      end

      local env = tl.package_loader_env
      if not env then
         tl.package_loader_env = assert(environment.for_runtime(parse_lang), "Default environment initialization failed")
         env = tl.package_loader_env
      end
      local defaults = env.defaults

      local w = { f = found_filename, x = 1, y = 1 }
      env.modules[module_name] = a_type(w, "typedecl", { def = a_type(w, "circular_require", {}) })

      local result = tl.check(program, found_filename, defaults, env)

      env.modules[module_name] = result.type



      local code = assert(tl.generate(program, defaults.gen_target, lua_generator.fast_opts))
      local chunk, err = load(code, "@" .. found_filename, "t")
      if chunk then
         return function(modname, loader_data)
            if loader_data == nil then
               loader_data = found_filename
            end
            local ret = chunk(modname, loader_data)
            return ret
         end, found_filename
      else
         error("Internal Compiler Error: Teal generator produced invalid Lua. Please report a bug at https://github.com/teal-language/tl\n\n" .. err)
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

local function env_for(parse_lang, env_tbl)
   if not env_tbl then
      return assert(tl.package_loader_env)
   end

   if not tl.load_envs then
      tl.load_envs = setmetatable({}, { __mode = "k" })
   end

   tl.load_envs[env_tbl] = tl.load_envs[env_tbl] or environment.for_runtime(parse_lang)
   return tl.load_envs[env_tbl]
end

tl.load = function(input, chunkname, mode, ...)
   local parse_lang = parser.lang_heuristic(chunkname)
   local program, errs = tl.parse(input, chunkname, parse_lang)
   if #errs > 0 then
      return nil, (chunkname or "") .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg
   end

   if not tl.package_loader_env then
      tl.package_loader_env = environment.for_runtime(parse_lang)
   end
   local defaults = tl.package_loader_env.defaults

   local filename = chunkname or ("string \"" .. input:sub(45) .. (#input > 45 and "..." or "") .. "\"")
   local result = tl.check(program, filename, defaults, env_for(parse_lang, ...))

   if mode and mode:match("c") then
      if #result.type_errors > 0 then
         local errout = {}
         for _, err in ipairs(result.type_errors) do
            table.insert(errout, err.filename .. ":" .. err.y .. ":" .. err.x .. ": " .. (err.msg or ""))
         end
         return nil, table.concat(errout, "\n")
      end

      mode = mode:gsub("c", "")
   end

   local code, err = lua_generator.generate(program, defaults.gen_target, lua_generator.fast_opts)
   if not code then
      return nil, err
   end

   return load(code, chunkname, mode, ...)
end

tl.version = function()
   return VERSION
end





function tl.get_types(result)
   return result.env.reporter:get_report(), result.env.reporter
end

tl.init_env = function(lax, gen_compat, gen_target, predefined)
   local opts = {
      defaults = {
         feat_lax = (lax and "on" or "off"),
         gen_compat = ((type(gen_compat) == "string") and gen_compat) or
         (gen_compat == false and "off") or
         (gen_compat == true or gen_compat == nil) and "optional",
         gen_target = gen_target or
         ((_VERSION == "Lua 5.1" or _VERSION == "Lua 5.2") and "5.1") or
         "5.3",
      },
      predefined_modules = predefined,
   }

   return tl.new_env(opts)
end

tl.type_check = function(ast, tc_opts)
   local opts = {
      feat_lax = tc_opts.lax and "on" or "off",
      feat_arity = tc_opts.env and tc_opts.env.defaults.feat_arity or "on",
      gen_compat = tc_opts.gen_compat,
      gen_target = tc_opts.gen_target,
      run_internal_compiler_checks = tc_opts.run_internal_compiler_checks,
   }
   return tl.check(ast, tc_opts.filename, opts, tc_opts.env)
end

tl.pretty_print_ast = function(ast, gen_target, mode)
   local opts
   if type(mode) == "table" then
      opts = mode
   elseif mode == true then
      opts = lua_generator.fast_opts
   else
      opts = lua_generator.default_opts
   end

   return lua_generator.generate(ast, gen_target, opts)
end

tl.process = function(filename, env, fd)
   return tl.check_file(filename, env, fd)
end

tl.process_string = function(input, is_lua, env, filename, _module_name)
   return tl.check_string(input, env or tl.init_env(is_lua), filename)
end

return tl
