local util = require("spec.util")

describe("call", function()
   it("catches a syntax error", util.check_syntax_error([[
      print("hello", "world",)
   ]], {
      { msg = "unexpected ')'" },
   }))

   it("cannot call a string", util.check_syntax_error([[
      x = "hello" (world)
   ]], {
      { msg = "cannot call this expression" },
   }))

   it("cannot call an invalid expression using a string", util.check_syntax_error([[
      x = 12 "hello"
   ]], {
      { msg = "cannot use a string here" },
   }))

   it("cannot call an invalid expression using a table", util.check_syntax_error([[
      x = {} {}
   ]], {
      { msg = "cannot use a table here" },
   }))

   it("fails when lhs is not a prefixexp", util.check_syntax_error([[
      print(nil("hello"))
   ]], {
      { y = 1, x = 16, msg = "cannot call this expression" },
   }))
end)
