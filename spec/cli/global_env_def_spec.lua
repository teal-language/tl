local assert = require("luassert")
local util = require("spec.util")

describe("--global-env-def argument", function()
   it("exports globals from a module", function()
      util.do_in(util.write_tmp_dir(finally, {
         mod = {
            ["add.tl"] = [[
               global function add(n: number, m: number): number
                   return n + m
               end
            ]],
         },
         ["test.tl"] = [[
            print(add(10, 20))
         ]],
      }), function()
         local pd = io.popen(util.tl_cmd("check", "--global-env-def", "mod.add", "test.tl"), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         assert.match("0 errors detected", output, 1, true)
      end)
   end)
   it("reports error in stderr and code 1 when a module cannot be found", function ()
      util.do_in(util.write_tmp_dir(finally, {
         ["test.tl"] = [[
             print(add(10, 20))
         ]],
      }), function()
         local pd = io.popen(util.tl_cmd("check", "--global-env-def", "module_that_doesnt_exist", "test.tl") .. " 2>&1", "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match("Error:", output, 1, true)
      end)
   end)
   it("cannot be used more than once", function ()
      util.do_in(util.write_tmp_dir(finally, {
         mod = {
            ["add.tl"] = [[
               global function add(n: number, m: number): number
                   return n + m
               end
            ]],
         },
         ["test.tl"] = [[
            print(add(10, 20))
         ]],
      }), function()
         local pd = io.popen(util.tl_cmd("check", "--global-env-def", "mod.subtract", "--global-env-def", "mod.add", "test.tl") .. " 2>&1", "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match("Error:", output, 1, true)
      end)
   end)
   it("reads global_env_def from tlconfig.lua", function ()
      util.do_in(util.write_tmp_dir(finally, {
         mod = {
            ["add.tl"] = [[
               global function add(n: number, m: number): number
                   return n + m
               end
            ]],
         },
         ["test.tl"] = [[
            print(add(10, 20))
         ]],
         ["tlconfig.lua"] = [[
         return {
            global_env_def = "mod.add",
         }
         ]],
      }), function()
         local pd = io.popen(util.tl_cmd("check", "test.tl"), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         assert.match("0 errors detected", output, 1, true)
      end)

   end);

end)
