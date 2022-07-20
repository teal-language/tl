local tl = require("tl")
local util = require("spec.util")

describe("syntax errors", function()
   it("invalid use of keyword", util.check_syntax_error([[
      local function do
   ]], {
      { y = 1, msg = "syntax error, expected identifier" },
      { y = 1, msg = "syntax error, expected '('" },
   }))

   it("bad assignment", util.check_syntax_error([[
      123 = 123
   ]], {
      { y = 1, msg = "syntax error" },
   }))

   it("missing expression", util.check_syntax_error([[
      local x =
   ]], {
      { y = 1, msg = "expected an expression" },
   }))

   it("incomplete expression", util.check_syntax_error([[
      return 1 +
   ]], {
      { y = 1, msg = "expected an expression" },
   }))

   it("incomplete enum", util.check_syntax_error([[
      local enum "hello"
   ]], {
      { y = 1, msg = "syntax error" },
   }))

   it("incomplete expression", util.check_syntax_error([[
      local x = -
   ]], {
      { y = 1, msg = "expected an expression" },
   }))

   it("incomplete expression", util.check_syntax_error([[
      local x = (
   ]], {
      { y = 1, msg = "expected an expression" },
   }))

   it("incomplete type definition", util.check_syntax_error([[
      local type argh
   ]], {
      { y = 1, msg = "expected '='" },
   }))

   it("incomplete type definition", util.check_syntax_error([[
      local type argh =
   ]], {
      { y = 1, msg = "expected a type" },
   }))

   it("reports error and resyncs", util.check_syntax_error([[
      repeat until ( type while repeat local )
      local x = 1
   ]], {
      { y = 1, msg = "expected ')'" },
   }))

   it("unclosed list reports expected token", util.check_syntax_error([[
      local t = {}
      for k,v in pairs(t)
         i = i + 1
      end
   ]], {
      { y = 3, msg = "syntax error, expected one of: 'do'" },
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
      { y = 2, msg = "syntax error" },
   }))

   it("malformed string: non escapable character", util.check_syntax_error([[
      print("\s")
   ]], {
      { y = 1, msg = "malformed string" },
   }))

   it("malformed string: bad hex character", util.check_syntax_error([[
      print("\xZZ")
   ]], {
      { y = 1, msg = "malformed string" },
   }))

   it("malformed string: bad UTF-8 character", util.check_syntax_error([[
      print("\u{ZZ}")
   ]], {
      { y = 1, msg = "malformed string" },
   }))

   it("malformed string: bad UTF-8 character", util.check_syntax_error([[
      print("\u{ZZ}")
   ]], {
      { y = 1, msg = "malformed string" },
   }))

   it("malformed number", util.check_syntax_error([[
      print(0eh)
   ]], {
      { y = 1, msg = "malformed number" },
   }))

   it("valid strings: numbered escape", util.check [[
      print("hello\1hello")
      print("hello\12hello")
      print("hello\123hello")
   ]])

   it("malformed string: numbered escape", util.check_syntax_error([[
      print("hello\300hello")
   ]], {
      { y = 1, msg = "malformed string" },
   }))

   it("reports on approximate source of missing 'end'", util.check_syntax_error([[
      local function foo1()
         bar()
      end

      local function foo2()
         if condition then
            if something_missing_here then
               bar()
            something_else()
         end
      end

      local function foo3()
         bar()
      end
   ]], {
      { y = 15, msg = "syntax error, expected 'end' to close construct started at :5:22:" },
   }))

   it("type missing local or global", util.check_syntax_error([[
      type foo = record
         x: number
      end

      -- skips over correctly and continues parsing
      local function foo2()
         bar()
      end
   ]], {
      { y = 1, msg = "types need to be declared with 'local type' or 'global type'" },
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
         ["bbb.tl"] = {
            { filename = "bbb.tl", y = 5 },
            { filename = "bbb.tl", y = 7 },
         },
         ["ccc.tl"] = {
            { filename = "ccc.tl", y = 1 },
         },
      }

      for file, expected in pairs(expected) do
         assert.same(#expected, #(assert(result.env.loaded[file]).syntax_errors))
         for i, err in ipairs(result.env.loaded[file].syntax_errors) do
            assert.match(expected[i].filename, err.filename, 1, true)
            assert.same(expected[i].y, err.y)
         end
      end
   end)
end)
