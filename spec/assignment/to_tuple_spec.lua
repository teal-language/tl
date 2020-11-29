local util = require("spec.util")

describe("assignment to tuple", function()
   it("should not care about an array's length when assigned indirectly", util.check [[
      local t: {number, number}
      local arr = {1, 2, 3, 4}
      t = arr
   ]])
end)
