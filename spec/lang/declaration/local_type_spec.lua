local util = require("spec.util")
local tl = require("teal.api.v2")

describe("local type", function()
   it("can declare a type alias for table", util.check([[
      local type PackTable = table.PackTable
      local args: table.PackTable<integer> = table.pack(1, 2, 3)
   ]]))

   it("can declare a nominal type alias (regression test for #238)", function ()
      util.mock_io(finally, {
         ["module.tl"] = [[
            local record module
              record Type
                data: number
              end
            end
            return module
         ]],
         ["main.tl"] = [[
            local module = require "module"
            local type Boo = module.Type
            local var: Boo = { dato = 0 }
            print(var.dato)
         ]],
      })
      local result, err = tl.check_file("main.tl")

      assert.same({}, result.syntax_errors)
      assert.same({
         { y = 3, x = 32, filename = "main.tl", msg = "in local declaration: var: unknown field dato" },
         { y = 4, x = 23, filename = "main.tl", msg = "invalid key 'dato' in record 'var' of type Boo" },
      }, result.type_errors)
   end)

   it("can resolve a nominal with generics (regression test for #777)", function ()
      util.mock_io(finally, {
         ["module.tl"] = [[
            local record module
              record Foo<K>
                something: K
              end
            end
            return module
         ]],
         ["main.tl"] = [[
            local module = require "module"

            local record Boo
               field: MyFoo<string>
            end

            local type MyFoo<Z> = module.Foo<Z>

            local b: Boo = { field = { something = "hi" } }
            local c: Boo = { field = { something = 123 } }
         ]],
      })
      local result, err = tl.check_file("main.tl")

      assert.same({}, result.syntax_errors)
      assert.same({
         { y = 10, x = 52, filename = "main.tl", msg = "in record field: something: got integer, expected string" },
      }, result.type_errors)
   end)

   it("catches unknown types", util.check_type_error([[
      local type MyType = UnknownType
   ]], {
      { msg = "unknown type UnknownType" }
   }))

   it("nominal types can take type arguments", util.check([[
      local record Foo<R>
         item: R
      end

      local type Foo2 = Foo
      local type Bla = Foo<number>

      local x: Bla = { item = 123 }
      local y: Foo2<number> = { item = 123 }
   ]]))

   it("declared as nominal types are aliases", util.check([[
      local record Foo<R>
         item: R
      end

      local type Foo2 = Foo
      local type FooNumber = Foo<number>

      local x: FooNumber = { item = 123 }
      local y: Foo2<number> = { item = 123 }

      local type Foo3 = Foo
      local type Foo4 = Foo2

      local zep: Foo2<string> = { item = "hello" }
      local zip: Foo3<string> = zep
      local zup: Foo4<string> = zip
   ]]))

   it("nested types can be resolved as aliases", util.check([[
      local record Foo<R>
         enum LocalEnum
            "loc"
         end

         record Nested
            x: {LocalEnum}
            y: R
         end

         item: R
      end

      local type Nested = Foo.Nested
   ]]))

   it("can require a module", function ()
      util.mock_io(finally, {
         ["class.tl"] = [[
            local record Class
              data: number
            end
            return Class
         ]],
         ["main.tl"] = [[
            local type Class = require("class")
            local obj: Class = { data = 2 }
         ]],
      })
      local result, err = tl.check_file("main.tl")

      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
   end)

   it("can require a module and type is usable", function ()
      util.mock_io(finally, {
         ["class.tl"] = [[
            local record Class
              data: number
            end
            return Class
         ]],
         ["main.tl"] = [[
            local type Class = require("class")
            local obj: Class = { invalid = 2 }
         ]],
      })
      local result, err = tl.check_file("main.tl")

      assert.same({}, result.syntax_errors)
      assert.same({
         { y = 2, x = 34, filename = "main.tl", msg = "in local declaration: obj: unknown field invalid" },
      }, result.type_errors)
   end)

   it("can require a module and its globals are visible", function ()
      util.mock_io(finally, {
         ["class.tl"] = [[
            global record Glob
              hello: number
            end

            local record Class
              data: number
            end
            return Class
         ]],
         ["main.tl"] = [[
            local type Class = require("class")
            local obj: Glob = { hello = 2 }
            local obj2: Glob = { invalid = 2 }
         ]],
      })
      local result, err = tl.check_file("main.tl")

      assert.same({}, result.syntax_errors)
      assert.same({
         { y = 3, x = 34, filename = "main.tl", msg = "in local declaration: obj2: unknown field invalid" },
      }, result.type_errors)
   end)

   it("does not accept type arguments declared twice", util.check_syntax_error([[
      local type Foo<T> = record<T>
      end
   ]], {
      { y = 1, msg = "cannot declare type arguments twice in type declaration" },
   }))

   it("propagates type arguments correctly", util.check_type_error([[
      local record module
        record Foo<A, B>
          first: A
          second: B
        end
      end

      -- note inverted arguments
      local type MyFoo<X, Y> = module.Foo<Y, X>

      local record Boo
         field: MyFoo<string, integer>
      end

      local b: Boo = { field = { first = "first", second = 2 } } -- bad, not inverted!
      local c: Boo = { field = { first = 1, second = "second" } } -- good, inverted!
   ]], {
      { y = 15, x = 42, msg = 'in record field: first: got string "first", expected integer' },
      { y = 15, x = 60, msg = 'in record field: second: got integer, expected string' },
   }))

   it("resolves type arguments in nested types correctly (#754)", util.check_type_error([[
      local record MyNamespace
          record MyGenericRecord<T>
              Data: T
          end
      end

      local enum MyEnum
          "foo"
          "bar"
      end

      local type MyAlias = MyNamespace.MyGenericRecord<MyEnum>

      local t: MyAlias = { Data = "invalid" }
   ]], {
      { y = 14, msg = 'in record field: Data: string "invalid" is not a member of MyEnum' }
   }))
end)
