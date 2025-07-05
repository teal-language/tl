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

local type_reporter = require("teal.type_reporter")





local v2 = { EnvOptions = {} }




















































environment.set_require_module_fn(require_file.require_module)

v2.warning_kinds = errors.warning_kinds
v2.typecodes = type_reporter.typecodes
















v2.check = function(ast, filename, opts, env)
   local result, err = check.check(ast, filename, opts, env)
   if result and result.ast then
      lua_compat.apply(result)
   end
   return result, err
end

v2.check_file = function(filename, env, fd)
   env = env or environment.new()
   local result, err = file_checker.check(env, filename, fd)
   if result and result.ast then
      lua_compat.apply(result)
   end
   return result, err
end

v2.check_string = function(input, env, filename, parse_lang)
   env = env or environment.new()
   env.defaults = env.defaults or {}
   env.defaults.feat_lax = parse_lang == "lua" and "on" or "off"
   local result = string_checker.check(env, input, filename)
   if result and result.ast then
      lua_compat.apply(result)
   end
   return result
end

v2.gen = function(input, env, opts, parse_lang)
   env = env or environment.new()
   env.defaults = env.defaults or {}
   env.defaults.feat_lax = parse_lang == "lua" and "on" or "off"
   local result = string_checker.check(env, input)

   if (not result.ast) or #result.syntax_errors > 0 then
      return nil, result
   end

   lua_compat.apply(result)

   local code
   code, result.gen_error = lua_generator.generate(result.ast, env.defaults.gen_target, opts)
   return code, result
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
   local env, err = environment.new(opts and opts.defaults)
   if not env then
      return nil, err
   end

   if opts and opts.predefined_modules then
      local ok
      ok, err = predefine_modules(env, opts.predefined_modules)
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

v2.search_module = require_file.search_module

v2.symbols_in_scope = type_reporter.symbols_in_scope

v2.target_from_lua_version = lua_generator.target_from_lua_version

v2.version = function()
   return environment.VERSION
end



return v2
