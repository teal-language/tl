local tl = require("tl")

describe("string method call", function()
   it("pass", function()
      -- pass
      local tokens = tl.lex([[
         print(("  "):rep(12))
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
   it("fail", function()
      local tokens = tl.lex([[
         print(("  "):rep("foo"))
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("error in argument 1:", errors[1].err, 1, true)
   end)
end)
