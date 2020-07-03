local util = require("spec.util")
local lfs = require("lfs")

local tl_path = lfs.currentdir()
local tl_executable = tl_path .. "/tl"
local tl_lib = tl_path .. "/tl.lua"
local function run_mock_project(t)
   local actual_dir_name = util.write_tmp_dir(finally, t.dir_name, t.dir_structure)
   lfs.link(tl_executable, actual_dir_name .. "/tl")
   lfs.link(tl_lib, actual_dir_name .. "/tl.lua")
   local expected_dir_structure = {
      ["tl"] = true,
      ["tl.lua"] = true,
   }
   local function insert_into(tab, files)
      for k, v in pairs(files) do
         if type(k) == "number" then
            tab[v] = true
         elseif type(v) == "table" then
            if not tab[k] then
               tab[k] = {}
            end
            insert_into(tab[k], v)
         elseif type(v) == "string" then
            tab[k] = true
         end
      end
   end
   insert_into(expected_dir_structure, t.dir_structure)
   insert_into(expected_dir_structure, t.generated_files)
   lfs.chdir(actual_dir_name)
   local pd = io.popen("./tl gen")
   local output = pd:read("*a")
   local actual_dir_structure = util.get_dir_structure(".")
   lfs.chdir(tl_path)
   t.popen_close = t.popen_close or {}
   util.assert_popen_close(
      t.popen_close[1] or true,
      t.popen_close[2] or "exit",
      t.popen_close[3] or 0,
      pd:close()
   )
   if t.cmd_output then --FIXME
      assert.are.equal(output, t.cmd_output)
   end
   assert.are.same(expected_dir_structure, actual_dir_structure)
end

