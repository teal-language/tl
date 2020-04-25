#!/usr/bin/env lua

local function script_path()
   local str = debug.getinfo(2, "S").source:sub(2)
   return str:match("(.*[/\\])") or "."
end

local function printerr(s)
   io.stderr:write(s .. "\n")
end

local function trim(str)
   return str:gsub("^%s*(.-)%s*$", "%1")
end

local function die(msg)
   printerr(msg)
   os.exit(1)
end

local function find_in_sequence(seq, value)
    for _, v in ipairs(seq) do
        if trim(v) == trim(value) then
            return true
        end
    end

    return false
end

-- FIXME
local function validate_config(config)
   local valid_keys = {
      preload_modules = true,
      include = true
   }

   for k, _ in pairs(config) do
      if not valid_keys[k] then
         print(string.format("Warning: unknown key '%s' in tlconfig.lua", k))
      end
   end

   -- TODO: could we type-check the config file using tl?

   return nil
end

local function get_config()
   local config = {
      preload_modules = {},
      include = {}
   }

   local status, user_config = pcall(require, "tlconfig")

   if not status then
      return config
   end

   -- Merge tlconfig with the default config
   for k, v in pairs(user_config) do
      config[k] = v
   end

   local err = validate_config(config)

   if err then
      die("Error while loading config: " .. err)
   end

   return config
end

package.path = script_path() .. "/?.lua;" .. package.path

local tl = require("tl")
local argparse = require("argparse")

local function get_args_parser()
   local parser = argparse("tl", "A minimalistic typed dialect of Lua.")

   parser:option("-l --preload", "Execute the equivalent of require('modulename') before executing the tl script(s).")
         :argname("<modulename>")
         :count("*")

   parser:option("-I --include", "Prepend this directory to package.path.")
         :argname("<directory>")
         :count("*")

   parser:flag("--skip-compat53", "Skip compat53 insertions.")

   parser:command_target("command")

   local check_command = parser:command("check", "Type-check one or more tl script.")
   check_command:argument("script", "The tl script."):args("+")

   local gen_command = parser:command("gen", "Generate a Lua file for one or more tl script.")
   gen_command:argument("script", "The tl script."):args("+")

   local run_command = parser:command("run", "Run a tl script.")
   run_command:argument("script", "The tl script."):args(1)
      :convert(function(arg)
         assert(type(arg) == "string")
         return { arg }
   end)

   return parser
end

local parser = get_args_parser()
local args = parser:parse()

local tlconfig = get_config()

local cmd = args["command"]

for _, preload_module_cli in ipairs(args["preload"]) do
   if not find_in_sequence(tlconfig.preload_modules, preload_module_cli) then
      table.insert(tlconfig.preload_modules, preload_module_cli)
   end
end

for _, include_dir_cli in ipairs(args["include"]) do
   if not find_in_sequence(tlconfig.include, include_dir_cli) then
      table.insert(tlconfig.include, include_dir_cli)
   end
end

local function report_errors(category, errors)
   if not errors then
      return false
   end
   if #errors > 0 then
      local n = #errors
      printerr("========================================")
      printerr(n .. " " .. category .. (n ~= 1 and "s" or "") .. ":")
      for _, err in ipairs(errors) do
         printerr(err.filename .. ":" .. err.y .. ":" .. err.x .. ": " .. (err.msg or ""))
      end
      return true
   end
   return false
end

local exit = 0

local function report_type_errors(result)
   local has_type_errors = report_errors("error", result.type_errors)
   report_errors("unknown variable", result.unknowns)

   return not has_type_errors
end

local env = nil

local function prepend_to_path(directory)
    local path_separator = package.config:sub(1, 1)

    local lua_path_str = directory

    if string.sub(lua_path_str, -1) == path_separator then
        lua_path_str = lua_path_str:sub(1, -2)
    end

    lua_path_str = lua_path_str .. path_separator .. "?.lua;"

    package.path = lua_path_str .. package.path
end

for _, include in ipairs(tlconfig["include"]) do
    prepend_to_path(include)
end

for i, filename in ipairs(args["script"]) do
   local modules = i == 1 and tlconfig.preload_modules

   if not env then
      local basename, extension = filename:match("(.*)%.([a-z]+)$")
      extension = extension and extension:lower()

      local lax_mode
      if extension == "tl" then
         lax_mode = false
      elseif extension == "lua" then
         lax_mode = true
      else
         -- if we can't decide based on the file extension, default to strict
         -- mode
         lax_mode = false
      end

      local skip_compat53 = args["skip_compat53"]

      env = tl.init_env(lax_mode, skip_compat53)
   end

   local result, err = tl.process(filename, env, nil, modules)
   if err then
      die(err)
   end
   env = result.env

   local has_syntax_errors = report_errors("syntax error", result.syntax_errors)
   if has_syntax_errors then
      exit = 1
      break
   end

   local lua_name = filename:gsub(".tl$", ".lua")

   if cmd == "run" then
      if filename:match("%.tl$") then
         local ok = report_type_errors(result)
         if not ok then
            exit = 1
            break
         end
      end

      local chunk = (loadstring or load)(tl.pretty_print_ast(result.ast), "@" .. filename)

      local narg = #arg
      for i = -5, narg do
         arg[i - 2] = arg[i]
      end
      arg[narg] = nil
      arg[narg - 1] = nil

      tl.loader()

      return chunk()

   elseif cmd == "check" then
      local ok = report_type_errors(result)
      if not ok then
         exit = 1
      end

      if exit == 0 and #args["script"] == 1 then
         print("========================================")
         print("Type checked " .. filename)
         print("0 errors detected -- you can use:")
         print()
         print("   tl run " .. filename)
         print()
         print("       to run " .. filename .. " as a program")
         print()
         print("   tl gen " .. filename)
         print()
         print("       to generate " .. lua_name)
      end

   elseif cmd == "gen" then
      local ofd, err = io.open(lua_name, "w")
      if not ofd then
         die("cannot write " .. lua_name .. ": " .. err)
      end

      local ok, err = ofd:write(tl.pretty_print_ast(result.ast))
      if err then
         die("error writing " .. lua_name .. ": " .. err)
      end

      ofd:close()
      print("Wrote: " .. lua_name)

   end
end

os.exit(exit)
