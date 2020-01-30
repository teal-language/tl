local tl = require("tl")

describe("syntax errors", function()
   describe("in table declaration", function()
      local tokens = tl.lex([[
         local x = {
            [123] = true,
            true = 123,
            foo = 9
         }
      ]])
      local syntax_errors = {}
      tl.parse_program(tokens, syntax_errors, "foo.tl")
      assert.match("syntax error", syntax_errors[1].msg, 1, true)
      assert.same(3, syntax_errors[1].y)
   end)
end)
