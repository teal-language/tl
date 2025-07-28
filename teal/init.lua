local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local check = require("teal.check.check")
local environment = require("teal.environment")

local errors = require("teal.errors")
local lexer = require("teal.lexer")
local loader = require("teal.loader")
local lua_compat = require("teal.gen.lua_compat")
local lua_generator = require("teal.gen.lua_generator")
local package_loader = require("teal.package_loader")
local parser = require("teal.parser")
local require_file = require("teal.check.require_file")
local targets = require("teal.gen.targets")

local util = require("teal.util")

local teal = { CheckError = {}, Compiler = {}, Input = {}, TokenList = {}, ParseTree = {}, Module = {}, CompilerOptions = {} }






















































































































local Compiler = teal.Compiler
local Module = teal.Module



local Input = teal.Input


local ParseTree = teal.ParseTree


local TokenList = teal.TokenList



local Compiler_mt = { __index = Compiler }
local Input_mt = { __index = Input }
local TokenList_mt = { __index = TokenList }
local ParseTree_mt = { __index = ParseTree }
local Module_mt = { __index = Module }

environment.set_require_module_fn(require_file.require_module)





local function module_from_result(result)
   local module = setmetatable({
      filename = result.filename,
      parse_tree = setmetatable({
         filename = result.filename,
         ast = result.ast,
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





function Compiler:input(teal_code, filename)
   if teal_code == nil then
      return nil, "missing Teal code as input"
   end
   return setmetatable({
      filename = filename or "<input>.tl",
      teal_code = teal_code,
      env = self.env,
   }, Input_mt)
end

function Compiler:open(filename)
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

function Compiler:require(module_name)
   local ok, err = environment.load_module(self.env, module_name)
   if not ok then
      return nil, nil, err
   end

   local filename = self.env.module_filenames[module_name]
   local result = self.env.loaded[filename]
   return module_from_result(result)
end

function Compiler:enable_type_reporting(enable)
   self.env.keep_going = enable
   self.env.report_types = enable
end

function Compiler:get_type_report()
   if not self.env.reporter then
      return nil
   end

   return self.env.reporter:get_report()
end

function Compiler:loaded_files()
   local i = 0
   return function()
      i = i + 1
      return self.env.loaded_order[i]
   end
end

function Compiler:recall(filename)
   local result = self.env.loaded[filename]
   if not result then
      return nil, nil
   end
   if result.ast then
      lua_compat.apply(result)
   end
   return module_from_result(result)
end





function Input:lex()
   local tokens, errs = lexer.lex(self.teal_code, self.filename)
   return setmetatable({
      filename = self.filename,
      tokens = tokens,
      lexical_errors = errs,
      env = self.env,
   }, TokenList_mt), errs
end

function Input:parse()
   local token_list = self:lex()
   return token_list:parse()
end

function Input:check(module_name)
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

function Input:gen(opts)
   local module, check_error = self:check()
   if #check_error.syntax_errors > 0 then
      return nil, module, check_error
   end
   local output = module:gen(opts)
   return output, module, check_error
end





function TokenList:get_token_at(line, column)
   return lexer.get_token_at(self.tokens, line, column)
end

function TokenList:parse()
   local errs = self.lexical_errors or {}
   local ast, required_modules = parser.parse_program(self.tokens, errs, self.filename)

   if #errs > 0 and not self.env.keep_going then
      environment.register_failed(self.env, self.filename, errs)
   end

   return setmetatable({
      filename = self.filename,
      required_modules = required_modules,
      ast = ast,
      env = self.env,
      syntax_errors = errs,
   }, ParseTree_mt), #errs > 0 and errs or nil
end





function ParseTree:check(module_name)
   if #self.syntax_errors > 0 and not self.env.keep_going then
      local result = self.env.loaded[self.filename]
      local _, check_err = module_from_result(result)
      return nil, check_err
   end

   local result = check.check(self.ast, self.env, self.filename)
   if result then
      result.syntax_errors = self.syntax_errors

      if result.ast then
         lua_compat.apply(result)
      end

      if module_name then
         self.env.modules[module_name] = result.type
         if module_name:match("%.init$") then
            module_name = module_name:sub(1, -6)
            self.env.modules[module_name] = result.type
         end
      end
   end

   return module_from_result(result)
end





function Module:gen(opts)
   return lua_generator.generate(self.parse_tree.ast, self.env.opts.gen_target, opts)
end





function teal.compiler(opts)
   local compiler = setmetatable({}, Compiler_mt)

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

function teal.search_module(module_name, extension_set)
   local found, _, tried = require_file.search_module(module_name, extension_set)
   if not found then
      return nil, tried
   end
   return found
end

teal.runtime_target = targets.detect

function teal.warning_set()
   local warning_set = {}
   for k, v in pairs(errors.warning_kinds) do
      warning_set[k] = v
   end
   return warning_set
end

function teal.version()
   return environment.VERSION
end

return teal
