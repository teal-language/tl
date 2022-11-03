
local util = require("spec.util")

describe("flow typing in 'if' statements", function()
   it("detects if branch returns", util.check [[
      local x: integer | string

      if x is string then
         return "bye"
      end

      -- x is known to be integer!
      print(x + 1)
   ]])

   it("detects if all branches return", util.check [[
      local x: integer | boolean | string

      if x is string then
         return "bye"
      elseif x is boolean then
         return "bye too"
      end

      -- x is known to be integer!
      print(x + 1)
   ]])

   it("detects if not all branches return", util.check_type_error([[
      local x: integer | boolean | string

      if x is string then
         print("go on")
      elseif x is boolean then
         return "bye too"
      end

      -- x is NOT known to be integer!
      print(x + 1)
   ]], {
      { msg = "cannot use operator '+' for types integer | boolean | string and integer" },
   }))

   it("detects if all nested branches return", util.check [[
      local x: integer | boolean | string
      local a: integer

      if x is string then
         if a > 10 then
            return "bye"
         elseif a < 10 then
            return "wat"
         end
      elseif x is boolean then
         return "bye too"
      end

      -- x is known to be integer!
      print(x + 1)
   ]])

   it("detect if not all nested branches return", util.check_type_error([[
      local x: integer | boolean | string
      local a: integer

      if x is string then
         if a > 10 then
            print("go on")
         elseif a < 10 then
            return "wat"
         end
      elseif x is boolean then
         return "bye too"
      end

      -- x is NOT known to be integer!
      print(x + 1)
   ]], {
      { msg = "cannot use operator '+' for types integer | boolean | string and integer" },
   }))

   it("detects if last branch doesn't return", util.check_type_error([[
      local x: integer | boolean | string

      if x is string then
         return "bye too"
      elseif x is boolean then
         print("go on")
      end

      -- x is NOT known to be integer!
      print(x + 1)
   ]], {
      { msg = "cannot use operator '+' for types integer | boolean | string and integer" },
   }))

   it("detects if last nested branches return", util.check [[
      local x: integer | boolean | string
      local a: integer

      if x is string then
         return "bye too"
      elseif x is boolean then
         if a > 10 then
            return "bye"
         elseif a < 10 then
            return "wat"
         end
      end

      -- x is known to be integer!
      print(x + 1)
   ]])

   it("detect if not nested all last branches return", util.check_type_error([[
      local x: integer | boolean | string
      local a: integer

      if x is string then
         return "bye too"
      elseif x is boolean then
         if a > 10 then
            return "wat"
         elseif a < 10 then
            print("go on")
         end
      end

      -- x is NOT known to be integer!
      print(x + 1)
   ]], {
      { msg = "cannot use operator '+' for types integer | boolean | string and integer" },
   }))
end)
