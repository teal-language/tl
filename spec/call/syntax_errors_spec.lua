local util = require("spec.util")

describe("call", function()
   it("catches a syntax error", util.check_syntax_error([[
      print("hello", "world",)
   ]], {
      { msg = "syntax error" },
      { msg = "syntax error" },
   }))

   it("fails when lhs is not a prefixexp", util.check_syntax_error([[
      print(nil("hello"))
   ]], {
      { x = 16, msg = "cannot call this expression" },
      { msg = "syntax error" },
   }))
end)
