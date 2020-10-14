local util = require("spec.util")

describe("config type checking", function()
   it("should error out when a config entry isn't the correct type", function()
      util.run_mock_project(finally, {
         dir_name = "config_type_check",
         dir_structure = {
            ["tlconfig.lua"] = [[return { include = "*.tl" }]],
            ["foo.tl"] = [[print "a"]],
         },
         cmd = "build",
         generated_files = {},
         popen = {
            status = nil,
            exit = "exit",
            code = 1,
         },
         cmd_output = "Error while loading config: Expected include to be a {string}\n",
      })
      util.run_mock_project(finally, {
         dir_name = "config_type_check2",
         dir_structure = {
            ["tlconfig.lua"] = [[return { source_dir = true }]],
            ["foo.tl"] = [[print "a"]],
         },
         cmd = "build",
         generated_files = {},
         popen = {
            status = nil,
            exit = "exit",
            code = 1,
         },
         cmd_output = "Error while loading config: Expected source_dir to be a string\n",
      })
   end)
end)
