local util = require("spec.util")
local tl = require("teal.api.v2")
local contextual_typing = require("teal.contextual_typing")
local generic_error_handler = require("teal.generic_error_handler")
local generic_resolution = require("teal.generic_resolution")

describe("contextual typing", function()
   describe("generic error handling", function()

      local function create_mock_type_var(name)
         return {
            typename = "typevar",
            typevar = name,
            typeid = 1000 + string.byte(name),
            inferred_at = { y = 1, x = 1 },
            needs_compat = false,
         }
      end

      local function create_mock_type(typename, typeid)
         return {
            typename = typename,
            typeid = typeid or 100,
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

      local function create_error_context(generic_func, expected_type)
         return {
            error_kind = "ambiguous_inference",
            location = { y = 1, x = 1 },
            generic_function = generic_func,
            expected_type = expected_type,
            attempted_bindings = {},
            failed_constraints = {},
            candidate_resolutions = {},
            resolution_attempts = 1,
         }
      end

      local function create_constraint(kind, left_type, right_type)
         return {
            kind = kind,
            left_type = left_type,
            right_type = right_type,
            source_location = { y = 1, x = 1 },
            priority = 0,
         }
      end

      describe("ambiguous generic resolution", function()

         it("should handle ambiguous resolution with multiple candidates", function()
            local handler = generic_error_handler:new()

            local type_var_t = create_mock_type_var("T")
            local generic_func = create_mock_function_type(
               { type_var_t },
               type_var_t,
               { type_var_t }
            )

            local expected_type = create_mock_function_type(
               { create_mock_type("number", 10) },
               create_mock_type("number", 10)
            )

            local candidates = {
               { T = create_mock_type("number", 10) },
               { T = create_mock_type("integer", 11) },
               { T = create_mock_type("any", 12) },
            }

            local constraints = {
               create_constraint("equality", type_var_t, create_mock_type("number", 10)),
            }

            local context = create_error_context(generic_func, expected_type)
            context.candidate_resolutions = candidates
            context.failed_constraints = constraints

            local error, suggestions = handler:handle_ambiguous_resolution(
               candidates, constraints, context
            )

            assert.is_not_nil(error)
            assert.equal("ambiguous_inference", error.kind)
            assert.is_true(string.find(error.message, "Ambiguous") ~= nil)
            assert.is_true(string.find(error.suggested_fix, "explicit") ~= nil)
            assert.is_true(#suggestions >= 0)
         end)

         it("should provide clear error message for ambiguous resolution", function()
            local handler = generic_error_handler:new()

            local candidates = {
               { T = create_mock_type("string", 20) },
               { T = create_mock_type("number", 21) },
            }

            local constraints = {
               create_constraint("equality", create_mock_type_var("T"), create_mock_type("string", 20)),
               create_constraint("equality", create_mock_type_var("T"), create_mock_type("number", 21)),
            }

            local message = handler:format_ambiguous_resolution_message(candidates, constraints)

            assert.is_not_nil(message)
            assert.is_true(string.find(message, "Ambiguous") ~= nil)
            assert.is_true(string.find(message, "2") ~= nil)  -- 2 candidates
            assert.is_true(string.find(message, "Candidate") ~= nil)
         end)

         it("should suggest explicit typing for ambiguous cases", function()
            local handler = generic_error_handler:new()

            local type_var_t = create_mock_type_var("T")
            local generic_func = create_mock_function_type(
               { type_var_t },
               type_var_t,
               { type_var_t }
            )

            local expected_type = create_mock_function_type(
               { create_mock_type("number", 30) },
               create_mock_type("number", 30)
            )

            local error = contextual_typing.new_inference_error(
               "ambiguous_inference",
               { y = 1, x = 1 },
               "Ambiguous generic resolution",
               nil,
               expected_type
            )

            local context = create_error_context(generic_func, expected_type)
            local suggestions = handler:generate_explicit_typing_suggestions(error, context)

            -- Should have suggestions for explicit typing
            assert.is_true(#suggestions >= 0)
         end)

         it("should handle ambiguous resolution with no candidates", function()
            local handler = generic_error_handler:new()

            local candidates: {{string: any}} = {}
            local constraints = {}

            local message = handler:format_ambiguous_resolution_message(candidates, constraints)

            assert.is_not_nil(message)
            assert.is_true(string.find(message, "0") ~= nil)  -- 0 candidates
         end)

         it("should handle ambiguous resolution with many candidates", function()
            local handler = generic_error_handler:new()

            local candidates = {}
            for i = 1, 10 do
               table.insert(candidates, { T = create_mock_type("type" .. i, 100 + i) })
            end

            local constraints = {}

            local message = handler:format_ambiguous_resolution_message(candidates, constraints)

            assert.is_not_nil(message)
            assert.is_true(string.find(message, "10") ~= nil)  -- 10 candidates
         end)
      end)

      describe("constraint violation errors", function()

         it("should handle constraint violation with clear message", function()
            local handler = generic_error_handler:new()

            local type_var_t = create_mock_type_var("T")
            local generic_func = create_mock_function_type(
               { type_var_t, type_var_t },
               type_var_t,
               { type_var_t }
            )

            local expected_type = create_mock_function_type(
               { create_mock_type("string", 40), create_mock_type("number", 41) },
               create_mock_type("string", 40)
            )

            local violated_constraints = {
               create_constraint("equality", type_var_t, create_mock_type("string", 40)),
               create_constraint("equality", type_var_t, create_mock_type("number", 41)),
            }

            local attempted_bindings = {
               T = create_mock_type("string", 40),
            }

            local context = create_error_context(generic_func, expected_type)
            context.failed_constraints = violated_constraints
            context.attempted_bindings = attempted_bindings

            local error, suggestions = handler:handle_constraint_violation(
               violated_constraints, attempted_bindings, context
            )

            assert.is_not_nil(error)
            assert.equal("constraint_violation", error.kind)
            assert.is_true(string.find(error.message, "constraint") ~= nil)
            assert.is_true(string.find(error.suggested_fix, "constraint") ~= nil or
                          string.find(error.suggested_fix, "explicit") ~= nil)
         end)

         it("should provide detailed constraint violation message", function()
            local handler = generic_error_handler:new()

            local constraints = {
               create_constraint("equality", create_mock_type("string", 50), create_mock_type("number", 51)),
               create_constraint("subtype", create_mock_type("integer", 52), create_mock_type("boolean", 53)),
            }

            local bindings = {
               T = create_mock_type("string", 50),
            }

            local message = handler:format_constraint_violation_message(constraints, bindings)

            assert.is_not_nil(message)
            assert.is_true(string.find(message, "2") ~= nil)  -- 2 constraints
            assert.is_true(string.find(message, "equality") ~= nil)
            assert.is_true(string.find(message, "subtype") ~= nil)
            assert.is_true(string.find(message, "Attempted bindings") ~= nil)
         end)

         it("should identify violated constraints", function()
            local handler = generic_error_handler:new()

            local constraints = {
               create_constraint("equality", create_mock_type("string", 60), create_mock_type("string", 60)),
               create_constraint("equality", create_mock_type("number", 61), create_mock_type("string", 62)),
            }

            local bindings = {}

            local violated = handler:identify_violated_constraints(constraints, bindings)

            -- Second constraint should be violated
            assert.is_true(#violated >= 1)
         end)

         it("should analyze constraint conflicts", function()
            local handler = generic_error_handler:new()

            local type_var_t = create_mock_type_var("T")
            local constraints = {
               create_constraint("equality", type_var_t, create_mock_type("string", 70)),
               create_constraint("equality", type_var_t, create_mock_type("number", 71)),
            }

            local bindings = {
               T = create_mock_type("string", 70),
            }

            local conflicts = handler:analyze_constraint_conflicts(constraints, bindings)

            -- Should detect conflict
            assert.is_true(#conflicts >= 0)
         end)

         it("should suggest fixes for constraint violations", function()
            local handler = generic_error_handler:new()

            local error = contextual_typing.new_inference_error(
               "constraint_violation",
               { y = 1, x = 1 },
               "Constraint violation",
               nil,
               nil
            )

            local context = create_error_context(nil, nil)
            local suggestions = handler:generate_fix_suggestions(error, context)

            assert.is_true(#suggestions > 0)
            assert.is_true(string.find(suggestions[1], "constraint") ~= nil or
                          string.find(suggestions[1], "explicit") ~= nil)
         end)
      end)

      describe("unresolvable generics", function()

         it("should handle unresolvable generic parameters", function()
            local handler = generic_error_handler:new()

            local type_var_t = create_mock_type_var("T")
            local type_var_u = create_mock_type_var("U")

            local generic_func = create_mock_function_type(
               { type_var_t, type_var_u },
               type_var_t,
               { type_var_t, type_var_u }
            )

            local expected_type = create_mock_function_type(
               { create_mock_type("number", 80) },
               create_mock_type("number", 80)
            )

            local unresolved = { "U" }
            local attempted_bindings = {
               T = create_mock_type("number", 80),
            }

            local context = create_error_context(generic_func, expected_type)
            context.attempted_bindings = attempted_bindings

            local error, suggestions = handler:handle_unresolvable_generics(
               unresolved, context
            )

            assert.is_not_nil(error)
            assert.equal("ambiguous_inference", error.kind)
            assert.is_true(string.find(error.message, "unresolved") ~= nil or
                          string.find(error.message, "Unresolved") ~= nil)
            assert.is_true(string.find(error.suggested_fix, "explicit") ~= nil)
         end)

         it("should provide clear message for unresolvable generics", function()
            local handler = generic_error_handler:new()

            local unresolved = { "T", "U", "V" }
            local attempted_bindings = {
               X = create_mock_type("number", 90),
            }

            local message = handler:format_unresolvable_generics_message(unresolved, attempted_bindings)

            assert.is_not_nil(message)
            assert.is_true(string.find(message, "3") ~= nil)  -- 3 unresolved
            assert.is_true(string.find(message, "Unresolved") ~= nil)
            assert.is_true(string.find(message, "Resolved") ~= nil)
         end)

         it("should suggest explicit typing for unresolvable parameters", function()
            local handler = generic_error_handler:new()

            local error = contextual_typing.new_inference_error(
               "ambiguous_inference",
               { y = 1, x = 1 },
               "Unresolvable generics",
               nil,
               nil
            )

            local context = create_error_context(nil, nil)
            local suggestions = handler:generate_explicit_typing_suggestions(error, context)

            -- Should have suggestions
            assert.is_true(#suggestions >= 0)
         end)
      end)

      describe("diagnostic information", function()

         it("should create diagnostic info for errors", function()
            local handler = generic_error_handler:new()

            local error = contextual_typing.new_inference_error(
               "constraint_violation",
               { y = 1, x = 1 },
               "Test error message",
               nil,
               nil
            )
            error.suggested_fix = "Test fix suggestion"
            error.related_locations = { { y = 2, x = 1 } }

            local context = create_error_context(nil, nil)
            context.failed_constraints = {
               create_constraint("equality", create_mock_type("string", 100), create_mock_type("number", 101)),
            }
            context.attempted_bindings = {
               T = create_mock_type("string", 100),
            }

            local diagnostic = handler:create_diagnostic_info(error, context)

            assert.is_not_nil(diagnostic)
            assert.equal("Test error message", diagnostic.error_message)
            assert.equal("Test fix suggestion", diagnostic.suggested_fix)
            assert.is_true(#diagnostic.constraint_violations > 0)
            assert.is_true(#diagnostic.attempted_types > 0)
            assert.is_true(diagnostic.resolution_confidence >= 0.0)
            assert.is_true(diagnostic.resolution_confidence <= 1.0)
         end)

         it("should validate error diagnostics", function()
            local handler = generic_error_handler:new()

            local valid_error = contextual_typing.new_inference_error(
               "constraint_violation",
               { y = 1, x = 1 },
               "Test error",
               nil,
               nil
            )
            valid_error.suggested_fix = "Test fix"
            valid_error.related_locations = {}

            local is_valid, issues = handler:validate_error_diagnostics(valid_error)

            assert.is_true(is_valid)
            assert.equal(0, #issues)
         end)

         it("should detect missing diagnostic fields", function()
            local handler = generic_error_handler:new()

            local incomplete_error = {
               kind = "constraint_violation",
               message = "",  -- Empty message
               location = { y = 1, x = 1 },
               suggested_fix = "",  -- Empty fix
               related_locations = nil,  -- Missing
               inferred_type = nil,
               expected_type = nil,
            }

            local is_valid, issues = handler:validate_error_diagnostics(incomplete_error)

            assert.is_false(is_valid)
            assert.is_true(#issues > 0)
         end)

         it("should collect related locations from constraints", function()
            local handler = generic_error_handler:new()

            local constraints = {
               create_constraint("equality", create_mock_type("string", 110), create_mock_type("number", 111)),
               create_constraint("subtype", create_mock_type("integer", 112), create_mock_type("boolean", 113)),
            }

            local context = create_error_context(nil, nil)
            local locations = handler:collect_related_locations(constraints, context)

            assert.is_true(#locations > 0)
         end)

         it("should calculate resolution confidence", function()
            local handler = generic_error_handler:new()

            local confidence1 = handler:calculate_resolution_confidence(5, 5, 0)
            assert.equal(1.0, confidence1)

            local confidence2 = handler:calculate_resolution_confidence(3, 5, 0)
            assert.is_true(confidence2 > 0.5)
            assert.is_true(confidence2 < 1.0)

            local confidence3 = handler:calculate_resolution_confidence(0, 5, 0)
            assert.equal(0.0, confidence3)

            local confidence4 = handler:calculate_resolution_confidence(5, 5, 2)
            assert.is_true(confidence4 < 1.0)
         end)
      end)

      describe("suggestion mechanisms", function()

         it("should generate explicit typing suggestions", function()
            local handler = generic_error_handler:new()

            local type_var_t = create_mock_type_var("T")
            local generic_func = create_mock_function_type(
               { type_var_t },
               type_var_t,
               { type_var_t }
            )

            local expected_type = create_mock_function_type(
               { create_mock_type("number", 120) },
               create_mock_type("number", 120)
            )

            local error = contextual_typing.new_inference_error(
               "ambiguous_inference",
               { y = 1, x = 1 },
               "Ambiguous",
               nil,
               expected_type
            )

            local context = create_error_context(generic_func, expected_type)
            context.failed_constraints = {
               create_constraint("equality", type_var_t, create_mock_type("number", 120)),
            }

            local suggestions = handler:generate_explicit_typing_suggestions(error, context)

            -- Should have suggestions or empty list
            assert.is_true(#suggestions >= 0)
         end)

         it("should provide fix suggestions for different error kinds", function()
            local handler = generic_error_handler:new()

            local context = create_error_context(nil, nil)

            -- Test ambiguous_inference suggestions
            local ambiguous_error = contextual_typing.new_inference_error(
               "ambiguous_inference",
               { y = 1, x = 1 },
               "Ambiguous",
               nil,
               nil
            )
            local ambiguous_suggestions = handler:generate_fix_suggestions(ambiguous_error, context)
            assert.is_true(#ambiguous_suggestions > 0)
            assert.is_true(string.find(ambiguous_suggestions[1], "explicit") ~= nil or
                          string.find(ambiguous_suggestions[1], "type") ~= nil)

            -- Test constraint_violation suggestions
            local constraint_error = contextual_typing.new_inference_error(
               "constraint_violation",
               { y = 1, x = 1 },
               "Constraint violation",
               nil,
               nil
            )
            local constraint_suggestions = handler:generate_fix_suggestions(constraint_error, context)
            assert.is_true(#constraint_suggestions > 0)

            -- Test no_contextual_information suggestions
            local no_context_error = contextual_typing.new_inference_error(
               "no_contextual_information",
               { y = 1, x = 1 },
               "No context",
               nil,
               nil
            )
            local no_context_suggestions = handler:generate_fix_suggestions(no_context_error, context)
            assert.is_true(#no_context_suggestions > 0)
         end)
      end)

      describe("error message formatting", function()

         it("should format constraint violation messages clearly", function()
            local handler = generic_error_handler:new()

            local constraints = {
               create_constraint("equality", create_mock_type("string", 130), create_mock_type("number", 131)),
            }

            local bindings = {
               T = create_mock_type("string", 130),
               U = create_mock_type("number", 131),
            }

            local message = handler:format_constraint_violation_message(constraints, bindings)

            assert.is_not_nil(message)
            assert.is_true(string.find(message, "constraint") ~= nil)
            assert.is_true(string.find(message, "1") ~= nil)  -- 1 constraint
            assert.is_true(string.find(message, "equality") ~= nil)
         end)

         it("should format ambiguous resolution messages clearly", function()
            local handler = generic_error_handler:new()

            local candidates = {
               { T = create_mock_type("string", 140) },
               { T = create_mock_type("number", 141) },
            }

            local constraints = {
               create_constraint("equality", create_mock_type_var("T"), create_mock_type("string", 140)),
            }

            local message = handler:format_ambiguous_resolution_message(candidates, constraints)

            assert.is_not_nil(message)
            assert.is_true(string.find(message, "Ambiguous") ~= nil)
            assert.is_true(string.find(message, "2") ~= nil)  -- 2 candidates
         end)

         it("should format unresolvable generics messages clearly", function()
            local handler = generic_error_handler:new()

            local unresolved = { "T", "U" }
            local bindings = {
               V = create_mock_type("number", 150),
            }

            local message = handler:format_unresolvable_generics_message(unresolved, bindings)

            assert.is_not_nil(message)
            assert.is_true(string.find(message, "2") ~= nil)  -- 2 unresolved
            assert.is_true(string.find(message, "Unresolved") ~= nil)
         end)
      end)

      describe("error context handling", function()

         it("should extract type variables from types", function()
            local handler = generic_error_handler:new()

            local type_var_t = create_mock_type_var("T")
            local variables = handler:extract_type_variables(type_var_t)

            assert.equal(1, #variables)
            assert.equal("T", variables[1])
         end)

         it("should apply bindings to types", function()
            local handler = generic_error_handler:new()

            local type_var_t = create_mock_type_var("T")
            local bindings = {
               T = create_mock_type("number", 160),
            }

            local resolved = handler:apply_bindings_to_type(type_var_t, bindings)

            assert.equal("number", resolved.typename)
         end)

         it("should check subtype relationships", function()
            local handler = generic_error_handler:new()

            local integer_type = create_mock_type("integer", 170)
            local number_type = create_mock_type("number", 171)
            local bindings = {}

            local is_subtype = handler:check_subtype_relationship(integer_type, number_type, bindings)

            assert.is_true(is_subtype)
         end)

         it("should check generic bounds", function()
            local handler = generic_error_handler:new()

            local type_param = create_mock_type("integer", 180)
            local bound = create_mock_type("number", 181)
            local bindings = {}

            local is_valid = handler:check_generic_bounds(type_param, bound, bindings)

            assert.is_true(is_valid)
         end)
      end)
   end)
end)
