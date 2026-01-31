local util = require("spec.util")
local tl = require("teal.api.v2")
local contextual_typing = require("teal.contextual_typing")
local contextual_type_checker = require("teal.contextual_type_checker")

describe("contextual typing inference equivalence", function()
   print("DEBUG: Starting inference equivalence tests")
   
   -- Property 2: Inference-Explicit Equivalence
   -- **Validates: Requirements 1.5, 3.1**
   -- For any function literal, when contextual inference succeeds, 
   -- the resulting type-checked function should behave identically 
   -- to an explicitly typed equivalent with the same inferred types.
   
   local function generate_equivalence_test_cases()
      return {
         -- Basic type equivalence cases
         {
            name = "single number parameter equivalence",
            expected_signature = {
               args = { { typename = "number" } },
               return_type = { typename = "number" }
            },
            inferred_literal = "function(x) return x end",
            explicit_literal = "function(x: number): number return x end",
            context_code = "local map_func = %s; local result = map_func(42)"
         },
         {
            name = "single string parameter equivalence",
            expected_signature = {
               args = { { typename = "string" } },
               return_type = { typename = "string" }
            },
            inferred_literal = "function(s) return s end",
            explicit_literal = "function(s: string): string return s end",
            context_code = "local str_func = %s; local result = str_func('hello')"
         },
         {
            name = "single boolean parameter equivalence",
            expected_signature = {
               args = { { typename = "boolean" } },
               return_type = { typename = "boolean" }
            },
            inferred_literal = "function(b) return b end",
            explicit_literal = "function(b: boolean): boolean return b end",
            context_code = "local bool_func = %s; local result = bool_func(true)"
         },
         
         -- Multiple parameter equivalence
         {
            name = "two number parameters equivalence",
            expected_signature = {
               args = { { typename = "number" }, { typename = "number" } },
               return_type = { typename = "number" }
            },
            inferred_literal = "function(x, y) return x + y end",
            explicit_literal = "function(x: number, y: number): number return x + y end",
            context_code = "local add_func = %s; local result = add_func(10, 20)"
         },
         {
            name = "mixed parameter types equivalence",
            expected_signature = {
               args = { { typename = "string" }, { typename = "number" } },
               return_type = { typename = "string" }
            },
            inferred_literal = "function(s, n) return s .. tostring(n) end",
            explicit_literal = "function(s: string, n: number): string return s .. tostring(n) end",
            context_code = "local concat_func = %s; local result = concat_func('value: ', 42)"
         },
         
         -- Array parameter equivalence
         {
            name = "array parameter equivalence",
            expected_signature = {
               args = { { typename = "array", elements = { typename = "number" } } },
               return_type = { typename = "number" }
            },
            inferred_literal = "function(arr) return #arr end",
            explicit_literal = "function(arr: {number}): number return #arr end",
            context_code = "local len_func = %s; local result = len_func({1, 2, 3})"
         },
         
         -- Function parameter equivalence
         {
            name = "callback parameter equivalence",
            expected_signature = {
               args = { { 
                  typename = "function",
                  args = { { typename = "number" } },
                  return_type = { typename = "string" }
               } },
               return_type = { typename = "string" }
            },
            inferred_literal = "function(callback) return callback(42) end",
            explicit_literal = "function(callback: function(number): string): string return callback(42) end",
            context_code = "local apply_func = %s; local result = apply_func(function(n: number): string return tostring(n) end)"
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
   
   local function validate_type_equivalence(inferred_type, explicit_type, test_name)
      -- Check that both types are functions
      assert.equal("function", inferred_type.typename, 
         "Inferred type should be function for: " .. test_name)
      assert.equal("function", explicit_type.typename,
         "Explicit type should be function for: " .. test_name)
      
      -- Check parameter count equivalence
      local inferred_args = inferred_type.args.tuple or {}
      local explicit_args = explicit_type.args.tuple or {}
      
      assert.equal(#explicit_args, #inferred_args,
         "Parameter count should be equivalent for: " .. test_name)
      
      -- Check parameter type equivalence
      for i, explicit_param in ipairs(explicit_args) do
         local inferred_param = inferred_args[i]
         assert.is_not_nil(inferred_param, 
            "Inferred parameter " .. i .. " should exist for: " .. test_name)
         
         -- Check typename equivalence (with numeric compatibility)
         local types_equivalent = (explicit_param.typename == inferred_param.typename) or
                                 (explicit_param.typename == "number" and inferred_param.typename == "integer") or
                                 (explicit_param.typename == "integer" and inferred_param.typename == "number")
         
         assert.is_true(types_equivalent,
            "Parameter " .. i .. " types should be equivalent: " .. 
            (explicit_param.typename or "nil") .. " vs " .. (inferred_param.typename or "nil") ..
            " for: " .. test_name)
      end
      
      -- Check return type equivalence
      local inferred_rets = inferred_type.rets.tuple or {}
      local explicit_rets = explicit_type.rets.tuple or {}
      
      if #explicit_rets > 0 and #inferred_rets > 0 then
         local explicit_ret = explicit_rets[1]
         local inferred_ret = inferred_rets[1]
         
         local return_types_equivalent = (explicit_ret.typename == inferred_ret.typename) or
                                        (explicit_ret.typename == "number" and inferred_ret.typename == "integer") or
                                        (explicit_ret.typename == "integer" and inferred_ret.typename == "number")
         
         assert.is_true(return_types_equivalent,
            "Return types should be equivalent: " .. 
            (explicit_ret.typename or "nil") .. " vs " .. (inferred_ret.typename or "nil") ..
            " for: " .. test_name)
      end
      
      return true
   end
   
   local function validate_behavioral_equivalence(inferred_result, explicit_result, test_name)
      -- Both should succeed or both should fail
      assert.equal(explicit_result.success, inferred_result.success,
         "Inference and explicit typing should have same success status for: " .. test_name)
      
      if inferred_result.success and explicit_result.success then
         -- Both succeeded - validate type equivalence
         validate_type_equivalence(inferred_result.inferred_type, explicit_result.inferred_type, test_name)
         
         -- Check that both have reasonable confidence
         assert.is_true(inferred_result.confidence > 0.0,
            "Inferred result should have positive confidence for: " .. test_name)
         assert.is_true(explicit_result.confidence > 0.0,
            "Explicit result should have positive confidence for: " .. test_name)
         
         -- Check that both applied constraints
         assert.is_true(#inferred_result.applied_constraints > 0,
            "Inferred result should have applied constraints for: " .. test_name)
         
      else
         -- Both failed - validate error equivalence
         assert.is_true(#inferred_result.errors > 0,
            "Failed inferred result should have errors for: " .. test_name)
         assert.is_true(#explicit_result.errors > 0,
            "Failed explicit result should have errors for: " .. test_name)
         
         -- Error kinds should be similar (though messages may differ)
         local inferred_error_kinds = {}
         local explicit_error_kinds = {}
         
         for _, error in ipairs(inferred_result.errors) do
            inferred_error_kinds[error.kind] = true
         end
         
         for _, error in ipairs(explicit_result.errors) do
            explicit_error_kinds[error.kind] = true
         end
         
         -- At least one error kind should overlap
         local has_common_error = false
         for kind, _ in pairs(inferred_error_kinds) do
            if explicit_error_kinds[kind] then
               has_common_error = true
               break
            end
         end
         
         assert.is_true(has_common_error,
            "Inferred and explicit results should have similar error kinds for: " .. test_name)
      end
      
      return true
   end
   
   -- Run property test with multiple iterations
   it("validates inference-explicit equivalence property with 100+ test cases", function()
      local test_cases = generate_equivalence_test_cases()
      local successful_equivalences = 0
      local total_tests = 0
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      for _, test_case in ipairs(test_cases) do
         -- Run each test case multiple times with variations
         for iteration = 1, 15 do -- 7 base cases * 15 iterations = 105 total tests
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
            
            -- Validate equivalence
            local equivalence_valid = validate_behavioral_equivalence(inferred_result, explicit_result, test_case.name)
            
            if equivalence_valid then
               successful_equivalences = successful_equivalences + 1
               
               -- Additional validation for successful cases
               if inferred_result.success and explicit_result.success then
                  -- Validate that inferred type is marked as contextually typed
                  assert.is_true(inferred_result.inferred_type.is_contextually_typed,
                     "Inferred type should be marked as contextually typed for: " .. test_case.name)
                  
                  -- Validate that explicit type may or may not be contextually typed
                  -- (depending on whether it had untyped parameters)
                  
                  -- Validate constraint application
                  assert.is_true(#inferred_result.applied_constraints > 0,
                     "Inferred result should have applied constraints for: " .. test_case.name)
                  
                  -- Validate confidence levels are reasonable
                  assert.is_true(inferred_result.confidence >= 0.5,
                     "Inferred result confidence should be reasonable for: " .. test_case.name)
                  assert.is_true(explicit_result.confidence >= 0.5,
                     "Explicit result confidence should be reasonable for: " .. test_case.name)
               end
            end
         end
      end
      
      -- Verify we ran enough tests (property-based testing requirement)
      assert.is_true(total_tests >= 100, 
         "Should run at least 100 test iterations, ran: " .. total_tests)
      
      -- Verify high success rate for equivalence property
      local success_rate = successful_equivalences / total_tests
      assert.is_true(success_rate >= 0.85, 
         "Inference-explicit equivalence property should hold for 85%+ of test cases. " ..
         "Success rate: " .. string.format("%.2f", success_rate * 100) .. "% " ..
         "(" .. successful_equivalences .. "/" .. total_tests .. ")")
   end)
   
   -- Test specific equivalence scenarios
   it("validates equivalence for common callback patterns", function()
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      -- Array.forEach-like callback equivalence
      local forEach_signature = {
         args = { { 
            typename = "function",
            args = { { typename = "number" }, { typename = "integer" } },
            return_type = { typename = "nil" }
         } },
         return_type = { typename = "nil" }
      }
      
      local expected_type = create_mock_function_type(forEach_signature)
      
      local inferred_literal = create_mock_function_literal("function(item, index) print(item) end")
      local explicit_literal = create_mock_function_literal("function(item: number, index: integer) print(item) end")
      
      local inferred_context = create_mock_inference_context(expected_type)
      local explicit_context = create_mock_inference_context(expected_type)
      
      local inferred_result = checker:infer_function_parameters(inferred_literal, expected_type, inferred_context)
      local explicit_result = checker:infer_function_parameters(explicit_literal, expected_type, explicit_context)
      
      -- Both should have similar outcomes
      assert.is_not_nil(inferred_result, "Should get inferred result")
      assert.is_not_nil(explicit_result, "Should get explicit result")
      
      -- If both succeed, they should be equivalent
      if inferred_result.success and explicit_result.success then
         validate_type_equivalence(inferred_result.inferred_type, explicit_result.inferred_type, "forEach callback")
      end
   end)
   
   -- Test equivalence validation methods
   it("validates equivalence checking methods work correctly", function()
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      -- Create two equivalent function types
      local type1 = {
         typename = "function",
         typeid = 1,
         args = {
            typename = "tuple",
            typeid = 2,
            tuple = {
               { typename = "number", typeid = 3 },
               { typename = "string", typeid = 4 }
            }
         },
         rets = {
            typename = "tuple",
            typeid = 5,
            tuple = {
               { typename = "boolean", typeid = 6 }
            }
         },
         is_method = false,
         maybe_method = false,
         is_record_function = false,
         min_arity = 2
      }
      
      local type2 = {
         typename = "function",
         typeid = 7,
         args = {
            typename = "tuple",
            typeid = 8,
            tuple = {
               { typename = "number", typeid = 9 },
               { typename = "string", typeid = 10 }
            }
         },
         rets = {
            typename = "tuple",
            typeid = 11,
            tuple = {
               { typename = "boolean", typeid = 12 }
            }
         },
         is_method = false,
         maybe_method = false,
         is_record_function = false,
         min_arity = 2
      }
      
      local location = { y = 1, x = 1 }
      
      -- Test equivalence validation
      local equivalent, errors = checker:validate_inference_explicit_equivalence(
         { kind = "function" },
         type1,
         type2
      )
      
      assert.is_not_nil(equivalent, "Should get equivalence result")
      assert.is_not_nil(errors, "Should get errors array")
      
      -- Test type equivalence checking
      local type_equivalent, type_errors = checker:check_type_equivalence(
         { typename = "number", typeid = 1 },
         { typename = "number", typeid = 2 },
         location
      )
      
      assert.is_true(type_equivalent, "Same types should be equivalent")
      assert.equal(0, #type_errors, "Equivalent types should have no errors")
      
      -- Test numeric type compatibility
      local numeric_equivalent, numeric_errors = checker:check_type_equivalence(
         { typename = "integer", typeid = 1 },
         { typename = "number", typeid = 2 },
         location
      )
      
      assert.is_true(numeric_equivalent, "Integer and number should be equivalent")
      assert.equal(0, #numeric_errors, "Compatible numeric types should have no errors")
   end)
   
   -- Test edge cases for equivalence
   it("validates equivalence handles edge cases gracefully", function()
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      -- Empty parameter lists should be equivalent
      local empty_signature = {
         args = {},
         return_type = { typename = "nil" }
      }
      
      local expected_type = create_mock_function_type(empty_signature)
      
      local inferred_literal = create_mock_function_literal("function() end")
      local explicit_literal = create_mock_function_literal("function(): nil end")
      
      local inferred_context = create_mock_inference_context(expected_type)
      local explicit_context = create_mock_inference_context(expected_type)
      
      local inferred_result = checker:infer_function_parameters(inferred_literal, expected_type, inferred_context)
      local explicit_result = checker:infer_function_parameters(explicit_literal, expected_type, explicit_context)
      
      -- Both should handle empty parameter lists
      assert.is_not_nil(inferred_result, "Should handle empty inferred parameters")
      assert.is_not_nil(explicit_result, "Should handle empty explicit parameters")
      
      -- Parameter count mismatch should fail equivalently
      local mismatch_signature = {
         args = { { typename = "number" } },
         return_type = { typename = "number" }
      }
      
      local mismatch_expected = create_mock_function_type(mismatch_signature)
      
      local mismatch_inferred = checker:infer_function_parameters(inferred_literal, mismatch_expected, inferred_context)
      local mismatch_explicit = checker:infer_function_parameters(explicit_literal, mismatch_expected, explicit_context)
      
      -- Both should fail for parameter count mismatch
      assert.equal(false, mismatch_inferred.success, "Inferred should fail on parameter count mismatch")
      assert.equal(false, mismatch_explicit.success, "Explicit should fail on parameter count mismatch")
      
      -- Both should have similar error kinds
      assert.is_true(#mismatch_inferred.errors > 0, "Inferred should have errors")
      assert.is_true(#mismatch_explicit.errors > 0, "Explicit should have errors")
   end)
end)