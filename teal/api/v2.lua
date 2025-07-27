local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local check = require("teal.check.check")
local environment = require("teal.environment")
local errors = require("teal.errors")
local lexer = require("teal.lexer")
local loader = require("teal.loader")
local lua_generator = require("teal.gen.lua_generator")
local lua_compat = require("teal.gen.lua_compat")
local package_loader = require("teal.package_loader")
local parser = require("teal.parser")
local require_file = require("teal.check.require_file")
local input = require("teal.input")
local targets = require("teal.gen.targets")

local type_reporter = require("teal.type_reporter")





local v2 = { CheckOptions = {}, EnvOptions = {} }
























































environment.set_require_module_fn(require_file.require_module)

v2.warning_kinds = errors.warning_kinds
v2.typecodes = type_reporter.typecodes

















local function env_from_check_options(opts)
   return environment.new(opts and {
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

   local result = check.check(ast, env, filename or "<input>.tl")
   if result and result.ast then
      lua_compat.apply(result)
   end
   return result
end

v2.check_file = function(filename, env, fd)
   env = env or environment.new()
   local err
   if not fd then
      fd, err = io.open(filename, "rb")
      if not fd then
         return nil, err
      end
   end
   local code
   code, err = fd:read("*a")
   if not code then
      return nil, err
   end
   local result = input.check(env, filename, code)
   if result.ast then
      lua_compat.apply(result)
   end
   return result
end

v2.check_string = function(teal_code, env, filename, parse_lang)
   env = env or environment.new()
   if not filename then
      filename = parse_lang == "lua" and "<input>.lua" or "<input>.tl"
   end
   local result = input.check(env, filename, teal_code)
   if result and result.ast then
      lua_compat.apply(result)
   end
   return result
end

v2.gen = function(teal_code, env, opts, parse_lang)
   env = env or environment.new()
   local filename = parse_lang == "lua" and "<input>.lua" or "<input>.tl"
   local result = input.check(env, filename, teal_code)
   if (not result.ast) or #result.syntax_errors > 0 then
      return nil, result
   end
   lua_compat.apply(result)
   local code = lua_generator.generate(result.ast, env.opts.gen_target, opts)
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
      local ok = environment.load_module(env, name)
      if not ok then
         return nil, "Error: could not predefine module '" .. name .. "'"
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

v2.parse = function(teal_code, filename, _parse_lang)
   local ast, errs, required_modules = parser.parse(teal_code, filename)
   return ast, errs, required_modules
end

v2.parse_program = function(tokens, errs, filename, parse_lang)
   local ast, required_modules = parser.parse_program(tokens, errs, filename, parse_lang)
   return ast, required_modules
end

v2.process = v2.check_file

v2.search_module = function(module_name, search_all)
   local found, _, tried = require_file.search_module(module_name, search_all and require_file.all_extensions)
   if found then
      return found, (io.open(found)), nil
   end
   return nil, nil, tried
end

v2.symbols_in_scope = function(tr, y, x, filename)
   return tr:symbols_in_scope(filename, y, x)
end

v2.target_from_lua_version = targets.detect

v2.version = function()
   return environment.VERSION
end



return v2
