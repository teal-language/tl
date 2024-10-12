local util = require("spec.util")

describe(":", function()
   describe("on self", function()
      it("can resolve methods (regression test for #812)", util.check([[
         local interface A
            get_type: function(A): string
         end

         local interface B is A where self:get_type() == "b"
         end

         local b: A = {
            get_type = function(): string return "b" end
         }

         if b is B then
            print("woaw")
         end
      ]]))
   end)
end)
