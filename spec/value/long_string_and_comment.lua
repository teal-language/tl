local tl = require("tl")

describe("nested long strings and comments", function()
   it("long comment within long string", function()
      local tokens = tl.lex([=[
         local foo = [[
               long string line 1
               --[[
                  long comment within long string
               ]]
               long string line 2
            ]]
      ]=])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("long string within long comment", function()
      local tokens = tl.lex([=[
         --[[
            long comment line 1
            [[
               long string within long comment
            ]]
            long comment line 2
         ]]
         local foo = 1
      ]=])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
