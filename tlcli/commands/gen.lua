local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local os = _tl_compat and _tl_compat.os or os; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table



local common = require("tlcli.common")
local driver = require("tlcli.driver")
local perf = require("tlcli.perf")
local report = require("tlcli.report")
local lfs = require("lfs")








local mkdir_cache = {}

local function make_dir_for(pathname)
   local normalized, root = common.normalize(pathname)
   local dirname = normalized:match("^(.*" .. common.sep .. ")[^" .. common.sep .. "]+$")

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

local function write_out(tlconfig, module, output_file, gen_opts, tree)
   assert(module)
   local is_stdout = output_file == "-"
   local prettyname = is_stdout and "<stdout>" or output_file
   if tlconfig["pretend"] then
      print("Would Write: " .. prettyname)
      return
   end

   local ofd, err
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

   local _
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

return function(tlconfig, args)
   if args["output"] and #args["file"] ~= 1 then
      print("Error: --output can only be used to map one input to one output")
      os.exit(1)
   end

   perf.turbo(true)

   local mods = {}
   local compiler = driver.setup_compiler(tlconfig)
   local gen_opts = {
      preserve_indent = true,
      preserve_newlines = true,
      preserve_hashbang = args["keep_hashbang"],
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
