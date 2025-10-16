
local VERSION = "0.25.0-alpha+dev"

local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG

local default_env = require("teal.precompiled.default_env")

local type errors = require("teal.errors")
local type Error = errors.Error

local type targets = require("teal.gen.targets")
local type GenTarget = targets.GenTarget

local type parser = require("teal.parser")
local type Node = parser.Node

local types = require("teal.types")
local type Type = types.Type
local type InvalidType = types.InvalidType
local type RecordType = types.RecordType
local type TupleType = types.TupleType
local type TypeDeclType = types.TypeDeclType
local type SpecialFunctionName = types.SpecialFunctionName
local a_type = types.a_type

local type type_reporter = require("teal.type_reporter")
local type TypeReporter = type_reporter.TypeReporter

local type variables = require("teal.variables")
local type Variable = variables.Variable

local record environment
   VERSION: string
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

   record EnvOptions
      feat_arity: Feat
      gen_compat: GenCompat
      gen_target: GenTarget
      run_internal_compiler_checks: boolean
   end

   type RequireModuleFn = function(env: Env, module_name: string): Type, string

   record Env
      loaded: {string:Result}
      loaded_order: {string}
      reporter: TypeReporter
      keep_going: boolean
      report_types: boolean

      -- private:
      opts: EnvOptions
      globals: {string:Variable}
      modules: {string:Type}
      module_filenames: {string:string}
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
      needs_compat: {string:boolean}
      compat_applied: boolean
   end

   stdlib_globals: {string:Variable}
end

environment.VERSION = VERSION
environment.DEFAULT_GEN_COMPAT = "optional"
environment.DEFAULT_GEN_TARGET = "5.3"

local type EnvOptions = environment.EnvOptions
local type Env = environment.Env
local type Result = environment.Result

local require_module: environment.RequireModuleFn

function environment.set_require_module_fn(fn: environment.RequireModuleFn)
   require_module = fn
end

local function empty_environment(): Env
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

local function declare_globals(env: Env)
   for name, var in pairs(environment.stdlib_globals) do
      env.globals[name] = var
      local t = var.t
      if t is TypeDeclType then
         -- make standard library tables available as modules for require()
         env.modules[name] = t
      end
   end
end

local function load_precompiled_default_env(env: Env)
   if not environment.stdlib_globals then
      -- TODO This type of state data which is currently "globally"
      -- stored in module tables and closures should move to the
      -- Env object, eventually.
      environment.stdlib_globals = default_env.globals as {string:Variable}
      types.internal_force_state(default_env.typeid_ctr, default_env.typevar_ctr)
   end

   declare_globals(env)
end

--- Build a default environment.
function environment.new(opts?: EnvOptions): Env
   local env = empty_environment()
   env.opts = opts or env.opts
   load_precompiled_default_env(env)
   return env
end

--- Build a default environment tuned to the Lua version we're running.
--
-- This is used by the APIs that are meant to run embedded in a
-- client application, such as `tl.load` and the Teal package loader.
function environment.for_runtime(): Env
   local gen_target = targets.detect()
   local gen_compat = (gen_target == "5.4") and "off" or environment.DEFAULT_GEN_COMPAT
   return environment.new({
      gen_target = gen_target,
      gen_compat = gen_compat,
      run_internal_compiler_checks = false,
   })
end

do
   local stdlib_compat: {string:boolean} = {
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
   function environment.construct(opts?: EnvOptions, prelude?: string, stdlib?: string): Env, string
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
         if typ is InvalidType then
            return nil, "prelude contains errors"
         end

         typ = env:require_module(stdlib or "teal.default.stdlib")
         if typ is InvalidType then
            return nil, "standard library contains errors"
         end

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
         local w = { filename = "@<stdlib>.tl", y = 1, x = 1 }
         stdlib_globals["..."] = { t = a_type(w, "tuple", { tuple = { a_type(w, "string", {}) }, is_va = true } as TupleType) }
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

function environment.load_module(env: Env, name: string): boolean, string
   local module_type = env:require_module(name)

   if not module_type then
      return false, string.format("could not load module '%s'", name)
   end

   return true
end

function environment.register(env: Env, filename: string, result: Result)
   env.loaded[filename] = result

   table.insert(env.loaded_order, filename)
end

function environment.register_failed(env: Env, filename: string, syntax_errors: {Error}): Result
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
