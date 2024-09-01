local util = require("spec.util")

describe("typealias", function()
   it("nested type aliases match", util.check([[
      local record R
         enum E
         end

         type E2 = E
      end

      function R.f(_use_type: R.E)
      end

      function R.g(use_alias: R.E2)
         R.f(use_alias)
      end
   ]]))

   it("resolves early, works with unions", util.check([[
      local record R
         record P
            x: integer
         end

         type Z = P
      end

      function R.f(a: boolean | R.Z)
         if a is R.Z then
            print("hello")
         end
      end
   ]]))
end)
