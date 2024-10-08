local util = require("spec.util")

describe("improved line break heuristics", function()
   it("a line starting with ( is not a function call for the previous line", util.gen([[
      local record Obj
      end

      function Obj:meth1()
         print("hehe")
      end

      local t = setmetatable({}, { __index = Obj })
      do
         (t as Obj):meth1()
         (t as Obj):meth1()
      end
   ]], [[
      local Obj = {}


      function Obj:meth1()
         print("hehe")
      end

      local t = setmetatable({}, { __index = Obj })
      do
         (t):meth1();
         (t):meth1()
      end
   ]]))
   it("break line correctly in multiline method declarations (regression test for #807)", util.gen([[
      local record Foo
      end

      function Foo:greet(
            greeting:string)
         print(greeting)
      end
   ]], [[
      local Foo = {}


      function Foo:greet(
            greeting)
         print(greeting)
      end
   ]]))
end)
