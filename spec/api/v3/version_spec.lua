local util = require("spec.util")
local teal = require("teal")

describe("teal.version", function()
   it("reports a version string", function()
      local v = teal.version()
      assert.is_string(v)
   end)
end)
