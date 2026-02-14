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
   it("does not propagate expected returns in assignment context", util.check_type_error([[
      local f: function(integer): string
      f = function(x)
         return tostring(x)
      end
   ]], {
      { msg = "in assignment: incompatible number of returns: got 0 (), expected 1 (string)" },
      { msg = "excess return values, expected 0 (), got 1 (string)" },
   }))
   it("propagates expected type in return position", util.check([[
      local function get_handler(): function(integer): string
         return function(x)
            return tostring(x)
         end
      end
   ]]))

end)
