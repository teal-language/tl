local file_checker = require("teal.check.file_checker")

local type errors = require("teal.errors")
local type Where = errors.Where

local types = require("teal.types")
local type InvalidType = types.InvalidType
local type Type = types.Type
local type TypeDeclType = types.TypeDeclType
local a_type = types.a_type

local type environment = require("teal.environment")
local type Env = environment.Env
local type Result = environment.Result

local record require_file
end

local function search_for(module_name: string, suffix: string, path: string, tried: {string}): string, FILE, {string}
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

function require_file.search_module(module_name: string, search_all: boolean): string, FILE, {string}
   local found: string
   local fd: FILE
   local tried: {string} = {}
   local path = os.getenv("TL_PATH") or package.path -- FIXME tl.path
   if search_all then
      found, fd, tried = search_for(module_name, ".d.tl", path, tried)
      if found then
         return found, fd
      end
   end
   found, fd, tried = search_for(module_name, ".tl", path, tried)
   if found then
      return found, fd
   end
   if search_all then
      found, fd, tried = search_for(module_name, ".lua", path, tried)
      if found then
         return found, fd
      end
   end
   return nil, nil, tried
end

local function a_circular_require(w: Where): TypeDeclType
   return a_type(w, "typedecl", { def = a_type(w, "circular_require", {}) } as TypeDeclType)
end

function require_file.require_module(env: Env, w: Where, module_name: string): Type, string
   local mod = env.modules[module_name]
   if mod then
      return mod, env.module_filenames[module_name]
   end

   local found, fd = require_file.search_module(module_name, true)
   if found and (env.opts.feat_lax == "on" or found:match("tl$") as boolean) then

      env.module_filenames[module_name] = found
      env.modules[module_name] = a_circular_require(w)

      local found_result, err: Result, string = file_checker.check(env, found, fd)
      assert(found_result, err)

      env.modules[module_name] = found_result.type

      return found_result.type, found
   elseif fd then
      fd:close()
   end

   return a_type(w, "invalid", {} as InvalidType), found
end

return require_file
