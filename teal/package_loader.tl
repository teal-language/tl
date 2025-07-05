local environment = require("teal.environment")
local type Env = environment.Env

local require_file = require("teal.check.require_file")
local search_module = require_file.search_module

local lua_generator = require("teal.gen.lua_generator")

local parser = require("teal.parser")

local types = require("teal.types")
local type TypeDeclType = types.TypeDeclType
local a_type = types.a_type

local check = require("teal.check.check")

local util = require("teal.util")
local read_file_skipping_bom = util.read_file_skipping_bom

local record package_loader
   env: Env
end

local function tl_package_loader(module_name: string): any, any
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

      local w = { f = found_filename, x = 1, y = 1 }
      env.modules[module_name] = a_type(w, "typedecl", { def = a_type(w, "circular_require", {}) } as TypeDeclType)

      local result = check.check(program as parser.Node, env, found_filename)

      env.modules[module_name] = result.type

      -- TODO: should this be a hard error? this seems analogous to
      -- finding a lua file with a syntax error in it
      local code = assert(lua_generator.generate(program, env.opts.gen_target, lua_generator.fast_opts))
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

function package_loader.install_loader()
   if package.searchers then
      table.insert(package.searchers, 2, tl_package_loader)
   else
      table.insert(package.loaders, 2, tl_package_loader)
   end
end

return package_loader
