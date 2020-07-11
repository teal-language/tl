local util = require("spec.util")

describe("assignment to array of maps", function()
   it("resolves records to maps", util.check [[
      local a: {{string:number}} = {
         {
            hello = 123,
            world = 234,
         },
         {
            foo = 345,
            bar = 456,
         },
      }
   ]])
end)
