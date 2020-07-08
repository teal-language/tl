local util = require("spec.util")

describe("files config option", function()
   it("should compile the given list of files", function()
      util.run_mock_project(finally, {
         dir_name = "files_test",
         dir_structure = {
            ["tlconfig.lua"] = [[return { files = { "foo.tl", "bar.tl" } }]],
            ["foo.tl"] = [[print "a"]],
            ["bar.tl"] = [[print "b"]],
            ["baz.tl"] = [[print "c"]],
         },
         cmd = "gen",
         generated_files = {
            "foo.lua",
            "bar.lua",
         }
      })
   end)
end)
