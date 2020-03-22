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

   it("missing separators", util.check_syntax_error([[
      local function x(a b c)

      end

      local function y(a: string b: string c: string)
         print(a b c)
      end
   ]], {
      { y = 1, "syntax error" },
      { y = 1, "expected an expression" },
      { y = 1, "syntax error" },
      { y = 5, "expected an expression" },
      { y = 5, "syntax error" },
      { y = 5, "expected an expression" },
      { y = 5, "syntax error" },
      { y = 5, "expected an expression" },
   }))

end)

