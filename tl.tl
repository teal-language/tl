
local VERSION = "0.24.7+dev"

local errors = require("teal.errors")

local file_checker = require("teal.checker.file_checker")

local lexer = require("teal.lexer")

local types = require("teal.types")
local type TypeDeclType = types.TypeDeclType
local a_type = types.a_type

local parser = require("teal.parser")
local type Node = parser.Node
local type ParseLang = parser.ParseLang

local lua_generator = require("teal.gen.lua_generator")

local require_file = require("teal.checker.require_file")

local string_checker = require("teal.checker.string_checker")

local type_checker = require("teal.checker.type_checker")

local type_reporter = require("teal.type_reporter")
local type TypeReporter = type_reporter.TypeReporter
local type TypeReport = type_reporter.TypeReport

local util = require("teal.util")
local read_file_skipping_bom = util.read_file_skipping_bom

local environment = require("teal.environment")
local type CheckOptions = environment.CheckOptions
local type Env = environment.Env
local type Feat = environment.Feat
local type GenCompat = environment.GenCompat
local type Result = environment.Result

local record tl
   enum LoadMode
      "b"
      "t"
      "bt"
      "cb"
      "ct"
      "cbt"
   end
   type LoadFunction = function(...:any): any...

   record EnvOptions
      defaults: CheckOptions
      predefined_modules: {string}
   end

   -- abstract type
   type Node = types.Node

   type GenCompat = environment.GenCompat
   type Feat = environment.Feat
   type CheckOptions = environment.CheckOptions
   type Env = environment.Env
   type Result = environment.Result

   -----------------------------------------------------------------------------
   -- Re-exported entries
   -----------------------------------------------------------------------------

   type WarningKind = errors.WarningKind
   warning_kinds: {WarningKind:boolean}
   type Error = errors.Error
   type TokenKind = lexer.TokenKind
   type Comment = lexer.Comment
   type Token = lexer.Token
   type GenerateOptions = lua_generator.Options
   type GenTarget = lua_generator.Target

   -----------------------------------------------------------------------------
   -- Public API
   -----------------------------------------------------------------------------

   check: function(Node, ? string, ? CheckOptions, ? Env): Result, string
   gen: function(string, ? Env, ? GenerateOptions): string, Result
   generate: function(ast: Node, gen_target: GenTarget, opts?: GenerateOptions): string, string
   get_token_at: function(tks: {Token}, y: integer, x: integer): string
   lex: function(input: string, filename: string): {Token}, {Error}
   load: function(string, ? string, ? LoadMode, ...: {any:any}): LoadFunction, string
   loader: function()
   new_env: function(? EnvOptions): Env, string
   parse: function(input: string, filename: string, parse_lang?: ParseLang): Node, {Error}, {string}
   parse_program: function(tokens: {Token}, errs: {Error}, filename?: string, parse_lang?: ParseLang): Node, {string}
   check_file: function(filename: string, env?: Env, fd?: FILE): (Result, string)
   check_string: function(input: string, env?: Env, filename?: string, parse_lang?: ParseLang): Result
   search_module: function(module_name: string, search_all: boolean): string, FILE, {string}
   symbols_in_scope: function(tr: TypeReport, y: integer, x: integer, filename: string): {string:integer}
   target_from_lua_version: function(str: string): GenTarget
   version: function(): string

   path: string -- if set be the user, this overrides package.path for Teal

   -----------------------------------------------------------------------------
   -- Deprecated, mantained for backwards compatibility:
   -----------------------------------------------------------------------------

   type CompatMode = GenCompat
   type PrettyPrintOptions = GenerateOptions
   type TargetMode = GenTarget

   record TypeCheckOptions
      lax: boolean
      filename: string
      module_name: string
      gen_compat: tl.CompatMode
      gen_target: tl.TargetMode
      env: Env
      run_internal_compiler_checks: boolean
   end

   init_env: function(? boolean, ? boolean | tl.CompatMode, ? tl.TargetMode, ? {string}): Env, string
   pretty_print_ast: function(ast: Node, gen_target?: tl.TargetMode, mode?: boolean | tl.PrettyPrintOptions): string, string
   process: function(filename: string, env?: Env, fd?: FILE): Result, string
   process_string: function(input: string, is_lua: boolean, env: Env, filename: string, _module_name: string): Result
   type_check: function(Node, TypeCheckOptions): Result, string

   -----------------------------------------------------------------------------
   -- Private data:
   -----------------------------------------------------------------------------

   package_loader_env: Env
   load_envs: { {any:any} : Env }
