local tl = require("tl")
local util = require("spec.util")

describe("syntax errors", function()
   it("in a nested required package refer to the correct filename of required file", function ()
      util.mock_io(finally, {
         ["aaa.tl"] = [[
            local bbb = require "bbb"

            function function() end

            local x: string = 1
         ]],
         ["bbb.tl"] = [[
            local bbb = {}

            bbb.y = 2

            if bbb.y end

            return bbb
         ]],
         ["foo.tl"] = [[
            local aaa = require "aaa"
         ]],
      })
      local result, err = tl.process("foo.tl")

      local expected = {
         { filename = "aaa.tl", y = 3 },
         { filename = "bbb.tl", y = 5 },
         { filename = "bbb.tl", y = 7 },
      }
      assert.same(#expected, #result.syntax_errors)
      for i, err in ipairs(result.syntax_errors) do
         assert.match(expected[i].filename, result.syntax_errors[i].filename, 1, true)
         assert.same(expected[i].y, result.syntax_errors[i].y)
      end
   end)
end)
