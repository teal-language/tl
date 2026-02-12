local util = require("spec.util")

describe("lambda contextual typing - exact arity matching", function()

   -- Property 1: Exact Arity Matching
   -- Validates: Requirements 2.1, 2.2, 2.3, 2.4
   -- Generate random function types and lambdas with various arities
   -- Verify arity mismatches are rejected
   -- Verify matching arities proceed to inference

   -- Helper function to generate parameter lists
   local function gen_params(count)
      local params = {}
      for i = 1, count do
         table.insert(params, "x" .. i)
      end
      return table.concat(params, ", ")
   end

   -- Helper function to generate function type signatures
   local function gen_func_type(param_count)
      local types = {}
      for i = 1, param_count do
         table.insert(types, "integer")
      end
      table.insert(types, "boolean")
      return "function(" .. table.concat(types, ", ") .. ")"
   end

   -- Test: Arity mismatch - fewer parameters
   pending("rejects lambda with fewer parameters than expected function type", util.check_type_error([[
      local f: function(integer, string): boolean = function(x)
         return true
      end
   ]], {
      { msg = "Lambda has 1 parameters but expected function type has 2 parameters" }
   }))

   -- Test: Arity mismatch - more parameters
   pending("rejects lambda with more parameters than expected function type", util.check_type_error([[
      local f: function(integer): boolean = function(x, y)
         return true
      end
   ]], {
      { msg = "Lambda has 2 parameters but expected function type has 1 parameters" }
   }))

   -- Test: Exact arity match - 1 parameter
   pending("accepts lambda with matching arity (1 parameter)", util.check([[
      local f: function(integer): boolean = function(x)
         return true
      end
   ]]))

   -- Test: Exact arity match - 2 parameters
   pending("accepts lambda with matching arity (2 parameters)", util.check([[
      local f: function(integer, string): boolean = function(x, y)
         return true
      end
   ]]))

   -- Test: Exact arity match - 3 parameters
   pending("accepts lambda with matching arity (3 parameters)", util.check([[
      local f: function(integer, string, boolean): number = function(x, y, z)
         return 42
      end
   ]]))

   -- Test: Exact arity match - 0 parameters
   pending("accepts lambda with matching arity (0 parameters)", util.check([[
      local f: function(): boolean = function()
         return true
      end
   ]]))

   -- Test: Arity mismatch - 0 vs 1
   pending("rejects lambda with 0 parameters when 1 expected", util.check_type_error([[
      local f: function(integer): boolean = function()
         return true
      end
   ]], {
      { msg = "Lambda has 0 parameters but expected function type has 1 parameters" }
   }))

   -- Test: Arity mismatch - 3 vs 2
   pending("rejects lambda with 3 parameters when 2 expected", util.check_type_error([[
      local f: function(integer, string): boolean = function(x, y, z)
         return true
      end
   ]], {
      { msg = "Lambda has 3 parameters but expected function type has 2 parameters" }
   }))

   -- Test: Arity match in function argument position
   pending("accepts lambda with matching arity in function argument position", util.check([[
      local function call_with_function(f: function(integer): string): string
         return f(42)
      end

      call_with_function(function(x)
         return tostring(x)
      end)
   ]]))

   -- Test: Arity mismatch in function argument position
   pending("rejects lambda with mismatched arity in function argument position", util.check_type_error([[
      local function call_with_function(f: function(integer): string): string
         return f(42)
      end

      call_with_function(function(x, y)
         return tostring(x)
      end)
   ]], {
      { msg = "Lambda has 2 parameters but expected function type has 1 parameters" }
   }))

   -- Test: Arity match in return position
   pending("accepts lambda with matching arity in return position", util.check([[
      local function get_handler(): function(integer): string
         return function(x)
            return tostring(x)
         end
      end
   ]]))

   -- Test: Arity mismatch in return position
   pending("rejects lambda with mismatched arity in return position", util.check_type_error([[
      local function get_handler(): function(integer): string
         return function(x, y)
            return tostring(x)
         end
      end
   ]], {
      { msg = "Lambda has 2 parameters but expected function type has 1 parameters" }
   }))

   -- Property-based tests: Generate multiple random arities
   -- Test various arity combinations to ensure the property holds
   for expected_arity = 0, 5 do
      for actual_arity = 0, 5 do
         if expected_arity == actual_arity then
            -- Matching arity should pass
            pending("property: accepts lambda with arity " .. actual_arity .. " matching expected arity " .. expected_arity, function()
               local params = gen_params(actual_arity)
               local func_type = gen_func_type(expected_arity)
               local lambda_body = params == "" and "return true" or "return true"
               local code = [[
                  local f: ]] .. func_type .. [[ = function(]] .. params .. [[)
                     ]] .. lambda_body .. [[
                  end
               ]]
               util.check(code)()
            end)
         else
            -- Mismatched arity should fail
            pending("property: rejects lambda with arity " .. actual_arity .. " when expected arity is " .. expected_arity, function()
               local params = gen_params(actual_arity)
               local func_type = gen_func_type(expected_arity)
               local lambda_body = params == "" and "return true" or "return true"
               local code = [[
                  local f: ]] .. func_type .. [[ = function(]] .. params .. [[)
                     ]] .. lambda_body .. [[
                  end
               ]]
               util.check_type_error(code, {
                  { msg = "Lambda has " .. actual_arity .. " parameters but expected function type has " .. expected_arity .. " parameters" }
               })()
            end)
         end
      end
   end

end)
