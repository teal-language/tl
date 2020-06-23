#!/usr/bin/env lua

local version_string = "0.7.1+dev"
local path_separator = package.config:sub(1, 1)

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

local function is_nil_or_whitespace(str)
   return str == nil or trim(str) == ""
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
      build_dir = true,
      files = true,
      ignore = true,
      include = true,
      exclude = true,
      include_dir = true,
      preload_modules = true,
      quiet = true,
      source_dir = true,
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
      include_dir = {},
      quiet = false
   }

   local status, user_config = pcall(require, "tlconfig")

   if not status then
      if user_config:match("^module 'tlconfig' not found:") then
         return config
      else
         die("Error while loading config:\n" .. user_config)
      end
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
local lfs = require("lfs")

local function get_args_parser()
   local parser = argparse("tl", "A minimalistic typed dialect of Lua.")

   parser:option("-l --preload", "Execute the equivalent of require('modulename') before executing the tl script(s).")
         :argname("<modulename>")
         :count("*")

   parser:option("-I --include-dir", "Prepend this directory to the module search path.")
         :argname("<directory>")
         :count("*")

   parser:option("-s --source-dir", "Compile all *.tl files in <directory>.")
         :argname("<directory>")

   parser:option("-b --build-dir", "Put all generated files in <directory>.")
         :argname("<directory>")

   parser:flag("--skip-compat53", "Skip compat53 insertions.")

   parser:flag("--version", "Print version and exit")

   parser:flag("-q --quiet", "Do not print information messages to stdout. Errors may still be printed to stderr.")

   parser:require_command(false)
   parser:command_target("command")

   local check_command = parser:command("check", "Type-check one or more tl script.")
   check_command:argument("script", "The tl script."):args("*")

   local gen_command = parser:command("gen", "Generate a Lua file for one or more tl script.")
   gen_command:argument("script", "The tl script."):args("*")

   local run_command = parser:command("run", "Run a tl script.")
   run_command:argument("script", "The tl script."):args("+")

   return parser
end

local parser = get_args_parser()
local args = parser:parse()

local tlconfig = get_config()


if args["version"] then
   print(version_string)
   os.exit(0)
end

local cmd = args["command"]
if not cmd then
   print(parser:get_usage())
   print()
   print("Error: a command is required")
   os.exit(1)
end

for _, preload_module_cli in ipairs(args["preload"]) do
   if not find_in_sequence(tlconfig.preload_modules, preload_module_cli) then
      table.insert(tlconfig.preload_modules, preload_module_cli)
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
tlconfig["source_dir"] = args["source_dir"] or tlconfig["source_dir"]
tlconfig["build_dir"] = args["build_dir"] or tlconfig["build_dir"]

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

local function get_shared_library_ext()
   if is_nil_or_whitespace(package.cpath) then
      return "so" -- FIXME
   end

   return package.cpath:match("%.(%w+)%s*$")
end

local function prepend_to_path(directory)
   local path_str = directory

   if string.sub(path_str, -1) == path_separator then
      path_str = path_str:sub(1, -2)
   end

   path_str = path_str .. path_separator

   local lib_path_str = path_str .. "?." .. get_shared_library_ext() .. ";"
   local lua_path_str = path_str .. "?.lua;"

   package.path = lua_path_str .. package.path
   package.cpath = lib_path_str .. package.cpath
end

for _, include in ipairs(tlconfig["include_dir"]) do
   prepend_to_path(include)
end

local function setup_env(filename)
   if not env then
      local basename, extension = filename:match("(.*)%.([a-z]+)$")
      extension = extension and extension:lower()

      local lax_mode
      if extension == "tl" then
         lax_mode = false
      elseif extension == "lua" then
         lax_mode = true
      else
         -- if we can't decide based on the file extension, default to strict mode
         lax_mode = false
      end

      local skip_compat53 = args["skip_compat53"]

      env = tl.init_env(lax_mode, skip_compat53)
   end
end

local function type_check_and_load(filename, modules)
   local result, err = tl.process(filename, env, nil, modules)
   if err then
      die(err)
   end
   env = result.env

   local has_syntax_errors = report_errors("syntax error", result.syntax_errors)
   if has_syntax_errors then
      exit = 1
      return
   end
   if filename:match("%.tl$") then
      local ok = report_type_errors(result)
      if not ok then
         os.exit(1)
      end
   end

   local chunk = (loadstring or load)(tl.pretty_print_ast(result.ast), "@" .. filename)
   return chunk
end

-- if were running a script, we don't need to build up a source map
local modules = tlconfig.preload_modules
if cmd == "run" then
   setup_env(args["script"][1])
   local chunk = type_check_and_load(args["script"][1], modules)

   -- collect all non-arguments including negative arg values
   local neg_arg = {}
   local nargs = #args["script"]
   local j = #arg
   local p = nargs
   local n = 1
   while arg[j] do
      if arg[j] == args["script"][p] then
         p = p - 1
      else
         neg_arg[n] = arg[j]
         n = n + 1
      end
      j = j - 1
   end

   -- shift back all non-arguments to negative positions
   for p, a in ipairs(neg_arg) do
      arg[-p] = a
   end
   -- put script in arg[0] and arguments in positive positions
   for p, a in ipairs(args["script"]) do
      arg[p - 1] = a
   end
   -- cleanup the rest
   n = nargs
   while arg[n] do
      arg[n] = nil
      n = n + 1
   end

   tl.loader()
   return chunk()
end

-- for check and gen, build a source map
local src_map = {}
local inc_patterns = {}
local exc_patterns = {}

