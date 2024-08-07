#!/usr/bin/env lua

-- Little trick for running development versions:
-- when tl.lua and tl are in the same folder, prefer that tl.lua
local tl
do
   local script_path = debug.getinfo(1, "S").source:match("^@?(.*[/\\])") or "."
   local save_package_path = package.path
   package.path = script_path .. "/?.lua;" .. package.path

   tl = require("tl")

   -- but otherwise don't pollute package.path inadvertedly
   package.path = save_package_path
end

local argparse = require("argparse")

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

local PATH_SEPARATOR = package.config:sub(1, 1)

local turbo
local is_turbo_on
do
   local tl_lex = tl.lex
   local turbo_is_on = false

   turbo = function(on)
      if on then
         if jit then
            jit.off()
            tl.lex = function(input, filename)
               jit.on()
               local r1, r2 = tl_lex(input, filename)
               jit.off()
               return r1, r2
            end
         end
         collectgarbage("stop")
      else
         if jit then
            jit.on()
            tl.lex = tl_lex
         end
         collectgarbage("restart")
      end
      turbo_is_on = on
   end

   is_turbo_on = function()
      return turbo_is_on
   end
end

local function check_collect(i)
   if i % 50 == 0 then
      collectgarbage()
   end
end

local function printerr(s)
   io.stderr:write(s .. "\n")
end

local function die(msg)
   printerr(msg)
   os.exit(1)
end

local function find_in_sequence(seq, value)
   for _, v in ipairs(seq) do
      if v == value then
         return true
      end
   end

   return false
end

local function keys(t)
   local ks = {}
   local n = 0
   for k, _ in pairs(t) do
      n = n + 1
      ks[n] = k
   end
   table.sort(ks)
   return ks, n
end

local function prepend_to_lua_paths(directory)
   local path_str = directory
   local shared_library_ext = package.cpath:match("%.(%w+)%s*$") or "so"

   if string.sub(path_str, -1) == PATH_SEPARATOR then
      path_str = path_str:sub(1, -2)
   end

   path_str = path_str .. PATH_SEPARATOR

   local lib_path_str = path_str .. "?." .. shared_library_ext .. ";"
   local lua_path_str = path_str .. "?.lua;" .. path_str .. "?/init.lua;"

   package.path = lua_path_str .. package.path
   package.cpath = lib_path_str .. package.cpath
end

local function find_file_in_parent_dirs(fname)
   for _ = 1, 20 do
      local fd = io.open(fname, "rb")
      if fd then
         fd:close()
         return fname
      end
      fname = ".." .. PATH_SEPARATOR .. fname
   end
end

local function filename_to_module_name(filename)
   local path = os.getenv("TL_PATH") or package.path
   for entry in path:gmatch("[^;]+") do
      entry = entry:gsub("%.", "%%.")
      local lua_pat = "^" .. entry:gsub("%?", ".+") .. "$"
      local d_tl_pat = lua_pat:gsub("%%.lua%$", "%%.d%%.tl$")
      local tl_pat = lua_pat:gsub("%%.lua%$", "%%.tl$")

      for _, pat in ipairs({ tl_pat, d_tl_pat, lua_pat }) do
         local cap = filename:match(pat)
         if cap then
            return (cap:gsub("[/\\]", "."))
         end
      end
   end

   -- fallback:
   return (filename:gsub("%.lua$", ""):gsub("%.d%.tl$", ""):gsub("%.tl$", ""):gsub("[/\\]", "."))
end

--------------------------------------------------------------------------------
-- Common driver backend
--------------------------------------------------------------------------------

local function setup_env(tlconfig, filename)
   local _, extension = filename:match("(.*)%.([a-z]+)$")
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

   tlconfig._init_env_modules = tlconfig._init_env_modules or {}
   if tlconfig.global_env_def then
      table.insert(tlconfig._init_env_modules, 1, tlconfig.global_env_def)
   end

   local opts = {
      defaults = {
         feat_lax = lax_mode and "on" or "off",
         feat_arity = tlconfig["feat_arity"],
         gen_compat = tlconfig["gen_compat"],
         gen_target = tlconfig["gen_target"],
      },
      predefined_modules = tlconfig._init_env_modules,
   }

   local env, err = tl.new_env(opts)
   if not env then
      die(err)
   end

   return env
end

