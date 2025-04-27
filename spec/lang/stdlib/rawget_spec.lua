local util = require("spec.util")

describe("rawget", function()
   it("reads ", util.check([[
      local self = {
         fmt = "hello"
      }
      local str = "hello"
      local a = {str:sub(2, 10)}
   ]]))

   it("errors on invalid indices", util.check_type_error([[
      local dat = { test = "1", that = 2 }
      local one: string = rawget(dat, "test")
      local f1 = rawget(dat, "t")
      local two: integer = rawget(dat, "that")
   ]], {
      {
         msg = "invalid key 't'",
         y = 3,
      }
   }))
end)
