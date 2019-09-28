local tl = require("tl")

describe("forin", function()
   it("with a single variable", function()
      local tokens = tl.lex([[
         local t = { 1, 2, 3 }
         for i in ipairs(t) do
            print(i)
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
   it("with two variables", function()
      local tokens = tl.lex([[
         local t = { 1, 2, 3 }
         for i, v in ipairs(t) do
            print(i, v)
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
   it("with an explicit iterator", function()
      local tokens = tl.lex([[
         local function iter(t): number
         end
         local t = { 1, 2, 3 }
         for i in iter, t do
            print(i + 1)
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
