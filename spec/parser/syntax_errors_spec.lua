local util = require("spec.util")

describe("syntax errors", function()
   it("unpaired 'end'(#166)", util.check_syntax_error([[
      print("A")

      end

      print("what")
   ]], {
      { y = 3, msg = "expected one or more expressions" },
   }))

   it("in table declaration", util.check_syntax_error([[
      local x = {
         [123] = true,
         true = 123,
         foo = 9
      }
   ]], {
      { y = 3, x = 15, msg = "syntax error, expected one of: '}', ','" },
      { y = 3, x = 17, msg = "expected an expression" },
   }))

   it("missing separators in table", util.check_syntax_error([[
      local x = {
         cat = true
         pizza = true
         brain = true
      }
   ]], {
      { y = 3, msg = "syntax error, expected one of: '}', ','" },
      { y = 4, msg = "syntax error, expected one of: '}', ','" },
   }))

   it("missing separators", util.check_syntax_error([[
      local function x(a b c)

      end
   ]], {
      { y = 1, x = 26, msg = "syntax error, expected one of: ')', ','" },
      { y = 1, x = 28, msg = "syntax error, expected one of: ')', ','" },
   }))

   it("missing separators with types", util.check_syntax_error([[
      local function y(a: string b: string c: string)
         print(a b c)
      end
   ]], {
      { y = 1, x = 34, msg = "syntax error, expected one of: ')', ','" },
      { y = 1, x = 44, msg = "syntax error, expected one of: ')', ','" },
      { y = 2, x = 18, msg = "syntax error, expected one of: ')', ','" },
      { y = 2, x = 20, msg = "syntax error, expected one of: ')', ','" },
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
      { y = 1, msg = "expected a type list" },
   }))

   it("cannot use keyword as an identifier in an argument list", util.check_syntax_error([[
      local function foo(do: number | string) end
   ]], {
      { y = 1, msg = "syntax error, expected identifier" },
   }))
end)

