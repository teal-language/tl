local util = require("spec.util")
local tl = require("teal.api.v2")
local contextual_typing = require("teal.contextual_typing")
local contextual_type_checker = require("teal.contextual_type_checker")

describe("contextual typing", function()
   describe("inference fallback mechanisms", function()
      
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
      
      -- Test scenarios with no contextual information
      describe("no contextual information scenarios", function()
         
         it("handles function literal with no context gracefully", function()
            local checker = contextual_type_checker.BaseContextualTypeChecker:new()
            local func_literal = create_mock_function_literal("function(x, y) return x + y end")
            
            local result = checker:handle_no_context_inference(func_literal)
            
            assert.equal(false, result.success, "Should fail when no context available")
            assert.is_true(#result.errors > 0, "Should have errors")
            assert.equal("no_contextual_information", result.errors[1].kind, "Should have correct error kind")
            assert.is_not_nil(result.errors[1].suggested_fix, "Should provide suggested fix")
            assert.is_true(#result.applied_constraints > 0, "Should have applied fallback constraints")
         end)
         
         it("provides helpful suggestions when no context available", function()
            local checker = contextual_type_checker.BaseContextualTypeChecker:new()
            local func_literal = create_mock_function_literal("function(a, b, c) return a end")
            
            local result = checker:handle_no_context_inference(func_literal)
            
            assert.equal(false, result.success, "Should fail gracefully")
            assert.is_not_nil(result.errors[1].suggested_fix, "Should provide suggestion")
            assert.is_true(string.find(result.errors[1].suggested_fix, "explicit type annotations") ~= nil,
               "Should suggest explicit type annotations")
         end)
         
         it("handles empty parameter list with no context", function()
            local checker = contextual_type_checker.BaseContextualTypeChecker:new()
            local func_literal = create_mock_function_literal("function() return 42 end")
            
            local result = checker:handle_no_context_inference(func_literal)
            
            assert.equal(false, result.success, "Should fail when no context")
            assert.is_true(#result.errors > 0, "Should have errors")
            assert.equal("no_contextual_information", result.errors[1].kind)
         end)
         
      end)
      
      -- Test partial inference for mixed parameter scenarios
      describe("mixed parameter scenarios", function()
         
         it("performs partial inference with mixed typed and untyped parameters", function()
            local checker = contextual_type_checker.BaseContextualTypeChecker:new()
            local func_literal = create_mock_function_literal("function(x: number, y, z: string) return x end")
            
            local result: contextual_typing.InferenceResult = {
               success = false,
               inferred_type = nil,
               errors = {},
               warnings = {},
               confidence = 0.0,
               applied_constraints = {}
            }
            
            local partial_success = checker:attempt_partial_inference(func_literal, result)
            
            assert.equal(true, partial_success, "Should succeed with partial inference")
            assert.is_not_nil(result.inferred_type, "Should create partial function type")
            assert.equal("function", result.inferred_type.typename, "Should be function type")
            assert.is_true(result.inferred_type.is_contextually_typed, "Should mark as contextually typed")
            
            -- Check that we have the right number of parameters
            local args = result.inferred_type.args.tuple
            assert.equal(3, #args, "Should have 3 parameters")
            
            -- Check parameter types (explicit types preserved, untyped become 'any')
            assert.equal("number", args[1].typename, "First parameter should be number")
            assert.equal("any", args[2].typename, "Second parameter should fallback to any")
            assert.equal("string", args[3].typename, "Third parameter should be string")
         end)
         
         it("handles all untyped parameters with partial inference", function()
            local checker = contextual_type_checker.BaseContextualTypeChecker:new()
            local func_literal = create_mock_function_literal("function(a, b, c) return a + b end")
            
            local result: contextual_typing.InferenceResult = {
               success = false,
               inferred_type = nil,
               errors = {},
               warnings = {},
               confidence = 0.0,
               applied_constraints = {}
            }
            
            local partial_success = checker:attempt_partial_inference(func_literal, result)
            
            assert.equal(false, partial_success, "Should fail with all untyped parameters")
            assert.is_nil(result.inferred_type, "Should not create function type")
         end)
         
         it("handles single typed parameter with untyped parameters", function()
            local checker = contextual_type_checker.BaseContextualTypeChecker:new()
            local func_literal = create_mock_function_literal("function(x: boolean, y, z) return x end")
            
            local result: contextual_typing.InferenceResult = {
               success = false,
               inferred_type = nil,
               errors = {},
               warnings = {},
               confidence = 0.0,
               applied_constraints = {}
            }
            
            local partial_success = checker:attempt_partial_inference(func_literal, result)
            
            assert.equal(true, partial_success, "Should succeed with mixed parameters")
            assert.is_not_nil(result.inferred_type, "Should create partial function type")
            
            local args = result.inferred_type.args.tuple
            assert.equal(3, #args, "Should have 3 parameters")
            assert.equal("boolean", args[1].typename, "First parameter should be boolean")
            assert.equal("any", args[2].typename, "Second parameter should fallback to any")
            assert.equal("any", args[3].typename, "Third parameter should fallback to any")
         end)
         
         it("preserves all explicit types when no untyped parameters", function()
            local checker = contextual_type_checker.BaseContextualTypeChecker:new()
            local func_literal = create_mock_function_literal("function(x: number, y: string) return x end")
            
            local result: contextual_typing.InferenceResult = {
               success = false,
               inferred_type = nil,
               errors = {},
               warnings = {},
               confidence = 0.0,
               applied_constraints = {}
            }
            
            local partial_success = checker:attempt_partial_inference(func_literal, result)
            
            assert.equal(true, partial_success, "Should succeed with all typed parameters")
            assert.is_not_nil(result.inferred_type, "Should create function type")
            
            local args = result.inferred_type.args.tuple
            assert.equal(2, #args, "Should have 2 parameters")
            assert.equal("number", args[1].typename, "First parameter should be number")
            assert.equal("string", args[2].typename, "Second parameter should be string")
         end)
         
      end)
      
      -- Test error message generation
      describe("error message generation", function()
         
         it("generates clear error messages for no contextual information", function()
            local checker = contextual_type_checker.BaseContextualTypeChecker:new()
            local func_literal = create_mock_function_literal("function(x, y) return x + y end")
            
            local result = checker:handle_no_context_inference(func_literal)
            
            assert.equal(false, result.success, "Should fail")
            assert.is_true(#result.errors > 0, "Should have errors")
            
            local error = result.errors[1]
            assert.equal("no_contextual_information", error.kind, "Should have correct error kind")
            assert.is_not_nil(error.message, "Should have error message")
            assert.is_true(string.len(error.message) > 0, "Error message should not be empty")
            assert.is_true(string.find(error.message, "Cannot infer parameter types") ~= nil,
               "Should mention inability to infer parameter types")
            assert.is_not_nil(error.suggested_fix, "Should provide suggested fix")
            assert.is_true(string.find(error.suggested_fix, "explicit type annotations") ~= nil,
               "Should suggest explicit type annotations")
         end)
         
         it("generates helpful suggestions based on function body analysis", function()
            local checker = contextual_type_checker.BaseContextualTypeChecker:new()
            local func_literal = create_mock_function_literal("function(a, b) return a * b + 1 end")
            
            local result = checker:handle_no_context_inference(func_literal)
            
            assert.equal(false, result.success, "Should fail")
            assert.is_true(#result.warnings > 0, "Should have warnings with suggestions")
            
            local warning = result.warnings[1]
            assert.is_not_nil(warning.message, "Should have warning message")
            assert.is_true(string.find(warning.message, "Suggestions based on function body") ~= nil,
               "Should provide function body analysis suggestions")
            assert.is_true(warning.confidence_level <= 0.5, "Should have low confidence for suggestions")
         end)
         
         it("generates appropriate error messages for mixed parameter conflicts", function()
            local checker = contextual_type_checker.BaseContextualTypeChecker:new()
            local func_literal = create_mock_function_literal("function(x: number, y, z: string) return x end")
            
            -- Create a mock expected type that conflicts with explicit types
            local expected_type: contextual_typing.FunctionType = {
               typename = "function",
               typeid = 100,
               args = {
                  typename = "tuple",
                  typeid = 101,
                  tuple = {
                     { typename = "string", typeid = 102 },  -- Conflicts with x: number
                     { typename = "boolean", typeid = 103 }, -- For y (untyped)
                     { typename = "number", typeid = 104 }   -- Conflicts with z: string
                  }
               },
               rets = {
                  typename = "tuple",
                  typeid = 105,
                  tuple = { { typename = "number", typeid = 106 } }
               }
            }
            
            local context = create_mock_inference_context(expected_type)
            local result = checker:infer_function_parameters(func_literal, expected_type, context)
            
            assert.equal(false, result.success, "Should fail due to type conflicts")
            assert.is_true(#result.errors > 0, "Should have errors")
            
            -- Check for parameter type mismatch errors
            local has_mismatch_error = false
            for _, error in ipairs(result.errors) do
               if error.kind == "incompatible_signature" and 
                  string.find(error.message, "type mismatch") then
                  has_mismatch_error = true
                  assert.is_not_nil(error.suggested_fix, "Should provide suggested fix")
                  break
               end
            end
            assert.is_true(has_mismatch_error, "Should have parameter type mismatch error")
         end)
         
         it("provides contextual suggestions for different error types", function()
            local checker = contextual_type_checker.BaseContextualTypeChecker:new()
            local func_literal = create_mock_function_literal("function(x, y) return x end")
            
            -- Test different error scenarios and their suggestions
            local test_cases = {
               {
                  error_kind = "no_contextual_information",
                  expected_suggestion = "explicit type annotations"
               },
               {
                  error_kind = "ambiguous_inference", 
                  expected_suggestion = "explicit types to resolve ambiguity"
               },
               {
                  error_kind = "incompatible_signature",
                  expected_suggestion = "parameter count and types match"
               },
               {
                  error_kind = "constraint_violation",
                  expected_suggestion = "generic constraints are satisfied"
               }
            }
            
            for _, test_case in ipairs(test_cases) do
               -- Create a mock error of the specified kind
               local mock_error = contextual_typing.new_inference_error(
                  test_case.error_kind,
                  func_literal,
                  "Test error message",
                  nil,
                  nil
               )
               
               local result = checker:handle_inference_fallback(func_literal, { mock_error })
               
               assert.is_true(#result.errors > 0, "Should have errors")
               local error = result.errors[1]
               assert.is_not_nil(error.suggested_fix, "Should provide suggested fix")
               assert.is_true(string.find(error.suggested_fix, test_case.expected_suggestion) ~= nil,
                  string.format("Should suggest '%s' for error kind '%s'", 
                               test_case.expected_suggestion, test_case.error_kind))
            end
         end)
         
         it("includes location information in error messages", function()
            local checker = contextual_type_checker.BaseContextualTypeChecker:new()
            local func_literal = create_mock_function_literal("function(x, y) return x + y end")
            
            local result = checker:handle_no_context_inference(func_literal)
            
            assert.equal(false, result.success, "Should fail")
            assert.is_true(#result.errors > 0, "Should have errors")
            
            local error = result.errors[1]
            assert.is_not_nil(error.location, "Should have location information")
            assert.equal(func_literal, error.location, "Location should point to function literal")
         end)
         
         it("generates warnings for fallback inference usage", function()
            local checker = contextual_type_checker.BaseContextualTypeChecker:new()
            local func_literal = create_mock_function_literal("function(x: number, y) return x end")
            
            local result: contextual_typing.InferenceResult = {
               success = false,
               inferred_type = nil,
               errors = {},
               warnings = {},
               confidence = 0.0,
               applied_constraints = {}
            }
            
            local partial_success = checker:attempt_partial_inference(func_literal, result)
            
            if partial_success then
               -- Simulate the fallback process that adds warnings
               local fallback_result = checker:handle_inference_fallback(func_literal, {})
               
               assert.is_true(#fallback_result.warnings > 0, "Should have warnings")
               local warning = fallback_result.warnings[1]
               assert.is_true(string.find(warning.message, "fallback inference") ~= nil,
                  "Should mention fallback inference usage")
               assert.is_true(warning.confidence_level < 1.0, "Should have reduced confidence")
            end
         end)
         
      end)
      
      -- Test integration scenarios
      describe("integration with inference engine", function()
         
         it("gracefully degrades when no context is available", function()
            local checker = contextual_type_checker.BaseContextualTypeChecker:new()
            local func_literal = create_mock_function_literal("function(x, y) return x + y end")
            
            local result = checker:infer_with_graceful_degradation(func_literal, nil)
            
            assert.equal(false, result.success, "Should fail gracefully")
            assert.is_true(#result.errors > 0, "Should have errors")
            assert.equal("no_contextual_information", result.errors[1].kind, "Should have correct error kind")
            assert.is_true(#result.applied_constraints > 0, "Should apply fallback constraints")
         end)
         
         it("handles invalid expected type gracefully", function()
            local checker = contextual_type_checker.BaseContextualTypeChecker:new()
            local func_literal = create_mock_function_literal("function(x) return x end")
            
            -- Create context with non-function expected type
            local invalid_expected_type = { typename = "number", typeid = 200 }
            local call_site = contextual_typing.new_call_site("test", 1, { y = 1, x = 1 })
            local context = contextual_typing.new_inference_context(
               invalid_expected_type, call_site, "call_site"
            )
            
            local result = checker:infer_with_graceful_degradation(func_literal, context)
            
            assert.equal(false, result.success, "Should fail gracefully")
            assert.is_true(#result.errors > 0, "Should have errors")
            assert.equal("incompatible_signature", result.errors[1].kind, "Should detect type mismatch")
            assert.is_true(string.find(result.errors[1].message, "not a function type") ~= nil,
               "Should explain the type mismatch")
         end)
         
         it("attempts fallback when normal inference fails", function()
            local checker = contextual_type_checker.BaseContextualTypeChecker:new()
            local func_literal = create_mock_function_literal("function(x: number, y) return x end")
            
            -- Create an incompatible expected type to force inference failure
            local incompatible_type: contextual_typing.FunctionType = {
               typename = "function",
               typeid = 300,
               args = {
                  typename = "tuple",
                  typeid = 301,
                  tuple = {
                     { typename = "string", typeid = 302 }  -- Only one param, but function has two
                  }
               },
               rets = {
                  typename = "tuple", 
                  typeid = 303,
                  tuple = { { typename = "number", typeid = 304 } }
               }
            }
            
            local context = create_mock_inference_context(incompatible_type)
            local result = checker:infer_with_fallback(func_literal, incompatible_type, context)
            
            -- Should attempt fallback after normal inference fails
            assert.equal(false, result.success, "Should fail due to incompatibility")
            assert.is_true(#result.errors > 0, "Should have errors from failed inference")
            assert.is_true(checker.performance_stats.fallback_used, "Should have used fallback")
         end)
         
      end)
      
   end)
end)