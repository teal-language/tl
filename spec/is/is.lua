local util = require("spec.util")

describe("Is<T>:", function()

   it("is_ function", util.check [[
      local record Is<T> end

      local record MyRecord
         a: number
      end

      local record OtherRecord
         a: boolean
      end

      local r : MyRecord | OtherRecord = { a = 1 }

      local n : number

      local function is_myrecord(x: any): Is<MyRecord>
         if x is table then
            local a = x.a
            return (a is number)
         else return false end
      end
      if is_myrecord(r) then
         n = r.a
      end
   ]])

   it("is_ method", util.check [[
      local record Is<T> end

      local record A
         is_b : function(self : A | B) : Is<B>
      end

      local record B
         is_b : function(self : A | B) : Is<B>
         b_field : string
      end

      local b1 : B = {
         is_b = function(self : A | B) : Is<B>
            return (self as {string:any}).b_field ~= nil
         end,
         b_field = "yes",
      }

      local ab : A | B = b1

      if ab:is_b() then
         local b2 : B = ab
         local s : string = b2.b_field
      end
   ]])

end)
