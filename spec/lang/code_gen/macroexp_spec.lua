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

   it("can resolve __eq metamethod (regression test for #814)", util.gen([[
      local type R = record
         x: number
         y: number

         metamethod __lt: function(a: R, b: R) = macroexp(a: R, b: R)
            return a.x < b.x
         end

         metamethod __eq: function(a: R, b: R) = macroexp(a: R, b: R)
            return a.x == b.x
         end
      end

      local r: R = { x = 10, y = 20 }
      local s: R = { x = 10, y = 0 }

      if r > s then
         print("yes")
      end

      if r == s then
         print("the 'x' fields are equal")
      end
   ]], [[













      local r = { x = 10, y = 20 }
      local s = { x = 10, y = 0 }

      if s.x < r.x then
         print("yes")
      end

      if r.x == s.x then
         print("the 'x' fields are equal")
      end
   ]]))

   it("works with ...", util.gen([[
      local macroexp macroprint(a: string, ...: string)
         return print(a, ...)
      end

      macroprint('varargs', 'dis', 'appear')
   ]], [[




      print('varargs', 'dis', 'appear')
   ]]))

   it("works with optional parameters", util.gen([[
      local macroexp macroprint(a: string, b ?: string, c ?: string)
         return print(a, b, c)
      end

      macroprint('arg1', 'arg2')
   ]], [[




      print('arg1', 'arg2', nil)
   ]]))

   it("overrides array __len", util.gen([[
      local interface Foo is {integer}
         sz: integer
         metamethod __len: function(self) = macroexp(self: Foo)
            return self.sz
         end
      end

      local f: Foo = {sz = 10}
      print(#f)
   ]], [[







      local f = {sz = 10}
      print(f.sz)
   ]]))
end)

