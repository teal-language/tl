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
      assert.same("cannot use operator < for types number and string", errors[1].err)
   end)
   it("fails with not gotcha", function()
      local tokens = tl.lex([[
         local x = 10
         local y = 20
         if not x < y then
            print("wat")
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same("cannot use operator < for types boolean and number", errors[1].err)
   end)
end)
