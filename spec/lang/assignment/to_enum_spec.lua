local util = require("spec.util")

describe("assignment to enum", function()
   it("accepts a valid string", util.check([[
      local type Direction = enum
         "north"
         "south"
         "east"
         "west"
      end

      local d: Direction

      d = "west"
   ]]))

   it("rejects an invalid string", util.check_type_error([[
      local type Direction = enum
         "north"
         "south"
         "east"
         "west"
      end

      local d: Direction

      d = "up"
   ]], {
      { msg = "string \"up\" is not a member of Direction" }
   }))
end)
