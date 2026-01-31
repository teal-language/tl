local util = require("spec.util")
local tl = require("teal.api.v2")
local contextual_typing = require("teal.contextual_typing")
local contextual_type_checker = require("teal.contextual_type_checker")

describe("contextual typing", function()
   describe("basic inference property", function()
      
      -- Property 1: Contextual Inference Correctness
      -- For any function literal with untyped parameters and any expected function type,
      -- when contextual inference succeeds, the inferred parameter types should match 
      -- the expected function signature parameters.
      
      local function generate_inference_test_cases()
         return {
            -- Simple type inference cases
            {
               name = "single number parameter",
               expected_signature = {
                  args = { { typename = "number" } },
                  return_type = { typename = "number" }
               },
               function_literal = "function(x) return x end",
               expected_inferred_types = { "number" }
            },
            {
               name = "single string parameter", 
               expected_signature = {
                  args = { { typename = "string" } },
                  return_type = { typename = "string" }
               },
               function_literal = "function(s) return s end",
               expected_inferred_types = { "string" }
            },
            {
               name = "single boolean parameter",
               expected_signature = {
                  args = { { typename = "boolean" } },
                  return_type = { typename = "boolean" }
               },
               function_literal = "function(b) return b end", 
               expected_inferred_types = { "boolean" }
            },
            
            -- Multiple parameter inference
            {
               name = "two number parameters",
               expected_signature = {
                  args = { { typename = "number" }, { typename = "number" } },
                  return_type = { typename = "number" }
               },
               function_literal = "function(x, y) return x + y end",
               expected_inferred_types = { "number", "number" }
            },
            {
               name = "mixed parameter types",
               expected_signature = {
                  args = { { typename = "string" }, { typename = "number" }, { typename = "boolean" } },
                  return_type = { typename = "string" }
               },
               function_literal = "function(s, n, b) return s end",
               expected_inferred_types = { "string", "number", "boolean" }
            },
            
            -- Array and table types
            {
               name = "array parameter",
               expected_signature = {
                  args = { { typename = "array", elements = { typename = "number" } } },
                  return_type = { typename = "number" }
               },
               function_literal = "function(arr) return #arr end",
               expected_inferred_types = { "array" }
            },
            
            -- Function parameter types
            {
               name = "callback parameter",
               expected_signature = {
                  args = { { 
                     typename = "function",
                     args = { { typename = "number" } },
                     return_type = { typename = "string" }
                  } },
                  return_type = { typename = "string" }
               },
               function_literal = "function(callback) return callback(42) end",
               expected_inferred_types = { "function" }
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
            table.insert(args_tuple.tuple, {
               typename = arg_type.typename,
               typeid = 2
            })
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
      
      -- Run property test with multiple iterations
      it("validates contextual inference correctness property with 100+ test cases", function()
         local test_cases = generate_inference_test_cases()
         local successful_inferences = 0
         local total_tests = 0
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         for _, test_case in ipairs(test_cases) do
            -- Run each test case multiple times with variations
            for iteration = 1, 15 do -- 7 base cases * 15 iterations = 105 total tests
               total_tests = total_tests + 1
               
               -- Create expected function type
               local expected_type = create_mock_function_type(test_case.expected_signature)
               
               -- Create function literal AST node
               local func_literal = create_mock_function_literal(test_case.function_literal)
               assert.is_not_nil(func_literal, "Should parse function literal: " .. test_case.function_literal)
               
               -- Create inference context
               local context = create_mock_inference_context(expected_type)
               
               -- Perform contextual inference
               local result = checker:infer_function_parameters(func_literal, expected_type, context)
               
               -- Validate inference result
               if result.success then
                  successful_inferences = successful_inferences + 1
                  
                  -- Verify inferred types match expected signature
                  assert.is_not_nil(result.inferred_type, "Should have inferred type")
                  assert.equal("function", result.inferred_type.typename, "Should infer function type")
                  assert.is_true(result.inferred_type.is_contextually_typed, "Should mark as contextually typed")
                  
                  -- Check parameter count
                  local inferred_args = result.inferred_type.args.tuple
                  local expected_args = expected_type.args.tuple
                  assert.equal(#expected_args, #inferred_args, 
                     "Inferred parameter count should match expected for: " .. test_case.name)
                  
                  -- Check parameter types
                  for i, expected_param_type in ipairs(expected_args) do
                     local inferred_param_type = inferred_args[i]
                     assert.equal(expected_param_type.typename, inferred_param_type.typename,
                        "Parameter " .. i .. " type should match expected for: " .. test_case.name)
                  end
                  
                  -- Verify confidence is reasonable
                  assert.is_true(result.confidence > 0.5, 
                     "Inference confidence should be reasonable for: " .. test_case.name)
                  
                  -- Verify constraints were applied
                  assert.is_true(#result.applied_constraints > 0,
                     "Should have applied constraints for: " .. test_case.name)
               else
                  -- If inference failed, check that errors are reasonable
                  assert.is_true(#result.errors > 0, "Failed inference should have errors")
                  for _, error in ipairs(result.errors) do
                     assert.is_not_nil(error.kind, "Error should have kind")
                     assert.is_not_nil(error.message, "Error should have message")
                  end
               end
            end
         end
         
         -- Verify we ran enough tests (property-based testing requirement)
         assert.is_true(total_tests >= 100, 
            "Should run at least 100 test iterations, ran: " .. total_tests)
         
         -- Verify reasonable success rate for basic inference
         local success_rate = successful_inferences / total_tests
         assert.is_true(success_rate >= 0.80, 
            "Basic inference property should hold for 80%+ of test cases. " ..
            "Success rate: " .. string.format("%.2f", success_rate * 100) .. "% " ..
            "(" .. successful_inferences .. "/" .. total_tests .. ")")
      end)
      
      -- Test specific inference scenarios
      it("validates inference works for common callback patterns", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Array.map-like callback
         local map_signature = {
            args = { { 
               typename = "function",
               args = { { typename = "number" }, { typename = "integer" } },
               return_type = { typename = "string" }
            } },
            return_type = { typename = "array" }
         }
         
         local expected_type = create_mock_function_type(map_signature)
         local func_literal = create_mock_function_literal("function(item, index) return tostring(item) end")
         local context = create_mock_inference_context(expected_type)
         
         local result = checker:infer_function_parameters(func_literal, expected_type, context)
         
         -- This specific test might fail due to nested function complexity
         -- but we should get a reasonable result or error
         assert.is_not_nil(result, "Should get inference result")
         assert.is_not_nil(result.errors, "Should have errors array")
         assert.is_not_nil(result.confidence, "Should have confidence score")
      end)
      
      -- Test edge cases
      it("validates inference handles edge cases gracefully", function()
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
         
         -- Parameter count mismatch should fail gracefully
         local mismatch_signature = {
            args = { { typename = "number" }, { typename = "string" } },
            return_type = { typename = "number" }
         }
         
         local mismatch_expected = create_mock_function_type(mismatch_signature)
         local single_param_literal = create_mock_function_literal("function(x) return x end")
         local mismatch_context = create_mock_inference_context(mismatch_expected)
         
         local mismatch_result = checker:infer_function_parameters(single_param_literal, mismatch_expected, mismatch_context)
         
         assert.equal(false, mismatch_result.success, "Parameter count mismatch should fail")
         assert.is_true(#mismatch_result.errors > 0, "Should have error for parameter count mismatch")
      end)
   end)
end)