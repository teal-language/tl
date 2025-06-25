local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG

local default_env = require("teal.precompiled.default_env")

local errors = require("teal.errors")
local type Error = errors.Error

local lua_generator = require("teal.gen.lua_generator")
local type GenTarget = lua_generator.Target
local target_from_lua_version = lua_generator.target_from_lua_version

local parser = require("teal.parser")
local type Node = parser.Node
local type ParseLang = parser.ParseLang

local types = require("teal.types")
local type Type = types.Type
local type Where = types.Where
local type InvalidType = types.InvalidType
local type RecordType = types.RecordType
local type TupleType = types.TupleType
local type TypeDeclType = types.TypeDeclType
local type SpecialFunctionName = types.SpecialFunctionName
local a_type = types.a_type

local type_reporter = require("teal.type_reporter")
local type TypeReporter = type_reporter.TypeReporter

local variables = require("teal.variables")
local type Variable = variables.Variable

local record environment
   DEFAULT_GEN_COMPAT: GenCompat
   DEFAULT_GEN_TARGET: GenTarget

   enum GenCompat
      "off"
      "optional"
      "required"
   end

   enum Feat
      "on"
      "off"
   end

   record CheckOptions
      feat_lax: Feat
      feat_arity: Feat
      gen_compat: GenCompat
      gen_target: lua_generator.Target
      run_internal_compiler_checks: boolean
   end

   type RequireModuleFn = function(env: Env, w: Where, module_name: string, opts: CheckOptions): Type, string

   record Env
      globals: {string:Variable}
      modules: {string:Type}
      module_filenames: {string:string}
      loaded: {string:Result}
      loaded_order: {string}
      reporter: TypeReporter
      keep_going: boolean
      report_types: boolean
      defaults: CheckOptions
      require_module: RequireModuleFn
   end

   record Result
      filename: string
      ast: Node
      type: Type
      syntax_errors: {Error}
      type_errors: {Error}
      gen_error: string
      warnings: {Error}
      env: Env
      dependencies: {string:string} -- module name, file found
   end

   stdlib_globals: {string:Variable}
end

environment.DEFAULT_GEN_COMPAT = "optional"
environment.DEFAULT_GEN_TARGET = "5.3"

local type CheckOptions = environment.CheckOptions
local type Env = environment.Env

local require_module: environment.RequireModuleFn

function environment.set_require_module_fn(fn: environment.RequireModuleFn)
   require_module = fn
end

function environment.empty(check_opts?: CheckOptions): Env, string
   if check_opts and check_opts.gen_target == "5.4" and check_opts.gen_compat ~= "off" then
      return nil, "gen-compat must be explicitly 'off' when gen-target is '5.4'"
   end

   return {
      modules = {},
      module_filenames = {},
      loaded = {},
      loaded_order = {},
      globals = {},
      defaults = check_opts or {},
      require_module = require_module,
   }
end

local function load_precompiled_default_env(env: Env)
   if not environment.stdlib_globals then
      -- TODO This type of state data which is currently "globally"
      -- stored in module tables and closures should move to the
      -- Env object, eventually.
      environment.stdlib_globals = default_env.globals as {string:Variable}
      types.internal_force_state(default_env.typeid_ctr, default_env.typevar_ctr)
   end

   for name, var in pairs(environment.stdlib_globals) do
      env.globals[name] = var
      local t = var.t
      if t is TypeDeclType then
         -- make standard library tables available as modules for require()
         env.modules[name] = t
      end
   end
end

--- Build a default environment.
function environment.new(check_opts?: CheckOptions): Env, string
   local env, err = environment.empty(check_opts)
   if not env then
      return nil, err
   end
   load_precompiled_default_env(env)
   return env
end

--- Build a default environment tuned to the Lua version we're running.
--
-- This is used by the APIs that are meant to run embedded in a
-- client application, such as `tl.load` and the Teal package loader.
function environment.for_runtime(parse_lang?: ParseLang): Env, string
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
   local function get_stdlib_compat(): {string:boolean}
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

   local function set_special_function(t: Type, fname: SpecialFunctionName)
      t = types.resolve_for_special_function(t)
      t.special_function_handler = fname
   end

   --- Constructs an environment from scratch, loading from Teal .d.tl files.
   --
   -- This builds an environment from scratch, requiring a prelude and a
   -- standard library module. It makes some assumptions about the standard
   -- library contents, annotating their entries with special markers used
   -- internally by the compiler.
   --
   -- This is used by the precompiler when building
   -- `teal.precompiled.default_env`.
   function environment.construct(check_opts?: CheckOptions, prelude?: string, stdlib?: string): Env, string
      local env, err = environment.empty(check_opts)
      if not env then
         return nil, err
      end

      local stdlib_globals = environment.stdlib_globals
      if not stdlib_globals then
         local tl_debug = TL_DEBUG
         TL_DEBUG = nil

         local w: Where = { f = "@prelude", x = 1, y = 1 }

         local typ = env:require_module(w, prelude or "teal.default.prelude", {})
         assert(not typ is InvalidType, "prelude contains errors")

         typ = env:require_module(w, stdlib or "teal.default.stdlib", {})
         assert(not typ is InvalidType, "standard library contains errors")

         stdlib_globals = env.globals
         environment.stdlib_globals = env.globals

         TL_DEBUG = tl_debug

         -- special cases for compatibility
         local math_t = (stdlib_globals["math"].t as TypeDeclType).def as RecordType
         local table_t = (stdlib_globals["table"].t as TypeDeclType).def as RecordType
         math_t.fields["maxinteger"].needs_compat = true
         math_t.fields["mininteger"].needs_compat = true
         table_t.fields["pack"].needs_compat = true
         table_t.fields["unpack"].needs_compat = true

         -- special cased functions
         local string_t = (stdlib_globals["string"].t as TypeDeclType).def as RecordType
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

         -- only global scope and vararg functions accept `...`:
         -- `@is_va` is an internal sentinel value which is
         -- `any` if `...` is accepted in this scope or `nil` if it isn't.
         stdlib_globals["..."] = { t = a_type(w, "tuple", { tuple = { a_type(w, "string", {}) }, is_va = true } as TupleType) }
         stdlib_globals["@is_va"] = { t = a_type(w, "any", {}) }

         env.globals = {}
      end

      local stdlib_compat = get_stdlib_compat()
      for name, var in pairs(stdlib_globals) do
         env.globals[name] = var
         var.needs_compat = stdlib_compat[name]
         local t = var.t
         if t is TypeDeclType then
            -- make standard library tables available as modules for require()
            env.modules[name] = t
         end
      end

      return env
   end
end

function environment.predefine(env: Env, predefined_modules: {string}): boolean, string
   local opts = {
      feat_lax = env.defaults.feat_lax,
      feat_arity = env.defaults.feat_arity,
   }
   for _, name in ipairs(predefined_modules) do
      local w: Where = { f = "@predefined", x = 1, y = 1 }
      local module_type = env:require_module(w, name, opts)

      if module_type is InvalidType then
         return false, string.format("Error: could not predefine module '%s'", name)
      end
   end

   return true
end

return environment
