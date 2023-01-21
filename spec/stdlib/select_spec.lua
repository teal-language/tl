local util = require("spec.util")

describe("select", function()
   it("accepts a number", util.check([[
      local greeting = select(2, "hi", "hello", 123)
   ]]))

   it("accepts hash", util.check([[
      local count = select("#", "hi", "hello")
      print(count / 2)
   ]]))

   it("rejects an invalid first argument", util.check_type_error([[
      select({}, "hi", "hello")
   ]], {
      -- FIXME not ideal message, but it fails on failure cases
      { msg = "got {}, expected number" },
   }))
end)
