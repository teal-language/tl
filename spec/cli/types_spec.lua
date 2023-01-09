local assert = require("luassert")
local json = require("dkjson")
local util = require("spec.util")

describe("tl types works like check", function()
   describe("on .tl files", function()
      it("works on empty files", function()
         local name = util.write_tmp_file(finally, [[]])
         local pd = io.popen(util.tl_cmd("types", name) .. " 2>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         -- TODO check json output
      end)

      it("reports 0 errors and code 0 on success", function()
         local name = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add(10, 20))
         ]])
         local pd = io.popen(util.tl_cmd("types", name) .. " 2>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         -- TODO check json output
      end)

      it("reports number of errors in stderr and code 1 on type errors", function()
         local name = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add("string", 20))
            print(add(10, true))
         ]])
         local pd = io.popen(util.tl_cmd("types", name) .. "2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match("2 errors:", output, 1, true)
         -- TODO check json output
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
         local pd = io.popen(util.tl_cmd("types", name1, name2) .. " 2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match(name1 .. ":", output, 1, true)
         assert.match(name2 .. ":", output, 1, true)
         -- TODO check json output
      end)

      it("reports number of errors in stderr and code 1 on syntax errors", function()
         local name = util.write_tmp_file(finally, [[
            print(add("string", 20))))))
         ]])
         local pd = io.popen(util.tl_cmd("types", name) .. "2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match("1 syntax error:", output, 1, true)
         -- TODO check json output
      end)

      it("reports use of unknowns as errors in stderr and returns code 1", function()
         local name = util.write_tmp_file(finally, [[
            local function unk(x, y): number, number
               return a + b
            end
         ]])
         local pd = io.popen(util.tl_cmd("types", name) .. "2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match("2 errors:", output, 1, true)
         assert.match("unknown variable: a", output, 1, true)
         assert.match("unknown variable: b", output, 1, true)
         -- TODO check json output
      end)

      it("does not get confused by compat code when using --get-target=5.1 (#430)", function()
         local name = util.write_tmp_file(finally, [[
            local x: integer = 1//2
            print(x)
         ]])
         local pd = io.popen(util.tl_cmd("types", name, "--gen-target=5.1") .. "2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         -- TODO check json output
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
         local pd = io.popen(util.tl_cmd("types", name) .. " 2>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         -- TODO check json output
      end)

      it("reports number of errors in stderr and code 1 on type errors", function()
         local name = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add("string", 20))
            print(add(10, true))
         ]])
         local pd = io.popen(util.tl_cmd("types", name) .. " 2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match("2 errors:", output, 1, true)
         -- TODO check json output
      end)

      it("reports number of errors in stderr and code 1 on syntax errors", function()
         local name = util.write_tmp_file(finally, [[
            print(add("string", 20))))))
         ]])
         local pd = io.popen(util.tl_cmd("types", name) .. "2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match("1 syntax error:", output, 1, true)
         -- TODO check json output
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
         local pd = io.popen(util.tl_cmd("types", name) .. " 2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         assert.match("unknown variable: x", output, 1, true)
         assert.match("unknown variable: y", output, 1, true)
         -- TODO check json output
      end)

      it("regression test for #386", function()
         local name = util.write_tmp_file(finally, [[
            local type X = function(callback: function(filename: string))
         ]])
         local pd = io.popen(util.tl_cmd("types", name) .. " 2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         assert.not_match("assertion failed", output, 1, true)
         -- TODO check json output
      end)

      it("regression test for #611", function()
         local name = util.write_tmp_file(finally, [[
            local type vec3 = r
         ]])
         local pd = io.popen(util.tl_cmd("types", name) .. " 2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.not_match("assertion failed", output, 1, true)
         -- TODO check json output
      end)

      it("produce values for incomplete input", function()
         local name = util.write_tmp_file(finally, [[
            require("os").
         ]])
         local pd = io.popen(util.tl_cmd("types", name) .. " 2>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         local types = json.decode(output)
         assert(types.by_pos)
         local by_pos = types.by_pos[next(types.by_pos)]
         assert(by_pos["1"])
         assert(by_pos["1"]["13"]) -- require
         assert(by_pos["1"]["20"]) -- (
         assert(by_pos["1"]["21"]) -- "os"
         assert(by_pos["1"]["26"]) -- .
         assert(by_pos["1"]["20"] == by_pos["1"]["26"])
      end)
   end)
end)
