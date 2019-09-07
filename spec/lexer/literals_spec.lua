local tl = require("tl")

describe("lexer", function()
   it("literals", function()
      local tokens = tl.lex([[
         local x = 0
         local x = 01234
         local x = 12345
         local x = 1
         local x = 0x10
         local x = 0x1a0
         local x = 0xABCD
         local x = "hello"
         local x = {}
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
