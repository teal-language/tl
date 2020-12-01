local util = require("spec.util")

describe("assignment to tuple", function()
   it("should not care about an array's inferred length when assigned indirectly", util.check [[
      local t: {number, number}
      local arr = {1, 2, 3, 4}
      t = arr
   ]])
   it("should error when an array literal is too long", util.check_type_error([[
      local t: {number, number}
      t = {1, 2, 3}
   ]], {
      { msg = "incompatible length, expected maximum length of 2, got 3", y = 2 },
   }))
end)
