local assert = require("luassert")
local util = require("spec.util")

describe("-l --preload argument", function()
   it("exports globals from a module", function()
      local name = util.write_tmp_file(finally, [[
         print(add(10, 20))
      ]])

      local pd = io.popen(util.tl_cmd("check", "-l", "spec.add", name), "r")
      local output = pd:read("*a")
      util.assert_popen_close(true, "exit", 0, pd:close())
      assert.match("0 errors detected", output, 1, true)
   end)
   it("reports error in stderr and code 1 when a module cannot be found", function ()
      local name = util.write_tmp_file(finally, [[
         print(add(10, 20))
      ]])

      local pd = io.popen(util.tl_cmd("check", "-l", "module_that_doesnt_exist", name) .. " 2>&1 1>/dev/null", "r")
      local output = pd:read("*a")
      util.assert_popen_close(nil, "exit", 1, pd:close())
      assert.match("Error:", output, 1, true)
    end)
    it("can be used more than once", function ()
      local name = util.write_tmp_file(finally, [[
         print(add(10, 20))
         print(subtract(20, 10))
      ]])

      local pd = io.popen(util.tl_cmd("check", "-l", "spec.add", "--preload",  "spec.subtract", name), "r")
      local output = pd:read("*a")
      util.assert_popen_close(true, "exit", 0, pd:close())
      assert.match("0 errors detected", output, 1, true)
    end)
end)
