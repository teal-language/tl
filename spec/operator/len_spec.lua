local util = require("spec.util")

describe("#", function()
   it("returns an integer when used on array", util.check[[
      local x: integer = #({1, 2, 3})
   ]])
   it("returns an integer when used on tuple", util.check[[
      local x: integer = #({1, "hi"})
   ]])
end)
