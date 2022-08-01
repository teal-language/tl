local assert = require("luassert")
local util = require("spec.util")

describe("tl check", function()
   describe("on .tl files", function()
      it("works on empty files", function()
         local name = util.write_tmp_file(finally, [[]])
         local pd = io.popen(util.tl_cmd("check", name), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         assert.match("0 errors detected", output, 1, true)
      end)

      it("reports 0 errors and code 0 on success", function()
         local name = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add(10, 20))
         ]])
         local pd = io.popen(util.tl_cmd("check", name), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
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
         local pd = io.popen(util.tl_cmd("check", name) .. "2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
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
         local pd = io.popen(util.tl_cmd("check", name1, name2) .. " 2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match(name1 .. ":", output, 1, true)
         assert.match(name2 .. ":", output, 1, true)
      end)

      it("reports number of errors in stderr and code 1 on syntax errors", function()
         local name = util.write_tmp_file(finally, [[
            print(add("string", 20))))))
         ]])
         local pd = io.popen(util.tl_cmd("check", name) .. "2>&1 1>" .. util.os_null, "r")
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
         local pd = io.popen(util.tl_cmd("check", name) .. "2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
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
         util.assert_popen_close(0, pd:close())
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
         local pd = io.popen(util.tl_cmd("check", name) .. " 2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match("2 errors:", output, 1, true)
      end)

      it("reports number of errors in stderr and code 1 on syntax errors", function()
         local name = util.write_tmp_file(finally, [[
            print(add("string", 20))))))
         ]], "lua")
         local pd = io.popen(util.tl_cmd("check", name) .. "2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
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
         local pd = io.popen(util.tl_cmd("check", name) .. " 2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         assert.match("unknown variable: x", output, 1, true)
         assert.match("unknown variable: y", output, 1, true)
      end)
   end)

   it("can check the global env def file (#518)", function()
      local dir_name = util.write_tmp_dir(finally, {
         ["somefile.d.tl"] = [[
            local type Foobar = number
            local MyLocalNumber: number
            local MyLocalFoobar: Foobar
            global MyGlobalNumber: number
            global MyGlobalFoobar: Foobar
         ]],
      })
      local pd, output
      util.do_in(dir_name, function()
         pd = io.popen(util.tl_cmd("check", "--global-env-def", "somefile", "somefile.d.tl") .. " 2>&1 1>" .. util.os_null, "r")
         output = pd:read("*a")
      end)
      util.assert_popen_close(0, pd:close())
      assert.match("2 warnings:", output, 1, true)
      assert.match("somefile.d.tl:3:19: unused variable MyLocalFoobar: Foobar", output, 1, true)
      assert.match("somefile.d.tl:2:19: unused variable MyLocalNumber: number", output, 1, true)
   end)
end)
