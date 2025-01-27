local util = require("spec.util")

describe("boolean context", function()
   it("do not infer a type variable to a boolean in a boolean context", util.check([[
      local x: {string: integer} = {}

      if next(x) then
      end
   ]]))
end)

