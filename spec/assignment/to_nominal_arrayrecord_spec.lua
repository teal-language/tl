local tl = require("tl")

describe("assignment to nominal arrayrecord", function()
   it("accepts empty table", function()
      local tokens = tl.lex([[
         local Node = record
            {Node}
            foo: boolean
         end
         local x: Node = {}
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("accepts complete fields without array entries", function()
      local tokens = tl.lex([[
         local Node = record
            {Node}
            foo: boolean
         end
         local x: Node = {
            foo = true,
         }
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("accepts complete fields with array entries", function()
      local tokens = tl.lex([[
         local Node = record
            {Node}
            foo: boolean
         end
         local x: Node = {
            foo = true,
         }
         local y: Node = {
            foo = true,
            [1] = x,
         }
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("accepts incomplete fields without array entries", function()
      local tokens = tl.lex([[
         local Node = record
            {Node}
            foo: boolean
            bar: number
         end
         local x: Node = {
            foo = true,
         }
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("accepts complete fields with array entries", function()
      local tokens = tl.lex([[
         local Node = record
            {Node}
            foo: boolean
            bar: number
         end
         local x: Node = {
            foo = true,
         }
         local y: Node = {
            foo = true,
            [1] = x,
         }
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("fails if table has extra fields", function()
      local tokens = tl.lex([[
         local Node = record
            {Node}
            foo: boolean
            bar: number
         end
         local x: Node = {
            foo = true,
            bla = 12,
         }
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.is_not.same({}, errors)
      assert.match("mismatch: ", errors[1].err, 1, true)
   end)

   it("fails if mismatch", function()
      local tokens = tl.lex([[
         local Node = record
            {Node}
            foo: boolean
         end
         local x: Node = 123
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("mismatch: ", errors[1].err, 1, true)
   end)
end)
