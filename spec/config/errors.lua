describe("config", function()
   it("should not report unknown keys in tlconfig.lua", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return { foo = "hello" }]],
         },
         cmd = "check",
         args = { "tlconfig.lua" },
         cmd_output = [[========================================
Type checked tlconfig.lua
0 errors detected -- you can use:

   tl run tlconfig.lua

       to run tlconfig.lua as a program

   tl gen tlconfig.lua

       to generate tlconfig.out.lua]],
      })
   end)
end)
