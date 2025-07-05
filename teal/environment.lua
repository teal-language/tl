local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string
local VERSION = "0.24.6+dev"

local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG

local default_env = require("teal.precompiled.default_env")





local lua_generator = require("teal.gen.lua_generator")

local target_from_lua_version = lua_generator.target_from_lua_version





local types = require("teal.types")






local a_type = types.a_type







local environment = { CheckOptions = {}, Env = {}, Result = {} }























































environment.VERSION = VERSION
environment.DEFAULT_GEN_COMPAT = "optional"
environment.DEFAULT_GEN_TARGET = "5.3"




local require_module

function environment.set_require_module_fn(fn)
   require_module = fn
end

local function empty_environment()
   return {
      modules = {},
      module_filenames = {},
      loaded = {},
      loaded_order = {},
      globals = {},
      defaults = {},
      require_module = require_module,
   }
end

local function load_precompiled_default_env(env)
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
end


function environment.new(check_opts)
   if check_opts and check_opts.gen_target == "5.4" and check_opts.gen_compat ~= "off" then
      return nil, "gen-compat must be explicitly 'off' when gen-target is '5.4'"
   end

   local env = empty_environment()
   env.defaults = check_opts or env.defaults
   load_precompiled_default_env(env)
   return env
end





function environment.for_runtime(parse_lang)
   local gen_target = target_from_lua_version(_VERSION)
   local gen_compat = (gen_target == "5.4") and "off" or environment.DEFAULT_GEN_COMPAT
   return environment.new({
      feat_lax = parse_lang == "lua" and "on" or "off",
      gen_target = gen_target,
      gen_compat = gen_compat,
      run_internal_compiler_checks = false,
   })
end

do
   local function get_stdlib_compat()
      return {
         ["io"] = true,
         ["math"] = true,
         ["string"] = true,
         ["table"] = true,
         ["utf8"] = true,
         ["coroutine"] = true,
         ["os"] = true,
         ["package"] = true,
         ["debug"] = true,
         ["load"] = true,
         ["loadfile"] = true,
         ["assert"] = true,
         ["pairs"] = true,
         ["ipairs"] = true,
         ["pcall"] = true,
         ["xpcall"] = true,
         ["rawlen"] = true,
      }
   end

   local function set_special_function(t, fname)
      t = types.resolve_for_special_function(t)
      t.special_function_handler = fname
   end










   function environment.construct(check_opts, prelude, stdlib)
      if check_opts and check_opts.gen_target == "5.4" and check_opts.gen_compat ~= "off" then
         return nil, "gen-compat must be explicitly 'off' when gen-target is '5.4'"
      end

      local env = empty_environment()
      env.defaults = check_opts or env.defaults

      local stdlib_globals = environment.stdlib_globals
      if not stdlib_globals then
         local tl_debug = TL_DEBUG
         TL_DEBUG = nil

         local w = { f = "@prelude", x = 1, y = 1 }

         local typ = env:require_module(w, prelude or "teal.default.prelude", {})
         if typ.typename == "invalid" then
            return nil, "prelude contains errors"
         end

         typ = env:require_module(w, stdlib or "teal.default.stdlib", {})
         if typ.typename == "invalid" then
            return nil, "standard library contains errors"
         end

         stdlib_globals = env.globals
         environment.stdlib_globals = env.globals

         TL_DEBUG = tl_debug


         local math_t = (stdlib_globals["math"].t).def
         local table_t = (stdlib_globals["table"].t).def
         math_t.fields["maxinteger"].needs_compat = true
         math_t.fields["mininteger"].needs_compat = true
         table_t.fields["pack"].needs_compat = true
         table_t.fields["unpack"].needs_compat = true


         local string_t = (stdlib_globals["string"].t).def
         set_special_function(string_t.fields["find"], "string.find")
         set_special_function(string_t.fields["format"], "string.format")
         set_special_function(string_t.fields["gmatch"], "string.gmatch")
         set_special_function(string_t.fields["gsub"], "string.gsub")
         set_special_function(string_t.fields["match"], "string.match")
         set_special_function(string_t.fields["pack"], "string.pack")
         set_special_function(string_t.fields["unpack"], "string.unpack")

         set_special_function(stdlib_globals["assert"].t, "assert")
         set_special_function(stdlib_globals["ipairs"].t, "ipairs")
         set_special_function(stdlib_globals["pairs"].t, "pairs")
         set_special_function(stdlib_globals["pcall"].t, "pcall")
         set_special_function(stdlib_globals["xpcall"].t, "xpcall")
         set_special_function(stdlib_globals["rawget"].t, "rawget")
         set_special_function(stdlib_globals["require"].t, "require")




         stdlib_globals["..."] = { t = a_type(w, "tuple", { tuple = { a_type(w, "string", {}) }, is_va = true }) }
         stdlib_globals["@is_va"] = { t = a_type(w, "any", {}) }

         env.globals = {}
      end

      local stdlib_compat = get_stdlib_compat()
      for name, var in pairs(stdlib_globals) do
         env.globals[name] = var
         var.needs_compat = stdlib_compat[name]
         local t = var.t
         if t.typename == "typedecl" then

            env.modules[name] = t
         end
      end

      return env
   end
end

function environment.load_module(env, name, opts)
   local w = { f = "@predefined", x = 1, y = 1 }
   local module_type = env:require_module(w, name, opts)

   if module_type.typename == "invalid" then
      return false, string.format("Error: could not predefine module '%s'", name)
   end

   return true
end

return environment
