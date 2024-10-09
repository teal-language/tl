local util = require("spec.util")

describe("+", function()
   it("pass", util.check([[
      local x = 1
      local y = 2
      local z = 3
      z = x + y
   ]]))

   it("has correct precedence compared to concatenation", util.check([[
      local h = "hi"
      local w = "world"

      print("this has " .. #h + #w .. " characters: ", h, w)
   ]]))
end)
