--------------------------------------------------------------------------------
-- Mixed Parameter Error Reporter for Contextual Typing
-- 
-- This module provides comprehensive error reporting for mixed parameter
-- scenarios, including detailed error messages, location tracking, and
-- suggestion mechanisms for fixing inference issues.
--------------------------------------------------------------------------------

local contextual_typing = require("teal.contextual_typing")
local type InferenceError = contextual_typing.InferenceError
local type ParameterInfo = contextual_typing.ParameterInfo
local type InferenceContext = contextual_typing.InferenceContext

local type types = require("teal.types")
local type Type = types.Type
local type FunctionType = types.FunctionType

local type errors = require("teal.errors")
local type Where = errors.Where

--------------------------------------------------------------------------------
-- Error Reporter Implementation
--------------------------------------------------------------------------------

local record MixedParameterErrorReporter
   -- Configuration for error reporting
   include_location_tracking: boolean
   include_suggestions: boolean
   include_related_locations: boolean
   verbose_mode: boolean
end

-- Create a new error reporter
function MixedParameterErrorReporter:new(): MixedParameterErrorReporter
   return {
      include_location_tracking = true,
      include_suggestions = true,
      include_related_locations = true,
      verbose_mode = false,
   }
end

--------------------------------------------------------------------------------
-- Error Message Generation
--------------------------------------------------------------------------------

-- Generate detailed error message for explicit/inferred type mismatch
function MixedParameterErrorReporter:generate_type_mismatch_error(
   param_index: integer,
   param_name: string,
   explicit_type: Type,
   expected_type: Type,
   location: Where
): InferenceError
   
   local explicit_typename = explicit_type.typename or "unknown"
   local expected_typename = expected_type.typename or "unknown"
   
   local message = string.format(
      "Parameter %d ('%s'): explicit type '%s' does not match expected type '%s'",
      param_index,
      param_name,
      explicit_typename,
      expected_typename
   )
   
   local error = contextual_typing.new_inference_error(
      "mixed_parameter_conflict",
      location,
      message,
      explicit_type,
      expected_type
   )
   
   -- Add detailed explanation
   error.suggested_fix = self:generate_type_mismatch_suggestions(
      param_index, param_name, explicit_typename, expected_typename
   )
   
   return error
end

-- Generate suggestions for type mismatch
function MixedParameterErrorReporter:generate_type_mismatch_suggestions(
   param_index: integer,
   param_name: string,
   explicit_typename: string,
   expected_typename: string
): string
   
   local suggestions = {}
   
   -- Suggestion 1: Change explicit type
   table.insert(suggestions, string.format(
      "Change parameter %d type from '%s' to '%s'",
      param_index,
      explicit_typename,
      expected_typename
   ))
   
   -- Suggestion 2: Remove explicit type
   table.insert(suggestions, string.format(
      "Remove explicit type annotation from parameter %d ('%s') to allow inference",
      param_index,
      param_name
   ))
   
   -- Suggestion 3: Adjust expected type
   table.insert(suggestions, string.format(
      "Adjust the expected function type to accept '%s' for parameter %d",
      explicit_typename,
      param_index
   ))
   
   -- Suggestion 4: Use union type if applicable
   if explicit_typename ~= "any" and expected_typename ~= "any" then
      table.insert(suggestions, string.format(
         "Use a union type for parameter %d: '%s | %s'",
         param_index,
         explicit_typename,
         expected_typename
      ))
   end
   
   return "Possible fixes:\n  • " .. table.concat(suggestions, "\n  • ")
end

-- Generate error for parameter count mismatch
function MixedParameterErrorReporter:generate_parameter_count_error(
   actual_count: integer,
   expected_count: integer,
   location: Where
): InferenceError
   
   local message = string.format(
      "Parameter count mismatch: function has %d parameters, expected %d",
      actual_count,
      expected_count
   )
   
   local error = contextual_typing.new_inference_error(
      "incompatible_signature",
      location,
      message,
      nil,
      nil
   )
   
   error.suggested_fix = self:generate_parameter_count_suggestions(actual_count, expected_count)
   
   return error
end

-- Generate suggestions for parameter count mismatch
function MixedParameterErrorReporter:generate_parameter_count_suggestions(
   actual_count: integer,
   expected_count: integer
): string
   
   local suggestions = {}
   
   if actual_count < expected_count then
      table.insert(suggestions, string.format(
         "Add %d more parameter(s) to the function",
         expected_count - actual_count
      ))
      table.insert(suggestions, "Use variadic parameters (...) to accept additional arguments")
   else
      table.insert(suggestions, string.format(
         "Remove %d parameter(s) from the function",
         actual_count - expected_count
      ))
      table.insert(suggestions, "Make some parameters optional by using default values")
   end
   
   table.insert(suggestions, "Adjust the expected function type to match the actual parameter count")
   
   return "Possible fixes:\n  • " .. table.concat(suggestions, "\n  • ")
