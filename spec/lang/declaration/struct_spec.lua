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
      it("inherits fields from parent via ':Parent'", util.check([[
         local struct Animal
            name: string
            sound: string
         end

         local struct Dog:Animal
            breed: string
         end

         local d = Dog.new { name = "Rex", sound = "Woof", breed = "Lab" }
         print(d.name, d.sound, d.breed)
      ]]))

      it("inherits methods from parent via declaration-time flattening", util.check([[
         local struct Animal
            name: string
         end

         function Animal:greet(): string
            return "hello from " .. self.name
         end

         local struct Dog:Animal
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

            local struct Dog:Animal
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

         local struct Derived:Base
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

            local struct Child:Base
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

            local struct Child:Rec
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

            local struct Child:Iface
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

      it("rejects ':Parent' inheritance in records", function()
         local result, err = tl.check_string([[
            local record A
               a: number
            end
            local record B: A
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

      it("rejects nested structs declared through type aliases in type bodies", function()
         local result, err = tl.check_string([[
            local record Outer
               type Inner = struct
                  x: number
               end
            end

            local i = Outer.Inner.new { x = 1 }
         ]])
         assert.truthy(result.syntax_errors and #result.syntax_errors > 0)
         assert.match("cannot be nested", result.syntax_errors[1].msg)
      end)

      it("allows structs declared inside function bodies", util.check([[
         local function make(): P
            local struct P
               x: number = 1
            end

            function P:init()
               self.x = self.x + 1
            end

            return P.new { x = 1 }
         end

         local p = make()
         print(p.x)
      ]]))

      it("allows a type alias as struct parent", function()
         local result, err = tl.check_string([[
            local struct Point
               x: number
            end

            function Point:double(): number
               return self.x * 2
            end

            local type P = Point

            local struct P3:P
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

            local struct Child:Base
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

            local struct Child:Base
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

            local struct B:A
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

            local struct Child:Base
               y: number
            end

            local c = Child.new { y = 1 }
            print(c.x, c.y)
         ]])
         assert.same({}, result.type_errors)
      end)
   end)

   describe("error cases", function()
      it("requires a parent name after ':'", function()
         local result = tl.check_string([[
            local struct Dog:
            end
         ]])
         assert.truthy(result.syntax_errors and #result.syntax_errors > 0)
      end)

      it("rejects a non-identifier parent", function()
         local result = tl.check_string([[
            local struct Dog: 123
               breed: string
            end
         ]])
         assert.truthy(result.syntax_errors and #result.syntax_errors > 0)
      end)
   end)

   describe(":Parent syntax ergonomics", function()
      it("allows a field named 'from' in first position of the body", util.check([[
         local struct Ledger
            from: string = "start"
            to: string = "end"
         end

         local l = Ledger.new {}
         print(l.from, l.to)
      ]]))

      it("supports parents written without surrounding whitespace", util.check([[
         local struct Animal
            name: string
         end

         local struct Dog:Animal
            breed: string
         end

         local d = Dog.new { name = "Rex", breed = "Lab" }
         print(d.name, d.breed)
      ]]))
   end)

   describe("method flattening and override", function()
      it("flattens inherited methods onto the child struct", util.check([[
         local struct Shape
            name: string
         end

         function Shape:describe(): string
            return "shape:" .. self.name
         end

         local struct Circle:Shape
            r: number
         end

         local c = Circle.new { name = "O", r = 5 }
         print(c:describe())
         print(Circle.describe(c))
      ]]))

      it("child method definitions override inherited copies", util.check([[
         local struct Shape
            name: string
         end

         function Shape:describe(): string
            return "shape:" .. self.name
         end

         local struct Circle:Shape
            r: number
         end

         function Circle:describe(): string
            return "circle:" .. self.name
         end

         local c = Circle.new { name = "O", r = 5 }
         print(c:describe())
      ]]))

      it("child defaults override inherited defaults", util.check([[
         local struct Base
            x: number = 1
         end

         local struct Child:Base
            x: number = 5
         end

         local c = Child.new {}
         local b = Base.new {}
         print(c.x, b.x)
      ]]))

      it("runs the init chain from parents to children", util.check([[
         local struct A
            log: {string}
         end

         function A:init()
            table.insert(self.log, "A")
         end

         local struct B:A
         end

         function B:init()
            table.insert(self.log, "B")
         end

         local struct C:B
         end

         function C:init()
            table.insert(self.log, "C")
         end

         local c = C.new { log = {} }
         print(table.concat(c.log, ","))
      ]]))

      it("skips ancestors without their own init in the chain", util.check([[
         local struct A
            log: {string}
         end

         function A:init()
            table.insert(self.log, "A")
         end

         local struct B:A
         end

         local struct C:B
         end

         function C:init()
            table.insert(self.log, "C")
         end

         local c = C.new { log = {} }
         print(table.concat(c.log, ","))   -- "A,C": B declares no init

         local b = B.new { log = {} }
         print(table.concat(b.log, ","))   -- "A": inherited init runs
      ]]))

      it("reports a mistyped parent default exactly once in children", function()
         local result, err = tl.check_string([[
            local struct Base
               x: number = "bad"
            end

            local struct Child:Base
               y: number
            end
         ]])
         assert.truthy(result.type_errors and #result.type_errors > 0)
         local n = 0
         for _, e in ipairs(result.type_errors) do
            if e.msg:match("invalid default value for field 'x'") then
               n = n + 1
            end
         end
         assert.equals(1, n)
      end)
   end)

   describe("acceptance battery", function()
      it("rejects a data field named 'new' with a clear error", function()
         local result, err = tl.check_string([[
            local struct A
               new: number = 5
            end
            local a = A.new {}
         ]])
         assert.truthy(result.type_errors and #result.type_errors > 0)
         assert.match("new' is reserved", result.type_errors[1].msg)
      end)

      it("allows a data field named 'init'", util.check([[
         local struct A
            x: number
            init: number = 7
         end
         local a = A.new { x = 1 }
         print(a.init)
      ]]))

      it("rejects a static field shadowing an instance field", function()
         local result, err = tl.check_string([[
            local struct A
               x: number
               static
                  x: number = 5
               end
            end
         ]])
         assert.truthy((result.type_errors and #result.type_errors > 0)
                       or (result.syntax_errors and #result.syntax_errors > 0))
      end)

      it("supports metamethod declarations in struct bodies", util.check([[
         local struct SVec
            x: number
            y: number
            metamethod __len: function(self): integer
         end

         function SVec.__len(self): integer
            return 2
         end

         local v = SVec.new { x = 1, y = 2 }
         print(#v)
      ]]))

      it("supports array interfaces combined with inheritance", util.check([[
         local struct Node is {Node}
            weight: number
         end

         local struct Big:Node
            extra: boolean
         end

         local n = Node.new { weight = 1 }
         local b = Big.new { weight = 2, extra = true }
         print(n.weight, b.weight, b.extra)
      ]]))

      it("supports structs exported and instantiated across modules", function()
         util.mock_io(finally, {
            ["animal.tl"] = [[
               local struct Animal
                  name: string
               end

               function Animal:speak(): string
                  return self.name .. " speaks"
               end

               return Animal
            ]],
            ["main.tl"] = [[
               local Animal = require("animal")
               local a = Animal.new { name = "Rex" }
               print(a:speak())
            ]],
         })
         local result, err = tl.check_file("main.tl")
         assert.truthy(result)
         assert.same({}, result.type_errors)
      end)

      it("supports cross-module parents via top-level require locals", function()
         util.mock_io(finally, {
            ["animal.tl"] = [[
               local struct Animal
                  name: string
                  legs: number = 4
               end

               function Animal:init()
                  self.name = self.name or "<unnamed>"
               end

               function Animal:speak(): string
                  return self.name .. " says hello"
               end

               return Animal
            ]],
            ["dog.tl"] = [[
               local Animal = require("animal")

               local struct Dog:Animal
                  breed: string
               end

               function Dog:speak(): string
                  return self.name .. " the " .. self.breed .. " barks"
               end

               local d = Dog.new { name = "Rex", breed = "Lab" }
               print(d:speak())
               print(Animal.speak(d))
               print(d.legs)
               return Dog
            ]],
         })
         local result, err = tl.check_file("dog.tl")
         assert.truthy(result)
         assert.same({}, result.type_errors)
      end)

      it("rejects global cross-module parents (no runtime presence guarantee)", function()
         util.mock_io(finally, {
            ["gmod.tl"] = [[
               global struct GAnimal
                  name: string
               end

               return {}
            ]],
            ["dog.tl"] = [[
               local M = require("gmod")
               print(type(M))

               local struct Dog:GAnimal
                  breed: string
               end
            ]],
         })
         local result, err = tl.check_file("dog.tl")
         assert.truthy(result)
         assert.truthy(result.type_errors and #result.type_errors > 0)
         assert.match("returned directly by a required module", result.type_errors[1].msg)
      end)

      it("rejects cross-module parents whose ancestors declare init", function()
         util.mock_io(finally, {
            ["chainmod.tl"] = [[
               local struct Base
                  tag: string
               end

               function Base:init()
                  self.tag = "base"
               end

               local struct Animal:Base
                  name: string
               end

               return Animal
            ]],
            ["dog.tl"] = [[
               local A = require("chainmod")

               local struct Dog:A
                  breed: string
               end
            ]],
         })
         local result, err = tl.check_file("dog.tl")
         assert.truthy(result)
         assert.truthy(result.type_errors and #result.type_errors > 0)
         assert.match("not visible outside its module", result.type_errors[1].msg)
      end)

      it("rejects cross-module parents with computed default values", function()
         util.mock_io(finally, {
            ["kmod.tl"] = [[
               local K: number = 7

               local struct Animal
                  name: string
                  speed: number = K
               end

               return Animal
            ]],
            ["dog.tl"] = [[
               local A = require("kmod")

               local struct Dog:A
                  breed: string
               end
            ]],
         })
         local result, err = tl.check_file("dog.tl")
         assert.truthy(result)
         assert.truthy(result.type_errors and #result.type_errors > 0)
         assert.match("only literal defaults are inheritable", result.type_errors[1].msg)
      end)

      it("rejects cross-module parents described by declaration files", function()
         util.mock_io(finally, {
            ["dlib.lua"] = [[
               return {
                  greet = function(self) return "hi " .. self.name end,
               }
            ]],
            ["dlib.d.tl"] = [[
               local type Lib = struct
                  name: string
                  greet: function(self): string
               end
               return Lib
            ]],
            ["dog.tl"] = [[
               local L = require("dlib")

               local struct Dog:L
                  breed: string
               end
            ]],
         })
         local result, err = tl.check_file("dog.tl")
         assert.truthy(result)
         assert.truthy(result.type_errors and #result.type_errors > 0)
         assert.match("described by declaration files", result.type_errors[1].msg)
      end)
   end)
end)