-- prepare build and source dirs
local function path_concat(...)
   return table.concat({...}, path_separator)
end
local function traverse(dirname)
   local files = {}
   for file in lfs.dir(dirname) do
      if file ~= "." and file ~= ".." then
         if lfs.attributes(path_concat(dirname, file)).mode == "directory" then
            local dir = traverse(path_concat(dirname, file))
            for input, output in pairs(dir) do
               files[input] = output
            end
         else
            local output = file
            if file:match(".tl$") and not file:match(".d.tl$") then
               output = file:gsub(".tl$", ".lua")
            end
            files[path_concat(dirname, file)] = path_concat(dirname, output)
         end
      end
   end
   return files
end

-- include/exclude pattern matching
local function str_split(str, delimiter)
   local idx = 1
   return function()
      if not idx then return end
      local prev_idx = idx
      local s_idx
      s_idx, idx = str:find(delimiter, idx, true)
      return str:sub(prev_idx, (s_idx or 0) - 1)
   end
end
local function patt_match(patt, str)
   local matches = true
   local idx = 1
   local s_idx
   for _, v in ipairs(patt) do
      s_idx, idx = str:find(v, idx)
      if not s_idx then
         matches = false
         break
      end
   end
   return matches
end
local function matcher(str)
   local chunks = {}
   for piece in str_split(str, "**/") do
      table.insert(chunks, (piece:gsub("%*", "[^" .. path_separator .. "]*")))
   end
   chunks[1] = "^" .. chunks[1]
   chunks[#chunks] = chunks[#chunks] .. "$"
   return function(str)
      return patt_match(chunks, str)
   end
end

if #args["script"] == 0 then
   if tlconfig["include"] then
      for i, patt in ipairs(tlconfig["include"]) do
         if tlconfig["source_dir"] then
            patt = path_concat(tlconfig["source_dir"], patt)
         end
         table.insert(inc_patterns, matcher(patt))
      end
   end
   if tlconfig["exclude"] then
      for i, patt in ipairs(tlconfig["exclude"]) do
         if tlconfig["source_dir"] then
            patt = path_concat(tlconfig["source_dir"], patt)
         end
         table.insert(exc_patterns, matcher(patt))
      end
   end

   if tlconfig["source_dir"] then
      src_map = traverse(tlconfig["source_dir"])
   else
      src_map = traverse(lfs.currentdir())
   end
else
   for i, filename in ipairs(args["script"]) do
      src_map[filename] = filename:gsub(".tl$", ".lua")
   end
end

local curr_dir = lfs.currentdir()
local function remove_lead_path(path, leading)
   return (path:gsub("^" .. leading .. path_separator, ""))
end
local function to_relative(path)
   return remove_lead_path(path, curr_dir)
end

if tlconfig["build_dir"] and cmd == "gen" then
   table.insert(exc_patterns, matcher(path_concat(tlconfig["build_dir"], "**/")))
   for input_file, output_file in pairs(src_map) do
      output_file = to_relative(output_file)
      if tlconfig["source_dir"] then
         output_file = remove_lead_path(output_file, tlconfig["source_dir"])
      end

      local new_path = path_concat(tlconfig["build_dir"], output_file)
      local path = {}
      for dir in new_path:gmatch("[^%" .. path_separator .. "]+") do
         path[#path + 1] = #path > 0 and path_concat(path[#path], dir) or dir
      end
      table.remove(path)
      for i, v in ipairs(path) do
         local attr = lfs.attributes(v)
         if not attr then
            lfs.mkdir(v)
         elseif attr.mode ~= "directory" then
            die("Error in build directory: " .. dir .. " is not a directory.")
         end
      end
      src_map[input_file] = new_path
   end
end

for input_file, output_file in pairs(src_map) do
   src_map[input_file] = to_relative(output_file)
end

if #args["script"] == 0 then
   for input_file, output_file in pairs(src_map) do
      rel_input_file = to_relative(input_file)
      local include = true
      for _, patt in ipairs(inc_patterns) do
         if not patt(rel_input_file) then
            include = false
            break
         end
      end
      for _, patt in ipairs(exc_patterns) do
         if patt(rel_input_file) then
            include = false
            break
         end
      end
      if not include then
         src_map[input_file] = nil
      end
   end
end

for input_file, output_file in pairs(src_map) do
   setup_env(input_file)

   local result, err = tl.process(input_file, env, nil, modules)
   if err then
      die(err)
   end
   env = result.env

   local has_syntax_errors = report_errors("syntax error", result.syntax_errors)
   if has_syntax_errors then
      exit = 1
      break
   end

   if cmd == "check" then
      local ok = report_type_errors(result)
      if not ok then
         exit = 1
      end

      if exit == 0 and tlconfig["quiet"] == false and #args["script"] == 1 then
         print("========================================")
         print("Type checked " .. input_file)
         print("0 errors detected -- you can use:")
         print()
         print("   tl run " .. input_file)
         print()
         print("       to run " .. input_file .. " as a program")
         print()
         print("   tl gen " .. input_file)
         print()
         print("       to generate " .. output_file)
      end

   elseif cmd == "gen" then
      local ofd, err = io.open(output_file, "w")

      if not ofd then
         die("cannot write " .. output_file .. ": " .. err)
      end

      local ok, err = ofd:write(tl.pretty_print_ast(result.ast) .. "\n")
      if err then
         die("error writing " .. output_file .. ": " .. err)
      end

      ofd:close()

      if tlconfig["quiet"] == false then
         print("Wrote: " .. output_file)
      end
   end
end

os.exit(exit)
