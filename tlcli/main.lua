local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local os = _tl_compat and _tl_compat.os or os; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack



local argparse = require("argparse")
local teal = require("teal.init")
local common = require("tlcli.common")
local configuration = require("tlcli.configuration")



local function get_args_parser()
   local parser = argparse("tl", "A minimalistic typed dialect of Lua.")

   parser:add_complete_command()

   parser:option("--global-env-def", "Predefined types from a custom global environment."):
   argname("<dtlfilename>"):
   count("*")

   parser:option("-I --include-dir", "Prepend this directory to the module search path."):
   argname("<directory>"):
   count("*")

   local warnings = common.keys(teal.warning_set())

   parser:option("--wdisable", "Disable the given kind of warning."):
   argname("<warning>"):
   choices(warnings):
   count("*")

   parser:option("--werror", "Promote the given kind of warning to an error. " ..
   "Use '--werror all' to promote all warnings to errors"):
   argname("<warning>"):
   choices({ "all", _tl_table_unpack(warnings) }):
   count("*")

   parser:option("--feat-arity", "Define minimum arities for functions based on optional argument annotations."):
   choices({ "off", "on" })

   parser:option("--gen-compat", "Generate compatibility code for targeting different Lua VM versions."):
   choices({ "off", "optional", "required" }):
   default("optional"):
   defmode("a")

   parser:option("--gen-target", "Minimum targeted Lua version for generated code."):
   choices({ "5.1", "5.3", "5.4" })

   parser:flag("--skip-compat53", "Skip compat53 insertions."):
   hidden(true):
   action(function(args) args.gen_compat = "off" end)

   parser:flag("--version", "Print version and exit")

   parser:flag("-q --quiet", "Do not print information messages to stdout. Errors may still be printed to stderr.")

   parser:flag("-p --pretend", "Do not write to any files, type check and output what files would be generated.")

   parser:require_command(false)
   parser:command_target("command")

   local check_command = parser:command("check", "Type-check one or more Teal files.")
   check_command:argument("file", "The Teal source file."):args("+")

   local gen_command = parser:command("gen", "Generate a Lua file for one or more Teal files.")
   gen_command:argument("file", "The Teal source file."):args("+")
   gen_command:option("--root", "Interpret module paths relative to given root directory."):
   argname("<dir>")
   gen_command:flag("-c --check", "Type check and fail on type errors.")
   gen_command:flag("--keep-hashbang", "Preserve hashbang line (#!) at the top of file if present.")
   gen_command:option("-o --output", "Write to <filename> instead."):
   argname("<filename>")
   gen_command:option("--output-dir", "Base directory to use for output files. " ..
   "When combined with --root, the tree structure " ..
   "of the input files is preserved."):
   argname("<dir>")
   gen_command:option("--custom-ext", "Use a custom filename extension for generated output."):
   argname("<.ext>"):
   default(".lua")

   local run_command = parser:command("run", "Run a Teal script.")
   run_command:argument("script", "The Teal script."):args("+")

   run_command:option("-l --require", "Require module for execution."):
   argname("<modulename>"):
   count("*")

   parser:command("warnings", "List each kind of warning the compiler can produce.")

   local types_command = parser:command("types", "Report all types found in one or more Teal files")
   types_command:argument("file", "The Teal source file."):args("+")
   types_command:option("-p --position", "Report values in scope in position line[:column]"):
   argname("<position>")

   return parser
end

return function(...)
   local commands = {
      check = require("tlcli.commands.check"),
      gen = require("tlcli.commands.gen"),
      run = require("tlcli.commands.run"),
      types = require("tlcli.commands.types"),
      warnings = require("tlcli.commands.warnings"),
   }

   local parser = get_args_parser()

   local args = parser:parse(...)

   if args["version"] then
      print(teal.version())
      os.exit(0)
   end

   local cmd = args["command"]
   if not cmd then
      print(parser:get_usage())
      print()
      print("Error: a command is required")
      os.exit(1)
   end

   local tlconfig, cfg_warnings = configuration.get()
   configuration.merge_config_and_args(tlconfig, args)
   if cfg_warnings and not args["quiet"] then
      for _, v in ipairs(cfg_warnings) do
         common.printerr(v)
      end
   end

   commands[cmd](tlconfig, args)
end
