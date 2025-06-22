local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs; local default_env = require("teal.precompiled.default_env")

local errors = require("teal.errors")


local lua_generator = require("teal.gen.lua_generator")

local target_from_lua_version = lua_generator.target_from_lua_version

local parser = require("teal.parser")



local types = require("teal.types")



local type_reporter = require("teal.type_reporter")


local variables = require("teal.variables")


local environment = { CheckOptions = {}, Env = {}, Result = {} }

















































environment.DEFAULT_GEN_COMPAT = "optional"
environment.DEFAULT_GEN_TARGET = "5.3"





function environment.default(parse_lang, runtime)
   local gen_target = runtime and target_from_lua_version(_VERSION) or environment.DEFAULT_GEN_TARGET
   local gen_compat = (gen_target == "5.4") and "off" or environment.DEFAULT_GEN_COMPAT
   local defaults = {
      feat_lax = parse_lang == "lua" and "on" or "off",
      gen_target = gen_target,
      gen_compat = gen_compat,
      run_internal_compiler_checks = false,
   }

   local env = {
      modules = {},
      module_filenames = {},
      loaded = {},
      loaded_order = {},
      globals = {},
      defaults = defaults,
   }

   if not environment.stdlib_globals then
      environment.stdlib_globals = default_env.globals
      types.internal_force_state(default_env.typeid_ctr, default_env.typevar_ctr)
   end

   for name, var in pairs(environment.stdlib_globals) do
      env.globals[name] = var
      local t = var.t
      if t.typename == "typedecl" then

         env.modules[name] = t
      end
   end

   return env
end

return environment
