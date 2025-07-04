local tl = require("teal.api.v2")
local util = require("spec.util")

local function map(f, xs)
   local rs = {}
   for i, x in ipairs(xs) do
      rs[i] = f(x)
   end
   return rs
end

local dedent = util.dedent

describe("lexer", function()
   it("line comment at the end of a line", function()
      local syntax_errors = {}
      local tokens = tl.lex("--\nlocal x = 1")
      tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors)
      assert.same(5, #tokens)
      assert.same({"local", "x", "=", "1", "$EOF$"}, map(function(x) return x.tk end, tokens))
   end)

   it("preserves single line comments", function()
      local syntax_errors = {}
      local tokens = tl.lex(dedent([[
         -- This is a single line comment
         local x = 1
      ]]))
      tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors)
      assert.same(5, #tokens)
      assert.same({"local", "x", "=", "1", "$EOF$"}, map(function(x) return x.tk end, tokens))
      assert.same({
         {text = "-- This is a single line comment", x = 1, y = 1}
      }, tokens[1].comments)
   end)

   it("preserves multi-line comments", function()
      local syntax_errors = {}
      local tokens = tl.lex(dedent([[
         -- This is a multi-line comment
         -- that spans multiple lines.
         local x = 1
      ]]))
      tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors)
      assert.same(5, #tokens)
      assert.same({"local", "x", "=", "1", "$EOF$"}, map(function(x) return x.tk end, tokens))
      assert.same({
         {text = "-- This is a multi-line comment", x = 1, y = 1},
         {text = "-- that spans multiple lines.", x = 1, y = 2}
      }, tokens[1].comments)
   end)

   it("always attaches comments to the leading token", function()
      local syntax_errors = {}
      local tokens = tl.lex(dedent([[
         local x = 1 -- trailing comment
         local y = 2
      ]]))
      tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors)
      assert.same(9, #tokens)
      assert.same({"local", "x", "=", "1", "local", "y", "=", "2", "$EOF$"}, map(function(x) return x.tk end, tokens))
      assert.same(nil, tokens[4].comments)
      assert.same({
         {text = "-- trailing comment", x = 13, y = 1}
      }, tokens[5].comments)
   end)

   it("preserves multi-line comments with whitespace between lines", function()
      local syntax_errors = {}
      local tokens = tl.lex(dedent([[
         -- This is a multi-line comment

         -- that spans multiple lines.
         -- It has some whitespace in between.
         local x = 1
      ]]))
      tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors)
      assert.same(5, #tokens)
      assert.same({"local", "x", "=", "1", "$EOF$"}, map(function(x) return x.tk end, tokens))
      assert.same({
         {text = "-- This is a multi-line comment", x = 1, y = 1},
         {text = "-- that spans multiple lines.", x = 1, y = 3},
         {text = "-- It has some whitespace in between.", x = 1, y = 4}
      }, tokens[1].comments)
   end)

   it("attaches comments to correct tokens in complex statements", function()
      local syntax_errors = {}

      local tokens = tl.lex(dedent([[
         -- comment before local
         local
         -- comment before function
         function
         -- comment before function name
         foo(): number
           return 1
         end
         -- comment after function
      ]]))

      tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors)
      assert.same(11, #tokens)
      assert.same({"local", "function", "foo", "(", ")", ":", "number", "return", "1", "end", "$EOF$"}, map(function(x) return x.tk end, tokens))
      assert.same({
         {text = "-- comment before local", x = 1, y = 1},
      }, tokens[1].comments)
      assert.same({
         {text = "-- comment before function", x = 1, y = 3},
      }, tokens[2].comments)
      assert.same({
         {text = "-- comment before function name", x = 1, y = 5},
      }, tokens[3].comments)
      assert.same({
         {text = "-- comment after function", x = 1, y = 9},
      }, tokens[11].comments)
   end)

end)
