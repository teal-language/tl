local util = require("spec.util")

describe("-o --output", function()
   it("should gen in the current directory when not provided", function()
      util.run_mock_project(finally, {
         dir_structure = {
            bar = {
               ["foo.tl"] = [[print 'hey']],
            },
         },
         generated_files = { "foo.lua" },
         cmd = "gen",
         args = { "bar/foo.tl" },
         popen = {
            status = true,
            exit = "exit",
            code = 0,
         },
      })
   end)
   it("should work with nested directories", function()
      util.run_mock_project(finally, {
         dir_structure = {a={b={c={["foo.tl"] = [[print 'hey']]}}}},
         generated_files = { "foo.lua" },
         cmd = "gen",
         args = { "a/b/c/foo.tl" },
         popen = {
            status = true,
            exit = "exit",
            code = 0,
         },
      })
   end)
   it("should write to the given filename", function()
      util.run_mock_project(finally, {
         args = { "foo.tl", "-o", "my_output_file.lua" },
         dir_structure = { ["foo.tl"] = [[print 'hey']] },
         generated_files = { "my_output_file.lua" },
         cmd = "gen",
         popen = {
            status = true,
            exit = "exit",
            code = 0,
         },
      })
   end)
   it("should write to the given filename in a directory", function()
      util.run_mock_project(finally, {
         args = { "foo.tl", "-o", "a/b/c/d.lua" },
         dir_structure = {
            ["foo.tl"] = [[print 'hey']],
            a={b={c={}}},
         },
         generated_files = {
            a={b={c={"d.lua"}}},
         },
         cmd = "gen",
         popen = {
            status = true,
            exit = "exit",
            code = 0,
         },
      })
   end)
   it("should gracefully error when the output directory doesn't exist", function()
      util.run_mock_project(finally, {
         args = { "foo.tl", "-o", "a/b/c/d.lua" },
         dir_structure = {
            ["foo.tl"] = [[print 'hey']],
         },
         generated_files = {},
         cmd = "gen",
         popen = {
            status = nil,
            exit = "exit",
            code = 1,
         },
      })
   end)
end)
