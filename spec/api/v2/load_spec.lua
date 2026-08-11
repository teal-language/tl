require("compat53")

local util = require("spec.util")

describe("tl.load", function()

   describe("loading Teal code from Lua", function()
      it("works", function()
         local lua_code = [[
            -- test.lua
            local tl = require('teal.api.v2')

            local program, err = tl.load('local a: string = "hey"; return a')
            return program()
         ]]
         local lua_chunk = load(lua_code)
         local result = lua_chunk()
         assert.same(result, "hey")
      end)

      it("can produce type checking errors when using 'c'", function()
         local lua_code = [[
            -- test.lua
            local tl = require('teal.api.v2')

            local program, err = tl.load('local a: string = 123; return a', 'code.tl', 'ct')
            assert(program == nil)
            return err
         ]]
         local lua_chunk = load(lua_code)
         local result = lua_chunk()
         assert.match(result, "code.tl:1:19: in local declaration: a: got integer, expected string")
      end)

      it("can run even with type check errors if not using 'c'", function()
         local lua_code = [[
            -- test.lua
            local tl = require('teal.api.v2')

            local program, err = tl.load('local a: string = 123; return a', 'code.tl')
            return program()
         ]]
         local lua_chunk = load(lua_code)
         local result = lua_chunk()
         assert.same(result, 123)
      end)

      -- run in a subprocess: requiring compat53 above patches the stdlib
      -- globally, which would mask a missing compat preamble on Lua < 5.3
      it("applies Lua version compatibility code", function()
         local dir_name = util.write_tmp_dir(finally, {
            ["main.lua"] = [[
            local tl = require("teal.api.v2")
            local program = assert(tl.load("local n: number = 3.0; return math.tointeger(n)"))
            print(program())
            ]]
         })
         local pd, output
         util.do_in(dir_name, function()
            pd = io.popen(util.lua_cmd("main.lua"), "r")
            output = pd:read("*a")
         end)
         util.assert_popen_close(0, pd:close())
         util.assert_line_by_line([[
            3
         ]], output)
      end)
   end)
end)
