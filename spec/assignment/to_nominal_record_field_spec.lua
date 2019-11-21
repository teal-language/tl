local tl = require("tl")

describe("assignment to nominal record field", function()
   it("passes", function()
      local tokens = tl.lex([[
         local Node = record
            foo: boolean
         end
         local Type = record
            node: Node
         end
         local t: Type = {}
         t.node = {}
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("fails if mismatch", function()
      local tokens = tl.lex([[
         local Node = record
            foo: boolean
         end
         local Type = record
            node: Node
         end
         local t: Type = {}
         t.node = 123
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("in assignment: got number, expected Node", errors[1].err, 1, true)
   end)
end)
