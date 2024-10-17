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
end)
