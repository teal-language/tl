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
local type TypeDeclType = types.TypeDeclType

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
local type GenCompat = environment.GenCompat

function environment.default(parse_lang?: ParseLang, runtime?: boolean): Env, string
   local gen_target = runtime and target_from_lua_version(_VERSION) or environment.DEFAULT_GEN_TARGET
   local gen_compat: GenCompat = (gen_target == "5.4") and "off" or environment.DEFAULT_GEN_COMPAT
   local defaults: CheckOptions = {
      feat_lax = parse_lang == "lua" and "on" or "off",
      gen_target = gen_target,
      gen_compat = gen_compat,
      run_internal_compiler_checks = false,
   }

   local env: Env = {
      modules = {},
      module_filenames = {},
      loaded = {},
      loaded_order = {},
      globals = {},
      defaults = defaults,
   }

   if not environment.stdlib_globals then
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

   return env
end

return environment
