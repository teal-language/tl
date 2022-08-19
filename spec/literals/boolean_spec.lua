local util = require("spec.util")

describe("boolean literals", function()
   it("true is truthy", util.check [[
      local x: number | string
      if x is number and true then
         print(x * 2)
      else
         print(x .. "!")
      end
   ]])

   it("false is not truthy", util.check_type_error([[
      local x: number | string
      if x is number and false then
         print(x * 2)
      else
         print(x .. "!")
      end
   ]], {
      { y = 5, "cannot use operator for types number | string and string" }
   }))
end)
