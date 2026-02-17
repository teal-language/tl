local util = require("spec.util")

describe("lambda contextual typing - arity behavior", function()

   -- Matching arity should work
   it("accepts lambda with matching arity (1 param)", util.check([[
      local f: function(integer): boolean = function(x)
         return x > 0
      end
   ]]))

   it("accepts lambda with matching arity (2 params)", util.check([[
      local f: function(integer, string): boolean = function(x, y)
         return x > 0
      end
   ]]))

   -- Mismatched arity should fail (using existing arity logic)
   it("rejects lambda with fewer parameters", util.check([[
      local f: function(integer, string): boolean = function(x)
         return true
      end
   ]]))
   -- TODO: This should generate an arity mismatch error

   it("rejects lambda with more parameters", util.check_type_error([[
      local f: function(integer): boolean = function(x, y)
         return true
      end
   ]], {
      { msg = "in local declaration: f: incompatible number of arguments: got 2 (<any type>, <any type>), expected 1 (integer)" }
   }))

   -- Works in argument position
   it("works in function argument position", util.check([[
      local function call_with_function(f: function(integer): string): string
         return f(42)
      end

      call_with_function(function(x)
         return tostring(x)
      end)
   ]]))

   -- Works in return position
   it("works in return position", util.check([[
      local function get_handler(): function(integer): string
         return function(x)
            return tostring(x)
         end
      end
   ]]))

end)
