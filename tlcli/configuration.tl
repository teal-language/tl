local type Args = require("tlcli.args")
local type TlConfig = require("tlcli.tlconfig")
local common = require("tlcli.common")
local teal = require("teal.init")

local warning_set = teal.warning_set()

local record configuration
end

local function find_file_in_parent_dirs(fname: string): string
   for _ = 1, 20 do
      local fd = io.open(fname, "rb")
      if fd then
         fd:close()
         return fname
      end
      fname = ".." .. common.sep .. fname
   end
end

local function find_in_sequence<A>(seq: {A}, value: A): boolean
   for _, v in ipairs(seq) do
      if v == value then
         return true
      end
   end
   return false
end

local function prepend_to_lua_paths(directory: string)
   local path_str = directory
   local shared_library_ext = package.cpath:match("%.(%w+)%s*$") or "so"

   if string.sub(path_str, -1) == common.sep then
      path_str = path_str:sub(1, -2)
   end

   path_str = path_str .. common.sep

   local lib_path_str = path_str .. "?." .. shared_library_ext .. ";"
   local lua_path_str = path_str .. "?.lua;" .. path_str .. "?/init.lua;"

   package.path = lua_path_str .. package.path
   package.cpath = lib_path_str .. package.cpath
end

local function validate_config(config: {any:any}): TlConfig, {string}, {string}
   local errs, warnings = {}, {}

   local function warn(k: string, fmt: string, ...)
      table.insert(warnings, string.format("* in key \"" .. k .. "\": " .. fmt, ...))
   end
   local function fail(k: string, fmt: string, ...)
      table.insert(errs, string.format("* in key \"" .. k .. "\": " .. fmt, ...))
   end

   local function check_warnings(key: string)
      local ck = config[key]
      if ck is {string} then
         local unknown = {}
         for _, warning in ipairs(ck) do
            if not warning_set[warning as teal.WarningKind] then
               table.insert(unknown, string.format("%q", warning))
            end
         end
         if #unknown > 0 then
            warn(key, "Unknown warning%s in config: %s", #unknown > 1 and "s" or "", table.concat(unknown, ", "))
         end
      end
   end

   local valid_keys: {string:(string|{string:boolean})} = {
      include_dir = "{string}",
      global_env_def = "string",
      quiet = "boolean",
      skip_compat53 = "boolean",
      feat_arity = { ["off"] = true, ["on"] = true },
      gen_compat = { ["off"] = true, ["optional"] = true, ["required"] = true },
      gen_target = { ["5.1"] = true, ["5.3"] = true, ["5.4"] = true },
      disable_warnings = "{string}",
      warning_error = "{string}",
   }

   local function check_key(k: any, v: any)
      if not k is string then
         fail(tostring(k), "expected a string key")
         return
      end

      if k == "preload_modules" then
         fail(k, "this key is no longer supported. To load a definition globally into the environment, use global_env_def.")
         return
      end

      if not valid_keys[k] then
         -- skip invalid keys, to be used by other tools
         return
      end

      local vk = valid_keys[k]
      if vk is {string:boolean} then
         if not v is string or not vk[v] then
            fail(k, "expected one of: %s", table.concat(common.keys(vk) as {string}, ", "))
         end
      elseif vk == "{string}" then
         if v is {string} then
            for i, val in ipairs(v) do
               if not val is string then
                  fail(k, "expected an array of strings, got %s in position %d", type(val), i)
               end
            end
         else
            fail(k, "expected an array of strings")
         end
      elseif vk == "string" then
         if not v is string then
            fail(k, "expected a string, got %s", type(v))
         end
      elseif vk == "boolean" then
         if not v is boolean then
            fail(k, "expected a boolean, got %s", type(v))
         end
      else
         error("bug: unhandled valid_keys type")
      end
   end

   for k, v in pairs(config) do
      check_key(k, v)
   end

   if config.skip_compat53 then
      config.gen_compat = "off"
   end

   check_warnings("disable_warnings")
   check_warnings("warning_error")

   return config as TlConfig, errs, warnings
end

function configuration.get(): TlConfig, {string}
   local default: {any:any} = {
      include_dir = {},
      disable_warnings = {},
      warning_error = {},
      quiet = false
   }

   local config_path = find_file_in_parent_dirs("tlconfig.lua") or "tlconfig.lua"

   local conf_fd = io.open(config_path, "r")
   if not conf_fd then
      return default as TlConfig
   end

   local conf_text = conf_fd:read("*a")
   if not conf_text then
      return default as TlConfig
   end

   local conf_fn, err = load(conf_text)
   if not conf_fn then
      common.die("Error loading tlconfig.lua:\n" .. err)
   end

   local ok, user_config = pcall(conf_fn) as (boolean, any)
   if not ok then
      err = user_config as string
      common.die("Error loading tlconfig.lua:\n" .. err)
   end
   if not user_config is table then
      common.die("Error loading tlconfig.lua")
      return
   end

   -- Merge tlconfig with the default config
   local merged: {any:any} = {}
   for k, v in pairs(default) do
      merged[k] = v
   end
   for k, v in pairs(user_config as {string:any}) do
      merged[k] = v
   end

   local conf, errs, warnings = validate_config(merged)

   if #errs > 0 then
      common.die("Error loading tlconfig.lua:\n" .. table.concat(errs, "\n"))
   end

   return conf, warnings
end

function configuration.merge_config_and_args(tlconfig: TlConfig, args: Args)
   do
      local default_true_mt = { __index = function(): boolean return true end }
      local function enable(tab: {string:boolean}, warning: string)
         if warning == "all" then
            setmetatable(tab, default_true_mt)
         else
            tab[warning] = true
         end
      end
      tlconfig._disabled_warnings_set = {}
      tlconfig._warning_errors_set = {}
      for _, list in ipairs({ tlconfig["disable_warnings"] or {}, args["wdisable"] or {} }) do
         for _, warning in ipairs(list) do
            enable(tlconfig._disabled_warnings_set, warning)
         end
      end
      for _, list in ipairs({ tlconfig["warning_error"] or {}, args["werror"] or {} }) do
         for _, warning in ipairs(list) do
            enable(tlconfig._warning_errors_set, warning)
         end
      end
   end

   for _, include_dir_cli in ipairs(args["include_dir"]) do
      if not find_in_sequence(tlconfig.include_dir, include_dir_cli) then
         table.insert(tlconfig.include_dir, include_dir_cli)
      end
   end

   if args["quiet"] then
      tlconfig["quiet"] = true
   end

   if args["pretend"] then
      tlconfig["pretend"] = true
   end

   tlconfig["feat_arity"] = args["feat_arity"] or tlconfig["feat_arity"]

   tlconfig["gen_target"] = args["gen_target"] or tlconfig["gen_target"]
   tlconfig["gen_compat"] = args["gen_compat"] or tlconfig["gen_compat"]
                                               or (tlconfig["skip_compat53"] and "off")

   if args["global_env_def"] then
      if #args["global_env_def"] > 1 then
         common.die("Error: --global-env-def can be used only once.")
      elseif args["global_env_def"][1] then
         tlconfig["global_env_def"] = args["global_env_def"][1]
      end
   end

   for _, include in ipairs(tlconfig["include_dir"]) do
      prepend_to_lua_paths(include)
   end
end

return configuration
