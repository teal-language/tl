local util = require("spec.util")

describe("if", function()

   it("accepts a boolean", util.check([[
      local b = true
      if b then
         print(b)
      end
   ]]))

   it("accepts a non-boolean", util.check([[
      local n = 123
      if n then
         print(n)
      end
   ]]))

   it("accepts boolean expressions", util.check([[
      local s = "Hallo, Welt"
      if string.match(s, "world") or s == "Hallo, Welt" then
         print(s)
      end
   ]]))

   it("accepts boolean expressions in elseif", util.check([[
      local s = "Hallo, Welt"
      if 1 == 2 then
         print("wat")
      elseif string.match(s, "world") or s == "Hallo, Welt" then
         print(s)
      end
   ]]))

   it("accepts non-boolean expressions", util.check([[
      local s = "Hello, world"
      if string.match(s, "world") then
         print(s)
      end
   ]]))

   it("accepts non-boolean expressions in elseif", util.check([[
      local s = "Hello, world"
      if 1 == 2 then
         print("wat")
      elseif string.match(s, "world") then
         print(s)
      end
   ]]))

   it("rejects a bad expression", util.check_type_error([[
      local x = 12
      if not x == 123 then
         print(x)
      end
   ]], {
      { msg = "types are not comparable for equality: boolean and integer" }
   }))

   it("rejects a bad expression in else if", util.check_type_error([[
      local x = 12
      if x == 123 then
         print(x)
      elseif not x == 123 then
         print("not " .. x)
      end
   ]], {
      { msg = "types are not comparable for equality: boolean and integer" }
   }))
end)
