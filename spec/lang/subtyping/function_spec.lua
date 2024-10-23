local util = require("spec.util")

describe("subtyping of functions:", function()
   it("f(a, ?b) <: f(a) (regression test 1 for #826)", util.check([[
      local type shared = string
      local interface test1
          a: function(a:string,b:shared)
      end
      local record test2 is test1
          a: function(a:string, b:shared, c?:string) -- Error when shared != string
      end
      local record test3 is test1
          a: function(a:string, b:shared, c?:number) -- Error when shared != number
      end
   ]]))

   it("f(a, ?b) <: f(a) (regression test 2 for #826)", util.check([[
      local type shared = number
      local interface test1
          a: function(a:string,b:shared)
      end
      local record test2 is test1
          a: function(a:string, b:shared, c?:string) -- Error when shared != string
      end
      local record test3 is test1
          a: function(a:string, b:shared, c?:number) -- Error when shared != number
      end
   ]]))
end)
