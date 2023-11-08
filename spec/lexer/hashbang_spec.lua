local tl = require("tl")

local function map(f, xs)
   local rs = {}
   for i, x in ipairs(xs) do
      rs[i] = f(x)
   end
   return rs
end

describe("lexer", function()
   it("skips hashbang at the beginning of a file", function()
      local syntax_errors = {}
      local tokens = tl.lex("#!/usr/bin/env lua\nlocal x = 1")
      assert.same({"#!/usr/bin/env lua\n", "local", "x", "=", "1", "$EOF$"}, map(function(x) return x.tk end, tokens))

      tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors)
   end)
end)
