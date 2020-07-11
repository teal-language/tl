local util = require("spec.util")

describe("assignment to const", function()
   it("fails", util.check_type_error([[
      local x = 2
      local y <const> = 3
      x, y = 10, 20
   ]], {
      { msg = "cannot assign to <const> variable" }
   }))

   it("catches a syntax error", util.check_syntax_error([[
      local x = 2
      local <const> y = 3
      x, y = 10, 20
   ]], {
      { msg = "expected a local variable definition" }
   }))
end)
