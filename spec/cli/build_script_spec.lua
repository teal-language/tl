local util = require("spec.util")

local build_cmd = util.tl_cmd("build")
local function runcmd(cmd)
   local ph = io.popen(cmd, "r")
   local out = ph:read("*a")
   util.assert_popen_close(true, "exit", 0, ph:close())
   return out
end

describe("build script", function()
   it("should error when it is not a file", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {
               build_file = "foo.tl"
            }]],
         },
         cmd = "build",
         generated_files = {},
         cmd_output = "Error loading config: Build script foo.tl is not a file\n",
         popen = {
            status = nil,
            exit = "exit",
            code = 1,
         },
      })
   end)

   it("is run when `tl build` is run", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {
               source_dir = "src",
               build_dir = "build",
            }]],
            ["build.tl"] = [[
               return {
                  gen_code = function()
                     print("Build Script")
                  end,
               }
            ]],
            src = {},
            build = {},
         },
         cmd = "build",
         generated_files = {},
         cmd_output = "Build Script\nAll files up to date\n"
      })
   end)

   it("should not be compiled when it is in the source_dir", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {}]],
            ["build.tl"] = [[
               return {
                  gen_code = function()
                     print("Build Script")
                  end,
               }
            ]],
         },
         cmd = "build",
         generated_files = {},
         cmd_output = "Build Script\nAll files up to date\n"
      })
   end)

   describe("gen_code", function()
      it("should pass the tlconfig build_file_output_dir as an argument", function()
         local path = "foo"
         util.run_mock_project(finally, {
            dir_structure = {
               ["tlconfig.lua"] = ([[return {
                  build_file_output_dir = %q
               }]]):format(path),
               ["build.tl"] = [[
                  return {
                     gen_code = function(path: string)
                        print("Build Script")
                        print(path)
                     end,
                  }
               ]],
            },
            cmd = "build",
            generated_files = {},
            cmd_output = "Build Script\n" .. path .. package.config:sub(1, 1) .. "\nAll files up to date\n"
         })
      end)

      it("should default to generated_code/", function()
         util.run_mock_project(finally, {
            dir_structure = {
               ["tlconfig.lua"] = [[]],
               ["build.tl"] = [[
                  return {
                     gen_code = function(path: string)
                        print("Build Script")
                        print(path)
                     end,
                  }
               ]],
            },
            cmd = "build",
            generated_files = {},
            cmd_output = "Build Script\ngenerated_code" .. package.config:sub(1, 1) .. "\nAll files up to date\n"
         })
      end)

      it("should report errors", function()
         util.run_mock_project(finally, {
            dir_structure = {
               ["tlconfig.lua"] = [[]],
               ["build.tl"] = [[
                  return {
                     gen_code = function(_path: string)
                        error("hello")
                     end,
                  }
               ]],
            },
            cmd = "build",
            generated_files = {},
            cmd_output = table.concat({
               "Error in gen_code: build.tl:3: hello\nstack traceback:",
               "[C]: in function 'error'",
               "build.tl:3: in field 'gen_code'\n",
            }, "\n\t"),
         })
      end)
   end)

   describe("after", function()
      it("should run after build has finished", function()
         util.run_mock_project(finally, {
            dir_structure = {
               ["tlconfig.lua"] = [[]],
               ["foo.tl"] = [[]],
               ["build.tl"] = [[
                  return {
                     after = function()
                        print("After")
                     end,
                  }
               ]],
            },
            cmd = "build",
            generated_files = {
               "foo.lua"
            },
            cmd_output = "Wrote: foo.lua\nAfter\n",
         })
      end)

      it("should report errors", function()
         util.run_mock_project(finally, {
            dir_structure = {
               ["tlconfig.lua"] = [[]],
               ["foo.tl"] = [[]],
               ["build.tl"] = [[
                  return {
                     after = function()
                        error("After")
                     end,
                  }
               ]],
            },
            cmd = "build",
            generated_files = {
               "foo.lua"
            },
            cmd_output = "Wrote: foo.lua\nError in after: build.tl:3: After\n" .. table.concat({
               "stack traceback:",
               "[C]: in function 'error'",
               "build.tl:3: in function <build.tl:2>\n",
            }, "\n\t")
         })
      end)
   end)

   it("can have a diffrent name by setting build_file", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {
               build_file = "other_name.tl"
            }]],
            ["other_name.tl"] = [[
               return {}
            ]],
         },
         cmd = "build",
         generated_files = {},
         cmd_output = "All files up to date\n",
      })
   end)

   it("Should not run when running something else than build", function()
      util.run_mock_project(finally, {
         dir_structure = {
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
         args = { "foo.tl" },
         cmd_output = "build.tl did not run\n"
      })

   end)

   pending("Should run when running something else than build and --run-build-script is passed", function()
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

   it("should only run the build script if there are other files to be processed", function()
      util.do_in(util.write_tmp_dir(finally, {
         ["tlconfig.lua"] = [[
            return {
               source_dir = "src",
               build_dir = "build",
            }
         ]],
         ["build.tl"] = [[
            return {
               gen_code = function()
                  print("Gen Code")
               end,
            }
         ]],
         ["src"] = { ["foo.tl"] = [[]] },
         ["build"] = {},
      }), function()
         assert.are.same("Gen Code\nWrote: build/foo.lua\n", runcmd(build_cmd))
         assert.match("All files up to date\n", runcmd(build_cmd))
         lfs.touch("src/foo.tl", os.time() + 5)
         assert.are.same("Gen Code\nWrote: build/foo.lua\n", runcmd(build_cmd))
      end)
   end)

   it("Should give an error if the build script contains invalid teal", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {}]],
            ["build.tl"] = [[ todo: write my super cool build file ]],
            ["bar.tl"] = [[print "bar"]],
         },
         cmd = "build",
         cmd_output =
[[========================================
1 syntax error:
build.tl:1:2: syntax error
]],
      })
   end)

   it("Should give an error if the key gen_code exists, but it is not a function", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {
               build_dir = "build",
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
         cmd_output = "Type error in build script gen_code: Expected function, got string\n",
      })
   end)
end)