end

tl.check = type_checker.check
tl.search_module = require_file.search_module
tl.warning_kinds = errors.warning_kinds
tl.lex = lexer.lex
tl.generate = lua_generator.generate
tl.get_token_at = lexer.get_token_at
tl.parse = parser.parse
tl.parse_program = parser.parse_program
tl.symbols_in_scope = type_reporter.symbols_in_scope
tl.target_from_lua_version = lua_generator.target_from_lua_version

environment.set_require_module_fn(require_file.require_module)

local type EnvOptions = tl.EnvOptions
local type GenTarget = tl.GenTarget
local type LoadFunction = tl.LoadFunction
local type LoadMode = tl.LoadMode
local type GenerateOptions = tl.GenerateOptions


--------------------------------------------------------------------------------
-- High-level API
--------------------------------------------------------------------------------

tl.check_file = function(filename: string, env?: Env, fd?: FILE): (Result, string)
   env = env or environment.new()
   return file_checker.check(env, filename, fd)
end

tl.check_string = function(input: string, env?: Env, filename?: string, parse_lang?: ParseLang): Result
   env = env or environment.new()
   env.defaults.feat_lax = parse_lang == "lua" and "on" or "off"
   return string_checker.check(env, input, filename)
end

tl.new_env = function(opts: EnvOptions): Env, string
   local env, err = environment.new(opts and opts.defaults)
   if not env then
      return nil, err
   end

   if opts.predefined_modules then
      local ok: boolean
      ok, err = environment.predefine(env, opts.predefined_modules)
      if not ok then
         return nil, err
      end
   end

   return env
end

tl.gen = function(input: string, env?: Env, opts?: GenerateOptions, parse_lang?: ParseLang): string, Result
   env = env or environment.new()
   env.defaults.feat_lax = parse_lang == "lua" and "on" or "off"
   local result = string_checker.check(env, input)

   if (not result.ast) or #result.syntax_errors > 0 then
      return nil, result
   end

   local code: string
   code, result.gen_error = lua_generator.generate(result.ast, env.defaults.gen_target, opts)
   return code, result
end

local function tl_package_loader(module_name: string): any, any
   local found_filename, fd, tried = tl.search_module(module_name, false)
   if found_filename then
      local parse_lang = parser.lang_heuristic(found_filename)
      local input = read_file_skipping_bom(fd)
      if not input then
         return table.concat(tried, "\n\t")
      end
      fd:close()
      local program, errs = tl.parse(input, found_filename, parse_lang)
      if #errs > 0 then
         error(found_filename .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg)
      end

      local env = tl.package_loader_env
      if not env then
         tl.package_loader_env = assert(environment.for_runtime(parse_lang), "Default environment initialization failed")
         env = tl.package_loader_env
      end
      local defaults = env.defaults

      local w = { f = found_filename, x = 1, y = 1 }
      env.modules[module_name] = a_type(w, "typedecl", { def = a_type(w, "circular_require", {}) } as TypeDeclType)

      local result = tl.check(program, found_filename, defaults, env)

      env.modules[module_name] = result.type

      -- TODO: should this be a hard error? this seems analogous to
      -- finding a lua file with a syntax error in it
      local code = assert(tl.generate(program, defaults.gen_target, lua_generator.fast_opts))
      local chunk, err = load(code, "@" .. found_filename, "t")
      if chunk then
         return function(modname: string, loader_data: string): any
            if loader_data == nil then
               loader_data = found_filename
            end
            local ret = chunk(modname, loader_data)
            return ret
         end, found_filename
      else
         error("Internal Compiler Error: Teal generator produced invalid Lua. Please report a bug at https://github.com/teal-language/tl\n\n" .. err)
      end
   end
   return table.concat(tried, "\n\t")
