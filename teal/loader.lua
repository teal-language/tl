local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local load = _tl_compat and _tl_compat.load or load; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local package_loader = require("teal.package_loader")
local parser = require("teal.parser")

local lua_generator = require("teal.gen.lua_generator")
local check = require("teal.check.check")
local environment = require("teal.environment")


local loader = {}
















local function env_for(parse_lang, env_tbl)
   if not env_tbl then
      return assert(package_loader.env)
   end

   if not loader.load_envs then
      loader.load_envs = setmetatable({}, { __mode = "k" })
   end

   loader.load_envs[env_tbl] = loader.load_envs[env_tbl] or environment.for_runtime(parse_lang)
   return loader.load_envs[env_tbl]
end

function loader.load(input, chunkname, mode, ...)
   local parse_lang = parser.lang_heuristic(chunkname)
   local program, errs = parser.parse(input, chunkname, parse_lang)
   if #errs > 0 then
      return nil, (chunkname or "") .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg
   end

   if not package_loader.env then
      package_loader.env = environment.for_runtime(parse_lang)
   end
   local defaults = package_loader.env.defaults

   local filename = chunkname or ("string \"" .. input:sub(45) .. (#input > 45 and "..." or "") .. "\"")
   local result = check.check(program, filename, defaults, env_for(parse_lang, ...))

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

   local code, err = lua_generator.generate(program, defaults.gen_target, lua_generator.fast_opts)
   if not code then
      return nil, err
   end

   return load(code, chunkname, mode, ...)
end

return loader
