local util = require("spec.util")

describe("if", function()
   util.init(it)

   util.check("accepts a boolean", [[
      local b = true
      if b then
         print(b)
      end
   ]])

   util.check("accepts a non-boolean", [[
      local n = 123
      if n then
         print(n)
      end
   ]])

   util.check("accepts boolean expressions", [[
      local s = "Hallo, Welt"
      if string.match(s, "world") or s == "Hallo, Welt" then
         print(s)
      end
   ]])

   util.check("accepts boolean expressions in elseif", [[
      local s = "Hallo, Welt"
      if 1 == 2 then
         print("wat")
      elseif string.match(s, "world") or s == "Hallo, Welt" then
         print(s)
      end
   ]])

   util.check("accepts non-boolean expressions", [[
      local s = "Hello, world"
      if string.match(s, "world") then
         print(s)
      end
   ]])

   util.check("accepts non-boolean expressions in elseif", [[
      local s = "Hello, world"
      if 1 == 2 then
         print("wat")
      elseif string.match(s, "world") then
         print(s)
      end
   ]])

   util.check_type_error("rejects a bad expression", [[
      local x = 12
      if not x == 123 then
         print(x)
      end
   ]], {
      { msg = "types are not comparable for equality: boolean and number" }
   })

   util.check_type_error("rejects a bad expression in else if", [[
      local x = 12
      if x == 123 then
         print(x)
      if not x == 123 then
         print("not " .. x)
      end
   ]], {
      { msg = "types are not comparable for equality: boolean and number" }
   })
end)
