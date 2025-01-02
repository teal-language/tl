local util = require("spec.util")

describe("declaration of generics", function()
   it("generics on array types can be explicitly declared (regression test for #880)", util.check([[
      local record TypeA<T> end

      local type TypeB<T> = {TypeA<T>}

      -- this works:
      local function TypeA_new<T>(): TypeA<T>
         local a: TypeA<T> = {}
         return a
      end

      -- this no longer fails with: "in return value: TypeB<T> is not a TypeB<T>"
      local function TypeB_new<T>(): TypeB<T>
         local a: TypeA<T> = {}
         local b: TypeB<T> = {a}
         return b
      end

      -- it works when leaving the type of b implicit:
      local function TypeB_new_<T>(): TypeB<T>
         local a: TypeA<T> = {}
         local b = {a}
         return b
      end
   ]]))
end)
