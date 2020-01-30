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

            -- local type
            local Box = record
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
      assert.same(2, #result.type_errors)
      assert.match("expected Box", result.type_errors[1].msg)
      assert.match("unknown type Box", result.type_errors[2].msg)
      assert.same(0, #result.unknowns)

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

   pending("exports scoped types", function ()
      -- ok
      util.mock_io(finally, {
         ["box.tl"] = [[
            local box = {}

            -- scoped type
            box.Box = record
               x: number
               y: number
               w: number
               h: number
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

      assert.same({}, result)
      assert.same(0, #result.syntax_errors)
      assert.same(0, #result.type_errors)
      assert.same(0, #result.unknowns)
   end)

end)
