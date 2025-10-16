local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table
local VERSION = "0.25.0-alpha+dev"

local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG

local default_env = require("teal.precompiled.default_env")




local targets = require("teal.gen.targets")





local types = require("teal.types")






local a_type = types.a_type







local environment = { EnvOptions = {}, Env = {}, Result = {} }
























































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
      opts = {},
      require_module = require_module,
   }
end

local function declare_globals(env)
   for name, var in pairs(environment.stdlib_globals) do
      env.globals[name] = var
      local t = var.t
      if t.typename == "typedecl" then

         env.modules[name] = t
      end
   end
end

local function load_precompiled_default_env(env)
   if not environment.stdlib_globals then



      environment.stdlib_globals = default_env.globals
      types.internal_force_state(default_env.typeid_ctr, default_env.typevar_ctr)
   end

   declare_globals(env)
end


function environment.new(opts)
   local env = empty_environment()
   env.opts = opts or env.opts
   load_precompiled_default_env(env)
   return env
end





function environment.for_runtime()
   local gen_target = targets.detect()
   local gen_compat = (gen_target == "5.4") and "off" or environment.DEFAULT_GEN_COMPAT
   return environment.new({
      gen_target = gen_target,
      gen_compat = gen_compat,
      run_internal_compiler_checks = false,
   })
end

do
   local stdlib_compat = {
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

   local function set_special_function(t, fname)
      t = types.resolve_for_special_function(t)
      t.special_function_handler = fname
   end










   function environment.construct(opts, prelude, stdlib)
      if opts and opts.gen_target == "5.4" and opts.gen_compat ~= "off" then
         return nil, "gen-compat must be explicitly 'off' when gen-target is '5.4'"
      end

      local env = empty_environment()
      env.opts = opts or env.opts

      local stdlib_globals = environment.stdlib_globals
      if not stdlib_globals then
         local tl_debug = TL_DEBUG
         TL_DEBUG = nil

         local typ = env:require_module(prelude or "teal.default.prelude")
         if typ.typename == "invalid" then
            return nil, "prelude contains errors"
         end

         typ = env:require_module(stdlib or "teal.default.stdlib")
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




         local w = { filename = "@<stdlib>.tl", y = 1, x = 1 }
         stdlib_globals["..."] = { t = a_type(w, "tuple", { tuple = { a_type(w, "string", {}) }, is_va = true }) }
         stdlib_globals["@is_va"] = { t = a_type(w, "any", {}) }

         env.globals = {}
      end

      declare_globals(env)

      for name, _ in pairs(stdlib_compat) do
         env.globals[name].needs_compat = true
      end

      return env
   end
end

function environment.load_module(env, name)
   local module_type = env:require_module(name)

   if not module_type then
      return false, string.format("could not load module '%s'", name)
   end

   return true
end

function environment.register(env, filename, result)
   env.loaded[filename] = result

   table.insert(env.loaded_order, filename)
end

function environment.register_failed(env, filename, syntax_errors)
   local result = {
      filename = filename,
      type = a_type({ f = filename, y = 1, x = 1 }, "boolean", {}),
      type_errors = {},
      syntax_errors = syntax_errors,
      dependencies = {},
      env = env,
   }
   env.loaded[filename] = result
   table.insert(env.loaded_order, filename)
   return result
end

return environment
