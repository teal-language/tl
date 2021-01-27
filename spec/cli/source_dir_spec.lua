local util = require("spec.util")

describe("-s --source-dir argument", function()
   it("recursively traverses the directory by default", function()
      util.run_mock_project(finally, {
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
         cmd = "build",
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
   it("should die when the given directory doesn't exist", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {source_dir="src"}]],
            ["foo.tl"] = [[print 'hi']],
         },
         cmd = "build",
         generated_files = {},
         cmd_output = "Build error: source_dir 'src' is not a directory\n",
      })
   end)
   it("should not include files from other directories", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {
               source_dir = "foo",
            }]],
            ["foo"] = {
               ["a.tl"] = [[return "hey"]],
            },
            ["bar"] = {
               ["b.tl"] = [[return "hi"]],
            },
         },
         cmd = "build",
         generated_files = {
            ["foo"] = {
               "a.lua"
            },
         },
      })
   end)
   it("should correctly match directory names", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {
               source_dir = "foo",
            }]],
            ["foo"] = {
               ["a.tl"] = [[return "hey"]],
            },
            ["foobar"] = {
               ["b.tl"] = [[return "hi"]],
            },
         },
         cmd = "build",
         generated_files = {
            ["foo"] = {
               "a.lua"
            },
         },
      })
   end)
end)
