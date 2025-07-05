local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local check = require("teal.check.check")
local environment = require("teal.environment")
local errors = require("teal.errors")
local file_checker = require("teal.check.file_checker")
local lexer = require("teal.lexer")
local loader = require("teal.loader")
local lua_generator = require("teal.gen.lua_generator")
local lua_compat = require("teal.gen.lua_compat")
local package_loader = require("teal.package_loader")
local parser = require("teal.parser")
local require_file = require("teal.check.require_file")
local string_checker = require("teal.check.string_checker")
local targets = require("teal.gen.targets")

local type_reporter = require("teal.type_reporter")





local v2 = { CheckOptions = {}, EnvOptions = {} }
























































environment.set_require_module_fn(require_file.require_module)

v2.warning_kinds = errors.warning_kinds
v2.typecodes = type_reporter.typecodes

















local function env_from_check_options(opts)
   return environment.new(opts and {
      feat_lax = opts.feat_lax,
      feat_arity = opts.feat_arity,
      gen_compat = opts.gen_compat,
      gen_target = opts.gen_target,
   })
end

v2.check = function(ast, filename, opts, env)
   if opts and opts.gen_target == "5.4" and opts.gen_compat ~= "off" then
      return nil, "gen-compat must be explicitly 'off' when gen-target is '5.4'"
   end

   if opts and env then








      if opts.feat_lax and env.opts.feat_lax and opts.feat_lax ~= env.opts.feat_lax then
         return nil, "opts.feat_lax does not match environment setting"
      end
      if opts.feat_arity and env.opts.feat_arity and opts.feat_arity ~= env.opts.feat_arity then
         return nil, "opts.feat_arity does not match environment setting"
      end
      if opts.gen_compat and env.opts.gen_compat and opts.gen_compat ~= env.opts.gen_compat then
         return nil, "opts.gen_compat does not match environment setting"
      end
      if opts.gen_target and env.opts.gen_target and opts.gen_target ~= env.opts.gen_target then
         return nil, "opts.gen_target does not match environment setting"
      end
   elseif opts or not env then
      env = env_from_check_options(opts)
   end

   local result = check.check(ast, env, filename or "?")
   if result and result.ast then
      lua_compat.apply(result)
   end
   return result
end

v2.check_file = function(filename, env, fd)
   env = env or environment.new()
   local result, err = file_checker.check(env, filename, fd)
   if not result then
      return nil, err
   end
   if result.ast then
      lua_compat.apply(result)
   end
   return result
end

local function run_adjusting_env(env, parse_lang, f)
   env = env or environment.new()
   env.opts = env.opts or {}
   local save_feat_lax = env.opts.feat_lax
   env.opts.feat_lax = parse_lang == "lua" and "on" or "off"
   local r, s = f(env)
   env.opts.feat_lax = save_feat_lax
   return r, s
end

v2.check_string = function(input, e, filename, parse_lang)
   return run_adjusting_env(e, parse_lang, function(env)
      local result = string_checker.check(env, input, filename)
      if result and result.ast then
         lua_compat.apply(result)
      end
      return result
   end)
end

v2.gen = function(input, e, opts, parse_lang)
   return run_adjusting_env(e, parse_lang, function(env)
      local result = string_checker.check(env, input)
      if (not result.ast) or #result.syntax_errors > 0 then
         return nil, result
      end
      lua_compat.apply(result)
      local code = lua_generator.generate(result.ast, env.opts.gen_target, opts)
      return code, result
   end)
end

v2.generate = function(ast, gen_target, opts)
   return lua_generator.generate(ast, gen_target, opts)
end

v2.get_token_at = lexer.get_token_at

v2.lex = lexer.lex

v2.load = loader.load

v2.loader = package_loader.install_loader

local function predefine_modules(env, predefined_modules)
   for _, name in ipairs(predefined_modules) do
      local ok, err = environment.load_module(env, name)
      if not ok then
         return nil, err
      end
   end

   return true
end

v2.new_env = function(opts)
   local env = env_from_check_options(opts and opts.defaults)

   if opts and opts.predefined_modules then
      local ok, err = predefine_modules(env, opts.predefined_modules)
      if not ok then
         return nil, err
      end
   end

   return env
end

v2.parse = function(input, filename, parse_lang)
   local ast, errs, required_modules = parser.parse(input, filename, parse_lang)
   return ast, errs, required_modules
end

v2.parse_program = function(tokens, errs, filename, parse_lang)
   local ast, required_modules = parser.parse_program(tokens, errs, filename, parse_lang)
   return ast, required_modules
end

v2.process = v2.check_file

v2.search_module = function(module_name, search_all)
   return require_file.search_module(module_name, search_all and require_file.all_extensions)
end

v2.symbols_in_scope = function(tr, y, x, filename)
   return tr:symbols_in_scope(filename, y, x)
end

v2.target_from_lua_version = targets.detect

v2.version = function()
   return environment.VERSION
end



return v2
