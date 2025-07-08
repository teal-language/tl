--------------------------------------------------------------------------------
-- tl check
--------------------------------------------------------------------------------

local common = require("tlcli.common")
local driver = require("tlcli.driver")
local perf = require("tlcli.perf")
local report = require("tlcli.report")

local type Args = require("tlcli.args")
local type TlConfig = require("tlcli.tlconfig")

return function(tlconfig: TlConfig, args: Args)
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
