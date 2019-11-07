local tl = require("tl")

describe("global", function()
   describe("undeclared", function()
      it("fails for single assignment", function()
         local tokens = tl.lex([[
            x = 1
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.same("unknown variable: x", errors[1].err)
         assert.same(0, #unknowns)
      end)

      it("fails for multiple assignment", function()
         local tokens = tl.lex([[
            x, y = 1, 2
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.same("unknown variable: x", errors[1].err)
         assert.same("unknown variable: y", errors[2].err)
         assert.same(0, #unknowns)
      end)
   end)

   describe("declared at top level", function()
      it("works for single assignment", function()
         local tokens = tl.lex([[
            x: number = 1
            x = 2
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.same({}, errors)
         assert.same(0, #unknowns)
      end)

      it("works for multiple assignment", function()
         local tokens = tl.lex([[
            x, y: number, string = 1, "hello"
            x = 2
            y = "world"
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.same({}, errors)
         assert.same(#unknowns, 0)
      end)
   end)
   describe("declared not at top level", function()
      it("fails for single assignment", function()
         local tokens = tl.lex([[
            function foo()
               x: number = 1
               x = 2
            end
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.same(2, #errors)
         assert.same(2, #errors)
         assert.same("unknown variable: x", errors[1].err)
         assert.same("unknown variable: x", errors[2].err)
      end)

      it("fails for multiple assignment", function()
         local tokens = tl.lex([[
            function foo()
               x, y: number, string = 1, "hello"
               x = 2
               y = "world"
            end
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         -- FIXME this craps out a lot of weird errors!
         assert.same(7, #errors)
         assert.same(#unknowns, 0)
      end)
   end)

end)
