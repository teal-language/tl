local util = require("spec.util")

describe("macroexp declaration", function()
   it("checks unused arguments", util.check_warnings([[
      local record R1
         metamethod __is: function(self: R1): boolean = macroexp(self: R1): boolean
            return true
         end
      end
   ]], {
      { y = 2, msg = "unused argument self: R1" }
   }))

   it("checks argument mismatch", util.check_type_error([[
      local record R1
         metamethod __call: function(self: R1, n: number): boolean = macroexp(self: R1, s: string): boolean
            return self.field == s
         end
         field: string
      end
   ]], {
      { y = 2, x = 70, msg = "macroexp type does not match declaration" }
   }))

   it("checks multiple use of arguments", util.check_type_error([[
      global function f(a: string, b:string)
         print(a, b)
      end

      local record R1
         metamethod __call: function(self: R1, s: string): boolean = macroexp(self: R1, s: string): boolean
            return print(s, s)
         end
      end
   ]], {
      { y = 7, x = 29, msg = "cannot use argument 's' multiple times in macroexp" }
   }))

   it("checks multiple use of arguments", util.check_type_error([[
      global function f(a: string, b:string)
         print(a, b)
      end

      local record R1
         metamethod __call: function(self: R1, ...: string): boolean = macroexp(self: R1, ...: string): boolean
            return print(...) or print(...)
         end
      end
   ]], {
      { y = 7, x = 40, msg = "cannot use argument '...' multiple times in macroexp" }
   }))

   it("rejects macroexp methods called on a union type (regression test for #1134)", util.check_type_error([[
      local record R1
         where self.k == 1
         k: integer
         method: function(self): boolean = macroexp(self: R1): boolean
            return false
         end
      end

      local record R2
         where self.k == 2
         k: integer
         method: function(self): boolean = macroexp(self: R2): boolean
            return true
         end
      end

      local function f(x: R1 | R2): boolean
         return x:method()
      end

      local function g(x: R1 | R2): boolean
         return x.method(x)
      end
   ]], {
      { y = 18, x = 19, msg = "cannot use macroexp 'method' on union type R1 | R2" },
      { y = 22, x = 19, msg = "cannot use macroexp 'method' on union type R1 | R2" }
   }))

   it("rejects a method that is a macroexp in only some types of a union", util.check_type_error([[
      local record R1
         where self.k == 1
         k: integer
         method: function(self): boolean
      end

      local record R2
         where self.k == 2
         k: integer
         method: function(self): boolean = macroexp(self: R2): boolean
            return true
         end
      end

      local function f(x: R1 | R2): boolean
         return x:method()
      end
   ]], {
      { y = 16, x = 19, msg = "cannot use macroexp 'method' on union type R1 | R2" }
   }))

   it("rejects a macroexp __call on a union type", util.check_type_error([[
      local record R1
         where self.k == 1
         k: integer
         metamethod __call: function(self): string = macroexp(self: R1): string
            return "one"
         end
      end

      local record R2
         where self.k == 2
         k: integer
         metamethod __call: function(self): string = macroexp(self: R2): string
            return "two"
         end
      end

      local function f(x: R1 | R2): string
         return x()
      end
   ]], {
      { y = 18, x = 18, msg = "cannot use macroexp '__call' on union type R1 | R2" }
   }))

   it("accepts a macroexp __call shared by all types of a union", util.check([[
      local interface I
         metamethod __call: function(self: I): string = macroexp(self: I): string
            return "called"
         end
      end

      local record R1 is I
         where self.k == 1
         k: integer
      end

      local record R2 is I
         where self.k == 2
         k: integer
      end

      local function f(x: R1 | R2): string
         return x()
      end
   ]]))
end)
