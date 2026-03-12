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
   
   it("record inherits interface tuple definition", util.check([[
      local interface MyInterface
         is {integer, string}
         x: integer
      end

      local record MyRecord
         is MyInterface
      end

      local r: MyRecord = {1, "abc"}
      print(r[1], r[2])
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

   it("no duplicate interfaces in interface_list with diamond inheritance", function()
      local tl = require("teal.api.v2")
      local result = tl.check_string([[
         local interface A
            a: number
         end

         local interface B is A
            b: string
         end

         local interface C is A
            c: boolean
         end

         -- This should result in interface_list: {B, A, C} (no duplicate A)
         local record D is B, C
            d: integer
         end

         -- Test that all fields are accessible
         local d: D = {
            a = 1,    -- from A (via B and C)
            b = "hi", -- from B
            c = true, -- from C
            d = 42    -- from D
         }
         print(d.a, d.b, d.c, d.d)
      ]])
      local expected = { "B", "A", "C" }
      for i,v in ipairs(result.ast[5].decltuple.tuple[1].resolved.interface_list) do
         assert.equal(expected[i], v.resolved.declname)
      end
   end)

   it("interfaces propagate userdata marking (#1070)", util.check_type_error([[
      local interface User
         is userdata
         name: string
      end

      local record Foo is User
      end

      local a: Foo = {
          name = "foo"
      }


      local function Foos(a:User) end

      Foos(a)
   ]], {
      { y = 9, msg = "record is not a userdata" },
   }))

   it("compatible tuple definitions are inherited", util.check([[
      local interface MyInterface
         is {integer, string}
         x: integer
      end
      
      local interface MyOtherInterface
         is {integer, string, boolean}
         y: integer
      end

      local record MyRecord
         is MyInterface, MyOtherInterface
      end

      local r: MyRecord = {1, "abc", false}
      print(r[1], r[2], r[3])
   ]]))
   
   it("incompatible tuple definitions produce error", util.check_type_error([[
      local interface MyInterface
         is {integer, string}
         x: integer
      end
      
      local interface MyOtherInterface
         is {boolean, integer, string}
         y: integer
      end

      local record MyRecord
         is MyInterface, MyOtherInterface
      end
   ]], {
      {y = 11, x = 7, msg = 'incompatible tuple interfaces'}
   }))

   it("compatible tuple and array definitions produce warning", util.check_warnings([[
      local interface MyTupleInterface
         is {integer, integer}
         x: integer
      end
      
      local interface MyArrayInterface
         is {integer}
         y: integer
      end

      local record MyRecord
         is MyTupleInterface, MyArrayInterface
      end

      local r: MyRecord = {10, 12, 14}
      print(r[1], r[2], r[3])
   ]], {
      {y = 11, x = 7, tag = 'inheritance', msg = 'inherits overlapping array {integer} and tuple {integer, integer}'}
   }))

   it("incompatible tuple and array definitions produce error", util.check_type_error([[
      local interface MyTupleInterface
         is {integer, string}
         x: integer
      end
      
      local interface MyArrayInterface
         is {boolean}
         y: integer
      end

      local record MyRecord
         is MyTupleInterface, MyArrayInterface
      end
   ]], {
      {y = 11, x = 7, msg = 'inherits incompatible array {boolean} and tuple {integer, string}'}
   }))

   it("tuple definition types replace array definition union types in tuple indexes", util.check_warnings([[
      local interface MyTupleInterface
         is {string, integer}
         x: integer
      end
      
      local interface MyArrayInterface
         is {string | integer | boolean}
         y: integer
      end

      local record MyRecord
         is MyTupleInterface, MyArrayInterface
      end

      local r: MyRecord = {"hello", 10}
      r[2] = "world"
      r[1] = true

      r.x = 20
      r.y = 7
      r[0] = "array index"
      r[4] = false
      print(r[0], r[1], r[2], r[4])
   ]], {
      {y = 11, x = 7, tag = 'inheritance', msg = 'inherits overlapping array {string | integer | boolean} and tuple {string, integer}'}
   }, {
      {y = 16, x = 14, msg = 'in assignment: got string "world", expected integer'},
      {y = 17, x = 14, msg = 'in assignment: got boolean, expected string'}
   }))
end)
