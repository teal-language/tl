local util = require("spec.util")

describe("function definition type propagation", function()

   -- Argument type propagation
   it("propagates expected type in variable assignment", util.check([[
      local f: function(integer): string = function(x)
         local added: integer = x + 1
         return tostring(added)
      end
   ]]))

   -- Argument type propagation in function calls
   it("propagates expected type in function argument", util.check([[
      local function call_with_function(f: function(integer): string): string
         return f(42)
      end

      call_with_function(function(x)
         local added: integer = x + 1
         return tostring(added)
      end)
   ]]))

   -- Return type propagation should not apply in assignment context
   it("does not propagate expected returns in assignment context", util.check_type_error([[
      local f: function(integer): string
      f = function(x)
         local added: integer = x + 1
         return tostring(added)
      end
   ]], {
      { y = 2, msg = "in assignment: incompatible number of returns: got 0 (), expected 1 (string)" },
      { y = 3, msg = "cannot use operator '+' for types <any type> and integer" },
      { y = 4, msg = "in return value: excess return values, expected 0 (), got 1 (string)" },
   }))

   -- Return type propagation in return position
   it("propagates expected type in return position", util.check([[
      local function get_handler(): function(integer): string
         return function(x: integer): string
            local added: integer = x + 1
            return tostring(added)
         end
      end
   ]]))

end)

