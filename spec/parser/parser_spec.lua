local tl = require("tl")

describe("parser", function()
   it("accepts an empty file (regression test for #43)", function ()
      local tokens = tl.lex("")
      local syntax_errors = {}
      local _, ast = tl.parse_program(tokens, syntax_errors, "foo.tl")
      assert.same({}, syntax_errors)
      assert.same({
         kind = "statements",
         tk = "$EOF$",
         x = 1,
         y = 1,
      }, ast)
   end)
end)
