local util = require("spec.util")

describe("cast", function()
   it("can be used inside table literals", util.check([[
      local type Foo = record
         x: string
      end

      local bla = {
         ovo = {} as Foo
      }
   ]]))

   it("can cast vararg returns as tuples", util.check([[
      local s = { 1234, "ola", 4566 }
      local a, b, c = table.unpack(s) as (number, string, number)

      print(a + 1)
      print(b:upper())
      print(c + 1)
   ]]))

   it("can cast to function", util.check([[
      local x = nil as function()
   ]]))

   it("can cast to enum", util.check([[
      local type Direction = enum
         "north"
         "south"
         "east"
         "west"
      end

      local function go(d: Direction)
         print("I am going " .. d .. "!") -- d works as a string!
      end

      -- a cast can force an invalid value into an enum type
      go("up" as Direction)
   ]]))

   it("can be used inside table literals", util.check([[
      local flux = {
         tokenize = nil as function()
      }

      -- this should not be parsed as part of the table literal
      local x = 10
      local y = 10
      local z = 10
   ]]))

   it("should not crash on unexpected eof (#345)", util.check_syntax_error([[
      local x = 1 as
   ]], {
      { msg = "expected a type" }
   }))

   it("should not crash when casting an empty expression (#345)", util.check_syntax_error([[
      local x = () as string
   ]], {
      { msg = "syntax error" },
      { msg = "syntax error, expected ')'" },
      { msg = "syntax error" },
   }))
end)
