local tl = require("teal.api.v2")

local function map(f, xs)
   local rs = {}
   for i, x in ipairs(xs) do
      rs[i] = f(x)
   end
   return rs
end

describe("lexer", function()
   it("equals at the end of a line", function()
      local tokens = tl.lex("local type argh =")
      assert.same({"local", "type", "argh", "=", "$EOF$"}, map(function(x) return x.tk end, tokens))
   end)
end)
