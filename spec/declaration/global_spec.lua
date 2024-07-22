local tl = require("tl")
local util = require("spec.util")

describe("global", function()
   describe("is not a keyword and", function()
      it("works as a table key", util.check([[
         local t = {
            global = 12
         }
         print(t.global)
      ]]))

      it("works in calls", util.check([[
         local global = 12
         print(global)
      ]]))

      it("works as a variable", util.check([[
         local global = 12
         global = 13
      ]]))
   end)

   describe("undeclared", function()
      it("fails for single assignment", util.check_type_error([[
         x = 1
      ]], {
         { msg = "unknown variable: x" },
      }))

      it("fails for multiple assignment", util.check_type_error([[
         x, y = 1, 2
      ]], {
         { msg = "unknown variable: x" },
         { msg = "unknown variable: y" },
      }))
   end)

   describe("declared at top level", function()
      it("works for single assignment", util.check([[
         global x: number = 1
         x = 2
      ]]))

      it("works for multiple assignment", util.check([[
         global x, y: number, string = 1, "hello"
         x = 2
         y = "world"
      ]]))
   end)

   describe("declared at a deeper level", function()
      it("works for single assignment", util.check([[
         local function foo()
            global x: number = 1
            x = 2
         end
      ]]))

      it("works for multiple assignment", util.check([[
         local function foo()
            global x, y: number, string = 1, "hello"
            x = 2
            y = "world"
         end
      ]]))
   end)

   describe("redeclared", function()
      it("works if types are the same", util.check([[
         global x: number = 1
         global x: number
         x = 2
      ]]))

      it("works for const if not reassigning", util.check([[
         global x <const>: number = 1
         global x <const>: number
      ]]))

      it("fails for const if reassigning", util.check_type_error([[
         global x <const>: number = 1
         global x <const>: number = 9
      ]], {
         { msg = "cannot reassign to <const> global" },
      }))

      it("fails for const if reassigning (regression test for #653)", util.check_type_error([[
         global assert = 1
      ]], {
         { msg = "cannot reassign to <const> global: assert" },
      }))

      it("fails if adding const", util.check_type_error([[
         global x: number
         global x <const>: number
      ]], {
         { msg = "global was previously declared as not <const>" },
      }))

      it("fails if removing const", util.check_type_error([[
         global string: number
      ]], {
         { msg = "cannot redeclare global with a different type" },
      }))

      it("fails if removing const", util.check_type_error([[
         global x <const>: number
         global x: number
      ]], {
         { msg = "global was previously declared as <const>" },
      }))

      it("fails if types don't match", util.check_type_error([[
         global x, y: number, string = 1, "hello"
         global x: string
         x = 2
         y = "world"
      ]], {
         { msg = "cannot redeclare global with a different type" },
      }))

      it("fails if types don't match", util.check_type_error([[
         local record AR
            {number}
         end

         global u: AR | number
         global u: {number} | number
      ]], {
         { msg = "cannot redeclare global with a different type" },
      }))
   end)

   describe("redeclared across files", function()
      it("works if types are the same", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x: number = 1"
         })
         util.run_check([[
            local foo = require("foo")
            global x: number
            x = 2
         ]])
      end)

      it("works for const if not reassigning", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x <const>: number = 1"
         })
         util.run_check([[
            local foo = require("foo")
            global x <const>: number
         ]])
      end)

      it("fails for const if reassigning", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x <const>: number = 1"
         })
         util.run_check_type_error([[
            local foo = require("foo")
            global x <const>: number = 9
         ]], {
            { msg = "cannot reassign to <const> global" },
         })
      end)

      it("fails if adding const", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x: number"
         })
         util.run_check_type_error([[
            local foo = require("foo")
            global x <const>: number
         ]], {
            { msg = "global was previously declared as not <const>" },
         })
      end)

      it("fails if removing const", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x <const>: number"
         })
         util.run_check_type_error([[
            local foo = require("foo")
            global x: number
         ]], {
            { msg = "global was previously declared as <const>" },
         })
      end)

      it("fails if types don't match", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x, y: number, string = 1, 'hello'"
         })
         util.run_check_type_error([[
            local foo = require("foo")
            global x: string
            x = 2
            y = "world"
         ]], {
            { msg = "cannot redeclare global with a different type" },
         })
      end)
   end)

   describe("with types", function()
      it("can be forward-declared to resolve circular type dependencies", function()
         util.mock_io(finally, {
            ["person.tl"] = [[
               local person = {}

               global type Building

               global record Person
                  residence: Building
               end

               return person
            ]],
            ["building.tl"] = [[
               local building = {}

               global type Person

               global record Building
                  owner: Person
               end

               return building
            ]],
         })
         util.run_check([[
            local person = require("person")
            local building = require("building")
            local b: Building = {}
            local p: Person = { residence = b }
            b.owner = p
         ]])
      end)

      it("nominal types can take type arguments", util.check([[
         global record Foo<R>
            item: R
         end

         global type Foo2 = Foo
         global type Bla = Foo<number>

         global x: Bla = { item = 123 }
         global y: Foo2<number> = { item = 123 }
      ]]))

      it("nested types can be resolved as aliases if there are no undefined type variables", util.check([[
         global record Foo<R>
            enum LocalEnum
               "loc"
            end

            record Nested
               x: {LocalEnum}
               y: number
            end

            item: R
         end

         global type Nested = Foo.Nested
      ]]))

      it("nested types cannot be resolved as aliases if there are undefined type variables", util.check_type_error([[
         global record Foo<R>
            enum LocalEnum
               "loc"
            end

            record Nested
               x: {LocalEnum}
               y: R
            end

            item: R
         end

         global type Nested = Foo.Nested
      ]], {
         { msg = "undefined type variable R" }, -- FIXME this shows y = 8, but should be y = 14
      }))

      it("types declared as nominal types are aliases", util.check([[
         global record Foo<R>
            item: R
         end

         global type Foo2 = Foo
         global type FooNumber = Foo<number>

         global x: FooNumber = { item = 123 }
         global y: Foo2<number> = { item = 123 }

         global type Foo3 = Foo
         global type Foo4 = Foo2

         global zep: Foo2<string> = { item = "hello" }
         global zip: Foo3<string> = zep
         global zup: Foo4<string> = zip
      ]]))

      it("global type can require a module", function ()
         util.mock_io(finally, {
            ["class.tl"] = [[
               local record Class
                 data: number
               end
               return Class
            ]],
            ["main.tl"] = [[
               global type Class = require("class")
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
               global type Class = require("class")
               local obj: Class = { invalid = 2 }
            ]],
         })
         local result, err = tl.process("main.tl")

         assert.same({}, result.syntax_errors)
         assert.same({
            { y = 2, x = 37, filename = "main.tl", msg = "in local declaration: obj: unknown field invalid" },
         }, result.type_errors)
      end)
   end)

   describe("shadowing", function()
      it("cannot define a global variable when a local variable with the same name is in scope", util.check_type_error([[
         global function test()
            local boo: string = "1"
            global boo: number = 1
         end

         local function test2()
            local boo2: string = "1"
            global boo2: number = 1
         end
      ]], {
         { y = 3, msg = "cannot define a global when a local with the same name is in scope" },
         { y = 8, msg = "cannot define a global when a local with the same name is in scope" },
      }))

      it("cannot define a global variable when a local function with the same name is in scope", util.check_type_error([[
         local function test()
         end

         local function f()
            global test: number = 1
         end

         global test: number = 1
      ]], {
         { y = 5, msg = "cannot define a global when a local with the same name is in scope" },
         { y = 8, msg = "cannot define a global when a local with the same name is in scope" },
      }))
   end)
end)