end

function tl.loader()
   if package.searchers then
      table.insert(package.searchers, 2, tl_package_loader)
   else
      table.insert(package.loaders, 2, tl_package_loader)
   end
end

local function env_for(parse_lang: ParseLang, env_tbl: {any:any}): Env
   if not env_tbl then
      return assert(tl.package_loader_env)
   end

   if not tl.load_envs then
      tl.load_envs = setmetatable({}, { __mode = "k" })
   end

   tl.load_envs[env_tbl] = tl.load_envs[env_tbl] or environment.for_runtime(parse_lang)
   return tl.load_envs[env_tbl]
end

tl.load = function(input: string, chunkname?: string, mode?: LoadMode, ...: {any:any}): LoadFunction, string
   local parse_lang = parser.lang_heuristic(chunkname)
   local program, errs = tl.parse(input, chunkname, parse_lang)
   if #errs > 0 then
      return nil, (chunkname or "") .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg
   end

   if not tl.package_loader_env then
      tl.package_loader_env = environment.for_runtime(parse_lang)
   end
   local defaults = tl.package_loader_env.defaults

   local filename = chunkname or ("string \"" .. input:sub(45) .. (#input > 45 and "..." or "") .. "\"")
   local result = tl.check(program, filename, defaults, env_for(parse_lang, ...))

   if mode and mode:match("c") then
      if #result.type_errors > 0 then
         local errout = {}
         for _, err in ipairs(result.type_errors) do
            table.insert(errout, err.filename .. ":" .. err.y .. ":" .. err.x .. ": " .. (err.msg or ""))
         end
         return nil, table.concat(errout, "\n")
      end

      mode = mode:gsub("c", "") as LoadMode
   end

   local code, err = lua_generator.generate(program, defaults.gen_target, lua_generator.fast_opts)
   if not code then
      return nil, err
   end

   return load(code, chunkname, mode, ...)
end

tl.version = function(): string
   return VERSION
end

--------------------------------------------------------------------------------
-- Backwards compatibility
--------------------------------------------------------------------------------

function tl.get_types(result: Result): TypeReport, TypeReporter
   return result.env.reporter:get_report(), result.env.reporter
end

tl.init_env = function(lax?: boolean, gen_compat?: boolean | GenCompat, gen_target?: GenTarget, predefined?: {string}): Env, string
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

   return tl.new_env(opts)
end

tl.type_check = function(ast: Node, tc_opts?: tl.TypeCheckOptions): Result, string
   local opts: CheckOptions = {
      feat_lax = tc_opts.lax and "on" or "off",
      feat_arity = tc_opts.env and tc_opts.env.defaults.feat_arity or "on",
      gen_compat = tc_opts.gen_compat,
      gen_target = tc_opts.gen_target,
      run_internal_compiler_checks = tc_opts.run_internal_compiler_checks,
   }
   return tl.check(ast, tc_opts.filename, opts, tc_opts.env)
end

tl.pretty_print_ast = function(ast: Node, gen_target?: tl.TargetMode, mode?: boolean | tl.PrettyPrintOptions): string, string
   local opts: GenerateOptions
   if mode is tl.PrettyPrintOptions then
      opts = mode
   elseif mode == true then
      opts = lua_generator.fast_opts
   else
      opts = lua_generator.default_opts
   end

   return lua_generator.generate(ast, gen_target, opts)
end

tl.process = function(filename: string, env?: Env, fd?: FILE): Result, string
   return tl.check_file(filename, env, fd)
end

tl.process_string = function(input: string, is_lua: boolean, env: Env, filename: string, _module_name: string): Result
   return tl.check_string(input, env or tl.init_env(is_lua), filename)
end

return tl
