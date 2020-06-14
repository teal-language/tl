local tl = require("tl")
local util = require("spec.util")

describe("cast", function()
   it("can be used inside table literals", util.check [[
      local Foo = record
         x: string
      end

      local bla = {
         ovo = {} as Foo
      }
   ]])

   it("can cast to function", util.check [[
      local x = nil as function()
   ]])

   it("can cast to enum", util.check [[
      local Direction = enum
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
   ]])

   it("can be used inside table literals", function()
      local tokens = tl.lex([[
         local flux = {
            tokenize = nil as function()
         }

         -- this should not be parsed as part of the table literal
         local x = 10
         local y = 10
         local z = 10
      ]])
      local _, ast = tl.parse_program(tokens)
      assert.same(4, #ast)
      local errors = tl.type_check(ast, false, "test.lua")
   end)

end)
