local util = require("spec.util")

describe("typed varargs", function()
   it("declaration", util.check([[
      local function f(a: number, ...: string): boolean
         return true
      end
   ]]))

   it("call with multiple arities", util.check([[
      local function f(a: number, ...: string): boolean
         return true
      end

      local ok = f(5)
      local ok = f(5, "aa")
      local ok = f(5, "aa", "bbb")
      local ok = f(5, "aa", "bbb", "ccc")
   ]]))

   it("can expand to multiple variables", util.check([[
      local function f(...: string): string
         local s, t = ...
         return s .. t
      end
      local s = f("aa", "bbb")
   ]]))

   it("can compress to a single variable", util.check([[
      local function f(...: string): number
         local s, n: string, number = ..., 12
         return #s + n
      end
      local s = f("aa", "bbb")
   ]]))
end)
