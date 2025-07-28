local util = require("spec.util")

describe("teal.loader", function()
   setup(util.chdir_setup)
   teardown(util.chdir_teardown)
   it("loads and reports filename correctly in debug info (#508)", function()
      local dir_name = util.write_tmp_dir(finally, {
         ["file1.tl"] = [[
         return {
            get_src = function()
               return debug.getinfo(1, "S").source
            end
         }
         ]],
         ["main.lua"] = [[
         local teal = require("teal.init")
         teal.loader()
         file1 = require("file1")
         print(file1.get_src())
         ]]
      })
      local pd, output
      util.do_in(dir_name, function()
         pd = io.popen(util.lua_cmd("main.lua"), "r")
         output = pd:read("*a")
      end)
      util.assert_popen_close(0, pd:close())
      util.assert_line_by_line([[
         @.]] .. util.os_sep .. [[file1.tl
      ]], output)
   end)
end)
