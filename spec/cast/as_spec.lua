local tl = require("tl")

describe("cast", function()
   it("can be used inside table literals", function()
      local tokens = tl.lex([[
         local Foo = record
            x: string
         end

         local bla = {
            ovo = {} as Foo
         }
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast, false, "test.lua")
      assert.same({}, errors)
   end)

   it("can cast to function", function()
      local tokens = tl.lex([[
         local x = nil as function()
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast, false, "test.lua")
      assert.same({}, errors)
   end)

   it("can be used inside table literals", function()
      local tokens = tl.lex([[
         local flux = {
            tokenize = nil as function()
         }

         -- this should not be parsed as part of the table literal
         local x = 10
         local y = 10
         local z = 10
      ]])
      local _, ast = tl.parse_program(tokens)
      assert.same(4, #ast)
      local errors = tl.type_check(ast, false, "test.lua")
   end)

end)
