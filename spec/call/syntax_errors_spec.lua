local util = require("spec.util")

describe("call", function()
   it("catches a syntax error", util.check_syntax_error([[
      print("hello", "world",)
   ]], {
      { msg = "unexpected ')'" },
      { msg = "syntax error, expected ')'" },
   }))

   it("cannot call a string", util.check_syntax_error([[
      x = "hello" (world)
   ]], {
      { msg = "cannot call this expression" },
   }))

   it("cannot call a table", util.check_syntax_error([[
      x = {}(world)
   ]], {
      { msg = "cannot call this expression" },
   }))

   it("fails when lhs is not a prefixexp", util.check_syntax_error([[
      print(nil("hello"))
   ]], {
      { y = 1, x = 16, msg = "cannot call this expression" },
   }))
end)
