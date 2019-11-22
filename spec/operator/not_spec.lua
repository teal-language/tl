local tl = require("tl")

local function trim_code(c)
   return c:gsub("^%s*", ""):gsub("\n%s*", "\n"):gsub("%s*$", "")
end

describe("not", function()
   it("ok with any type", function()
      local tokens = tl.lex([[
         local x = 1
         local y = 2
         local z = true
         if not x then
            z = false
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
   it("ok with not not", function()
      local tokens = tl.lex([[
         local x = true
         local z: boolean = not not x
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
   it("not not casts to boolean", function()
      local tokens = tl.lex([[
         local i = 12
         local z: boolean = not not 12
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
   pending("handles precedence of sequential unaries correctly", function()
      local code = [[
         local y = not -a == not -b
         local x = not not a == not not b
      ]]

      local tokens = tl.lex(code)
      local _, ast = tl.parse_program(tokens)
      local output = tl.pretty_print_ast(ast, true)

      assert.same(trim_code(code), trim_code(output))
   end)
   pending("handles complex expression with not", function()
      local code = [[
         if t1.typevar == t2.typevar and
            (not not typevars or
            not not typevars[t1.typevar] == not typevars[t2.typevar]) then
            return true
         end
         if t1.typevar == t2.typevar and
            (not typevars or
            not not typevars[t1.typevar] == not not typevars[t2.typevar]) then
            return true
         end
      ]]

      local tokens = tl.lex(code)
      local _, ast = tl.parse_program(tokens)
      local output = tl.pretty_print_ast(ast, true)

      assert.same(trim_code(code), trim_code(output))
   end)

end)
