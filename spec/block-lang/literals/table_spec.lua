local util = require("spec.block-util")

describe("table literals", function()
   it("do not leak types (regression test for #965)", util.check_type_error([[
      local function F(a: string | number, b: any)
         print({a, b})
         local x: string = a
         print(x)
      end
   ]], {
      { y = 3, msg = "x: got string | number, expected string" }
   }))
end)
