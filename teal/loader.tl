local environment = require("teal.environment")
local lua_generator = require("teal.gen.lua_generator")
local package_loader = require("teal.package_loader")
local input = require("teal.input")
local type Env = environment.Env

local record loader
   enum LoadMode
      "b"
      "t"
      "bt"
      "cb"
      "ct"
      "cbt"
   end
   type LoadFunction = function(...:any): any...

   load_envs: { {any:any} : Env }
end

local type LoadMode = loader.LoadMode
local type LoadFunction = loader.LoadFunction

local function env_for(env_tbl: {any:any}): Env
   if not env_tbl then
      if not package_loader.env then
         package_loader.env = environment.for_runtime()
      end
      return assert(package_loader.env)
   end

   if not loader.load_envs then
      loader.load_envs = setmetatable({}, { __mode = "k" })
   end

   loader.load_envs[env_tbl] = loader.load_envs[env_tbl] or environment.for_runtime()
   return loader.load_envs[env_tbl]
end

function loader.load(teal_code: string, chunkname?: string, mode?: LoadMode, ...: {any:any}): LoadFunction, string
   local env = env_for(...)
   local filename = chunkname or ("string \"" .. teal_code:sub(45) .. (#teal_code > 45 and "..." or "") .. "\".tl")
   local result = input.check(env, filename, teal_code)

   local errs = result.syntax_errors
   if #errs > 0 then
      return nil, (chunkname or "") .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg
   end

   if mode and mode:match("c") then
      if #result.type_errors > 0 then
         local errout = {}
         for _, err in ipairs(result.type_errors) do
            table.insert(errout, err.filename .. ":" .. err.y .. ":" .. err.x .. ": " .. (err.msg or ""))
         end
         return nil, table.concat(errout, "\n")
      end

      mode = mode:gsub("c", "") as LoadMode
   end

   local lua_code = lua_generator.generate(result.ast, package_loader.env.opts.gen_target, lua_generator.fast_opts)

   return load(lua_code, chunkname, mode, ...)
end

return loader
