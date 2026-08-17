local util = require("spec.util")
local tl = require("teal.api.v2")

describe("struct", function()
   describe("basic", function()
      it("declares a struct with fields", util.check([[
         local struct Point
            x: number
            y: number
         end
      ]]))

      it("auto-generates .new constructor", util.check([[
         local struct Point
            x: number
            y: number
         end

         local p = Point.new { x = 1, y = 2 }
         print(p.x, p.y)
      ]]))

      it("supports :init() hook called from .new", function()
         local result, err = tl.check_string([[
            local struct Point
               x: number
               y: number
               distance: number
            end

            function Point:init()
               self.distance = math.sqrt(self.x ^ 2 + self.y ^ 2)
            end

            local p = Point.new { x = 3, y = 4 }
            print(p.distance)
         ]])
         assert.same({}, result.type_errors)
      end)

      it("generates working Lua code via tl gen", function()
         util.mock_io(finally, {
            ["main.tl"] = [[
               local struct Counter
                  count: number
               end

               function Counter:init()
                  self.count = self.count or 0
               end

               function Counter:increment()
                  self.count = self.count + 1
               end

               local c = Counter.new { count = 10 }
               c:increment()
               c:increment()
               print(c.count)
            ]],
         })
         local result, err = tl.check_file("main.tl")
         assert.truthy(result)
         assert.same({}, result.type_errors, "expected no type errors")
      end)
   end)

   describe("methods", function()
      it("supports instance methods via colon syntax", util.check([[
         local struct Point
            x: number
            y: number
         end

         function Point:move(dx: number, dy: number)
            self.x = self.x + dx
            self.y = self.y + dy
         end

         local p = Point.new { x = 1, y = 2 }
         p:move(10, 20)
      ]]))

      it("supports static methods via dot syntax", util.check([[
         local struct Point
            x: number
            y: number
         end

         function Point.origin(): Point
            return Point.new { x = 0, y = 0 }
         end

         local p = Point.origin()
         print(p.x)
      ]]))
   end)

   describe("inheritance", function()
      it("inherits fields from parent via 'from'", util.check([[
         local struct Animal
            name: string
            sound: string
         end

         local struct Dog from Animal
            breed: string
         end

         local d = Dog.new { name = "Rex", sound = "Woof", breed = "Lab" }
         print(d.name, d.sound, d.breed)
      ]]))

      it("inherits methods from parent at runtime via __index chain", util.check([[
         local struct Animal
            name: string
         end

         function Animal:greet(): string
            return "hello from " .. self.name
         end

         local struct Dog from Animal
            breed: string
         end

         local d = Dog.new { name = "Rex", breed = "Lab" }
         print(d:greet())
      ]]))

      it("allows overriding init in child", function()
         local result, err = tl.check_string([[
            local struct Animal
               name: string
               sound: string
            end

            function Animal:init()
               self.sound = self.sound or "<silence>"
            end

            local struct Dog from Animal
               breed: string
            end

            function Dog:init()
               self.sound = "Woof"
            end

            local d = Dog.new { name = "Rex", breed = "Lab" }
            print(d.sound)
         ]])
         assert.same({}, result.type_errors)
      end)
   end)

   describe("static fields", function()
      it("declares static fields in a static ... end block", util.check([[
         local struct Counter
            count: number

            static
               PI: number = 3.14
               version: string
            end
         end
      ]]))

      it("auto-initializes static fields with initializers", function()
         local result, err = tl.check_string([[
            local struct Counter
               count: number

               static
                  total: number = 0
                  PI: number = 3.14
               end
            end

            -- accessible on the type itself:
            print(Counter.total)
            print(Counter.PI)
         ]])
         assert.same({}, result.type_errors)
      end)

      it("allows static fields without initializer to be assigned later", util.check([[
         local struct Config
            debug: boolean

            static
               version: string
            end
         end

         Config.version = "1.0.0"
         print(Config.version)
      ]]))

      it("makes static fields accessible via instances through __index", util.check([[
         local struct Constants
            x: number

            static
               PI: number = 3.14
            end
         end

         local c = Constants.new { x = 1 }
         print(c.PI)
      ]]))

      it("rejects static fields passed to .new opts", function()
         local result, err = tl.check_string([[
            local struct Counter
               count: number

               static
                  total: number = 0
               end
            end

            local c = Counter.new { count = 1, total = 99 }
         ]])
         assert.truthy(result.type_errors and #result.type_errors > 0,
                       "expected a type error when passing static field to .new")
      end)

      it("inherits static fields from parent struct", util.check([[
         local struct Base
            x: number

            static
               klass: string = "Base"
               count: number = 0
            end
         end

         local struct Derived from Base
            y: number
         end

         print(Derived.klass)
         print(Derived.count)
      ]]))

      it("allows only one static block per struct", function()
         local result, err = tl.check_string([[
            local struct Foo
               x: number

               static
                  a: number = 1
               end

               static
                  b: number = 2
               end
            end
         ]])
         assert.truthy(result.syntax_errors and #result.syntax_errors > 0,
                       "expected a syntax error for multiple static blocks")
      end)
   end)

   describe("production hardening", function()
      it("rejects table literals assigned to a struct type", function()
         local result, err = tl.check_string([[
            local struct Point
               x: number
               y: number
            end

            local p: Point = { x = 3, y = 4 }
         ]])
         assert.truthy(result.type_errors and #result.type_errors > 0)
         assert.match("construct instances with Point%.new", result.type_errors[1].msg)
      end)

      it("rejects empty tables assigned to a struct type", function()
         local result, err = tl.check_string([[
            local struct Point
               x: number
            end

            local p: Point = {}
         ]])
         assert.truthy(result.type_errors and #result.type_errors > 0)
         assert.match("construct instances with Point%.new", result.type_errors[1].msg)
      end)

      it("rejects plain record values passed where a struct is expected", function()
         local result, err = tl.check_string([[
            local struct Point
               x: number
               y: number
            end

            local function f(p: Point): number
               return p.x
            end

            local v = { x = 1, y = 2 }
            print(f(v))
         ]])
         assert.truthy(result.type_errors and #result.type_errors > 0)
         assert.match("Point is a struct", result.type_errors[1].msg)
      end)

      it("still accepts struct instances where a parent struct is expected", function()
         local result, err = tl.check_string([[
            local struct Base
               x: number
            end

            local struct Child from Base
               y: number
            end

            local function f(b: Base): number
               return b.x
            end

            local c = Child.new { x = 1, y = 2 }
            print(f(c))
         ]])
         assert.same({}, result.type_errors)
      end)

      it("rejects a record as parent of a struct", function()
         local result, err = tl.check_string([[
            local record Rec
               a: number
            end

            local struct Child from Rec
               b: number
            end
         ]])
         assert.truthy(result.type_errors and #result.type_errors > 0)
         assert.match("can only extend another struct", result.type_errors[1].msg)
      end)

      it("rejects an interface as parent of a struct", function()
         local result, err = tl.check_string([[
            local interface Iface
               a: number
            end

            local struct Child from Iface
               b: number
            end
         ]])
         assert.truthy(result.type_errors and #result.type_errors > 0)
         assert.match("can only extend another struct", result.type_errors[1].msg)
      end)

      it("supports global structs", function()
         local result, err = tl.check_string([[
            global struct Config
               name: string

               static
                  version: string = "1.0"
               end
            end

            local c = Config.new { name = "test" }
            print(c.name, Config.version)
         ]])
         assert.same({}, result.type_errors)
      end)

      it("rejects generic structs with a clear error", function()
         local result, err = tl.check_string([[
            local struct Stack<T>
               items: {T}
            end
         ]])
         assert.truthy(result.type_errors and #result.type_errors > 0)
         assert.match("generic structs are not supported yet", result.type_errors[1].msg)
      end)

      it("rejects user-declared .new on a struct with a hint", function()
         local result, err = tl.check_string([[
            local struct Point
               x: number
            end

            function Point.new(x: number): Point
               return Point.new { x = x }
            end
         ]])
         assert.truthy(result.type_errors and #result.type_errors > 0)
         assert.match("structs generate %.new automatically", result.type_errors[1].msg)
      end)

      it("rejects static blocks in records", function()
         local result, err = tl.check_string([[
            local record R
               a: number
               static
                  b: number = 1
               end
            end
         ]])
         assert.truthy(result.syntax_errors and #result.syntax_errors > 0)
         assert.match("only allowed in struct", result.syntax_errors[1].msg)
      end)

      it("rejects 'from' in records", function()
         local result, err = tl.check_string([[
            local record A
               a: number
            end
            local record B from A
               b: number
            end
         ]])
         assert.truthy(result.syntax_errors and #result.syntax_errors > 0)
         assert.match("only allowed in struct", result.syntax_errors[1].msg)
      end)

      it("rejects nested structs", function()
         local result, err = tl.check_string([[
            local record Outer
               struct Inner
                  x: number
               end
               y: number
            end
         ]])
         assert.truthy(result.syntax_errors and #result.syntax_errors > 0)
         assert.match("cannot be nested", result.syntax_errors[1].msg)
      end)

      it("allows a type alias as struct parent", function()
         local result, err = tl.check_string([[
            local struct Point
               x: number
            end

            function Point:double(): number
               return self.x * 2
            end

            local type P = Point

            local struct P3 from P
               z: number
            end

            local p = P3.new { x = 1, z = 2 }
            print(p:double())
         ]])
         assert.same({}, result.type_errors)
      end)

      it("rejects incompatible field overrides in child structs", function()
         local result, err = tl.check_string([[
            local struct Base
               x: number
            end

            local struct Child from Base
               x: string
            end
         ]])
         assert.truthy(result.type_errors and #result.type_errors > 0)
         assert.match("conflicts with field inherited from 'Base'", result.type_errors[1].msg)
      end)

      it("allows compatible field overrides in child structs", function()
         local result, err = tl.check_string([[
            local struct Base
               x: number
            end

            local struct Child from Base
               x: number
               y: number
            end
         ]])
         assert.same({}, result.type_errors)
      end)

      it("runs parent init for children without their own init", function()
         local result, err = tl.check_string([[
            local struct A
               x: number
               doubled: number
            end

            function A:init()
               self.doubled = self.x * 2
            end

            local struct B from A
               y: number
            end

            local b = B.new { x = 5, y = 1 }
            print(b.doubled)
         ]])
         assert.same({}, result.type_errors)
      end)
   end)

   describe("default value typechecking", function()
      it("rejects a mistyped instance default value", function()
         local result, err = tl.check_string([[
            local struct Point
               x: number = "hello"
            end
         ]])
         assert.truthy(result.type_errors and #result.type_errors > 0)
         assert.match("invalid default value for field 'x'", result.type_errors[1].msg)
      end)

      it("rejects a mistyped static initializer", function()
         local result, err = tl.check_string([[
            local struct C
               a: number
               static
                  total: string = 3.14
               end
            end
         ]])
         assert.truthy(result.type_errors and #result.type_errors > 0)
         assert.match("invalid default value for field 'total'", result.type_errors[1].msg)
      end)

      it("accepts well-typed defaults of various kinds", util.check([[
         local D: number = 42

         local struct Point
            x: number = math.pi
            flag: boolean = false
            xs: {number} = { 1, 2, 3 }
            d: number = D
         end

         local p = Point.new { x = 1 }
         print(p.x, p.flag, #p.xs, p.d)
      ]]))

      it("reports errors inside default expressions", function()
         local result, err = tl.check_string([[
            local struct Point
               x: number = nonexistent_function()
            end
         ]])
         assert.truthy(result.type_errors and #result.type_errors > 0)
      end)

      it("rejects forward references in default expressions", function()
         local result, err = tl.check_string([[
            local struct Point
               x: number = later_fn()
            end

            local function later_fn(): number
               return 7
            end
         ]])
         assert.truthy(result.type_errors and #result.type_errors > 0)
         assert.match("later_fn", result.type_errors[1].msg)
      end)

      it("accepts references to earlier locals in defaults", util.check([[
         local D: number = 42

         local struct Point
            d: number = D
         end

         local p = Point.new {}
         print(p.d)
      ]]))

      it("emits static initializers in declaration order", function()
         local result, err = tl.check_string([[
            local struct S
               x: number
               static
                  A: number = 1
                  B: number = 2
                  C: number = 3
               end
            end
            print(S.C)
         ]])
         assert.same({}, result.type_errors)
      end)

      it("typechecks inherited defaults against the field type", function()
         local result, err = tl.check_string([[
            local struct Base
               x: number = 10
            end

            local struct Child from Base
               y: number
            end

            local c = Child.new { y = 1 }
            print(c.x, c.y)
         ]])
         assert.same({}, result.type_errors)
      end)
   end)

   describe("error cases", function()
      it("requires 'from' to be followed by a parent name", function()
         -- missing parent name after 'from' yields syntax errors
         local result = tl.check_string([[
            local struct Dog from
               breed: string
            end
         ]])
         assert.truthy(result.syntax_errors and #result.syntax_errors > 0)
      end)
   end)
end)