describe("globs", function()
   describe("*", function()
      it("should match non directory separators", function()
         run_mock_project{
            dir_name = "non_dir_sep_test",
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = {"*"} }]],
               ["a.tl"] = [[print "a"]],
               ["b.tl"] = [[print "b"]],
               ["c.tl"] = [[print "c"]],
            },
            generated_files = {
               "a.lua",
               "b.lua",
               "c.lua",
            },
            --FIXME: order is not guaranteed, fix either in here or in tl itself
            --cmd_output = "Wrote: a.lua\nWrote: b.lua\nWrote: c.lua\n"
         }
      end)
      it("should match when other characters are present in the pattern", function()
         run_mock_project{
            dir_name = "other_chars_test",
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = { "ab*cd.tl" } }]],
               ["abzcd.tl"] = [[print "a"]],
               ["abcd.tl"] = [[print "b"]],
               ["abfoocd.tl"] = [[print "c"]],
               ["abbarcd.tl"] = [[print "d"]],
            },
            generated_files = {
               "abzcd.lua",
               "abcd.lua",
               "abfoocd.lua",
               "abbarcd.lua",
            },
            --FIXME cmd_output = "Wrote: abzcd.lua\n",
         }
      end)
      it("should only match .tl by default", function()
         run_mock_project{
            dir_name = "match_only_teal_test",
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = { "*" } }]],
               ["foo.tl"] = [[print "a"]],
               ["foo.py"] = [[print("b")]],
               ["foo.hs"] = [[main = print "c"]],
               ["foo.sh"] = [[echo "d"]],
            },
            generated_files = {
               "foo.lua"
            },
         }
      end)
      it("should not match .d.tl files", function()
         run_mock_project{
            dir_name = "dont_match_d_tl",
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = { "*" } }]],
               ["foo.tl"] = [[print "a"]],
               ["bar.d.tl"] = [[local Point = record x: number y: number end return Point]],
            },
            generated_files = {
               "foo.lua"
            },
         }
      end)
      it("should match directories in the middle of a path", function()
         run_mock_project{
            dir_name = "match_dirs_in_middle_test",
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = { "foo/*/baz.tl" } }]],
               ["foo"] = {
                  ["bar"] = {
                     ["foo.tl"] = [[print "a"]],
                     ["baz.tl"] = [[print "b"]],
                  },
                  ["bingo"] = {
                     ["foo.tl"] = [[print "c"]],
                     ["baz.tl"] = [[print "d"]],
                  },
                  ["bongo"] = {
                     ["foo.tl"] = [[print "e"]],
                  },
               }
            },
            generated_files = {
               ["foo"] = {
                  ["bar"] = {
                     "baz.lua"
                  },
                  ["bingo"] = {
                     "baz.lua"
                  },
               },
            },
         }
      end)
   end)
   describe("**/", function()
      it("should match the current directory", function()
         run_mock_project{
            dir_name = "match_current_dir_test",
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = { "**/*" } }]],
               ["foo.tl"] = [[print "a"]],
               ["bar.tl"] = [[print "b"]],
               ["baz.tl"] = [[print "c"]],
            },
            generated_files = {
               "foo.lua",
               "bar.lua",
               "baz.lua",
            },
         }
      end)
      it("should match any subdirectory", function()
         run_mock_project{
            dir_name = "match_current_dir_test",
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = { "**/*" } }]],
               ["foo"] = {
                  ["foo.tl"] = [[print "a"]],
                  ["bar.tl"] = [[print "b"]],
                  ["baz.tl"] = [[print "c"]],
               },
               ["bar"] = {
                  ["foo.tl"] = [[print "a"]],
                  ["baz"] = {
                     ["bar.tl"] = [[print "b"]],
                     ["baz.tl"] = [[print "c"]],
                  }
               },
               ["a"] = {a={a={a={a={a={["a.tl"]=[[global a = "a"]]}}}}}}
            },
            generated_files = {
               ["foo"] = {
                  "foo.lua",
                  "bar.lua",
                  "baz.lua",
               },
               ["bar"] = {
                  "foo.lua",
                  ["baz"] = {
                     "bar.lua",
                     "baz.lua",
                  }
               },
               ["a"] = {a={a={a={a={a={"a.lua"}}}}}},
            },
         }
      end)
      it("should not get the order of directories confused", function()
         run_mock_project{
            dir_name = "match_current_dir_test",
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = { "foo/**/bar/**/baz/a.tl" } }]],
               ["foo"] = {
                  ["bar"] = {
                     ["baz"] = {
                        ["a.tl"] = [[print "a"]],
                     },
                  },
               },
               ["baz"] = {
                  ["bar"] = {
                     ["foo"] = {
                        ["a.tl"] = [[print "a"]],
                     },
                  },
               },
               ["bar"] = {
                  ["baz"] = {
                     ["foo"] = {
                        ["a.tl"] = [[print "a"]],
                     },
                  },
               },
            },
            generated_files = {
               ["foo"] = {
                  ["bar"] = {
                     ["baz"] = {
                        "a.lua",
                     }
                  }
               },
            },
         }
      end)
   end)
   describe("* and **/", function()
      it("should work together", function()
         run_mock_project{
            dir_name = "glob_interference_test",
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = { "**/foo/*/bar/**/*" } }]],
               ["foo"] = {
                  ["a"] = {
                     ["bar"] = {
                        ["baz"] = {
                           ["a"] = {["b"] = {["c.tl"] = [[print "c"]]}},
                        },
                        ["bat"] = {
                           ["a"] = {["b.tl"] = [[print "b"]]},
                        },
                     },
                  },
                  ["b"] = {
                     ["bar"] = {
                           ["a"] = {["b.tl"] = [[print "b"]]},
                     },
                  },
                  ["c"] = {
                     ["d"] = {
                        ["bar"] = {
                           ["a.tl"] = [[print "not included"]]
                        },
                     },
                  },
               },
               ["a"] = {
                  ["b"] = {
                     ["foo"] = {
                        ["a"] = {
                           ["bar"] = {
                              ["baz"] = {
                                 ["a"] = {["b"] = {["c.tl"] = [[print "c"]]}},
                              },
                              ["bat"] = {
                                 ["a"] = {["b.tl"] = [[print "b"]]},
                              },
                           },
                        },
                        ["b"] = {
                           ["bar"] = {
                              ["baz"] = {
                                 ["a"] = {["b"] = {["c.tl"] = [[print "c"]]}},
                              },
                              ["bat"] = {
                                 ["a"] = {["b.tl"] = [[print "b"]]},
                              },
                           },
                        },
                     },
                  },
               },
            },
            generated_files = {
               ["foo"] = {
                  ["a"] = {
                     ["bar"] = {
                        ["baz"] = {
                           ["a"] = {["b"] = {"c.lua"}},
                        },
                        ["bat"] = {
                           ["a"] = {"b.lua"},
                        },
                     },
                  },
                  ["b"] = {
                     ["bar"] = {
                           ["a"] = {"b.lua"},
                     },
                  },
               },
               ["a"] = {
                  ["b"] = {
                     ["foo"] = {
                        ["a"] = {
                           ["bar"] = {
                              ["baz"] = {
                                 ["a"] = {["b"] = {"c.lua"}},
                              },
                              ["bat"] = {
                                 ["a"] = {"b.lua"},
                              },
                           },
                        },
                        ["b"] = {
                           ["bar"] = {
                              ["baz"] = {
                                 ["a"] = {["b"] = {"c.lua"}},
                              },
                              ["bat"] = {
                                 ["a"] = {"b.lua"},
                              },
                           },
                        },
                     },
                  },
               },
            },
         }
      end)
   end)
end)
