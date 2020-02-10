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

   it("accepts 'return;' (regression test for #52)", function ()
      local tokens = tl.lex("return;")
      local syntax_errors = {}
      local _, ast = tl.parse_program(tokens, syntax_errors, "foo.tl")
      assert.same({}, syntax_errors)
      assert.same(1, #ast)
      assert.same("return", ast[1].kind)
   end)
end)
