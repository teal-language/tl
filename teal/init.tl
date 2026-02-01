local type check = require("teal.check.check")
local type environment = require("teal.environment")
local type Env = environment.Env
local type errors = require("teal.errors")
local type lexer = require("teal.lexer")
local type loader = require("teal.loader")
local type lua_compat = require("teal.gen.lua_compat")
local type lua_generator = require("teal.gen.lua_generator")
local type package_loader = require("teal.package_loader")
local type parser = require("teal.parser")
local type require_file = require("teal.check.require_file")
local type targets = require("teal.gen.targets")
local type type_reporter = require("teal.type_reporter")
local type util = require("teal.util")

local record teal
   type Error = errors.Error
   type Extension = require_file.Extension
   type Feat = environment.Feat
   type GenCompat = environment.GenCompat
   type GenTarget = targets.GenTarget
   type GenOptions = lua_generator.Options
   type LoadFunction = loader.LoadFunction
   type LoadMode = loader.LoadMode
   type Token = lexer.Token
   type TokenKind = lexer.TokenKind
   type WarningKind = errors.WarningKind
   type TypeReport = type_reporter.TypeReport

   -- abstract type
   interface Node
   end

   ----------------------------------------
   -- Errors
   ----------------------------------------

   type LexError = {Error}
   type ParseError = {Error}
   type SearchError = {string}
   type RequireError = string

   record CheckError
      syntax_errors: {Error}
      type_errors: {Error}
      warnings: {Error}
   end

   ----------------------------------------
   -- Compiler pipeline
   ----------------------------------------

   record Compiler
      input: function(self, teal_code: string, filename?: string): Input, string
      open: function(self, filename: string): Input, string
      require: function(self, module_name: string): Module, CheckError, RequireError

      enable_type_reporting: function(self, enable: boolean)
      get_type_report: function(self): TypeReport

      loaded_files: function(self): (function(): string)
      recall: function(self, filename: string): Module, CheckError

      -- private:
      env: Env
   end

   record Input
      filename: string
      teal_code: string

      lex: function(self): TokenList, LexError
      parse: function(self): ParseTree, ParseError
      check: function(self, module_name?: string): Module, CheckError
      gen: function(self, opts?: GenOptions): string, Module, CheckError

      -- private:
      env: Env
   end

   record TokenList
      filename: string
      tokens: {Token}
      lexical_errors: LexError

      get_token_at: function(self, line: integer, column: integer): string
      parse: function(self): ParseTree, ParseError

      -- private:
      env: Env
   end

   record ParseTree
      filename: string
      ast: Node
      required_modules: {string}

      check: function(self, module_name?: string): Module, CheckError

      -- private:
      env: Env
      syntax_errors: ParseError
   end

   record Module
      filename: string
      parse_tree: ParseTree

      gen: function(self, opts?: GenOptions): string

      -- private:
      env: Env
   end

   ----------------------------------------
   -- Module functions
   ----------------------------------------

   record CompilerOptions
      feat_arity: Feat
      gen_compat: GenCompat
      gen_target: GenTarget
   end

   compiler: function(opts?: CompilerOptions): Compiler
   load: function(input: string, chunkname?: string, mode?: LoadMode, ...: {any:any}): LoadFunction, string
   loader: function()
   search_module: function(module_name: string, extension_set?: {Extension:boolean}): string, SearchError
   runtime_target: function(): GenTarget
   warning_set: function(): {WarningKind:boolean}
   version: function(): string
end

local type CompilerOptions = teal.CompilerOptions
local type Compiler = teal.Compiler
local type Module = teal.Module
local type CheckError = teal.CheckError
local type Extension = teal.Extension
local type GenOptions = teal.GenOptions
local type Input = teal.Input
local type LexError = teal.LexError
local type ParseError = teal.ParseError
local type ParseTree = teal.ParseTree
local type RequireError = teal.RequireError
local type SearchError = teal.SearchError
local type TokenList = teal.TokenList
local type TypeReport = teal.TypeReport
local type WarningKind = teal.WarningKind

local Compiler_mt: metatable<Compiler> = { __index = Compiler }
local Input_mt: metatable<Input> = { __index = Input }
local TokenList_mt: metatable<TokenList> = { __index = TokenList }
local ParseTree_mt: metatable<ParseTree> = { __index = ParseTree }
local Module_mt: metatable<Module> = { __index = Module }

environment.set_require_module_fn(require_file.require_module)

--------------------------------------------------------------------------------
-- Data type conversions
--------------------------------------------------------------------------------

local function module_from_result(result: environment.Result): Module, CheckError
   local module: Module = setmetatable({
      filename = result.filename,
      parse_tree = setmetatable({
         filename = result.filename,
         ast = result.ast as teal.Node,
         required_modules = util.sorted_keys(result.dependencies),
         syntax_errors = result.syntax_errors,
      }, ParseTree_mt),
      env = result.env,
   }, Module_mt)

   local check_error = {
      syntax_errors = result.syntax_errors or {},
      type_errors = result.type_errors or {},
      warnings = result.warnings or {},
   }

   return module, check_error
end

--------------------------------------------------------------------------------
-- Compiler
--------------------------------------------------------------------------------

