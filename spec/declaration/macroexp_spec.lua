local util = require("spec.util")

describe("macroexp declaration", function()
   it("checks unused arguments", util.check_warnings([[
      local record R1
         metamethod __is: function(self: R1): boolean = macroexp(self: R1): boolean
            true
         end
      end
   ]], {
      { y = 2, msg = "unused argument self: R1" }
   }))

   it("checks argument mismatch", util.check_type_error([[
      local record R1
         metamethod __call: function(self: R1, n: number): boolean = macroexp(self: R1, s: string): boolean
            self.field == s
         end
         field: string
      end
   ]], {
      { y = 2, x = 70, msg = "macroexp type does not match declaration" }
   }))

   it("checks multiple use of arguments", util.check_type_error([[
      global function f(a: string, b:string)
         print(a, b)
      end

      local record R1
         metamethod __call: function(self: R1, s: string): boolean = macroexp(self: R1, s: string): boolean
            print(s, s)
         end
      end
   ]], {
      { y = 7, x = 22, msg = "cannot use argument 's' multiple times in macroexp" }
   }))
end)
