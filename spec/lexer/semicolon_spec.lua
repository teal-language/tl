local util = require("spec.util")

describe("semicolon", function()

   it("is ignored", util.check ";local x = 0; local z = 12;;;")
end)
