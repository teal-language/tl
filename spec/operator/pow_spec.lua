local tl = require("tl")

describe("^", function()
   it("pass", function()
      local tokens = tl.lex([[
         local x = 1
         local y = 2
         local z = 3
         z = x ^ y ^ 0.5
      ]])
      local syntax_errors = {}
      local _, ast = tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
