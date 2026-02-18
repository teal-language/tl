local util = require("spec.util")

describe("lambda parameter type inference", function()

   it("infers single parameter type from expected function type", util.check([[
      local f: function(integer): string = function(x)
         return tostring(x)
      end
   ]]))

   it("enforces inferred types for multiple parameters", util.check_type_error([[
      local f: function(integer, string): boolean = function(x, y)
         return y + x
      end
   ]], {
      { msg = "cannot use operator '+' for types string and integer" }
   }))


   it("explicit annotation must still match expected type", util.check_type_error([[
      local f: function(integer): string = function(x: string)
         return x
      end
   ]], {
      { msg = "in local declaration: f: argument 1: got string, expected integer" }
   }))



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

   it("rejects arity mismatch", util.check([[
      local f: function(integer, string): boolean = function(x)
         return true
      end
   ]]))
 

   it("does not enforce inferred type without expected type", util.check_type_error([[
      local f = function(x)
         return x + 1
      end
   ]], {
      { msg = "in return value: excess return values, expected 0 (), got 1 (<invalid type>)" },
      { msg = "cannot use operator '+' for types <any type> and integer" }
   }))

   it("enforces inferred integer type in body", util.check_type_error([[
      local f: function(integer): boolean = function(x)
         return #x > 0
      end
   ]], {
      { msg = "cannot use operator '#' on type integer" }
   }))


end)
