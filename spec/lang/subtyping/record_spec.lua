local util = require("spec.util")

describe("records", function()
   it("report error on fields (regression test for #456)", util.check_type_error([[
      local record Rec
         m: string
      end

      local function t1(): Rec
         return { m = 42 }
      end

      local function t2(): Rec
         local x = { m = 42 }
         return x
      end

      local function f(_: Rec) end
      f({ m = 42 })

      local t: Rec = { m = 42 }
   ]], {
      { y = 6, "record field doesn't match: m: got integer, expected string" },
      { y = 11, "record field doesn't match: m: got integer, expected string" },
      { y = 15, "record field doesn't match: m: got integer, expected string" },
      { y = 17, "record field doesn't match: m: got integer, expected string" },
   }))
end)

