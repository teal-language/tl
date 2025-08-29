local assert = require("luassert")
local json = require("dkjson")
local util = require("spec.util")

describe("tl types works like check", function()
   describe("on .tl files", function()
      it("reports missing files", function()
         local pd = io.popen(util.tl_cmd("types", "nonexistent_file") .. "2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match("could not open nonexistent_file", output, 1, true)
      end)

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
      end)

      it("scans multiple files; symbols reports only the first one; symbols_by_file reports all", function()
         local name0 = util.write_tmp_file(finally, [[
            local function add0(a: number, b: number): number
               return a + b
            end

            return add0
         ]])
         local dirname, modname = name0:match("^(.*[/\\])([^.]+).tl$")
         local name1 = util.write_tmp_file(finally, [[
            local mod = require("]] .. modname .. [[")
            local function add1(a: number, b: number): number
               return a + b
            end

            print(add1(10, 20), mod(30, 40))
         ]])
         local name2 = util.write_tmp_file(finally, [[
            local function add2(a: number, b: number): number
               return a + b
            end

            print(add2(10, 20))
         ]])
         local pd = io.popen(util.tl_cmd("types", "-I", dirname, name1, name2), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         local types = json.decode(output)
         -- "symbols" reports a single file
         assert(types.symbols)
         local y, x = 1, 1
         for _, s in ipairs(types.symbols) do
            local sy, sx = s[1], s[2]
            assert(sy > y or (sy == y and sx >= x), "symbols list is not sorted")
            y, x = sy, sx
         end
         -- "symbols_by_file" reports each file
         assert(types.symbols_by_file)
         for _name, symbols in pairs(types.symbols_by_file) do
            y, x = 1, 1
            for _, s in ipairs(symbols) do
               local sy, sx = s[1], s[2]
               assert(sy > y or (sy == y and sx >= x), "symbols list is not sorted")
               y, x = sy, sx
            end
         end
         -- "symbols" matches the first file
         local first = types.symbols_by_file[name1]
         assert(#first == #types.symbols)
         local found_add1 = false
         for i, s in ipairs(types.symbols) do
            local f = first[i]
            if s[3] == "add1" then
               found_add1 = true
            end
            assert(s[1] == f[1] and s[2] == f[2] and s[3] == f[3] and s[4] == f[4])
         end
         assert(found_add1)
      end)

      it("reports symbols in scope for a position", function()
         local name0 = util.write_tmp_file(finally, [[
            local function add0(a: number, b: number): number
               return a + b
            end

            return add0
         ]])
         local dirname, modname = name0:match("^(.*[/\\])([^.]+).tl$")
         local name1 = util.write_tmp_file(finally, [[
            local mod = require("]] .. modname .. [[")
            local function add1(a: number, b: number): number
               return a + b
            end

            print(add1(10, 20), mod(30, 40))
         ]])
         local name2 = util.write_tmp_file(finally, [[
            local function add2(a: number, b: number): number
               return a + b
            end

            print(add2(10, 20))
         ]])
         local pd = io.popen(util.tl_cmd("types", "-I", dirname, "-p", "3:23", name1, name2), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         local types = json.decode(output)
         local n = 0
         for _ in pairs(types) do
            n = n + 1
         end
         assert(n == 4)
         assert(type(types["a"]) == "number")
         assert(type(types["add1"]) == "number")
         assert(type(types["mod"]) == "number")
         assert(type(types["b"]) == "number")
         assert(type(types["x"]) == "nil")
         assert(type(types["add2"]) == "nil")
         assert(type(types["y"]) == "nil")
      end)

      it("reports end of if-block correctly", function()
         local filename = util.write_tmp_file(finally, [[
            -- test.tl

            local function hello(): number
                return 1
            end

            if 1 == 1 then
                local abc = hello()
                local _def = abc





                _def = abc
            end
         ]])
         local pd = io.popen(util.tl_cmd("types", "-p", "12:1", filename), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         local types = json.decode(output)
         local n = 0
         for _ in pairs(types) do
            n = n + 1
         end
         assert(n == 3)
         assert(type(types["abc"]) == "number")
         assert(type(types["_def"]) == "number")
         assert(type(types["hello"]) == "number")
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

      it("does not crash when a require() expression does not resolve (#778)", function()
         local name = util.write_tmp_file(finally, [[
            local type Foo = require("missingmodule").baz
         ]])
         local pd = io.popen(util.tl_cmd("types", name, "--gen-target=5.1") .. "2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match("1 error:", output, 1, true)
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
         assert(by_pos["1"]["21"]) -- "os"
         assert(by_pos["1"]["26"]) -- .
      end)

      it("produce values for forin variables", function()
         local name = util.write_tmp_file(finally, [[
            local x: {string:boolean} = {}
            for k, v in pairs(x) do
            end
         ]])
         local pd = io.popen(util.tl_cmd("types", name) .. " 2>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         local types = json.decode(output)
         assert(types.by_pos)
         local by_pos = types.by_pos[next(types.by_pos)]
         local function map_to_str(tbl)
            local ntbl = {}
            for k, v in pairs(tbl) do
               ntbl[k] = assert(types.types[tostring(v)]).str
            end
            return ntbl
         end

         assert.same({
            ["19"] = '{string : boolean}',
            ["22"] = '{string : boolean}',
            ["23"] = 'string',
            ["30"] = 'boolean',
            ["41"] = '{string : boolean}',
         }, map_to_str(by_pos["1"]))
         assert.same({
            ["17"] = 'string',
            ["20"] = 'boolean',
            ["25"] = 'function({K : V}): (function({K : V}, ? K): (K, V), {K : V}, K)',
            ["31"] = '{string : boolean}',
         }, map_to_str(by_pos["2"]))
      end)
   end)
end)
