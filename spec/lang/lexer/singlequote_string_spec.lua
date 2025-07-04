local tl = require("teal.api.v2")
local util = require("spec.util")


local function string_trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end


describe("singlequote string", function()
   it("accepts", util.check [[local foo = 'bar']])

   it("export Lua", function()
      local result = tl.check_string([[local foo = 'bar']])
      local lua = tl.generate(result.ast)
      assert.equal([[local foo = 'bar']], string_trim(lua))
   end)
end)
