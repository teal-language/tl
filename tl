#!/usr/bin/env lua

local function script_path()
   local str = debug.getinfo(2, "S").source:sub(2)
   return str:match("(.*[/\\])") or "."
end

local function printerr(s)
   io.stderr:write(s .. "\n")
end

local function starts_with(str, start)
   return str:sub(1, #start) == start
end

local function trim(str)
   return str:gsub("^%s*(.-)%s*$", "%1")
end

local function die(msg)
   printerr(msg)
   os.exit(1)
end

-- FIXME
local function validate_config(config)
   local valid_keys = {
      preload_modules = true
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
      preload_modules = {}
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

local function setup_commands(parser)
   parser:command_target("command")

   local check_command = parser:command("check", "Type-check one or more tl script.")
   check_command:argument("script", "The tl script."):args("+")

   local gen_command = parser:command("gen", "Generate a Lua file for one or more tl script.")
   gen_command:argument("script", "The tl script."):args("+")

   local run_command = parser:command("run", "Run a tl script.")
   run_command:argument("script", "The tl script."):args(1)
end

local function get_parser(explicit_command)
   local parser = argparse("tl", "A minimalistic typed dialect of Lua.")

   parser:option("-l --preload", "Execute the equivalent of require('modulename') before executing the tl script(s).")
        :argname("<modulename>")
        :count("*")

   if explicit_command then
      setup_commands(parser)
   else
      parser:argument("script", "The tl script."):args("+")
   end

   return parser
end

local parser = get_parser(true)

local success, args = parser:pparse()

if not success then
   local err = args
   if starts_with(err, "unknown command") then -- Assume the command was actually a file
      parser = get_parser(false) -- Reset the parser
      args = parser:parse()
   else
      print(err)
      os.exit(1)
   end
end

local tlconfig = get_config()

local cmd = args["command"] or "check"

for _, preload_module_cli in ipairs(args["preload"]) do
   local found_in_config = false

   for _, preload_module_config in ipairs(tlconfig.preload_modules) do
      if trim(preload_module_cli) == trim(preload_module_config) then
         found_in_config = true
         break;
      end
   end

   if not found_in_config then
      table.insert(tlconfig.preload_modules, preload_module_cli)
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

local function report_type_errors(result)
   local has_type_errors = report_errors("error", result.type_errors)
   report_errors("unknown variable", result.unknowns)

   if has_type_errors then
      os.exit(1)
   end
end

for _, filename in ipairs(args["script"]) do
   local result, err = tl.process(filename, nil, nil, nil, tlconfig.preload_modules)
   if err then
      die(err)
   end

   local has_syntax_errors = report_errors("syntax error", result.syntax_errors)
   if has_syntax_errors then
      os.exit(1)
   end

   local lua_name = filename:gsub(".tl$", ".lua")

   if cmd == "run" then
      if filename:match("%.tl$") then
         report_type_errors(result)
      end

      local chunk = (loadstring or load)(tl.pretty_print_ast(result.ast), "@" .. filename)

      local narg = #arg
      for i = -5, narg do
         arg[i - 2] = arg[i]
      end
      arg[narg] = nil
      arg[narg - 1] = nil

      return chunk()
   elseif cmd == "check" then
      report_type_errors(result)

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
