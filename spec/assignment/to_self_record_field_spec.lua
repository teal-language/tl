local util = require("spec.util")

describe("assignment to self record field", function()
   it("passes", util.check([[
      local type Node = record
         foo: boolean
      end
      function Node:method()
         self.foo = true
      end
   ]]))

   it("fails if mismatch", util.check_type_error([[
      local type Node = record
         foo: string
      end
      function Node:method()
         self.foo = 12
      end
   ]], {
      { msg = "in assignment: got integer, expected string" }
   }))
end)
