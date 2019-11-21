local tl = require("tl")

describe("record method call", function()
   it("method call on an expression", function()
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
         (r):f(3, "abc")
      ]])
      local errs = {}
      local _, ast = tl.parse_program(tokens, errs)
      assert.same({}, errs)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("nested record method calls", function()
      local tokens = tl.lex([[
         local r = {
            x = 2,
            b = true,
         }
         function r:f(b: string): string
            if self.b then
               return #b == 3 and "yes" or "no"
            end
            return "what"
         end
         function foo()
            r:f(r:f("hello"))
         end
      ]])
      local errs = {}
      local _, ast = tl.parse_program(tokens, errs)
      assert.same({}, errs)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   describe("lax", function()
      it("nested record method calls", function()
         local tokens = tl.lex([[
            local SW = {}

            function SW:write(arg1,arg2,...)
            end

            function SW:writef(fmt,...)
               self:write(fmt:format(...))
            end
         ]])
         local errs = {}
         local _, ast = tl.parse_program(tokens, errs)
         assert.same({}, errs)
         local errors = tl.type_check(ast, true)
         assert.same({}, errors)
      end)
   end)

end)
