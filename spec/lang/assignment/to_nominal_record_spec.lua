local util = require("spec.util")

describe("assignment to nominal record", function()
   it("accepts empty table", util.check([[
      local type Node = record
         b: boolean
      end
      local x: Node = {}
   ]]))

   it("accepts complete table", util.check([[
      local type R = record
         foo: string
      end
      local type AR = record
         {Node}
         bar: string
      end
      local type Node = record
         b: boolean
         n: number
         m: {number: string}
         a: {boolean}
         r: R
         ar: AR
      end
      local x: Node = {
         b = true,
         n = 1,
         m = {},
         a = {},
         r = {},
         ar = {},
      }
   ]]))

   it("accepts incomplete table", util.check([[
      local type Node = record
         b: boolean
         n: number
      end
      local x: Node = {
         b = true,
      }
   ]]))

   it("fails if table has extra fields", util.check_type_error([[
      local type Node = record
         b: boolean
         n: number
      end
      local x: Node = {
         b = true,
         bla = 12,
      }
   ]], {
      { msg = "in local declaration: x: unknown field bla" }
   }))

   it("fails if mismatch", util.check_type_error([[
      local type Node = record
         b: boolean
      end
      local x: Node = 123
   ]], {
      { msg = "in local declaration: x: got integer, expected Node" }
   }))

   it("type system is nominal: fails if different records with compatible structure", util.check_type_error([[
      local type Node1 = record
         b: boolean
      end

      local type Node2 = record
         b: boolean
      end

      local n1: Node1 = { b = true }
      local n2: Node2 = { b = true }
      n1 = n2
   ]], {
      { msg = "in assignment: Node2 is not a Node1" },
   }))

   it("identical generic instances resolve to the same type", util.check([[
      local type R = record<T>
         x: T
      end

      local function foo(): R<string>
         return { x = "hello" }
      end

      local function bar(): R<string>
         return { x = "world" }
      end

      local v = foo()
      v = bar()
   ]]))
end)
