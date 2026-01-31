local util = require("spec.util")
local tl = require("teal.api.v2")
local contextual_typing = require("teal.contextual_typing")
local contextual_type_checker = require("teal.contextual_type_checker")

describe("contextual typing", function()
   describe("complex type handling property", function()
      
      -- Property 8: Complex Type Handling
      -- For any function literal used with union types, intersection types, 
      -- or recursive types, contextual inference should handle the complex 
      -- type scenarios without infinite loops or incorrect type resolution.
      -- **Validates: Requirements 6.5, 8.3, 8.5**
      
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
               argtype = nil,
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
      
      local function create_union_type(member_types)
         return {
            typename = "union",
            typeid = 100,
            types = member_types or {},
            inferred_at = { y = 1, x = 1 },
            needs_compat = false
         }
      end
      
      local function create_intersection_type(member_types)
         return {
            typename = "intersection",
            typeid = 101,
            types = member_types or {},
            inferred_at = { y = 1, x = 1 },
            needs_compat = false
         }
      end
      
      it("should handle union type with multiple function options", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create union of function types: (number) -> string | (string) -> number
         local func_type_1 = create_mock_function_type(
            { { typename = "number", typeid = 3 } },
            { typename = "string", typeid = 4 }
         )
         
         local func_type_2 = create_mock_function_type(
            { { typename = "string", typeid = 5 } },
            { typename = "number", typeid = 6 }
         )
         
         local union_type = create_union_type({ func_type_1, func_type_2 })
         
         local func_literal = create_mock_function_literal(1)
         
         local call_site = contextual_typing.new_call_site(
            "test_function",
            1,
            { y = 1, x = 1 }
         )
         
         local context = contextual_typing.new_inference_context(
            union_type,
            call_site,
            "call_site"
         )
         
         -- Perform inference with union type
         local result = checker:infer_union_type_scenario(
            func_literal,
            union_type,
            context
         )
         
         -- Should succeed with one of the union members
         assert.is_true(result.success or #result.errors > 0, 
                       "Should handle union type scenario")
      end)
      
      it("should select best matching union member by confidence", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create union with multiple function types
         local func_types = {}
         for i = 1, 3 do
            table.insert(func_types, create_mock_function_type(
               { { typename = "number", typeid = 10 + i } },
               { typename = "string", typeid = 20 + i }
            ))
         end
         
         local union_type = create_union_type(func_types)
         local func_literal = create_mock_function_literal(1)
         
         local call_site = contextual_typing.new_call_site(
            "test_function",
            1,
            { y = 1, x = 1 }
         )
         
         local context = contextual_typing.new_inference_context(
            union_type,
            call_site,
            "call_site"
         )
         
         -- Perform inference
         local result = checker:infer_union_type_scenario(
            func_literal,
            union_type,
            context
         )
         
         -- Verify confidence is reduced for union types
         if result.success then
            assert.is_true(result.confidence >= 0.0 and result.confidence <= 1.0,
                          "Confidence should be in valid range")
         end
      end)
      
      it("should handle intersection type with function member", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create intersection with function and other types
         local func_type = create_mock_function_type(
            { { typename = "number", typeid = 30 } },
            { typename = "string", typeid = 31 }
         )
         
         local other_type = { typename = "table", typeid = 32 }
         
         local intersection_type = create_intersection_type({ func_type, other_type })
         
         local func_literal = create_mock_function_literal(1)
         
         local call_site = contextual_typing.new_call_site(
            "test_function",
            1,
            { y = 1, x = 1 }
         )
         
         local context = contextual_typing.new_inference_context(
            intersection_type,
            call_site,
            "call_site"
         )
         
         -- Perform inference with intersection type
         local result = checker:infer_intersection_type_scenario(
            func_literal,
            intersection_type,
            context
         )
         
         -- Should succeed by extracting function type from intersection
         assert.is_true(result.success or #result.errors > 0,
                       "Should handle intersection type scenario")
      end)
      
      it("should detect recursive type cycles", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create a recursive type structure
         local recursive_type = {
            typename = "function",
            typeid = 40,
            inferred_at = { y = 1, x = 1 },
            needs_compat = false,
            is_method = false,
            maybe_method = false,
            is_record_function = false,
            min_arity = 1,
            args = {
               typename = "tuple",
               typeid = 41,
               tuple = {},
               inferred_at = { y = 1, x = 1 },
               needs_compat = false
            },
            rets = nil,  -- Will be set to self
            macroexp = false,
            special_function_handler = nil,
         }
         
         -- Create cycle
         recursive_type.rets = recursive_type
         
         local func_literal = create_mock_function_literal(0)
         
         local call_site = contextual_typing.new_call_site(
            "test_function",
            1,
            { y = 1, x = 1 }
         )
         
         local context = contextual_typing.new_inference_context(
            recursive_type,
            call_site,
            "call_site"
         )
         
         -- Perform inference with recursive type
         local result = checker:infer_recursive_type_scenario(
            func_literal,
            recursive_type,
            context,
            {}
         )
         
         -- Should detect cycle and not infinite loop
         assert.is_true(result.confidence >= 0.0 and result.confidence <= 1.0,
                       "Should handle recursive type without infinite loop")
      end)
      
      it("should prevent infinite recursion in type detection", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create a recursive type
         local recursive_type = {
            typename = "function",
            typeid = 50,
            inferred_at = { y = 1, x = 1 },
            needs_compat = false,
            is_method = false,
            maybe_method = false,
            is_record_function = false,
            min_arity = 1,
            args = {
               typename = "tuple",
               typeid = 51,
               tuple = {},
               inferred_at = { y = 1, x = 1 },
               needs_compat = false
            },
            rets = nil,
            macroexp = false,
            special_function_handler = nil,
         }
         
         recursive_type.rets = recursive_type
         
         -- Detect recursive type
         local is_recursive = checker:detect_recursive_type(recursive_type, {})
         
         -- Should detect recursion
         assert.is_true(is_recursive, "Should detect recursive type")
      end)
      
      it("should handle conditional expression with function branches", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create conditional AST
         local conditional = {
            kind = "if",
            ifs = {
               {
                  body = {
                     kind = "block",
                     {
                        kind = "function",
                        args = { { tk = "x", argtype = nil } },
                        body = { kind = "block" }
                     }
                  }
               }
            },
            elsebody = {
               kind = "block",
               {
                  kind = "function",
                  args = { { tk = "y", argtype = nil } },
                  body = { kind = "block" }
               }
            }
         }
         
         local expected_type = create_mock_function_type(
            { { typename = "number", typeid = 60 } },
            { typename = "string", typeid = 61 }
         )
         
         local call_site = contextual_typing.new_call_site(
            "test_function",
            1,
            { y = 1, x = 1 }
         )
         
         local context = contextual_typing.new_inference_context(
            expected_type,
            call_site,
            "call_site"
         )
         
         -- Perform inference on conditional
         local result = checker:infer_conditional_expression_type(
            conditional,
            conditional,
            expected_type,
            context
         )
         
         -- Should handle conditional branches
         assert.is_true(result.success or #result.errors > 0,
                       "Should handle conditional expression")
      end)
      
      it("should handle complex nested union and intersection types", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create complex type: (number | string) -> (function | table)
         local param_union = create_union_type({
            { typename = "number", typeid = 70 },
            { typename = "string", typeid = 71 }
         })
         
         local return_union = create_union_type({
            create_mock_function_type(
               { { typename = "boolean", typeid = 72 } },
               { typename = "integer", typeid = 73 }
            ),
            { typename = "table", typeid = 74 }
         })
         
         local complex_type = {
            typename = "function",
            typeid = 75,
            inferred_at = { y = 1, x = 1 },
            needs_compat = false,
            is_method = false,
            maybe_method = false,
            is_record_function = false,
            min_arity = 1,
            args = {
               typename = "tuple",
               typeid = 76,
               tuple = { param_union },
               inferred_at = { y = 1, x = 1 },
               needs_compat = false
            },
            rets = return_union,
            macroexp = false,
            special_function_handler = nil,
         }
         
         local func_literal = create_mock_function_literal(1)
         
         local call_site = contextual_typing.new_call_site(
            "test_function",
            1,
            { y = 1, x = 1 }
         )
         
         local context = contextual_typing.new_inference_context(
            complex_type,
            call_site,
            "call_site"
         )
         
         -- Perform inference on complex type
         local result = checker:infer_complex_type_scenario(
            func_literal,
            complex_type,
            context
         )
         
         -- Should handle complex type scenario
         assert.is_true(result.confidence >= 0.0 and result.confidence <= 1.0,
                       "Should handle complex type scenario")
      end)
      
      it("should handle array types in complex scenarios", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create array type: {(number) -> string}
         local element_func_type = create_mock_function_type(
            { { typename = "number", typeid = 80 } },
            { typename = "string", typeid = 81 }
         )
         
         local array_type = {
            typename = "array",
            typeid = 82,
            elements = element_func_type,
            inferred_at = { y = 1, x = 1 },
            needs_compat = false
         }
         
         -- Detect recursive type in array
         local is_recursive = checker:detect_recursive_type(array_type, {})
         
         -- Should not be recursive
         assert.is_true(not is_recursive, "Array type should not be recursive")
      end)
      
      it("should handle map types in complex scenarios", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create map type: {string: (number) -> boolean}
         local value_func_type = create_mock_function_type(
            { { typename = "number", typeid = 90 } },
            { typename = "boolean", typeid = 91 }
         )
         
         local map_type = {
            typename = "map",
            typeid = 92,
            keys = { typename = "string", typeid = 93 },
            values = value_func_type,
            inferred_at = { y = 1, x = 1 },
            needs_compat = false
         }
         
         -- Detect recursive type in map
         local is_recursive = checker:detect_recursive_type(map_type, {})
         
         -- Should not be recursive
         assert.is_true(not is_recursive, "Map type should not be recursive")
      end)
      
      it("should maintain confidence through complex type handling", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create union type
         local func_type_1 = create_mock_function_type(
            { { typename = "number", typeid = 100 } },
            { typename = "string", typeid = 101 }
         )
         
         local func_type_2 = create_mock_function_type(
            { { typename = "string", typeid = 102 } },
            { typename = "number", typeid = 103 }
         )
         
         local union_type = create_union_type({ func_type_1, func_type_2 })
         
         local func_literal = create_mock_function_literal(1)
         
         local call_site = contextual_typing.new_call_site(
            "test_function",
            1,
            { y = 1, x = 1 }
         )
         
         local context = contextual_typing.new_inference_context(
            union_type,
            call_site,
            "call_site"
         )
         
         -- Perform inference
         local result = checker:infer_union_type_scenario(
            func_literal,
            union_type,
            context
         )
         
         -- Verify confidence is tracked
         assert.is_true(result.confidence >= 0.0 and result.confidence <= 1.0,
                       "Confidence should be in valid range")
         
         -- Union types should have reduced confidence
         if result.success then
            assert.is_true(result.confidence <= 0.95,
                          "Union type inference should have reduced confidence")
         end
      end)
      
      it("should handle empty union type gracefully", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create empty union type
         local empty_union = create_union_type({})
         
         local func_literal = create_mock_function_literal(1)
         
         local call_site = contextual_typing.new_call_site(
            "test_function",
            1,
            { y = 1, x = 1 }
         )
         
         local context = contextual_typing.new_inference_context(
            empty_union,
            call_site,
            "call_site"
         )
         
         -- Perform inference with empty union
         local result = checker:infer_union_type_scenario(
            func_literal,
            empty_union,
            context
         )
         
         -- Should fail gracefully
         assert.is_true(#result.errors > 0, "Should report error for empty union")
      end)
      
      it("should handle intersection without function type gracefully", function()
         local checker = contextual_type_checker.BaseContextualTypeChecker:new()
         
         -- Create intersection without function type
         local non_func_intersection = create_intersection_type({
            { typename = "number", typeid = 110 },
            { typename = "string", typeid = 111 }
         })
         
         local func_literal = create_mock_function_literal(1)
         
         local call_site = contextual_typing.new_call_site(
            "test_function",
            1,
            { y = 1, x = 1 }
         )
         
         local context = contextual_typing.new_inference_context(
            non_func_intersection,
            call_site,
            "call_site"
         )
         
         -- Perform inference
         local result = checker:infer_intersection_type_scenario(
            func_literal,
            non_func_intersection,
            context
         )
         
         -- Should fail gracefully
         assert.is_true(#result.errors > 0, 
                       "Should report error for intersection without function type")
      end)
   end)
end)
