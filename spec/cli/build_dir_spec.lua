local util = require("spec.util")

describe("-b --build-dir argument", function()
   it("generates files in the given directory", function()
      util.run_mock_project(finally, {
         dir_name = "build_dir_test",
         dir_structure = {
            ["tlconfig.lua"] = [[return { build_dir = "build" }]],
            ["foo.tl"] = [[print "foo"]],
            ["bar.tl"] = [[print "bar"]],
         },
         cmd = "gen",
         args = "foo.tl bar.tl",
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
         dir_name = "build_dir_nested_test",
         dir_structure = {
            ["tlconfig.lua"] = [[return { build_dir = "build" }]],
            ["foo.tl"] = [[print "foo"]],
            ["bar.tl"] = [[print "bar"]],
            ["baz"] = {
               ["foo.tl"] = [[print "foo"]],
               ["bar"] = {
                  ["foo.tl"] = [[print "foo"]],
               }
            }
         },
         cmd = "gen",
         args = "foo.tl bar.tl baz/foo.tl baz/bar/foo.tl",
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
end)
