local tl = require("tl")

describe("assignment to array", function()
   it("accept expression", function()
      local tokens = tl.lex([[
         local self = {
            fmt = "hello"
         }
         local str = "hello"
         local a = {str:sub(2, 10)}
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
