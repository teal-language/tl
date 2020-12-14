local tl = require("tl")
local util = require("spec.util")

describe("syntax errors", function()
   it("missing expression", util.check_syntax_error([[
      local x =
   ]], {
      { y = 1, msg = "expected an expression" },
   }))

   it("in enum", util.check_syntax_error([[
      local type Direction = enum
         "north",
         "south",
         "east",
         "west"
      end
   ]], {
      { y = 2, msg = "syntax error, expected string" },
      { y = 3, msg = "syntax error, expected string" },
      { y = 4, msg = "syntax error, expected string" },
   }))

   it("unexpected comma", util.check_syntax_error([[
      print(1),
      print(2),
      print(3)
      print(4)
   ]], {
      { y = 1, msg = "syntax error" },
   }))

   it("malformed string: non escapable character", util.check_syntax_error([[
      print("\s")
   ]], {
      { y = 1, msg = "syntax error" },
   }))

   it("malformed string: bad hex character", util.check_syntax_error([[
      print("\xZZ")
   ]], {
      { y = 1, msg = "syntax error" },
   }))

   it("malformed string: bad UTF-8 character", util.check_syntax_error([[
      print("\u{ZZ}")
   ]], {
      { y = 1, msg = "syntax error" },
   }))

   it("malformed string: bad UTF-8 character", util.check_syntax_error([[
      print("\")
   ]], {
      { y = 1, msg = "syntax error" },
   }))

   it("valid strings: numbered escape", util.check [[
      print("hello\1hello")
      print("hello\12hello")
      print("hello\123hello")
   ]])

   it("malformed string: numbered escape", util.check_syntax_error([[
      print("hello\300hello")
   ]], {
      { y = 1, msg = "syntax error" },
   }))

   it("in a nested required package refer to the correct filename of required file", function ()
      util.mock_io(finally, {
         ["aaa.tl"] = [[
            local bbb = require "bbb"

            local x: string = 1
         ]],
         ["ccc.tl"] = [[
            function function() end
         ]],
         ["bbb.tl"] = [[
            local bbb = {}

            bbb.y = 2

            if bbb.y end

            return bbb
         ]],
         ["foo.tl"] = [[
            local aaa = require "aaa"
            local ccc = require "ccc"
         ]],
      })
      local result, err = tl.process("foo.tl")

      local expected = {
         { filename = "bbb.tl", y = 5 },
         { filename = "bbb.tl", y = 7 },
         { filename = "ccc.tl", y = 1 },
      }
      assert.same(#expected, #result.syntax_errors)
      for i, err in ipairs(result.syntax_errors) do
         assert.match(expected[i].filename, result.syntax_errors[i].filename, 1, true)
         assert.same(expected[i].y, result.syntax_errors[i].y)
      end
   end)
end)