end

-- Generate error for missing type information
function MixedParameterErrorReporter:generate_missing_type_error(
   param_index: integer,
   param_name: string,
   location: Where
): InferenceError
   
   local message = string.format(
      "Parameter %d ('%s'): no type information available (neither explicit nor inferred)",
      param_index,
      param_name
   )
   
   local error = contextual_typing.new_inference_error(
      "incompatible_signature",
      location,
      message,
      nil,
      nil
   )
   
   error.suggested_fix = string.format(
      "Add explicit type annotation to parameter %d: '%s: Type'",
      param_index,
      param_name
   )
   
   return error
end

-- Generate error for inference failure
function MixedParameterErrorReporter:generate_inference_failure_error(
   param_index: integer,
   param_name: string,
   reason: string,
   location: Where
): InferenceError
   
   local message = string.format(
      "Failed to infer type for parameter %d ('%s'): %s",
      param_index,
      param_name,
      reason
   )
   
   local error = contextual_typing.new_inference_error(
      "no_contextual_information",
      location,
      message,
      nil,
      nil
   )
   
   error.suggested_fix = string.format(
      "Add explicit type annotation to parameter %d to resolve the inference failure",
      param_index
   )
   
   return error
end

--------------------------------------------------------------------------------
-- Location Tracking
--------------------------------------------------------------------------------

-- Create location tracking information for error reporting
function MixedParameterErrorReporter:create_location_tracking(
   param_info: {ParameterInfo},
   expected_type: FunctionType,
   context: InferenceContext
): {
   parameter_locations: {integer: {
      name: string,
      position: Where,
      is_explicit: boolean,
      source_type: string
   }},
   expected_type_location: Where,
   call_site_location: Where,
   inference_context_location: Where
}
   
   local tracking = {
      parameter_locations = {},
      expected_type_location = expected_type.inferred_at,
      call_site_location = context.call_site.source_location,
      inference_context_location = context.call_site.source_location,
   }
   
   for i, param in ipairs(param_info) do
      tracking.parameter_locations[i] = {
         name = param.name,
         position = param.position,
         is_explicit = param.declared_type ~= nil,
         source_type = param.declared_type and "explicit_annotation" or "inference_context",
      }
   end
   
   return tracking
end

-- Add related locations to error for better context
function MixedParameterErrorReporter:add_related_locations(
   error: InferenceError,
   param_info: ParameterInfo,
   expected_type: FunctionType,
   context: InferenceContext
): InferenceError
   
   if not self.include_related_locations then
      return error
   end
   
   error.related_locations = {}
   
   -- Add parameter location
   if param_info.position then
      table.insert(error.related_locations, param_info.position)
   end
   
   -- Add expected type location
   if expected_type.inferred_at then
      table.insert(error.related_locations, expected_type.inferred_at)
   end
   
   -- Add call site location
   if context.call_site.source_location then
      table.insert(error.related_locations, context.call_site.source_location)
   end
   
   return error
end

--------------------------------------------------------------------------------
-- Suggestion Generation
--------------------------------------------------------------------------------

-- Generate suggestions for resolving mixed parameter issues
function MixedParameterErrorReporter:generate_resolution_suggestions(
   param_info: {ParameterInfo},
   expected_type: FunctionType,
   context: InferenceContext
): {string}
   
   local suggestions = {}
   
   -- Analyze parameter mix
   local has_explicit = false
   local has_untyped = false
   local explicit_count = 0
   local untyped_count = 0
   
   for _, param in ipairs(param_info) do
      if param.declared_type then
         has_explicit = true
         explicit_count = explicit_count + 1
      else
         has_untyped = true
         untyped_count = untyped_count + 1
      end
   end
   
   -- Generate suggestions based on parameter mix
   if has_explicit and has_untyped then
      table.insert(suggestions, "You have a mix of explicit and untyped parameters")
      table.insert(suggestions, string.format(
         "Explicit parameters: %d, Untyped parameters: %d",
         explicit_count,
         untyped_count
      ))
      table.insert(suggestions, "Consider either:")
      table.insert(suggestions, "  1. Making all parameters explicit for clarity")
      table.insert(suggestions, "  2. Making all parameters untyped to rely on inference")
      table.insert(suggestions, "  3. Ensuring explicit types match the expected function signature")
   elseif has_explicit then
      table.insert(suggestions, "All parameters are explicitly typed")
      table.insert(suggestions, "Verify that explicit types match the expected function signature")
   else
      table.insert(suggestions, "All parameters are untyped and will be inferred")
      table.insert(suggestions, "Ensure the expected function type provides sufficient type information")
   end
   
   return suggestions
