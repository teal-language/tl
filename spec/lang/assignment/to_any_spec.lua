local util = require("spec.util")

describe("assignment with any", function()
   it("is ok from any type", util.check([[
      local a: any

      local i = 0
      a = i

      local s = "string"
      a = s

      local m = { ["foo"] = 2, ["bar"] = 3 }
      a = m

      local arr = {1,2,3}
      a = arr

      local E = {}
      a = E

      local f = function():string return "wee" end
      a = f

      local a2: any
      a = a2
      a2 = a
   ]]))
end)
