local util = require("spec.util")

describe("invalid pragma", function()
   it("ignores other --# lines", util.check([[
      --#invalid on
   ]]))

   it("rejects invalid pragma", util.check_type_error([[
      --#pragma invalid_foo on
   ]], {
      { y = 1, msg = "invalid pragma: invalid_foo" }
   }))

   it("pragmas currently do not accept punctuation", util.check_syntax_error([[
      --#pragma something(other)
   ]], {
      { y = 1, x = 26, msg = "invalid token '('" },
      { y = 1, x = 32, msg = "invalid token ')'" },
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
