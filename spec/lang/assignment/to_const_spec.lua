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

   it("close variable fails", util.check_type_error([[
      local record R
         metamethod __close: function()
      end
      local c <close>: R = setmetatable({}, {
         __close = function() end
      })
      c = nil
   ]], {
      { y = 7, x = 7, msg = "cannot assign to <close> variable" },
   }, "5.4"))

   it("close variable 'is_closable' check should not crash with built-in function", util.check_type_error([[
      local function f() end
      local a <close> = f
      local b <close> = setmetatable
   ]], {
      { y = 2, x = 13, msg = "to-be-closed variable a has a non-closable type function()" },
      { y = 3, x = 13, msg = "to-be-closed variable b has a non-closable type function<T>(T, metatable<T>): T" },
   }, "5.4"))
end)

describe("attributes syntax", function()
   it("with annotation error", util.check_syntax_error([[
      local c <costn> = 3
      local a <> = 1
      print(c, a)
   ]], {
      { y = 1, x = 21, msg = "unknown variable annotation: costn" },
      { y = 2, x = 16, msg = "syntax error, expected identifier" },
      { y = 2, x = 18, msg = "expected a variable annotation" },
      { y = 3, x = 7, msg = "syntax error" },
   }))

   it("error", util.check_syntax_error([[
      local b < = 2
      print(b)
   ]], {
      { y = 1, x = 17, msg = "syntax error, expected identifier"},
      { y = 1, x = 19, msg = "expected a variable annotation" },
   }))
end)
