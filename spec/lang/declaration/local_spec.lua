local util = require("spec.util")
local tl = require("teal.api.v2")

describe("local", function()
   describe("declaration", function()
      it("basic inference sets types, fail", util.check_type_error([[
         local x = 1
         local y = 2
         local z: table
         z = x + y
      ]], {
         { msg = "in assignment: got integer" },
      }))

      it("basic inference sets types, pass", util.check([[
         local x = 1
         local y = 2
         local z: number
         z = x + y
      ]]))

      it("'type', 'record' and 'enum' are not reserved keywords", util.check([[
         local type = type
         local record: string = "hello"
         local enum: number = 123
         print(record)
         print(enum + 123)
      ]]))

      it("reports unset and untyped values as errors in tl mode", util.check_type_error([[
         local record T
            x: number
            y: number
         end

         function T:returnsTwo(): number, number
            return self.x, self.y
         end

         function T:method()
            local a, b = self.returnsTwo and self:returnsTwo()
         end
      ]], {
         { msg = "assignment in declaration did not produce an initial value for variable 'b'" },
      }))

      it("reports unset values as unknown in Lua mode", util.lax_check([[
         local record T
            x: number
            y: number
         end

         function T:returnsTwo(): number, number
            return self.x, self.y
         end

         function T:method()
            local a, b = self.returnsTwo and self:returnsTwo()
         end
      ]], {
         { msg = "b" },
      }))
   end)

   describe("multiple declaration", function()
      it("basic inference catches errors", util.check_type_error([[
         local x, y = 1, 2
         local z: table
         z = x + y
      ]], {
         { msg = "in assignment: got integer" },
      }))

      it("basic inference sets types", util.check([[
         local x, y = 1, 2
         local z: number
         z = x + y
      ]]))

      describe("with types", function()
         it("checks values", util.check_type_error([[
            local x, y: string, number = 1, "a"
            local z
            z = x + string.byte(y)
         ]], {
            { msg = "x: got integer, expected string" },
            { msg = "y: got string \"a\", expected number" },
            { msg = "variable 'z' has no type" },
            { msg = "cannot use operator '+'" },
            { msg = "argument 1: got number, expected string" },
         }))

         it("propagates correct type", util.check_type_error([[
            local x, y: integer, string = 1, "a"
            local z: table

            z = x + string.byte(y)
         ]], {
            { msg = "in assignment: got integer" },
         }))

         it("uses correct type", util.check([[
            local x, y: number, string = 1, "a"
            local z: number
            z = x + string.byte(y)
         ]]))
      end)
   end)

   describe("annotation", function()
      it("fails with unknown annotations", util.check_syntax_error([[
         local x <blergh> = 1
      ]], {
         { msg = "unknown variable annotation: blergh" },
      }))

      it("accepts <const> annotation", util.check([[
         local x <const> = 1
      ]]))

      describe("<total>", function()
         it("fails without an init value", util.check_type_error([[
            local x <total>: {boolean:string}
         ]], {
            { msg = "variable declared <total> does not declare an initialization value" },
         }))

         it("only accepts maps and records", util.check_type_error([[
            local x <total>: integer
         ]], {
            { msg = "attribute <total> only applies to maps and records" },
         }))

         it("fails when missing boolean keys from the domain", util.check_type_error([[
            local x <total>: {boolean:string} = {
               [true] = "hello"
            }
            local y <total>: {boolean:string} = {
               [false] = "hello"
            }
         ]], {
            { y = 1, msg = "map variable declared <total> does not declare values for all possible keys (missing: false)" },
            { y = 4, msg = "map variable declared <total> does not declare values for all possible keys (missing: true)" },
         }))

         it("fails when missing enum keys from the domain", util.check_type_error([[
            local enum Color
               "red"
               "green"
               "blue"
            end
            local x <total>: {Color:string} = {
               ["red"] = "hello"
            }
         ]], {
            { msg = "map variable declared <total> does not declare values for all possible keys (missing: blue, green)" },
         }))

         it("accepts nil declarations in keys", util.check([[
            local enum Color
               "red"
               "green"
               "blue"
            end
            local x <total>: {Color:string} = {
               ["red"] = "hello",
               ["green"] = nil,
               ["blue"] = nil,
            }
         ]]))

         it("does not accept direct declaration from total to total", util.check_type_error([[
            local record Point
               x: number
            end

            local p <total>: Point = {
               x = 2,
            }

            local p2 <total>: Point = p
         ]], {
            { y = 9, msg = "attribute <total> only applies to literal tables" },
         }))

         it("rejects direct declaration from non-total to total", util.check_type_error([[
            local record Point
               x: number
               y: number
            end

            local p: Point = {
               x = 2,
            }

            local p2 <total>: Point = p
         ]], {
            { y = 10, msg = "attribute <total> only applies to literal tables" },
         }))

         it("cannot reassign a total", util.check_type_error([[
            local record Point
               x: number
            end

            local p1 <total>: Point = {
               x = 1,
            }

            local p2 <total>: Point = {
               x = 2,
            }

            p2 = p1
         ]], {
            { msg = "cannot assign to <total> variable" },
         }))

         it("fails when map domain can't be total", util.check_type_error([[
            local enum Color
               "red"
               "green"
               "blue"
            end
            local x <total>: {string:string} = {
               ["red"] = "hello"
            }
         ]], {
            { msg = "map variable declared <total> does not declare values for all possible keys" },
         }))

         it("fails when missing fields from a record", util.check_type_error([[
            local record Point
               x: number
               y: number
               z: number
            end
            local p <total>: Point = {
               x = 1.0,
               y = 2.0,
            }
         ]], {
            { msg = "record variable declared <total> does not declare values for all fields (missing: z)" },
         }))

         it("does not consider a subtype to be a missing field", util.check([[
            local record Fruit
               name: string
            end

            local record Person
               record Identity
                  name: string
                  born: integer
               end

               id: Identity
               likes: Fruit
            end

            local person <total>: Person = {
               id = {
                  name = 'Fulano',
                  born = 1995
               },
               likes = {name='orange'}
            }
         ]]))

         it("does not consider a record function to be a missing field", util.check([[
            local record A
               v: number
            end

            function A:echo()
               print('A:', self.v)
            end

            local b <total>: A = { v = 10 }
         ]]))

         it("does not consider a metamethod to be a missing field (regression test for #749", util.check([[
            local interface Op
               op: string
            end

            local interface Binary
               is Op
               left: number
               right: number
            end

            local record Add
               is Binary
               where self.op == '+' -- removing the comment triggers an error
            end

            local sum <total>: Add = {
               op = '+',
               left = 10,
               right = 20
            }

            print(sum.op, sum.left, sum.right)
         ]]))
      end)

      describe("<close>", function()
         local function check54(code) return util.check(code, "5.4") end
         local function check_type54(code, errs) return util.check_type_error(code, errs, "5.4") end
         it("accepted for 5.4 target", check54([[
            local x <close> = io.open("foobar", "r")
         ]]))

         it("rejects multiple in a single declaration", check_type54([[
            local x <close>, y <close> = io.open("foobar", "r"), io.open("baz", "r")
         ]], {
            { msg = "only one <close>" }
         }))

         it("rejects values that are valid for the type, but not closable", check_type54([[
            local record Foo
               metamethod __close: function(Foo, any)
            end
            local x <close>: Foo = {} -- valid type as records aren't inherently tied to their metatables
                                      -- invalid <close> as table literal has no metatable
            global make_foo: function(): Foo
            local y <close> = make_foo() -- valid type, unable to prove value can't be <close>, so allow it

            print(x, y)
         ]], {
            { y = 4, msg = "assigned a non-closable value" }
         }))

         it("allows nil to be closed", check54([[
            local x <close>: nil
         ]]))
      end)
   end)

   it("localizing a record does not make the new local a type (#759)", util.check([[
      local record k
      end

      local kk: k = {}

      local k = k

      k = {}

      kk = {}
   ]]))

   it("using a base type name in a regular variable produces no warnings", util.check_warnings([[
      local any = true
      print(any)

      local record integer
      end
   ]], {
      { tag = "redeclaration", msg = "variable shadows previous declaration of 'integer'" },
      { tag = "unused", msg = "unused type integer" },
   }))

   it("catches bad assignments of record tables (regression test for #752)", util.check_type_error([[
      local record Foo
         qux: integer
      end

      local record Bar
         gorp: number
      end

      local _bar1: Bar = 0.0
      local _bar2: Bar = Foo
   ]], {
      { y = 9, msg = "_bar1: got number, expected Bar" },
      { y = 10, msg = "_bar2: Foo is not a Bar" },
   }))

   it("catches excessive types in declaration (regression test for #868)", util.check_type_error([[
      local function f(): string, string
         return "hello", "world"
      end

      local x, y: integer, string, string = 1, ""

      local z, w = 0, f()

      z, w = 0, f()
   ]], {
      { y = 5, x = 36, msg = "number of types exceeds number of variables" },
   }))

   -- behaviors to be deprecated, once we can implement
   -- proper detection and warnings.
   describe("behavior to deprecate", function()
      it("plain `local` aliasing of enums works (regression test for #891)", util.check([[
         local enum MyEnum1
             "A"
             "B"
         end

         -- this should require `local type`...
         local MyEnum2 = MyEnum1

         local record MyRecord
             x: MyEnum2
         end

         local x: MyRecord = {x = "A"}
         assert(x)
      ]]))
      it("plain `local` aliasing of records works (regression test for #891)", util.check([[
         local record MyRecord1 end

         local MyRecord2 = MyRecord1

         local record MyRecord
             x: MyRecord2
         end

         local x: MyRecord = {x = {}}
         assert(x)
      ]]))

      it("plain `local` aliasing of records works across `require` (regression test for #891)", function()
         util.mock_io(finally, {
            ["foo.tl"] = [[
               local enum MyEnum
                   "A"
                   "B"
               end

               return { MyEnum = MyEnum }
            ]],
            ["bar.tl"] = [[
               local foo = require "foo"

               local MyEnum = foo.MyEnum

               local record MyRecord
                   x: MyEnum
               end

               local x: MyRecord = {x = "A"}
               assert(x)
            ]],
         })
         local result, err = tl.check_file("bar.tl")
         assert.same(nil, err)
         assert.same({}, result.syntax_errors)
         assert.same({}, result.type_errors)
      end)
   end)
end)
