local tl = require("tl")
local util = require("spec.util")

describe("record method", function()
   it("valid declaration", util.check [[
      local r = {
         x = 2,
         b = true,
      }
      function r:f(a: number, b: string): boolean
         if self.b then
            return #b == 3
         else
            return a > self.x
         end
      end
      local ok = r:f(3, "abc")
   ]])

   it("valid declaration with type variables", util.check [[
      local r = {
         x = 2,
         b = true,
      }
      function r:f<T>(a: number, b: string, xs: {T}): boolean, T
         if self.b then
            return #b == 3, xs[1]
         else
            return a > self.x, xs[2]
         end
      end
      local ok, s = r:f(3, "abc", {"what"})
      print(s .. "!")
   ]])

   it("nested declaration", util.check [[
      local r = {
         z = {
            x = 2,
            b = true,
         },
      }
      function r.z:f(a: number, b: string): boolean
         if self.b then
            return #b == 3
         else
            return a > self.x
         end
      end
      local ok = r.z:f(3, "abc")
   ]])

   it("nested declaration in {}", util.check [[
      local r = {
         z = {},
      }
      function r.z:f(a: number, b: string): boolean
         return true
      end
      local ok = r.z:f(3, "abc")
   ]])

   it("deep nested declaration", util.check [[
      local r = {
         a = {
            b = {
               x = true
            }
         },
      }
      function r.a.b:f(a: number, b: string): boolean
         return self.x
      end
      local ok = r.a.b:f(3, "abc")
   ]])

   it("resolves self", util.check_type_error([[
      local r = {
         x = 2,
         b = true,
      }
      function r:f(a: number, b: string): boolean
         return self.invalid
      end
      local ok = r:f(3, "abc")
   ]], {
      { msg = "invalid key 'invalid' in record 'self'" }
   }))

   it("resolves self but does not output it as an argument (#27)", function()
      util.mock_io(finally, {
         ["foo.tl"] = [[
            local r = {
               x = 2,
               b = true,
            }
            function r:f(a: number, b: string): boolean
               return self.invalid
            end
            function r:g()
               return
            end
            local ok = r:f(3, "abc")
         ]],
      })
      local result, err = tl.process("foo.tl")
      local output = tl.pretty_print_ast(result.ast)
      util.assert_line_by_line([[
         local r = {
            x = 2,
            b = true,
         }
         function r:f(a, b)
            return self.invalid
         end
         function r:g()
            return
         end
         local ok = r:f(3, "abc")
      ]], output)
   end)

   it("catches invocation style", util.check_type_error([[
      local r = {
         x = 2,
         b = true,
      }
      function r:f(a: number, b: string): boolean
         return self.b
      end
      local ok = r.f(3, "abc")
   ]], {
      { msg = "invoked method as a regular function" }
   }))

   it("allows invocation when properly used with '.'", util.check [[
      local r = {
         x = 2,
         b = true,
      }
      function r:f(a: number, b: string): boolean
         return self.b
      end
      local ok = r.f(r, 3, "abc")
   ]])

   it("allows invocation when properly used with ':'", util.check [[
      local r = {
         x = 2,
         b = true,
      }
      function r:f(a: number, b: string): boolean
         return self.b
      end
      local ok = r:f(3, "abc")
   ]])

   it("allows colon notation in methods", function()
      util.mock_io(finally, {
         ["foo.tl"] = [[
            local type Point = record
               x: number
               y: number
               __index: Point
            end

            Point.__index = Point

            function Point.new(x: number, y: number): Point
               local self = setmetatable({} as Point, Point as metatable<Point>)

               self.x = x or 0
               self.y = y or 0

               return self
            end

            function Point:print()
               print("x: " .. self.x .. "; y: " .. self.y)
            end

            local a = Point.new(1, 1)

            a:print()
         ]]
      })
      local result, err = tl.process("foo.tl")
      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
      local output = tl.pretty_print_ast(result.ast)
      util.assert_line_by_line([[
         local Point = {}





         Point.__index = Point

         function Point.new(x, y)
            local self = setmetatable({}, Point)

            self.x = x or 0
            self.y = y or 0

            return self
         end

         function Point:print()
            print("x: " .. self.x .. "; y: " .. self.y)
         end

         local a = Point.new(1, 1)

         a:print()
      ]], output)
   end)

   it("record method assignment must match record type", util.check_type_error([[
      local type Foo = record
         x: string
      end
      local foo_mt: metatable<Foo> = {}
      foo_mt.__tostring = function()
         return "hello"
      end
   ]], {
      { msg = "in assignment: incompatible number of returns: got 0 (), expected 1 (string)" },
      { msg = "excess return values, expected 0 (), got 1 (string \"hello\")" },
   }))

   it("allows functions declared on method tables (#27)", function()
      util.mock_io(finally, {
         ["foo.tl"] = [[
            local type Point = record
               x: number
               y: number
            end

            local PointMetatable: metatable<Point> = {
               __index = Point
            }

            function Point.new(x: number, y: number): Point
               local self = setmetatable({} as Point, PointMetatable)

               self.x = x or 0
               self.y = y or 0

               return self
            end

            function Point.move(self: Point, dx: number, dy: number)
               self.x = self.x + dx
               self.y = self.y + dy
            end

            local pt: Point = Point.new(1, 2)
            pt:move(3, 4)
         ]]
      })
      local result, err = tl.process("foo.tl")
      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
      local output = tl.pretty_print_ast(result.ast)
      util.assert_line_by_line([[
         local Point = {}




         local PointMetatable = {
            __index = Point,
         }

         function Point.new(x, y)
            local self = setmetatable({}, PointMetatable)

            self.x = x or 0
            self.y = y or 0

            return self
         end

         function Point.move(self, dx, dy)
            self.x = self.x + dx
            self.y = self.y + dy
         end

         local pt = Point.new(1, 2)
         pt:move(3, 4)
      ]], output)
   end)

   it("does not fail when declaring methods on untyped self (regression test for #427)", util.check_type_error([[
      function foo()
        local self = { }
        function self:bar(): string
          return "bar"
        end
        return self
      end
   ]], {
      { msg = "in return value: excess return values" }
   }))

   it("does not fail when traversing dot on non-record", util.check_type_error([[
      local foo: number
      function foo.bla:bar(): string
         return "bar"
      end
   ]], {
      { msg = "cannot index something that is not a record" }
   }))

   it("does not fail when declaring methods on untyped self (regression test for #427)", util.check [[
      local record T<A, B>
        method: function(function(A)): T<A, B>
      end

      local t = { }

      function t.new<A, B>(): T<A, B>
        local self = { }
        function self:method(callback: function(A)): T<A, B>
          return self
        end
        return self
      end

      return t
   ]])

   it("does not fail when declaring methods a record where they were already declared (regression test for #463)", util.check [[
      local record Tank
          left: function(Tank)
          right: function(Tank)
      end

      function Tank:left() end
      function Tank:right() end

      local function foo(direction: string): boolean
          local playerTank: Tank
          local enum E
              "left"
              "right"
          end
          playerTank[direction as E](playerTank)
          return false
      end
   ]])

   it("catches method on unknown variable (regression test for #470)", util.check_type_error([[
      function bla.dosomething()
      end
   ]], {
      { msg = "unknown variable: bla" }
   }))

   it("doesn't hang when comparing method and non-method (regression test for #501)", util.check_type_error([[
      local record Point
      end

      function Point:new(x: number, y: number): Point
      end

      function Point:move(dx: number, dy: number)
      end

      local record Rect
        move: function(Rect, number, number)
      end

      function Rect:new(top_left: Point, right_bottom: Point): Rect
        top_left.new(self)
        return self
      end
   ]], {
      { msg = "invoked method as a regular function" }
   }))

end)
