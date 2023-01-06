local util = require("spec.util")
local tl = require("tl")

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

      it("basic inference sets types, pass", util.check [[
         local x = 1
         local y = 2
         local z: number
         z = x + y
      ]])
   end)

   describe("multiple declaration", function()
      it("basic inference catches errors", util.check_type_error([[
         local x, y = 1, 2
         local z: table
         z = x + y
      ]], {
         { msg = "in assignment: got integer" },
      }))

      it("basic inference sets types", util.check [[
         local x, y = 1, 2
         local z: number
         z = x + y
      ]])

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
            local x, y: number, string = 1, "a"
            local z: table
            z = x + string.byte(y)
         ]], {
            { msg = "in assignment: got number" },
         }))

         it("uses correct type", util.check [[
            local x, y: number, string = 1, "a"
            local z: number
            z = x + string.byte(y)
         ]])
      end)

      it("reports unset and untyped values as errors in tl mode", util.check_type_error([[
         local type T = record
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
         local type T = record
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

      it("local type can declare a nominal type alias (regression test for #238)", function ()
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
         local result, err = tl.process("main.tl")

         assert.same({}, result.syntax_errors)
         assert.same({
            { y = 3, x = 35, filename = "main.tl", msg = "in local declaration: var: unknown field dato" },
            { y = 4, x = 26, filename = "main.tl", msg = "invalid key 'dato' in record 'var' of type Boo" },
         }, result.type_errors)
      end)

      it("catches unknown types", util.check_type_error([[
         local type MyType = UnknownType
      ]], {
         { msg = "UnknownType is not a type" }
      }))

      it("nominal types can take type arguments", util.check [[
         local record Foo<R>
            item: R
         end

         local type Foo2 = Foo
         local type Bla = Foo<number>

         local x: Bla = { item = 123 }
         local y: Foo2<number> = { item = 123 }
      ]])

      it("types declared as nominal types are aliases", util.check [[
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
      ]])

      it("nested types can be resolved as aliases", util.check [[
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
      ]])

      it("'type', 'record' and 'enum' are not reserved keywords", util.check [[
         local type = type
         local record: string = "hello"
         local enum: number = 123
         print(record)
         print(enum + 123)
      ]])

      it("local type can require a module", function ()
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
         local result, err = tl.process("main.tl")

         assert.same({}, result.syntax_errors)
         assert.same({}, result.type_errors)
      end)

      it("local type can require a module and type is usable", function ()
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
         local result, err = tl.process("main.tl")

         assert.same({}, result.syntax_errors)
         assert.same({
            { y = 2, x = 37, filename = "main.tl", msg = "in local declaration: obj: unknown field invalid" },
         }, result.type_errors)
      end)

      it("local type can require a module and its globals are visible", function ()
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
         local result, err = tl.process("main.tl")

         assert.same({}, result.syntax_errors)
         assert.same({
            { y = 3, x = 37, filename = "main.tl", msg = "in local declaration: obj2: unknown field invalid" },
         }, result.type_errors)
      end)
   end)

   describe("annotation", function()
      it("fails with unknown annotations", util.check_syntax_error([[
         local x <blergh> = 1
      ]], {
         { msg = "unknown variable annotation: blergh" },
      }))

      it("accepts <const> annotation", util.check [[
         local x <const> = 1
      ]])

      describe("<close>", function()
         local function check54(code) return util.check(code, "5.4") end
         local function check_type54(code, errs) return util.check_type_error(code, errs, "5.4") end
         it("accepted for 5.4 target", check54 [[
            local x <close> = io.open("foobar", "r")
         ]])

         for _, t in ipairs{"5.1", "5.3"} do
            it("rejected for non 5.4 target (" .. t .. ")", util.check_type_error([[
               local x <close> = io.open("foobar", "r")
            ]], {
               { msg = "only valid for Lua 5.4" }
            }, t))
         end

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

         it("allows nil to be closed", check54 [[
            local x <close>: nil
         ]])
      end)
   end)
end)
