local util = require("spec.util")

describe("%", function()
   it("pass", util.check([[
      local x = 1
      local y = 2
      local z = 3
      z = x % y
   ]]))

   it("fail", util.check_type_error([[
      local x = "hello"
      local y = "world"
      local z = "heh"
      z = x % y
   ]], {
      { msg = "cannot use operator '%' for types string" }
   }))
end)
