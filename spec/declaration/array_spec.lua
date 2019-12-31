local tl = require("tl")

describe("array declarations", function()
   it("can be simple", function()
      local tokens = tl.lex([[
         local x = {1, 2, 3}
         x[2] = 10
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("can be sparse", function()
      local tokens = tl.lex([[
         local x = {
            [2] = 2,
            [10] = 3,
         }
         print(x[10])
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("can be indirect", function()
      local tokens = tl.lex([[
         local RED = 1
         local BLUE = 2
         local x = {
            [RED] = 2,
            [BLUE] = 3,
         }
         print(x[RED])
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("indirect only works for numeric keys", function()
      local tokens = tl.lex([[
         local RED = 1
         local BLUE = 2
         local GREEN: string = (function():string return "hello" end)()
         local x = {
            [RED] = 2,
            [BLUE] = 3,
            [GREEN] = 4,
         }
         print(x[RED])
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same("cannot determine type of table literal", errors[1].msg, 1, true)
   end)

   it("indirect works array-records", function()
      local tokens = tl.lex([[
         local RED = 1
         local BLUE = 2
         local x = {
            [RED] = 2,
            [BLUE] = 3,
            GREEN = 4,
         }
         print(x[RED])
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
