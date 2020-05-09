local tl = require("tl")

describe("assignment to maps", function()
   it("resolves a record to a map", function()
      local tokens = tl.lex([[
         local m: {string:number} = {
            hello = 123,
            world = 234,
         }
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
   it("resolves strings to enum", function()
      local tokens = tl.lex([[
         local Direction = enum
            "north"
            "south"
            "east"
            "west"
         end
         local m: {string:Direction} = {
            hello = "north",
            world = "south",
         }
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
