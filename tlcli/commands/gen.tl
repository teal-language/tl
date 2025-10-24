--------------------------------------------------------------------------------
-- tl gen
--------------------------------------------------------------------------------

local common = require("tlcli.common")
local driver = require("tlcli.driver")
local perf = require("tlcli.perf")
local report = require("tlcli.report")
local lfs = require("lfs")

local type TlConfig = require("tlcli.tlconfig")
local type Args = require("tlcli.args")

local type teal = require("teal")
local type GenOptions = teal.GenOptions
local type Module = teal.Module

local mkdir_cache = {}

local function make_dir_for(pathname: string)
   local normalized, root = common.normalize(pathname)
   local dirname = normalized:match("^(.*" .. common.sep .. ")[^" .. common.sep .. "]+$")
   -- on Windows, root contains the drive letter and looks like `D:\`
   if dirname == root then
      return
   end
   if dirname then
      if mkdir_cache[dirname] then
         return
      end
      make_dir_for(dirname)
      lfs.mkdir(dirname)
      mkdir_cache[dirname] = true
   end
end

local function write_out(tlconfig: TlConfig, module: Module, output_file: string, gen_opts: GenOptions, tree: boolean)
   assert(module)
   local is_stdout = output_file == "-"
   local prettyname = is_stdout and "<stdout>" or output_file
   if tlconfig["pretend"] then
      print("Would Write: " .. prettyname)
      return
   end

   local ofd, err: FILE, string
   if is_stdout then
      ofd = io.output()
   else
      if tree then
         make_dir_for(output_file)
      end
      ofd, err = io.open(output_file, "wb")
      if not ofd then
         common.die("cannot write " .. prettyname .. ": " .. err)
      end
   end

   local lua_code = module:gen(gen_opts)

   local _: FILE
   _, err = ofd:write(lua_code, "\n")
   if err then
      common.die("error writing " .. prettyname .. ": " .. err)
   end

   if not is_stdout then
      ofd:close()
   end

   if not tlconfig["quiet"] then
      print("Wrote: " .. prettyname)
   end
end

return function(tlconfig: TlConfig, args: Args)
   if args["output"] and #args["file"] ~= 1 then
      print("Error: --output can only be used to map one input to one output")
      os.exit(1)
   end

   perf.turbo(true)

   local mods = {}
   local compiler = driver.setup_compiler(tlconfig)
   local gen_opts: GenOptions = {
      preserve_indent = true,
      preserve_newlines = true,
      preserve_hashbang = args["keep_hashbang"]
   }

   for i, input_file in ipairs(args["file"]) do
      local module, check_err, err = driver.process_module(compiler, input_file)
      if err then
         common.die(err)
      end

      table.insert(mods, {
         input_file = input_file,
         output_file = common.get_output_filename(input_file, args["root"], args["output_dir"], args["custom_ext"]),
         module = module,
         check_err = check_err,
      })

      perf.check_collect(i)
   end

   for _, mod in ipairs(mods) do
      if #mod.check_err.syntax_errors == 0 then
         local output_filename = args["output"] or mod.output_file
         assert(mod.module)
         write_out(tlconfig, mod.module, output_filename, gen_opts, not not args["root"])
      end
   end

   local ok = report.report_all_errors(tlconfig, compiler, not args["check"])

   os.exit(ok and 0 or 1)
end
