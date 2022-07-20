local tl = require("tl")
local util = require("spec.util")

describe("require", function()
   it("reports module not found", util.check_type_error([[
      local notfound = require "modulenotfound"
   ]], {
      { y = 1, msg = "module not found: 'modulenotfound'" }
   }))

   it("for .tl files, complain if required module has no type information", function ()
      -- ok
      util.mock_io(finally, {
         ["box.lua"] = [[
            local box = {}

            function box.foo(n)
               return "hello number " .. tostring(n)
            end

            return box
         ]],
         ["foo.tl"] = [[
            local Box = require "box"

            Box.foo(123)
         ]],
      })
      local result, err = tl.process("foo.tl")

      assert.same(0, #result.syntax_errors)
      assert.same({
         { filename = "foo.tl", y = 1, x = 33, msg = "no type information for required module: 'box'" },
      }, result.type_errors)
   end)

   it("exports functions", function ()
      -- ok
      util.mock_io(finally, {
         ["box.tl"] = [[
            local box = {}

            function box.foo(n: number): string
               return "hello number " .. tostring(n)
            end

            return box
         ]],
         ["foo.tl"] = [[
            local Box = require "box"

            Box.foo(123)
         ]],
      })
      local result, err = tl.process("foo.tl")

      assert.same(0, #result.syntax_errors)
      assert.same(0, #result.type_errors)
   end)

   it("exports types", function ()
      -- ok
      util.mock_io(finally, {
         ["point.tl"] = [[
            local type Point = record
               x: number
               y: number
            end

            local point = {
               Point = Point,
            }

            function Point:move(x: number, y: number)
               self.x = self.x + x
               self.y = self.y + y
            end

            return point
         ]],
         ["foo.tl"] = [[
            local point = require "point"

            function bla(p: point.Point)
               print(p.x, p.y)
            end
         ]],
      })
      local result, err = tl.process("foo.tl")

      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
   end)

   it("local types can be exported indirectly, but not their names", function ()
      util.mock_io(finally, {
         ["box.tl"] = [[
            local box = {}

            local type Box = record
               x: number
               y: number
               w: number
               h: number
            end

            function box.foo(self: Box): Box
               return self
            end

            return box
         ]],
         ["foo.tl"] = [[
            local box = require "box"

            -- passing a table that matches the local type works
            local b = box.foo({ x = 10, y = 10, w = 123, h = 120 })

            -- you can declare a variable based on another value's type
            local anotherbox = b
            anotherbox = { x = 10, y = 10, w = 123, h = 120 }
         ]],
      })
      local result, err = tl.process("foo.tl")

      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
   end)

   it("exported types resolve regardless of module name", function ()
      -- ok
      util.mock_io(finally, {
         ["point.tl"] = [[
            local type Point = record
               x: number
               y: number
            end

            local point = {
               Point = Point,
            }

            function Point:move(x: number, y: number)
               self.x = self.x + x
               self.y = self.y + y
            end

            return point
         ]],
         ["bar.tl"] = [[
            local bar = {}

            local mypoint = require "point"

            function bar.get_point(): mypoint.Point
               return { x = 100, y = 100 }
            end

            return bar
         ]],
         ["bla.tl"] = [[
            local type bla = record
               record subtype
                  xx: number
               end
            end

            function bla.func(): bla.subtype
               return { xx = 2 }
            end

            return bla
         ]],
         ["foo.tl"] = [[
            local pnt = require "point"
            local bar = require "bar"
            local bla1 = require "bla"

            function use_point(p: pnt.Point)
               print(p.x, p.y)
               print(bla1.func().xx)
            end

            use_point(bar.get_point():move(5, 5))
         ]],
      })
      local result, err = tl.process("foo.tl")

      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
   end)

   it("local types can get exported", function ()
      -- ok
      util.mock_io(finally, {
         ["point.tl"] = [[
            local type Point = record
               x: number
               y: number
            end

            local point = {
               Point = Point,
            }

            function Point:move(x: number, y: number)
               self.x = self.x + x
               self.y = self.y + y
            end

            return point
         ]],
         ["bar.tl"] = [[
            local mypoint = require "point"

            local type rec = record
               xx: number
               yy: number
            end

            local function get_point(): mypoint.Point
               return { x = 100, y = 100 }
            end

            return {
               get_point = get_point,
               rec = rec,
            }
         ]],
         ["foo.tl"] = [[
            local pnt = require "point"
            local bar = require "bar"

            function use_point(p: pnt.Point)
               print(p.x, p.y)
            end

            use_point(bar.get_point():move(5, 5))
            local r: bar.rec = {
               xx = 10,
               yy = 20,
            }
         ]],
      })
      local result, err = tl.process("foo.tl")

      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
   end)

   it("equality of nominal types does not depend on module names", function ()
      -- ok
      util.mock_io(finally, {
         ["point.tl"] = [[
            local type Point = record
               x: number
               y: number
            end

            local point = {
               Point = Point,
            }

            return point
         ]],
         ["foo.tl"] = [[
            local point1 = require "point"
            local point2 = require "point"

            local a: point1.Point = { x = 1, y = 2 }
            local b: point2.Point = a
         ]],
      })
      local result, err = tl.process("foo.tl")

      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
   end)

   it("does not get confused by similar names", function ()
      -- ok
      util.mock_io(finally, {
         ["point.tl"] = [[
            local type Point = record
               x: number
               y: number
            end

            local point = {
               Point = Point,
            }

            function point.f(p: Point): number
               return p.x + p.y
            end

            return point
         ]],
         ["foo.tl"] = [[
            local point1 = require "point"

            local type Point = record
               foo: string
            end

            local a: point1.Point = { x = 1, y = 2 }

            local myp: Point = { foo = "hello" }
            point1.f(myp)
         ]],
      })
      local result, err = tl.process("foo.tl")

      assert.same({}, result.syntax_errors)
      assert.same(1, #result.type_errors)
      assert.match("Point (defined in foo.tl:3) is not a Point (defined in point.tl:1)", result.type_errors[1].msg, 1, true)
   end)

   it("catches errors in exported functions", function ()
      util.mock_io(finally, {
         ["box.tl"] = [[
            local box = {}

            function box.foo(n: number): string
               return "hello number " .. box.foo
            end

            return box
         ]],
         ["foo.tl"] = [[
            local Box = require "box"

            Box.foo(123)
         ]],
      })
      local result, err = tl.process("foo.tl")

      assert.same(0, #result.syntax_errors)
      assert.same(1, #result.env.loaded["box.tl"].type_errors)
      assert.match("cannot use operator ..", result.env.loaded["box.tl"].type_errors[1].msg)
   end)

   it("exports global types", function ()
      -- ok
      util.mock_io(finally, {
         ["box.tl"] = [[
            local box = {}

            -- global type
            global type Box = record
               x: number
               y: number
               w: number
               h: number
            end

            function box.foo(self: Box): string
               return "hello " .. tostring(self.w)
            end

            return box
         ]],
         ["foo.tl"] = [[
            local box = require "box"

            box.foo({ x = 10, y = 10, w = 123, h = 120 })
         ]],
      })
      local result, err = tl.process("foo.tl")

      assert.same(0, #result.syntax_errors)
      assert.same(0, #result.type_errors)
   end)

   it("exports scoped types", function ()
      -- ok
      util.mock_io(finally, {
         ["box.tl"] = [[
            local record box
               record Box
                  x: number
                  y: number
                  w: number
                  h: number
               end
            end

            function box.foo(self: box.Box): string
               return "hello " .. tostring(self.w)
            end

            return box
         ]],
         ["foo.tl"] = [[
            local Box = require "box"

            Box.foo({ x = 10, y = 10, w = 123, h = 120 })
         ]],
      })
      local result, err = tl.process("foo.tl")

      assert.same(0, #result.syntax_errors)
      assert.same(0, #result.type_errors)
   end)

   it("nested types resolve in definition files", function ()
      -- ok
      util.mock_io(finally, {
         ["someds.d.tl"] = [[
            local type someds = record
               type Event = record
               end
               type Callback = function(Event)
               subscribe: function(callback: Callback)
            end

            return someds
         ]],
         ["main.tl"] = [[
            local someds = require("someds")

            function main()
               local b:someds.Callback = function(event: someds.Event)
               end
               someds.subscribe(b)
            end
         ]],
      })
      local result, err = tl.process("main.tl")

      assert.same(0, #result.syntax_errors)
      assert.same(0, #result.type_errors)
   end)

   it("nested types resolve in definition files required with different name", function ()
      -- ok
      util.mock_io(finally, {
         ["someds.d.tl"] = [[
            local type someds = record
               type Event = record
               end
               type Callback = function(Event)
               subscribe: function(callback: Callback)
            end

            return someds
         ]],
         ["main.tl"] = [[
            local som = require("someds")

            function main()
               local b:som.Callback = function(event: som.Event)
               end
               som.subscribe(b)
            end
         ]],
      })
      local result, err = tl.process("main.tl")

      assert.same(0, #result.syntax_errors)
      assert.same(0, #result.type_errors)
   end)

   it("nested types with metamethods resolve in definition files required with different names (#326)", function ()
      -- ok
      util.mock_io(finally, {
         ["my_huge_lib_name.d.tl"] = [[
            local record my_huge_lib_name
              record nested_type
                f: function(my_huge_lib_name.nested_type, my_huge_lib_name.nested_type)
                metamethod __add: function(my_huge_lib_name.nested_type, number)
              end
              new: function(): my_huge_lib_name.nested_type
            end
            return my_huge_lib_name
         ]],
         ["main.tl"] = [[
            local lib = require 'my_huge_lib_name'
            local v = lib.new()
            v:f(v) -- this works fine
            print(v + 2)
         ]],
      })
      local result, err = tl.process("main.tl")

      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
   end)

   it("generic nested types resolve in definition files", function ()
      -- ok
      util.mock_io(finally, {
         ["someds.d.tl"] = [[
            local type someds = record
               type Event = record<T>
                  x: T
               end
               type Callback = function(Event<string>)
               subscribe: function(callback: Callback)
            end

            return someds
         ]],
         ["main.tl"] = [[
            local someds = require("someds")

            function main()
               local b:someds.Callback = function(event: someds.Event<string>)
               end
               someds.subscribe(b)
            end
         ]],
      })
      local result, err = tl.process("main.tl")

      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
   end)

   it("cannot extend a record object with unknown types outside of scope", function ()
      util.mock_io(finally, {
         ["love.d.tl"] = [[
            global type LoveGraphics = record
               print: function(text: string)
            end

            global type Love = record
               draw: function()
               graphics: LoveGraphics
            end

            global love: Love
         ]],
         ["foo.tl"] = [[
            function love.draw()
               love.graphics.print("<3")
            end

            function love.draws()
               love.graphics.print("</3")
            end
         ]],
      })

      local result, err = tl.process("foo.tl", assert(tl.init_env(false, nil, nil, {"love"})))

      assert.same(nil, err)
      assert.same({}, result.syntax_errors)
      assert.match("cannot add undeclared function 'draws' outside of the scope where 'love' was originally declared", result.type_errors[1].msg)
   end)

   it("cannot extend a record type with unknown types outside of scope", function ()
      util.mock_io(finally, {
         ["love.d.tl"] = [[
            global type love_graphics = record
               print: function(text: string)
            end

            global type love = record
               draw: function()
               graphics: love_graphics
            end
         ]],
         ["foo.tl"] = [[
            function love.draw()
               love.graphics.print("<3")
            end

            function love.draws()
               love.graphics.print("</3")
            end
         ]],
      })

      local result, err = tl.process("foo.tl", assert(tl.init_env(false, nil, nil, {"love"})))

      assert.same(nil, err)
      assert.same({}, result.syntax_errors)
      assert.same(1, #result.type_errors)
      assert.match("cannot add undeclared function 'draws' outside of the scope where 'love' was originally declared", result.type_errors[1].msg)
   end)

   it("cannot extend a record type outside of scope", function ()
      util.mock_io(finally, {
         ["widget.tl"] = [[
            local type Widget = record
                draw: function(self: Widget)
            end

            return Widget
         ]],
         ["foo.tl"] = [[
            local Widget = require("widget")

            function Widget:totally_unrelated_function()
                print("heyo")
            end
         ]],
      })

      local result, err = tl.process("foo.tl")

      assert.same(nil, err)
      assert.same({}, result.syntax_errors)
      assert.same(1, #result.type_errors)
      assert.match("cannot add undeclared function 'totally_unrelated_function' outside of the scope where 'Widget' was originally declared", result.type_errors[1].msg)
   end)

   it("can redeclare a function that was previously declared outside of scope", function ()
      util.mock_io(finally, {
         ["widget.tl"] = [[
            local type Widget = record
                draw: function(self: Widget)
            end

            return Widget
         ]],
         ["foo.tl"] = [[
            local Widget = require("widget")

            function Widget:draw()
                print("heyo")
            end
         ]],
      })

      local result, err = tl.process("foo.tl")

      assert.same(nil, err)
      assert.same({}, result.syntax_errors)
      assert.same(0, #result.type_errors)
   end)

   it("can extend a global defined in scope", function ()
      util.mock_io(finally, {
         ["luaunit.d.tl"] = [[
            global type luaunit_runner_t = record
               setOutputType: function(luaunit_runner_t, string)
               runSuite: function(luaunit_runner_t, any): number
            end

            global type luaunit_t = record
               new: function(): luaunit_runner_t
            end

            local type luaunit = record
               LuaUnit: luaunit_t
               assertIsTrue: function(any)
            end

            return luaunit
         ]],
         ["tests.tl"] = [[
            local lu = require("luaunit")
            local os = require("os")

            -- it must be global to use luaunit
            global TestSuite = {}

            function TestSuite:test_count()
                lu.assertIsTrue(100 == 200)
            end

            function main(args: any)
                local runner = lu.LuaUnit.new()
                runner:setOutputType("tap")
                local code = runner:runSuite(args)
                os.exit(code)
            end
         ]],
      })

      local result, err = tl.process("tests.tl")

      assert.same(nil, err)
      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
   end)

   it("can use type definitions to do dynamic dispatch on module returns (#334)", function()
      util.mock_io(finally, {
         ["minimal/type/Front.d.tl"] = [[
            local record Front
               bool: boolean
            end
            return Front
         ]],
         ["minimal/back.tl"] = [[
            local Front = require "minimal.type.Front"
            return function(bool: boolean): Front return {bool = bool} end
         ]],
         ["minimal/middle-true.tl"] = [[
            return (require "minimal.back")(true)
         ]],
         ["minimal/middle-false.tl"] = [[
            return (require "minimal.back")(false)
         ]],
         ["minimal/front.tl"] = [[
            if true then return require "minimal.middle-true" else return require "minimal.middle-false" end
         ]],
         ["minimal/proof.tl"] = [[
            local front = require "minimal.front"
            print(front.bool)
         ]],
      })

      local result, err = tl.process("minimal/proof.tl")

      assert.same(nil, err)
      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
   end)
end)
