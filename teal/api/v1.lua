local type = type; local environment = require("teal.environment")




local errors = require("teal.errors")

local lexer = require("teal.lexer")

local loader = require("teal.loader")
local lua_generator = require("teal.gen.lua_generator")
local package_loader = require("teal.package_loader")
local parser = require("teal.parser")

local targets = require("teal.gen.targets")
local type_reporter = require("teal.type_reporter")


local v2 = require("teal.api.v2")





local v1 = { TypeCheckOptions = {} }















































v1.gen = function(input, env)
   return v2.gen(input, env)
end

v1.get_token_at = lexer.get_token_at

v1.get_types = function(result)
   return result.env.reporter:get_report(), result.env.reporter
end

v1.init_env = function(lax, gen_compat, gen_target, predefined)
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

   if opts.defaults.gen_target == "5.4" and opts.defaults.gen_compat ~= "off" then
      return nil, "gen-compat must be explicitly 'off' when gen-target is '5.4'"
   end

   local env, err = v2.new_env(opts)
   if env then
      env.report_types = true
   end
   return env, err
end

v1.lex = lexer.lex

v1.load = loader.load

v1.loader = package_loader.install_loader

v1.parse = function(input, filename)
   return parser.parse(input, filename)
end

v1.parse_program = function(tokens, errs, filename)
   return parser.parse_program(tokens, errs, filename)
end

v1.pretty_print_ast = function(ast, gen_target, mode)
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

v1.process = function(filename, env, _module_name, fd)
   return v2.check_file(filename, env, fd)
end

v1.process_string = function(input, is_lua, env, filename, _module_name)
   return v2.check_string(input, env or v1.init_env(is_lua), filename)
end

v1.search_module = v2.search_module

v1.symbols_in_scope = v2.symbols_in_scope

v1.target_from_lua_version = targets.detect

v1.type_check = function(ast, tc_opts)
   local opts = {
      feat_lax = tc_opts.lax and "on" or "off",
      feat_arity = tc_opts.env and tc_opts.env.opts.feat_arity or "on",
      gen_compat = tc_opts.gen_compat,
      gen_target = tc_opts.gen_target,
   }
   return v2.check(ast, tc_opts.filename, opts, tc_opts.env)
end

v1.version = v2.version

return v1
