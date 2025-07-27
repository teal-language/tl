local util = require("spec.util")
local teal = require("teal")

local function assert_tokens(token_list, tokens)
   assert.same(#token_list.tokens, #tokens)

   for i, t in ipairs(tokens) do
      assert.same(token_list.tokens[i].y, t.y)
      assert.same(token_list.tokens[i].tk, t.tk)
      assert.same(token_list.tokens[i].kind, t.kind)
   end
end

describe("Input.lex", function()
   it("can lex Teal code", function()
      local tl_code = [[
         local foo: string = "hello"
         local planet: integer = 3
      ]]

      local compiler = teal.compiler()
      local input = compiler:input(tl_code)
      local token_list, err = input:lex()

      local tokens = {
         { y = 1, tk = "local", kind = "keyword" },
         { y = 1, tk = "foo", kind = "identifier" },
         { y = 1, tk = ":", kind = ":" },
         { y = 1, tk = "string", kind = "identifier" },
         { y = 1, tk = "=", kind = "op" },
         { y = 1, tk = '"hello"', kind = "string" },
         { y = 2, tk = "local", kind = "keyword" },
         { y = 2, tk = "planet", kind = "identifier" },
         { y = 2, tk = ":", kind = ":" },
         { y = 2, tk = "integer", kind = "identifier" },
         { y = 2, tk = "=", kind = "op" },
         { y = 2, tk = "3", kind = "integer" },
         { y = 3, tk = "$EOF$", kind = "$EOF$" },
      }
      assert_tokens(token_list, tokens)
      assert.same(0, #err)
   end)

   it("can report syntax errors", function()
      local tl_code = [[
         2.e + 1
      ]]

      local compiler = teal.compiler()
      local input = compiler:input(tl_code)
      local token_list, err = input:lex()

      local tokens = {
         { y = 1, tk = "2.e", kind = "$ERR$" },
         { y = 1, tk = "+", kind = "op" },
         { y = 1, tk = "1", kind = "integer" },
         { y = 2, tk = "$EOF$", kind = "$EOF$" },
      }
      assert_tokens(token_list, tokens)
      assert.is_table(err)
      assert.same(1, #err)
      assert.same(err[1].msg, "malformed number")
      assert.same(err[1].y, 1)
      assert.same(err[1].x, 10)
   end)
end)
