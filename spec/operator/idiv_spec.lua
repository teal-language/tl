local util = require("spec.util")

describe("//", function()
   it("pass", util.check([[
      local x = 1
      local y = 2
      local z = 3
      z = x // y
   ]]))
end)
