local tl = require("tl")

describe("not", function()
   it("ok with any type", function()
      local tokens = tl.lex([[
         local x = 1
         local y = 2
         local z = true
         if not x then
            z = false
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
   it("ok with not not", function()
      local tokens = tl.lex([[
         local x = true
         local z: boolean = not not x
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
   it("not not casts to boolean", function()
      local tokens = tl.lex([[
         local i = 12
         local z: boolean = not not 12
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
