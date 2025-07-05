local environment = require("teal.environment")
local type Env = environment.Env
local type Feat = environment.Feat
local type GenCompat = environment.GenCompat
local type Result = environment.Result
local errors = require("teal.errors")
local type Error = errors.Error
local lexer = require("teal.lexer")
local type Token = lexer.Token
local loader = require("teal.loader")
local lua_generator = require("teal.gen.lua_generator")
local package_loader = require("teal.package_loader")
local parser = require("teal.parser")
local type Node = parser.Node
local targets = require("teal.gen.targets")
local type_reporter = require("teal.type_reporter")
local type TypeReport = type_reporter.TypeReport
local type TypeReporter = type_reporter.TypeReporter
local v2 = require("teal.api.v2")

--------------------------------------------------------------------------------
-- Public API v1 (~0.15.x)
--------------------------------------------------------------------------------

local record v1
   type CompatMode = environment.GenCompat
   type Env = environment.Env
   type Error = errors.Error
   type LoadFunction = loader.LoadFunction
   type LoadMode = loader.LoadMode
   type PrettyPrintOpts = v2.GenerateOptions
   type Result = environment.Result
   type Symbol = type_reporter.TypeCollector.Symbol
   type TargetMode = targets.GenTarget
   type TypeInfo = type_reporter.TypeInfo
   type TypeReport = type_reporter.TypeReport
   type WarningKind = errors.WarningKind

   record TypeCheckOptions
      lax: boolean
      filename: string
      module_name: string
      gen_compat: CompatMode
      gen_target: TargetMode
      env: Env
      run_internal_compiler_checks: boolean
   end

   warning_kinds: {WarningKind:boolean}
   typecodes: {string:integer}

   gen: function(string, Env): string, Result
   get_token_at: function(tks: {Token}, y: integer, x: integer): string
   get_types: function(result: Result): TypeReport, TypeReporter
   init_env: function(boolean, ? boolean | CompatMode, ? TargetMode, ? {string}): Env, string
   lex: function(input: string, filename: string): {Token}, {Error}
   loader: function()
   load: function(string, string, LoadMode, {any:any}): LoadFunction, string
   parse: function(input: string, filename: string): Node, {Error}, {string}
   parse_program: function(tokens: {Token}, errs: {Error}, filename?: string): Node, {string}
   pretty_print_ast: function(ast: Node, gen_target?: TargetMode, mode?: boolean | PrettyPrintOpts): string, string
   process: function(string, Env, string, FILE): (Result, string)
   process_string: function(input: string, is_lua: boolean, env: Env, filename: string, _module_name: string): Result
   search_module: function(module_name: string, search_all: boolean): string, FILE, {string}
   symbols_in_scope: function(tr: TypeReport, y: integer, x: integer, filename: string): {string:integer}
   target_from_lua_version: function(str: string): TargetMode
   type_check: function(Node, TypeCheckOptions): Result, string
   version: function(): string
end

local type TargetMode = v1.TargetMode

v1.gen = function(input: string, env: Env): string, Result
   return v2.gen(input, env)
end

v1.get_token_at = lexer.get_token_at

v1.get_types = function(result: Result): TypeReport, TypeReporter
   return result.env.reporter:get_report(), result.env.reporter
end

v1.init_env = function(lax?: boolean, gen_compat?: boolean | GenCompat, gen_target?: TargetMode, predefined?: {string}): Env, string
   local opts = {
      defaults = {
         feat_lax = (lax and "on" or "off") as Feat,
         gen_compat = ((gen_compat is GenCompat) and gen_compat) or
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

v1.parse = function(input: string, filename: string): Node, {Error}, {string}
   return parser.parse(input, filename) as (parser.Node, {Error}, {string})
end

v1.parse_program = function(tokens: {Token}, errs: {Error}, filename?: string): Node, {string}
   return parser.parse_program(tokens, errs, filename) as (parser.Node, {string})
end

v1.pretty_print_ast = function(ast: Node, gen_target?: v1.TargetMode, mode?: boolean | v1.PrettyPrintOpts): string, string
   local opts: v1.PrettyPrintOpts
   if mode is v1.PrettyPrintOpts then
      opts = mode
   elseif mode == true then
      opts = lua_generator.fast_opts
   else
      opts = lua_generator.default_opts
   end

   return lua_generator.generate(ast, gen_target, opts)
end

v1.process = function(filename: string, env?: Env, _module_name?: string, fd?: FILE): Result, string
   return v2.check_file(filename, env, fd)
end

v1.process_string = function(input: string, is_lua: boolean, env: Env, filename: string, _module_name: string): Result
   return v2.check_string(input, env or v1.init_env(is_lua), filename)
end

v1.search_module = v2.search_module

v1.symbols_in_scope = v2.symbols_in_scope

v1.target_from_lua_version = targets.detect

v1.type_check = function(ast: Node, tc_opts?: v1.TypeCheckOptions): Result, string
   local opts: v2.CheckOptions = {
      feat_lax = tc_opts.lax and "on" or "off",
      feat_arity = tc_opts.env and tc_opts.env.opts.feat_arity or "on",
      gen_compat = tc_opts.gen_compat,
      gen_target = tc_opts.gen_target,
   }
   return v2.check(ast as v2.Node, tc_opts.filename, opts, tc_opts.env)
end

v1.version = v2.version

return v1
