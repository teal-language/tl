local util = require("spec.util")

describe("-I --include argument", function()
   it("adds a directory to package.path", function()
      local name = util.write_tmp_file(finally, "foo.tl", [[
         require("add")
         local x: number = add(1, 2)

         assert(x == 3)
      ]])

      local pd = io.popen("./tl -I spec check " .. name, "r")
      local output = pd:read("*a")
      util.assert_popen_close(true, "exit", 0, pd:close())
      assert.match("0 errors detected", output, 1, true)
   end)
end)
