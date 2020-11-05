local util = require("spec.util")

describe("math", function()

   describe("atan", function()
      it("accepts one or two arguments (regression test for #256)", util.check [[
         local x: number = math.atan(1)
         local z: number = math.atan(1, 2)
      ]])
   end)

end)
