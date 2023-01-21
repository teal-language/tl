local util = require("spec.util")

describe("assignment to nominal arrayrecord", function()
   it("accepts empty table", util.check([[
      local type Node = record
         {Node}
         foo: boolean
      end
      local x: Node = {}
   ]]))

   it("accepts complete fields without array entries", util.check([[
      local type Node = record
         {Node}
         foo: boolean
      end
      local x: Node = {
         foo = true,
      }
   ]]))

   it("accepts complete fields with array entries", util.check([[
      local type Node = record
         {Node}
         foo: boolean
      end
      local x: Node = {
         foo = true,
      }
      local y: Node = {
         foo = true,
         [1] = x,
      }
   ]]))

   it("accepts incomplete fields without array entries", util.check([[
      local type Node = record
         {Node}
         foo: boolean
         bar: number
      end
      local x: Node = {
         foo = true,
      }
   ]]))

   it("accepts complete fields with array entries", util.check([[
      local type Node = record
         {Node}
         foo: boolean
         bar: number
      end
      local x: Node = {
         foo = true,
      }
      local y: Node = {
         foo = true,
         [1] = x,
      }
   ]]))

   it("fails if table has extra fields", util.check_type_error([[
      local type Node = record
         {Node}
         foo: boolean
         bar: number
      end
      local x: Node = {
         foo = true,
         bla = 12,
      }
   ]], {
      { msg = "in local declaration: x: unknown field bla" }
   }))

   it("fails if mismatch", util.check_type_error([[
      local type Node = record
         {Node}
         foo: boolean
      end
      local x: Node = 123
   ]], {
      { msg = "in local declaration: x: got integer, expected Node" }
   }))
end)
