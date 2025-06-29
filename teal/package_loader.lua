local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local load = _tl_compat and _tl_compat.load or load; local package = _tl_compat and _tl_compat.package or package; local table = _tl_compat and _tl_compat.table or table; local environment = require("teal.environment")


local require_file = require("teal.checker.require_file")
local search_module = require_file.search_module

local lua_generator = require("teal.gen.lua_generator")

local parser = require("teal.parser")

local types = require("teal.types")

local a_type = types.a_type

local visitors = require("teal.checker.visitors")

local util = require("teal.util")
local read_file_skipping_bom = util.read_file_skipping_bom

local package_loader = {}



local function tl_package_loader(module_name)
   local found_filename, fd, tried = search_module(module_name, false)
   if found_filename then
      local parse_lang = parser.lang_heuristic(found_filename)
      local input = read_file_skipping_bom(fd)
      if not input then
         return table.concat(tried, "\n\t")
      end
      fd:close()
      local program, errs = parser.parse(input, found_filename, parse_lang)
      if #errs > 0 then
         error(found_filename .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg)
      end

      local env = package_loader.env
      if not env then
         package_loader.env = assert(environment.for_runtime(parse_lang), "Default environment initialization failed")
         env = package_loader.env
      end
      local defaults = env.defaults

      local w = { f = found_filename, x = 1, y = 1 }
      env.modules[module_name] = a_type(w, "typedecl", { def = a_type(w, "circular_require", {}) })

      local result = visitors.check(program, found_filename, defaults, env)

      env.modules[module_name] = result.type



      local code = assert(lua_generator.generate(program, defaults.gen_target, lua_generator.fast_opts))
      local chunk, err = load(code, "@" .. found_filename, "t")
      if chunk then
         return function(modname, loader_data)
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

function package_loader.install_loader()
   if package.searchers then
      table.insert(package.searchers, 2, tl_package_loader)
   else
      table.insert(package.loaders, 2, tl_package_loader)
   end
end

return package_loader
