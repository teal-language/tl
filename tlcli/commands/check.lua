local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local os = _tl_compat and _tl_compat.os or os



local common = require("tlcli.common")
local driver = require("tlcli.driver")
local perf = require("tlcli.perf")
local report = require("tlcli.report")




return function(tlconfig, args)
   perf.turbo(true)
   local compiler = driver.setup_compiler(tlconfig)
   for i, input_file in ipairs(args["file"]) do
      local _, _, err = driver.process_module(compiler, input_file)
      if err then
         common.die(err)
      end

      perf.check_collect(i)
   end

   local ok = report.report_all_errors(tlconfig, compiler)

   if ok and tlconfig["quiet"] == false and #args["file"] == 1 then
      local file_name = args["file"][1]

      local output_file = common.get_output_filename(file_name)
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