end

-- Generate detailed diagnostic information
function MixedParameterErrorReporter:generate_diagnostic_info(
   param_info: {ParameterInfo},
   expected_type: FunctionType,
   context: InferenceContext
): string
   
   local info = {}
   
   table.insert(info, "=== Mixed Parameter Diagnostic Information ===")
   table.insert(info, "")
   
   -- Parameter information
   table.insert(info, "Parameters:")
   for i, param in ipairs(param_info) do
      local param_type = param.declared_type and param.declared_type.typename or "untyped"
      local source = param.declared_type and "explicit" or "inferred"
      table.insert(info, string.format(
         "  [%d] %s: %s (%s)",
         i,
         param.name,
         param_type,
         source
      ))
   end
   
   table.insert(info, "")
   
   -- Expected type information
   table.insert(info, "Expected Function Type:")
   if expected_type.args and expected_type.args.tuple then
      for i, param_type in ipairs(expected_type.args.tuple) do
         table.insert(info, string.format(
            "  [%d] %s",
            i,
            param_type.typename or "unknown"
         ))
      end
   end
   
   table.insert(info, "")
   
   -- Context information
   table.insert(info, "Inference Context:")
   table.insert(info, string.format("  Source: %s", context.source))
   table.insert(info, string.format("  Depth: %d", context.inference_depth))
   table.insert(info, string.format("  Call Site: %s", context.call_site.function_name))
   
   return table.concat(info, "\n")
end

--------------------------------------------------------------------------------
-- Error Formatting
--------------------------------------------------------------------------------

-- Format error message with full context
function MixedParameterErrorReporter:format_error_with_context(
   error: InferenceError,
   param_info: {ParameterInfo},
   expected_type: FunctionType,
   context: InferenceContext
): string
   
   local formatted = {}
   
   -- Main error message
   table.insert(formatted, "Error: " .. error.message)
   table.insert(formatted, "")
   
   -- Location information
   if error.location then
      table.insert(formatted, "Location: " .. tostring(error.location))
   end
   
   -- Related locations
   if error.related_locations and #error.related_locations > 0 then
      table.insert(formatted, "Related locations:")
      for _, loc in ipairs(error.related_locations) do
         table.insert(formatted, "  - " .. tostring(loc))
      end
   end
   
   table.insert(formatted, "")
   
   -- Suggested fix
   if error.suggested_fix then
      table.insert(formatted, "Suggested fix:")
      table.insert(formatted, error.suggested_fix)
   end
   
   -- Diagnostic information in verbose mode
   if self.verbose_mode then
      table.insert(formatted, "")
      table.insert(formatted, self:generate_diagnostic_info(param_info, expected_type, context))
   end
   
   return table.concat(formatted, "\n")
end

-- Create a summary of all errors
function MixedParameterErrorReporter:create_error_summary(
   errors: {InferenceError}
): string
   
   if #errors == 0 then
      return "No errors"
   end
   
   local summary = {}
   
   table.insert(summary, string.format("Found %d error(s):", #errors))
   table.insert(summary, "")
   
   for i, error in ipairs(errors) do
      table.insert(summary, string.format("[%d] %s", i, error.kind))
      table.insert(summary, "    " .. error.message)
      
      if error.suggested_fix then
         table.insert(summary, "    Fix: " .. error.suggested_fix)
      end
      
      table.insert(summary, "")
   end
   
   return table.concat(summary, "\n")
end

--------------------------------------------------------------------------------
-- Validation and Consistency Checking
--------------------------------------------------------------------------------

-- Validate error consistency
function MixedParameterErrorReporter:validate_error_consistency(
   errors: {InferenceError}
): boolean, {string}
   
   local issues = {}
   
   -- Check for duplicate errors
   local seen_messages = {}
   for _, error in ipairs(errors) do
      if seen_messages[error.message] then
         table.insert(issues, "Duplicate error message: " .. error.message)
      end
      seen_messages[error.message] = true
   end
   
   -- Check for errors without suggested fixes
   for i, error in ipairs(errors) do
      if not error.suggested_fix or error.suggested_fix == "" then
         table.insert(issues, string.format("Error %d has no suggested fix", i))
      end
   end
   
   -- Check for errors without location information
   for i, error in ipairs(errors) do
      if not error.location then
         table.insert(issues, string.format("Error %d has no location information", i))
      end
   end
   
   return #issues == 0, issues
end

--------------------------------------------------------------------------------
-- Module exports
--------------------------------------------------------------------------------

local mixed_parameter_error_reporter = {
   MixedParameterErrorReporter = MixedParameterErrorReporter,
}

return mixed_parameter_error_reporter
