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

   it("does not report unused global variables", util.check_warnings([[
      global foo = "bar"
   ]], { }))

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
      { y = 1, x = 22, msg = "unused function foo: function()" }
   }))

   it("does not report used labels", util.check_warnings([[
      global function f()
         ::foo::
         if math.random(1, 2) then
            goto foo
         end
      end
   ]], {}))

   it("reports unused labels as 'label' and not 'variable'", util.check_warnings([[
      global function f()
         ::foo::
      end
   ]], {
      { y = 2, msg = "unused label ::foo::" },
   }))

   it("reports unused function arguments as 'argument' and not 'variable'", util.check_warnings([[
      local function foo(x: number)
      end
      foo()
   ]], {
      { y = 1, msg = "unused argument x: number" }
   }))

   it("should not report that a narrowed variable is unused", util.check_warnings([[
      local function foo(bar: string | number): string
         if bar is string then
            if string.sub(bar, 1, 1) == "#" then
               bar = string.sub(bar, 2, -1)
            end
            bar = tonumber(bar, 16)
         end
      end
      foo()
   ]], { }))

   it("should report unused types", util.check_warnings([[
      local type Foo = number
   ]], {
      { y = 1, msg = "unused type Foo: type number" }
   }))
end)
