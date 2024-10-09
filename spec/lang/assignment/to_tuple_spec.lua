local util = require("spec.util")

describe("assignment to tuple", function()
   it("should not care about an array's inferred length when assigned indirectly", util.check([[
      local t: {number, number}
      local arr = {1, 2, 3, 4}
      t = arr
   ]]))
   it("should error when an array literal is too long", util.check_type_error([[
      local t: {number, number}
      t = {1, 2, 3}
   ]], {
      { y = 2, msg = "unexpected index 3 in tuple {number, number}" },
   }))
   it("should allow an array literal when its length fits the tuple type", util.check([[
      local t: {number, number, string}
      t = {1, 2}
   ]]))
end)
