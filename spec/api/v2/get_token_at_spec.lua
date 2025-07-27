local tl = require("teal.api.v2")

describe("tl.get_token_at", function()
   it("should find the token at the given position", function()
      local tks = assert(tl.lex([==[
         local x = 10
         local y --[[ :) ]] = 12
         global function foo()
         end
      ]==]))
      local function assert_range(y, x_start, x_end, str)
         for x = x_start, x_end do
            assert.are.equal(
               str,
               assert.not_nil(
                  tl.get_token_at(tks, y, x),
                  "No token found at " .. y .. ":" .. x .. " (expected " .. str .. ")"
               )
            )
         end
      end
      assert_range(1, 10, 14, "local")
      assert_range(1, 20, 21, "10")
      assert_range(3, 10, 15, "global")
      assert_range(4, 10, 12, "end")
   end)
   it("should return nil if there is whitespace at the location", function()
      local tks = assert(tl.lex([[
      local x: number

      local    y:   number
      ]]))
      local function assert_range_nil(y, x_start, x_end)
         for x = x_start, x_end do
            assert.is["nil"](tl.get_token_at(tks, y, x))
         end
      end
      assert_range_nil(1, 1, 6)
      assert_range_nil(1, 12, 12)
      assert_range_nil(1, 15, 15)

      assert_range_nil(2, 1, 6)
      assert_range_nil(2, 12, 15)
      assert_range_nil(2, 18, 20)
   end)
end)
