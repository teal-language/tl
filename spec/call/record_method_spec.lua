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

   describe("catches wrong use of self, in call", function()
      it("for methods declared outside of the record", util.check_type_error([[
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

      it("for methods declared inside of a record", util.check_type_error([[
         local record Foo
            method_a: function(self: Foo)
            method_b: function(self: Foo)
            method_c: function(self: Foo, arg: string)
         end
         Foo.method_b = function(self: Foo)
            self.method_a()
            self.method_c("hello")
         end
      ]], {
         { y = 7, msg = "invoked method as a regular function: use ':' instead of '.'" },
         { y = 8, msg = "invoked method as a regular function: use ':' instead of '.'" },
      }))

      it("for methods declared inside of a nested record", util.check_type_error([[
         local record Foo
            record Bar
               method_a: function(self: Bar)
               method_b: function(self: Bar)
               method_c: function(self: Bar, arg: string)
            end
         end
         Foo.Bar.method_b = function(self: Foo.Bar)
            self.method_a()
            self.method_c("hello")
         end
      ]], {
         { y = 9, msg = "invoked method as a regular function: use ':' instead of '.'" },
         { y = 10, msg = "invoked method as a regular function: use ':' instead of '.'" },
      }))

      it("for methods declared inside of a generic record", util.check_type_error([[
         local record Foo<T>
            method_a: function(self: Foo<T>)
            method_c: function(self: Foo<T>, arg: string)
         end
         local function_b = function<T>(self: Foo<T>)
            self.method_a()
            self.method_c("hello")
         end
      ]], {
         { y = 6, msg = "invoked method as a regular function: use ':' instead of '.'" },
         { y = 7, msg = "invoked method as a regular function: use ':' instead of '.'" },
      }))

   end)

   describe("reports potentially wrong use of self. in call", function()
      it("for methods declared outside of the record", util.check_warnings([[
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

      it("for methods declared inside of the record", util.check_warnings([[
         local record Foo
            x: integer
            copy_x: function(self: Foo, other: Foo)
            copy_all: function(self: Foo, other: Foo)
         end
         Foo.copy_all = function(self: Foo, other: Foo)
            self.copy_x(other)
         end
      ]], {
         { y = 7, msg = "invoked method as a regular function: consider using ':' instead of '.'" }
      }))

      it("for methods declared inside of a nested record", util.check_warnings([[
         local record Foo
            record Bar
               x: integer
               copy_x: function(self: Bar, other: Bar)
               copy_all: function(self: Bar, other: Bar)
            end
         end
         Foo.Bar.copy_all = function(self: Foo.Bar, other: Foo.Bar)
            self.copy_x(other)
         end
      ]], {
         { y = 9, msg = "invoked method as a regular function: consider using ':' instead of '.'" }
      }))

      it("for methods declared inside of a generic record", util.check_warnings([[
         local record Foo<T>
            x: integer
            copy_x: function(self: Foo<T>, other: Foo<T>)
         end
         local copy_all = function<T>(self: Foo<T>, other: Foo<T>)
            self.copy_x(other)
         end
         copy_all()
      ]], {
         { y = 6, msg = "invoked method as a regular function: consider using ':' instead of '.'" }
      }))

   end)

   describe("accepts use of dot call", function()
      it("for method on record typetype", util.check_warnings([[
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
         local record m
            a: Foo
         end
         m.a.add(first)
      ]], {
         -- FIXME this warning needs to go away when we detect that "m.a" and "first" are not the same
         { y = 14, msg = "invoked method as a regular function: consider using ':' instead of '.'" }
      }, {}))

      it("for function declared in record body with self as different type from receiver", util.check_warnings([[
         local record Bar
         end
         local record Foo
            x: integer
            add: function(self: Bar, other?: Bar)
         end
         local first: Foo = {}
         local second: Bar = {}
         first.add(second)
      ]], {}, {}))

      it("for function declared in method body with self as different generic type from receiver", util.check_warnings([[
         local record Foo<T>
            x: T
            add: function(self: Foo<integer>, other?: Foo<integer>)
         end
         local first: Foo<string> = {}
         local second: Foo<integer> = {}
         first.add(second)
      ]], {}, {}))

      it("for correctly-typed calls on aliases of method", util.check_warnings([[
         local record Foo
            x: integer
         end
         function Foo:add(other?: Foo)
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

   describe("reports correct errors", function()

      it("for calls on aliases of method", util.check_type_error([[
         local record Foo
            x: integer
         end
         function Foo:add(other?: integer)
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

      it("for function declared in record body with self as different type from receiver", util.check_type_error([[
         local record Bar
         end
         local record Foo
            x: integer
            add: function(self: Bar, other?: Bar)
         end
         local first: Foo = {}
         first.add(first)
      ]],
      {
         { y = 8, msg = "argument 1: Foo is not a Bar" },
      }))

      it("for function declared in record body with self as different generic type from receiver", util.check_type_error([[
         local record Foo<T>
            x: T
            add: function(self: Foo<integer>, other?: Foo<integer>)
         end
         local first: Foo<string> = {}
         first.add(first)
      ]],
      {
         { y = 6, msg = "argument 1: type parameter <integer>: got string, expected integer" },
      }))

   end)

end)
