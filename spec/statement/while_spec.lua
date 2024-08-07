local util = require("spec.util")

describe("while", function()
   it("accepts a boolean", util.check([[
      local b = true
      while b do
         print(b)
      end
   ]]))

   it("accepts a non-boolean", util.check([[
      local n = 123
      while n do
         print(n)
      end
   ]]))

   it("while expression propagates a boolean context", util.check([[
      local n = 123
      local s = "hello"
      while n or s do
         local ns: number | string = n or s
         print(ns)
      end
   ]]))
end)
