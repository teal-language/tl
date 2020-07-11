local tl = require("tl")
local util = require("spec.util")

describe("local", function()
   describe("declaration", function()
      it("basic inference sets types, fail", util.check_type_error([[
         local x = 1
         local y = 2
         local z: table
         z = x + y
      ]], {
         { msg = "in assignment: got number" },
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
         { msg = "in assignment: got number" },
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
            { msg = "x: got number, expected string" },
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

         it("uses correct type", function()
            -- pass
            local tokens = tl.lex([[
               local x, y: number, string = 1, "a"
               local z: number
               z = x + string.byte(y)
            ]])
            local _, ast = tl.parse_program(tokens)
            local errors = tl.type_check(ast)
            assert.same({}, errors)
         end)
      end)

      it("reports unset and untyped values as errors in tl mode", function()
         local tokens = tl.lex([[
            local T = record
               x: number
               y: number
            end

            function T:returnsTwo(): number, number
               return self.x, self.y
            end

            function T:method()
               local a, b = self.returnsTwo and self:returnsTwo()
            end
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.same(1, #errors)
      end)

      it("reports unset values as unknown in Lua mode", function()
         local tokens = tl.lex([[
            local T = record
               x: number
               y: number
            end

            function T:returnsTwo(): number, number
               return self.x, self.y
            end

            function T:method()
               local a, b = self.returnsTwo and self:returnsTwo()
            end
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast, { lax = true })
         assert.same({}, errors)
         assert.same(1, #unknowns)
         assert.same("b", unknowns[1].msg)
      end)
   end)
end)
