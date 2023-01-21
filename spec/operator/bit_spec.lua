local util = require("spec.util")

describe("bitwise operators", function()
   it("pass", util.check([[
      local x = 1
      local y = 2
      local z = 3
      z = x & y -- and
      z = x | y -- or
      z = x ~ y -- xor
      z = ~ y -- not
      z = x << 2 -- lshift
      z = x >> 2 -- rshift
   ]]))
end)
