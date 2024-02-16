local tl = require("tl")
local util = require("spec.util")

describe("record method", function()
   it("valid declaration", util.check([[
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
   ]]))

   it("valid declaration with type variables", util.check([[
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
   ]]))

   it("nested declaration", util.check([[
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
   ]]))

   it("nested declaration for record (regression test for #648)", util.check([[
      local record Math
         record Point
            x: number
            y: number
         end
      end

      function Math.Point:move(dx: number, dy: number)
         self.x = self.x + dx
         self.y = self.y + dy
      end
   ]]))

   it("nested declaration in {}", util.check([[
      local r = {
         z = {},
      }
      function r.z:f(a: number, b: string): boolean
         return true
      end
      local ok = r.z:f(3, "abc")
   ]]))

   it("deep nested declaration", util.check([[
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
   ]]))

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

   it("allows invocation when properly used with '.'", util.check([[
      local r = {
         x = 2,
         b = true,
      }
      function r:f(a: number, b: string): boolean
         return self.b
      end
      local ok = r.f(r, 3, "abc")
   ]]))

   it("allows invocation when properly used with ':'", util.check([[
      local r = {
         x = 2,
         b = true,
      }
      function r:f(a: number, b: string): boolean
         return self.b
      end
      local ok = r:f(3, "abc")
   ]]))

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
      { y = 5, msg = "in assignment: incompatible number of returns: got 0 (), expected 1 (string)" },
      { y = 6, msg = "excess return values, expected 0 (), got 1 (string \"hello\")" },
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
      local function foo()
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
      { msg = "cannot index key 'bla' in type number" }
   }))

   it("catches a bad number of arguments in method", util.check_type_error([[
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
   ]], {
      { y = 10, msg = "incompatible number of arguments" },
      { y = 12, msg = "incompatible number of arguments" },
   }))

   it("does not fail when declaring methods on untyped self (regression test for #427)", util.check([[
      local record Rec<A, B>
        my_method: function(Rec<A, B>, function(A)): Rec<A, B>
      end

      local t = { }

      function t.new<A, B>(): Rec<A, B>
        local self = { }
        function self:my_method(callback: function(A)): Rec<A, B>
          return self
        end
        return self
      end

      return t
   ]]))

   it("does not fail when declaring methods a record where they were already declared (regression test for #463)", util.check([[
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
   ]]))

   it("catches method on unknown variable (regression test for #470)", util.check_type_error([[
      function bla.dosomething()
      end
   ]], {
      { msg = "unknown variable: bla" }
   }))

   it("doesn't hang when comparing method and non-method (regression test for #501)", util.check_type_error([[
      local record Point
      end

      function Point:new(x?: number, y?: number): Point
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

   it("catches inconsistent declarations, allows consistent ones (regression test for #517)", util.check_type_error([[
      local record Rec
          record Plugin
              start: function(self: Rec.Plugin, config: any)
              stop: function(self: Rec.Plugin)
          end
      end

      local b : Rec.Plugin = {}

      -- works
      function b:start(config: any)
      end

      -- fails
      function b:start(config: any, n: number)
      end

      -- works
      function b.start(self: Rec.Plugin, config: any)
      end

      -- works
      function b:stop()
      end

      -- works
      function b.stop(self: Rec.Plugin)
      end
   ]], {
      { y = 15, msg = "type signature of 'start' does not match its declaration in Rec.Plugin: different number of input arguments: " }
   }))

   it("does not cause conflicts with type variables (regression test for #610)", util.check([[
      local MyObj = {}

      function MyObj.do_something<T>(array: {T}): {T}
         return array
      end

      function MyObj.test_fails<T>(array: {T}): {T}
         return MyObj.do_something(array)
      end
   ]]))

   it("inherits type variables from the record definition (regression test for #657)", util.check([[
      local record Test<T>
          value: T
      end

      function Test.new(value: T): Test<T>
          return setmetatable({ value = value }, { __index = Test })
      end

      function Test:print()
          local t: T
          t = self.value
      end
   ]]))

   describe("redeclaration: ", function()
      it("an inconsistent arity in redeclaration produces an error (regression test for #496)", util.check_type_error([[
         local record Y
         end

         function Y:do_x(a: integer, b: integer): integer
             return a + b
         end

         function Y:do_x(a: integer): integer
             return self:do_x(a, 1)
         end
      ]], {
         { y = 8, msg = "type signature of 'do_x' does not match its declaration in Y: different number of input arguments: got 1, expected 2" },
      }))

      it("an inconsistent type in declaration produces an error", util.check_type_error([[
         local record Y
            do_x: function(Y, integer, integer): integer
         end

         function Y:do_x(a: integer, b: string): integer
             return a + math.tointeger(b)
         end
      ]], {
         { y = 5, msg = "type signature of 'do_x' does not match its declaration in Y: argument 2: got string, expected integer" },
      }))

      it("cannot implement a polymorphic method via redeclaration", util.check_type_error([[
         local record Y
            do_x: function(Y, integer, integer): integer
            do_x: function(Y, integer): integer
         end

         function Y:do_x(a: integer, b: string): integer
             return a + math.tointeger(b)
         end
      ]], {
         { y = 6, msg = "type signature does not match declaration: field has multiple function definitions" },
      }))

      it("an inconsistent type in redeclaration produces an error", util.check_type_error([[
         local record Y
         end

         function Y:do_x(a: integer, b: integer): integer
             return a + b
         end

         function Y:do_x(a: integer, b: string): integer
             return a + math.tointeger(b)
         end
      ]], {
         { y = 8, msg = "type signature of 'do_x' does not match its declaration in Y: argument 2: got string, expected integer" },
      }))

      it("a consistent redeclaration produces a warning", util.check_warnings([[
         local record Y
         end

         function Y:do_x(a: integer, b: integer): integer
             return a + b
         end

         function Y:do_x(a: integer, b: integer): integer
             return a - b
         end
      ]], {
         { y = 8, msg = "redeclaration of function 'do_x'" },
      }))

      it("a type signature does not count as a redeclaration", util.check_warnings([[
         local record Y
            do_x: function(Y, integer, integer): integer
         end

         function Y:do_x(a: integer, b: integer): integer
             return a + b
         end
      ]], {}, {}))

      it("a type signature does not count as a redeclaration, but catches inconsistency", util.check_warnings([[
         local record Y
            do_x: function(integer, integer): integer
         end

         function Y:do_x(a: integer, b: integer): integer
             return a + b
         end
      ]], {}, {
         { y = 5, msg = "method and non-method are not the same type" },
      }))

      it("nested records resolve correctly and do not crash (regression test for #615)", util.check([[
         local record Bar
            record Qux
               foo:function(Qux)
            end
         end

         function Bar.Qux:foo()
            print("todo")
         end
      ]]))

      it("regression test for #620", function ()
         util.mock_io(finally, {
            ["base.tl"] = [[
               local record M
                  foo: function(M)
               end

               return M
            ]],
            ["t1.tl"] = [[
               local B = require('base')

               local M: B = {}

               function M:foo()
               end

               return M
            ]],
            ["t2.tl"] = [[
               local B = require('base')

               local M: B = {}

               function M:foo()
               end

               return M
            ]],
            ["top.tl"] = [[
               local B = require('base')

               local function new(cond: boolean): B
                 local C: B
                 if cond then
                   C = require('t1')
                 else
                   C = require('t2')
                 end
               end

               return new
            ]],
         })

         local env = tl.init_env()
         local _, err = tl.process("top.tl", env)

         assert.same(nil, err)
         assert.same(4, #env.loaded_order)
         for _, name in ipairs(env.loaded_order) do
            local result = env.loaded[name]

            assert.same({}, result.warnings)
            assert.same({}, result.syntax_errors)
            assert.same({}, result.type_errors)
         end
      end)
   end)
end)
