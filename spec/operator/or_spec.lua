local tl = require("tl")

describe("or", function()
   it("map or record matching map", function()
      local tokens = tl.lex([[
         local Ty = record
            name: string
            foo: number
         end
         local t: Ty = { name = "bla" }
         local m1: {string:Ty} = {}
         local m2: {string:Ty} = m1 or { foo = t }
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
