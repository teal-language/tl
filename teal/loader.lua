local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local load = _tl_compat and _tl_compat.load or load; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local environment = require("teal.environment")
local lua_generator = require("teal.gen.lua_generator")
local package_loader = require("teal.package_loader")
local input = require("teal.input")


local loader = {}
















local function env_for(env_tbl)
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

function loader.load(teal_code, chunkname, mode, ...)
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

      mode = mode:gsub("c", "")
   end

   local lua_code = lua_generator.generate(result.ast, package_loader.env.opts.gen_target, lua_generator.fast_opts)

   return load(lua_code, chunkname, mode, ...)
end

return loader
