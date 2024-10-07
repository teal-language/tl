local util = require("spec.util")

describe("macroexp code generation", function()
   it("can use where with generic types", util.gen([[
      local type Success = record<T>
         where self.error == false

         error: boolean
         value: T
      end

      local type Failure = record<T>
         where self.error == true

         error: boolean
         value: T
      end

      local function ok<T>(value: T): Success<T>
         return {
            error = false,
            value = value,
         }
      end

      local function fail<T>(value: T): Failure<T>
         return {
            error = true,
            value = value,
         }
      end

      local type Maybe<T> = Success<T> | Failure<T>

      local function call_me<T>(maybe: Maybe<T>)
         if maybe is Success<T> then
            print("hello, " .. tostring(maybe.value))
         end
      end

      call_me(ok(8675309))
      call_me(fail(911))
   ]], [[














      local function ok(value)
         return {
            error = false,
            value = value,
         }
      end

      local function fail(value)
         return {
            error = true,
            value = value,
         }
      end



      local function call_me(maybe)
         if maybe.error == false then
            print("hello, " .. tostring(maybe.value))
         end
      end

      call_me(ok(8675309))
      call_me(fail(911))
   ]]))

   it("can resolve self for methods", util.gen([[
      local record R
         x: number

         metamethod __call: function(self) = macroexp(self: R)
            return print("R is " .. tostring(self.x) .. "!")
         end

         get_x: function(self): number = macroexp(self: R): number
            return self.x
         end
      end

      local r: R = { x = 10 }
      print(r:get_x())
      r()
   ]], [[












      local r: R = { x = 10 }
      print(r.x)
      print("R is " .. tostring(r.x) .. "!")
   ]]))

   it("can resolve metamethods", util.gen([[
      local record R
         x: number

         metamethod __lt: function(a: R, b: R): boolean = macroexp(a: R, b: R): boolean
            return a.x < b.x
         end
      end

      local r: R = { x = 10 }
      local s: R = { x = 20 }
      if r > s then
         print("yes")
      end
   ]], [[








      local r = { x = 10 }
      local s = { x = 20 }
      if s.x < r.x then
         print("yes")
      end
   ]]))
end)

