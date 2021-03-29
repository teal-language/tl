local util = require("spec.util")

describe("globs", function()
   describe("*", function()
      it("should match non directory separators", function()
         util.run_mock_project(finally, {
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
            cmd_output = "Wrote: a.lua\nWrote: b.lua\nWrote: c.lua\n"
         })
      end)
      it("should match when other characters are present in the pattern", function()
         util.run_mock_project(finally, {
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
               "abbarcd.lua",
               "abcd.lua",
               "abfoocd.lua",
               "abzcd.lua",
            },
            cmd_output = "Wrote: abbarcd.lua\nWrote: abcd.lua\nWrote: abfoocd.lua\nWrote: abzcd.lua\n"
         })
      end)
      it("should only match .tl by default", function()
         util.run_mock_project(finally, {
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
      it("should match directories in the middle of a path", function()
         util.run_mock_project(finally, {
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = { ]] .. util.os_path('"foo/*/baz.tl"') .. [[ } }]],
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
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = { ]] .. util.os_path('"**/*"') .. [[ } }]],
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
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = { ]] .. util.os_path('"**/*"') .. [[ } }]],
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
      it("should not get the order of directories confused", function()
         util.run_mock_project(finally, {
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = { ]] .. util.os_path('"foo/**/bar/**/baz/a.tl"') .. [[ } }]],
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
      it("should work together", function()
         util.run_mock_project(finally, {
            dir_structure = {
               ["tlconfig.lua"] = [[return { include = { ]] .. util.os_path('"**/foo/*/bar/**/*"') .. [[ } }]],
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
