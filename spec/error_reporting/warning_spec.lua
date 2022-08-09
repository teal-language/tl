local util = require("spec.util")

describe("warnings", function()
   describe("on variables", function()
      it("reports redefined variables", util.check_warnings([[
         local a = 1
         print(a)
         local a = 2
         print(a)
      ]], {
         { y = 3, msg = "redeclaration of variable 'a' (originally declared at 1:16)" },
      }))

      it("reports redefined variables in for loops", util.check_warnings([[
         for i = 1, 10 do
            print(i)
            local i = 15
            print(i)
         end

         for k, v in ipairs{'a', 'b', 'c'} do
            print(k, v)
            local k = 2
            local v = 'd'
            print(k, v)
         end
      ]], {
         { y = 3, msg = "redeclaration of variable 'i' (originally declared at 1:14)" },
         { y = 9, msg = "redeclaration of variable 'k' (originally declared at 7:14)" },
         { y = 10, msg = "redeclaration of variable 'v' (originally declared at 7:17)" },
      }))

      it("reports use of pairs on arrays", util.check_warnings([[
         for k, v in pairs{'a', 'b', 'c'} do
            print(k, v)
         end
      ]], {
         { y = 1, msg = "applying pairs on an array: did you intend to apply ipairs?" },
      }))

      it("does not report localized globals", util.check_warnings([[
         global x = 9

         do
            local x = x
            print(x)
         end

         local os = os
         print(os)
      ]], { }))

      it("reports unused variables", util.check_warnings([[
         local foo = "bar"
      ]], {
         { y = 1, msg = [[unused variable foo: string]] }
      }))

      it("does not report redeclaration of variables prefixed with '_'", util.check_warnings([[
         local _ = 1
         print(_) -- ensure usage
         local _ = 2
         print(_)
      ]], { }))

      it("does not report unused global variables", util.check_warnings([[
         global foo = "bar"
      ]], { }))

      it("doesn't report unused variables that start with '_'", util.check_warnings([[
         local _foo = "bar"
      ]], { }))

      it("reports both unused and redefined variables of the same name", util.check_warnings([[
         local a = 10
         do
            local a = 12
            print(a)
         end
      ]], {
         { y = 3, msg = "redeclaration of variable 'a' (originally declared at 1:16)" },
         { y = 1, msg = "unused variable a: integer" },
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

      it("reports when implicitly declared variables redeclare a local (for loop)", util.check_warnings([[
         local i = 1
         for i = 1, 10 do
            print(i)
         end
      ]], {
         { y = 2, msg = "redeclaration of variable 'i' (originally declared at 1:16)" },
         { y = 1, msg = "unused variable i: integer" },
      }))

      it("reports when implicitly declared variables redeclare a local (function arg)", util.check_warnings([[
         local i = 1
         local function _foo(i: integer)
            print(i)
         end
      ]], {
         { y = 2, msg = "redeclaration of variable 'i' (originally declared at 1:16)" },
         { y = 1, msg = "unused variable i: integer" },
      }))
   end)

   describe("on goto labels", function()
      it("do not report used labels when used after declaration", util.check_warnings([[
         global function f()
            ::foo::
            if math.random(1, 2) then
               goto foo
            end
         end
         f()
      ]], {}))

      it("do not report used labels when used before declaration", util.check_warnings([[
         local function f()
            if math.random(1, 2) then
               goto foo
            end
            ::foo::
         end
         f()
      ]], {}))

      it("report unused labels as 'label' and not 'variable'", util.check_warnings([[
         global function f()
            ::foo::
         end
      ]], {
         { y = 2, msg = "unused label ::foo::" },
      }))
   end)

   describe("on functions", function()
      it("report unused functions as 'function' and not 'variable'", util.check_warnings([[
         local function foo()
         end
      ]], {
         { y = 1, msg = "unused function foo: function()" }
      }))


      it("report unused function arguments as 'argument' and not 'variable'", util.check_warnings([[
         local function foo(x: number)
         end
         foo()
      ]], {
         { y = 1, msg = "unused argument x: number" }
      }))
   end)

   describe("on types", function()
      it("should report unused types as 'type' and not 'variable'", util.check_warnings([[
         local type Foo = number
      ]], {
         { y = 1, msg = "unused type Foo: type number" }
      }))
   end)

   describe("on return", function()
      it("should report when discarding returns via expressions with 'and'", util.check_warnings([[
         local function may_fail(chance: number): boolean, string
            if math.random() >= chance then
               return true
            else
               return fail, "unlucky this time!"
            end
         end

         local function try_twice(c1: number, c2: number): boolean, string
            return may_fail(c1)
               and may_fail(c2)
         end

         local ok, err = try_twice(0.9, 0.5)
         if not ok then
            print(err)
         end
      ]], {
         { y = 11, msg = "additional return values are being discarded due to 'and' expression; suggest parentheses if intentional" }
      }))

      it("should report when discarding returns via expressions with 'or'", util.check_warnings([[
         local function may_fail(chance: number): boolean, string
            if math.random() >= chance then
               return true
            else
               return fail, "unlucky this time!"
            end
         end

         local function try_twice(c1: number, c2: number): boolean, string
            return may_fail(c1)
                or may_fail(c2)
         end

         local ok, err = try_twice(0.5, 0.9)
         if not ok then
            print(err)
         end
      ]], {
         { y = 11, msg = "additional return values are being discarded due to 'or' expression; suggest parentheses if intentional" }
      }))
   end)
end)
