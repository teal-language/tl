
local util = require("spec.util")

describe("flow typing in 'if' statements", function()
   it("detects if branch returns", util.check([[
      local x: integer | string

      if x is string then
         return "bye"
      end

      -- x is known to be integer!
      print(x + 1)
   ]]))

   it("detects if all branches return", util.check([[
      local x: integer | boolean | string

      if x is string then
         return "bye"
      elseif x is boolean then
         return "bye too"
      end

      -- x is known to be integer!
      print(x + 1)
   ]]))

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

   it("detects if all nested branches return", util.check([[
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
   ]]))

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

   it("detects if last nested branches return", util.check([[
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
   ]]))

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

   -- see also pending test "detects empty unions" in spec/operators/is_spec.lua
   it("detects a union value to be nil if all types are exhausted (regression test for #695)", util.check_warnings([[
      global function f2(val: string|number)
         if val is string then
            print(val)
         elseif val is number then
            print(val)
         else
            error("string or number expected")
         end
      end
   ]], {}, {}))

   it("do not widen if type remains the same (regression test for #994)", util.check([[
      local type T = table
      global function a() : string
         local value : string | T

         local is_escaped = false;
         if value is string then
            if not is_escaped then
               value = tostring(value)
            end
            return "" .. value .. ""
         end
      end
   ]]))

   it("do not widen back type if type in all blocks are the same", util.check([[
      local t: number | string | boolean
      local u: number | string
      t = 12
      if math.random(10) > 5 then
         t = 8
      else
         t = 9
      end
      local v: integer = t
   ]]))

   it("widen back type if type in blocks are different", util.check_type_error([[
      local t: number | string | boolean
      local u: number | string
      t = 12
      if math.random(10) > 5 then
         t = true
      else
         t = 9
      end
      local v: integer = t
   ]], {
      -- if we produced a union of each if branch, we could provide
      -- a more specific type here
      { msg = "got number | string | boolean, expected integer" },
   }))
end)
