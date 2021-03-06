local util = require("spec.util")

describe("config type checking", function()
   it("should error out when config.include is not a {string}", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return { include = "*.tl" }]],
            ["foo.tl"] = [[print "a"]],
         },
         cmd = "build",
         generated_files = {},
         exit_code = 1,
         cmd_output = "Error loading tlconfig.lua:\n* in key \"include\": expected a {string}, got string\n",
      })
   end)
   it("should error out when config.source_dir is not a string", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return { source_dir = true }]],
            ["foo.tl"] = [[print "a"]],
         },
         cmd = "build",
         generated_files = {},
         exit_code = 1,
         cmd_output = "Error loading tlconfig.lua:\n* in key \"source_dir\": expected a string, got boolean\n",
      })
   end)
end)
