local util = require("spec.util")

describe("warnings", function()
   it("reports redefined variables", util.check_warnings([[
      local a = 1
      local a = 2
      print(a)
   ]], {
      { y = 2, msg = "redeclaration of variable 'a' (originally declared at 1:13)" },
   }))

   it("reports redefined variables in for loops", util.check_warnings([[
      for i = 1, 10 do
         local i = 15
         print(i)
      end

      for k, v in pairs{'a', 'b', 'c'} do
         local k = 2
         local v = 'd'
         print(k, v)
      end
   ]], {
      { y = 2, msg = "redeclaration of variable 'i' (originally declared at 1:11)" },
      { y = 7, msg = "redeclaration of variable 'k' (originally declared at 6:11)" },
      { y = 8, msg = "redeclaration of variable 'v' (originally declared at 6:14)" },
   }))

   it("reports unused variables", util.check_warnings([[
      local foo = "bar"
   ]], {
      { y = 1, msg = [[unused variable foo: string "bar"]] }
   }))

   it("doesn't report unused variables that start with '_'", util.check_warnings([[
      local _foo = "bar"
   ]], { }))

   pending("reports both unused and redefined variables of the same name", util.check_warnings([[
      local a = 10
      do
         local a = 12
         print(a)
      end
   ]], {
      { y = 3, msg = "redeclaration of variable 'a' (originally declared at 1:13)" },
      { y = 1, msg = "unused variable 'a'" },
   }))

   it("reports unused functions as 'function' and not 'variable'", util.check_warnings([[
      local function foo()
      end
   ]], {
      { y = 1, msg = "unused function foo: function()" }
   }))

   it("reports unused function arguments as 'argument' and not 'variable'", util.check_warnings([[
      local function foo(x: number)
      end
      foo()
   ]], {
      { y = 1, msg = "unused argument x: number" }
   }))
end)
