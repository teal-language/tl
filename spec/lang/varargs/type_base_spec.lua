local util = require("spec.util")

describe("type base", function()
   it("reports vararg functions with proper `...` within errors (regression test for #340)", util.check_type_error([[
      local function f(x: number, ...: string): string...
         return ...
      end

      f = 2
   ]], {
      { msg = "in assignment: got integer, expected function(number, ...: string): string..." }
   }))
end)
