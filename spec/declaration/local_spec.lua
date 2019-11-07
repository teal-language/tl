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
   it("multiple declaration", function()
      -- fail
      local tokens = tl.lex([[
         local x, y = 1, 2
         local z
         z = x + y
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("mismatch: z", errors[1].err, 1, true)
      local tokens = tl.lex([[
         local x, y = 1, 2
         local z: table
         z = x + y
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("mismatch: z", errors[1].err, 1, true)
      -- pass
      local tokens = tl.lex([[
         local x, y = 1, 2
         local z: number
         z = x + y
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
   it("multiple declaration with types", function()
      -- fail
      local tokens = tl.lex([[
         local x, y: string, number = 1, "a"
         local z
         z = x + string.byte(y)
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("x: number is not a string", errors[1].err, 1, true)
      assert.match("y: string is not a number", errors[2].err, 1, true)
      -- fail
      local tokens = tl.lex([[
         local x, y: number, string = 1, "a"
         local z
         z = x + string.byte(y)
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("mismatch: z", errors[1].err, 1, true)
      local tokens = tl.lex([[
         local x, y: number, string = 1, "a"
         local z: table
         z = x + string.byte(y)
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("mismatch: z", errors[1].err, 1, true)
      -- pass
      local tokens = tl.lex([[
         local x, y: number, string = 1, "a"
         local z: number
         z = x + string.byte(y)
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
