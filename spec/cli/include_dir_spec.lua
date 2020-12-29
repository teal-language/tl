local util = require("spec.util")

describe("-I --include-dir argument", function()
   it("adds a directory to package.path", function()
      local name = util.write_tmp_file(finally, [[
         require("add")
         local x: number = add(1, 2)

         assert(x == 3)
      ]])

      local pd = io.popen("./tl -I spec check " .. name, "r")
      local pd = io.popen(util.tl_cmd("check", "-I", "spec", name), "r")
      local output = pd:read("*a")
      util.assert_popen_close(true, "exit", 0, pd:close())
      assert.match("0 errors detected", output, 1, true)
   end)
   it("adds a directory to package.cpath", function()
      local name = util.write_tmp_file(finally, [[
         print(package.cpath:match("spec/cli/") ~= nil)
      ]])
      local pd = io.popen(util.tl_cmd("run", "-I", "spec/cli/", name), "r")
      local output = pd:read("*a")
      util.assert_popen_close(true, "exit", 0, pd:close())
      util.assert_line_by_line([[
         true
      ]], output)
   end)
end)
