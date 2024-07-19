local util = require("spec.util")

describe("repeat", function()
   it("accepts a boolean", util.check([[
      local b = true
      repeat
         print(b)
      until b
   ]]))

   it("accepts a non-boolean", util.check([[
      local n = 123
      repeat
         print(n)
      until n
   ]]))

   it("until expression propagates a boolean context", util.check([[
      local n = 123
      local s = "hello"
      repeat
         local ns: number | string = n or s
         print(ns)
      until n or s
   ]]))

   it("only closes scope after until", util.check([[
      repeat
         local type R = record
            a: string
         end
         local r = { a = "hello" }
      until r.a == "hello"
   ]]))
   it("closes scope on exit", util.check_type_error([[
      repeat
         local type R = record
            a: string
         end
         local r = { a = "hello" }
      until r.a == "hello"

      print(r.a)
   ]], {
      { y = 8, msg = "unknown variable: r" },
   }))
end)
