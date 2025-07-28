local tl = require("teal.api.v2")
local util = require("spec.util")


local function string_trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local dedent = util.dedent

local function map(f, xs)
   local rs = {}
   for i, x in ipairs(xs) do
      rs[i] = f(x)
   end
   return rs
end

describe("long comment", function()
   it("accepts a level 0 long comment", util.check [=[
      --[[
         long comment line 1
         long comment line 2
      ]]
      local foo = 1
   ]=])

   it("accepts a level 1 long comment", util.check([[
      --[=[
         long comment line 1
         long comment line 2
      ]=]
      local foo = 1
   ]]))

   it("accepts a level 1 long comment inside a level 2 long comment", util.check([[
      --[=[
         long comment line 1
         --[==[
           long comment within long comment
         ]==]
         long comment line 2
      ]=]
      local foo = 1
   ]]))

   it("accepts a level 2 long comment inside a level 1 long comment", util.check([[
      --[==[
         long comment line 1
         --[=[
           long comment within long comment
         ]=]
         long comment line 2
      ]==]
      local foo = 1
   ]]))

   it("long comments can contain quotes and double quotes", util.check [=[
      --[[
         ' "
      ]]
      local foo = 1
   ]=])

   it("wrongly nested long comments result in a parse error", util.check_syntax_error([[
      --[==[
         long comment line 1
         --[=[
           long comment within long comment
         ]==]
         long comment line 2
      ]=]
      local foo = 1
   ]], {
      { y = 6, msg = "syntax error" },
      { y = 7, msg = "syntax error" },
   }))

   it("catches unfinished long comment", util.check_syntax_error(
      "print --[[ unfinished long comment\n", {
      { y = 1, msg = "unfinished long comment" },
   }))

   it("preseves long comments in tokens", function()
      local syntax_errors = {}
      local tokens = tl.lex(dedent([[
         --[==[
            This is a multi-line comment
            that spans multiple lines.
         ]==]
         local x = 1
      ]]))
      tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors)
      assert.same(5, #tokens)
      assert.same({"local", "x", "=", "1", "$EOF$"}, map(function(x) return x.tk end, tokens))
      assert.same({
         {text = "--[==[\n   This is a multi-line comment\n   that spans multiple lines.\n]==]", x = 1, y = 1},
      }, tokens[1].comments)
   end)

   it("correctly attaches inline long comments to the leading token", function()
      local syntax_errors = {}
      local tokens = tl.lex(dedent([=[
         local --[[inline long comment]] x --[[another inline comment]] --[[one more inline comment]] = 1
      ]=]))
      tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors)
      assert.same(5, #tokens)
      assert.same({"local", "x", "=", "1", "$EOF$"}, map(function(x) return x.tk end, tokens))
      assert.same({
         {text = "--[[inline long comment]]", x = 7, y = 1},
      }, tokens[2].comments)
      assert.same({
         {text = "--[[another inline comment]]", x = 35, y = 1},
         {text = "--[[one more inline comment]]", x = 64, y = 1}
      }, tokens[3].comments)
   end)

   it("correctly attaches trailling long comments to the leading token", function()
      local syntax_errors = {}
      local tokens = tl.lex(dedent([=[
         local x = 1 --[[
         trailing long comment
         ]]
         local y = 2
      ]=]))
      tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors)
      assert.same(9, #tokens)
      assert.same({"local", "x", "=", "1", "local", "y", "=", "2", "$EOF$"}, map(function(x) return x.tk end, tokens))
      assert.same(nil, tokens[4].comments)
      assert.same({
         {text = "--[[\ntrailing long comment\n]]", x = 13, y = 1}
      }, tokens[5].comments)
   end)

   it("preserves long comments with whitespace between lines", function()
      local syntax_errors = {}
      local tokens = tl.lex(dedent([=[
         --[[
            This is a multi-line comment
            that spans multiple lines.
         ]]

         --[[
            This is another multi-line comment
            that also spans multiple lines.
         ]]
         local x = 1
      ]=]))
      tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors)
      assert.same(5, #tokens)
      assert.same({"local", "x", "=", "1", "$EOF$"}, map(function(x) return x.tk end, tokens))
      assert.same({
         {text = "--[[\n   This is a multi-line comment\n   that spans multiple lines.\n]]", x = 1, y = 1},
         {text = "--[[\n   This is another multi-line comment\n   that also spans multiple lines.\n]]", x = 1, y = 6}
      }, tokens[1].comments)
   end)
end)
