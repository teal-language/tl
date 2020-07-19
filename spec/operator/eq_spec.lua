local util = require("spec.util")

describe("==", function()
   it("passes with the same type", util.check [[
      local x = "hello"
      if x == "hello" then
         print("hello!")
      end
   ]])

   it("fails with different types", util.check_type_error([[
      local x = "hello"
      if not x == "hello" then
         print("unreachable")
      end
   ]], {
      { msg = "not comparable for equality" }
   }))

   it("fails comparing enum to invalid literal string", util.check_type_error([[
      local type MyEnum = enum
         "foo"
         "bar"
      end
      local data: MyEnum = "foo"
      if data == "hello" then
         print("unreachable")
      end
   ]], {
      { msg = "not comparable for equality" }
   }))
end)
