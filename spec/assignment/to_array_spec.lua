local tl = require("tl")
local util = require("spec.util")

describe("assignment to array", function()
   it("check array type", util.check_type_error([[
      local a: {string}
      a = 100
      a = {"a", 100}
   ]], {
      { y = 2, msg = "got number, expected {string}" },
      { y = 3, msg = "got {string | number} (from {1: string, 2: number}), expected {string}" },
   }))

   it("check expansion of expression inside array", util.check_type_error([[
      local function f(): string, number
         return "hello", 123
      end
      local a: {string}
      a = { f() }
   ]], {
      { y = 5, msg = "in assignment: got {string | number} (from {1: string, 2: number}), expected {string}" },
   }))

   it("accept expression", util.check [[
      local self = {
         fmt = "hello"
      }
      local str = "hello"
      local a = {str:sub(2, 10)}
   ]])

   it("catches a syntax error", util.check_syntax_error([[
      local self = {
         ["fmt"] = {
            x = 123,
            y = 234,
         }
         ["bla"] = {
            z = 345,
            w = 456,
         }
      }
   ]], {
      { y = 6, msg = "syntax error" },
      { y = 6, msg = "syntax error" },
      { y = 8, msg = "syntax error" },
   }))
end)
