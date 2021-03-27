local util = require("spec.util")

describe("config option interactions", function()
   describe("include+exclude", function()
      it("exclude should have precedence over include", function()
         util.run_mock_project(finally, {
            dir_structure = {
               ["tlconfig.lua"] = [[return {
                  include = {
                     ]] .. util.os_path('"**/*"') .. [[,
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
      it("Having source_dir inside of build_dir works", function()
         util.run_mock_project(finally, {
            dir_structure = {
               ["tlconfig.lua"] = [[return {
                  source_dir = ]] .. util.os_path('"foo/bar"') .. [[,
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
      it("Having build_dir inside of source_dir works", function()
         util.run_mock_project(finally, {
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
   end)
   describe("source_dir+include+exclude", function()
      it("nothing outside of source_dir is included", function()
         util.run_mock_project(finally, {
            dir_structure = {
               ["tlconfig.lua"] = [[return {
                  source_dir = "src",
                  include = {
                     ]] .. util.os_path('"**/*"') .. [[
                  },
               }]],
               ["src"] = {
                  ["foo"] = {
                     ["bar"] = {
                        ["a.tl"] = [[print "a"]],
                        ["b.tl"] = [[print "b"]],
                     },
                     ["a.tl"] = [[print "a"]],
                     ["b.tl"] = [[print "b"]],
                  },
               },
               ["a.tl"] = [[print "a"]],
               ["b.tl"] = [[print "b"]],
            },
            cmd = "build",
            generated_files = {
               ["src"] = {
                  ["foo"] = {
                     ["bar"] = {
                        "a.lua",
                        "b.lua",
                     },
                     "a.lua",
                     "b.lua",
                  },
               },
            },
         })
      end)
      it("include and exclude work as expected", function()
         util.run_mock_project(finally, {
            dir_structure = {
               ["tlconfig.lua"] = [[return {
                  source_dir = ".",
                  include = {
                     ]] .. util.os_path('"foo/*.tl"') .. [[,
                  },
                  exclude = {
                     ]] .. util.os_path('"foo/a*.tl"') .. [[,
                  },
               }]],
               foo = {
                  ["a.tl"] = [[print 'a']],
                  ["ab.tl"] = [[print 'a']],
                  ["ac.tl"] = [[print 'a']],
                  ["b.tl"] = [[print 'b']],
                  ["bc.tl"] = [[print 'b']],
                  ["bd.tl"] = [[print 'b']],
               },
               bar = {
                  ["c.tl"] = [[print 'c']],
                  ["cd.tl"] = [[print 'c']],
                  ["ce.tl"] = [[print 'c']],
               },
            },
            cmd = "build",
            generated_files = {
               foo = {
                  "b.lua",
                  "bc.lua",
                  "bd.lua",
               },
            },
         })
      end)
   end)
end)
