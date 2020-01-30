local tl = require("tl")

math.randomseed(os.time())

describe("semicolon", function()

   it("is ignored", function()
      local syntax_errors = {}
      local tokens = tl.lex(";local x = 0; local z = 12;;;")
      local _, ast = tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
