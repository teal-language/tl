local util = require("spec.util")

describe("typealias function declaration", function()
   it("declares a function type", util.check [[
      local t = typealias function(number, number): string

      local func = function(a: number, b: number): string
         return tostring(a + b)
      end
   ]])

   it("function type can return a union including itself (#135)", util.check [[
      local F = typealias function(): F | number

      local i = 5
      local func: F
      func = function(): F | number
         i = i - 1
         if i == 0 then
            return 12345
         end
         return func
      end
      while true do
         local a = func()
         if a is number then
            assert(a == 12345)
            print("bye!")
            break
         else
            func = a
         end
      end
   ]])

end)

describe("typealias union declaration", function()
   it("declares a union type", util.check [[
      local NS = typealias (number | string)

      local func = function(a: NS, b: NS): string
         local s = ""
         return (a is number and tostring(a + 1) or a .. "!")
             .. (b is number and tostring(b + 1) or b .. "!")
      end
   ]])

   -- typealiases cannot be mutually recursive yet because unions resolve eagerly
   pending("function type can return a union including itself (#135)", util.check [[
      local U = typealias (F | number)
      local F = typealias function(): U

      local i = 5
      local func: F
      func = function(): U
         i = i - 1
         if i == 0 then
            return 12345
         end
         return func
      end
      while true do
         local a = func()
         if a is number then
            assert(a == 12345)
            print("bye!")
            break
         else
            func = a
         end
      end
   ]])

end)
