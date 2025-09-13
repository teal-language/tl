local util = require("spec.util")

describe("tl dump", function()
   setup(util.chdir_setup)
   teardown(util.chdir_teardown)

   it("dumps reader blocks as JSON", function()
      local name = util.write_tmp_file(finally, [[
         local x = 1
      ]])
      local pd = io.popen(util.tl_cmd("dump blocks --format=json", name), "r")
      local output = pd:read("*a")
      util.assert_popen_close(0, pd:close())
      assert.is_truthy(output:match('\"kind\":\"statements\"'))
   end)

   it("dumps parser AST as JSON", function()
      local name = util.write_tmp_file(finally, [[
         local x = 1
      ]])
      local pd = io.popen(util.tl_cmd("dump ast --format=json", name), "r")
      local output = pd:read("*a")
      util.assert_popen_close(0, pd:close())
      -- Should contain a local_declaration node
      assert.is_truthy(output:match('\"kind\":\"local_declaration\"'))
   end)

   it("supports stdin for blocks", function()
      local pd = io.popen(util.tl_pipe_cmd("echo \"local x = 1\"", "dump blocks --format=json", "-"), "r")
      local output = pd:read("*a")
      util.assert_popen_close(0, pd:close())
      assert.is_truthy(output:match('\"kind\":\"statements\"'))
   end)
end)

