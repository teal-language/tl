local lua_generator = require("teal.gen.lua_generator")

local type_reporter = require("teal.type_reporter")
local type TypeReporter = type_reporter.TypeReporter

local variables = require("teal.variables")
local type Variable = variables.Variable

local types = require("teal.types")
local type Type = types.Type

local parser = require("teal.parser")
local type Node = parser.Node

local errors = require("teal.errors")
local type Error = errors.Error

local record environment
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
end

return environment
