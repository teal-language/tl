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
         assert.match("in assignment: got number", errors[1].err, 1, true)
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
         assert.match("in assignment: got number", errors[1].err, 1, true)
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
            local errors = tl.type_check(ast)
            assert.match("x: got number, expected string", errors[1].err, 1, true)
            assert.match("y: got string \"a\", expected number", errors[2].err, 1, true)
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
            assert.match("in assignment: got number", errors[1].err, 1, true)
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
   end)
end)
