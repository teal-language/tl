local tl = require("tl")

describe("%", function()
   it("pass", function()
      local tokens = tl.lex([[
         local x = 1
         local y = 2
         local z = 3
         z = x % y
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("fail", function()
      local tokens = tl.lex([[
         local x = "hello"
         local y = "world"
         local z = "heh"
         z = x % y
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same(1, #errors)
      assert.match("cannot use operator '%' for types string", errors[1].msg, 1, true)
   end)
end)
