local util = require("spec.util")

describe("tl run", function()
   setup(util.chdir_setup)
   teardown(util.chdir_teardown)
   describe("on .tl files", function()
      it("works on empty files", function()
         local name = util.write_tmp_file(finally, [[]])
         local pd = io.popen(util.tl_cmd("run", name), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         util.assert_line_by_line([[]], output)
      end)

      it("reports nothing if no errors, runs and returns code 0 on success", function()
         local name = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add(10, 20))
         ]])
         local pd = io.popen(util.tl_cmd("run", name), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         util.assert_line_by_line([[
            30
         ]], output)
      end)

      it("reports number of errors in stderr and code 1 on type errors", function()
         local name = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add("string", 20))
            print(add(10, true))
         ]])
         local pd = io.popen(util.tl_cmd("run", name) .. "2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match("2 errors:", output, 1, true)
      end)

      it("reports number of errors in stderr and code 1 on syntax errors", function()
         local name = util.write_tmp_file(finally, [[
            print(add("string", 20))))))
         ]])
         local pd = io.popen(util.tl_cmd("run", name) .. "2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match("1 syntax error:", output, 1, true)
      end)

      it("reports use of unknowns as errors in stderr and returns code 1", function()
         local name = util.write_tmp_file(finally, [[
            local function unk(x, y): number, number
               return a + b
            end
         ]])
         local pd = io.popen(util.tl_cmd("run", name) .. "2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match("2 errors:", output, 1, true)
         assert.match("unknown variable: a", output, 1, true)
         assert.match("unknown variable: b", output, 1, true)
      end)

      it("can require other .tl files", function()
         local dir_name = util.write_tmp_dir(finally, {
            ["add.tl"] = [[
            local function add(a: number, b: number): number
               return a + b
            end

            return add
            ]],
            ["main.tl"] = [[
            local add = require("add")

            print(add(10, 20))
            ]]
         })
         local pd, output
         util.do_in(dir_name, function()
            pd = io.popen(util.tl_cmd("run", "main.tl"), "r")
            output = pd:read("*a")
         end)
         util.assert_popen_close(0, pd:close())
         util.assert_line_by_line([[
            30
         ]], output)
      end)

      it("passes standard arguments to required chunks", function()
         local dir_name = util.write_tmp_dir(finally, {
            ["ld.tl"] = [[
            require("foo")
            print("Done")
            ]],
            ["foo.tl"] = [[
            print(...)
            ]]
         })
         local pd, output
         util.do_in(dir_name, function()
            pd = io.popen(util.tl_cmd("run", "ld.tl"), "r")
            output = pd:read("*a")
         end)
         util.assert_popen_close(0, pd:close())
         util.assert_line_by_line(util.os_path([[
            foo ./foo.tl
            Done
         ]]), output)
      end)

      describe("-l --require", function()
         it("can require a module from the CLI like Lua", function()
            local dir_name = util.write_tmp_dir(finally, {
               ["add.tl"] = [[
               global function add(a: number, b: number): number
                  return a + b
               end

               return add
               ]],
               ["main.tl"] = [[
               print(add(10, 20))
               ]]
            })
            for _, flag in ipairs({ "-l add", "-ladd", "--require add" }) do
               local pd, output
               util.do_in(dir_name, function()
                  pd = io.popen(util.tl_cmd("run " .. flag, "main.tl"), "r")
                  output = pd:read("*a")
               end)
               util.assert_popen_close(0, pd:close())
               util.assert_line_by_line([[
                  30
               ]], output)
            end
         end)
      end)
   end)

   describe("on .lua files", function()
      it("reports nothing if no errors, runs and code 0 on success", function()
         local name = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add(10, 20))
         ]])
         local pd = io.popen(util.tl_cmd("run", name), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         util.assert_line_by_line([[
            30
         ]], output)
      end)

      it("ignores type errors, runs anyway and fails with a runtime error", function()
         local name = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add("string", 20))
            print(add(10, true))
         ]], "lua")
         local pd = io.popen(util.tl_cmd("run", name) .. "2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         if _VERSION == "Lua 5.4" then
            assert.match("attempt to add a 'string' with a 'number'", output, 1, true)
         else
            assert.match("attempt to perform arithmetic on", output, 1, true)
         end
      end)

      it("reports number of errors in stderr and code 1 on syntax errors", function()
         local name = util.write_tmp_file(finally, [[
            print(add("string", 20))))))
         ]])
         local pd = io.popen(util.tl_cmd("run", name) .. "2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match("1 syntax error:", output, 1, true)
      end)

      it("ignores unknown variables and runs anyway", function()
         local name = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            local function sub(x, y): number
               return x + y
            end
         ]], "lua")
         local pd = io.popen(util.tl_cmd("run", name) .. "2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         assert.same("", output)
      end)
   end)

   describe("with arguments", function()
      it("passes arguments as arg", function()
         local name = util.write_tmp_file(finally, [[
            for i = -10, 10 do
               print(i .. " " .. tostring(arg[i]))
            end
         ]])
         local pd = io.popen(util.tl_cmd("run", name, "hello", "world"), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         util.assert_line_by_line([[
            -10 nil
            -9 nil
            -8 nil
            -7 nil
            -6 nil
            -5 nil
            -4 nil
            -3 ]] .. util.lua_interpreter .. "\n" .. [[
            -2 ]] .. util.tl_executable .. "\n" .. [[
            -1 run
            0 ]] .. name .. "\n" .. [[
            1 hello
            2 world
            3 nil
            4 nil
            5 nil
            6 nil
            7 nil
            8 nil
            9 nil
            10 nil
         ]], output)
      end)

      it("allows -- to stop argument parsing after script name", function()
         local name = util.write_tmp_file(finally, [[
            for i = -10, 10 do
               print(i .. " " .. tostring(arg[i]))
            end
         ]])
         local pd = io.popen(util.tl_cmd("run", name, "--", "--skip-compat53", "hello", "world"), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         util.assert_line_by_line([[
            -10 nil
            -9 nil
            -8 nil
            -7 nil
            -6 nil
            -5 nil
            -4 ]] .. util.lua_interpreter .. "\n" .. [[
            -3 ]] .. util.tl_executable .. "\n" .. [[
            -2 run
            -1 --
            0 ]] .. name .. "\n" .. [[
            1 --skip-compat53
            2 hello
            3 world
            4 nil
            5 nil
            6 nil
            7 nil
            8 nil
            9 nil
            10 nil
         ]], output)
      end)

      it("allows -- to stop argument parsing before script name", function()
         local name = util.write_tmp_file(finally, [[
            for i = -10, 10 do
               print(i .. " " .. tostring(arg[i]))
            end
         ]])
         local pd = io.popen(util.tl_cmd("run", "--", name, "--skip-compat53", "hello", "world"), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         util.assert_line_by_line([[
            -10 nil
            -9 nil
            -8 nil
            -7 nil
            -6 nil
            -5 nil
            -4 ]] .. util.lua_interpreter .. "\n" .. [[
            -3 ]] .. util.tl_executable .. "\n" .. [[
            -2 run
            -1 --
            0 ]] .. name .. "\n" .. [[
            1 --skip-compat53
            2 hello
            3 world
            4 nil
            5 nil
            6 nil
            7 nil
            8 nil
            9 nil
            10 nil
         ]], output)
      end)

      it("does not get arguments and non-arguments confused when they look the same", function()
         local name = util.write_tmp_file(finally, [[
            for i = -10, 10 do
               print(i .. " " .. tostring(arg[i]))
            end
         ]])
         local pd = io.popen(util.tl_cmd("run", "-I", ".", "--", name, "-I", ".", "hello", "world"), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         util.assert_line_by_line([[
            -10 nil
            -9 nil
            -8 nil
            -7 nil
            -6 ]] .. util.lua_interpreter .. "\n" .. [[
            -5 ]] .. util.tl_executable .. "\n" .. [[
            -4 run
            -3 -I
            -2 .
            -1 --
            0 ]] .. name .. "\n" .. [[
            1 -I
            2 .
            3 hello
            4 world
            5 nil
            6 nil
            7 nil
            8 nil
            9 nil
            10 nil
         ]], output)
      end)

      it("passes args through as ... to the target script", function()
         local name = util.write_tmp_file(finally, [[
            local args = {...}
            for i = -5, 5 do
               print(i .. " " .. tostring(args[i]))
            end
         ]])
         local pd = io.popen(util.tl_cmd("run", "-I", ".", "--", name, "-I", ".", "hello", "world"), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         util.assert_line_by_line([[
         -5 nil
         -4 nil
         -3 nil
         -2 nil
         -1 nil
         0 nil
         1 -I
         2 .
         3 hello
         4 world
         5 nil
      ]], output)
     end)
   end)

   it("compilation errors should be caught when loading modules", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["my_module.tl"] = [[todo, write module :)]],
            ["my_script.tl"] = [[local mod = require("my_module"); mod.do_things()]],
         },
         cmd = "run",
         args = { "my_script.tl" },
         exit_code = 1,
      })
   end)
end)
