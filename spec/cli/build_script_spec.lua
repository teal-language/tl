local util = require("spec.util")

describe("build.tl", function()
   it("defaults to the generated_code folder", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {
               build_dir = "build",
            }]],
            ["foo.tl"] = [[print(require("generated_code/generated"))]],
            ["build.tl"] = [[
               return {
                  gen_code = function(path:string)
                     local file = io.open(path .. "/generated.tl", "w")
                     file:write('return "Hello from script generated by build.tl"')
                     file:close()
                  end
               }
            ]],
            ["bar.tl"] = [[print "bar"]],
         },
         cmd = "build",
         generated_files = {
            ["build"] = {
               "build.lua",
               "foo.lua",
               "bar.lua",
               ["generated_code"] = {
                  "generated.lua"
               }
            },
            ["internal_compiler_output"] = {
               ["build_script_output"] = {
                  ["generated_code"] = {
                     "generated.tl"
                  }
               },
               "last_build_script_time"
            }
         },
      })
   end)
   it("can have the location it stores altered by setting build_file_output_dir", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {
               build_dir = "build",
               build_file_output_dir = "other_generated_code"
            }]],
            ["foo.tl"] = [[print(require("other_generated_code/generated"))]],
            ["build.tl"] = [[
                return {
                    gen_code = function(path:string)
                        local file = io.open(path .. "/generated.tl", "w")
                        file:write('return "Hello from script generated by build.tl"')
                        file:close()
                    end
                }]],
            ["bar.tl"] = [[print "bar"]],
         },
         cmd = "build",
         generated_files = {
            ["build"] = {
               "build.lua",
               "foo.lua",
               "bar.lua",
               ["other_generated_code"] = {
                   "generated.lua"
               }
            },
            ["internal_compiler_output"] = {
               ["build_script_output"] = {
                  ["other_generated_code"] = {
                     "generated.tl"
                  }
               },
               "last_build_script_time"
            }
         },
      })
   end)
   it("can have a diffrent name by setting build_file", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {
               build_dir = "build",
               build_file = "other_name.tl"
            }]],
            ["foo.tl"] = [[print(require("generated_code/generated"))]],
            ["other_name.tl"] = [[
               return {
                  gen_code = function(path:string)
                     local file = io.open(path .. "/generated.tl", "w")
                     file:write('return "Hello from script generated by build.tl"')
                     file:close()
                  end
               }
            ]],
            ["bar.tl"] = [[print "bar"]],
         },
         cmd = "build",
         generated_files = {
            ["build"] = {
               "other_name.lua",
               "foo.lua",
               "bar.lua",
               ["generated_code"] = {
                  "generated.lua"
               }
            },
            ["internal_compiler_output"] = {
               ["build_script_output"] = {
                  ["generated_code"] = {
                     "generated.tl"
                  }
               },
               "last_build_script_time"
            }
         }
      })
   end)
   it("Can have the location for cached output files changed", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {
               build_dir = "build",
               internal_compiler_output = "this_other_folder_to_store_cached_items"
            }]],
            ["foo.tl"] = [[print(require("generated_code/generated"))]],
            ["build.tl"] = [[
               return {
                  gen_code = function(path:string)
                     local file = io.open(path .. "/generated.tl", "w")
                     file:write('return "Hello from script generated by build.tl"')
                     file:close()
                  end

               }
            ]],
            ["bar.tl"] = [[print "bar"]],
         },
         cmd = "build",
         generated_files = {
            ["build"] = {
               "build.lua",
               "foo.lua",
               "bar.lua",
               ["generated_code"] = {
                  "generated.lua"
               }
            },
            ["this_other_folder_to_store_cached_items"] = {
               ["build_script_output"] = {
                  ["generated_code"] = {
                     "generated.tl"
                  }
               },
               "last_build_script_time"
            }
         },
      })

   end)
   it("Should not run when running something else than build", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {
               build_dir = "build",
               build_file_output_dir = "generated_code",
               internal_compiler_output = "this_other_folder_to_store_cached_items"
            }]],
            ["foo.tl"] = [[print("build.tl did not run")]],
            ["build.tl"] = [[
               {
                  gen_code = function(path:string)
                     local file = io.open(path .. "/generated.tl", "w")
                     file:write('return "Hello from script generated by build.tl"')
                     file:close()
                  end

               }
            ]],
         },
         cmd = "run",
         args = {
            "foo.tl"
         },
         cmd_output = "build.tl did not run\n"
      })

   end)
   it("Should run when running something else than build and --run-build-script is passed", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {
               build_dir = "build",
               build_file_output_dir = "generated_code",
               internal_compiler_output = "this_other_folder_to_store_cached_items"
            }]],
            ["foo.tl"] = [[local x =require("generated_code/generated") print(x)]],
            ["build.tl"] = [[
               return {
                  gen_code = function(path:string)
                     local file = io.open(path .. "/generated.tl", "w")
                     file:write('return "Hello from script generated by build.tl"')
                     file:close()
                  end

               }
            ]],
         },
         cmd = "run",
         pre_args = {"--run-build-script"},
         args = {
            "foo.tl",
         },
         cmd_output = "Hello from script generated by build.tl\n"
      })

   end)

   it("It should only run the build script if it changed since last time", function()
      local path = util.write_tmp_dir(finally, {
            ["tlconfig.lua"] = [[return {
               build_dir = "build",
               build_file_output_dir = "generated_code",
               internal_compiler_output = "test"
            }]],
            ["build.tl"] = [[
               return {
                  gen_code = function(_:string)

                     print("This text should appear only once")
                  end

               }
            ]],
      })
      util.run_mock_project(finally, {
            cmd = "build",
            cmd_output = [[
This text should appear only once
Wrote: build/build.lua
]]
         },
         path
      )
      util.run_mock_project(finally, {
            cmd = "build",
            cmd_output = [[
Wrote: build/build.lua
]]
         },
         path
      )

   end)


   it("Should give an error if the build script contains invalid teal", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {
               build_dir = "build",
               build_file_output_dir = "generated_code",
               internal_compiler_output = "this_other_folder_to_store_cached_items"
            }]],
            ["foo.tl"] = [[print(require("generated_code/generated"))]],
            ["build.tl"] = [[
               {
                  gen_code = function(path:string)
                     local file = io.open(path .. "/generated.tl", "w")
                     file:write('return "Hello from script generated by build.tl"')
                     file:close()
                  end

               }
            ]],
            ["bar.tl"] = [[print "bar"]],
         },
         cmd = "build",
         cmd_output =
[[========================================
1 syntax error:
./build.tl:8:17: syntax error
]]
      })
   end)
   it("Should give an error if the key gen_code exists, but it is not a function", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {
               build_dir = "build",
               build_file_output_dir = "generated_code",
               internal_compiler_output = "this_other_folder_to_store_cached_items"
            }]],
            ["foo.tl"] = [[print(require("generated_code/generated"))]],
            ["build.tl"] = [[
               return {
                  gen_code = "I am a string"

               }
            ]],
            ["bar.tl"] = [[print "bar"]],
         },
         cmd = "build",
         cmd_output =
[[the key "gen_code" exists in the build file, but it is not a function. Value: I am a string
]]
      })
   end)
end)