function Compiler:input(teal_code: string, filename?: string): Input, string
   if teal_code is nil then
      return nil, "missing Teal code as input"
   end
   return setmetatable({
      filename = filename or "<input>.tl",
      teal_code = teal_code,
      env = self.env,
   }, Input_mt)
end

function Compiler:open(filename: string): Input, string
   local fd, err = io.open(filename, "rb")
   if not fd then
      return nil, "could not open " .. err
   end

   local teal_code, read_err = fd:read("*a")
   if not teal_code then
      return nil, "could not open " .. read_err
   end

   return self:input(teal_code, filename)
end

function Compiler:require(module_name: string): Module, CheckError, RequireError
   local ok, err = environment.load_module(self.env, module_name)
   if not ok then
      return nil, nil, err
   end

   local filename = self.env.module_filenames[module_name]
   local result = self.env.loaded[filename]
   return module_from_result(result)
end

function Compiler:enable_type_reporting(enable: boolean)
   self.env.keep_going = enable
   self.env.report_types = enable
end

function Compiler:get_type_report(): TypeReport
   if not self.env.reporter then
      return nil
   end

   return self.env.reporter:get_report()
end

function Compiler:loaded_files(): (function(): string)
   local i = 0
   return function(): string
      i = i + 1
      return self.env.loaded_order[i]
   end
end

function Compiler:recall(filename: string): Module, CheckError
   local result = self.env.loaded[filename]
   if not result then
      return nil, nil
   end
   if result.ast then
      lua_compat.apply(result)
   end
   return module_from_result(result)
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

function Input:lex(): TokenList, LexError
   local tokens, errs = lexer.lex(self.teal_code, self.filename)
   return setmetatable({
      filename = self.filename,
      tokens = tokens,
      lexical_errors = errs,
      env = self.env,
   }, TokenList_mt), errs
end

function Input:parse(): ParseTree, ParseError
   local token_list = self:lex()
   return token_list:parse()
end

function Input:check(module_name?: string): Module, CheckError
   local parse_tree, parse_error = self:parse()

   if parse_error and not self.env.keep_going then
      return nil, {
         syntax_errors = parse_error,
         type_errors = {},
         warnings = {},
      }
   end

   return parse_tree:check(module_name)
end

function Input:gen(opts?: GenOptions): string, Module, CheckError
   local module, check_error = self:check()
   if #check_error.syntax_errors > 0 then
      return nil, module, check_error
   end
   local output = module:gen(opts)
   return output, module, check_error
end

--------------------------------------------------------------------------------
-- TokenList
--------------------------------------------------------------------------------

function TokenList:get_token_at(line: integer, column: integer): string
   return lexer.get_token_at(self.tokens, line, column)
end

function TokenList:parse(): ParseTree, ParseError
   local errs = self.lexical_errors as {teal.Error} or {}
   local ast, required_modules = parser.parse_program(self.tokens, errs, self.filename)

   if #errs > 0 and not self.env.keep_going then
      environment.register_failed(self.env, self.filename, errs)
   end

   return setmetatable({
      filename = self.filename,
      required_modules = required_modules,
      ast = ast as teal.Node,
      env = self.env,
      syntax_errors = errs,
   }, ParseTree_mt), #errs > 0 and errs or nil
end

--------------------------------------------------------------------------------
-- ParseTree
--------------------------------------------------------------------------------

function ParseTree:check(module_name?: string): Module, CheckError
   if #self.syntax_errors > 0 and not self.env.keep_going then
      local result = self.env.loaded[self.filename]
      local _, check_err = module_from_result(result)
      return nil, check_err
   end

   local result = check.check(self.ast as parser.Node, self.env, self.filename)
   if result then
      result.syntax_errors = self.syntax_errors

      if result.ast then
         lua_compat.apply(result)
      end

      if module_name then
         self.env.modules[module_name] = result.type
         if module_name:match("%.init$") then
            module_name = module_name:sub(1, -6) -- remove trailing ".init"
            self.env.modules[module_name] = result.type
         end
      end
   end

   return module_from_result(result)
end

--------------------------------------------------------------------------------
-- Module
--------------------------------------------------------------------------------

function Module:gen(opts?: GenOptions): string
   return lua_generator.generate(self.parse_tree.ast as parser.Node, self.env.opts.gen_target, opts)
end

--------------------------------------------------------------------------------
-- Module functions
--------------------------------------------------------------------------------

function teal.compiler(opts?: CompilerOptions): Compiler
   local compiler: Compiler = setmetatable({}, Compiler_mt)

   local env_opts = {
      feat_arity = opts and opts.feat_arity,
      gen_compat = opts and opts.gen_compat,
      gen_target = opts and opts.gen_target,
   }

   compiler.env = environment.new(env_opts)

   return compiler
end

teal.load = loader.load

function teal.loader()
   package_loader.install_loader()
end

function teal.search_module(module_name: string, extension_set?: {Extension:boolean}): string, SearchError
   local found, _, tried = require_file.search_module(module_name, extension_set)
   if not found then
      return nil, tried
   end
   return found
end

teal.runtime_target = targets.detect

function teal.warning_set(): {WarningKind:boolean}
   local warning_set = {}
   for k, v in pairs(errors.warning_kinds) do
      warning_set[k] = v
   end
   return warning_set
end

function teal.version(): string
   return environment.VERSION
end

return teal
