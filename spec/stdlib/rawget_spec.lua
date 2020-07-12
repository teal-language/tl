local util = require("spec.util")

describe("rawget", function()
   it("reads ", util.check [[
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
      { msg = "syntax error" },
      { msg = "syntax error" },
      { msg = "syntax error" },
   }))
end)
