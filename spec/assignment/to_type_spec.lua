local util = require("spec.util")

describe("assignment to type", function()
   it("is not allowed", util.check_type_error([[
      local type R = record
         x: number
      end

      local r: R = {}

      R = r
   ]], {
      { msg = "cannot reassign a type" },
   }))
end)
