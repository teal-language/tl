local util = require("spec.util")
local lfs = require("lfs")

local build_cmd = util.tl_cmd("build")
local function runcmd(cmd)
   local ph = io.popen(cmd, "r")
   local out = ph:read("*a")
   util.assert_popen_close(true, "exit", 0, ph:close())
   return out
end

describe("build command", function()
   it("should exit with non zero exit code when there is an error", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return {}]],
            ["foo.tl"] = [[print "a"]],
            ["bar.tl"] = [[local x: string = 10]],
         },
         cmd = "build",
         popen = {
            status = nil,
            exit = "exit",
            code = 1,
         },
      })
   end)

   it("should not error when tlconfig returns nil/nothing", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[]],
         },
         cmd = "build",
         popen = {
            status = true,
            exit = "exit",
            code = 0,
         },
      })
   end)

   it("should find tlconfig.lua in a parent directory", function()
      util.do_in(util.write_tmp_dir(finally, {
         ["tlconfig.lua"] = [[
            return {
               source_dir = "src"
            }
         ]],
         src = {
            ["foo.tl"] = "",
         },
      }), function()
         local ph = io.popen("cd src && " .. util.tl_cmd("build"), "r")
         ph:read("*a")
         util.assert_popen_close(true, "exit", 0, ph:close())
      end)
   end)

   describe("lazy rebuilds", function()
      it("should not recompile when targets are newer than sources", function()
         util.do_in(util.write_tmp_dir(finally, {
            ["tlconfig.lua"] = [[
               return {
                  source_dir = "src",
                  build_dir = "build",
               }
            ]],
            ["src"] = {
               ["foo.tl"] = [[]]
            },
         }), function()
            assert.are.same(runcmd(build_cmd), "Created directory: build\nWrote: build/foo.lua\n")
            assert.match(runcmd(build_cmd), "All files up to date\n")
         end)
      end)

      it("should recompile when sources are newer than targets", function()
         util.do_in(util.write_tmp_dir(finally, {
            ["tlconfig.lua"] = [[
               return {
                  source_dir = "src",
                  build_dir = "build",
               }
            ]],
            ["src"] = {
               ["foo.tl"] = [[]]
            },
         }), function()
            assert.are.same("Created directory: build\nWrote: build/foo.lua\n", runcmd(build_cmd))
            assert.match("All files up to date\n", runcmd(build_cmd))
            lfs.touch("src/foo.tl", os.time() + 5)
            assert.are.same("Wrote: build/foo.lua\n", runcmd(build_cmd))
         end)
      end)

      it("should recompile when given --update-all flag", function()
         util.do_in(util.write_tmp_dir(finally, {
            ["tlconfig.lua"] = [[
               return {
                  source_dir = "src",
                  build_dir = "build",
               }
            ]],
            ["src"] = {
               ["foo.tl"] = [[]]
            },
         }), function()
            local cmd = util.tl_cmd("build", "--update-all")
            assert.are.same("Created directory: build\nWrote: build/foo.lua\n", runcmd(cmd))
            assert.are.same("Wrote: build/foo.lua\n", runcmd(cmd))
         end)
      end)
   end)

   it("should be able to detect circular dependencies", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[]],
            ["foo.tl"] = [[require"bar"]],
            ["bar.tl"] = [[require"foo"]],
            ["baz.tl"] = [[require"foo"]],
         },
         cmd = "build",
         popen = {
            status = nil,
            exit = "exit",
            code = 1,
         },
         cmd_output = "Circular dependency detected in the following files:\n"
                   .. "   foo.tl depends on: bar.tl\n"
                   .. "   bar.tl, baz.tl all depend on: foo.tl\n"
      })
   end)
end)
