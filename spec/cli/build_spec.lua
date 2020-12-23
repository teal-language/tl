local util = require("spec.util")

describe("build command", function()
   it("should exit with non zero exit code when there is an error", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {}]],
            ["foo.tl"] = [[print "a"]],
            ["bar.tl"] = [[local x: string = 10]],
         },
         cmd = "build",
         popen = {
            status = nil,
            exit = "exit",
            code = 1,
         },
      })
   end)

   it("should not error when tlconfig returns nil/nothing", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[]],
         },
         cmd = "build",
         popen = {
            status = true,
            exit = "exit",
            code = 0,
         },
      })
   end)
end)
