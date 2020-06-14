describe("tl.load", function()

   it("can load Teal code from Lua", function()
      finally(function()
         if package.searchers then
            table.remove(package.searchers, 2)
         else
            table.remove(package.loaders, 2)
         end
      end)

      local lua_code = [[
         -- test.lua
         local tl = require('tl')
         tl.loader()

         local program, err = tl.load('local a: string = "hey"; return a')
         return program()
      ]]
      local lua_chunk = load(lua_code)
      local result = lua_chunk()
      assert.same(result, "hey")
   end)

end)
