local util = require("spec.util")

describe("-b --build-dir argument", function()
   it("generates files in the given directory", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {
               build_dir = "build",
               include = {
                  "foo.tl", "bar.tl"
               },
            }]],
            ["foo.tl"] = [[print "foo"]],
            ["bar.tl"] = [[print "bar"]],
         },
         cmd = "build",
         generated_files = {
            ["build"] = {
               "foo.lua",
               "bar.lua",
            }
         },
      })
   end)
   it("replicates the directory structure of the source", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {
               build_dir = "build",
               include = {]] .. util.os_path('"**/*.tl"') .. [[}
            }]],
            ["foo.tl"] = [[print "foo"]],
            ["bar.tl"] = [[print "bar"]],
            ["baz"] = {
               ["foo.tl"] = [[print "foo"]],
               ["bar"] = {
                  ["foo.tl"] = [[print "foo"]],
               }
            }
         },
         cmd = "build",
         generated_files = {
            ["build"] = {
               "foo.lua",
               "bar.lua",
               ["baz"] = {
                  "foo.lua",
                  ["bar"] = {
                     "foo.lua",
                  }
               }
            }
         },
      })
   end)
   it("dies when no config is found", function()
      util.run_mock_project(finally, {
         dir_structure = {},
         cmd = "build",
         generated_files = {},
         exit_code = 1,
         cmd_output = "Build error: tlconfig.lua not found\n"
      })
   end)

end)
