local util = require("spec.util")

describe("invalid pragma", function()
   it("rejects invalid pragma", util.check_syntax_error([[
      --#invalid_pragma on
   ]], {
      { y = 1, msg = "invalid token '--#invalid_pragma'" }
   }))

   it("pragmas currently do not accept punctuation", util.check_syntax_error([[
      --#pragma something(other)
   ]], {
      { y = 1, msg = "invalid token '('" },
      { y = 1, msg = "invalid token ')'" },
   }))

   it("pragma arguments need to be in a single line", util.check_syntax_error([[
      --#pragma arity
        on

      local function f(x: integer, y: integer)
         print(x + y)
      end

      print(f(10))
   ]], {
      { msg = "expected pragma value" }
   }))
end)
