local util = require("spec.util")

describe("expected function type propagation", function()

   it("propagates expected type in variable assignment", util.check([[
      local f: function(integer): string = function(x)
         return tostring(x)
      end
   ]]))

   it("propagates expected type in function argument", util.check([[
      local function call_with_function(f: function(integer): string): string
         return f(42)
      end

      call_with_function(function(x)
         return tostring(x)
      end)
   ]]))

   it("propagates expected type in return position", util.check([[
      local function get_handler(): function(integer): string
         return function(x)
            return tostring(x)
         end
      end
   ]]))

end)
