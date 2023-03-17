local util = require("spec.util")

describe("record method call", function()
   it("method call on an expression", util.check([[
      local r = {
         x = 2,
         b = true,
      }
      function r:f(a: number, b: string): boolean
         if self.b then
            return #b == 3
         else
            return a > self.x
         end
      end
      (r):f(3, "abc")
   ]]))

   it("method call with different call forms", util.check([[
      local foo = {bar = function(x: any, t: any) end}
      print(foo:bar())
      print(foo:bar{})
      print(foo:bar"hello")
   ]]))

   it("catches wrong use of : without a call", util.check_syntax_error([[
      local foo = {bar = function(x: any, t: any) end}
      print(foo:bar)
   ]], {
      { y = 2, msg = "expected a function call" },
   }))

   it("nested record method calls", util.check([[
      local r = {
         x = 2,
         b = true,
      }
      function r:f(b: string): string
         if self.b then
            return #b == 3 and "yes" or "no"
         end
         return "what"
      end
      local function foo()
         r:f(r:f("hello"))
      end
   ]]))

   describe("lax", function()
      it("nested record method calls", util.lax_check([[
         local SW = {}

         function SW:write(arg1,arg2,...)
         end

         function SW:writef(fmt,...)
            self:write(fmt:format(...))
         end
      ]], {
         { msg = "arg1" },
         { msg = "arg2" },
         { msg = "fmt" },
         { msg = "fmt.format" },
      }))
   end)

   it("catches wrong use of self. in call", util.check_type_error([[
      local record Foo
      end
      function Foo:method_a()
      end
      function Foo:method_c(arg: string)
      end
      function Foo:method_b()
         self.method_a()
         self.method_c("hello")
      end
   ]], {
      { y = 8, msg = "invoked method as a regular function: use ':' instead of '.'" },
      { y = 9, msg = "invoked method as a regular function: use ':' instead of '.'" },
   }))

   it("reports potentially wrong use of self. in call", util.check_warnings([[
      local record Foo
         x: integer
      end
      function Foo:copy_x(other: Foo)
         self.x = other.x
      end
      function Foo:copy_all(other: Foo)
         self.copy_x(other)
      end
   ]], {
      { y = 8, msg = "invoked method as a regular function: consider using ':' instead of '.'" }
   }))

   it("accepts use of dot call for method on record typetype", util.check_warnings([[
      local record Foo
         x: integer
      end
      function Foo:add(other: Foo)
         self.x = other and (self.x + other.x) or self.x
      end
      local first: Foo = {}
      Foo.add(first)
      local q = Foo
      q.add(first)
      local m = {
         a: Foo
      }
      m.a.add(first)
   ]], {}, {}))

   it("reports correct errors for calls on aliases of method", util.check_type_error([[
      local record Foo
         x: integer
      end
      function Foo:add(other: integer)
         self.x = other and (self.x + other) or self.x
      end
      local first: Foo = {}
      local fadd = first.add
      fadd(12)
      global gadd = first.add
      gadd(13)
      local tab = {
         hadd = first.add
      }
      tab.hadd(14)

   ]],
   { 
      { y = 9, msg = "argument 1: got integer, expected Foo" },
      { y = 11, msg = "argument 1: got integer, expected Foo" },
      { y = 15, msg = "argument 1: got integer, expected Foo" },
   }))

   it("reports no warnings for correctly-typed calls on aliases of method", util.check_warnings([[
      local record Foo
         x: integer
      end
      function Foo:add(other: Foo)
         self.x = other and (self.x + other.x) or self.x
      end
      local first: Foo = {}
      local fadd = first.add
      fadd(first)
      global gadd = first.add
      gadd(first)
      local tab = {
         hadd = first.add
      }
      tab.hadd(first)

   ]], {}, {}))

end)
