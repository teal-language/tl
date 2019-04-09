local tl = require("tl")

describe("==", function()
   it("passes with the same type", function()
      local tokens = tl.lex([[
         local x = "hello"
         if x == "hello" then
            print("hello!")
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
   it("fails with different types", function()
      local tokens = tl.lex([[
         local x = "hello"
         if not x == "hello" then
            print("unreachable")
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("not comparable for equality", errors[1].err)
   end)
end)
