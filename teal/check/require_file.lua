local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local os = _tl_compat and _tl_compat.os or os; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local input = require("teal.input")




local types = require("teal.types")


local a_type = types.a_type





local require_file = {}











require_file.all_extensions = {
   [".d.tl"] = true,
   [".tl"] = true,
   [".lua"] = true,
}

local function search_for(module_name, suffix, path, tried)
   for entry in path:gmatch("[^;]+") do
      local slash_name = module_name:gsub("%.", "/")


      if not entry:match("%?[/\\]init%.lua$") then
         local filename = entry:gsub("?", slash_name)
         local tl_filename = filename:gsub("%.lua$", suffix)
         local fd = io.open(tl_filename, "rb")
         if not fd then
            table.insert(tried, "no file '" .. tl_filename .. "'")


            tl_filename = filename:gsub("%.lua$", "/init" .. suffix)
            fd = io.open(tl_filename, "rb")
            if not fd then
               table.insert(tried, "no file '" .. tl_filename .. "'")
            end
         end

         if fd then
            local code = fd:read("*a")
            if not code then
               return nil, nil, tried
            end
            fd:close()
            return tl_filename, code, tried
         end
      end
   end
   return nil, nil, tried
end

function require_file.search_module(module_name, extension_set)
   local found
   local code
   local tried = {}
   local path = os.getenv("TL_PATH") or package.path

   if extension_set and extension_set[".d.tl"] then
      found, code, tried = search_for(module_name, ".d.tl", path, tried)
      if found then
         return found, code
      end
   end
   if (not extension_set) or extension_set[".tl"] then
      found, code, tried = search_for(module_name, ".tl", path, tried)
      if found then
         return found, code
      end
   end
   if extension_set and extension_set[".lua"] then
      found, code, tried = search_for(module_name, ".lua", path, tried)
      if found then
         return found, code
      end
   end
   return nil, nil, tried
end

local function a_circular_require(w)
   return a_type(w, "typedecl", { def = a_type(w, "circular_require", {}) })
end

function require_file.search_and_load(env, module_name, extension_set)
   local found, code, tried = require_file.search_module(module_name, extension_set)
   if not found then
      return nil, nil, tried
   end

   env.module_filenames[module_name] = found

   local w = { f = found, x = 1, y = 1 }
   env.modules[module_name] = a_circular_require(w)

   local found_result = input.check(env, found, code)
   if not found_result then
      return nil, nil, tried
   end

   env.modules[module_name] = found_result.type

   return found_result, found
end

function require_file.require_module(env, module_name)
   local mod = env.modules[module_name]
   if mod then
      return mod, env.module_filenames[module_name]
   end

   local extensions = require_file.all_extensions
   local found_result, found = require_file.search_and_load(env, module_name, extensions)
   if not found_result then
      return nil
   end

   return found_result.type, found
end

return require_file
