local tl = require("tl")

describe("assignment to multiple variables", function()
   it("from a function call", function()
      local tokens = tl.lex([[
         local function foo(): boolean, string
            return true, "yeah!"
         end
         local a, b = foo()
         print(b .. " right!")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("reports unsufficient rvalues as an error, simple", function()
      local tokens = tl.lex([[
         local a, b = 1, 2
         a, b = 3
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors, unknowns = tl.type_check(ast)
      assert.same("variable is not being assigned a value", errors[1].err)
   end)

   it("reports unsufficient rvalues as an error, tricky", function()
      local tokens = tl.lex([[
         local T = record
            x: number
            y: number
         end

         function T:returnsTwo(): number, number
            return self.x, self.y
         end

         function T:method()
            local a, b: number, number
            a, b = self.returnsTwo and self:returnsTwo()
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors, unknowns = tl.type_check(ast)
      assert.same("variable is not being assigned a value", errors[1].err)
   end)
end)
