local util = require("spec.util")

describe("subtyping of interfaces:", function()
   it("record inherits interface array definition", util.check([[
      local interface MyInterface
         is {MyInterface}
         x: integer
      end

      local record MyRecord
         is MyInterface
      end

      local r: MyRecord = {}
      print(#r)
   ]]))

   it("record <: interface", util.check([[
      local interface MyInterface
         x: integer
      end

      local record MyRecord is MyInterface
      end

      local function f(p: MyInterface)
         print(p.x)
      end

      local r: MyRecord = { x = 2 }
      f(r)
   ]]))

   it("prototype record <: interface", util.check([[
      local interface MyInterface
         x: integer
      end

      local record MyRecord is MyInterface
      end

      local function f(p: MyInterface)
         print(p.x)
      end

      MyRecord.x = 2
      f(MyRecord)
   ]]))

   it("record <: interface (regression test for #859, example without generics)", util.check([[
      local interface IFoo
         get_value: function(self): integer
      end

      local record Foo is IFoo
         _value: integer
      end

      function Foo:get_value():integer
         return self._value
      end

      function Foo.new(value: integer):Foo
         local fields = { _value = value }
         return setmetatable(fields, { __index = Foo })
      end

      local function create_foo(value: integer):IFoo
         local foo = Foo.new(value)
         return foo
      end

      local foo = create_foo(5)
      print(foo:get_value())
    ]]))

   it("generic record <: generic interface (regression test for #859)", util.check([[
      local interface IFoo<T>
         get_value: function(self): T
      end

      local record Foo<T> is IFoo<T>
         _value: T
      end

      function Foo:get_value():T
         return self._value
      end

      function Foo.new(value: T):Foo<T>
         local fields = { _value = value }
         return setmetatable(fields, { __index = Foo })
      end

      local function create_foo<T>(value: T):IFoo<T>
         local foo = Foo.new(value)
         return foo

         -- Have to do this instead for now:
         -- return foo as IFoo<T>
      end

      ------------------------

      local foo = create_foo(5)
      print(foo:get_value())
   ]]))

   it("regression test when matching against an unknown type", util.check_type_error([[
      local interface B
      end

      local x: B

      if x is W then
      end
   ]], {
      { msg = "x (of type B) can never be a W" },
      { msg = "unknown type W" },
   }))

   it("regression test for #830", util.check_lines([[
      local interface IFoo
      end

      local record Foo is IFoo
      end

      local function bar(_value:Foo)
      end

      local function qux(_value:IFoo)
      end

      local foo:Foo

   ]], {
      { line = "bar(foo)" },
      { line = "bar(Foo)" },
      { line = "bar(IFoo)", err = "IFoo is not a Foo" },
      { line = "bar(foo as Foo)" },
      { line = "bar(Foo as Foo)" },
      { line = "bar(IFoo as Foo)", err = "interfaces are abstract" },
      { line = "bar(foo as IFoo)", err = "IFoo is not a Foo" },
      { line = "bar(Foo as IFoo)", err = "IFoo is not a Foo"  },
      { line = "bar(IFoo as IFoo)", err = "interfaces are abstract" },
      { line = "qux(foo)" },
      { line = "qux(Foo)" },
      { line = "qux(IFoo)", err = "interfaces are abstract" },
      { line = "qux(foo as Foo)" },
      { line = "qux(Foo as Foo)" },
      { line = "qux(IFoo as Foo)", err = "interfaces are abstract" },
      { line = "qux(foo as IFoo)" },
      { line = "qux(Foo as IFoo)" },
      { line = "qux(IFoo as IFoo)", err = "interfaces are abstract" },
   }))

   it("interface fields are covariant (regression test for #944)", util.check([[
      local interface Move
      end

      local interface Fly is Move
      end

      local interface Animal
          move: Move -- Error: field 'move' does not match definition in interface Bird
      end

      local interface Bird is Animal
          move: Fly
      end

      local record Test1 is Animal
      end

      local record Test2 is Bird
      end
   ]]))

   it("interface fields are covariant (regression test for #944)", util.check_type_error([[
      local interface Move
      end

      local interface Fly is Move
      end

      local interface Animal
          move: Fly
      end

      local interface Bird is Animal
          move: Move
      end

      local record Test1 is Animal
      end

      local record Test2 is Bird
      end
   ]], {
      { y = 12, msg = "'move' does not match definition in interface Animal" }
   }))

   it("interface fields are covariant even if interface not instantiated (regression test for #944)", util.check_type_error([[
      local interface Move
      end

      local interface Fly is Move
      end

      local interface Animal
          move: Fly
      end

      local interface Bird is Animal
          move: Move
      end
   ]], {
      { y = 12, msg = "'move' does not match definition in interface Animal" }
   }))

   it("early-outs on nonexistent nested interface types (regression test for #986)", util.check_type_error([[
      local interface Example
      end

      local fails: Example.A.B = {}
   ]], {
      { y = 4, msg = "unknown type Example.A.B" }
   }))

   it("interface :> record but not the other way around", util.check_type_error([[
      local interface I
      end

      local record R is I
      end

      local r: R
      local i: I

      local wants_i1: I = i or r
      local wants_i2: I = r or i

      local wants_r1: R = i or r
      local wants_r2: R = r or i
   ]], {
      { y = 13, msg = "I is not a R" },
      { y = 14, msg = "I is not a R" },
   }))

   it("array inheritance works (regression test for #1022)", util.check([[
      local interface A is {string}
      end
      local interface B is A
      end
      local _a: A = { "a", "b" }
      local _b: B = { "c" }
   ]]))
end)
