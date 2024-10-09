local util = require("spec.util")

describe("^", function()
   it("pass", util.check([[
      local x = 1
      local y = 2
      local z: number = 3
      z = x ^ y ^ 0.5
   ]]))

   it("fail", util.check_type_error([[
      local x = 1
      local y = 2
      local z = 3
      z = x ^ y ^ 0.5
   ]], {
      { y = 4, msg = "got number, expected integer" },
   }))

end)
