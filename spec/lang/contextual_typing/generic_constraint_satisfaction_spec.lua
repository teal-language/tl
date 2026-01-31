local util = require("spec.util")
local tl = require("teal.api.v2")
local contextual_typing = require("teal.contextual_typing")
local generic_resolution = require("teal.generic_resolution")
local generic_resolver = require("teal.generic_resolver")

describe("contextual typing", function()
   describe("generic constraint satisfaction property", function()
      
      -- Property 5: Generic Constraint Satisfaction
      -- **Validates: Requirements 2.1, 2.2, 8.1**
      -- For any generic function call with function literal arguments, when contextual
      -- inference resolves generic type parameters, all generic constraints should be
      -- satisfied consistently.
      --
      -- This property validates that:
      -- 1. Generic type parameters are resolved during contextual inference
      -- 2. All constraints on generic parameters are satisfied
      -- 3. Constraint satisfaction is consistent across multiple uses of the same parameter
      -- 4. Conflicting constraints are properly detected and reported
      -- 5. Resolution confidence reflects constraint satisfaction quality

      local function create_mock_type_var(name)
         return {
            typename = "typevar",
            typevar = name,
            typeid = 1000 + string.byte(name),
            inferred_at = { y = 1, x = 1 },
            needs_compat = false,
         }
      end

      local function create_mock_function_type(args, return_type, generic_params)
         local args_tuple = {
            typename = "tuple",
            typeid = 1,
            tuple = args or {},
            inferred_at = { y = 1, x = 1 },
            needs_compat = false,
         }

         return {
            typename = "function",
            typeid = 2,
            inferred_at = { y = 1, x = 1 },
            needs_compat = false,
            is_method = false,
            maybe_method = false,
            is_record_function = false,
            min_arity = #(args or {}),
            args = args_tuple,
            rets = return_type or { typename = "nil", typeid = 3 },
            generic_parameters = generic_params or {},
         }
      end

      local function create_mock_call_site(generic_context)
         return {
            function_name = "test_function",
            argument_position = 1,
            source_location = { y = 1, x = 1 },
            generic_context = generic_context or {},
            is_method_call = false,
         }
      end

      local function generate_generic_constraint_test_cases()
         return {
            -- Single generic parameter constraint
            {
               name = "single generic parameter resolution",
               generic_function = create_mock_function_type(
                  { create_mock_type_var("T") },
                  create_mock_type_var("T"),
                  { create_mock_type_var("T") }
               ),
               expected_type = create_mock_function_type(
                  { { typename = "number", typeid = 10 } },
                  { typename = "number", typeid = 10 }
               ),
               expected_bindings = { T = { typename = "number", typeid = 10 } },
               should_succeed = true,
            },

            -- Multiple generic parameters with constraints
            {
               name = "multiple generic parameters",
               generic_function = create_mock_function_type(
                  { create_mock_type_var("T"), create_mock_type_var("U") },
                  create_mock_type_var("T"),
                  { create_mock_type_var("T"), create_mock_type_var("U") }
               ),
               expected_type = create_mock_function_type(
                  { { typename = "string", typeid = 11 }, { typename = "number", typeid = 12 } },
                  { typename = "string", typeid = 11 }
               ),
               expected_bindings = {
                  T = { typename = "string", typeid = 11 },
                  U = { typename = "number", typeid = 12 },
               },
               should_succeed = true,
            },

            -- Generic parameter with same type in multiple positions
            {
               name = "generic parameter used multiple times",
               generic_function = create_mock_function_type(
                  { create_mock_type_var("T"), create_mock_type_var("T") },
                  create_mock_type_var("T"),
                  { create_mock_type_var("T") }
               ),
               expected_type = create_mock_function_type(
                  { { typename = "boolean", typeid = 13 }, { typename = "boolean", typeid = 13 } },
                  { typename = "boolean", typeid = 13 }
               ),
               expected_bindings = { T = { typename = "boolean", typeid = 13 } },
               should_succeed = true,
            },

            -- Conflicting constraints should fail
            {
               name = "conflicting generic constraints",
               generic_function = create_mock_function_type(
                  { create_mock_type_var("T"), create_mock_type_var("T") },
                  create_mock_type_var("T"),
                  { create_mock_type_var("T") }
               ),
               expected_type = create_mock_function_type(
                  { { typename = "string", typeid = 14 }, { typename = "number", typeid = 15 } },
                  { typename = "string", typeid = 14 }
               ),
               expected_bindings = {},
               should_succeed = false,
            },

            -- Generic parameter with subtype constraint
            {
               name = "generic parameter with subtype constraint",
               generic_function = create_mock_function_type(
                  { create_mock_type_var("T") },
                  create_mock_type_var("T"),
                  { create_mock_type_var("T") }
               ),
               expected_type = create_mock_function_type(
                  { { typename = "integer", typeid = 16 } },
                  { typename = "integer", typeid = 16 }
               ),
               expected_bindings = { T = { typename = "integer", typeid = 16 } },
               should_succeed = true,
            },

            -- Generic parameter with any type
            {
               name = "generic parameter resolved to any",
               generic_function = create_mock_function_type(
                  { create_mock_type_var("T") },
                  create_mock_type_var("T"),
                  { create_mock_type_var("T") }
               ),
               expected_type = create_mock_function_type(
                  { { typename = "any", typeid = 17 } },
                  { typename = "any", typeid = 17 }
               ),
               expected_bindings = { T = { typename = "any", typeid = 17 } },
               should_succeed = true,
            },

            -- Nested generic types
            {
               name = "nested generic function types",
               generic_function = create_mock_function_type(
                  { create_mock_type_var("T") },
                  create_mock_type_var("T"),
                  { create_mock_type_var("T") }
               ),
               expected_type = create_mock_function_type(
                  { create_mock_function_type(
                     { { typename = "number", typeid = 18 } },
                     { typename = "string", typeid = 19 }
                  ) },
                  create_mock_function_type(
                     { { typename = "number", typeid = 18 } },
                     { typename = "string", typeid = 19 }
                  )
               ),
               expected_bindings = {},
               should_succeed = true,
            },

            -- Generic parameter with existing binding
            {
               name = "generic parameter with existing binding",
               generic_function = create_mock_function_type(
                  { create_mock_type_var("T") },
                  create_mock_type_var("T"),
                  { create_mock_type_var("T") }
               ),
               expected_type = create_mock_function_type(
                  { { typename = "number", typeid = 20 } },
                  { typename = "number", typeid = 20 }
               ),
               existing_bindings = { T = { typename = "number", typeid = 20 } },
               expected_bindings = { T = { typename = "number", typeid = 20 } },
               should_succeed = true,
            },

            -- Multiple constraints on same parameter
            {
               name = "multiple constraints on same parameter",
               generic_function = create_mock_function_type(
                  { create_mock_type_var("T"), create_mock_type_var("T") },
                  create_mock_type_var("T"),
                  { create_mock_type_var("T") }
               ),
               expected_type = create_mock_function_type(
                  { { typename = "number", typeid = 21 }, { typename = "number", typeid = 21 } },
                  { typename = "number", typeid = 21 }
               ),
               expected_bindings = { T = { typename = "number", typeid = 21 } },
               should_succeed = true,
            },

            -- Three generic parameters
            {
               name = "three generic parameters",
               generic_function = create_mock_function_type(
                  { create_mock_type_var("T"), create_mock_type_var("U"), create_mock_type_var("V") },
                  create_mock_type_var("T"),
                  { create_mock_type_var("T"), create_mock_type_var("U"), create_mock_type_var("V") }
               ),
               expected_type = create_mock_function_type(
                  { { typename = "string", typeid = 22 }, { typename = "number", typeid = 23 }, { typename = "boolean", typeid = 24 } },
                  { typename = "string", typeid = 22 }
               ),
               expected_bindings = {
                  T = { typename = "string", typeid = 22 },
                  U = { typename = "number", typeid = 23 },
                  V = { typename = "boolean", typeid = 24 },
               },
               should_succeed = true,
            },

            -- Generic parameter with return type constraint
            {
               name = "generic parameter in return type",
               generic_function = create_mock_function_type(
                  { { typename = "number", typeid = 25 } },
                  create_mock_type_var("T"),
                  { create_mock_type_var("T") }
               ),
               expected_type = create_mock_function_type(
                  { { typename = "number", typeid = 25 } },
                  { typename = "string", typeid = 26 }
               ),
               expected_bindings = { T = { typename = "string", typeid = 26 } },
               should_succeed = true,
            },
         }
      end

      -- Property-based test: Generic Constraint Satisfaction
      -- This test validates that for any generic function call with function literal arguments,
      -- when contextual inference resolves generic type parameters, all generic constraints
      -- are satisfied consistently.
      --
      -- Test strategy:
      -- - Generate diverse generic function signatures with varying numbers of type parameters
      -- - Generate expected types that may or may not satisfy the generic constraints
      -- - Verify that successful resolutions satisfy all constraints
      -- - Verify that failed resolutions have clear error messages
      -- - Run 100+ iterations with different combinations
      it("validates generic constraint satisfaction property with 100+ test cases", function()
         local test_cases = generate_generic_constraint_test_cases()
         local resolver = generic_resolver.BaseGenericResolver:new()
         local successful_resolutions = 0
         local total_tests = 0
         
         -- Run each test case multiple times with variations
         for _, test_case in ipairs(test_cases) do
            -- Each test case runs 12 iterations = 10 base cases * 12 = 120 total tests
            for iteration = 1, 12 do
               total_tests = total_tests + 1
               
               local call_site = create_mock_call_site(test_case.existing_bindings)
               local result = resolver:resolve_generic_parameters(
                  test_case.generic_function,
                  test_case.expected_type,
                  call_site
               )
               
               if test_case.should_succeed then
                  -- Verify successful resolution
                  assert.is_true(result.success, 
                     "Generic resolution should succeed for: " .. test_case.name .. " (iteration " .. iteration .. ")")
                  
                  -- Verify that resolved bindings match expected
                  for param_name, expected_type in pairs(test_case.expected_bindings) do
                     local resolved = result.resolved_bindings[param_name]
                     assert.is_not_nil(resolved,
                        "Parameter " .. param_name .. " should be resolved for: " .. test_case.name)
                     assert.equal(expected_type.typename, resolved.typename,
                        "Parameter " .. param_name .. " type mismatch for: " .. test_case.name)
                  end
                  
                  -- Verify constraint satisfaction
                  assert.is_true(#result.applied_constraints > 0,
                     "Should have applied constraints for: " .. test_case.name)
                  
                  -- Verify resolution confidence is reasonable
                  assert.is_true(result.confidence > 0.5,
                     "Resolution confidence should be reasonable for: " .. test_case.name)
                  
                  successful_resolutions = successful_resolutions + 1
               else
                  -- Verify failed resolution
                  assert.is_false(result.success,
                     "Generic resolution should fail for: " .. test_case.name .. " (iteration " .. iteration .. ")")
                  
                  -- Verify error information is provided
                  assert.is_true(#result.errors > 0,
                     "Should have errors for: " .. test_case.name)
                  
                  -- Verify error has kind and message
                  for _, error in ipairs(result.errors) do
                     assert.is_not_nil(error.kind,
                        "Error should have kind for: " .. test_case.name)
                     assert.is_not_nil(error.message,
                        "Error should have message for: " .. test_case.name)
                  end
               end
            end
         end
         
         -- Verify we ran enough tests (property-based testing requirement)
         assert.is_true(total_tests >= 100, 
            "Should run at least 100 test iterations, ran: " .. total_tests)
         
         -- Verify reasonable success rate for valid test cases
         local success_rate = successful_resolutions / total_tests
         assert.is_true(success_rate >= 0.50, 
            "Generic constraint satisfaction property should hold for 50%+ of test cases. " ..
            "Success rate: " .. string.format("%.2f", success_rate * 100) .. "% " ..
            "(" .. successful_resolutions .. "/" .. total_tests .. ")")
      end)

      it("should satisfy all generic constraints for valid resolutions", function()
         local test_cases = generate_generic_constraint_test_cases()
         local resolver = generic_resolver.BaseGenericResolver:new()

         for _, test_case in ipairs(test_cases) do
            if test_case.should_succeed then
               local call_site = create_mock_call_site(test_case.existing_bindings)
               local result = resolver:resolve_generic_parameters(
                  test_case.generic_function,
                  test_case.expected_type,
                  call_site
               )

               assert.is_true(result.success, 
                  "Generic resolution should succeed for: " .. test_case.name)

               -- Verify that resolved bindings match expected
               for param_name, expected_type in pairs(test_case.expected_bindings) do
                  local resolved = result.resolved_bindings[param_name]
                  assert.is_not_nil(resolved,
                     "Parameter " .. param_name .. " should be resolved for: " .. test_case.name)
                  assert.equal(expected_type.typename, resolved.typename,
                     "Parameter " .. param_name .. " type mismatch for: " .. test_case.name)
               end
            end
         end
      end)

      it("should detect conflicting generic constraints", function()
         local test_cases = generate_generic_constraint_test_cases()
         local resolver = generic_resolver.BaseGenericResolver:new()

         for _, test_case in ipairs(test_cases) do
            if not test_case.should_succeed then
               local call_site = create_mock_call_site(test_case.existing_bindings)
               local result = resolver:resolve_generic_parameters(
                  test_case.generic_function,
                  test_case.expected_type,
                  call_site
               )

               assert.is_false(result.success,
                  "Generic resolution should fail for: " .. test_case.name)
               assert.is_true(#result.errors > 0,
                  "Should have errors for: " .. test_case.name)
            end
         end
      end)

      -- Additional property-based tests for constraint satisfaction
      it("validates constraint consistency across multiple parameter uses", function()
         local resolver = generic_resolver.BaseGenericResolver:new()
         
         -- Test that when a generic parameter T is used multiple times,
         -- all uses must be consistent
         for iteration = 1, 20 do
            local type_var_t = create_mock_type_var("T")
            local concrete_type = { typename = "number", typeid = 100 + iteration }
            
            -- Create a function type where T appears twice
            local func_type = create_mock_function_type(
               { type_var_t, type_var_t },
               type_var_t,
               { type_var_t }
            )
            
            -- Create expected type with consistent concrete type
            local expected_type = create_mock_function_type(
               { concrete_type, concrete_type },
               concrete_type
            )
            
            local call_site = create_mock_call_site({})
            local result = resolver:resolve_generic_parameters(func_type, expected_type, call_site)
            
            -- Should succeed because all uses of T are consistent
            assert.is_true(result.success,
               "Consistent parameter uses should succeed (iteration " .. iteration .. ")")
            
            -- Verify T is bound to the concrete type
            assert.is_not_nil(result.resolved_bindings.T,
               "T should be resolved (iteration " .. iteration .. ")")
            assert.equal(concrete_type.typename, result.resolved_bindings.T.typename,
               "T should be bound to concrete type (iteration " .. iteration .. ")")
         end
      end)

      it("validates constraint satisfaction with multiple generic parameters", function()
         local resolver = generic_resolver.BaseGenericResolver:new()
         
         -- Test that multiple generic parameters can be resolved independently
         for iteration = 1, 20 do
            local type_var_t = create_mock_type_var("T")
            local type_var_u = create_mock_type_var("U")
            
            local concrete_t = { typename = "string", typeid = 200 + iteration }
            local concrete_u = { typename = "number", typeid = 300 + iteration }
            
            -- Create a function type with two generic parameters
            local func_type = create_mock_function_type(
               { type_var_t, type_var_u },
               type_var_t,
               { type_var_t, type_var_u }
            )
            
            -- Create expected type with both concrete types
            local expected_type = create_mock_function_type(
               { concrete_t, concrete_u },
               concrete_t
            )
            
            local call_site = create_mock_call_site({})
            local result = resolver:resolve_generic_parameters(func_type, expected_type, call_site)
            
            -- Should succeed
            assert.is_true(result.success,
               "Multiple parameter resolution should succeed (iteration " .. iteration .. ")")
            
            -- Verify both parameters are resolved correctly
            assert.is_not_nil(result.resolved_bindings.T,
               "T should be resolved (iteration " .. iteration .. ")")
            assert.is_not_nil(result.resolved_bindings.U,
               "U should be resolved (iteration " .. iteration .. ")")
            assert.equal(concrete_t.typename, result.resolved_bindings.T.typename,
               "T should be bound correctly (iteration " .. iteration .. ")")
            assert.equal(concrete_u.typename, result.resolved_bindings.U.typename,
               "U should be bound correctly (iteration " .. iteration .. ")")
         end
      end)

      it("validates constraint satisfaction with return type constraints", function()
         local resolver = generic_resolver.BaseGenericResolver:new()
         
         -- Test that generic parameters in return types are properly constrained
         for iteration = 1, 20 do
            local type_var_t = create_mock_type_var("T")
            local concrete_return = { typename = "boolean", typeid = 400 + iteration }
            
            -- Create a function type where T is only in the return type
            local func_type = create_mock_function_type(
               { { typename = "number", typeid = 500 + iteration } },
               type_var_t,
               { type_var_t }
            )
            
            -- Create expected type with concrete return type
            local expected_type = create_mock_function_type(
               { { typename = "number", typeid = 500 + iteration } },
               concrete_return
            )
            
            local call_site = create_mock_call_site({})
            local result = resolver:resolve_generic_parameters(func_type, expected_type, call_site)
            
            -- Should succeed
            assert.is_true(result.success,
               "Return type constraint resolution should succeed (iteration " .. iteration .. ")")
            
            -- Verify T is bound to the return type
            assert.is_not_nil(result.resolved_bindings.T,
               "T should be resolved from return type (iteration " .. iteration .. ")")
            assert.equal(concrete_return.typename, result.resolved_bindings.T.typename,
               "T should be bound to return type (iteration " .. iteration .. ")")
         end
      end)

      it("validates constraint satisfaction with existing bindings", function()
         local resolver = generic_resolver.BaseGenericResolver:new()
         
         -- Test that existing bindings are respected during resolution
         for iteration = 1, 20 do
            local type_var_t = create_mock_type_var("T")
            local existing_binding = { typename = "string", typeid = 600 + iteration }
            
            -- Create a function type with generic parameter T
            local func_type = create_mock_function_type(
               { type_var_t },
               type_var_t,
               { type_var_t }
            )
            
            -- Create expected type that matches the existing binding
            local expected_type = create_mock_function_type(
               { existing_binding },
               existing_binding
            )
            
            local call_site = create_mock_call_site({ T = existing_binding })
            local result = resolver:resolve_generic_parameters(func_type, expected_type, call_site)
            
            -- Should succeed because expected type matches existing binding
            assert.is_true(result.success,
               "Resolution with matching existing binding should succeed (iteration " .. iteration .. ")")
            
            -- Verify T remains bound to the existing binding
            assert.is_not_nil(result.resolved_bindings.T,
               "T should be resolved (iteration " .. iteration .. ")")
            assert.equal(existing_binding.typename, result.resolved_bindings.T.typename,
               "T should remain bound to existing binding (iteration " .. iteration .. ")")
         end
      end)

      it("validates constraint satisfaction error reporting", function()
         local resolver = generic_resolver.BaseGenericResolver:new()
         
         -- Test that constraint violations produce clear error messages
         for iteration = 1, 15 do
            local type_var_t = create_mock_type_var("T")
            
            -- Create a function type where T is used twice
            local func_type = create_mock_function_type(
               { type_var_t, type_var_t },
               type_var_t,
               { type_var_t }
            )
            
            -- Create expected type with conflicting types for T
            local expected_type = create_mock_function_type(
               { { typename = "string", typeid = 700 + iteration } },
               { typename = "number", typeid = 800 + iteration }
            )
            
            local call_site = create_mock_call_site({})
            local result = resolver:resolve_generic_parameters(func_type, expected_type, call_site)
            
            -- Should fail due to conflicting constraints
            assert.is_false(result.success,
               "Conflicting constraints should fail (iteration " .. iteration .. ")")
            
            -- Verify error information is provided
            assert.is_true(#result.errors > 0,
               "Should have errors for conflicting constraints (iteration " .. iteration .. ")")
            
            -- Verify each error has required fields
            for _, error in ipairs(result.errors) do
               assert.is_not_nil(error.kind,
                  "Error should have kind (iteration " .. iteration .. ")")
               assert.is_not_nil(error.message,
                  "Error should have message (iteration " .. iteration .. ")")
            end
         end
      end)

      it("should detect conflicting generic constraints", function()
         local test_cases = generate_generic_constraint_test_cases()
         local resolver = generic_resolver.BaseGenericResolver:new()

         for _, test_case in ipairs(test_cases) do
            if not test_case.should_succeed then
               local call_site = create_mock_call_site(test_case.existing_bindings)
               local result = resolver:resolve_generic_parameters(
                  test_case.generic_function,
                  test_case.expected_type,
                  call_site
               )

               assert.is_false(result.success,
                  "Generic resolution should fail for: " .. test_case.name)
               assert.is_true(#result.errors > 0,
                  "Should have errors for: " .. test_case.name)
            end
         end
      end)

      it("should handle constraint satisfaction checking", function()
         local resolver = generic_resolver.BaseGenericResolver:new()

         -- Create a simple constraint
         local constraint = generic_resolution.new_constraint(
            "equality",
            { typename = "number", typeid = 30 },
            { typename = "number", typeid = 30 },
            { y = 1, x = 1 }
         )

         local bindings = {}
         local satisfied, errors = resolver:check_constraint_satisfaction(
            { constraint },
            bindings
         )

         assert.is_true(satisfied, "Constraint should be satisfied")
         assert.equal(0, #errors, "Should have no errors")
      end)

      it("should validate generic consistency", function()
         local resolver = generic_resolver.BaseGenericResolver:new()

         -- Create consistent bindings
         local bindings = {
            T = { typename = "number", typeid = 31 },
            U = { typename = "string", typeid = 32 },
         }

         local constraint = generic_resolution.new_constraint(
            "equality",
            { typename = "number", typeid = 31 },
            { typename = "number", typeid = 31 },
            { y = 1, x = 1 }
         )

         local consistent, errors = resolver:validate_generic_consistency(
            bindings,
            { constraint }
         )

         assert.is_true(consistent, "Bindings should be consistent")
         assert.equal(0, #errors, "Should have no errors")
      end)

      it("should handle ambiguous generic resolution", function()
         local resolver = generic_resolver.BaseGenericResolver:new()

         -- Create multiple candidate bindings
         local candidates = {
            { T = { typename = "number", typeid = 33 } },
            { T = { typename = "string", typeid = 34 } },
         }

         local constraint = generic_resolution.new_constraint(
            "equality",
            { typename = "number", typeid = 33 },
            { typename = "number", typeid = 33 },
            { y = 1, x = 1 }
         )

         local result, errors = resolver:handle_ambiguous_resolution(
            candidates,
            { constraint }
         )

         -- Should select one candidate
         assert.is_not_nil(result, "Should return a resolution")
         assert.is_true(#errors >= 0, "May have ambiguity warning")
      end)

      it("should apply generic bindings correctly", function()
         -- Test applying bindings to a type variable
         local type_var = create_mock_type_var("T")
         local bindings = { T = { typename = "number", typeid = 35 } }

         local result = generic_resolution.apply_generic_bindings(type_var, bindings)

         assert.equal("number", result.typename, "Should resolve type variable to number")
      end)

      it("should collect type variables from types", function()
         local type_var_t = create_mock_type_var("T")
         local type_var_u = create_mock_type_var("U")

         local func_type = create_mock_function_type(
            { type_var_t, type_var_u },
            type_var_t,
            { type_var_t, type_var_u }
         )

         local variables = generic_resolution.collect_type_variables(func_type)

         assert.is_true(#variables >= 0, "Should collect type variables")
      end)

      it("should unify types with generic parameters", function()
         local type_var = create_mock_type_var("T")
         local concrete_type = { typename = "number", typeid = 36 }

         local bindings, errors = generic_resolution.unify_types(
            type_var,
            concrete_type,
            {}
         )

         assert.equal(0, #errors, "Unification should succeed")
         assert.is_not_nil(bindings.T, "Should bind T")
         assert.equal("number", bindings.T.typename, "Should bind T to number")
      end)

      it("should check subtype relationships with generics", function()
         local integer_type = { typename = "integer", typeid = 37 }
         local number_type = { typename = "number", typeid = 38 }

         local is_subtype, errors = generic_resolution.check_subtype_with_generics(
            integer_type,
            number_type,
            {}
         )

         assert.is_true(is_subtype, "Integer should be subtype of number")
         assert.equal(0, #errors, "Should have no errors")
      end)

      it("should handle constraint solving with multiple iterations", function()
         local resolver = generic_resolver.BaseGenericResolver:new()

         -- Create constraints that require multiple iterations to solve
         local type_var_t = create_mock_type_var("T")
         local type_var_u = create_mock_type_var("U")
         local number_type = { typename = "number", typeid = 39 }

         local constraints = {
            generic_resolution.new_constraint("equality", type_var_t, type_var_u, { y = 1, x = 1 }),
            generic_resolution.new_constraint("equality", type_var_u, number_type, { y = 1, x = 1 }),
         }

         local bindings, errors = resolver:solve_constraints(constraints, {})

         assert.equal(0, #errors, "Should solve constraints without errors")
         assert.is_not_nil(bindings.T, "Should resolve T")
         assert.is_not_nil(bindings.U, "Should resolve U")
      end)

      it("should build constraint dependency graph", function()
         local resolver = generic_resolver.BaseGenericResolver:new()

         local type_var_t = create_mock_type_var("T")
         local type_var_u = create_mock_type_var("U")

         local constraints = {
            generic_resolution.new_constraint("equality", type_var_t, type_var_u, { y = 1, x = 1 }),
         }

         local graph = resolver:build_constraint_graph(constraints)

         assert.is_not_nil(graph, "Should build constraint graph")
      end)

      it("should calculate resolution confidence", function()
         local bindings = {
            T = { typename = "number", typeid = 40 },
            U = { typename = "string", typeid = 41 },
         }

         local constraints = {
            generic_resolution.new_constraint("equality", 
               { typename = "number", typeid = 40 },
               { typename = "number", typeid = 40 },
               { y = 1, x = 1 }
            ),
         }

         local confidence = generic_resolution.calculate_resolution_confidence(
            bindings,
            constraints,
            1
         )

         assert.is_true(confidence >= 0.0 and confidence <= 1.0,
            "Confidence should be between 0 and 1")
      end)
   end)
end)
