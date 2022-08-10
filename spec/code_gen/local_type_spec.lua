local util = require("spec.util")

describe("local type code generation", function()
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

end)
