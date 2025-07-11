local tl = require("tl-block")
local util = require("spec.block-util")


local function string_trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end


describe("singlequote string", function()
   it("accepts", util.check [[local foo = 'bar']])

   it("export Lua", function()
      local result = tl.process_string([[local foo = 'bar']])
      local lua = tl.pretty_print_ast(result.ast)
      assert.equal([[local foo = 'bar']], string_trim(lua))
   end)
end)
