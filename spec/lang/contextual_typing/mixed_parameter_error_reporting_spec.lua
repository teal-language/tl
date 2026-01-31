local util = require("spec.util")
local tl = require("teal.api.v2")
local contextual_typing = require("teal.contextual_typing")
local mixed_parameter_error_reporter = require("teal.mixed_parameter_error_reporter")

describe("contextual typing", function()
   describe("mixed parameter error reporting", function()
      
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
      
      describe("error message content and clarity", function()
         
         it("generates clear error message for type mismatch", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local explicit_type = { typename = "string", typeid = 200 }
            local expected_type = { typename = "number", typeid = 201 }
            local location = { y = 1, x = 1 }
            
            local error = reporter:generate_type_mismatch_error(
               1, "x", explicit_type, expected_type, location
            )
            
            assert.equal("mixed_parameter_conflict", error.kind)
            assert.is_not_nil(error.message)
            assert.is_true(string.len(error.message) > 0)
            assert.is_true(string.find(error.message, "Parameter 1") ~= nil)
            assert.is_true(string.find(error.message, "string") ~= nil)
            assert.is_true(string.find(error.message, "number") ~= nil)
            assert.is_not_nil(error.suggested_fix)
            assert.is_true(string.len(error.suggested_fix) > 0)
         end)
         
         it("generates clear error message for parameter count mismatch", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local location = { y = 1, x = 1 }
            local error = reporter:generate_parameter_count_error(3, 2, location)
            
            assert.equal("incompatible_signature", error.kind)
            assert.is_not_nil(error.message)
            assert.is_true(string.find(error.message, "3") ~= nil)
            assert.is_true(string.find(error.message, "2") ~= nil)
            assert.is_true(string.find(error.message, "Parameter count mismatch") ~= nil)
            assert.is_not_nil(error.suggested_fix)
         end)
         
         it("generates clear error message for missing type information", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local location = { y = 1, x = 1 }
            local error = reporter:generate_missing_type_error(2, "y", location)
            
            assert.equal("incompatible_signature", error.kind)
            assert.is_not_nil(error.message)
            assert.is_true(string.find(error.message, "Parameter 2") ~= nil)
            assert.is_true(string.find(error.message, "no type information") ~= nil)
            assert.is_not_nil(error.suggested_fix)
            assert.is_true(string.find(error.suggested_fix, "explicit type annotation") ~= nil)
         end)
         
         it("generates clear error message for inference failure", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local location = { y = 1, x = 1 }
            local error = reporter:generate_inference_failure_error(
               1, "x", "no contextual information available", location
            )
            
            assert.equal("no_contextual_information", error.kind)
            assert.is_not_nil(error.message)
            assert.is_true(string.find(error.message, "Failed to infer") ~= nil)
            assert.is_true(string.find(error.message, "Parameter 1") ~= nil)
            assert.is_not_nil(error.suggested_fix)
         end)
         
         it("includes parameter name in error messages", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local explicit_type = { typename = "boolean", typeid = 300 }
            local expected_type = { typename = "string", typeid = 301 }
            local location = { y = 1, x = 1 }
            
            local error = reporter:generate_type_mismatch_error(
               2, "callback", explicit_type, expected_type, location
            )
            
            assert.is_true(string.find(error.message, "callback") ~= nil)
            assert.is_true(string.find(error.message, "Parameter 2") ~= nil)
         end)
         
         it("includes type names in error messages", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local explicit_type = { typename = "integer", typeid = 400 }
            local expected_type = { typename = "number", typeid = 401 }
            local location = { y = 1, x = 1 }
            
            local error = reporter:generate_type_mismatch_error(
               1, "x", explicit_type, expected_type, location
            )
            
            assert.is_true(string.find(error.message, "integer") ~= nil)
            assert.is_true(string.find(error.message, "number") ~= nil)
         end)
         
      end)
      
      describe("location tracking accuracy", function()
         
         it("tracks parameter locations correctly", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local param_info = {
               {
                  name = "x",
                  declared_type = { typename = "number", typeid = 500 },
                  inferred_type = nil,
                  position = { y = 10, x = 5 },
                  is_inferred = false,
                  inference_confidence = 1.0,
                  inference_source = "explicit_annotation"
               },
               {
                  name = "y",
                  declared_type = nil,
                  inferred_type = nil,
                  position = { y = 10, x = 15 },
                  is_inferred = true,
                  inference_confidence = 0.8,
                  inference_source = "call_site"
               }
            }
            
            local expected_type = create_function_type({
               { typename = "number", typeid = 501 },
               { typename = "string", typeid = 502 }
            })
            
            local context = create_mock_inference_context(expected_type)
            
            local tracking = reporter:create_location_tracking(param_info, expected_type, context)
            
            assert.is_not_nil(tracking.parameter_locations)
            assert.equal(2, #tracking.parameter_locations)
            assert.equal("x", tracking.parameter_locations[1].name)
            assert.equal("y", tracking.parameter_locations[2].name)
            assert.equal(true, tracking.parameter_locations[1].is_explicit)
            assert.equal(false, tracking.parameter_locations[2].is_explicit)
         end)
         
         it("tracks expected type location", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local param_info = {}
            local expected_type = create_function_type({
               { typename = "number", typeid = 600 }
            })
            
            local context = create_mock_inference_context(expected_type)
            
            local tracking = reporter:create_location_tracking(param_info, expected_type, context)
            
            assert.is_not_nil(tracking.expected_type_location)
            assert.equal(expected_type.inferred_at, tracking.expected_type_location)
         end)
         
         it("tracks call site location", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local param_info = {}
            local expected_type = create_function_type({
               { typename = "number", typeid = 700 }
            })
            
            local context = create_mock_inference_context(expected_type)
            
            local tracking = reporter:create_location_tracking(param_info, expected_type, context)
            
            assert.is_not_nil(tracking.call_site_location)
            assert.equal(context.call_site.source_location, tracking.call_site_location)
         end)
         
         it("adds related locations to errors", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local param_info = {
               {
                  name = "x",
                  declared_type = { typename = "number", typeid = 800 },
                  inferred_type = nil,
                  position = { y = 20, x = 10 },
                  is_inferred = false,
                  inference_confidence = 1.0,
                  inference_source = "explicit_annotation"
               }
            }
            
            local expected_type = create_function_type({
               { typename = "string", typeid = 801 }
            })
            
            local context = create_mock_inference_context(expected_type)
            
            local error = reporter:generate_type_mismatch_error(
               1, "x", param_info[1].declared_type, expected_type.args.tuple[1], param_info[1].position
            )
            
            error = reporter:add_related_locations(error, param_info[1], expected_type, context)
            
            assert.is_not_nil(error.related_locations)
            assert.is_true(#error.related_locations > 0)
         end)
         
      end)
      
      describe("suggestion generation quality", function()
         
         it("generates multiple suggestions for type mismatch", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local suggestions = reporter:generate_type_mismatch_suggestions(
               1, "x", "string", "number"
            )
            
            assert.is_not_nil(suggestions)
            assert.is_true(string.len(suggestions) > 0)
            assert.is_true(string.find(suggestions, "Change parameter") ~= nil)
            assert.is_true(string.find(suggestions, "Remove explicit type") ~= nil)
            assert.is_true(string.find(suggestions, "Adjust the expected") ~= nil)
         end)
         
         it("generates suggestions for parameter count mismatch", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local suggestions = reporter:generate_parameter_count_suggestions(3, 2)
            
            assert.is_not_nil(suggestions)
            assert.is_true(string.len(suggestions) > 0)
            assert.is_true(string.find(suggestions, "Remove") ~= nil)
         end)
         
         it("generates suggestions for fewer parameters", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local suggestions = reporter:generate_parameter_count_suggestions(2, 3)
            
            assert.is_not_nil(suggestions)
            assert.is_true(string.find(suggestions, "Add") ~= nil)
         end)
         
         it("generates resolution suggestions for mixed parameters", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local param_info = {
               {
                  name = "x",
                  declared_type = { typename = "number", typeid = 900 },
                  inferred_type = nil,
                  position = { y = 1, x = 1 },
                  is_inferred = false,
                  inference_confidence = 1.0,
                  inference_source = "explicit_annotation"
               },
               {
                  name = "y",
                  declared_type = nil,
                  inferred_type = nil,
                  position = { y = 1, x = 1 },
                  is_inferred = true,
                  inference_confidence = 0.8,
                  inference_source = "call_site"
               }
            }
            
            local expected_type = create_function_type({
               { typename = "number", typeid = 901 },
               { typename = "string", typeid = 902 }
            })
            
            local context = create_mock_inference_context(expected_type)
            
            local suggestions = reporter:generate_resolution_suggestions(
               param_info, expected_type, context
            )
            
            assert.is_not_nil(suggestions)
            assert.is_true(#suggestions > 0)
            assert.is_true(string.find(suggestions[1], "mix") ~= nil)
         end)
         
         it("suggests union types when applicable", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local suggestions = reporter:generate_type_mismatch_suggestions(
               1, "x", "string", "number"
            )
            
            assert.is_true(string.find(suggestions, "union type") ~= nil or
                          string.find(suggestions, "|") ~= nil)
         end)
         
      end)
      
      describe("error formatting and presentation", function()
         
         it("formats error with context information", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local param_info = {
               {
                  name = "x",
                  declared_type = { typename = "number", typeid = 1000 },
                  inferred_type = nil,
                  position = { y = 1, x = 1 },
                  is_inferred = false,
                  inference_confidence = 1.0,
                  inference_source = "explicit_annotation"
               }
            }
            
            local expected_type = create_function_type({
               { typename = "string", typeid = 1001 }
            })
            
            local context = create_mock_inference_context(expected_type)
            
            local error = reporter:generate_type_mismatch_error(
               1, "x", param_info[1].declared_type, expected_type.args.tuple[1], param_info[1].position
            )
            
            local formatted = reporter:format_error_with_context(
               error, param_info, expected_type, context
            )
            
            assert.is_not_nil(formatted)
            assert.is_true(string.len(formatted) > 0)
            assert.is_true(string.find(formatted, "Error:") ~= nil)
            assert.is_true(string.find(formatted, "Suggested fix") ~= nil)
         end)
         
         it("creates error summary for multiple errors", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local error1 = contextual_typing.new_inference_error(
               "mixed_parameter_conflict",
               { y = 1, x = 1 },
               "Parameter 1 type mismatch",
               nil,
               nil
            )
            error1.suggested_fix = "Change parameter type"
            
            local error2 = contextual_typing.new_inference_error(
               "incompatible_signature",
               { y = 1, x = 1 },
               "Parameter count mismatch",
               nil,
               nil
            )
            error2.suggested_fix = "Add more parameters"
            
            local summary = reporter:create_error_summary({ error1, error2 })
            
            assert.is_not_nil(summary)
            assert.is_true(string.find(summary, "2 error") ~= nil)
            assert.is_true(string.find(summary, "mixed_parameter_conflict") ~= nil)
            assert.is_true(string.find(summary, "incompatible_signature") ~= nil)
         end)
         
         it("includes diagnostic information in verbose mode", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            reporter.verbose_mode = true
            
            local param_info = {
               {
                  name = "x",
                  declared_type = { typename = "number", typeid = 1100 },
                  inferred_type = nil,
                  position = { y = 1, x = 1 },
                  is_inferred = false,
                  inference_confidence = 1.0,
                  inference_source = "explicit_annotation"
               }
            }
            
            local expected_type = create_function_type({
               { typename = "string", typeid = 1101 }
            })
            
            local context = create_mock_inference_context(expected_type)
            
            local error = reporter:generate_type_mismatch_error(
               1, "x", param_info[1].declared_type, expected_type.args.tuple[1], param_info[1].position
            )
            
            local formatted = reporter:format_error_with_context(
               error, param_info, expected_type, context
            )
            
            assert.is_true(string.find(formatted, "Diagnostic") ~= nil or
                          string.find(formatted, "Parameters:") ~= nil)
         end)
         
      end)
      
      describe("diagnostic information generation", function()
         
         it("generates diagnostic info with parameter details", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local param_info = {
               {
                  name = "x",
                  declared_type = { typename = "number", typeid = 1200 },
                  inferred_type = nil,
                  position = { y = 1, x = 1 },
                  is_inferred = false,
                  inference_confidence = 1.0,
                  inference_source = "explicit_annotation"
               },
               {
                  name = "y",
                  declared_type = nil,
                  inferred_type = nil,
                  position = { y = 1, x = 1 },
                  is_inferred = true,
                  inference_confidence = 0.8,
                  inference_source = "call_site"
               }
            }
            
            local expected_type = create_function_type({
               { typename = "number", typeid = 1201 },
               { typename = "string", typeid = 1202 }
            })
            
            local context = create_mock_inference_context(expected_type)
            
            local diagnostic = reporter:generate_diagnostic_info(param_info, expected_type, context)
            
            assert.is_not_nil(diagnostic)
            assert.is_true(string.find(diagnostic, "Parameters:") ~= nil)
            assert.is_true(string.find(diagnostic, "x") ~= nil)
            assert.is_true(string.find(diagnostic, "y") ~= nil)
            assert.is_true(string.find(diagnostic, "Expected Function Type") ~= nil)
         end)
         
         it("includes inference context in diagnostic info", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local param_info = {}
            local expected_type = create_function_type({
               { typename = "number", typeid = 1300 }
            })
            
            local context = create_mock_inference_context(expected_type)
            
            local diagnostic = reporter:generate_diagnostic_info(param_info, expected_type, context)
            
            assert.is_true(string.find(diagnostic, "Inference Context") ~= nil)
            assert.is_true(string.find(diagnostic, "call_site") ~= nil)
         end)
         
      end)
      
      describe("error validation and consistency", function()
         
         it("validates error consistency", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local error1 = contextual_typing.new_inference_error(
               "mixed_parameter_conflict",
               { y = 1, x = 1 },
               "Parameter 1 type mismatch",
               nil,
               nil
            )
            error1.suggested_fix = "Change parameter type"
            
            local error2 = contextual_typing.new_inference_error(
               "incompatible_signature",
               { y = 1, x = 1 },
               "Parameter count mismatch",
               nil,
               nil
            )
            error2.suggested_fix = "Add more parameters"
            
            local is_consistent, issues = reporter:validate_error_consistency({ error1, error2 })
            
            assert.equal(true, is_consistent)
            assert.equal(0, #issues)
         end)
         
         it("detects duplicate error messages", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local error1 = contextual_typing.new_inference_error(
               "mixed_parameter_conflict",
               { y = 1, x = 1 },
               "Duplicate message",
               nil,
               nil
            )
            error1.suggested_fix = "Fix 1"
            
            local error2 = contextual_typing.new_inference_error(
               "mixed_parameter_conflict",
               { y = 1, x = 1 },
               "Duplicate message",
               nil,
               nil
            )
            error2.suggested_fix = "Fix 2"
            
            local is_consistent, issues = reporter:validate_error_consistency({ error1, error2 })
            
            assert.equal(false, is_consistent)
            assert.is_true(#issues > 0)
         end)
         
         it("detects errors without suggested fixes", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local error1 = contextual_typing.new_inference_error(
               "mixed_parameter_conflict",
               { y = 1, x = 1 },
               "Error without fix",
               nil,
               nil
            )
            error1.suggested_fix = nil
            
            local is_consistent, issues = reporter:validate_error_consistency({ error1 })
            
            assert.equal(false, is_consistent)
            assert.is_true(#issues > 0)
         end)
         
         it("detects errors without location information", function()
            local reporter = mixed_parameter_error_reporter.MixedParameterErrorReporter:new()
            
            local error1 = contextual_typing.new_inference_error(
               "mixed_parameter_conflict",
               nil,
               "Error without location",
               nil,
               nil
            )
            error1.suggested_fix = "Fix it"
            
            local is_consistent, issues = reporter:validate_error_consistency({ error1 })
            
            assert.equal(false, is_consistent)
            assert.is_true(#issues > 0)
         end)
         
      end)
      
   end)
end)
