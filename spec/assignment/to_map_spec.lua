local util = require("spec.util")

describe("assignment to maps", function()
   it("resolves a record to a map", util.check [[
      local m: {string:number} = {
         hello = 123,
         world = 234,
      }
   ]])

   it("resolves strings to enum", util.check [[
      local type Direction = enum
         "north"
         "south"
         "east"
         "west"
      end
      local m: {string:Direction} = {
         hello = "north",
         world = "south",
      }
   ]])
end)
