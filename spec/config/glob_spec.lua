local util = require("spec.util")

describe("globs", function()
   describe("*", function()
      it("should match non directory separators", function()
         util.run_mock_project(finally, {
            dir_name = "non_dir_sep_test",
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = {"*"} }]],
               ["a.tl"] = [[print "a"]],
               ["b.tl"] = [[print "b"]],
               ["c.tl"] = [[print "c"]],
            },
            cmd = "build",
            generated_files = {
               "a.lua",
               "b.lua",
               "c.lua",
            },
            --FIXME: order is not guaranteed, fix either in here or in tl itself
            --cmd_output = "Wrote: a.lua\nWrote: b.lua\nWrote: c.lua\n"
         })
      end)
      it("should match when other characters are present in the pattern", function()
         util.run_mock_project(finally, {
            dir_name = "other_chars_test",
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = { "ab*cd.tl" } }]],
               ["abzcd.tl"] = [[print "a"]],
               ["abcd.tl"] = [[print "b"]],
               ["abfoocd.tl"] = [[print "c"]],
               ["abbarcd.tl"] = [[print "d"]],
               ["abbar.tl"] = [[print "e"]],
               ["barcd.tl"] = [[print "f"]],
            },
            cmd = "build",
            generated_files = {
               "abzcd.lua",
               "abcd.lua",
               "abfoocd.lua",
               "abbarcd.lua",
            },
            --FIXME cmd_output = "Wrote: abzcd.lua\n",
         })
      end)
      it("should only match .tl by default", function()
         util.run_mock_project(finally, {
            dir_name = "match_only_teal_test",
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = { "*" } }]],
               ["foo.tl"] = [[print "a"]],
               ["foo.py"] = [[print("b")]],
               ["foo.hs"] = [[main = print "c"]],
               ["foo.sh"] = [[echo "d"]],
            },
            cmd = "build",
            generated_files = {
               "foo.lua"
            },
         })
      end)
      it("should not match .d.tl files", function()
         util.run_mock_project(finally, {
            dir_name = "dont_match_d_tl",
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = { "*" } }]],
               ["foo.tl"] = [[print "a"]],
               ["bar.d.tl"] = [[local Point = record x: number y: number end return Point]],
            },
            cmd = "build",
            generated_files = {
               "foo.lua"
            },
         })
      end)
      pending("should match directories in the middle of a path", function()
         util.run_mock_project(finally, {
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
            cmd = "build",
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
         })
      end)
   end)
   describe("**/", function()
      it("should match the current directory", function()
         util.run_mock_project(finally, {
            dir_name = "match_current_dir_test",
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = { "**/*" } }]],
               ["foo.tl"] = [[print "a"]],
               ["bar.tl"] = [[print "b"]],
               ["baz.tl"] = [[print "c"]],
            },
            cmd = "build",
            generated_files = {
               "foo.lua",
               "bar.lua",
               "baz.lua",
            },
         })
      end)
      it("should match any subdirectory", function()
         util.run_mock_project(finally, {
            dir_name = "match_sub_dir_test",
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
            cmd = "build",
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
         })
      end)
      pending("should not get the order of directories confused", function()
         util.run_mock_project(finally, {
            dir_name = "match_order_test",
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
            cmd = "build",
            generated_files = {
               ["foo"] = {
                  ["bar"] = {
                     ["baz"] = {
                        "a.lua",
                     }
                  }
               },
            },
         })
      end)
   end)
   describe("* and **/", function()
      pending("should work together", function()
         util.run_mock_project(finally, {
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
            cmd = "build",
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
         })
      end)
   end)
end)
