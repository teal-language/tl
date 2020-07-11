local util = require("spec.util")

describe("assignment to multiple variables", function()
   it("from a function call", util.check [[
      local function foo(): boolean, string
         return true, "yeah!"
      end
      local a, b = foo()
      print(b .. " right!")
   ]])

   it("reports unsufficient rvalues as an error, simple", util.check_type_error([[
      local a, b = 1, 2
      a, b = 3
   ]], {
      { msg = "variable is not being assigned a value" }
   }))

   it("reports unsufficient rvalues as an error, tricky", util.check_type_error([[
      local T = record
         x: number
         y: number
      end

      function T:returnsTwo(): number, number
         return self.x, self.y
      end

      function T:method()
         local a, b: number, number
         a, b = self.returnsTwo and self:returnsTwo()
      end
   ]], {
      { msg = "variable is not being assigned a value" }
   }))
end)
