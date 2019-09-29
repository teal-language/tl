local tl = require("tl")

describe("record method call", function()
   it("method call on an expression", function()
      local tokens = tl.lex([[
         local r = {
            x = 2,
            b = true,
         }
         function r:f(a: number, b: string): boolean
            if self.b then
               return #b == 3
            else
               return a > self.x
            end
         end
         (r):f(3, "abc")
      ]])
      local errs = {}
      local _, ast = tl.parse_program(tokens, errs)
      assert.same({}, errs)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
