local tl = require("tl")

describe("local", function()
   it("declaration", function()
      -- fail
      local tokens = tl.lex([[
         local x = 1
         local y = 2
         local z
         z = x + y
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("mismatch: z", errors[1].err, 1, true)
      local tokens = tl.lex([[
         local x = 1
         local y = 2
         local z: table
         z = x + y
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("mismatch: z", errors[1].err, 1, true)
      -- pass
      local tokens = tl.lex([[
         local x = 1
         local y = 2
         local z: number
         z = x + y
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
