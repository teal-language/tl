local tl = require("tl")

describe("local", function()
   describe("declaration", function()
      it("basic inference sets types", function()
         -- fail
         local tokens = tl.lex([[
            local x = 1
            local y = 2
            local z: table
            z = x + y
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.match("in assignment: got number", errors[1].msg, 1, true)
         -- pass
         local tokens = tl.lex([[
            local x = 1
            local y = 2
            local z: number
            z = x + y
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.same({}, errors)
      end)
   end)

   describe("multiple declaration", function()
      it("basic inference catches errors", function()
         local tokens = tl.lex([[
            local x, y = 1, 2
            local z: table
            z = x + y
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.match("in assignment: got number", errors[1].msg, 1, true)
      end)

      it("basic inference sets types", function()
         -- pass
         local tokens = tl.lex([[
            local x, y = 1, 2
            local z: number
            z = x + y
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.same({}, errors)
      end)

      describe("with types", function()
         it("checks values", function()
            -- fail
            local tokens = tl.lex([[
               local x, y: string, number = 1, "a"
               local z
               z = x + string.byte(y)
            ]])
            local _, ast = tl.parse_program(tokens)
            local errors = tl.type_check(ast, nil, "bla.tl")
            assert.match("x: got number, expected string", errors[1].msg, 1, true)
            assert.match("y: got string \"a\", expected number", errors[2].msg, 1, true)
         end)

         it("propagates correct type", function()
            -- fail
            local tokens = tl.lex([[
               local x, y: number, string = 1, "a"
               local z: table
               z = x + string.byte(y)
            ]])
            local _, ast = tl.parse_program(tokens)
            local errors = tl.type_check(ast)
            assert.match("in assignment: got number", errors[1].msg, 1, true)
         end)

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
         local errors, unknowns = tl.type_check(ast, true)
         assert.same({}, errors)
         assert.same(1, #unknowns)
         assert.same("b", unknowns[1].msg)
      end)
   end)
end)
