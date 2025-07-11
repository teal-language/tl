local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local load = _tl_compat and _tl_compat.load or load; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type
local VERSION = "0.24.6+dev"

local errors = require("teal.errors")

local file_checker = require("teal.check.block_file_checker")

local lexer = require("teal.lexer")



local package_loader = require("teal.package_loader")

local parser = require("teal.parser")



local lua_generator = require("teal.gen.lua_generator")

local lua_compat = require("teal.gen.lua_compat")

local require_file = require("teal.check.require_file")

local string_checker = require("teal.check.block_string_checker")

local check = require("teal.check.check")

local type_reporter = require("teal.type_reporter")



local environment = require("teal.environment")






local tl = { EnvOptions = {}, TypeCheckOptions = {} }




























































































tl.check = check.check
tl.search_module = require_file.search_module
tl.warning_kinds = errors.warning_kinds
tl.lex = lexer.lex
tl.loader = package_loader.install_loader
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

tl.apply_compat = function(result)
   if result.compat_applied then
      return
   end
   result.compat_applied = true

   local gen_compat = result.env.defaults.gen_compat or environment.DEFAULT_GEN_COMPAT
   local gen_target = result.env.defaults.gen_target or environment.DEFAULT_GEN_TARGET

   local ok, errs = lua_compat.adjust_code(result.filename, result.ast, result.needs_compat, gen_compat, gen_target)
   if not ok then
      if not result.type_errors then
         result.type_errors = {}
      end
      for _, err in ipairs(errs.errors) do
         table.insert(result.type_errors, err)
      end
      errors.clear_redundant_errors(result.type_errors)
   end
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

local function env_for(parse_lang, env_tbl)
   if not env_tbl then
      return assert(package_loader.env)
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

   if not package_loader.env then
      package_loader.env = environment.for_runtime(parse_lang)
   end
   local defaults = package_loader.env.defaults

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