local function filter_warnings(tlconfig, result)
   if not result.warnings then
      return
   end
   for i = #result.warnings, 1, -1 do
      local w = result.warnings[i]
      if tlconfig._disabled_warnings_set[w.tag] then
         table.remove(result.warnings, i)
      elseif tlconfig._warning_errors_set[w.tag] then
         local err = table.remove(result.warnings, i)
         table.insert(result.type_errors, err)
      end
   end
end

local report_all_errors
do
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
         printerr("----------------------------------------")
         printerr(n .. " " .. category .. (n ~= 1 and "s" or ""))
         return true
      end
      return false
   end

   report_all_errors = function(tlconfig, env, syntax_only)
      local any_syntax_err, any_type_err, any_warning
      for _, name in ipairs(env.loaded_order) do
         local result = env.loaded[name]

         local syntax_err = report_errors("syntax error", result.syntax_errors)
         if syntax_err then
            any_syntax_err = true
         elseif not syntax_only then
            filter_warnings(tlconfig, result)
            any_warning = report_errors("warning", result.warnings) or any_warning
            any_type_err = report_errors("error", result.type_errors) or any_type_err
         end
      end
      local ok = not (any_syntax_err or any_type_err)
      return ok, any_syntax_err, any_type_err, any_warning
   end
end

local function process_module(filename, env)
   local module_name = filename_to_module_name(filename)
   local result, err = tl.process(filename, env)
   if result then
      env.modules[module_name] = result.type
   end
   return result, err
end

local function type_check_and_load(tlconfig, filename)
   local env = setup_env(tlconfig, filename)
   local result, err = process_module(filename, env)
   if err then
      die(err)
   end

   local is_tl = filename:match("%.tl$")
   local _, syntax_err, type_err = report_all_errors(tlconfig, env, not is_tl)
   if syntax_err then
      os.exit(1)
   end

   if is_tl and type_err then
      os.exit(1)
   end

   local chunk; chunk, err = (loadstring or load)(tl.pretty_print_ast(result.ast, tlconfig.gen_target), "@" .. filename)
   if err then
      die("Internal Compiler Error: Teal generator produced invalid Lua. " ..
          "Please report a bug at https://github.com/teal-language/tl\n\n" .. tostring(err))
   end
   return chunk
end

local function write_out(tlconfig, result, output_file, pp_opts)
   if tlconfig["pretend"] then
      print("Would Write: " .. output_file)
      return
   end

   local ofd, err = io.open(output_file, "wb")

   if not ofd then
      die("cannot write " .. output_file .. ": " .. err)
   end

   local _
   _, err = ofd:write(tl.pretty_print_ast(result.ast, tlconfig.gen_target, pp_opts) .. "\n")
   if err then
      die("error writing " .. output_file .. ": " .. err)
   end

   ofd:close()

   if not tlconfig["quiet"] then
      print("Wrote: " .. output_file)
   end
end

--------------------------------------------------------------------------------
-- Driver utilities
--------------------------------------------------------------------------------

