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

   it("if expression propagates a boolean context", util.check([[
      local n = 123
      local s = "hello"
      if n or s then
         local ns: number | string = n or s
         print(ns)
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

   it("performs type narrowing/widening on all branches", util.check([[
      local interface Another
         where self.another

         another: string
      end

      local interface Type
         where self.t

         t: string
      end

      local record SpecificType is Type
         where self.t == "specific"
      end

      local function needs_type(t: Type): Type
         print(t.t)
      end

      local it: Type | Another

      local a: Another = { another = "yes" }

      if it is Type then
         if it is SpecificType then
            it = a -- this does not impact the other branch
         else
            it = needs_type(it) -- preserves narrowing here
         end
      end

      it = a -- widen back to the union
   ]]))

   it("performs type narrowing/widening on all branches (with constrained generic)", util.check([[
      local interface Another
         where self.another

         another: string
      end

      local interface Type
         where self.t

         t: string
      end

      local record SpecificType is Type
         where self.t == "specific"
      end

      -- function with constrained generic
      local function needs_type<T is Type>(t: T): T
         print(t.t)
      end

      local it: Type | Another

      local a: Another = { another = "yes" }

      if it is Type then
         if it is SpecificType then
            it = a -- this does not impact the other branch
         else
            it = needs_type(it) -- preserves narrowing here
         end
      end

      it = a -- widen back to the union
   ]]))

   it("knows when to discard narrowing", util.check([[
      local type Key = string | number | boolean

      local function f(k: Key, n: number)
         if not k then
            k = n
            if not k then
               k = true
            end
         end
      end
   ]]))

end)
