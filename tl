#!/usr/bin/env lua

--------------------------------------------------------------------
--                           SETUP                                --
--------------------------------------------------------------------

local tl = require("tl")
local argparse = require("argparse")
local lfs = require("lfs")

local version_string = "0.10.0+dev"
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
      build_dir = "string",
      exclude = "{string}",
      files = "{string}",
      include = "{string}",
      include_dir = "{string}",
      preload_modules = "{string}",
      quiet = "boolean",
      source_dir = "string",
      skip_compat53 = "boolean",
      disable_warnings = "{string}",
      warning_error = "{string}",
   }

   for k, v in pairs(config) do
      if not valid_keys[k] then
         print(string.format("Warning: unknown key '%s' in tlconfig.lua", k))
      else
         -- TODO: could we type-check the config file using tl?
         local arr_type = valid_keys[k]:match("{(.*)}")
         if arr_type then
            if type(v) ~= "table" then
               return "Expected " .. k .. " to be a " .. valid_keys[k]
            end
            for i, val in ipairs(v) do
               if type(val) ~= arr_type then
                  return "Expected " .. k .. "[" .. i .. "] to be a " .. valid_keys[k]
               end
            end
         else
            if type(v) ~= valid_keys[k] then
               return "Expected " .. k .. " to be a " .. valid_keys[k]
            end
         end
      end
   end

   if config.disable_warnings then
      local unknown = {}
      for _, warning in ipairs(config.disable_warnings) do
         if not tl.warning_kinds[warning] then
            table.insert(unknown, string.format("%q", warning))
         end
      end
      if #unknown > 0 then
         print("Unknown warning" .. (#unknown > 1 and "s" or "") .. " in config: " .. table.concat(unknown, ", "))
      end
   end

   if config.warning_error then
      local unknown = {}
      for _, warning in ipairs(config.disable_warnings) do
         if not tl.warning_kinds[warning] then
            table.insert(unknown, string.format("%q", warning))
         end
      end
      if #unknown > 0 then
         print("Unknown warning" .. (#unknown > 1 and "s" or "") .. " in config: " .. table.concat(unknown, ", "))
      end
   end

   return nil
end

local config_from_file = false
local function get_config()
   local config = {
      preload_modules = {},
      include_dir = {},
      disable_warnings = {},
      warning_error = {},
      quiet = false
   }

   local conf, err = loadfile("tlconfig.lua")
   if not conf then
      if err:match("No such file or directory$") then
         return config
      else
         die("Error loading config:\n" .. err)
      end
   end
   config_from_file = true

   local ok, user_config = pcall(conf)
   if not ok then
      die("Error loading config:\n" .. err)
   end

   -- Merge tlconfig with the default config
   if user_config then
      for k, v in pairs(user_config) do
         config[k] = v
      end
   end

   err = validate_config(config)

   if err then
      die("Error while loading config: " .. err)
   end

   return config
end

package.path = script_path() .. "/?.lua;" .. package.path

local function get_args_parser()
   local parser = argparse("tl", "A minimalistic typed dialect of Lua.")

   parser:option("-l --preload", "Execute the equivalent of require('modulename') before processing Teal files.")
         :argname("<modulename>")
         :count("*")

   parser:option("-I --include-dir", "Prepend this directory to the module search path.")
         :argname("<directory>")
         :count("*")

   parser:option("--wdisable", "Disable the given kind of warning.")
         :argname("<warning>")
         :count("*")

   parser:option("--werror", "Promote the given kind of warning to an error. Use '--werror all' to promote all warnings to errors")
         :argname("<warning>")
         :count("*")

   parser:option("--warning-error-all")

   parser:flag("--skip-compat53", "Skip compat53 insertions.")

   parser:flag("--version", "Print version and exit")

   parser:flag("-q --quiet", "Do not print information messages to stdout. Errors may still be printed to stderr.")

   parser:flag("-p --pretend", "Do not write to any files, type check and output what files would be generated.")

   parser:require_command(false)
   parser:command_target("command")

   local check_command = parser:command("check", "Type-check one or more Teal files.")
   check_command:argument("file", "The Teal source file."):args("+")

   local gen_command = parser:command("gen", "Generate a Lua file for one or more Teal files.")
   gen_command:argument("file", "The Teal source file."):args("+")
   gen_command:option("-o --output", "Write to <filename> instead.")
              :argname("<filename>")

   local run_command = parser:command("run", "Run a Teal script.")
   run_command:argument("script", "The Teal script."):args("+")

   local build_command = parser:command("build", "Build your project according to tlconfig.lua by type checking and compiling each specified file.")
   build_command:option("-b --build-dir", "Put all generated files in <directory>.")
                :argname("<directory>")
   build_command:option("-s --source-dir", "Compile all *.tl files in <directory> (and all subdirectories).")
                :argname("<directory>")

   parser:command("warnings", "List each kind of warning the compiler can produce.")

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

local function merge_list(a, b)
   a = a or {}
   b = b or {}
   local c = {}
   for i, v in ipairs(a) do
      table.insert(c, v)
   end
   for i, v in ipairs(b) do
      table.insert(c, v)
   end
   return c
end

local disabled_warnings = {}
local warning_errors = {}
do
   local default_true_mt = { __index = function() return true end }
   local function enable(tab, warning)
      if warning == "all" then
         setmetatable(tab, default_true_mt)
      else
         tab[warning] = true
      end
   end
   for _, warning in ipairs(merge_list(tlconfig["disable_warnings"], args["wdisable"])) do
      enable(disabled_warnings, warning)
   end
   for _, warning in ipairs(merge_list(tlconfig["warning_error"], args["werror"])) do
      enable(warning_errors, warning)
   end
end

if cmd == "warnings" then
   local function right_pad(str, wid)
      return (" "):rep(wid - #str) .. str
   end
   local w = {}
   local longest = 0
   for warning in pairs(tl.warning_kinds) do
      if #warning > longest then
         longest = #warning
      end
      table.insert(w, warning)
   end
   table.sort(w)
   print("Compiler warnings:")
   for _, v in ipairs(w) do
      io.write(" ", right_pad(v, longest), " : ")
      if disabled_warnings[v] then
         io.write("disabled")
      elseif warning_errors[v] then
         io.write("promoted to error")
      else
         io.write("enabled")
      end
      io.write("\n")
   end
   os.exit(0)
end

--------------------------------------------------------------------
--                     CONFIG VALIDATION                          --
--------------------------------------------------------------------

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
if cmd == "build" then
   tlconfig["source_dir"] = args["source_dir"] or tlconfig["source_dir"]
   tlconfig["build_dir"] = args["build_dir"] or tlconfig["build_dir"]
end
tlconfig["skip_compat53"] = args["skip_compat53"] or tlconfig["skip_compat53"]
if cmd == "gen" and args["output"] and #args["file"] ~= 1 then
   print("Error: --output can only be used to map one input to one output")
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

local exit = 0

--------------------------------------------------------------------
--                        ENVIRONMENT                             --
--------------------------------------------------------------------

local function report_warnings(result)
   if not args["quiet"] then
      local res_warnings = {}
      for _, warning in ipairs(result.warnings) do
         if not (disabled_warnings[warning.tag] or warning_errors[warning.tag]) then
            table.insert(res_warnings, warning)
         end
      end
      return not report_errors("warning", res_warnings)
   end
end

local function get_warning_errors(result)
   local res_warnings = {}
   for _, warning in ipairs(result.warnings) do
      local tag = warning.tag
      if warning_errors[tag]
         and not disabled_warnings[tag]
      then
         table.insert(res_warnings, warning)
      end
   end
   return res_warnings
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

local modules = tlconfig.preload_modules

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

      local skip_compat53 = tlconfig["skip_compat53"]

      env = tl.init_env(lax_mode, skip_compat53)
   end
end

local function get_output_filename(file_name)
   local tail = file_name:match("[^%" .. path_separator .. "]+$")
   if not tail then
      return
   end
   local name, ext = tail:match("(.+)%.([a-zA-Z]+)$")
   if not name then name = tail end
   if ext ~= "lua" then
      return name .. ".lua"
   else
      return name .. ".out.lua"
   end
end

local function report_result(result)
   report_warnings(result)
   local errs = merge_list(result.type_errors, get_warning_errors(result))
   local ok = not report_errors("error", errs)
   report_errors("unknown variable", result.unknowns)
   return ok
end

local function type_check_file(file_name)
   setup_env(file_name)

   local result, err = tl.process(file_name, env, nil, modules)
   if err then
      die(err)
   end
   env = result.env

   local has_syntax_errors = report_errors("syntax error", result.syntax_errors)
   if has_syntax_errors then
      exit = 1
      return
   end

   local ok = report_result(result)
   if not ok then
      exit = 1
   end

   if exit == 0 and tlconfig["quiet"] == false and #args["file"] == 1 then
      local output_file = get_output_filename(file_name)
      print("========================================")
      print("Type checked " .. file_name)
      print("0 errors detected -- you can use:")
      print()
      print("   tl run " .. file_name)
      print()
      print("       to run " .. file_name .. " as a program")
      print()
      print("   tl gen " .. file_name)
      print()
      print("       to generate " .. output_file)
   end
   return result
end

local function type_check_and_load(filename, modules)
   local result, err = tl.process(filename, env, nil, modules)
   if err then
      die(err)
   end
   env = result.env

   local has_syntax_errors = report_errors("syntax error", result.syntax_errors)
   if has_syntax_errors then
      os.exit(1)
   end
   if filename:match("%.tl$") then
      local ok = report_result(result)
      if not ok then
         os.exit(1)
      end
   end

   local chunk; chunk, err = (loadstring or load)(tl.pretty_print_ast(result.ast), "@" .. filename)
   if err then
      die("Internal Compiler Error: Teal generator produced invalid Lua. Please report a bug at https://github.com/teal-language/tl\n\n" .. tostring(err))
   end
   return chunk
end

--------------------------------------------------------------------
--                            RUN                                 --
--------------------------------------------------------------------

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
   for p2, a in ipairs(neg_arg) do
      arg[-p2] = a
   end
   -- put script in arg[0] and arguments in positive positions
   for p2, a in ipairs(args["script"]) do
      arg[p2 - 1] = a
   end
   -- cleanup the rest
   n = nargs
   while arg[n] do
      arg[n] = nil
      n = n + 1
   end

   tl.loader()
   return chunk((unpack or table.unpack)(arg))
end

--------------------------------------------------------------------
--                           CHECK                                --
--------------------------------------------------------------------

if cmd == "check" then
   for i, input_file in ipairs(args["file"]) do
      type_check_file(input_file)
   end
   os.exit(exit)
end

--------------------------------------------------------------------
--                            GEN                                 --
--------------------------------------------------------------------

local function write_out(result, output_file)
   if not args["pretend"] then
      local ofd, err = io.open(output_file, "w")

      if not ofd then
         die("cannot write " .. output_file .. ": " .. err)
      end

      local ok; ok, err = ofd:write(tl.pretty_print_ast(result.ast) .. "\n")
      if err then
         die("error writing " .. output_file .. ": " .. err)
      end

      ofd:close()
   end
   if args["pretend"] then
      print("Would Write: " .. output_file)
   else
      print("Wrote: " .. output_file)
   end
end

if cmd == "gen" then
   local results = {}
   local err
   for i, input_file in ipairs(args["file"]) do
      setup_env(input_file)
      local res = {
         input_file = input_file,
         output_file = get_output_filename(input_file)
      }

      res.tl_result, err = tl.process(input_file, env, nil, modules)
      if err then
         die(err)
      end
      env = res.tl_result.env

      if #res.tl_result.syntax_errors > 0 then
         exit = 1
      end
      table.insert(results, res)
   end
   if exit ~= 0 then
      for i, res in ipairs(results) do
         if #res.tl_result.syntax_errors > 0 then
            report_errors("syntax error", res.tl_result.syntax_errors)
         end
      end
   else
      for i, res in ipairs(results) do
         write_out(res.tl_result, args["output"] or res.output_file)
      end
   end
   os.exit(exit)
end

if cmd == "build" and not config_from_file then
   die("Build error: tlconfig.lua not found")
end


--------------------------------------------------------------------
--                      PATTERN MATCHING                          --
--------------------------------------------------------------------

local function match(patt_arr, str)
   for i, v in ipairs(patt_arr) do
      if v(str) then
         return i
      end
   end
   return nil
end
local inc_patterns = {}
local exc_patterns = {}

local function str_split(str, delimiter)
   local idx = 0
   return function()
      if not idx then return end
      idx = idx + 1
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
   for piece in str_split(str, "**" .. path_separator) do
      table.insert(chunks, (piece:gsub("%*", "[^" .. path_separator .. "]-")))
   end
   chunks[1] = "^" .. chunks[1]
   chunks[#chunks] = chunks[#chunks] .. "$"
   return function(str)
      return patt_match(chunks, str)
   end
end

--------------------------------------------------------------------
--                     FILESYSTEM HELPERS                         --
--------------------------------------------------------------------

-- prepare build and source dirs
local curr_dir = lfs.currentdir()
local function cleanup_file_name(name) --remove trailing and extra path separators, substitute './' for 'current_dir/'
   return (name
      :gsub("^(%.)(.?)", function(a, b)
         assert(a == ".")
         if b == "." then
            die("Config error: .." .. path_separator .. " not allowed, please use direct paths")
         elseif b == path_separator then
            return ""
         else
            return b
         end
      end)
      :gsub(path_separator .. "+", path_separator))
      :gsub(path_separator .. "+$", "")
end
local function path_concat(...)
   local path = {}
   for i = 1, select("#", ...) do
      local fname = cleanup_file_name((select(i, ...)))
      if #fname > 0 then
         table.insert(path, fname)
      end
   end
   return table.concat(path, path_separator)
end
local function remove_leading_path(leading_part, path)
   local s, e = path:find("^" .. leading_part .. path_separator .. "?")
   if s then
      return path:sub(e+1, -1)
   end
   return path
end

local function traverse(dirname, emptyref)
   local files = {}
   local paths = {} --lookup table for string paths to help
   -- with pattern matching while iterating over a project
   -- paths[files.foo.bar] -> "foo/bar"
   emptyref = emptyref or {}
   for file in lfs.dir(dirname) do
      if file ~= "." and file ~= ".." then
         if lfs.attributes(path_concat(dirname, file), "mode") == "directory" then
            local p
            local prefix = dirname
            files[file], p = traverse(path_concat(dirname, file), emptyref)
            paths[files[file]] = file
            for k, v in pairs(p) do
               paths[k] = path_concat(file, v)
            end
         else
            -- storing a special entry in this table to it mark as empty could
            -- interfere with convoluted or maliciously constructed directory
            -- names so we use a table with specific metatable to mark
            -- something as the end of a traversal to have a property attached
            -- to the table, without creating an entry in the table
            files[file] = setmetatable({}, emptyref)
            paths[files[file]] = file
         end
      end
   end
   return files, paths, emptyref
end

local project = {} -- This will probably get exposed in the api if that happens
function project:files(inc_patt_arr, exc_patt_arr, dirname) -- iterate over the files in the project adhering to the provided patterns
   local iter_dir
   if dirname then
      iter_dir = project:find(dirname)
   else
      iter_dir = self.dir
   end
   if not iter_dir then
      return function() end
   end
   inc_patt_arr = inc_patt_arr or {}
   exc_patt_arr = exc_patt_arr or {}
   local function iter(dirs)
      for fname, file in pairs(dirs) do
         local path = self.paths[file]
         if dirname then
            path = remove_leading_path(dirname, path)
         end
         if getmetatable(file) == self.emptyref then
            local include = true

            if tlconfig["files"] then
               include = false
            end
            -- TODO: print out patterns that include/exclude paths to help
            -- users debug tlconfig.lua (this is why match returns the array index)
            if #inc_patt_arr > 0 then
               local idx = match(inc_patt_arr, path)
               if not idx then
                  include = false
               end
            end
            if #exc_patt_arr > 0 then
               local idx = match(exc_patt_arr, path)
               if include and idx then
                  include = false
               end
            end
            if include then
               coroutine.yield(self.paths[file])
            end
         else
            iter(file, fname)
         end
      end
   end
   return coroutine.wrap(iter), iter_dir
end
function project:find(path) -- allow for indexing with paths project:find("foo/bar") -> project.dir.foo.bar
   if not path then return nil end
   if path == "" then return self.dir end -- empty string is the current dir
   local current_dir = self.dir
   for dirname in str_split(path, path_separator) do
      current_dir = current_dir[dirname]
      if not current_dir then
         return nil
      end
   end
   return current_dir
end

project.dir, project.paths, project.emptyref = traverse(lfs.currentdir())
project.source_file_map = {}
if cmd == "build" then
   if tlconfig["source_dir"] then
      tlconfig["source_dir"] = cleanup_file_name(tlconfig["source_dir"])
      local project_source = project:find(tlconfig["source_dir"])
      if not project_source then
         die("Build error: source_dir '" .. tlconfig["source_dir"] .. "' doesn't exist")
      elseif getmetatable(project_source) == project.emptyref then
         die("Build error: source_dir '" .. tlconfig["source_dir"] .. "' is not a directory")
      end
   end
   if tlconfig["build_dir"] then
      tlconfig["build_dir"] = cleanup_file_name(tlconfig["build_dir"])
   end

   -- include/exclude pattern matching
   -- create matchers for each pattern
   if tlconfig["include"] then
      for i, patt in ipairs(tlconfig["include"]) do
         patt = cleanup_file_name(patt)
         table.insert(inc_patterns, matcher(patt))
      end
   end
   if tlconfig["exclude"] then
      for i, patt in ipairs(tlconfig["exclude"]) do
         patt = cleanup_file_name(patt)
         table.insert(exc_patterns, matcher(patt))
      end
   end

   local dirs_to_be_mked = {}
   local function check_parent_dirs(path)
      local parent_dirs = {}
      for dir in str_split(path, path_separator) do
         parent_dirs[#parent_dirs + 1] = #parent_dirs > 0 and path_concat(parent_dirs[#parent_dirs], dir) or dir
      end
      for i, v in ipairs(parent_dirs) do
         if i < #parent_dirs then
            local mode = lfs.attributes(v, "mode")
            if not mode and not dirs_to_be_mked[v] then
               table.insert(dirs_to_be_mked, v)
               dirs_to_be_mked[v] = true
            elseif mode and mode ~= "directory" then
               die("Build error: expected " .. v .. " to be a directory")
            end
         end
      end
   end

   if tlconfig["files"] then
      -- TODO: check if files are not relative
      for i, fname in ipairs(tlconfig["files"]) do
         if not project:find(fname) then
            die("Build error: file \"" .. fname .. "\" not found")
         end
         project.source_file_map[fname] = fname:gsub("%.tl$", ".lua")
         if tlconfig["build_dir"] then
            project.source_file_map[path] = path_concat(tlconfig["build_dir"], project.source_file_map[path])
         end
         check_parent_dirs(project.source_file_map[fname])
      end
   end
   for path in project:files(inc_patterns, exc_patterns, tlconfig["source_dir"]) do
      --TODO: make this better
      local valid = true
      if not (path:match("%.tl$") and not path:match("%.d%.tl$")) then
         valid = false
      end
      if valid then
         project.source_file_map[path] = path:gsub("%.tl$", ".lua")
         if tlconfig["build_dir"] then
            if tlconfig["source_dir"] then
               project.source_file_map[path] = remove_leading_path(tlconfig["source_dir"], project.source_file_map[path])
            end
            project.source_file_map[path] = path_concat(tlconfig["build_dir"], project.source_file_map[path])
         end

         check_parent_dirs(project.source_file_map[path])
      end
   end
   for i, v in ipairs(dirs_to_be_mked) do
      if not lfs.mkdir(v) then
         die("Build error: unable to mkdir \"" .. v .. "\"")
      end
   end
end

--------------------------------------------------------------------
--                            BUILD                               --
--------------------------------------------------------------------
-- print(require"inspect"(project))

-- sort source map so that order is deterministic (helps for testing output)
local sorted_source_file_arr = {}
for input_file, output_file in pairs(project.source_file_map) do
   table.insert(sorted_source_file_arr, {input_file, output_file})
end
table.sort(sorted_source_file_arr, function(a, b) return a[1] < b[1] end)

for i, files in ipairs(sorted_source_file_arr) do
   local input_file, output_file = files[1], files[2]
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
   local ok = report_result(result)
   if ok then
      write_out(result, output_file)
   else
      exit = 1
   end
end

os.exit(exit)
