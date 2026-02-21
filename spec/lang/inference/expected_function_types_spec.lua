local util = require("spec.util")

describe("expected function type propagation", function()

   it("propagates expected type in variable assignment", util.check([[
      local f: function(integer): string = function(x)
         local added: integer = x + 1
         return tostring(x)
      end
   ]]))

   it("propagates expected type in function argument", util.check([[
      local function call_with_function(f: function(integer): string): string
         return f(42)
      end

      call_with_function(function(x)
         local added: integer = x + 1
         return tostring(x)
      end)
   ]]))
   it("does not propagate expected returns in assignment context", util.check_type_error([[
      local f: function(integer): string
      f = function(x)
         local added: integer = x + 1
         return tostring(x)
      end
   ]], {
      { y = 2, msg = "in assignment: incompatible...", },
      { y = 3, msg = "excess return values...", },
   }))
   it("propagates expected type in return position", util.check([[
      local function get_handler(): function(integer): string
         return function(x: integer): string
            local added: integer = x + 1
            return tostring(x)
         end
      end
   ]]))

end)
