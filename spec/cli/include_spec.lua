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
   it("adds a directory to package.cpath", function()
      local name = util.write_tmp_file(finally, "foo.lua", [[
         print(package.cpath)
      ]])
      local pd = io.popen("LUA_CPATH=\"/usr/lib/lua/?.so\" ./tl run -I spec/cli/ " .. name, "r")
      local output = pd:read("*a")
      util.assert_popen_close(true, "exit", 0, pd:close())
      util.assert_line_by_line([[
         spec/cli/?.so;/usr/lib/lua/?.so
      ]], output)
   end)
end)
