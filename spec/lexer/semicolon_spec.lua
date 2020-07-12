local util = require("spec.util")

math.randomseed(os.time())

describe("semicolon", function()

   it("is ignored", util.check ";local x = 0; local z = 12;;;")
end)