local function validate_config(config)
   local errs, warnings = {}, {}

   local function warning(k, fmt, ...)
      table.insert(warnings, string.format("* in key \"" .. k .. "\": " .. fmt, ...))
   end
   local function fail(k, fmt, ...)
      table.insert(errs, string.format("* in key \"" .. k .. "\": " .. fmt, ...))
   end

   local function check_warnings(key)
      if config[key] then
         local unknown = {}
         for _, warning in ipairs(config[key]) do
            if not tl.warning_kinds[warning] then
               table.insert(unknown, string.format("%q", warning))
            end
         end
         if #unknown > 0 then
            warning(key, "Unknown warning%s in config: %s", #unknown > 1 and "s" or "", table.concat(unknown, ", "))
         end
      end
   end

   local valid_keys = {
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

   for k, v in pairs(config) do
      if k == "preload_modules" then
         fail(k, "this key is no longer supported. To load a definition globally into the environment, use global_env_def.")
      elseif not valid_keys[k] then
         -- skip invalid keys, to be used by other tools
      elseif type(valid_keys[k]) == "table" then
         if not valid_keys[k][v] then
            fail(k, "expected one of: %s", table.concat(keys(valid_keys[k][v]), ", "))
         end
      else
         -- TODO: could we type-check the config file using tl?
         local arr_type = valid_keys[k]:match("{(.*)}")
         if arr_type and type(v) == "table" then
            for i, val in ipairs(v) do
               if type(val) ~= arr_type then
                  fail(k, "expected a %s, got %s in position %d", valid_keys[k], type(val), i)
               end
            end
         elseif type(v) ~= valid_keys[k] then
            fail(k, "expected a %s, got %s", valid_keys[k], type(v))
         end
      end
   end

   if config.skip_compat53 then
      config.gen_compat = "off"
   end

   check_warnings("disable_warnings")
   check_warnings("warning_error")

   return errs, warnings
end

local function get_args_parser()
   local parser = argparse("tl", "A minimalistic typed dialect of Lua.")

   parser:option("--global-env-def", "Predefined types from a custom global environment.")
         :argname("<dtlfilename>")
         :count("*") -- count("1") does not work? we verify by hand below then

   parser:option("-I --include-dir", "Prepend this directory to the module search path.")
         :argname("<directory>")
         :count("*")

   parser:option("--wdisable", "Disable the given kind of warning.")
         :argname("<warning>")
         :count("*")

   parser:option("--werror", "Promote the given kind of warning to an error. " ..
                             "Use '--werror all' to promote all warnings to errors")
         :argname("<warning>")
         :count("*")

   parser:option("--feat-arity", "Define minimum arities for functions based on optional argument annotations.")
         :choices({ "off", "on" })

   parser:option("--gen-compat", "Generate compatibility code for targeting different Lua VM versions.")
         :choices({ "off", "optional", "required" })
         :default("optional")
         :defmode("a")

   parser:option("--gen-target", "Minimum targeted Lua version for generated code.")
         :choices({ "5.1", "5.3", "5.4" })

   parser:flag("--skip-compat53", "Skip compat53 insertions.")
         :hidden(true)
         :action(function(args) args.gen_compat = "off" end)

   parser:flag("--version", "Print version and exit")

   parser:flag("-q --quiet", "Do not print information messages to stdout. Errors may still be printed to stderr.")

   parser:flag("-p --pretend", "Do not write to any files, type check and output what files would be generated.")

   parser:require_command(false)
   parser:command_target("command")

   local check_command = parser:command("check", "Type-check one or more Teal files.")
   check_command:argument("file", "The Teal source file."):args("+")

   local gen_command = parser:command("gen", "Generate a Lua file for one or more Teal files.")
   gen_command:argument("file", "The Teal source file."):args("+")
   gen_command:flag("-c --check", "Type check and fail on type errors.")
   gen_command:flag("--keep-hashbang", "Preserve hashbang line (#!) at the top of file if present.")
   gen_command:option("-o --output", "Write to <filename> instead.")
              :argname("<filename>")

   local run_command = parser:command("run", "Run a Teal script.")
   run_command:argument("script", "The Teal script."):args("+")

   run_command:option("-l --require", "Require module for execution.")
              :argname("<modulename>")
              :count("*")

   parser:command("warnings", "List each kind of warning the compiler can produce.")

   local types_command = parser:command("types", "Report all types found in one or more Teal files")
   types_command:argument("file", "The Teal source file."):args("+")
   types_command:option("-p --position", "Report values in scope in position line[:column]")
              :argname("<position>")

   return parser
end

local function get_config(cmd)
   local config = {
      include_dir = {},
      disable_warnings = {},
      warning_error = {},
      quiet = false
   }

   local config_path = find_file_in_parent_dirs("tlconfig.lua") or "tlconfig.lua"

   local conf, err
   local conf_fd = io.open(config_path, "r")
   if conf_fd then
      local conf_text = conf_fd:read("*a")
      if conf_text then
         conf, err = (loadstring or load)(conf_text)
         if not conf then
            die("Error loading tlconfig.lua:\n" .. err)
         end
      end
   end

   if conf then
      local ok, user_config = pcall(conf)
      if not ok then
         err = user_config
         die("Error loading tlconfig.lua:\n" .. err)
      end

      -- Merge tlconfig with the default config
      if user_config then
         for k, v in pairs(user_config) do
            config[k] = v
         end
      end
   end

   local errs, warnings = validate_config(config)

   if #errs > 0 then
      die("Error loading tlconfig.lua:\n" .. table.concat(errs, "\n"))
   end

   return config, warnings
end

local function merge_config_and_args(tlconfig, args)
   do
      local default_true_mt = { __index = function() return true end }
      local function enable(tab, warning)
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

   if args["global_env_def"] then
      if #args["global_env_def"] > 1 then
         die("Error: --global-env-def can be used only once.")
      elseif args["global_env_def"][1] then
         tlconfig["global_env_def"] = args["global_env_def"][1]
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
   for _, include in ipairs(tlconfig["include_dir"]) do
      prepend_to_lua_paths(include)
   end
end

local function get_output_filename(file_name)
   local tail = file_name:match("[^%" .. PATH_SEPARATOR .. "]+$")
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

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

local commands = {}

--------------------------------------------------------------------------------
-- tl warnings
--------------------------------------------------------------------------------

commands["warnings"] = function(tlconfig)
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
      if tlconfig._disabled_warnings_set[v] then
         io.write("disabled")
      elseif tlconfig._warning_errors_set[v] then
         io.write("promoted to error")
      else
         io.write("enabled")
      end
      io.write("\n")
   end
   os.exit(0)
end

--------------------------------------------------------------------------------
-- tl run
--------------------------------------------------------------------------------

commands["run"] = function(tlconfig, args)
   if args["require"] then
      tlconfig._init_env_modules = {}
      for _, module in ipairs(args["require"]) do
         table.insert(tlconfig._init_env_modules, module)
      end
   end

   local chunk = type_check_and_load(tlconfig, args["script"][1])

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

   assert(not is_turbo_on())

   for _, module in ipairs(args["require"]) do
      require(module)
   end

   return chunk((unpack or table.unpack)(arg))
end

--------------------------------------------------------------------------------
-- tl check
--------------------------------------------------------------------------------

local function split_drive(filename)
   if PATH_SEPARATOR == "\\" then
      local d, r = filename:match("^(.:)(.*)$")
      if d then
         return d, r
      end
   end
   return "", filename
end

local cd_cache
local function cd()
   if cd_cache then
      return cd_cache
   end
   local wd = os.getenv("PWD")
   if not wd then
      local pd = io.popen("cd", "rb")
      wd = pd:read("*l")
      pd:close()
   end
   cd_cache = wd
   return wd
end

local function normalize(filename)
   local drive = ""

   if PATH_SEPARATOR == "\\" then
      filename = filename:gsub("\\", "/")
      drive, filename = split_drive(filename)
   end

   if filename:sub(1, 1) ~= "/" then
      filename = cd() .. "/" .. filename
      drive, filename = split_drive(filename)
   end

   local root = ""
   if filename:sub(1, 1) == "/" then
      root = "/"
   end

   local pieces = {}
   for piece in filename:gmatch("[^/]+") do
      if piece == ".." then
         local prev = pieces[#pieces]
         if not prev or prev == ".." then
            table.insert(pieces, "..")
         elseif prev ~= "" then
            table.remove(pieces)
         end
      elseif piece ~= "." then
         table.insert(pieces, piece)
      end
   end

   filename = (drive .. root .. table.concat(pieces, "/")):gsub("/*$", "")

   if PATH_SEPARATOR == "\\" then
      filename = filename:gsub("/", "\\")
   end

   return filename
end

local function already_loaded(env, input_file)
   input_file = normalize(input_file)
   for file, _ in pairs(env.loaded) do
      if normalize(file) == input_file then
         return true
      end
   end
   return false
end

commands["check"] = function(tlconfig, args)
   turbo(true)
   local env
   for i, input_file in ipairs(args["file"]) do
      if not env then
         env = setup_env(tlconfig, input_file)
      end
      if not already_loaded(env, input_file) then
         local _, err = process_module(input_file, env)
         if err then
            die(err)
         end
      end

      check_collect(i)
   end

   local ok = report_all_errors(tlconfig, env)

   if ok and tlconfig["quiet"] == false and #args["file"] == 1 then
      local file_name = args["file"][1]

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

   os.exit(ok and 0 or 1)
end

--------------------------------------------------------------------------------
-- tl gen
--------------------------------------------------------------------------------

commands["gen"] = function(tlconfig, args)
   if args["output"] and #args["file"] ~= 1 then
      print("Error: --output can only be used to map one input to one output")
      os.exit(1)
   end

   turbo(true)
   local results = {}
   local err
   local env
   local pp_opts
   for i, input_file in ipairs(args["file"]) do
      if not env then
         env = setup_env(tlconfig, input_file)
         pp_opts = {
            preserve_indent = true,
            preserve_newlines = true,
            preserve_hashbang = args["keep_hashbang"]
         }
      end

      local res = {
         input_file = input_file,
         output_file = get_output_filename(input_file)
      }

      res.tl_result, err = process_module(input_file, env)
      if err then
         die(err)
      end

      table.insert(results, res)
      check_collect(i)
   end

   for _, res in ipairs(results) do
      if #res.tl_result.syntax_errors == 0 then
         write_out(tlconfig, res.tl_result, args["output"] or res.output_file, pp_opts)
      end
   end

   local ok = report_all_errors(tlconfig, env, not args["check"])

   os.exit(ok and 0 or 1)
end

--------------------------------------------------------------------------------
-- tl types
--------------------------------------------------------------------------------

do
   local json_special_codes = "[%z\1-\31\34\92]"
   -- %z is deprecated in Lua 5.2+; switch over if it stops working
   if not ("\0"):match("%z") then
      json_special_codes = "[\0-\31\34\92]"
   end

   local function json_escape(s)
      return "\\u" .. string.format("%04x", s:byte())
   end

   local function json_out_table(fd, x)
      if x[0] == false then -- special array marker for json dump
         local l = #x
         if l == 0 then
            fd:write("[]")
            return
         end
         fd:write("[")
         local sep = l < 10 and "," or ",\n"
         for i, v in ipairs(x) do
            if i == l then
               sep = "]"
            end
            local tv = type(v)
            if tv == "number" then
               fd:write(v, sep)
            elseif tv == "table" then
               json_out_table(fd, v)
               fd:write(sep)
            elseif tv == "string" then
               fd:write('"', v:gsub(json_special_codes, json_escape), '"', sep)
            else
               fd:write(tostring(v), sep)
            end
         end
      else
         local ks, l = keys(x)
         if l == 0 then
            fd:write("{}")
            return
         end
         fd:write("{\"")
         local sep = ",\n\""
         for i, k in ipairs(ks) do
            if i == l then
               sep = "}"
            end
            local v = x[k]
            local sk = type(k) == "string" and k:gsub(json_special_codes, json_escape) or k
            local tv = type(v)
            if tv == "number" then
               fd:write(sk, '":', v, sep)
            elseif tv == "table" then
               fd:write(sk, '":')
               json_out_table(fd, v)
               fd:write(sep)
            elseif tv == "string" then
               fd:write(sk, '":"', v:gsub(json_special_codes, json_escape), '"', sep)
            else
               fd:write(sk, '":', tostring(v), sep)
            end
         end
      end
   end

   commands["types"] = function(tlconfig, args)
      turbo(true)
      tlconfig["quiet"] = true
      tlconfig["gen_compat"] = "off"

      local env = setup_env(tlconfig, args["file"][1])
      env.keep_going = true
      env.report_types = true

      for i, input_file in ipairs(args["file"]) do
         local pok, perr, err = pcall(process_module, input_file, env)
         if not pok then
            die("Internal Compiler Error: " .. perr)
         end
         if err then
            printerr(err)
         end

         check_collect(i)
      end

      local ok, _, _, w = report_all_errors(tlconfig, env)

      if not env.reporter then
         os.exit(1)
      end

      local tr = env.reporter:get_report()
      if tr then
         if w or not ok then
            printerr("")
         end

         local pos = args["position"]
         if pos then
            local y, x = pos:match("^(%d+):?(%d*)")
            y = tonumber(y) or 1
            x = tonumber(x) or 1
            json_out_table(io.stdout, tl.symbols_in_scope(tr, y, x))
         else
            json_out_table(io.stdout, tr)
         end

      end
      os.exit(ok and 0 or 1)
   end
end

--------------------------------------------------------------------------------
-- Main program
--------------------------------------------------------------------------------

local parser = get_args_parser()

local args = parser:parse()

if args["version"] then
   print(tl.version())
   os.exit(0)
end

local cmd = args["command"]
if not cmd then
   print(parser:get_usage())
   print()
   print("Error: a command is required")
   os.exit(1)
end

local tlconfig, cfg_warnings = get_config(cmd)
merge_config_and_args(tlconfig, args)
if not args["quiet"] then
   for _, v in ipairs(cfg_warnings) do
      printerr(v)
   end
end

commands[cmd](tlconfig, args)
