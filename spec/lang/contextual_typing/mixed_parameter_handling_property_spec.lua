local util = require("spec.util")
local tl = require("teal.api.v2")
local contextual_typing = require("teal.contextual_typing")
local contextual_type_checker = require("teal.contextual_type_checker")
local mixed_parameter_handler = require("teal.mixed_parameter_handler")

describe("contextual typing", function()
   describe("mixed parameter handling - Property 9", function()
      
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
      
      local function create_function_type(param_types, return_type)
         local tuple_elements = {}
         for _, ptype in ipairs(param_types) do
            table.insert(tuple_elements, ptype)
         end
         
         return {
            typename = "function",
            typeid = 100,
            args = {
               typename = "tuple",
               typeid = 101,
               tuple = tuple_elements,
               inferred_at = { y = 1, x = 1 },
               needs_compat = false
            },
            rets = {
               typename = "tuple",
               typeid = 102,
               tuple = { return_type or { typename = "any", typeid = 103 } },
               inferred_at = { y = 1, x = 1 },
               needs_compat = false
            },
            inferred_at = { y = 1, x = 1 },
            needs_compat = false,
            is_method = false,
            maybe_method = false,
            is_record_function = false,
            min_arity = #tuple_elements
         }
      end
      
      -- Property 9: Mixed Parameter Handling
      -- For any function literal with both explicitly typed and untyped parameters,
      -- the type checker should use explicit types where provided and infer types
      -- only for untyped parameters.
      -- **Validates: Requirements 5.2, 7.4**
      
      describe("Property 9: Mixed Parameter Handling", function()
         
         it("uses explicit types where provided in mixed parameters", function()
            local handler = mixed_parameter_handler.MixedParameterHandler:new()
            
            -- Test case: function(x: number, y, z: string)
            local func_literal = create_mock_function_literal(
               "function(x: number, y, z: string) return x end"
            )
            
            local param_info = contextual_typing.extract_parameter_info(func_literal)
            
            -- Create expected type
            local expected_type = create_function_type({
               { typename = "number", typeid = 200 },
               { typename = "boolean", typeid = 201 },
               { typename = "string", typeid = 202 }
            })
            
            local context = create_mock_inference_context(expected_type)
            
            -- Resolve mixed parameters
            local resolved_params, errors = handler:resolve_mixed_parameters(
               param_info, expected_type, context
            )
            
            -- Verify explicit types are preserved
            assert.equal(3, #resolved_params, "Should have 3 parameters")
            assert.equal("number", resolved_params[1].inferred_type.typename,
               "First parameter should use explicit type 'number'")
            assert.equal(false, resolved_params[1].is_inferred,
               "First parameter should not be marked as inferred")
            
            -- Verify untyped parameter is inferred
            assert.equal("boolean", resolved_params[2].inferred_type.typename,
               "Second parameter should be inferred as 'boolean'")
            assert.equal(true, resolved_params[2].is_inferred,
               "Second parameter should be marked as inferred")
            
            -- Verify third explicit type is preserved
            assert.equal("string", resolved_params[3].inferred_type.typename,
               "Third parameter should use explicit type 'string'")
            assert.equal(false, resolved_params[3].is_inferred,
               "Third parameter should not be marked as inferred")
         end)
         
         it("infers types only for untyped parameters in mixed scenarios", function()
            local handler = mixed_parameter_handler.MixedParameterHandler:new()
            
            -- Test case: function(a, b: string, c)
            local func_literal = create_mock_function_literal(
               "function(a, b: string, c) return a end"
            )
            
            local param_info = contextual_typing.extract_parameter_info(func_literal)
            
            -- Create expected type
            local expected_type = create_function_type({
               { typename = "number", typeid = 300 },
               { typename = "string", typeid = 301 },
               { typename = "boolean", typeid = 302 }
            })
            
            local context = create_mock_inference_context(expected_type)
            
            -- Resolve mixed parameters
            local resolved_params, errors = handler:resolve_mixed_parameters(
               param_info, expected_type, context
            )
            
            -- Verify inference only for untyped parameters
            assert.equal("number", resolved_params[1].inferred_type.typename,
               "First untyped parameter should be inferred")
            assert.equal(true, resolved_params[1].is_inferred,
               "First parameter should be marked as inferred")
            
            assert.equal("string", resolved_params[2].inferred_type.typename,
               "Second parameter should use explicit type")
            assert.equal(false, resolved_params[2].is_inferred,
               "Second parameter should not be marked as inferred")
            
            assert.equal("boolean", resolved_params[3].inferred_type.typename,
               "Third untyped parameter should be inferred")
            assert.equal(true, resolved_params[3].is_inferred,
               "Third parameter should be marked as inferred")
         end)
         
         it("ensures consistent handling across parameter combinations", function()
            local handler = mixed_parameter_handler.MixedParameterHandler:new()
            
            -- Test multiple combinations
            local test_cases = {
               {
                  code = "function(x: number, y) return x end",
                  expected_types = {
                     { typename = "number", typeid = 400 },
                     { typename = "string", typeid = 401 }
                  },
                  expected_results = {
                     { is_inferred = false, typename = "number" },
                     { is_inferred = true, typename = "string" }
                  }
               },
               {
                  code = "function(a, b: boolean, c, d: number) return a end",
                  expected_types = {
                     { typename = "string", typeid = 500 },
                     { typename = "boolean", typeid = 501 },
                     { typename = "integer", typeid = 502 },
                     { typename = "number", typeid = 503 }
                  },
                  expected_results = {
                     { is_inferred = true, typename = "string" },
                     { is_inferred = false, typename = "boolean" },
                     { is_inferred = true, typename = "integer" },
                     { is_inferred = false, typename = "number" }
                  }
               },
               {
                  code = "function(x: string, y: number, z: boolean) return x end",
                  expected_types = {
                     { typename = "string", typeid = 600 },
                     { typename = "number", typeid = 601 },
                     { typename = "boolean", typeid = 602 }
                  },
                  expected_results = {
                     { is_inferred = false, typename = "string" },
                     { is_inferred = false, typename = "number" },
                     { is_inferred = false, typename = "boolean" }
                  }
               }
            }
            
            for _, test_case in ipairs(test_cases) do
               local func_literal = create_mock_function_literal(test_case.code)
               local param_info = contextual_typing.extract_parameter_info(func_literal)
               
               local expected_type = create_function_type(test_case.expected_types)
               local context = create_mock_inference_context(expected_type)
               
               local resolved_params, errors = handler:resolve_mixed_parameters(
                  param_info, expected_type, context
               )
               
               -- Verify each parameter matches expected result
               for i, expected_result in ipairs(test_case.expected_results) do
                  assert.equal(expected_result.is_inferred, resolved_params[i].is_inferred,
                     string.format("Parameter %d inference flag mismatch in test case: %s",
                                 i, test_case.code))
                  assert.equal(expected_result.typename, resolved_params[i].inferred_type.typename,
                     string.format("Parameter %d type mismatch in test case: %s",
                                 i, test_case.code))
               end
            end
         end)
         
         it("validates compatibility between explicit and expected types", function()
            local handler = mixed_parameter_handler.MixedParameterHandler:new()
            
            -- Test case with type conflict
            local func_literal = create_mock_function_literal(
               "function(x: string, y) return x end"
            )
            
            local param_info = contextual_typing.extract_parameter_info(func_literal)
            
            -- Create expected type with conflicting first parameter
            local expected_type = create_function_type({
               { typename = "number", typeid = 700 },  -- Conflicts with x: string
               { typename = "boolean", typeid = 701 }
            })
            
            local context = create_mock_inference_context(expected_type)
            
            -- Resolve mixed parameters
            local resolved_params, errors = handler:resolve_mixed_parameters(
               param_info, expected_type, context
            )
            
            -- Should have error for type conflict
            assert.is_true(#errors > 0, "Should have errors for type conflict")
            assert.equal("mixed_parameter_conflict", errors[1].kind,
               "Should have mixed parameter conflict error")
            assert.is_not_nil(errors[1].suggested_fix,
               "Should provide suggested fix for conflict")
         end)
         
         it("handles parameter count mismatches in mixed scenarios", function()
            local handler = mixed_parameter_handler.MixedParameterHandler:new()
            
            -- Test case: function has 3 params, expected has 2
            local func_literal = create_mock_function_literal(
               "function(x: number, y, z) return x end"
            )
            
            local param_info = contextual_typing.extract_parameter_info(func_literal)
            
            -- Create expected type with fewer parameters
            local expected_type = create_function_type({
               { typename = "number", typeid = 800 },
               { typename = "string", typeid = 801 }
            })
            
            local context = create_mock_inference_context(expected_type)
            
            -- Resolve mixed parameters
            local resolved_params, errors = handler:resolve_mixed_parameters(
               param_info, expected_type, context
            )
            
            -- Should have error for parameter count mismatch
            assert.is_true(#errors > 0, "Should have errors for parameter count mismatch")
            assert.equal("incompatible_signature", errors[1].kind,
               "Should have incompatible signature error")
         end)
         
         it("preserves inference source information for mixed parameters", function()
            local handler = mixed_parameter_handler.MixedParameterHandler:new()
            
            -- Test case: function(x: number, y, z: string)
            local func_literal = create_mock_function_literal(
               "function(x: number, y, z: string) return x end"
            )
            
            local param_info = contextual_typing.extract_parameter_info(func_literal)
            
            local expected_type = create_function_type({
               { typename = "number", typeid = 900 },
               { typename = "boolean", typeid = 901 },
               { typename = "string", typeid = 902 }
            })
            
            local context = create_mock_inference_context(expected_type)
            context.source = "call_site"
            
            -- Resolve mixed parameters
            local resolved_params, errors = handler:resolve_mixed_parameters(
               param_info, expected_type, context
            )
            
            -- Verify inference source tracking
            assert.equal("explicit_annotation", resolved_params[1].inference_source,
               "First parameter should have explicit_annotation source")
            assert.equal("call_site", resolved_params[2].inference_source,
               "Second parameter should have call_site source")
            assert.equal("explicit_annotation", resolved_params[3].inference_source,
               "Third parameter should have explicit_annotation source")
         end)
         
         it("generates appropriate error messages for mixed parameter conflicts", function()
            local handler = mixed_parameter_handler.MixedParameterHandler:new()
            
            -- Test case with type conflict
            local func_literal = create_mock_function_literal(
               "function(x: boolean, y) return x end"
            )
            
            local param_info = contextual_typing.extract_parameter_info(func_literal)
            
            -- Create expected type with conflicting first parameter
            local expected_type = create_function_type({
               { typename = "number", typeid = 1000 },
               { typename = "string", typeid = 1001 }
            })
            
            local context = create_mock_inference_context(expected_type)
            
            -- Resolve mixed parameters
            local resolved_params, errors = handler:resolve_mixed_parameters(
               param_info, expected_type, context
            )
            
            -- Verify error message quality
            assert.is_true(#errors > 0, "Should have errors")
            local error = errors[1]
            assert.is_not_nil(error.message, "Should have error message")
            assert.is_true(string.len(error.message) > 0, "Error message should not be empty")
            assert.is_true(string.find(error.message, "Parameter") ~= nil,
               "Error should mention parameter")
            assert.is_true(string.find(error.message, "type mismatch") ~= nil or
                          string.find(error.message, "conflict") ~= nil,
               "Error should mention type conflict")
            assert.is_not_nil(error.suggested_fix, "Should provide suggested fix")
            assert.is_true(string.len(error.suggested_fix) > 0, "Suggested fix should not be empty")
         end)
         
         it("handles all explicit parameters correctly", function()
            local handler = mixed_parameter_handler.MixedParameterHandler:new()
            
            -- Test case: all parameters are explicit
            local func_literal = create_mock_function_literal(
               "function(x: number, y: string, z: boolean) return x end"
            )
            
            local param_info = contextual_typing.extract_parameter_info(func_literal)
            
            local expected_type = create_function_type({
               { typename = "number", typeid = 1100 },
               { typename = "string", typeid = 1101 },
               { typename = "boolean", typeid = 1102 }
            })
            
            local context = create_mock_inference_context(expected_type)
            
            -- Resolve mixed parameters
            local resolved_params, errors = handler:resolve_mixed_parameters(
               param_info, expected_type, context
            )
            
            -- All parameters should use explicit types
            for i, param in ipairs(resolved_params) do
               assert.equal(false, param.is_inferred,
                  string.format("Parameter %d should not be inferred", i))
               assert.equal(1.0, param.inference_confidence,
                  string.format("Parameter %d should have full confidence", i))
            end
         end)
         
         it("handles all untyped parameters correctly", function()
            local handler = mixed_parameter_handler.MixedParameterHandler:new()
            
            -- Test case: all parameters are untyped
            local func_literal = create_mock_function_literal(
               "function(a, b, c) return a end"
            )
            
            local param_info = contextual_typing.extract_parameter_info(func_literal)
            
            local expected_type = create_function_type({
               { typename = "number", typeid = 1200 },
               { typename = "string", typeid = 1201 },
               { typename = "boolean", typeid = 1202 }
            })
            
            local context = create_mock_inference_context(expected_type)
            
            -- Resolve mixed parameters
            local resolved_params, errors = handler:resolve_mixed_parameters(
               param_info, expected_type, context
            )
            
            -- All parameters should be inferred
            for i, param in ipairs(resolved_params) do
               assert.equal(true, param.is_inferred,
                  string.format("Parameter %d should be inferred", i))
               assert.is_true(param.inference_confidence > 0.5,
                  string.format("Parameter %d should have reasonable confidence", i))
            end
         end)
         
         it("validates consistency of mixed parameter resolution", function()
            local handler = mixed_parameter_handler.MixedParameterHandler:new()
            
            -- Test case: function(x: number, y, z: string)
            local func_literal = create_mock_function_literal(
               "function(x: number, y, z: string) return x end"
            )
            
            local param_info = contextual_typing.extract_parameter_info(func_literal)
            
            local expected_type = create_function_type({
               { typename = "number", typeid = 1300 },
               { typename = "boolean", typeid = 1301 },
               { typename = "string", typeid = 1302 }
            })
            
            local context = create_mock_inference_context(expected_type)
            
            -- Resolve mixed parameters
            local resolved_params, errors = handler:resolve_mixed_parameters(
               param_info, expected_type, context
            )
            
            -- Validate consistency
            local is_consistent, consistency_errors = handler:validate_mixed_parameter_consistency(
               resolved_params, expected_type, context
            )
            
            assert.equal(true, is_consistent, "Resolution should be consistent")
            assert.equal(0, #consistency_errors, "Should have no consistency errors")
         end)
         
      end)
      
   end)
end)
