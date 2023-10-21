local util = require("spec.util")

describe("__is with macroexp", function()
   it("can expand a constant expression", util.gen([[
      local record R1
         metamethod __is: function(self: R1|R2): boolean = macroexp(_self: R1|R2): boolean
            true
         end
      end

      local record R2
         metamethod __is: function(self: R1|R2): boolean = macroexp(_self: R1|R2): boolean
            false
         end
      end

      local type RS = R1 | R2

      local rs1 : RS

      if rs1 is R1 then
         print("yes")
      end

      local rs2 : R1 | R2

      if rs2 is R2 then
         print("yes")
      end
   ]], [[














      local rs1

      if true then
         print("yes")
      end

      local rs2

      if false then
         print("yes")
      end
   ]]))

   it("can expand self in an expression", util.gen([[
      local record R1
         metamethod __is: function(self: R1|R2): boolean = macroexp(self: R1|R2): boolean
            self.kind == "r1"
         end

         kind: string
      end

      local record R2
         metamethod __is: function(self: R1|R2): boolean = macroexp(self: R1|R2): boolean
            self.kind == "r2"
         end

         kind: string
      end

      local type RS = R1 | R2

      local rs1 : RS = { kind = "r1" }

      if rs1 is R1 then
         print("yes")
      end

      local rs2 : R1 | R2 = { kind = "r2" }

      if rs2 is R2 then
         print("yes")
      end
   ]], [[


















      local rs1 = { kind = "r1" }

      if rs1.kind == "r1" then
         print("yes")
      end

      local rs2 = { kind = "r2" }

      if rs2.kind == "r2" then
         print("yes")
      end
   ]]))
end)
