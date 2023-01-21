local util = require("spec.util")

describe("function results", function()
   it("should be adjusted down to 1 result in an expression list", util.check([[
      local function f(): string, number
      end
      local a, b = f(), "hi"
      a = "hey"
   ]]))

   it("can resolve type arguments based on expected type at use site (#512)", util.check([[
      local function get_foos<T>():{T}
         return {}
      end

      local foos:{integer} = get_foos()
      print(foos)
   ]]))
end)
