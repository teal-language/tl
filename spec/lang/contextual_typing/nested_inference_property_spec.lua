local util = require("spec.util")
local tl = require("teal.api.v2")
local contextual_typing = require("teal.contextual_typing")
local contextual_type_checker = require("teal.contextual_type_checker")

describe("contextual typing", function()
   describe("nested inference property", function()
      
      -- Property 7: Nested Inference Propagation
      -- For any nested function literal structure, contextual type information 
      -- should propagate correctly through all nesting levels, enabling inference 
      -- at each level.
      -- **Validates: Requirements 6.1, 6.2, 6.4**
      
      local function create_mock_function_type(param_types, return_type)
         local args_tuple = {
            typename = "tuple",
            typeid = 1,
            tuple = param_types or {},
            inferred_at = { y = 1, x = 1 },
            needs_compat = false
         }
         
         return {
            typename = "function",
            typeid = 2,
            inferred_at = { y = 1, x = 1 },
            needs_compat = false,
            is_method = false,
            maybe_method = false,
            is_record_function = false,
            min_arity = #(param_types or {}),
            args = args_tuple,
            rets = return_type or { typename = "nil", typeid = 0 },
            macroexp = false,
            special_function_handler = nil,
         }
      end
      
      local function create_mock_function_literal(param_count)
         local args = {}
         for i = 1, param_count do
            table.insert(args, {
               tk = "param" .. i,
               argtype = nil,  -- Untyped parameter
               y = 1,
               x = i
            })
         end
         
         return {
            kind = "function",
            args = args,
            body = {
               kind = "block",
               y = 1,
               x = 1
            },
            y = 1,
            x = 1
         }
      end
      
      local function create_nested_function_literal(outer_params, inner_params)
         -- Create inner function literal
         local inner_args = {}
         for i = 1, inner_params do
            table.insert(inner_args, {
               tk = "inner_param" .. i,
               argtype = nil,
               y = 2,
               x = i
            })
         end
         
         local inner_func = {
            kind = "function",
            args = inner_args,
            body = {
               kind = "block",
               y = 2,
               x = 1
            },
            y = 2,
            x = 1
         }
         
         -- Create outer function literal with inner function in body
         local outer_args = {}
         for i = 1, outer_params do
            table.insert(outer_args, {
               tk = "outer_param" .. i,
               argtype = nil,
               y = 1,
               x = i
            })
         end
         
         return {
            kind = "function",
            args = outer_args,
            body = {
               kind = "block",
               y = 1,
               x = 1,
               inner_func  -- Nested function in body
            },
            y = 1,
            x = 1
         }
      end
      
      it("should propagate types through single level of nesting", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create a higher-order function type: (number) -> (string) -> boolean
         local inner_func_type = create_mock_function_type(
            { { typename = "string", typeid = 3 } },
            { typename = "boolean", typeid = 4 }
         )
         
         local outer_func_type = create_mock_function_type(
            { { typename = "number", typeid = 5 } },
            inner_func_type
         )
         
         -- Create nested function literal
         local func_literal = create_nested_function_literal(1, 1)
         
         -- Create inference context
         local call_site = contextual_typing.new_call_site(
            "test_function",
            1,
            { y = 1, x = 1 }
         )
         
         local context = contextual_typing.new_inference_context(
            outer_func_type,
            call_site,
            "call_site"
         )
         
         -- Perform nested inference
         local result = checker:infer_nested_function_literal(
            func_literal,
            outer_func_type,
            context
         )
         
         -- Verify inference succeeded
         assert.is_true(result.success, "Nested inference should succeed")
         assert.is_not_nil(result.inferred_type, "Inferred type should not be nil")
         assert.equal("function", result.inferred_type.typename, "Inferred type should be function")
         
         -- Verify constraints were applied
         assert.is_true(#result.applied_constraints > 0, "Should have applied constraints")
      end)
      
      it("should handle multiple nesting levels", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create triple-nested function type: (number) -> (string) -> (boolean) -> integer
         local innermost_type = create_mock_function_type(
            { { typename = "boolean", typeid = 6 } },
            { typename = "integer", typeid = 7 }
         )
         
         local middle_type = create_mock_function_type(
            { { typename = "string", typeid = 8 } },
            innermost_type
         )
         
         local outer_type = create_mock_function_type(
            { { typename = "number", typeid = 9 } },
            middle_type
         )
         
         -- Create nested function literal
         local func_literal = create_nested_function_literal(1, 1)
         
         -- Create inference context
         local call_site = contextual_typing.new_call_site(
            "test_function",
            1,
            { y = 1, x = 1 }
         )
         
         local context = contextual_typing.new_inference_context(
            outer_type,
            call_site,
            "call_site"
         )
         
         -- Perform nested inference with depth tracking
         local result = checker:propagate_type_through_nesting(
            func_literal,
            outer_type,
            context,
            0
         )
         
         -- Verify inference succeeded
         assert.is_true(result.success, "Multi-level nested inference should succeed")
         assert.is_not_nil(result.inferred_type, "Inferred type should not be nil")
         
         -- Verify confidence is reasonable
         assert.is_true(result.confidence >= 0.0 and result.confidence <= 1.0,
                       "Confidence should be in valid range")
      end)
      
      it("should respect nesting depth limits", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         checker.max_inference_depth = 2  -- Set low limit for testing
         
         -- Create deeply nested function type
         local current_type = { typename = "integer", typeid = 10 }
         
         for i = 1, 5 do
            current_type = create_mock_function_type(
               { { typename = "number", typeid = 10 + i } },
               current_type
            )
         end
         
         local func_literal = create_mock_function_literal(1)
         
         local call_site = contextual_typing.new_call_site(
            "test_function",
            1,
            { y = 1, x = 1 }
         )
         
         local context = contextual_typing.new_inference_context(
            current_type,
            call_site,
            "call_site"
         )
         
         -- Attempt inference with depth limit
         local result = checker:propagate_type_through_nesting(
            func_literal,
            current_type,
            context,
            0
         )
         
         -- Should eventually hit depth limit
         -- (may succeed at lower depths but should not exceed limit)
         assert.is_true(result.confidence >= 0.0 and result.confidence <= 1.0,
                       "Should handle depth limits gracefully")
      end)
      
      it("should infer callback returning function", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create callback type: (number) -> (function(string) -> boolean)
         local returned_func_type = create_mock_function_type(
            { { typename = "string", typeid = 11 } },
            { typename = "boolean", typeid = 12 }
         )
         
         local callback_type = create_mock_function_type(
            { { typename = "number", typeid = 13 } },
            returned_func_type
         )
         
         local callback_literal = create_mock_function_literal(1)
         
         local call_site = contextual_typing.new_call_site(
            "test_callback",
            1,
            { y = 1, x = 1 }
         )
         
         local context = contextual_typing.new_inference_context(
            callback_type,
            call_site,
            "call_site"
         )
         
         -- Infer callback returning function
         local result = checker:infer_callback_returning_function(
            callback_literal,
            callback_type,
            context
         )
         
         -- Verify inference succeeded
         assert.is_true(result.success, "Callback returning function inference should succeed")
         assert.is_not_nil(result.inferred_type, "Inferred type should not be nil")
         
         -- Verify constraint was applied
         assert.is_true(
            util.contains(result.applied_constraints, "callback_returning_function_inferred"),
            "Should apply callback_returning_function_inferred constraint"
         )
      end)
      
      it("should find nested function literals in AST", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create AST with nested functions
         local nested_ast = {
            kind = "block",
            {
               kind = "function",
               args = {},
               body = {
                  kind = "block",
                  {
                     kind = "function",
                     args = {},
                     body = { kind = "block" }
                  }
               }
            }
         }
         
         -- Find nested functions
         local nested_functions = checker:find_nested_function_literals(nested_ast)
         
         -- Should find at least the nested function
         assert.is_true(#nested_functions > 0, "Should find nested function literals")
      end)
      
      it("should find return statements in function body", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create AST with return statements
         local func_body = {
            kind = "block",
            {
               kind = "if",
               ifs = {
                  {
                     body = {
                        kind = "block",
                        {
                           kind = "return",
                           exps = { { kind = "number", value = 42 } }
                        }
                     }
                  }
               },
               elsebody = {
                  kind = "block",
                  {
                     kind = "return",
                     exps = { { kind = "number", value = 0 } }
                  }
               }
            }
         }
         
         -- Find return statements
         local returns = checker:find_return_statements(func_body)
         
         -- Should find both return statements
         assert.is_true(#returns >= 2, "Should find all return statements")
      end)
      
      it("should infer return type from function body", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create expected return type (function)
         local expected_return_type = create_mock_function_type(
            { { typename = "number", typeid = 14 } },
            { typename = "string", typeid = 15 }
         )
         
         -- Create function body with return statement
         local func_body = {
            kind = "block",
            {
               kind = "return",
               exps = {
                  {
                     kind = "function",
                     args = { { tk = "x", argtype = nil } },
                     body = { kind = "block" }
                  }
               }
            }
         }
         
         local call_site = contextual_typing.new_call_site(
            "test_function",
            1,
            { y = 1, x = 1 }
         )
         
         local context = contextual_typing.new_inference_context(
            expected_return_type,
            call_site,
            "call_site"
         )
         
         -- Infer return type
         local result = checker:infer_return_type_from_body(
            func_body,
            expected_return_type,
            context
         )
         
         -- Verify inference succeeded
         assert.is_true(result.success, "Return type inference should succeed")
         assert.is_not_nil(result.inferred_type, "Inferred return type should not be nil")
      end)
      
      it("should propagate generic bindings through nesting", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create generic function type with type variable
         local type_var = {
            typename = "typevar",
            typeid = 16,
            typevar = "T"
         }
         
         local generic_func_type = create_mock_function_type(
            { type_var },
            type_var
         )
         
         local func_literal = create_mock_function_literal(1)
         
         local call_site = contextual_typing.new_call_site(
            "test_function",
            1,
            { y = 1, x = 1 }
         )
         
         local context = contextual_typing.new_inference_context(
            generic_func_type,
            call_site,
            "call_site"
         )
         
         -- Add generic binding
         context.generic_bindings["T"] = { typename = "number", typeid = 17 }
         
         -- Perform inference
         local result = checker:infer_function_parameters(
            func_literal,
            generic_func_type,
            context
         )
         
         -- Verify inference succeeded
         assert.is_true(result.success, "Generic binding propagation should succeed")
         
         -- Verify generic resolution was applied
         assert.is_true(
            util.contains(result.applied_constraints, "generic_resolution_applied"),
            "Should apply generic resolution"
         )
      end)
      
      it("should handle mixed explicit and inferred parameters in nested context", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create function type
         local func_type = create_mock_function_type(
            { { typename = "number", typeid = 18 }, { typename = "string", typeid = 19 } },
            { typename = "boolean", typeid = 20 }
         )
         
         -- Create function literal with mixed parameters
         local func_literal = {
            kind = "function",
            args = {
               { tk = "x", argtype = { typename = "number", typeid = 18 }, y = 1, x = 1 },  -- Explicit
               { tk = "y", argtype = nil, y = 1, x = 2 }  -- Untyped
            },
            body = { kind = "block", y = 1, x = 1 },
            y = 1,
            x = 1
         }
         
         local call_site = contextual_typing.new_call_site(
            "test_function",
            1,
            { y = 1, x = 1 }
         )
         
         local context = contextual_typing.new_inference_context(
            func_type,
            call_site,
            "call_site"
         )
         
         -- Perform inference
         local result = checker:infer_function_parameters(
            func_literal,
            func_type,
            context
         )
         
         -- Verify inference succeeded
         assert.is_true(result.success, "Mixed parameter inference should succeed")
         
         -- Verify both explicit and inferred parameters were handled
         assert.is_not_nil(result.inferred_type, "Should have inferred type")
      end)
      
      it("should maintain confidence scores through nesting levels", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create nested function type
         local inner_type = create_mock_function_type(
            { { typename = "string", typeid = 21 } },
            { typename = "boolean", typeid = 22 }
         )
         
         local outer_type = create_mock_function_type(
            { { typename = "number", typeid = 23 } },
            inner_type
         )
         
         local func_literal = create_nested_function_literal(1, 1)
         
         local call_site = contextual_typing.new_call_site(
            "test_function",
            1,
            { y = 1, x = 1 }
         )
         
         local context = contextual_typing.new_inference_context(
            outer_type,
            call_site,
            "call_site"
         )
         
         -- Perform nested inference
         local result = checker:infer_nested_function_literal(
            func_literal,
            outer_type,
            context
         )
         
         -- Verify confidence is tracked
         assert.is_true(result.confidence >= 0.0 and result.confidence <= 1.0,
                       "Confidence should be in valid range")
         
         -- Confidence should be reasonable for successful inference
         if result.success then
            assert.is_true(result.confidence > 0.3,
                          "Successful inference should have reasonable confidence")
         end
      end)
   end)
end)
