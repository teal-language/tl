local tl = require("tl")

describe("assignment to self record field", function()
   it("passes", function()
      local tokens = tl.lex([[
         local Node = record
            foo: boolean
         end
         function Node:method()
            self.foo = true
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("fails if mismatch", function()
      local tokens = tl.lex([[
         local Node = record
            foo: string
         end
         function Node:method()
            self.foo = 12
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("mismatch: ", errors[1].err, 1, true)
   end)
end)
