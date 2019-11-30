#!/usr/bin/env lua_no_tailcalls

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

local function title_errors(category, n)
   category = category and (category .. " ") or ""
   printerr("========================================")
   printerr(n .. " " .. category .. "error" .. (n ~= 1 and "s" or "") .. ":")
end

local function report_syntax_errors(syntax_errors)
   if #syntax_errors > 0 then
      title_errors("syntax", #syntax_errors)
      for _, err in ipairs(syntax_errors) do
         printerr(err.filename .. ":" .. err.y .. ":" .. err.x .. ": " .. err.msg)
      end
      os.exit(1)
   end
end

local function report_type_errors(result)
   if #result.type_errors > 0 then
      title_errors(nil, #result.type_errors)
      for _, err in ipairs(result.type_errors) do
         printerr(err.filename .. ":" .. err.y .. ":" .. err.x .. ": " .. err.err)
      end
   end

   if #result.unknowns > 0 then
      printerr("----------------------------------------")
      printerr(#result.unknowns .. " variable" .. (#result.unknowns ~= 1 and "s" or "") .. " of unknown type:")
      for _, var in ipairs(result.unknowns) do
         printerr(var.filename .. ":" .. var.y .. ":" .. var.x .. ": " .. var.name)
      end
   end

   if #result.type_errors > 0 then
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

report_syntax_errors(result.syntax_errors)

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
