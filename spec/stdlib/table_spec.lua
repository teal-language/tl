local util = require("spec.util")

describe("table", function()

   describe("unpack", function()
      it("can unpack multiple values", util.check([[
         local s = { 1234, "5678", 4566 }
         local a, b, c: any, any, any = table.unpack(s)
         local a = a as number
         local b = b as string
         local c = c as number
      ]]))

      -- standard library definition has special cases
      -- for tuples of sizes up to 5
      it("can unpack some tuples", util.check([[
         local s = { 1234, "5678", 4566, "foo", 123 }
         local a, b, c, d, e = table.unpack(s)
         a = a + 1 -- number
         b = b .. "!" -- string
         c = c + 2 -- number
         d = d .. "!" -- string
         e = e + 3 -- number
      ]]))
   end)

   describe("concat", function()
      it("can concat a mixed list of strings and numbers", util.check([[
         local t = { "a", 1, "b", 2 }
         print(table.concat(t))
      ]]))
   end)

end)
