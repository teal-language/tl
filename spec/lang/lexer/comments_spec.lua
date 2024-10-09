local tl = require("tl")

local function map(f, xs)
   local rs = {}
   for i, x in ipairs(xs) do
      rs[i] = f(x)
   end
   return rs
end

describe("lexer", function()
   it("line comment at the end of a line", function()
      local syntax_errors = {}
      local tokens = tl.lex("--\nlocal x = 1")
      tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors)
      assert.same(5, #tokens)
      assert.same({"local", "x", "=", "1", "$EOF$"}, map(function(x) return x.tk end, tokens))
   end)
end)
