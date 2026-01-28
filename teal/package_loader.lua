local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local load = _tl_compat and _tl_compat.load or load; local package = _tl_compat and _tl_compat.package or package; local table = _tl_compat and _tl_compat.table or table; local environment = require("teal.environment")


local require_file = require("teal.check.require_file")

local lua_generator = require("teal.gen.lua_generator")

local package_loader = {}



local function tl_package_loader(module_name)
   local env = package_loader.env
   if not env then
      package_loader.env = environment.for_runtime()
      env = package_loader.env
   end

   local result, found_filename, tried = require_file.search_and_load(env, module_name)
   if not found_filename then
      return table.concat(tried, "\n\t")
   end

   local errs = result.syntax_errors
   if #errs > 0 then
      error(found_filename .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg)
   end



   local code = assert(lua_generator.generate(result.ast, env.opts.gen_target, lua_generator.fast_opts))
   local chunk, err = load(code, "@" .. found_filename, "t")
   if not chunk then
      error("Internal Compiler Error: Teal generator produced invalid Lua. Please report a bug at https://github.com/teal-language/tl\n\n" .. err)
   end

   return function(modname, loader_data)
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
