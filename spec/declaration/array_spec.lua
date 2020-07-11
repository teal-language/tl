local util = require("spec.util")

describe("array declarations", function()
   it("can be simple", util.check [[
      local x = {1, 2, 3}
      x[2] = 10
   ]])

   it("can be sparse", util.check [[
      local x = {
         [2] = 2,
         [10] = 3,
      }
      print(x[10])
   ]])

   it("can be indirect", util.check [[
      local RED = 1
      local BLUE = 2
      local x = {
         [RED] = 2,
         [BLUE] = 3,
      }
      print(x[RED])
   ]])

   it("indirect only works for numeric keys", util.check_type_error([[
      local RED = 1
      local BLUE = 2
      local GREEN: string = (function():string return "hello" end)()
      local x = {
         [RED] = 2,
         [BLUE] = 3,
         [GREEN] = 4,
      }
      print(x[RED])
   ]], {
      { msg = "cannot determine type of table literal" },
   }))

   it("indirect works array-records", util.check [[
      local RED = 1
      local BLUE = 2
      local x = {
         [RED] = 2,
         [BLUE] = 3,
         GREEN = 4,
      }
      print(x[RED])
   ]])
end)
