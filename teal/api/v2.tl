local type check = require("teal.check.check")
local type environment = require("teal.environment")
local type errors = require("teal.errors")
local type file_checker = require("teal.check.file_checker")
local type lexer = require("teal.lexer")
local type loader = require("teal.loader")
local type lua_generator = require("teal.gen.lua_generator")
local type lua_compat = require("teal.gen.lua_compat")
local type package_loader = require("teal.package_loader")
local type parser = require("teal.parser")
local type require_file = require("teal.check.require_file")
local type string_checker = require("teal.check.string_checker")
local type type_errors = require("teal.type_errors")
local type type_reporter = require("teal.type_reporter")

--------------------------------------------------------------------------------
-- Public API v2 (0.24.x)
--------------------------------------------------------------------------------

local record v2
   type CheckOptions = environment.CheckOptions
   type Env = environment.Env
   type Error = errors.Error
   type Feat = environment.Feat
   type GenCompat = environment.GenCompat
   type GenerateOptions = lua_generator.Options
   type GenTarget = lua_generator.Target
   type LoadFunction = loader.LoadFunction
   type LoadMode = loader.LoadMode
   type ParseLang = parser.ParseLang
   type Result = environment.Result
   type TokenKind = lexer.TokenKind
   type Token = lexer.Token
   type TypeInfo = type_reporter.TypeInfo
   type TypeReport = type_reporter.TypeReport
   type WarningKind = errors.WarningKind

   type errors = type_errors.Errors

   warning_kinds: {WarningKind:boolean}
   typecodes: {string:integer}

   record EnvOptions
      defaults: CheckOptions
      predefined_modules: {string}
   end

   -- abstract type
   interface Node
   end

   check_file: function(filename: string, env?: Env, fd?: FILE): (Result, string)
   check: function(Node, ? string, ? CheckOptions, ? Env): Result, string
   check_string: function(input: string, env?: Env, filename?: string, parse_lang?: ParseLang): Result
   generate: function(ast: Node, gen_target: GenTarget, opts?: GenerateOptions): string, string
   gen: function(string, ? Env, ? GenerateOptions): string, Result
   get_token_at: function(tks: {Token}, y: integer, x: integer): string
   lex: function(input: string, filename: string): {Token}, {Error}
   loader: function()
   load: function(string, ? string, ? LoadMode, ...: {any:any}): LoadFunction, string
   new_env: function(? EnvOptions): Env, string
   parse: function(input: string, filename: string, parse_lang?: ParseLang): Node, {Error}, {string}
   parse_program: function(tokens: {Token}, errs: {Error}, filename?: string, parse_lang?: ParseLang): Node, {string}
   process: function(filename: string, env?: Env, fd?: FILE): (Result, string)
   search_module: function(module_name: string, search_all: boolean): string, FILE, {string}
   symbols_in_scope: function(tr: TypeReport, y: integer, x: integer, filename: string): {string:integer}
   target_from_lua_version: function(str: string): GenTarget
   version: function(): string

   path: string -- if set be the user, this overrides package.path for Teal
end

environment.set_require_module_fn(require_file.require_module)

v2.warning_kinds = errors.warning_kinds
v2.typecodes = type_reporter.typecodes

local type CheckOptions = v2.CheckOptions
local type EnvOptions = v2.EnvOptions
local type Env = v2.Env
local type Error = v2.Error
local type GenerateOptions = v2.GenerateOptions
local type GenTarget = v2.GenTarget
local type Node = v2.Node
local type ParseLang = v2.ParseLang
local type Result = v2.Result
local type Token = v2.Token

--------------------------------------------------------------------------------
-- Functions
--------------------------------------------------------------------------------

v2.check = function(ast: Node, filename?: string, opts?: CheckOptions, env?: Env): Result, string
   local result, err = check.check(ast as parser.Node, filename, opts, env)
   if result and result.ast then
      lua_compat.apply(result)
   end
   return result, err
end

v2.check_file = function(filename: string, env?: Env, fd?: FILE): (Result, string)
   env = env or environment.new()
   local result, err = file_checker.check(env, filename, fd)
   if result and result.ast then
      lua_compat.apply(result)
   end
   return result, err
end

v2.check_string = function(input: string, env?: Env, filename?: string, parse_lang?: ParseLang): Result
   env = env or environment.new()
   env.defaults = env.defaults or {}
   env.defaults.feat_lax = parse_lang == "lua" and "on" or "off"
   local result = string_checker.check(env, input, filename)
   if result and result.ast then
      lua_compat.apply(result)
   end
   return result
end

v2.gen = function(input: string, env?: Env, opts?: GenerateOptions, parse_lang?: ParseLang): string, Result
   env = env or environment.new()
   env.defaults = env.defaults or {}
   env.defaults.feat_lax = parse_lang == "lua" and "on" or "off"
   local result = string_checker.check(env, input)

   if (not result.ast) or #result.syntax_errors > 0 then
      return nil, result
   end

   lua_compat.apply(result)

   local code = lua_generator.generate(result.ast, env.defaults.gen_target, opts)
   return code, result
end

v2.generate = function(ast: Node, gen_target: GenTarget, opts?: GenerateOptions): string, string
   return lua_generator.generate(ast as parser.Node, gen_target, opts)
end

v2.get_token_at = lexer.get_token_at

v2.lex = lexer.lex

v2.load = loader.load

v2.loader = package_loader.install_loader

local function predefine_modules(env: Env, predefined_modules: {string}): boolean, string
   for _, name in ipairs(predefined_modules) do
      local ok, err = environment.load_module(env, name)
      if not ok then
         return nil, err
      end
   end

   return true
end

v2.new_env = function(opts?: EnvOptions): Env, string
   local env, err = environment.new(opts and opts.defaults)
   if not env then
      return nil, err
   end

   if opts and opts.predefined_modules then
      local ok: boolean
      ok, err = predefine_modules(env, opts.predefined_modules)
      if not ok then
         return nil, err
      end
   end

   return env
end

v2.parse = function(input: string, filename: string, parse_lang?: ParseLang): Node, {Error}, {string}
   local ast, errs, required_modules = parser.parse(input, filename, parse_lang)
   return ast as v2.Node, errs, required_modules
end

v2.parse_program = function(tokens: {Token}, errs: {Error}, filename?: string, parse_lang?: ParseLang): Node, {string}
   local ast, required_modules = parser.parse_program(tokens, errs, filename, parse_lang)
   return ast as v2.Node, required_modules
end

v2.process = v2.check_file

v2.search_module = require_file.search_module

v2.symbols_in_scope = type_reporter.symbols_in_scope

v2.target_from_lua_version = lua_generator.target_from_lua_version

v2.version = function(): string
   return environment.VERSION
end

--------------------------------------------------------------------------------

return v2
