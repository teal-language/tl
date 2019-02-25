local tl = require("tl")

describe("+", function()
   it("pass", function()
      local tokens = tl.lex([[
         local x = 1
         local y = 2
         local z = 3
         z = x + y
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
