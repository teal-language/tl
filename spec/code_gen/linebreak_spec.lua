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
end)
