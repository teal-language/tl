local util = require("spec.util")
local teal = require("teal")

describe("teal.warning_set", function()
   it("reports the set of warnings", function()
      local set = teal.warning_set()
      local n = 0
      for k, v in pairs(set) do
         n = n + 1
         assert.is_string(k)
         assert.same(true, v)
      end
      assert(n > 0)
   end)
end)
