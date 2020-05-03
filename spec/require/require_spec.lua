local tl = require("tl")
local util = require("spec.util")

describe("require", function()
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
      assert.same(0, #result.unknowns)
   end)

   it("exports types", function ()
      -- ok
      util.mock_io(finally, {
         ["point.tl"] = [[
            local Point = record
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
      assert.same({}, result.unknowns)
   end)

   it("local types can be exported indirectly, but not their names", function ()
      util.mock_io(finally, {
         ["box.tl"] = [[
            local box = {}

            -- local type
            local Box = record
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
      assert.same({}, result.unknowns)
   end)

   it("exported types resolve regardless of module name", function ()
      -- ok
      util.mock_io(finally, {
         ["point.tl"] = [[
            local Point = record
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
         ["foo.tl"] = [[
            local point = require "point"
            local bar = require "bar"

            function use_point(p: point.Point)
               print(p.x, p.y)
            end

            use_point(bar.get_point():move(5, 5))
         ]],
      })
      local result, err = tl.process("foo.tl")

      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
      assert.same({}, result.unknowns)
   end)

   it("equality of nominal types does not depend on module names", function ()
      -- ok
      util.mock_io(finally, {
         ["point.tl"] = [[
            local Point = record
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
      assert.same({}, result.unknowns)
   end)

   it("does not get confused by similar names", function ()
      -- ok
      util.mock_io(finally, {
         ["point.tl"] = [[
            local Point = record
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

            local Point = record
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
      -- not ideal message, but technically correct...
      assert.match("Point is not a Point", result.type_errors[1].msg, 1, true)
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
      assert.same(1, #result.type_errors)
      assert.match("cannot use operator ..", result.type_errors[1].msg)
      assert.same(0, #result.unknowns)
   end)

   it("exports global types", function ()
      -- ok
      util.mock_io(finally, {
         ["box.tl"] = [[
            local box = {}

            -- global type
            global Box = record
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
      assert.same(0, #result.unknowns)
   end)

   it("exports scoped types", function ()
      -- ok
      util.mock_io(finally, {
         ["box.tl"] = [[
            local box = {
               Box = record
                  x: number
                  y: number
                  w: number
                  h: number
               end
            }

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
      assert.same(0, #result.unknowns)
   end)

   it("cannot extend a record object with unknown types outside of scope", function ()
      util.mock_io(finally, {
         ["love.d.tl"] = [[
            global LoveGraphics = record
               print: function(text: string)
            end

            global Love = record
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

      local result, err = tl.process("foo.tl", nil, nil, {"love"})

      assert.same(nil, err)
      assert.same({}, result.syntax_errors)
      assert.match("cannot add undeclared function 'draws' outside of the scope where 'love' was originally declared", result.type_errors[1].msg)
      assert.same({}, result.unknowns)
   end)

   it("cannot extend a record type with unknown types outside of scope", function ()
      util.mock_io(finally, {
         ["love.d.tl"] = [[
            global love_graphics = record
               print: function(text: string)
            end

            global love = record
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

      local result, err = tl.process("foo.tl", nil, nil, {"love"})

      assert.same(nil, err)
      assert.same({}, result.syntax_errors)
      assert.match("cannot add undeclared function 'draws' outside of the scope where 'love' was originally declared", result.type_errors[1].msg)
      assert.same({}, result.unknowns)
   end)
end)
