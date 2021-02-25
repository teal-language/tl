local tl = require("tl")

describe("tl.get_token_at", function()
   it("should find the token at the given position", function()
      local tks = assert(tl.lex([==[
         local x = 10
         local y --[[ :) ]] = 12
         global function foo()
         end
      ]==]))
      assert(tl.get_token_at(tks, 1, 10).tk == "local")
      assert(tl.get_token_at(tks, 1, 13).tk == "local")
      assert(tl.get_token_at(tks, 1, 20).tk == "10")
      assert(tl.get_token_at(tks, 3, 13).tk == "global")
   end)
   it("should return nil if there is whitespace at the location", function()
      local tks = assert(tl.lex([[
      local x: number

      local y: number
      ]]))
      assert(tl.get_token_at(tks, 2, 1) == nil)
      assert(tl.get_token_at(tks, 1, 15) == nil)
   end)
end)
