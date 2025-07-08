local environment = require("teal.environment")
local type Env = environment.Env

local require_file = require("teal.check.require_file")
local search_module = require_file.search_module

local file_input = require("teal.input.file_input")

local lua_generator = require("teal.gen.lua_generator")

local types = require("teal.types")
local type TypeDeclType = types.TypeDeclType
local a_type = types.a_type

local record package_loader
   env: Env
end

local function tl_package_loader(module_name: string): any, any
   local found_filename, fd, tried = search_module(module_name)
   if not found_filename then
      return table.concat(tried, "\n\t")
   end

   local env = package_loader.env
   if not env then
      package_loader.env = environment.for_runtime()
      env = package_loader.env
   end

   local w = { f = found_filename, x = 1, y = 1 }
   env.modules[module_name] = a_type(w, "typedecl", { def = a_type(w, "circular_require", {}) } as TypeDeclType)

   local result, input_err = file_input.check(env, found_filename, fd)
   if input_err then
      return table.concat(tried, "\n\t")
   end

   local errs = result.syntax_errors
   if #errs > 0 then
      error(found_filename .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg)
   end

   env.modules[module_name] = result.type

   -- TODO: should this be a hard error? this seems analogous to
   -- finding a lua file with a syntax error in it
   local code = assert(lua_generator.generate(result.ast, env.opts.gen_target, lua_generator.fast_opts))
   local chunk, err = load(code, "@" .. found_filename, "t")
   if not chunk then
      error("Internal Compiler Error: Teal generator produced invalid Lua. Please report a bug at https://github.com/teal-language/tl\n\n" .. err)
   end

   return function(modname: string, loader_data: string): any
      if loader_data == nil then
         loader_data = found_filename
      end
      local ret = chunk(modname, loader_data)
      return ret
   end, found_filename
end

function package_loader.install_loader()
   local searchers = package.searchers or package.loaders
   table.insert(searchers, 2, tl_package_loader)
end

return package_loader
