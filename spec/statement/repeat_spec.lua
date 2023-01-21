local util = require("spec.util")

describe("repeat", function()
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
