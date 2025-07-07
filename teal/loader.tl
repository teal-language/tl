local package_loader = require("teal.package_loader")
local parser = require("teal.parser")
local lua_generator = require("teal.gen.lua_generator")
local check = require("teal.check.check")
local environment = require("teal.environment")
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
      return assert(package_loader.env)
   end

   if not loader.load_envs then
      loader.load_envs = setmetatable({}, { __mode = "k" })
   end

   loader.load_envs[env_tbl] = loader.load_envs[env_tbl] or environment.for_runtime()
   return loader.load_envs[env_tbl]
end

function loader.load(input: string, chunkname?: string, mode?: LoadMode, ...: {any:any}): LoadFunction, string
   local program, errs = parser.parse(input, chunkname)
   if #errs > 0 then
      return nil, (chunkname or "") .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg
   end

   if not package_loader.env then
      package_loader.env = environment.for_runtime()
   end

   local filename = chunkname or ("string \"" .. input:sub(45) .. (#input > 45 and "..." or "") .. "\"")
   local result = check.check(program as parser.Node, env_for(...), filename)

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

   local code = lua_generator.generate(program, package_loader.env.opts.gen_target, lua_generator.fast_opts)
   return load(code, chunkname, mode, ...)
end

return loader
