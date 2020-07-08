local util = require("spec.util")

describe("-s --source-dir argument", function()
   it("recursively traverses the directory by default", function()
      util.run_mock_project(finally, {
         dir_name = "source_dir_traversal_test",
         dir_structure = {
            ["tlconfig.lua"] = [[return { source_dir = "src" }]],
            ["src"] = {
               ["foo.tl"] = [[print "foo"]],
               ["bar.tl"] = [[print "bar"]],
               foo = {
                  ["bar.tl"] = [[print "bar"]],
                  baz = {
                     ["foo.tl"] = [[print "baz"]],
                  }
               }
            }
         },
         cmd = "gen",
         generated_files = {
            ["src"] = {
               "foo.lua",
               "bar.lua",
               foo = {
                  "bar.lua",
                  baz = {
                     "foo.lua"
                  }
               }
            }
         },
      })
   end)
end)
