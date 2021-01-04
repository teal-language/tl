local util = require("spec.util")

describe("function results", function()
   it("should be adjusted down to 1 result in an expression list", util.check [[
      local function f(): string, number
      end
      local a, b = f(), "hi"
      a = "hey"
   ]])
end)
