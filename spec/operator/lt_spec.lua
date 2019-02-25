local tl = require("tl")

describe("<", function()
   it("ok", function()
      local tokens = tl.lex([[
         local x = 1
         local y = 2
         local z = true
         if x < y then
            z = false
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
   it("fail", function()
      local tokens = tl.lex([[
         local x = 1
         local y = "hello"
         local z = true
         if x < y then
            z = false
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same("binop mismatch for <: number string", errors[1].err)
   end)
end)
