local tl = require("tl")
local util = require("spec.util")

describe("record method", function()
   it("valid declaration", function()
      local tokens = tl.lex([[
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
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("valid declaration with type variables", function()
      local tokens = tl.lex([[
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
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("nested declaration", function()
      local tokens = tl.lex([[
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
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("nested declaration in {}", function()
      local tokens = tl.lex([[
         local r = {
            z = {},
         }
         function r.z:f(a: number, b: string): boolean
            return true
         end
         local ok = r.z:f(3, "abc")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("deep nested declaration", function()
      local tokens = tl.lex([[
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
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("resolves self", function()
      local tokens = tl.lex([[
         local r = {
            x = 2,
            b = true,
         }
         function r:f(a: number, b: string): boolean
            return self.invalid
         end
         local ok = r:f(3, "abc")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("invalid key 'invalid' in record 'self'", errors[1].msg, 1, true)
   end)

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

   it("catches invocation style", function()
      local tokens = tl.lex([[
         local r = {
            x = 2,
            b = true,
         }
         function r:f(a: number, b: string): boolean
            return self.b
         end
         local ok = r.f(3, "abc")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("invoked method as a regular function", errors[1].msg, 1, true)
   end)

   it("allows invocation when properly used with '.'", function()
      local tokens = tl.lex([[
         local r = {
            x = 2,
            b = true,
         }
         function r:f(a: number, b: string): boolean
            return self.b
         end
         local ok = r.f(r, 3, "abc")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("allows invocation when properly used with ':'", function()
      local tokens = tl.lex([[
         local r = {
            x = 2,
            b = true,
         }
         function r:f(a: number, b: string): boolean
            return self.b
         end
         local ok = r:f(3, "abc")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)


   it("allows colon notation in methods", function()
      util.mock_io(finally, {
         ["foo.tl"] = [[
            local Point = record
               x: number
               y: number
               __index: Point
            end

            Point.__index = Point as Point

            function Point.new(x: number, y: number): Point
               local self: Point = setmetatable({}, Point as METATABLE)

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

   it("allows functions declared on method tables (#27)", function()
      util.mock_io(finally, {
         ["foo.tl"] = [[
            local Point = record
               x: number
               y: number
            end

            local PointMetatable: METATABLE = {
               __index = Point
            }

            function Point.new(x: number, y: number): Point
               local self = setmetatable({}, PointMetatable) as Point

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

end)
