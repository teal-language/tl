local tl = require("tl")

describe("rawget", function()
   it("reads ", function()
      local tokens = tl.lex([[
         local self = {
            fmt = "hello"
         }
         local str = "hello"
         local a = {str:sub(2, 10)}
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
   it("catches a syntax error", function()
      local tokens = tl.lex([[
         local self = {
            ["fmt"] = {
               x = 123,
               y = 234,
            }
            ["bla"] = {
               z = 345,
               w = 456,
            }
         }
      ]])
      local errors = {}
      tl.parse_program(tokens, errors)
      assert.same("syntax error", errors[1].msg)
   end)
end)
