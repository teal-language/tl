#!/usr/bin/env lua

--------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------

local is_turbo_on = false
local function turbo(on)
   if on then
      if jit then
         jit.off()
      end
      collectgarbage("stop")
   else
      if jit then
         jit.on()
      end
      collectgarbage("restart")
   end
   is_turbo_on = on
end

local tl = require("tl")
local argparse = require("argparse")
local lfs = require("lfs")

local version_string = "0.11.1+dev"
local path_separator = package.config:sub(1, 1)

--------------------------------------------------------------------
-- String Utils
--------------------------------------------------------------------

local function trim(str)
   return str:gsub("^%s*(.-)%s*$", "%1")
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

local function str_split(str, delimiter)
   local idx = 0
   local s_idx, prev_idx
   return function()
      if not idx then return end
      idx = idx + 1
      prev_idx = idx
      s_idx, idx = str:find(delimiter, idx, true)
      return str:sub(prev_idx, (s_idx or 0) - 1)
   end
end

local function right_pad(str, wid)
   return (" "):rep(wid - #str) .. str
end

--------------------------------------------------------------------
-- Table Utils
--------------------------------------------------------------------

local function keys(t)
   local ks = {}
   for k, _ in pairs(t) do
      table.insert(ks, k)
   end
   table.sort(ks)
   return ks
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

--------------------------------------------------------------------
-- Logging
--------------------------------------------------------------------

local function logger(stream)
   return function(...)
      stream:write(...)
      stream:write("\n")
      stream:flush()
   end
end

local log = setmetatable({
   default = logger(io.stdout),
   err = logger(io.stderr),
   warn = logger(io.stderr),
   null = function() end,
}, {
   __call = function(self, ...)
      self.default(...)
   end
})

local logf = setmetatable({}, {
   __index = function(self, key)
      assert(log[key], "no logger for " .. tostring(key))
      return function(fmt, ...)
         log[key](string.format(fmt, ...))
      end
   end,
   __call = function(self, ...)
      logf.default(...)
   end,
})

local function die(...)
   log.err(...)
   os.exit(1)
end

local function report_errors(category, errors, logfn)
   if not errors then
      return false
   end
   if #errors > 0 then
      logfn = logfn or log.err
      local n = #errors
      logfn("========================================")
      logfn(n, " ", category, (n ~= 1 and "s" or ""), ":")
      for _, err in ipairs(errors) do
         logfn(err.filename, ":", err.y, ":", err.x, ": ", err.msg or "")
      end
      return true
   end
   return false
end

local disabled_warnings = {}
local warning_errors = {}
local function report_warnings(result)
   local res_warnings = {}
   for _, warning in ipairs(result.warnings or {}) do
      if not (disabled_warnings[warning.tag] or warning_errors[warning.tag]) then
         table.insert(res_warnings, warning)
      end
   end
   return not report_errors("warning", res_warnings, log.warn)
end

local function get_warning_errors(result)
   local res_warnings = {}
   for _, warning in ipairs(result.warnings or {}) do
      local tag = warning.tag
      if warning_errors[tag]
         and not disabled_warnings[tag]
      then
         table.insert(res_warnings, warning)
      end
   end
   return res_warnings
end

local function report_result(result)
   report_warnings(result)
   local errs = merge_list(result.type_errors, get_warning_errors(result))
   local ok = not report_errors("error", errs)
   report_errors("unknown variable", result.unknowns)
   return ok
end

--------------------------------------------------------------------
-- Path Utils
--------------------------------------------------------------------

local function self_path()
   return debug.getinfo(2, "S").source:sub(2)
end

local function script_path()
   return self_path():match("(.*[/\\])") or "."
end

local function get_shared_library_ext()
   if is_nil_or_whitespace(package.cpath) then
      return "so" -- FIXME
   end

   return package.cpath:match("%.(%w+)%s*$")
end

local function prepend_to_lua_path(directory)
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

local function find_file_in_parent_dirs(fname)
   local currentdir = lfs.currentdir()
   local it = str_split(currentdir, path_separator)
   local paths = { (it() or "") .. path_separator .. (it() or "") } -- base path is '/' or 'C:\' etc.
   for chunk in it do
      paths[#paths + 1] = paths[#paths] .. path_separator .. chunk
   end
   for i = #paths, 1, -1 do
      for file in lfs.dir(paths[i]) do
         if file == fname then
            return paths[i] .. path_separator .. fname
         end
      end
   end
end

local function is_absolute_path(path)
   return path and path:sub(1, 1) == "/"
end

local function mode(path)
   return lfs.attributes(path, "mode")
end

local function is_file(path)
   return path and mode(path) == "file"
end

local function is_dir(path)
   return path and mode(path) == "directory"
end

-- remove trailing and extra path separators, substitute './' for 'current_dir/'
local function cleanup_file_name(name)
   return (name
      :gsub("^(%.)(.?)", function(a, b)
         assert(a == ".")
         if b == "." then
            die("Config error: ../ not allowed, please use direct paths")
         elseif b == path_separator then
            return ""
         else
            return b
         end
      end)
      :gsub("/+", "/"))
      :gsub("/+$", "")
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

local function is_in_dir(dirname, fname)
   if dirname == fname then
      return false
   end

   local dir_it, file_it = str_split(dirname, "/"), str_split(fname, "/")
   local last_d, last_f

   repeat last_d, last_f = dir_it(), file_it()
   until last_d ~= last_f

   return last_d == nil and last_f ~= nil
end

local function extension_split(path, ndots)
   if not path then
      return path
   end
   for n = ndots or 1, 1, -1 do
      local patt = "^(.-)(" .. ("%.%a+"):rep(n) .. ")$"
      local base, ext = path:match(patt)
      if ext then
         ext = ext:lower()
         return base, ext
      end
   end
   return path
end

local function remove_leading_path(leading_part, path)
   local s, e = path:find("^" .. leading_part .. path_separator)
   if s then
      return path:sub(e+1, -1)
   end
   return path
end

--------------------------------------------------------------------
-- Runtime type checking/error handling
--------------------------------------------------------------------

local function pcall_or_die(fn, prefix)
   prefix = prefix or ""

   local co = coroutine.create(fn)
   local ok, res = coroutine.resume(co)
   if not ok then
      local lines = {}
      for ln in str_split(debug.traceback(co), "\n") do
         table.insert(lines, ln)
      end
      for i = #lines, 1, -1 do
         if lines[i]:find(self_path(), 2) then
            lines[i] = nil
         else
            break
         end
      end
      die(prefix, res, "\n", table.concat(lines, "\n"))
   end

   return res
end

---@param val: any the value to be type checked
---@param expected: string the type val should be
---@param prefix: string prepend this to the error message
---@param get_type: function(any): string a custom type getting function to replace type()
local function type_check_or_die(val, expected, prefix, get_type)
   local got = (get_type or type)(val)
   if got ~= expected then
      die(prefix, "Expected ", tostring(expected), ", got ", tostring(got))
   end
end

local function nil_type_check_or_die(val, expected, prefix, get_type)
   if val == nil then
      return
   end
   type_check_or_die(val, expected, prefix, get_type)
end

---@param val: any the value to be type checked
---@param default: string if the array is empty, treat it as an array of 'default'
---@return string the type of val, in the case of an array
--- output will be formatted like {string}
--- behaves like default type(val) otherwise
local function get_array_type(val, default)
   if type(val) ~= "table" then
      return type(val)
   end
   local set = {}
   for i, v in ipairs(val) do
      set[type(v)] = true
   end
   local ts = keys(set)
   if #ts == 0 then
      ts[1] = default
   end
   return "{" .. table.concat(ts, "|") .. "}"
end

--------------------------------------------------------------------
-- Config Validation
--------------------------------------------------------------------

-- FIXME
local function validate_config(config)
   -- TODO: could we type-check the config file using tl?
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
      gen_compat = { ["off"] = true, ["optional"] = true, ["required"] = true },
      gen_target = { ["5.1"] = true, ["5.3"] = true },
      disable_warnings = "{string}",
      warning_error = "{string}",
      build_file = "string",
      build_file_output_dir = "string",
   }

   for k, v in pairs(config) do
      if not valid_keys[k] then
         log(string.format("Warning: unknown key '%s' in tlconfig.lua", k))
      elseif type(valid_keys[k]) == "table" then
         if not valid_keys[k][v] then
            return "Invalid value for " .. k .. ", expected one of: " ..
                   table.concat(keys(valid_keys[k][v]), ", ")
         end
      else
         local vtype = get_array_type(v, valid_keys[k]:match("^{(.*)}$"))
         if vtype ~= valid_keys[k] then
            return "Expected " .. k .. " to be a " .. valid_keys[k] .. ", got " .. vtype
         end
      end
   end

   if config.skip_compat53 then
      config.gen_compat = "off"
   end

   if is_absolute_path(config.source_dir) then
      return "source_dir must be a relative path"
   end

   if config.disable_warnings then
      local unknown = {}
      for _, warning in ipairs(config.disable_warnings) do
         if not tl.warning_kinds[warning] then
            table.insert(unknown, string.format("%q", warning))
         end
      end
      if #unknown > 0 then
         log.err("Unknown warning", (#unknown > 1 and "s" or ""), " in config: ", table.concat(unknown, ", "))
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
         log.err("Unknown warning", (#unknown > 1 and "s" or ""), " in config: ", table.concat(unknown, ", "))
      end
   end

   if not config.build_file then
      if is_file("build.tl") then
         config.build_file = "build.tl"
      end
   else
      if not is_file(config.build_file) then
         return "Build script " .. config.build_file .. " is not a file"
      end
   end

   if not config.build_file_output_dir then
      config.build_file_output_dir = "generated_code" .. path_separator
   end

   if config.build_file_output_dir:sub(-1, -1) ~= path_separator then
      config.build_file_output_dir = config.build_file_output_dir .. path_separator
   end

   return nil
end

--------------------------------------------------------------------
-- Argparser
--------------------------------------------------------------------

package.path = script_path() .. "/?.lua;" .. package.path

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

parser:option("--gen-compat", "Generate compatibility code for targeting different Lua VM versions.")
      :choices({ "off", "optional", "required" })
      :default("optional")
      :defmode("a")

parser:option("--gen-target", "Minimum targeted Lua version for generated code.")
      :choices({ "5.1", "5.3" })

parser:flag("--skip-compat53", "Skip compat53 insertions.")
      :hidden(true)
      :action(function(args) args.gen_compat = "off" end)

parser:flag("--version", "Print version and exit")

parser:flag("-q --quiet", "Do not print information messages to stdout. Errors may still be printed to stderr.")

parser:flag("-p --pretend", "Do not write to any files, type check and output what files would be generated.")
-- parser:flag("--run-build-script", "Run the build script if needed, even when not running the build comamnd.")

parser:require_command(false)
parser:command_target("command")

do
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

   local types_command = parser:command("types", "Report all types found in one or more Teal files")
   types_command:argument("file", "The Teal source file."):args("+")
   types_command:option("-p --position", "Report values in scope in position line[:column]")
                :argname("<position>")

end

local args = parser:parse()

if args["version"] then
   log(version_string)
   os.exit(0)
end

local cmd = args["command"]
if not cmd then
   log(parser:get_usage(), "\nError: a command is required")
   os.exit(1)
end

if args["quiet"] then
   log.default = log.null
   log.warn = log.null
end

local function get_config()
   local config = {
      preload_modules = {},
      include_dir = {},
      disable_warnings = {},
      warning_error = {},
      quiet = false
   }

   local config_path = cmd == "build"
      and find_file_in_parent_dirs("tlconfig.lua")
      or "tlconfig.lua"

   local conf, err = loadfile(config_path)
   if not conf then
      if err:match("No such file or directory$") then
         if cmd == "build" then
            die("Build error: tlconfig.lua not found")
         end
      else
         die("Error loading config: ", err)
      end
   end

   if conf then
      local ok, res = pcall(conf)
      if not ok then
         die("Error loading config: ", res)
      end

      -- Merge tlconfig with the default config
      if res then
         for k, v in pairs(res) do
            config[k] = v
         end
      end
   end

   config_path = config_path:match("^(.+)" .. path_separator .. "tlconfig.lua$")
   if cmd == "build" and config_path then
      assert(lfs.chdir(config_path))
   end

   err = validate_config(config)

   if err then
      die("Error loading config: ", err)
   end

   return config
end

local tlconfig = get_config()

--------------------------------------------------------------------
-- Warnings
--------------------------------------------------------------------

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
   local w = {}
   local longest = 0
   for warning in pairs(tl.warning_kinds) do
      if #warning > longest then
         longest = #warning
      end
      table.insert(w, warning)
   end
   table.sort(w)
   log("Compiler warnings:")
   for _, v in ipairs(w) do
      log(" ", right_pad(v, longest), " : ",
         disabled_warnings[v] and "disabled"
         or warning_errors[v] and "promoted to error"
         or "enabled"
      )
   end
   os.exit(0)
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
if cmd == "build" then
   tlconfig["source_dir"] = args["source_dir"] or tlconfig["source_dir"]
   tlconfig["build_dir"] = args["build_dir"] or tlconfig["build_dir"]
end
tlconfig["gen_target"] = args["gen_target"] or tlconfig["gen_target"]
tlconfig["gen_compat"] = args["gen_compat"] or tlconfig["gen_compat"]
                                            or (tlconfig["skip_compat53"] and "off")
if cmd == "gen" and args["output"] and #args["file"] ~= 1 then
   die("--output can only be used to map one input to one output")
end

for _, include in ipairs(tlconfig["include_dir"]) do
   prepend_to_lua_path(include)
end

--------------------------------------------------------------------
-- Pattern Matching
--------------------------------------------------------------------

local new_matcher
do
   local function match_str(str)
   end

   local patterns = {}
   local function make_pattern(str)
      if not patterns[str] then
         local chunks = {}
         for piece in str_split(str, "**/") do
            table.insert(chunks, (piece:gsub("%*", "[^/]-")))
         end
         chunks[1] = "^" .. chunks[1]
         chunks[#chunks] = chunks[#chunks] .. "$"
         patterns[str] = chunks
      end
      return patterns[str]
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

   local Matcher = {}

   function Matcher:match(str)
      for i, patt_str in ipairs(self) do
         if patt_match(make_pattern(patt_str), str) then
            return i
         end
      end
   end

   function Matcher:add_pattern(pattstr)
      table.insert(self, pattstr)
   end

   new_matcher = function(t)
      return setmetatable(t or {}, { __index = Matcher })
   end
end

--------------------------------------------------------------------
-- Filesystem Helpers
--------------------------------------------------------------------

local read_file, parse_file
do
   local read_cache = {}
   read_file = function(fname)
      if not read_cache[fname] then
         local fh, err = io.open(fname)
         if not fh then
            return nil, err
         end
         read_cache[fname] = fh:read("*a")
         fh:close()
      end
      return read_cache[fname]
   end

   local parse_cache = {}
   parse_file = function(fname)
      if not parse_cache[fname] then
         local content = read_file(fname)
         local tks, errs = tl.lex(content)
         if errs then
            return nil, errs
         end
         local parse_errs = {}
         parse_cache[fname] = { select(2, tl.parse_program(tks, parse_errs, fname)) }
      end
      return parse_cache[fname][1], parse_cache[fname][2]
   end
end

local scan_dir
do
   local function dir_iter(dirname)
      for file in lfs.dir(dirname) do
         if file:sub(1, 1) ~= "." then
            local full_path = path_concat(dirname, file)
            if is_dir(full_path) then
               dir_iter(full_path)
            else
               coroutine.yield(full_path)
            end
         end
      end
   end

   scan_dir = function(dirname, include_matcher, exclude_matcher)
      return coroutine.wrap(function()
         for file in coroutine.wrap(dir_iter), dirname do
            local sub_path = remove_leading_path(dirname, file)

            local include = true
            if #include_matcher > 0 then
               local idx = include_matcher:match(sub_path)
               if not idx then
                  include = false
               end
            end
            if include and #exclude_matcher > 0 then
               local idx = exclude_matcher:match(sub_path)
               if idx then
                  include = false
               end
            end
            if include then
               coroutine.yield(file)
            end
         end
      end)
   end
end

local function delete_dir(dir)
   for file in lfs.dir(dir) do
      if file ~= "." and file ~= ".." then
         local file_path = path_concat(dir, file)
         if file ~= "." and file ~= ".." then
            if is_file(file_path) then
               os.remove(file_path)
            elseif is_dir(file_path) then
               delete_dir(file_path)
            end
         end
      end
   end
   lfs.rmdir(dir)
end

local build_path
local function cleanup_generated_files()
   if build_path then
      delete_dir(build_path)
   end
end

--------------------------------------------------------------------
-- Environment
--------------------------------------------------------------------

local exit = 0

local function setup_env(filename)
   local _, extension = extension_split(filename)

   local lax_mode
   if extension == "tl" then
      lax_mode = false
   elseif extension == "lua" then
      lax_mode = true
   else
      -- if we can't decide based on the file extension, default to strict mode
      lax_mode = false
   end

   local gen_compat = tlconfig["gen_compat"]
   local gen_target = tlconfig["gen_target"]

   local env = tl.init_env(lax_mode, gen_compat, gen_target)

   if tlconfig.preload_modules then
      for _, mod in ipairs(tlconfig.preload_modules) do
         local modtype = tl.require_module(mod, lax_mode, env)
         if not modtype or modtype.typename == "unknown" then
            die("Unable to preload module '", mod, "'")
         end
      end
   end

   return env
end

local function get_output_filename(file_name)
   local tail = file_name:match("[^%" .. path_separator .. "]+$")
   if not tail then
      return
   end
   local name, ext = extension_split(tail)
   if not name then name = tail end
   if ext ~= "lua" then
      return name .. ".lua"
   else
      return name .. ".out.lua"
   end
end

local function type_check_file(file_name, env)
   local result, err = tl.process(file_name, env)
   if err then
      die(err)
   end

   local has_syntax_errors = report_errors("syntax error", result.syntax_errors)
   if has_syntax_errors then
      exit = 1
   end

   local ok = report_result(result)
   if not ok then
      exit = 1
   end

   if exit == 0 and #args["file"] == 1 then
      local output_file = get_output_filename(file_name)
      log("========================================")
      log("Type checked ", file_name)
      log("0 errors detected -- you can use:\n")
      log("   tl run ", file_name, "\n")
      log("       to run ", file_name, " as a program\n")
      log("   tl gen ", file_name, "\n")
      log("       to generate", output_file)
   end
   return result
end

local function type_check_and_load(filename, env)
   env = env or setup_env(filename)
   local result, err = tl.process(filename, env)
   if err then
      die(err)
   end

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
      die("Internal Compiler Error: Teal generator produced invalid Lua. Please report a bug at https://github.com/teal-language/tl\n\n", tostring(err))
   end
   return chunk
end

--------------------------------------------------------------------
-- Run
--------------------------------------------------------------------

if cmd == "run" then
   local env = setup_env(args["script"][1])
   local chunk = type_check_and_load(args["script"][1], env)

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

   assert(not is_turbo_on)

   return chunk((unpack or table.unpack)(arg))
end

--------------------------------------------------------------------
-- Check
--------------------------------------------------------------------

if cmd == "check" then
   turbo(true)
   local env = setup_env(args["file"][1])
   for i, input_file in ipairs(args["file"]) do
      type_check_file(input_file, env)
      if i > 1 then
         collectgarbage()
      end
   end
   os.exit(exit)
end


--------------------------------------------------------------------
--                           TYPES                                --
--------------------------------------------------------------------

local json_special_codes = "[%z\1-\31\34\92]"
-- %z is deprecated in Lua 5.2+; switch over if it stops working
if not ("\0"):match("%z") then
   json_special_codes = "[\0-\31\34\92]"
end

local function json_escape(s)
   return "\\u" .. string.format("%04x", s:byte())
end

local function json_out(fd, x)
   local tx = type(x)
   if tx == "string" then
      fd:write('"' .. x:gsub(json_special_codes, json_escape) .. '"')
      return
   elseif tx == "number" then
      fd:write(tostring(x))
      return
   end
   assert(tx == "table")
   if x[0] == false then -- special array marker for json dump
      fd:write("[")
      local l = #x
      local colon = "," .. (#x < 10 and "" or "\n")
      for i, v in ipairs(x) do
         json_out(fd, v)
         if i < l then
            fd:write(colon)
         end
      end
      fd:write("]")
   else
      fd:write("{")
      local c = ""
      for k, v in pairs(x) do
         fd:write(string.format("%s%q:", c, tostring(k)))
         c = ",\n"
         json_out(fd, v)
      end
      fd:write("}")
   end
end

if cmd == "types" then
   turbo(true)
   tlconfig["quiet"] = true
   tlconfig["gen_compat"] = "off"

   setup_env(args["file"][1])
   env.keep_going = true

   local tr, trenv
   local errs = false
   for i, input_file in ipairs(args["file"]) do
      local pok, result = pcall(type_check_file, input_file)
      if pok then
         if result and result.ast then
            tr, trenv = tl.get_types(result, trenv)
         end
         if #result.warnings > 0 or #result.syntax_errors > 0 or #result.type_errors > 0 then
            errs = true
         end
      else
         errs = true
      end
      if i > 1 then
         collectgarbage()
      end
   end
   if tr then
      if errs then
         printerr("")
      end

      local pos = args["position"]
      if pos then
         local y, x = pos:match("^(%d+):?(%d*)")
         y = tonumber(y) or 1
         x = tonumber(x) or 1
         json_out(io.stdout, tl.symbols_in_scope(tr, y, x))
      else
         json_out(io.stdout, tr)
      end

   end
   os.exit(exit)
end

--------------------------------------------------------------------
-- Gen
--------------------------------------------------------------------

local function write_out(txt, output_file)
   if args["pretend"] then
      log("Would Write: " .. output_file)
   else
      local ofd, ok, err
      ofd, err = io.open(output_file, "w")

      if not ofd then
         die("cannot write ", output_file, ": ", err)
      end

      ok, err = ofd:write(txt, "\n")
      if err then
         die("error writing ", output_file, ": ", err)
      end

      ofd:close()
      log("Wrote: ", output_file)
   end
end

if cmd == "gen" then
   turbo(true)
   local results = {}
   local err
   for i, input_file in ipairs(args["file"]) do
      local env = setup_env(input_file)
      local res = {
         input_file = input_file,
         output_file = get_output_filename(input_file)
      }

      res.tl_result, err = tl.process(input_file, env)
      if err then
         die(err)
      end
      env = res.tl_result.env

      if #res.tl_result.syntax_errors > 0 then
         exit = 1
      end
      table.insert(results, res)
      if i > 1 then
         collectgarbage()
      end
   end
   if exit ~= 0 then
      for i, res in ipairs(results) do
         if #res.tl_result.syntax_errors > 0 then
            report_errors("syntax error", res.tl_result.syntax_errors)
         end
      end
   else
      for i, res in ipairs(results) do
         write_out(tl.pretty_print_ast(res.tl_result.ast), args["output"] or res.output_file)
      end
   end
   os.exit(exit)
end

--------------------------------------------------------------------
-- Build
--------------------------------------------------------------------

-- load build script (if neccesary)
local build_script = {}
if is_file(tlconfig.build_file) then
   local chunk = type_check_and_load(tlconfig.build_file)
   build_script = pcall_or_die(chunk, "Error in build script: ")
end

-- validate build script
for _, key_type in ipairs{
   {"gen_code", "function"},
   {"after", "function"},
} do
   nil_type_check_or_die(build_script[key_type[1]], key_type[2], ("Type error in build script %s: "):format(key_type[1]))
end

if build_script.gen_code then
   pcall_or_die(function()
      build_script.gen_code(tlconfig.build_file_output_dir)
   end, "Error in gen_code: ")
end

-- prepare build and source dirs
local inc, exc = new_matcher(), new_matcher()

local files = {}
if cmd == "build" then
   if tlconfig["source_dir"] then
      tlconfig["source_dir"] = cleanup_file_name(tlconfig["source_dir"])
      if tlconfig["source_dir"] == "" then
         tlconfig["source_dir"] = "."
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
         inc:add_pattern(patt)
      end
   end
   if tlconfig["exclude"] then
      for i, patt in ipairs(tlconfig["exclude"]) do
         patt = cleanup_file_name(patt)
         exc:add_pattern(patt)
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
               die("Build error: expected ", v, " to be a directory")
            end
         end
      end
   end

   if tlconfig["files"] then
      for i, fname in ipairs(tlconfig["files"]) do
         if is_absolute_path(fname) then
            die("Build error: in config, ", fname, " (files[", i, "]), files must be relative")
         end
         if not is_file(fname) then
            die("Build error: ", fname, " is not a file")
         end
         local outfile = fname
         if tlconfig["build_dir"] then
            if tlconfig["source_dir"] then
               outfile = remove_leading_path(tlconfig["source_dir"], outfile)
            end
            outfile = path_concat(tlconfig["build_dir"], outfile)
         end
         local base, ext = extension_split(outfile)
         outfile = base .. (ext == ".lua" and ".out.lua" or ".lua")
         files[fname] = outfile
         check_parent_dirs(outfile)
      end
   end

   local source_dir = tlconfig["source_dir"] or "."
   if not is_dir(source_dir) then
      die("Build error: source_dir '", source_dir, "' is not a directory")
   end

   if (tlconfig["files"] and (#inc > 0 or #exc > 0)) or not tlconfig["files"] then
      for path in scan_dir(source_dir, inc, exc) do
         local basename, ext = extension_split(path, 2)
         if ext == ".tl" and not files[path] then
            local outfile = basename .. ".lua"
            if tlconfig["build_dir"] then
               if tlconfig["source_dir"] then
                  outfile = remove_leading_path(tlconfig["source_dir"], outfile)
               end
               outfile = path_concat(tlconfig["build_dir"], outfile)
            end
            check_parent_dirs(outfile)
            files[path] = outfile
         end
      end
   end

   for i, v in ipairs(dirs_to_be_mked) do
      if not lfs.mkdir(v) then
         die("Build error: unable to mkdir \"", v, "\"")
      end
      log("Created directory: ", v)
   end
end

--------------------------------------------------------------------
-- Build
--------------------------------------------------------------------
turbo(true)


--[[
local record Node
   input: string
   output: string
   modules: {string:string}
   marked: boolean
   dependents: {Node}
end
dag: {string:Node}
-- dag = directed acyclic graph
]]
local dag = {}
for input, output in pairs(files) do
   if input ~= tlconfig.build_file then
      local _, require_calls = parse_file(input)
      local modules = {}
      for _, req in ipairs(require_calls) do
         local mod_name = req.e2[1].conststr
         local found, fd = tl.search_module(mod_name, true)
         if found then
            modules[mod_name] = found
            fd:close()
         end
      end
      dag[input] = {
         input = input,
         output = output,
         modules = modules,
         dependents = {},
         marked = false,
      }
   end
end

for file, node in pairs(dag) do
   for _, mod_file in pairs(node.modules) do
      local dep_node = dag[mod_file]
      if dep_node then
         table.insert(dep_node.dependents, node)
      end
   end
end

local function mark_for_update(node)
   if node.marked then return end -- if a node is marked so are its children
   node.marked = true
   for _, dep in ipairs(node.dependents) do
      mark_for_update(dep)
   end
end

local function should_update(input, output)
   local in_mod = lfs.attributes(input, "modification")
   local out_mod = lfs.attributes(output, "modification")
   if not out_mod then
      return true
   end
   return in_mod > out_mod
end

for file, node in pairs(dag) do
   if should_update(file, node.output) then
      mark_for_update(node)
   end
end

local nodes_to_process = {}
for file, node in pairs(dag) do
   if node.marked then
      table.insert(nodes_to_process, node)
   end
end

if #nodes_to_process == 0 then
   log("All files up to date")
   os.exit(0)
end

table.sort(nodes_to_process, function(a, b)
   return #b.dependents < #a.dependents
end)

local env = setup_env()
for i, node in ipairs(nodes_to_process) do
   local input, output = node.input, node.output
   local ast = parse_file(input)

   local type_errors = tl.type_check(ast, {
      filename = input,
      env = env,
   })
   if report_errors("type error", type_errors) then
      exit = 1
   else
      local code = tl.pretty_print_ast(ast)
      write_out(code, output)
   end
   if i > 1 then
      collectgarbage()
   end
end

if exit == 0 and build_script.after then
   pcall_or_die(build_script.after, "Error in after: ")
end

os.exit(exit)

