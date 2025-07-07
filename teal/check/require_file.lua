local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local os = _tl_compat and _tl_compat.os or os; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local file_checker = require("teal.check.file_checker")




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
      local filename = entry:gsub("?", slash_name)
      local tl_filename = filename:gsub("%.lua$", suffix)
      local fd = io.open(tl_filename, "rb")
      if fd then
         return tl_filename, fd, tried
      end
      table.insert(tried, "no file '" .. tl_filename .. "'")
   end
   return nil, nil, tried
end

function require_file.search_module(module_name, extension_set)
   local found
   local fd
   local tried = {}
   local path = os.getenv("TL_PATH") or package.path
   if extension_set and extension_set[".d.tl"] then
      found, fd, tried = search_for(module_name, ".d.tl", path, tried)
      if found then
         return found, fd
      end
   end
   if (not extension_set) or extension_set[".tl"] then
      found, fd, tried = search_for(module_name, ".tl", path, tried)
      if found then
         return found, fd
      end
   end
   if extension_set and extension_set[".lua"] then
      found, fd, tried = search_for(module_name, ".lua", path, tried)
      if found then
         return found, fd
      end
   end
   return nil, nil, tried
end

local function a_circular_require(w)
   return a_type(w, "typedecl", { def = a_type(w, "circular_require", {}) })
end

function require_file.require_module(env, w, module_name)
   local mod = env.modules[module_name]
   if mod then
      return mod, env.module_filenames[module_name]
   end

   local extensions = require_file.all_extensions
   local found, fd = require_file.search_module(module_name, extensions)
   if not found then
      return nil
   end

   env.module_filenames[module_name] = found
   env.modules[module_name] = a_circular_require(w)

   local found_result, err = file_checker.check(env, found, fd)
   assert(found_result, err)

   env.modules[module_name] = found_result.type

   return found_result.type, found
end

return require_file
