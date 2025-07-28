local util = require("spec.util")
local teal = require("teal")

local tl_code = [[
   local foo: string = "hello"
   local planet: integer = 3
]]

describe("TokenList.parse", function()
   it("can find tokens with position in the start", function()
      local compiler = teal.compiler()
      local input = compiler:input(tl_code)
      local token_list = input:lex()
      local token = token_list:get_token_at(1, 4)
      assert.same("local", token)
   end)

   it("can find tokens with position in the middle", function()
      local compiler = teal.compiler()
      local input = compiler:input(tl_code)
      local token_list = input:lex()
      local token = token_list:get_token_at(1, 6)
      assert.same("local", token)
   end)

   it("returns nil in between tokens", function()
      local compiler = teal.compiler()
      local input = compiler:input(tl_code)
      local token_list = input:lex()
      local token = token_list:get_token_at(1, 9)
      assert.same(nil, token)
   end)

   it("returns nil if position has no token", function()
      local compiler = teal.compiler()
      local input = compiler:input(tl_code)
      local token_list = input:lex()
      local token = token_list:get_token_at(1, 2)
      assert.same(nil, token)
   end)
end)
