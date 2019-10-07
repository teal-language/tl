local tl = require("tl")

describe("assignment to const", function()
   it("fails", function()
      local tokens = tl.lex([[
         local x = 2
         local <const> y = 3
         x, y = 10, 20
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("cannot assign to <const> variable", errors[1].err, 1, true)
   end)
end)
