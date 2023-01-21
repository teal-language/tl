local util = require("spec.util")

describe("enum argument", function()
   it("accepts a valid string", util.check([[
      local type Direction = enum
         "north"
         "south"
         "east"
         "west"
      end

      local function go(d: Direction)
         print("I am going " .. d .. "!") -- d works as a string!
      end

      go("west")
   ]]))

   it("rejects an invalid string", util.check_type_error([[
      local type Direction = enum
         "north"
         "south"
         "east"
         "west"
      end

      local function go(d: Direction)
         print("I am going " .. d .. "!") -- d works as a string!
      end

      go("rest")
   ]], {
      { msg = "string \"rest\" is not a member of Direction" }
   }))
end)
