local util = require("spec.util")

describe("tl run", function()
   describe("on .tl files", function()
      it("reports nothing if no errors, runs and returns code 0 on success", function()
         local name = util.write_tmp_file(finally, "add.tl", [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add(10, 20))
         ]])
         local pd = io.popen("./tl run " .. name, "r")
         local output = pd:read("*a")
         util.assert_popen_close(true, "exit", 0, pd:close())
         util.assert_line_by_line([[
            30
         ]], output)
      end)

      it("reports number of errors in stderr and code 1 on type errors", function()
         local name = util.write_tmp_file(finally, "add.tl", [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add("string", 20))
            print(add(10, true))
         ]])
         local pd = io.popen("./tl run " .. name .. " 2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(nil, "exit", 1, pd:close())
         assert.match("2 errors:", output, 1, true)
      end)

      it("reports number of errors in stderr and code 1 on syntax errors", function()
         local name = util.write_tmp_file(finally, "add.tl", [[
            print(add("string", 20))))))
         ]])
         local pd = io.popen("./tl run " .. name .. " 2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(nil, "exit", 1, pd:close())
         assert.match("1 syntax error:", output, 1, true)
      end)

      it("reports use of unknowns as errors in stderr and returns code 1", function()
         local name = util.write_tmp_file(finally, "add.tl", [[
            local function unk(x, y): number, number
               return a + b
            end
         ]])
         local pd = io.popen("./tl run " .. name .. " 2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(nil, "exit", 1, pd:close())
         assert.match("2 errors:", output, 1, true)
         assert.match("unknown variable: a", output, 1, true)
         assert.match("unknown variable: b", output, 1, true)
      end)
   end)

   describe("on .lua files", function()
      it("reports nothing if no errors, runs and code 0 on success", function()
         local name = util.write_tmp_file(finally, "add.lua", [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add(10, 20))
         ]])
         local pd = io.popen("./tl run " .. name, "r")
         local output = pd:read("*a")
         util.assert_popen_close(true, "exit", 0, pd:close())
         util.assert_line_by_line([[
            30
         ]], output)
      end)

      it("ignores type errors, runs anyway and fails with a runtime error", function()
         local name = util.write_tmp_file(finally, "add.lua", [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add("string", 20))
            print(add(10, true))
         ]])
         local pd = io.popen("./tl run " .. name .. " 2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(nil, "exit", 1, pd:close())
         assert.match("attempt to perform arithmetic on", output, 1, true)
      end)

      it("reports number of errors in stderr and code 1 on syntax errors", function()
         local name = util.write_tmp_file(finally, "add.lua", [[
            print(add("string", 20))))))
         ]])
         local pd = io.popen("./tl run " .. name .. " 2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(nil, "exit", 1, pd:close())
         assert.match("1 syntax error:", output, 1, true)
      end)

      it("ignores unknown variables and runs anyway", function()
         local name = util.write_tmp_file(finally, "add.lua", [[
            local function add(a: number, b: number): number
               return a + b
            end

            local function sub(x, y): number
               return x + y
            end
         ]])
         local pd = io.popen("./tl run " .. name .. " 2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(true, "exit", 0, pd:close())
         assert.same("", output)
      end)
   end)
end)
