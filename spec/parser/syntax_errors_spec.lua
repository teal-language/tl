local util = require("spec.util")

describe("syntax errors", function()
   it("in table declaration", util.check_syntax_error([[
      local x = {
         [123] = true,
         true = 123,
         foo = 9
      }
   ]], {
      { y = 3, "syntax error" },
      { y = 3, "expected an expression" },
   }))
end)

