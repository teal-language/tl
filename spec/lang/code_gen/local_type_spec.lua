local util = require("spec.util")

describe("local type code generation", function()
   for _, gen_target in ipairs{"5.1", "5.3"} do
      it("rejected for non 5.4 target (" .. gen_target .. ")", util.gen([[
         local x <close> = io.open("foobar", "r")
      ]], nil, gen_target, {
         { msg = "only valid for Lua 5.4" }
      }))
   end

   it("elides local function type used only as type", util.gen([[
      local type MyFun = function(integer, integer): integer

      local function execute(f: MyFun, x: integer, y: integer): integer
        return f(x, y)
      end

      local function sum(x:integer, y:integer): integer
        return x + y
      end

      execute(sum, 1, 2)
   ]], [[


      local function execute(f, x, y)
         return f(x, y)
      end

      local function sum(x, y)
         return x + y
      end

      execute(sum, 1, 2)
   ]]))

   it("elides local record type used only as type", util.gen([[
      local type Elided = record
         x: string
      end

      local r: Elided = { x = "hello" }

      local function use_as_type(m: Elided): string
        return m.x
      end

      print(use_as_type(r))
   ]], [[




      local r = { x = "hello" }

      local function use_as_type(m)
         return m.x
      end

      print(use_as_type(r))
   ]]))

   it("does not elide local record type used as a variable", util.gen([[
      local type ConcreteViaVar = record
         x: string
      end

      local c1: ConcreteViaVar = setmetatable(
         { x = "hello" } as ConcreteViaVar,
         { __index = ConcreteViaVar })

      print(c1.x)
   ]], [[
      local ConcreteViaVar = {}



      local c1 = setmetatable(
      { x = "hello" },
      { __index = ConcreteViaVar })

      print(c1.x)
   ]]))

   it("does not elide local record type used in record functions", util.gen([[
      local type ConcreteViaMethod = record
         x: string
      end

      local c2: ConcreteViaMethod = { x = "hello" }

      function ConcreteViaMethod:use_it(): string
        return self.x
      end

      print(c2:use_it())
   ]], [[
      local ConcreteViaMethod = {}



      local c2 = { x = "hello" }

      function ConcreteViaMethod:use_it()
         return self.x
      end

      print(c2:use_it())
   ]]))

   it("alias for a type that shouldn't be elided", util.gen([[
      local type List2 = record<T>
          new: function(initialItems: {T}): List2<T>
      end

      function List2.new<T>(initialItems: {T}): List2<T>
      end

      local type Fruit2 = enum
         "apple"
         "peach"
         "banana"
      end

      local type L2 = List2<Fruit2>
      local lunchbox = L2.new({"apple", "peach"})
   ]], [[
      local List2 = {}



      function List2.new(initialItems)
      end







      local L2 = List2
      local lunchbox = L2.new({ "apple", "peach" })
   ]]))

   it("alias for a type that shouldn't be elided, with function generics", util.gen([[
      local type List2 = record<T>
          new: function<U>(initialItems: {T}, u: U): List2<T>
      end

      function List2.new<Y>(initialItems: {T}, u: Y): List2<T>
      end

      local type Fruit2 = enum
         "apple"
         "peach"
         "banana"
      end

      local type L2 = List2<Fruit2>
      local lunchbox = L2.new({"apple", "peach"}, true)
   ]], [[
      local List2 = {}



      function List2.new(initialItems, u)
      end







      local L2 = List2
      local lunchbox = L2.new({ "apple", "peach" }, true)
   ]]))

   it("if alias shouldn't be elided, type shouldn't be elided either", util.gen([[
      local type List = record<T>
          new: function(initialItems: {T}): List<T>
      end

      local type Fruit = enum
         "apple"
         "peach"
         "banana"
      end

      local type L = List<Fruit>
      local lunchbox = L.new({"apple", "peach"})
   ]], [[
      local List = {}









      local L = List
      local lunchbox = L.new({ "apple", "peach" })
   ]]))

   it("alias that can be elided for a type that can be elided", util.gen([[
      local type List3 = record<T>
          new: function(initialItems: {T}): List3<T>
      end

      local type Fruit3 = enum
         "apple"
         "peach"
         "banana"
      end

      local type L3 = List3<Fruit3>
      local function x(z: L3)
      end
   ]], [[











      local function x(z)
      end
   ]]))

   it("elides local type require used only as type", function()
      util.mock_io(finally, {
         ["foo.tl"] = [[
            local record Foo
               x: number
            end

            return Foo
         ]]
      })
      util.gen([[
         local type Foo = require("foo")

         local d: Foo = { x = 2 }
      ]], [[


         local d = { x = 2 }
      ]])
   end)

   it("does not elide local type require used as a variable", function()
      util.mock_io(finally, {
         ["foo.tl"] = [[
            local record Foo
               x: number
            end

            return Foo
         ]]
      })
      util.gen([[
         local type Foo = require("Foo")

         local d: Foo = { x = 2 }

         print(Foo)
      ]], [[
         local Foo = require("Foo")

         local d = { x = 2 }

         print(Foo)
      ]])
   end)

   it("always elides local type require used as a variable, even if incorrect use of interfaces or aliases", util.gen([[
      local interface IFoo
      end

      local type Alias = IFoo

      local record Foo is IFoo
      end

      local function register(_id:any, _value:any)
      end

      local foo:Foo

      register(IFoo, foo)

      register(Alias, foo)
   ]], [[








      local function register(_id, _value)
      end

      local foo

      register(IFoo, foo)

      register(Alias, foo)
   ]], nil, {
      { y = 14, msg = "interfaces are abstract" },
      { y = 16, msg = "interfaces are abstract" },
   }))

   it("does not elide generic entries that are needed (#902)", util.gen([[
      local record Qux<T>
          v: integer
      end

      Qux.v = 123

      local record Foo
          record Bar<S>
              value: S

              metamethod __call: function(self, value: S): self
          end
      end

      setmetatable(Foo.Bar, {
          __call = function<S>(self, value: S): Foo.Bar<S>
              return {value = value}
          end
      })

      print(Foo.Bar("hi").value)
   ]], [[
      local Qux = {}



      Qux.v = 123

      local Foo = {Bar = {}, }







      setmetatable(Foo.Bar, {
         __call = function(self, value)
            return { value = value }
         end,
      })

      print(Foo.Bar("hi").value)
   ]], nil, {}))

end)
