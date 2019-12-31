#!/usr/bin/env lua

local function script_path()
   local str = debug.getinfo(2, "S").source:sub(2)
   return str:match("(.*[/\\])") or "."
end

package.path = script_path() .. "/?.lua;" .. package.path

local tl = require("tl")

local cmd
local filename

local is_cmd = {
   run = true,
   check = true,
   gen = true,
}

if is_cmd[arg[1]] then
   cmd = arg[1]
   filename = arg[2]
else
   cmd = "check"
   filename = arg[1]
end

local function printerr(s)
   io.stderr:write(s .. "\n")
end

if not filename then
   printerr("usage:")
   printerr("   tl run <file>")
   printerr("   tl check <file>")
   printerr("   tl gen <file>")
   os.exit(1)
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

local function die(msg)
   printerr(msg)
   os.exit(1)
end

local result, err = tl.process(filename)
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

   local chunk = load(tl.pretty_print_ast(result.ast), "@" .. filename)

   local narg = #arg
   for i = -5, narg do
      arg[i-2] = arg[i]
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
   print("   tl run " .. filename )
   print()
   print("       to run " .. filename .. " as a program")
   print()
   print("   tl gen " .. filename)
   print()
   print("       to generate " .. lua_name)
   os.exit(0)

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
   os.exit(0)
end
