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

   it("resolves early even if type arguments are not used (regression test for #881)", util.check([[
      local record Foo<T> end
      local record Bar<T> end

      local type StringFoo = Foo<string>
      local type StringBar = Bar<string>

      local type Test = {StringFoo: StringBar}
      local test: Test = {}
   ]]))

   it("nested generic type aliases work with early resolution (regression test for #888)", util.check([[
      local record Generic<T>
         x: T
      end

      local record Export
         type Test = Generic<string>
      end
   ]]))
end)
