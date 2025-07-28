local util = require("spec.util")
local teal = require("teal")

describe("teal.runtime_target", function()
   it("reports the set of warnings", function()
      local target = teal.runtime_target()
      assert.matches("5.%d", target)
   end)
end)
