local util = require("spec.util")

describe("array declarations", function()
   it("can be simple", util.check([[
      local x = {1, 2, 3}
      x[2] = 10
   ]]))

   it("can be sparse", util.check([[
      local x = {
         [2] = 2,
         [10] = 3,
      }
      print(x[10])
   ]]))

   it("catches redeclaration of literal keys", util.check_type_error([[
      local x = {
         [2] = 2,
         [10] = 3,
         [10] = 4,
      }
      print(x[10])
   ]], {
      { msg = "redeclared key 10" }
   }))

   it("skips over nils when defining the type (regression test for #268)", util.check([[
      local x: {number} = {nil, 5}
   ]]))

   it("can be declared as a nominal type", util.check([[
      local type Booleans = {boolean}
      local bs: Booleans = {
         true, false, [12] = true,
      }
   ]]))

   it("can be indirect", util.check([[
      local RED = 1
      local BLUE = 2
      local x = {
         [RED] = 2,
         [BLUE] = 3,
      }
      print(x[RED])
   ]]))

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

   it("explicit number indices work with array-records", util.check([[
      local x = {
         [1] = 2,
         [2] = 3,
         GREEN = 4,
      }
      print(x.GREEN)
   ]]))

   it("indirect works with array-records", util.check([[
      local RED = 1
      local BLUE = 2
      local x = {
         [RED] = 2,
         [BLUE] = 3,
         GREEN = 4,
      }
      print(x[RED])
   ]]))
end)
