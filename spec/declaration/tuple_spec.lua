local util = require("spec.util")

describe("tuple declarations", function()
   it("can be simple", util.check [[
      local x = { 1, "hi" }
   ]])

   it("can be declared as a nominal type", util.check [[
      local type Coords = [number, number]
      local c: Coords = { 1, 2 }
   ]])
end)
