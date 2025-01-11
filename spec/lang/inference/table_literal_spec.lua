local util = require("spec.util")

describe("bidirectional inference for table literals", function()
   it("declaration directs inference of table (regression test for #375)", util.check_type_error([[
      local record Container
         enum TypeEnum
            "number"
         end
         type: TypeEnum
      end

      local x: {Container} = {
         { type = 'number' },
         { type = 'who'    },
      }
      print(x)
   ]], {
      { msg = "in record field: type: string \"who\" is not a member of TypeEnum" },
   }))

   it("directed inference produces correct results for incomplete records (regression test for #348)", util.check([[
      local record test_t
         a: number
         b: number
      end

      local _: {test_t} = {
         {
            a=1,
         },
         {
            a=1,
            b=2
         }
      }
   ]]))

   it("directed inference produces correct results for methods (regression test for #407)", util.check_type_error([[
      local record Foo
         enum Eno
            "a"
            "c"
         end
         bar: function(Foo, {Eno})
      end

      local f: Foo

      f:bar({ "a", "b" })
   ]], {
      { msg = 'expected an array: at index 2: string "b" is not a member of Eno' }
   }))

   it("resolves nominals across nested generics (regression test for #499)", util.check_type_error([[
      local record Tree<X>
        {Tree<X>}
        item: X
      end

      local t: Tree<number> = {
        item = 1,
        { item = 2 },
        { item = "wtf", { item = 4 } },
      }
   ]], {
      { msg = 'in record field: item: got string "wtf", expected number' }
   }))

   it("resolves self type from records (regression test for #846)", util.check_type_error([[
      local record Struct<T>
         a: T
         b: T
         c: self
      end

      local a: Struct<integer> = {
         a = 1,
         b = 2,
         c = 3,
      }

      print(a.a, a.b, a.c)
   ]], {
      { msg = 'in record field: c: got integer, expected Struct' }
   }))

   it("resolves self type in function fields (regression test for #846)", util.check_type_error([[
      local record Struct<T>
         a: T
         b: T
         c: function<T>(self)
      end

      local a: Struct<integer> = {
         a = 1,
         b = 2,
         c = function(a: integer) end,
      }

      print(a.a, a.b, a.c)
   ]], {
      { msg = 'in record field: c: argument 1: got integer, expected Struct' }
   }))

   it("resolves self type from interfaces (regression test for #846)", util.check_type_error([[
      local interface Struct<T>
         a: T
         b: T
         c: self
      end

      local a: Struct<integer> = {
         a = 1,
         b = 2,
         c = 3,
      }

      print(a.a, a.b, a.c)
   ]], {
      { msg = 'in record field: c: got integer, expected Struct' }
   }))
end)
