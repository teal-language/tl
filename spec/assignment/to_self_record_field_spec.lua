local util = require("spec.util")

describe("assignment to self record field", function()
   it("passes", util.check [[
      local Node = record
         foo: boolean
      end
      function Node:method()
         self.foo = true
      end
   ]])

   it("fails if mismatch", util.check_type_error([[
      local Node = record
         foo: string
      end
      function Node:method()
         self.foo = 12
      end
   ]], {
      { msg = "in assignment: got number, expected string" }
   }))
end)
