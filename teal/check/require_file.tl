local input = require("teal.input")

local type errors = require("teal.errors")
local type Where = errors.Where

local types = require("teal.types")
local type Type = types.Type
local type TypeDeclType = types.TypeDeclType
local a_type = types.a_type

local type environment = require("teal.environment")
local type Env = environment.Env
local type Result = environment.Result

local record require_file
   enum Extension
      ".d.tl"
      ".tl"
      ".lua"
   end

   all_extensions: {Extension:boolean}
end

local type Extension = require_file.Extension

require_file.all_extensions = {
   [".d.tl"] = true,
   [".tl"] = true,
   [".lua"] = true,
}

local function search_for(module_name: string, suffix: string, path: string, tried: {string}): string, string, {string}
   for entry in path:gmatch("[^;]+") do
      local slash_name = module_name:gsub("%.", "/")

      -- skip the `init.lua` entries from the path; we handle them ourselves
      if not entry:match("%?[/\\]init%.lua$") then
         local filename = entry:gsub("?", slash_name)
         local tl_filename = filename:gsub("%.lua$", suffix)
         local fd = io.open(tl_filename, "rb")
         if not fd then
            table.insert(tried, "no file '" .. tl_filename .. "'")

            -- if the plain entry wasn't found, try the `init` entry
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

function require_file.search_module(module_name: string, extension_set?: {Extension:boolean}): string, string, {string}
   local found: string
   local code: string
   local tried: {string} = {}
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

local function a_circular_require(w: Where): TypeDeclType
   return a_type(w, "typedecl", { def = a_type(w, "circular_require", {}) } as TypeDeclType)
end

function require_file.search_and_load(env: Env, module_name: string, extension_set?: {Extension:boolean}): Result, string, {string}
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

function require_file.require_module(env: Env, module_name: string): Type, string
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
