local util = require("spec.util")

describe("call", function()
   it("catches a syntax error", util.check_syntax_error([[
      print("hello", "world",)
   ]], {
      { msg = "syntax error" },
      { msg = "syntax error" },
   }))
end)
