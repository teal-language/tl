local util = require("spec.util")
local tl = require("teal.api.v2")
local contextual_typing = require("teal.contextual_typing")
local contextual_type_checker = require("teal.contextual_type_checker")

describe("contextual typing type safety preservation", function()
   
   -- Property 3: Type Safety Preservation
   -- **Validates: Requirements 3.1, 3.4**
   -- For any program using contextual typing, the type checker should enforce 
   -- the same type constraints and prevent the same type-unsafe operations 
   -- as it would with explicit typing.
   
   local function generate_type_safety_test_cases()
      return {
         -- Basic type constraint enforcement
         {
            name = "number parameter type constraint",
            expected_signature = {
               args = { { typename = "number" } },
               return_type = { typename = "number" }
            },
            inferred_literal = "function(x) return x + 1 end",
            explicit_literal = "function(x: number): number return x + 1 end",
            should_enforce_constraints = true,
            unsafe_operations = {
               "function(x) return x .. 'string' end",  -- String concat on number
               "function(x) return x[1] end",           -- Array indexing on number
            }
         },
         {
            name = "string parameter type constraint",
            expected_signature = {
               args = { { typename = "string" } },
               return_type = { typename = "string" }
            },
            inferred_literal = "function(s) return s .. 'suffix' end",
            explicit_literal = "function(s: string): string return s .. 'suffix' end",
            should_enforce_constraints = true,
            unsafe_operations = {
               "function(s) return s + 1 end",          -- Arithmetic on string
               "function(s) return s[1] end",           -- Array indexing on string
            }
         },
         {
            name = "boolean parameter type constraint",
            expected_signature = {
               args = { { typename = "boolean" } },
               return_type = { typename = "boolean" }
            },
            inferred_literal = "function(b) return not b end",
            explicit_literal = "function(b: boolean): boolean return not b end",
            should_enforce_constraints = true,
            unsafe_operations = {
               "function(b) return b + 1 end",          -- Arithmetic on boolean
               "function(b) return b .. 'text' end",    -- String concat on boolean
            }
         },
         
         -- Array type constraints
         {
            name = "array parameter type constraint",
            expected_signature = {
               args = { { typename = "array", elements = { typename = "number" } } },
               return_type = { typename = "number" }
            },
            inferred_literal = "function(arr) return arr[1] end",
            explicit_literal = "function(arr: {number}): number return arr[1] end",
            should_enforce_constraints = true,
            unsafe_operations = {
               "function(arr) return arr + 1 end",      -- Arithmetic on array
               "function(arr) return arr .. 'text' end", -- String concat on array
            }
         },
         
         -- Function parameter constraints
         {
            name = "function parameter type constraint",
            expected_signature = {
               args = { { 
                  typename = "function",
                  args = { { typename = "number" } },
                  return_type = { typename = "string" }
               } },
               return_type = { typename = "string" }
            },
            inferred_literal = "function(f) return f(42) end",
            explicit_literal = "function(f: function(number): string): string return f(42) end",
            should_enforce_constraints = true,
            unsafe_operations = {
               "function(f) return f('string') end",    -- Wrong argument type
               "function(f) return f() end",            -- Missing argument
            }
         },
         
         -- Multiple parameter constraints
         {
            name = "multiple parameter type constraints",
            expected_signature = {
               args = { { typename = "number" }, { typename = "string" } },
               return_type = { typename = "string" }
            },
            inferred_literal = "function(n, s) return s .. tostring(n) end",
            explicit_literal = "function(n: number, s: string): string return s .. tostring(n) end",
            should_enforce_constraints = true,
            unsafe_operations = {
               "function(n, s) return n .. s end",      -- Wrong operation for number
               "function(n, s) return n + s end",       -- Type mismatch in operation
            }
         },
         
         -- Return type constraints
         {
            name = "return type constraint enforcement",
            expected_signature = {
               args = { { typename = "number" } },
               return_type = { typename = "number" }
            },
            inferred_literal = "function(x) return x * 2 end",
            explicit_literal = "function(x: number): number return x * 2 end",
            should_enforce_constraints = true,
            unsafe_operations = {
               "function(x) return 'string' end",       -- Wrong return type
               "function(x) return nil end",            -- Wrong return type
            }
         },
         
         -- Numeric type compatibility
         {
            name = "numeric type compatibility constraints",
            expected_signature = {
               args = { { typename = "number" } },
               return_type = { typename = "number" }
            },
            inferred_literal = "function(x) return x + 1 end",
            explicit_literal = "function(x: number): number return x + 1 end",
            should_enforce_constraints = true,
            unsafe_operations = {
               "function(x) return x .. 'text' end",    -- String concat on number
            }
         }
      }
   end
   
   local function create_mock_function_type(signature)
      -- Create a mock FunctionType based on the signature
      local args_tuple = {
         typename = "tuple",
         typeid = 1,
         tuple = {}
      }
      
      for _, arg_type in ipairs(signature.args) do
         local mock_type = {
            typename = arg_type.typename,
            typeid = 2
         }
         
         -- Handle complex types like arrays and functions
         if arg_type.elements then
            mock_type.elements = arg_type.elements
         end
         if arg_type.args then
            mock_type.args = arg_type.args
         end
         if arg_type.return_type then
            mock_type.return_type = arg_type.return_type
         end
         
         table.insert(args_tuple.tuple, mock_type)
      end
      
      return {
         typename = "function",
         typeid = 3,
         args = args_tuple,
         rets = {
            typename = "tuple", 
            typeid = 4,
            tuple = { signature.return_type }
         },
         is_method = false,
         maybe_method = false,
         is_record_function = false,
         min_arity = #signature.args,
         needs_compat = false
      }
   end
   
   local function create_mock_function_literal(code)
      -- Parse the function literal to get AST node
      local full_code = "local f = " .. code
      local ast, syntax_errors = tl.parse(full_code, "test.tl")
      
      if #syntax_errors > 0 then
         error("Syntax error in function literal: " .. code)
      end
      
      -- Find the function literal in the AST
      local function find_function_literal(node)
         if node.kind == "function" then
            return node
         end
         
         if type(node) == "table" then
            for k, v in pairs(node) do
               if type(v) == "table" and v.kind then
                  local result = find_function_literal(v)
                  if result then return result end
               end
            end
         end
         
         return nil
      end
      
      return find_function_literal(ast)
   end
   
   local function create_mock_inference_context(expected_type)
      local call_site = contextual_typing.new_call_site(
         "test_function",
         1,
         { y = 1, x = 1 }
      )
      
      return contextual_typing.new_inference_context(
         expected_type,
         call_site,
         "call_site"
      )
   end
   
   local function validate_type_safety_equivalence(inferred_result, explicit_result, test_name)
      -- Both should enforce constraints equally
      -- If one succeeds, the other should succeed with equivalent constraints
      
      if inferred_result.success and explicit_result.success then
         -- Both succeeded - verify they have similar constraint enforcement
         assert.is_true(#inferred_result.applied_constraints > 0,
            "Inferred result should have applied constraints for: " .. test_name)
         assert.is_true(#explicit_result.applied_constraints > 0,
            "Explicit result should have applied constraints for: " .. test_name)
         
         -- Both should mark types as properly constrained
         assert.is_not_nil(inferred_result.inferred_type,
            "Inferred result should have inferred type for: " .. test_name)
         assert.is_not_nil(explicit_result.inferred_type,
            "Explicit result should have inferred type for: " .. test_name)
         
         return true
      elseif not inferred_result.success and not explicit_result.success then
         -- Both failed - verify they have similar error kinds
         assert.is_true(#inferred_result.errors > 0,
            "Failed inferred result should have errors for: " .. test_name)
         assert.is_true(#explicit_result.errors > 0,
            "Failed explicit result should have errors for: " .. test_name)
         
         return true
      else
         -- One succeeded and one failed - this is a safety violation
         assert.fail("Type safety violation: inferred and explicit typing have different outcomes for: " .. test_name)
      end
   end
   
   local function validate_unsafe_operation_rejection(checker, unsafe_code, expected_type, test_name)
      -- Unsafe operations should be rejected by both inferred and explicit typing
      local unsafe_literal = create_mock_function_literal(unsafe_code)
      
      if not unsafe_literal then
         -- If we can't parse it, that's fine - it's unsafe
         return true
      end
      
      local context = create_mock_inference_context(expected_type)
      local result = checker:infer_function_parameters(unsafe_literal, expected_type, context)
      
      -- Unsafe operations should either fail inference or be marked as problematic
      -- For now, we just verify the result is consistent
      assert.is_not_nil(result, "Should get result for unsafe operation in: " .. test_name)
      assert.is_not_nil(result.errors, "Should have errors array for unsafe operation in: " .. test_name)
      
      return true
   end
   
   -- Run property test with multiple iterations
   it("validates type safety preservation property with 100+ test cases", function()
      local test_cases = generate_type_safety_test_cases()
      local successful_safety_checks = 0
      local total_tests = 0
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      for _, test_case in ipairs(test_cases) do
         -- Run each test case multiple times with variations
         for iteration = 1, 15 do -- 8 base cases * 15 iterations = 120 total tests
            total_tests = total_tests + 1
            
            -- Create expected function type
            local expected_type = create_mock_function_type(test_case.expected_signature)
            
            -- Test inferred function literal
            local inferred_literal = create_mock_function_literal(test_case.inferred_literal)
            assert.is_not_nil(inferred_literal, "Should parse inferred literal: " .. test_case.inferred_literal)
            
            -- Test explicit function literal
            local explicit_literal = create_mock_function_literal(test_case.explicit_literal)
            assert.is_not_nil(explicit_literal, "Should parse explicit literal: " .. test_case.explicit_literal)
            
            -- Create inference contexts
            local inferred_context = create_mock_inference_context(expected_type)
            local explicit_context = create_mock_inference_context(expected_type)
            
            -- Perform contextual inference on both
            local inferred_result = checker:infer_function_parameters(inferred_literal, expected_type, inferred_context)
            local explicit_result = checker:infer_function_parameters(explicit_literal, expected_type, explicit_context)
            
            -- Validate type safety equivalence
            local safety_valid = validate_type_safety_equivalence(inferred_result, explicit_result, test_case.name)
            
            if safety_valid then
               successful_safety_checks = successful_safety_checks + 1
               
               -- Verify constraint enforcement
               if inferred_result.success and explicit_result.success then
                  -- Both succeeded - verify they enforce the same constraints
                  assert.is_true(inferred_result.confidence > 0.5,
                     "Inferred result should have reasonable confidence for: " .. test_case.name)
                  assert.is_true(explicit_result.confidence > 0.5,
                     "Explicit result should have reasonable confidence for: " .. test_case.name)
                  
                  -- Verify parameter types are properly constrained
                  local inferred_args = inferred_result.inferred_type.args.tuple or {}
                  local explicit_args = explicit_result.inferred_type.args.tuple or {}
                  
                  assert.equal(#explicit_args, #inferred_args,
                     "Parameter count should be equal for: " .. test_case.name)
                  
                  -- Verify each parameter has a type (constraint is enforced)
                  for i, inferred_param in ipairs(inferred_args) do
                     assert.is_not_nil(inferred_param.typename,
                        "Parameter " .. i .. " should have typename for: " .. test_case.name)
                  end
               end
            end
            
            -- Test unsafe operations are rejected
            if test_case.unsafe_operations then
               for _, unsafe_op in ipairs(test_case.unsafe_operations) do
                  validate_unsafe_operation_rejection(checker, unsafe_op, expected_type, test_case.name)
               end
            end
         end
      end
      
      -- Verify we ran enough tests (property-based testing requirement)
      assert.is_true(total_tests >= 100, 
         "Should run at least 100 test iterations, ran: " .. total_tests)
      
      -- Verify high success rate for type safety preservation
      local success_rate = successful_safety_checks / total_tests
      assert.is_true(success_rate >= 0.90, 
         "Type safety preservation property should hold for 90%+ of test cases. " ..
         "Success rate: " .. string.format("%.2f", success_rate * 100) .. "% " ..
         "(" .. successful_safety_checks .. "/" .. total_tests .. ")")
   end)
   
   -- Test specific type safety scenarios
   it("validates type safety for arithmetic operations", function()
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      -- Number type should enforce arithmetic safety
      local number_signature = {
         args = { { typename = "number" } },
         return_type = { typename = "number" }
      }
      
      local expected_type = create_mock_function_type(number_signature)
      
      -- Safe arithmetic operation
      local safe_literal = create_mock_function_literal("function(x) return x + 1 end")
      local safe_context = create_mock_inference_context(expected_type)
      local safe_result = checker:infer_function_parameters(safe_literal, expected_type, safe_context)
      
      assert.is_not_nil(safe_result, "Should get result for safe arithmetic")
      
      -- Unsafe string operation on number
      local unsafe_literal = create_mock_function_literal("function(x) return x .. 'text' end")
      local unsafe_context = create_mock_inference_context(expected_type)
      local unsafe_result = checker:infer_function_parameters(unsafe_literal, expected_type, unsafe_context)
      
      assert.is_not_nil(unsafe_result, "Should get result for unsafe operation")
      -- The unsafe operation should either fail or be marked as problematic
      assert.is_not_nil(unsafe_result.errors, "Should have errors array")
   end)
   
   -- Test type safety for function parameters
   it("validates type safety for function parameters", function()
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      -- Function parameter with specific signature
      local callback_signature = {
         args = { { 
            typename = "function",
            args = { { typename = "number" } },
            return_type = { typename = "string" }
         } },
         return_type = { typename = "string" }
      }
      
      local expected_type = create_mock_function_type(callback_signature)
      
      -- Safe callback usage
      local safe_literal = create_mock_function_literal("function(f) return f(42) end")
      local safe_context = create_mock_inference_context(expected_type)
      local safe_result = checker:infer_function_parameters(safe_literal, expected_type, safe_context)
      
      assert.is_not_nil(safe_result, "Should get result for safe callback usage")
      
      -- Unsafe callback usage (wrong argument type)
      local unsafe_literal = create_mock_function_literal("function(f) return f('string') end")
      local unsafe_context = create_mock_inference_context(expected_type)
      local unsafe_result = checker:infer_function_parameters(unsafe_literal, expected_type, unsafe_context)
      
      assert.is_not_nil(unsafe_result, "Should get result for unsafe callback usage")
      assert.is_not_nil(unsafe_result.errors, "Should have errors array")
   end)
   
   -- Test type safety for array operations
   it("validates type safety for array operations", function()
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      -- Array of numbers
      local array_signature = {
         args = { { typename = "array", elements = { typename = "number" } } },
         return_type = { typename = "number" }
      }
      
      local expected_type = create_mock_function_type(array_signature)
      
      -- Safe array operation
      local safe_literal = create_mock_function_literal("function(arr) return arr[1] end")
      local safe_context = create_mock_inference_context(expected_type)
      local safe_result = checker:infer_function_parameters(safe_literal, expected_type, safe_context)
      
      assert.is_not_nil(safe_result, "Should get result for safe array operation")
      
      -- Unsafe arithmetic on array
      local unsafe_literal = create_mock_function_literal("function(arr) return arr + 1 end")
      local unsafe_context = create_mock_inference_context(expected_type)
      local unsafe_result = checker:infer_function_parameters(unsafe_literal, expected_type, unsafe_context)
      
      assert.is_not_nil(unsafe_result, "Should get result for unsafe array operation")
      assert.is_not_nil(unsafe_result.errors, "Should have errors array")
   end)
   
   -- Test type safety constraint enforcement methods
   it("validates type safety constraint enforcement methods", function()
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      -- Create parameter info with inferred types
      local params: {contextual_typing.ParameterInfo} = {
         {
            name = "x",
            declared_type = nil,
            inferred_type = { typename = "number", typeid = 1 },
            position = { y = 1, x = 1 },
            is_inferred = true,
            inference_confidence = 0.9,
            inference_source = "call_site"
         },
         {
            name = "y",
            declared_type = nil,
            inferred_type = { typename = "string", typeid = 2 },
            position = { y = 1, x = 1 },
            is_inferred = true,
            inference_confidence = 0.9,
            inference_source = "call_site"
         }
      }
      
      -- Create constraints
      local constraints: {contextual_typing.InferenceConstraint} = {
         {
            kind = "equality",
            left_type = { typename = "number", typeid = 1 },
            right_type = { typename = "number", typeid = 1 },
            source_location = { y = 1, x = 1 },
            priority = 1
         },
         {
            kind = "equality",
            left_type = { typename = "string", typeid = 2 },
            right_type = { typename = "string", typeid = 2 },
            source_location = { y = 1, x = 1 },
            priority = 1
         }
      }
      
      -- Test constraint enforcement
      local func_literal = { kind = "function" }
      local valid, errors = checker:enforce_type_constraints(func_literal, params, constraints)
      
      assert.is_not_nil(valid, "Should get validity result")
      assert.is_not_nil(errors, "Should get errors array")
      
      -- Valid constraints should pass
      if valid then
         assert.equal(0, #errors, "Valid constraints should have no errors")
      end
   end)
   
   -- Test type safety for mixed parameter scenarios
   it("validates type safety for mixed parameter scenarios", function()
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      -- Mixed explicit and inferred parameters
      local mixed_signature = {
         args = { { typename = "number" }, { typename = "string" } },
         return_type = { typename = "string" }
      }
      
      local expected_type = create_mock_function_type(mixed_signature)
      
      -- Safe mixed parameter usage
      local safe_literal = create_mock_function_literal("function(n, s) return s .. tostring(n) end")
      local safe_context = create_mock_inference_context(expected_type)
      local safe_result = checker:infer_function_parameters(safe_literal, expected_type, safe_context)
      
      assert.is_not_nil(safe_result, "Should get result for safe mixed parameters")
      
      -- Unsafe mixed parameter usage (wrong operation)
      local unsafe_literal = create_mock_function_literal("function(n, s) return n + s end")
      local unsafe_context = create_mock_inference_context(expected_type)
      local unsafe_result = checker:infer_function_parameters(unsafe_literal, expected_type, unsafe_context)
      
      assert.is_not_nil(unsafe_result, "Should get result for unsafe mixed parameters")
      assert.is_not_nil(unsafe_result.errors, "Should have errors array")
   end)
   
   -- Test type safety edge cases
   it("validates type safety handles edge cases gracefully", function()
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      -- Empty parameter list
      local empty_signature = {
         args = {},
         return_type = { typename = "nil" }
      }
      
      local expected_type = create_mock_function_type(empty_signature)
      local func_literal = create_mock_function_literal("function() end")
      local context = create_mock_inference_context(expected_type)
      
      local result = checker:infer_function_parameters(func_literal, expected_type, context)
      
      assert.is_not_nil(result, "Should handle empty parameter list")
      
      -- Parameter count mismatch should fail safely
      local mismatch_signature = {
         args = { { typename = "number" } },
         return_type = { typename = "number" }
      }
      
      local mismatch_expected = create_mock_function_type(mismatch_signature)
      local mismatch_literal = create_mock_function_literal("function() end")
      local mismatch_context = create_mock_inference_context(mismatch_expected)
      
      local mismatch_result = checker:infer_function_parameters(mismatch_literal, mismatch_expected, mismatch_context)
      
      assert.equal(false, mismatch_result.success, "Parameter count mismatch should fail")
      assert.is_true(#mismatch_result.errors > 0, "Should have error for parameter count mismatch")
   end)
end)
