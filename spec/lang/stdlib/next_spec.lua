local util = require("spec.util")

describe("next", function()
   it("can be used as an explicit iterator in for-in (#525)", util.check([[
      -- this is a case of a poly function in for-in:
      local t: {integer:integer} = {1,2,3}

      for k, v in next,t,nil do
        print(k,v)
      end
   ]]))
end)
