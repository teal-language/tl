local tl = require("tl")

describe("assignment to multiple variables", function()
   it("from a function call", function()
      local tokens = tl.lex([[
         local function foo(): boolean, string
            return true, "yeah!"
         end
         local a, b = foo()
         print(b .. " right!")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
