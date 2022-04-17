require("compat53")

describe("tl.load", function()

   describe("loading Teal code from Lua", function()
      it("works", function()
         local lua_code = [[
            -- test.lua
            local tl = require('tl')

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
            local tl = require('tl')

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
            local tl = require('tl')

            local program, err = tl.load('local a: string = 123; return a', 'code.tl')
            return program()
         ]]
         local lua_chunk = load(lua_code)
         local result = lua_chunk()
         assert.same(result, 123)
      end)
   end)
end)
