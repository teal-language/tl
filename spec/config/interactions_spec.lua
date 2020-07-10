local util = require("spec.util")

describe("config option interactions", function()
   describe("include+exclude", function()
      pending("exclude should have precedence over include", function()
         util.run_mock_project(finally, {
            dir_name = "interaction_inc_exc_test",
            dir_structure = {
               ["tlconfig.lua"] = [[return {
                  include = {
                     "**/*",
                  },
                  exclude = {
                     "*",
                  },
               }]],
               -- should include any .tl file not in the top directory
               ["foo.tl"] = [[print "hey"]],
               ["bar.tl"] = [[print "hi"]],
               baz = {
                  foo = {
                     ["bar.tl"] = [[print "h"]],
                  },
                  bar = {
                     ["baz.tl"] = [[print "hello"]],
                  },
               },
            },
            cmd = "build",
            generated_files = {
               baz = {
                  foo = { "bar.lua" },
                  bar = { "baz.lua" },
               },
            },
         })
      end)
   end)
   describe("source_dir+build_dir", function()
      pending("Having source_dir inside of build_dir works", function()
         util.run_mock_project(finally, {
            dir_name = "source_dir_in_build_dir_test",
            dir_structure = {
               ["tlconfig.lua"] = [[return {
                  source_dir = "foo/bar",
                  build_dir = "foo",
               }]],
               foo = {
                  bar = {
                     ["a.tl"] = [[print "a"]],
                     ["b.tl"] = [[print "b"]],
                  }
               }
            },
            cmd = "build",
            generated_files = {
               foo = {
                  "a.lua",
                  "b.lua",
               }
            },
         })
      end)
      pending("Having build_dir inside of source_dir works if no inputs from ", function()
         util.run_mock_project(finally, {
            dir_name = "build_dir_in_source_dir_test",
            dir_structure = {
               ["tlconfig.lua"] = [[return {
                  source_dir = "foo",
                  build_dir = "foo/bar",
               }]],
               foo = {
                  ["a.tl"] = [[print "a"]],
                  ["b.tl"] = [[print "b"]],
               }
            },
            cmd = "build",
            generated_files = {
               foo = {
                  bar = {
                     "a.lua",
                     "b.lua",
                  }
               }
            },
         })
      end)
      it("fails when a file would be generated inside of source_dir while there is a build_dir", function()
         util.run_mock_project(finally, {
            dir_name = "gen_in_source_dir_test",
            dir_structure = {
               ["tlconfig.lua"] = [[return {
                  source_dir = "src",
                  build_dir = ".",
               }]],
               src = {
                  ["foo.tl"] = [[print "hi"]],
                  src = {
                     ["foo.tl"] = [[print "hi"]],
                  },
               },
            },
            generated_files = {}, -- Build errors should not generate anything
            cmd = "build",
            popen = {
               status = false,
               exit = "exit",
               code = 1,
            },
         })
      end)
      pending("should not include any files in build_dir", function()
         util.run_mock_project(finally, {
            dir_name = "source_file_in_build_dir_test",
            dir_structure = {
               ["tlconfig.lua"] = [[return {
                  source_dir = ".",
                  build_dir = "build",
               }]],
               ["foo.tl"] = [[print "hi"]],
               bar = {
                  ["baz.tl"] = [[print "hi"]],
               },
               build = {
                  ["dont_include_this.tl"] = [[print "dont"]],
               },
            },
            cmd = "build",
            generated_files = {
               build = {
                  "foo.lua",
                  bar = {
                     "baz.lua",
                  },
               },
            },
         })
      end)
   end)
   describe("source_dir+include+exclude", function()
      pending("nothing outside of source_dir is included", function()
      end)
   end)
end)
