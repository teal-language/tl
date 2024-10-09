local util = require("spec.util")

describe("vararg scope", function()
   it("works", util.check([[
      local function f(a: number, ...: string): boolean
         local function g(a: number, ...: number): number
            local n = select(1, ...)
            return n / 2
         end
         return true
      end
   ]]))

   it("catches use in incorrect scope", util.check_type_error([[
      local function foo(...: any): function(): any
         return function(): any
            return select(1, ...) -- ... isn't allowed here
         end
      end
   ]], {
      { msg = "cannot use '...' outside a vararg function" }
   }))
end)
