local util = require("spec.util")

describe("lambda parameter type inference", function()

   it("infers single parameter type from expected function type", util.check([[
      local f: function(integer): string = function(x)
         return tostring(x)
      end
   ]]))

   it("infers multiple parameter types from expected function type", util.check([[
      local f: function(integer, string): boolean = function(x, y)
         return #y > x
      end
   ]]))

   it("enforces inferred integer type in body", util.check_type_error([[
      local f: function(integer): boolean = function(x)
         return #x > 0
      end
   ]]))

   it("explicit annotation must match expected type", util.check_type_error([[
      local f: function(integer): string = function(x: string)
         return x
      end
   ]]))

   it("does not override explicit parameter annotation when compatible", util.check([[
      local f: function(integer): string = function(x: number)
         return tostring(x)
      end
   ]]))

   it("infers parameter types in function argument position", util.check([[
      local function call_with_function(f: function(integer): string): string
         return f(42)
      end

      call_with_function(function(x)
         return tostring(x)
      end)
   ]]))

   it("infers parameter types in return position", util.check([[
      local function get_handler(): function(integer): string
         return function(x)
            return tostring(x)
         end
      end
   ]]))
    it("keeps inference behavior when no expected type exists", util.check([[
      local f = function(x)
         return x
      end
   ]]))

   it("infers integer from expected type for unannotated lambda parameter", util.check([[
      local f: function(integer): integer = function(x)
         return x
      end
   ]]))

   it("accepts wider explicit parameter annotations", util.check([[
      local f: function(integer): integer = function(x: number)
         return x
      end
   ]]))

   it("rejects incompatible explicit parameter annotations", util.check_type_error([[
      local f: function(integer): integer = function(x: string)
         return 1
      end
   ]]))

   it("rejects arity mismatch", util.check_type_error([[
      local f: function(integer, string): boolean = function(x)
         return true
      end
   ]]))

end)
