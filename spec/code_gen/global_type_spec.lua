local util = require("spec.util")

describe("global type code generation", function()
   it("does not elide global function type used only as type", util.gen([[
      global type MyFun = function(integer, integer): integer

      global function execute(f: MyFun, x: integer, y: integer): integer
        return f(x, y)
      end

      global function sum(x:integer, y:integer): integer
        return x + y
      end

      execute(sum, 1, 2)
   ]], [[
      MyFun = {}

      function execute(f, x, y)
         return f(x, y)
      end

      function sum(x, y)
         return x + y
      end

      execute(sum, 1, 2)
   ]]))

   it("does not elide global record type used only as type", util.gen([[
      global type NotElided = record
         x: string
      end

      global r: NotElided = { x = "hello" }

      global function use_as_type(m: NotElided): string
        return m.x
      end

      print(use_as_type(r))
   ]], [[
      NotElided = {}



      r = { x = "hello" }

      function use_as_type(m)
         return m.x
      end

      print(use_as_type(r))
   ]]))

   it("does not elide global record type used as a variable", util.gen([[
      global type ConcreteViaVar = record
         x: string
      end

      global c1: ConcreteViaVar = setmetatable(
         { x = "hello" } as ConcreteViaVar,
         { __index = ConcreteViaVar })

      print(c1.x)
   ]], [[
      ConcreteViaVar = {}



      c1 = setmetatable(
      { x = "hello" },
      { __index = ConcreteViaVar })

      print(c1.x)
   ]]))

   it("does not elide global record type used in record functions", util.gen([[
      global type ConcreteViaMethod = record
         x: string
      end

      global c2: ConcreteViaMethod = { x = "hello" }

      function ConcreteViaMethod:use_it(): string
        return self.x
      end

      print(c2:use_it())
   ]], [[
      ConcreteViaMethod = {}



      c2 = { x = "hello" }

      function ConcreteViaMethod:use_it()
         return self.x
      end

      print(c2:use_it())
   ]]))
end)
