local util = require("spec.util")

describe("tl.loader", function()
   setup(util.chdir_setup)
   teardown(util.chdir_teardown)
   describe("on .tl files", function()
      it("reports filename correctly in debug info (#508)", function()
         local dir_name = util.write_tmp_dir(finally, {
            ["file1.tl"] = [[
            return {
               get_src = function()
                  return debug.getinfo(1, "S").source
               end
            }
            ]],
            ["main.lua"] = [[
            local tl = require("teal.api.v2")
            tl.loader()
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
      it("works properly with the package.loaded table", function()
         local dir_name = util.write_tmp_dir(finally, {
            ["module.lua"] = [[
               package.loaded['module'] = { worked = 'it works' }

               return nil
            ]],
            ["module.d.tl"] = [[
               local record module
                  worked: string
               end

               return module
            ]],
            ["main.tl"] = [[
               local m = require 'module'
               print(type(m))
               print(m.worked)
            ]]
         })
         local pd, output
         util.do_in(dir_name, function()
            pd = io.popen(util.tl_cmd("run", "main.tl"), "r")
            output = pd:read("*a")
         end)
         util.assert_popen_close(0, pd:close())
         util.assert_line_by_line([[
            table
            it works
         ]], output)
      end)
   end)
end)
