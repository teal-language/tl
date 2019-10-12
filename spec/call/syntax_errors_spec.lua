local tl = require("tl")

describe("call", function()
   it("catches a syntax error", function()
      local tokens = tl.lex([[
         print("hello", "world",)
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
