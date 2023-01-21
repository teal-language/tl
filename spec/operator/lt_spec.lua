local util = require("spec.util")

describe("<", function()
   it("ok", util.check([[
      local x = 1
      local y = 2
      local z = true
      if x < y then
         z = false
      end
   ]]))

   it("fail", util.check_type_error([[
      local x = 1
      local y = "hello"
      local z = true
      if x < y then
         z = false
      end
   ]], {
      { msg = "cannot use operator '<' for types integer and string" }
   }))

   it("fails with not gotcha", util.check_type_error([[
      local x = 10
      local y = 20
      if not x < y then
         print("wat")
      end
   ]], {
      { msg = "cannot use operator '<' for types boolean and integer" }
   }))
end)
