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

   it("cannot have nested empty argument list (#958)", util.check_syntax_error([[
      local interface Foo
      end

      local record Bar<T is Foo<>>
      end

      local type printBar = function<T is Foo<>>(T): nil
   ]], {
      { y = 4, x = 33, msg = "type argument list cannot be empty" },
      { y = 7, x = 47, msg = "type argument list cannot be empty" },
   }))

   it("nested generics cannot reference outer name (#958)", util.check_type_error([[
      local interface Foo
      end

      local interface FooV2<T>
      end

      local record Buzz<T is FooV2<T>>
      end

      local type printBuzz = function<T is FooV2<T>>(T): nil
   ]], {
      { y = 7, x = 36, msg = "unknown type T" },
      { y = 10, x = 50, msg = "unknown type T" },
   }))
end)
