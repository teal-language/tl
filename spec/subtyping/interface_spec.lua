local util = require("spec.util")

describe("subtyping of interfaces:", function()
   it("record inherits interface array definition", util.check([[
      local interface MyInterface
         is {MyInterface}
         x: integer
      end

      local record MyRecord
         is MyInterface
      end

      local r: MyRecord = {}
      print(#r)
   ]]))
end)

