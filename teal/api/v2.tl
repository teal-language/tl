local type check = require("teal.check.check")
local type environment = require("teal.environment")
local type errors = require("teal.errors")
local type lexer = require("teal.lexer")
local type loader = require("teal.loader")
local type lua_generator = require("teal.gen.lua_generator")
local type lua_compat = require("teal.gen.lua_compat")
local type package_loader = require("teal.package_loader")
local type parser = require("teal.parser")
local type require_file = require("teal.check.require_file")
local type input = require("teal.input")
local type targets = require("teal.gen.targets")
local type type_errors = require("teal.type_errors")
local type type_reporter = require("teal.type_reporter")

--------------------------------------------------------------------------------
-- Public API v2 (0.24.x)
--------------------------------------------------------------------------------

local record v2
   type Env = environment.Env
   type Error = errors.Error
   type Feat = environment.Feat
   type GenCompat = environment.GenCompat
   type GenerateOptions = lua_generator.Options
   type GenTarget = targets.GenTarget
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

   record CheckOptions
      feat_lax: Feat
      feat_arity: Feat
      gen_compat: GenCompat
      gen_target: GenTarget
   end

   record EnvOptions
      defaults: CheckOptions
      predefined_modules: {string}
   end

   -- abstract type
   interface Node
   end

   check_file: function(filename: string, env?: Env, fd?: FILE): (Result, string)
   check: function(Node, ? string, ? CheckOptions, ? Env): Result, string
   check_string: function(teal_code: string, env?: Env, filename?: string, parse_lang?: ParseLang): Result
   generate: function(ast: Node, gen_target: GenTarget, opts?: GenerateOptions): string, string
   gen: function(string, ? Env, ? GenerateOptions): string, Result
   get_token_at: function(tks: {Token}, y: integer, x: integer): string
   lex: function(teal_code: string, filename: string): {Token}, {Error}
   loader: function()
   load: function(string, ? string, ? LoadMode, ...: {any:any}): LoadFunction, string
   new_env: function(? EnvOptions): Env, string
   parse: function(teal_code: string, filename: string, parse_lang?: ParseLang): Node, {Error}, {string}
   parse_program: function(tokens: {Token}, errs: {Error}, filename?: string, parse_lang?: ParseLang): Node, {string}
   process: function(filename: string, env?: Env, fd?: FILE): (Result, string)
   search_module: function(module_name: string, search_all: boolean): string, FILE, {string}
   symbols_in_scope: function(tr: TypeReport, y: integer, x: integer, filename: string): {string:integer}
   target_from_lua_version: function(str: string): GenTarget
   version: function(): string
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
local type TypeReport = v2.TypeReport

--------------------------------------------------------------------------------
-- Functions
--------------------------------------------------------------------------------

local function env_from_check_options(opts?: CheckOptions): Env
   return environment.new(opts and {
      feat_arity = opts.feat_arity,
      gen_compat = opts.gen_compat,
      gen_target = opts.gen_target,
   })
end

v2.check = function(ast: Node, filename?: string, opts?: CheckOptions, env?: Env): Result, string
   if opts and opts.gen_target == "5.4" and opts.gen_compat ~= "off" then
      return nil, "gen-compat must be explicitly 'off' when gen-target is '5.4'"
   end

   if opts and env then
      -- If both opts and env are given in the old-style v2 API,
      -- they must match. We support the v2 API syntactically,
      -- but we no longer support the ability to override the
      -- environment setting via opts. This was always somewhat
      -- inconsistent, and it seems like ther was no real-world usage
      -- of this ability. So it's better to clean up the internals
      -- of the codebase, and explicitly check for any attempts
      -- to do that here. Also, `feat_lax` is ignored and lax
      -- mode detection is solely based on the filename extension,
      -- as this is the behavior exposed by the `tl` CLI anyway.
      if opts.feat_arity and env.opts.feat_arity and opts.feat_arity ~= env.opts.feat_arity then
         return nil, "opts.feat_arity does not match environment setting"
      end
      if opts.gen_compat and env.opts.gen_compat and opts.gen_compat ~= env.opts.gen_compat then
         return nil, "opts.gen_compat does not match environment setting"
      end
      if opts.gen_target and env.opts.gen_target and opts.gen_target ~= env.opts.gen_target then
         return nil, "opts.gen_target does not match environment setting"
      end
   elseif opts or not env then
      env = env_from_check_options(opts)
   end

   local result = check.check(ast as parser.Node, env, filename or "<input>.tl")
   if result and result.ast then
      lua_compat.apply(result)
   end
   return result
end

v2.check_file = function(filename: string, env?: Env, fd?: FILE): (Result, string)
   env = env or environment.new()
   local err: string
   if not fd then
      fd, err = io.open(filename, "rb")
      if not fd then
         return nil, err
      end
   end
   local code: string
   code, err = fd:read("*a")
   if not code then
      return nil, err
   end
   local result = input.check(env, filename, code)
   if result.ast then
      lua_compat.apply(result)
   end
   return result
end

v2.check_string = function(teal_code: string, env?: Env, filename?: string, parse_lang?: ParseLang): Result
   env = env or environment.new()
   if not filename then
      filename = parse_lang == "lua" and "<input>.lua" or "<input>.tl"
   end
   local result = input.check(env, filename, teal_code)
   if result and result.ast then
      lua_compat.apply(result)
   end
   return result
end

v2.gen = function(teal_code: string, env?: Env, opts?: GenerateOptions, parse_lang?: ParseLang): string, Result
   env = env or environment.new()
   local filename = parse_lang == "lua" and "<input>.lua" or "<input>.tl"
   local result = input.check(env, filename, teal_code)
   if (not result.ast) or #result.syntax_errors > 0 then
      return nil, result
   end
   lua_compat.apply(result)
   local code = lua_generator.generate(result.ast, env.opts.gen_target, opts)
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
      local ok = environment.load_module(env, name)
      if not ok then
         return nil, "Error: could not predefine module '" .. name .. "'"
      end
   end

   return true
end

v2.new_env = function(opts?: EnvOptions): Env, string
   local env = env_from_check_options(opts and opts.defaults)

   if opts and opts.predefined_modules then
      local ok, err = predefine_modules(env, opts.predefined_modules)
      if not ok then
         return nil, err
      end
   end

   return env
end

v2.parse = function(teal_code: string, filename: string, _parse_lang?: ParseLang): Node, {Error}, {string}
   local ast, errs, required_modules = parser.parse(teal_code, filename)
   return ast as v2.Node, errs, required_modules
end

v2.parse_program = function(tokens: {Token}, errs: {Error}, filename?: string, parse_lang?: ParseLang): Node, {string}
   local ast, required_modules = parser.parse_program(tokens, errs, filename, parse_lang)
   return ast as v2.Node, required_modules
end

v2.process = v2.check_file

v2.search_module = function(module_name: string, search_all: boolean): string, FILE, {string}
   local found, _, tried = require_file.search_module(module_name, search_all and require_file.all_extensions)
   if found then
      return found, (io.open(found)), nil
   end
   return nil, nil, tried
end

v2.symbols_in_scope = function(tr: TypeReport, y: integer, x: integer, filename: string): {string:integer}
   return tr:symbols_in_scope(filename, y, x)
end

v2.target_from_lua_version = targets.detect

v2.version = function(): string
   return environment.VERSION
end

--------------------------------------------------------------------------------

return v2
