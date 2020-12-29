local util = require("spec.util")

describe("tl check", function()
   describe("on .tl files", function()
      it("reports 0 errors and code 0 on success", function()
         local name = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add(10, 20))
         ]])
         local pd = io.popen(util.tl_cmd("check", name), "r")
         local output = pd:read("*a")
         util.assert_popen_close(true, "exit", 0, pd:close())
         assert.match("0 errors detected", output, 1, true)
      end)

      it("reports number of errors in stderr and code 1 on type errors", function()
         local name = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add("string", 20))
            print(add(10, true))
         ]])
         local pd = io.popen("./tl check " .. name .. " 2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(nil, "exit", 1, pd:close())
         assert.match("2 errors:", output, 1, true)
      end)

      it("reports errors in multiple files", function()
         local name1 = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add("string", 20))
            print(add(10, true))
         ]])
         local name2 = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add("string", 20))
            print(add(10, true))
         ]])
         local pd = io.popen(util.tl_cmd("check", name1, name2) .. " 2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(nil, "exit", 1, pd:close())
         assert.match(name1 .. ":", output, 1, true)
         assert.match(name2 .. ":", output, 1, true)
      end)

      it("reports number of errors in stderr and code 1 on syntax errors", function()
         local name = util.write_tmp_file(finally, [[
            print(add("string", 20))))))
         ]])
         local pd = io.popen(util.tl_cmd("check", name) .. "2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(nil, "exit", 1, pd:close())
         assert.match("1 syntax error:", output, 1, true)
      end)

      it("reports use of unknowns as errors in stderr and returns code 1", function()
         local name = util.write_tmp_file(finally, [[
            local function unk(x, y): number, number
               return a + b
            end
         ]])
         local pd = io.popen(util.tl_cmd("check", name) .. "2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(nil, "exit", 1, pd:close())
         assert.match("2 errors:", output, 1, true)
         assert.match("unknown variable: a", output, 1, true)
         assert.match("unknown variable: b", output, 1, true)
      end)
   end)

   describe("on .lua files", function()
      it("reports 0 errors and code 0 on success", function()
         local name = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add(10, 20))
         ]], "lua")
         local pd = io.popen(util.tl_cmd("check", name), "r")
         local output = pd:read("*a")
         util.assert_popen_close(true, "exit", 0, pd:close())
         assert.match("0 errors detected", output, 1, true)
      end)

      it("reports number of errors in stderr and code 1 on type errors", function()
         local name = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add("string", 20))
            print(add(10, true))
         ]], "lua")
         local pd = io.popen(util.tl_cmd("check", name) .. " 2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(nil, "exit", 1, pd:close())
         assert.match("2 errors:", output, 1, true)
      end)

      it("reports number of errors in stderr and code 1 on syntax errors", function()
         local name = util.write_tmp_file(finally, [[
            print(add("string", 20))))))
         ]], "lua")
         local pd = io.popen(util.tl_cmd("check", name) .. "2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(nil, "exit", 1, pd:close())
         assert.match("1 syntax error:", output, 1, true)
      end)

      it("reports unknowns variables in stderr and code 0 if no errors", function()
         local name = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            local function sub(x, y): number
               return x + y
            end
         ]], "lua")
         local pd = io.popen(util.tl_cmd("check", name) .. " 2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(true, "exit", 0, pd:close())
         assert.match("2 unknown variables:", output, 1, true)
      end)
   end)
end)
