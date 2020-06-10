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

   it("in variadic return type", util.check_syntax_error([[
      local f: function(x: number)...
   ]], {
      { y = 1, "unexpected '...'" },
   }))

   it("missing return type", util.check_syntax_error([[
      function error(err: string):
         -- msg is a typo
         if msg is string then
            return
         else
            return
         end
      end
   ]], {
      { y = 1, "expected a type list" },
   }))

   it("cannot use keyword as an identifier in an argument list", util.check_syntax_error([[
      local function foo(do: number | string) end
   ]], {
      { y = 1, "syntax error, expected identifier" },
   }))
end)

