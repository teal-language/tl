local assert = require("luassert")
local util = require("spec.util")

describe("-l --preload argument", function()
   it("exports globals from a module", function()
      util.do_in(util.write_tmp_dir(finally, {
         mod = {
            ["add.tl"] = [[
               function add(n: number, m: number): number
                   return n + m
               end

               return add
            ]],
         },
         ["test.tl"] = [[
            print(add(10, 20))
         ]],
      }), function()
         local pd = io.popen(util.tl_cmd("check", "-l", "mod.add", "test.tl"), "r")
         local output = pd:read("*a")
         util.assert_popen_close(true, "exit", 0, pd:close())
         assert.match("0 errors detected", output, 1, true)
      end)
   end)
   it("reports error in stderr and code 1 when a module cannot be found", function ()
      local name = "test.tl"
      util.do_in(util.write_tmp_dir(finally, {
         [name] = [[
             print(add(10, 20))
         ]],
      }), function()
         local pd = io.popen(util.tl_cmd("check", "-l", "module_that_doesnt_exist", name) .. " 2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(nil, "exit", 1, pd:close())
         assert.match("Unable to find module", output, 1, true)
      end)
   end)
   it("can be used more than once", function ()
      util.do_in(util.write_tmp_dir(finally, {
         mod = {
            ["add.tl"] = [[
               function add(n: number, m: number): number
                   return n + m
               end

               return add
            ]],
            ["subtract.tl"] = [[
               function subtract(n: number, m: number): number
                   return n - m
               end

               return subtract
            ]],
         },
         ["test.tl"] = [[
             print(add(10, 20))
             print(subtract(20, 10))
         ]],
         src = {},
      }), function()
         local pd = io.popen(util.tl_cmd("check", "-l", "mod.subtract", "--preload", "mod.add", "test.tl"), "r")
         local output = pd:read("*a")
         util.assert_popen_close(true, "exit", 0, pd:close())
         assert.match("0 errors detected", output, 1, true)
      end)
   end)
end)
