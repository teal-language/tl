local util = require("spec.util")

describe("rawget", function()
   it("reads ", util.check([[
      local self = {
         fmt = "hello"
      }
      local str = "hello"
      local a = {str:sub(2, 10)}
   ]]))
end)
