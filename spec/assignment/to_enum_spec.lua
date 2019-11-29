local tl = require("tl")

describe("assignment to enum", function()
   it("accepts a valid string", function()
      local tokens = tl.lex([[
         local Direction = enum
            "north"
            "south"
            "east"
            "west"
         end

         local d: Direction

         d = "west"
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("rejects an invalid string", function()
      local tokens = tl.lex([[
         local Direction = enum
            "north"
            "south"
            "east"
            "west"
         end

         local d: Direction

         d = "up"
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("string \"up\" is not a member of Direction", errors[1].err)
   end)
end)
