local util = require("spec.util")

describe("functiontype declaration", function()
   it("declares a functiontype", util.check [[
      local type t = function(number, number): string

      local func = function(a: number, b: number): string
         return tostring(a + b)
      end
   ]])

   it("functiontype can return a union including itself (#135)", util.check [[
      local type F = function(): F | number

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
