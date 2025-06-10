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
   it("adds a semi for disambiguation even with macroexps", util.gen([[
      local record Obj
         prt: function(self)
         call_prt: function(self)
            = macroexp(o: Obj) return (o):prt() end
      end
      function Obj:prt()
         print("hehe")
      end

      local t: Obj = setmetatable({}, { __index = Obj })
      do
         t:call_prt()
         t:call_prt()
      end
   ]], [[
      local Obj = {}




      function Obj:prt()
         print("hehe")
      end

      local t = setmetatable({}, { __index = Obj })
      do
         (t):prt();
         (t):prt()
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
