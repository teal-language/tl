local tl = require("tl")
local util = require("spec.util")


local function string_trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end


describe("doublequote string", function()
   it("accepts", util.check([[local foo = "bar"]]))

   it("export Lua", function()
      local result = tl.process_string([[local foo = "bar"]])
      local lua = tl.pretty_print_ast(result.ast)
      assert.equal([[local foo = "bar"]], string_trim(lua))
   end)
end)
