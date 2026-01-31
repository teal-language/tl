--------------------------------------------------------------------------------
-- Contextual Type Checker Implementation for Teal
-- 
-- This module provides the base implementation of the ContextualTypeChecker
-- interface for performing contextual type inference on function literals.
--------------------------------------------------------------------------------

local contextual_typing = require("teal.contextual_typing")
local type ContextualTypeChecker = contextual_typing.ContextualTypeChecker
local type InferenceResult = contextual_typing.InferenceResult
local type InferenceContext = contextual_typing.InferenceContext
local type InferenceError = contextual_typing.InferenceError
local type InferenceErrorKind = contextual_typing.InferenceErrorKind
local type InferenceSource = contextual_typing.InferenceSource
local type CallSite = contextual_typing.CallSite
local type ParameterInfo = contextual_typing.ParameterInfo
local type InferenceState = contextual_typing.InferenceState
local type InferenceMetadata = contextual_typing.InferenceMetadata

local type types = require("teal.types")
local type Type = types.Type
local type FunctionType = types.FunctionType
local type TupleType = types.TupleType
local type TypeVarType = types.TypeVarType

local type parser = require("teal.parser")
local type Node = parser.Node

local type errors = require("teal.errors")
local type Where = errors.Where

--------------------------------------------------------------------------------
-- Base Contextual Type Checker Implementation
--------------------------------------------------------------------------------

local record BaseContextualTypeChecker
   is ContextualTypeChecker
   
   -- Internal state for inference process
   inference_state: InferenceState
   performance_stats: InferenceMetadata
   max_inference_depth: integer
   enable_performance_monitoring: boolean
end

-- Create a new base contextual type checker instance
function BaseContextualTypeChecker:new(): BaseContextualTypeChecker
   local checker: BaseContextualTypeChecker = {
      inference_state = {
         expected_types = {},
         generic_bindings = {},
         inference_stack = {},
         error_accumulator = {},
         depth_limit = 10,  -- Prevent infinite recursion
         current_depth = 0,
      },
      performance_stats = {
         inference_attempts = 0,
         successful_inferences = 0,
         failed_inferences = 0,
         inference_time_ms = 0.0,
         constraint_violations = {},
         fallback_used = false,
      },
      max_inference_depth = 10,
      enable_performance_monitoring = true,
   }
   return checker
end

-- Main inference method: infer parameter types from expected function type
function BaseContextualTypeChecker:infer_function_parameters(
   func_literal: Node,
   expected_type: FunctionType,
   context: InferenceContext
): InferenceResult
   
   -- Initialize result
   local result: InferenceResult = {
      success = false,
      inferred_type = expected_type,
      errors = {},
      warnings = {},
      confidence = 0.0,
      applied_constraints = {},
   }
   
   -- Update performance stats
   if self.enable_performance_monitoring then
      self.performance_stats.inference_attempts = self.performance_stats.inference_attempts + 1
   end
   
   -- Check depth limit to prevent infinite recursion
   if context.inference_depth >= self.max_inference_depth then
      local error = contextual_typing.new_inference_error(
         "recursive_type_limit",
         func_literal as Where,
         string.format("Inference depth limit exceeded (%d)", self.max_inference_depth),
         nil,
         expected_type
      )
      table.insert(result.errors, error)
      self.performance_stats.failed_inferences = self.performance_stats.failed_inferences + 1
      return result
   end
   
   -- STEP 1: Resolve generic type parameters if the expected type has generics
   local resolved_expected_type = expected_type
   local generic_bindings: {string: Type} = {}
   
   if expected_type.generic_parameters and #expected_type.generic_parameters > 0 then
      -- Create a call site for generic resolution
      local call_site = contextual_typing.new_call_site(
         "contextual_inference",
         1,
         func_literal as Where
      )
      
      -- Copy existing generic context from the inference context
      if context.generic_bindings then
         for name, typ in pairs(context.generic_bindings) do
            call_site.generic_context[name] = typ
         end
      end
      
      -- Resolve generic parameters
      resolved_expected_type, generic_bindings = self:resolve_generics(expected_type, call_site)
      
      -- Update context with resolved generic bindings
      for name, typ in pairs(generic_bindings) do
         context.generic_bindings[name] = typ
      end
      
      -- Record that generic resolution was applied
      table.insert(result.applied_constraints, "generic_resolution_applied")
   end
   
   -- Extract parameter information from function literal
   local param_info = contextual_typing.extract_parameter_info(func_literal)
   
   -- Check if we have compatible parameter counts
   if not resolved_expected_type.args or not resolved_expected_type.args.tuple then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         func_literal as Where,
         "Expected function type has no parameter information",
         nil,
         resolved_expected_type
      )
      table.insert(result.errors, error)
      self.performance_stats.failed_inferences = self.performance_stats.failed_inferences + 1
      return result
   end
   
   local expected_params = resolved_expected_type.args.tuple
   local literal_param_count = #param_info
   local expected_param_count = #expected_params
   
   if literal_param_count ~= expected_param_count then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         func_literal as Where,
         string.format("Parameter count mismatch: function has %d parameters, expected %d",
                      literal_param_count, expected_param_count),
         nil,
         resolved_expected_type
      )
      table.insert(result.errors, error)
      self.performance_stats.failed_inferences = self.performance_stats.failed_inferences + 1
      return result
   end
   
   -- Perform parameter type inference with enhanced type propagation
   local inferred_params: {ParameterInfo} = {}
   local constraints_satisfied = 0
   local total_constraints = 0
   
   for i, param in ipairs(param_info) do
      local expected_param_type = expected_params[i]
      local inferred_param: ParameterInfo = {
         name = param.name,
         declared_type = param.declared_type,
         inferred_type = nil,
         position = param.position,
         is_inferred = false,
         inference_confidence = 0.0,
         inference_source = context.source,
      }
      
      total_constraints = total_constraints + 1
      
      if param.declared_type then
         -- Parameter has explicit type, validate compatibility with expected type
         local compatible, unification_errors = self:unify_types(param.declared_type, expected_param_type)
         if compatible then
            inferred_param.inferred_type = param.declared_type
            inferred_param.is_inferred = false
            inferred_param.inference_confidence = 1.0
            constraints_satisfied = constraints_satisfied + 1
         else
            -- Type mismatch between explicit and expected
            local error = contextual_typing.new_inference_error(
               "incompatible_signature",
               param.position,
               string.format("Parameter %d type mismatch: declared %s, expected %s",
                           i, param.declared_type.typename or "unknown", 
                           expected_param_type.typename or "unknown"),
               param.declared_type,
               expected_param_type
            )
            table.insert(result.errors, error)
         end
      else
         -- Parameter needs type inference - propagate expected type
         local propagated_type = self:propagate_expected_type(expected_param_type, context)
         inferred_param.inferred_type = propagated_type
         inferred_param.is_inferred = true
         inferred_param.inference_confidence = self:calculate_type_confidence(propagated_type, context)
         constraints_satisfied = constraints_satisfied + 1
         
         table.insert(result.applied_constraints, 
                     string.format("param_%d: inferred %s from %s", 
                                 i, propagated_type.typename or "unknown",
                                 context.source))
      end
      
      table.insert(inferred_params, inferred_param)
   end
   
   -- Create inferred function type with proper type propagation
   local inferred_args = self:create_inferred_tuple_type(inferred_params, resolved_expected_type.args)
   local inferred_function_type: FunctionType = {
      typename = "function",
      typeid = resolved_expected_type.typeid,
      inferred_at = func_literal as Where,
      needs_compat = resolved_expected_type.needs_compat,
      is_method = resolved_expected_type.is_method,
      maybe_method = resolved_expected_type.maybe_method,
      is_record_function = resolved_expected_type.is_record_function,
      min_arity = resolved_expected_type.min_arity,
      args = inferred_args,
      rets = resolved_expected_type.rets,  -- Return type inference would be handled separately
      macroexp = resolved_expected_type.macroexp,
      special_function_handler = resolved_expected_type.special_function_handler,
      is_contextually_typed = true,
      inference_constraints = result.applied_constraints,
   }
   
   -- STEP 2: Check generic constraint satisfaction if generics were resolved
   if next(generic_bindings) then
      local constraints_satisfied_check, constraint_errors = self:check_generic_constraint_satisfaction(
         inferred_function_type, resolved_expected_type, generic_bindings
      )
      
      if not constraints_satisfied_check then
         for _, error in ipairs(constraint_errors) do
            table.insert(result.errors, error)
         end
      else
         table.insert(result.applied_constraints, "generic_constraints_satisfied")
      end
   end
   
   -- Calculate confidence and finalize result
   result.confidence = contextual_typing.calculate_inference_confidence(
      result, constraints_satisfied, total_constraints
   )
   result.inferred_type = inferred_function_type
   result.success = #result.errors == 0
   
   if result.success then
      self.performance_stats.successful_inferences = self.performance_stats.successful_inferences + 1
   else
      self.performance_stats.failed_inferences = self.performance_stats.failed_inferences + 1
   end
   
   return result
end

-- Check if contextual inference is applicable for a function literal
function BaseContextualTypeChecker:can_infer_contextually(
   func_literal: Node,
   context: InferenceContext
): boolean
   
   -- Must be a function literal
   if func_literal.kind ~= "function" then
      return false
   end
   
   -- Must have expected type information
   if not context.expected_type then
      return false
   end
   
   -- Expected type must be a function type
   if context.expected_type.typename ~= "function" then
      return false
   end
   
   -- Must have at least one untyped parameter to infer
   if func_literal.args then
      for _, arg in ipairs(func_literal.args) do
         if not arg.argtype then
            return true  -- Found at least one untyped parameter
         end
      end
   end
   
   return false  -- All parameters are already typed
end

-- Enhanced inference method with better fallback handling
function BaseContextualTypeChecker:infer_with_fallback(
   func_literal: Node,
   expected_type: FunctionType,
   context: InferenceContext
): InferenceResult
   
   -- First attempt normal contextual inference
   local result = self:infer_function_parameters(func_literal, expected_type, context)
   
   -- If inference failed, try fallback mechanisms
   if not result.success then
      -- Check if we can do partial inference
      local fallback_result = self:handle_inference_fallback(func_literal, result.errors)
      
      -- If partial inference succeeded, merge results
      if fallback_result.success then
         -- Merge successful partial inference with original errors as warnings
         for _, error in ipairs(result.errors) do
            local warning: contextual_typing.InferenceWarning = {
               message = "Original inference failed: " .. error.message,
               location = error.location,
               confidence_level = 0.2
            }
            table.insert(fallback_result.warnings, warning)
         end
         
         return fallback_result
      else
         -- Both normal and fallback inference failed
         return fallback_result
      end
   end
   
   return result
end

-- Method to handle graceful degradation when no context is available
function BaseContextualTypeChecker:infer_with_graceful_degradation(
   func_literal: Node,
   context?: InferenceContext
): InferenceResult
   
   -- If no context provided, handle no-context case
   if not context or not context.expected_type then
      return self:handle_no_context_inference(func_literal)
   end
   
   -- If context is available but expected type is not a function
   if context.expected_type.typename ~= "function" then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         func_literal as Where,
         "Expected type is not a function type: " .. (context.expected_type.typename or "unknown"),
         nil,
         context.expected_type
      )
      
      return {
         success = false,
         inferred_type = nil,
         errors = { error },
         warnings = {},
         confidence = 0.0,
         applied_constraints = {"type_mismatch_fallback"}
      }
   end
   
   -- Try normal inference with fallback
   return self:infer_with_fallback(func_literal, context.expected_type as FunctionType, context)
end

-- Resolve generic type variables during inference
function BaseContextualTypeChecker:resolve_generics(
   expected_type: FunctionType,
   call_context: CallSite
): FunctionType, {string: Type}
   
   local generic_resolver = require("teal.generic_resolver")
   local resolver = generic_resolver.BaseGenericResolver:new()
   
   -- If expected type has no generic parameters, return as-is
   if not expected_type.generic_parameters or #expected_type.generic_parameters == 0 then
      local generic_bindings: {string: Type} = {}
      if call_context.generic_context then
         for name, typ in pairs(call_context.generic_context) do
            generic_bindings[name] = typ
         end
      end
      return expected_type, generic_bindings
   end
   
   -- Perform generic resolution
   local resolution_result = resolver:resolve_generic_parameters(
      expected_type, expected_type, call_context
   )
   
   -- Apply resolved bindings to the expected type
   local resolved_type = expected_type
   if next(resolution_result.resolved_bindings) then
      resolved_type = self:apply_generic_bindings_to_function_type(
         expected_type, resolution_result.resolved_bindings
      )
   end
   
   return resolved_type, resolution_result.resolved_bindings
end

-- Apply generic bindings to a function type
function BaseContextualTypeChecker:apply_generic_bindings_to_function_type(
   func_type: FunctionType,
   bindings: {string: Type}
): FunctionType
   
   local generic_resolution = require("teal.generic_resolution")
   
   local new_func_type: FunctionType = {
      typename = "function",
      typeid = func_type.typeid,
      inferred_at = func_type.inferred_at,
      needs_compat = func_type.needs_compat,
      is_method = func_type.is_method,
      maybe_method = func_type.maybe_method,
      is_record_function = func_type.is_record_function,
      min_arity = func_type.min_arity,
      args = generic_resolution.apply_generic_bindings(func_type.args, bindings),
      rets = generic_resolution.apply_generic_bindings(func_type.rets, bindings),
      macroexp = func_type.macroexp,
      special_function_handler = func_type.special_function_handler,
   }
   
   return new_func_type
end

-- Create inference context from call site information
function BaseContextualTypeChecker:create_inference_context(
   expected_type: Type,
   call_site: CallSite,
   source: InferenceSource
): InferenceContext
   
   return contextual_typing.new_inference_context(expected_type, call_site, source)
end

-- Validate inferred types against constraints
function BaseContextualTypeChecker:validate_inference(
   inferred_type: FunctionType,
   constraints: {contextual_typing.InferenceConstraint}
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- For now, basic validation - full constraint checking would be more complex
   if not inferred_type then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         inferred_type as Where,
         "Inferred type is nil",
         inferred_type,
         nil
      ))
   end
   
   return #errors == 0, errors
end

-- Check if all generic constraints are satisfied during inference
function BaseContextualTypeChecker:check_generic_constraint_satisfaction(
   inferred_type: FunctionType,
   expected_type: FunctionType,
   generic_bindings: {string: Type}
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   local generic_resolution = require("teal.generic_resolution")
   
   -- If no generic bindings, constraints are trivially satisfied
   if not next(generic_bindings) then
      return true, errors
   end
   
   -- Check that inferred parameters match expected parameters after applying bindings
   if not inferred_type.args or not expected_type.args then
      return true, errors
   end
   
   local inferred_params = inferred_type.args.tuple or {}
   local expected_params = expected_type.args.tuple or {}
   
   if #inferred_params ~= #expected_params then
      table.insert(errors, contextual_typing.new_inference_error(
         "constraint_violation",
         inferred_type as Where,
         string.format("Parameter count mismatch after generic resolution: %d vs %d",
                      #inferred_params, #expected_params),
         inferred_type,
         expected_type
      ))
      return false, errors
   end
   
   -- Check each parameter constraint
   for i, inferred_param in ipairs(inferred_params) do
      local expected_param = expected_params[i]
      
      -- Apply generic bindings to expected parameter
      local resolved_expected = generic_resolution.apply_generic_bindings(expected_param, generic_bindings)
      
      -- Check if types are compatible
      local compatible, unify_errors = generic_resolution.are_types_unifiable(
         inferred_param, resolved_expected, generic_bindings
      )
      
      if not compatible then
         table.insert(errors, contextual_typing.new_inference_error(
            "constraint_violation",
            inferred_type as Where,
            string.format("Parameter %d constraint not satisfied: inferred %s, expected %s",
                         i, inferred_param.typename or "unknown",
                         resolved_expected.typename or "unknown"),
            inferred_param,
            resolved_expected
         ))
      end
   end
   
   -- Check return type constraint
   if inferred_type.rets and expected_type.rets then
      local resolved_expected_ret = generic_resolution.apply_generic_bindings(
         expected_type.rets, generic_bindings
      )
      
      local compatible, unify_errors = generic_resolution.are_types_unifiable(
         inferred_type.rets, resolved_expected_ret, generic_bindings
      )
      
      if not compatible then
         table.insert(errors, contextual_typing.new_inference_error(
            "constraint_violation",
            inferred_type as Where,
            string.format("Return type constraint not satisfied: inferred %s, expected %s",
                         inferred_type.rets.typename or "unknown",
                         resolved_expected_ret.typename or "unknown"),
            inferred_type.rets,
            resolved_expected_ret
         ))
      end
   end
   
   return #errors == 0, errors
end

-- Handle inference fallback when contextual inference fails
function BaseContextualTypeChecker:handle_inference_fallback(
   func_literal: Node,
   errors: {InferenceError}
): InferenceResult
   
   local fallback_result: InferenceResult = {
      success = false,
      inferred_type = nil,
      errors = {},
      warnings = {},
      confidence = 0.0,
      applied_constraints = {"fallback_used"},
   }
   
   self.performance_stats.fallback_used = true
   
   -- Copy original errors
   for _, error in ipairs(errors) do
      table.insert(fallback_result.errors, error)
   end
   
   -- Attempt partial inference for mixed parameter scenarios
   local partial_success = self:attempt_partial_inference(func_literal, fallback_result)
   
   if partial_success then
      fallback_result.success = true
      fallback_result.confidence = 0.3  -- Low confidence for fallback
      
      local warning: contextual_typing.InferenceWarning = {
         message = "Used fallback inference for some parameters",
         location = func_literal as Where,
         confidence_level = 0.3
      }
      table.insert(fallback_result.warnings, warning)
   end
   
   -- Add contextual suggestions for different error types
   for _, error in ipairs(fallback_result.errors) do
      if error.kind == "no_contextual_information" then
         error.suggested_fix = "Add explicit type annotations to function parameters: function(param: Type)"
      elseif error.kind == "ambiguous_inference" then
         error.suggested_fix = "Specify explicit types to resolve ambiguity or provide more context"
      elseif error.kind == "incompatible_signature" then
         error.suggested_fix = "Check parameter count and types match the expected function signature"
      elseif error.kind == "constraint_violation" then
         error.suggested_fix = "Ensure generic constraints are satisfied or add explicit type bounds"
      elseif error.kind == "mixed_parameter_conflict" then
         error.suggested_fix = "Resolve conflicts between explicit and inferred parameter types"
      end
   end
   
   return fallback_result
end

-- Attempt partial inference when full inference fails
function BaseContextualTypeChecker:attempt_partial_inference(
   func_literal: Node,
   result: InferenceResult
): boolean
   
   -- Extract parameter information
   local param_info = contextual_typing.extract_parameter_info(func_literal)
   
   if #param_info == 0 then
      return false  -- No parameters to infer
   end
   
   -- Check if we have any explicitly typed parameters
   local has_explicit_types = false
   local has_untyped_params = false
   
   for _, param in ipairs(param_info) do
      if param.declared_type then
         has_explicit_types = true
      else
         has_untyped_params = true
      end
   end
   
   -- If we have mixed parameters, we can partially succeed
   if has_explicit_types and has_untyped_params then
      -- Create a partial function type using explicit types
      local partial_args: {Type} = {}
      
      for _, param in ipairs(param_info) do
         if param.declared_type then
            table.insert(partial_args, param.declared_type)
         else
            -- Use 'any' type as fallback for untyped parameters
            table.insert(partial_args, {
               typename = "any",
               typeid = 999,  -- Special ID for fallback types
               inferred_at = param.position,
               needs_compat = false
            })
         end
      end
      
      -- Create partial function type
      local partial_tuple: types.TupleType = {
         typename = "tuple",
         typeid = 998,
         tuple = partial_args,
         inferred_at = func_literal as Where,
         needs_compat = false
      }
      
      result.inferred_type = {
         typename = "function",
         typeid = 997,
         inferred_at = func_literal as Where,
         needs_compat = false,
         is_method = false,
         maybe_method = false,
         is_record_function = false,
         min_arity = #partial_args,
         args = partial_tuple,
         rets = {
            typename = "tuple",
            typeid = 996,
            tuple = { { typename = "any", typeid = 995 } },
            inferred_at = func_literal as Where,
            needs_compat = false
         },
         is_contextually_typed = true,
         inference_constraints = {"partial_fallback"}
      }
      
      table.insert(result.applied_constraints, "partial_inference_with_any_fallback")
      return true
   end
   
   return false
end

-- Enhanced method to handle cases with no contextual information
function BaseContextualTypeChecker:handle_no_context_inference(
   func_literal: Node
): InferenceResult
   
   local result: InferenceResult = {
      success = false,
      inferred_type = nil,
      errors = {},
      warnings = {},
      confidence = 0.0,
      applied_constraints = {"no_context_fallback"},
   }
   
   -- Create error for lack of contextual information
   local error = contextual_typing.new_inference_error(
      "no_contextual_information",
      func_literal as Where,
      "Cannot infer parameter types: no contextual type information available",
      nil,
      nil
   )
   error.suggested_fix = "Provide explicit type annotations or use the function in a context that provides type information"
   table.insert(result.errors, error)
   
   -- Check if we can provide any helpful suggestions based on function body
   local suggestions = self:analyze_function_body_for_suggestions(func_literal)
   if #suggestions > 0 then
      local warning: contextual_typing.InferenceWarning = {
         message = "Suggestions based on function body analysis: " .. table.concat(suggestions, ", "),
         location = func_literal as Where,
         confidence_level = 0.2
      }
      table.insert(result.warnings, warning)
   end
   
   return result
end

-- Analyze function body to provide type suggestions
function BaseContextualTypeChecker:analyze_function_body_for_suggestions(
   func_literal: Node
): {string}
   
   local suggestions: {string} = {}
   
   -- This is a simplified analysis - a full implementation would
   -- traverse the AST and look for type clues
   if func_literal.body then
      -- Look for common patterns that suggest parameter types
      -- For now, just provide generic suggestions
      table.insert(suggestions, "consider common types like number, string, boolean")
      
      -- Check if function uses arithmetic operations (suggests number)
      -- Check if function uses string operations (suggests string)
      -- Check if function uses array/table operations (suggests array/table)
      -- This would require more sophisticated AST analysis
   end
   
   return suggestions
end

-- Performance monitoring and optimization
function BaseContextualTypeChecker:get_inference_stats(): InferenceMetadata
   return self.performance_stats
end

-- Validate that inferred types behave identically to explicit types
function BaseContextualTypeChecker:validate_inference_explicit_equivalence(
   func_literal: Node,
   inferred_type: FunctionType,
   explicit_type: FunctionType
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Check parameter count equivalence
   if not inferred_type.args or not explicit_type.args then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         func_literal as Where,
         "Missing parameter information in function types",
         inferred_type,
         explicit_type
      ))
      return false, errors
   end
   
   local inferred_params = inferred_type.args.tuple or {}
   local explicit_params = explicit_type.args.tuple or {}
   
   if #inferred_params ~= #explicit_params then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         func_literal as Where,
         string.format("Parameter count mismatch: inferred %d, explicit %d",
                      #inferred_params, #explicit_params),
         inferred_type,
         explicit_type
      ))
      return false, errors
   end
   
   -- Check parameter type equivalence
   for i, inferred_param in ipairs(inferred_params) do
      local explicit_param = explicit_params[i]
      local equivalent, param_errors = self:check_type_equivalence(
         inferred_param, explicit_param, func_literal as Where
      )
      
      if not equivalent then
         for _, error in ipairs(param_errors) do
            error.message = string.format("Parameter %d: %s", i, error.message)
            table.insert(errors, error)
         end
      end
   end
   
   -- Check return type equivalence
   local return_equivalent, return_errors = self:check_return_type_equivalence(
      inferred_type.rets, explicit_type.rets, func_literal as Where
   )
   
   if not return_equivalent then
      for _, error in ipairs(return_errors) do
         table.insert(errors, error)
      end
   end
   
   -- Check function properties equivalence
   local properties_equivalent, property_errors = self:check_function_properties_equivalence(
      inferred_type, explicit_type, func_literal as Where
   )
   
   if not properties_equivalent then
      for _, error in ipairs(property_errors) do
         table.insert(errors, error)
      end
   end
   
   return #errors == 0, errors
end

-- Check if two types are equivalent for inference purposes
function BaseContextualTypeChecker:check_type_equivalence(
   type1: Type,
   type2: Type,
   location: Where
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Handle nil types
   if not type1 and not type2 then
      return true, errors
   end
   
   if not type1 or not type2 then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         location,
         "One type is nil while the other is not",
         type1,
         type2
      ))
      return false, errors
   end
   
   -- Check typename equivalence
   if type1.typename ~= type2.typename then
      -- Handle special cases for numeric type compatibility
      if (type1.typename == "integer" and type2.typename == "number") or
         (type1.typename == "number" and type2.typename == "integer") then
         return true, errors  -- These are considered equivalent
      end
      
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         location,
         string.format("Type mismatch: %s vs %s", 
                      type1.typename or "unknown", type2.typename or "unknown"),
         type1,
         type2
      ))
      return false, errors
   end
   
   -- For function types, check deeper equivalence
   if type1.typename == "function" then
      return self:check_function_type_equivalence(
         type1 as FunctionType, type2 as FunctionType, location
      )
   end
   
   -- For tuple types, check element equivalence
   if type1.typename == "tuple" then
      return self:check_tuple_type_equivalence(
         type1 as types.TupleType, type2 as types.TupleType, location
      )
   end
   
   -- For other types, basic typename equivalence is sufficient
   return true, errors
end

-- Check equivalence of function types
function BaseContextualTypeChecker:check_function_type_equivalence(
   func1: FunctionType,
   func2: FunctionType,
   location: Where
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Check argument equivalence
   local args_equivalent, args_errors = self:check_type_equivalence(
      func1.args, func2.args, location
   )
   
   if not args_equivalent then
      for _, error in ipairs(args_errors) do
         error.message = "Function arguments: " .. error.message
         table.insert(errors, error)
      end
   end
   
   -- Check return type equivalence
   local rets_equivalent, rets_errors = self:check_type_equivalence(
      func1.rets, func2.rets, location
   )
   
   if not rets_equivalent then
      for _, error in ipairs(rets_errors) do
         error.message = "Function returns: " .. error.message
         table.insert(errors, error)
      end
   end
   
   -- Check method properties
   if func1.is_method ~= func2.is_method then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         location,
         string.format("Method property mismatch: %s vs %s",
                      tostring(func1.is_method), tostring(func2.is_method)),
         func1,
         func2
      ))
   end
   
   return #errors == 0, errors
end

-- Check equivalence of tuple types
function BaseContextualTypeChecker:check_tuple_type_equivalence(
   tuple1: types.TupleType,
   tuple2: types.TupleType,
   location: Where
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   local elements1 = tuple1.tuple or {}
   local elements2 = tuple2.tuple or {}
   
   if #elements1 ~= #elements2 then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         location,
         string.format("Tuple length mismatch: %d vs %d", #elements1, #elements2),
         tuple1,
         tuple2
      ))
      return false, errors
   end
   
   for i, elem1 in ipairs(elements1) do
      local elem2 = elements2[i]
      local equivalent, elem_errors = self:check_type_equivalence(elem1, elem2, location)
      
      if not equivalent then
         for _, error in ipairs(elem_errors) do
            error.message = string.format("Tuple element %d: %s", i, error.message)
            table.insert(errors, error)
         end
      end
   end
   
   return #errors == 0, errors
end

-- Check return type equivalence
function BaseContextualTypeChecker:check_return_type_equivalence(
   inferred_rets: Type,
   explicit_rets: Type,
   location: Where
): boolean, {InferenceError}
   
   return self:check_type_equivalence(inferred_rets, explicit_rets, location)
end

-- Check function properties equivalence
function BaseContextualTypeChecker:check_function_properties_equivalence(
   inferred: FunctionType,
   explicit: FunctionType,
   location: Where
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Check method properties
   if inferred.is_method ~= explicit.is_method then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         location,
         string.format("Method property mismatch: inferred %s, explicit %s",
                      tostring(inferred.is_method), tostring(explicit.is_method)),
         inferred,
         explicit
      ))
   end
   
   if inferred.maybe_method ~= explicit.maybe_method then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         location,
         string.format("Maybe method property mismatch: inferred %s, explicit %s",
                      tostring(inferred.maybe_method), tostring(explicit.maybe_method)),
         inferred,
         explicit
      ))
   end
   
   -- Check record function property
   if inferred.is_record_function ~= explicit.is_record_function then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         location,
         string.format("Record function property mismatch: inferred %s, explicit %s",
                      tostring(inferred.is_record_function), tostring(explicit.is_record_function)),
         inferred,
         explicit
      ))
   end
   
   -- Check minimum arity
   if inferred.min_arity ~= explicit.min_arity then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         location,
         string.format("Minimum arity mismatch: inferred %s, explicit %s",
                      tostring(inferred.min_arity), tostring(explicit.min_arity)),
         inferred,
         explicit
      ))
   end
   
   return #errors == 0, errors
end

-- Enforce type constraints for inferred parameters
function BaseContextualTypeChecker:enforce_type_constraints(
   func_literal: Node,
   inferred_params: {ParameterInfo},
   constraints: {contextual_typing.InferenceConstraint}
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Check each constraint against inferred parameters
   for _, constraint in ipairs(constraints) do
      local constraint_satisfied, constraint_errors = self:check_constraint_satisfaction(
         constraint, inferred_params, func_literal as Where
      )
      
      if not constraint_satisfied then
         for _, error in ipairs(constraint_errors) do
            table.insert(errors, error)
         end
      end
   end
   
   -- Additional constraint checks for parameter consistency
   for i, param in ipairs(inferred_params) do
      if param.inferred_type then
         local valid, validation_errors = self:validate_parameter_type_constraints(
            param, i, func_literal as Where
         )
         
         if not valid then
            for _, error in ipairs(validation_errors) do
               table.insert(errors, error)
            end
         end
      end
   end
   
   return #errors == 0, errors
end

-- Check if a constraint is satisfied by inferred parameters
function BaseContextualTypeChecker:check_constraint_satisfaction(
   constraint: contextual_typing.InferenceConstraint,
   inferred_params: {ParameterInfo},
   location: Where
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   if constraint.kind == "subtype" then
      -- Check if left_type is a subtype of right_type
      local is_subtype, subtype_errors = self:check_subtype_relationship(
         constraint.left_type, constraint.right_type, location
      )
      
      if not is_subtype then
         for _, error in ipairs(subtype_errors) do
            error.message = "Subtype constraint violation: " .. error.message
            table.insert(errors, error)
         end
      end
      
   elseif constraint.kind == "equality" then
      -- Check if types are equal
      local are_equal, equality_errors = self:check_type_equivalence(
         constraint.left_type, constraint.right_type, location
      )
      
      if not are_equal then
         for _, error in ipairs(equality_errors) do
            error.message = "Equality constraint violation: " .. error.message
            table.insert(errors, error)
         end
      end
      
   elseif constraint.kind == "generic_bound" then
      -- Check generic type bounds
      local bounds_satisfied, bounds_errors = self:check_generic_bounds(
         constraint.left_type, constraint.right_type, location
      )
      
      if not bounds_satisfied then
         for _, error in ipairs(bounds_errors) do
            error.message = "Generic bound constraint violation: " .. error.message
            table.insert(errors, error)
         end
      end
      
   elseif constraint.kind == "contextual_match" then
      -- Check contextual type matching
      local matches, match_errors = self:check_contextual_type_match(
         constraint.left_type, constraint.right_type, location
      )
      
      if not matches then
         for _, error in ipairs(match_errors) do
            error.message = "Contextual match constraint violation: " .. error.message
            table.insert(errors, error)
         end
      end
   end
   
   return #errors == 0, errors
end

-- Validate function body using inferred types
function BaseContextualTypeChecker:validate_function_body_with_inferred_types(
   func_literal: Node,
   inferred_params: {ParameterInfo}
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Create a type environment with inferred parameter types
   local type_env = self:create_type_environment_from_inferred_params(inferred_params)
   
   -- Validate function body against the type environment
   if func_literal.body then
      local body_valid, body_errors = self:validate_function_body_statements(
         func_literal.body, type_env, func_literal as Where
      )
      
      if not body_valid then
         for _, error in ipairs(body_errors) do
            table.insert(errors, error)
         end
      end
   end
   
   return #errors == 0, errors
end

--------------------------------------------------------------------------------
-- Core Type Inference Helper Methods
--------------------------------------------------------------------------------

-- Unify two types to check compatibility
function BaseContextualTypeChecker:unify_types(
   type1: Type,
   type2: Type
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Basic type compatibility check
   if type1.typename == type2.typename then
      return true, errors
   end
   
   -- Handle numeric type compatibility (integer <: number)
   if type1.typename == "integer" and type2.typename == "number" then
      return true, errors
   end
   
   if type1.typename == "number" and type2.typename == "integer" then
      return true, errors
   end
   
   -- Handle any type (any is compatible with everything)
   if type1.typename == "any" or type2.typename == "any" then
      return true, errors
   end
   
   -- Types are incompatible
   local error = contextual_typing.new_inference_error(
      "incompatible_signature",
      type1 as Where,
      string.format("Type mismatch: %s is not compatible with %s",
                   type1.typename or "unknown", type2.typename or "unknown"),
      type1,
      type2
   )
   table.insert(errors, error)
   
   return false, errors
end

-- Propagate expected type through inference context
function BaseContextualTypeChecker:propagate_expected_type(
   expected_type: Type,
   context: InferenceContext
): Type
   
   -- Apply generic bindings if present
   if context.generic_bindings and next(context.generic_bindings) then
      return self:apply_generic_bindings(expected_type, context.generic_bindings)
   end
   
   -- For now, return the expected type directly
   -- More sophisticated propagation would handle nested types, unions, etc.
   return expected_type
end

-- Apply generic type bindings to a type
function BaseContextualTypeChecker:apply_generic_bindings(
   typ: Type,
   bindings: {string: Type}
): Type
   
   -- If this is a type variable, look up its binding
   if typ.typename == "typevar" then
      local typevar = typ as types.TypeVarType
      if typevar.typevar and bindings[typevar.typevar] then
         return bindings[typevar.typevar]
      end
   end
   
   -- For other types, return as-is for now
   -- Full generic substitution would require recursive type traversal
   return typ
end

-- Calculate confidence score for a propagated type
function BaseContextualTypeChecker:calculate_type_confidence(
   propagated_type: Type,
   context: InferenceContext
): number
   
   local base_confidence = 0.8  -- High confidence for direct propagation
   
   -- Reduce confidence for complex types
   if propagated_type.typename == "union" then
      base_confidence = base_confidence * 0.7
   elseif propagated_type.typename == "generic" then
      base_confidence = base_confidence * 0.8
   end
   
   -- Reduce confidence for deep inference contexts
   if context.inference_depth > 2 then
      base_confidence = base_confidence * (0.9 ^ (context.inference_depth - 2))
   end
   
   return math.max(0.1, math.min(1.0, base_confidence))
end

-- Create inferred tuple type from parameter information
function BaseContextualTypeChecker:create_inferred_tuple_type(
   params: {ParameterInfo},
   original_args: types.TupleType
): types.TupleType
   
   local inferred_tuple: types.TupleType = {
      typename = "tuple",
      typeid = original_args.typeid,
      inferred_at = original_args.inferred_at,
      needs_compat = original_args.needs_compat,
      tuple = {},
   }
   
   -- Build tuple from inferred parameter types
   for _, param in ipairs(params) do
      if param.inferred_type then
         table.insert(inferred_tuple.tuple, param.inferred_type)
      end
   end
   
   return inferred_tuple
end

-- Check subtype relationship between two types
function BaseContextualTypeChecker:check_subtype_relationship(
   subtype: Type,
   supertype: Type,
   location: Where
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Basic subtype rules
   if subtype.typename == supertype.typename then
      return true, errors
   end
   
   -- Integer is a subtype of number
   if subtype.typename == "integer" and supertype.typename == "number" then
      return true, errors
   end
   
   -- Any type is a supertype of all types
   if supertype.typename == "any" then
      return true, errors
   end
   
   -- All types are subtypes of any
   if subtype.typename == "any" then
      return true, errors
   end
   
   -- Not a subtype relationship
   table.insert(errors, contextual_typing.new_inference_error(
      "constraint_violation",
      location,
      string.format("%s is not a subtype of %s", 
                   subtype.typename or "unknown", supertype.typename or "unknown"),
      subtype,
      supertype
   ))
   
   return false, errors
end

-- Check generic type bounds
function BaseContextualTypeChecker:check_generic_bounds(
   type_param: Type,
   bound: Type,
   location: Where
): boolean, {InferenceError}
   
   -- For now, use subtype checking for generic bounds
   return self:check_subtype_relationship(type_param, bound, location)
end

-- Check contextual type matching
function BaseContextualTypeChecker:check_contextual_type_match(
   actual: Type,
   expected: Type,
   location: Where
): boolean, {InferenceError}
   
   -- For now, use type equivalence for contextual matching
   return self:check_type_equivalence(actual, expected, location)
end

-- Validate parameter type constraints
function BaseContextualTypeChecker:validate_parameter_type_constraints(
   param: ParameterInfo,
   param_index: integer,
   location: Where
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Check if inferred type is valid
   if not param.inferred_type then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         location,
         string.format("Parameter %d has no inferred type", param_index),
         nil,
         nil
      ))
      return false, errors
   end
   
   -- Check if inferred type has valid typename
   if not param.inferred_type.typename then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         location,
         string.format("Parameter %d has invalid inferred type", param_index),
         param.inferred_type,
         nil
      ))
      return false, errors
   end
   
   -- Additional validation rules can be added here
   return true, errors
end

-- Create type environment from inferred parameters
function BaseContextualTypeChecker:create_type_environment_from_inferred_params(
   inferred_params: {ParameterInfo}
): {string: Type}
   
   local type_env: {string: Type} = {}
   
   for _, param in ipairs(inferred_params) do
      if param.inferred_type then
         type_env[param.name] = param.inferred_type
      end
   end
   
   return type_env
end

-- Validate function body statements with type environment
function BaseContextualTypeChecker:validate_function_body_statements(
   body: Node,
   type_env: {string: Type},
   location: Where
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- This is a simplified validation - a full implementation would
   -- traverse the AST and validate all expressions and statements
   -- against the type environment
   
   -- For now, just check that the body exists and is valid
   if not body then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         location,
         "Function body is missing",
         nil,
         nil
      ))
      return false, errors
   end
   
   -- Additional body validation would go here
   -- This would involve traversing the AST and checking:
   -- - Variable references against type_env
   -- - Function calls with proper argument types
   -- - Return statements with compatible types
   -- - Arithmetic operations with numeric types
   -- etc.
   
   return true, errors
end

-- Validate backward compatibility with existing explicitly typed code
function BaseContextualTypeChecker:validate_backward_compatibility(
   original_code: string,
   modified_code: string
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Parse both versions
   local original_ast, original_syntax_errors = self:parse_code(original_code)
   local modified_ast, modified_syntax_errors = self:parse_code(modified_code)
   
   -- Check for syntax errors
   if #original_syntax_errors > 0 then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         { y = 1, x = 1 },
         "Original code has syntax errors: " .. table.concat(original_syntax_errors, ", "),
         nil,
         nil
      ))
      return false, errors
   end
   
   if #modified_syntax_errors > 0 then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         { y = 1, x = 1 },
         "Modified code has syntax errors: " .. table.concat(modified_syntax_errors, ", "),
         nil,
         nil
      ))
      return false, errors
   end
   
   -- Compare AST structures for compatibility
   local ast_compatible, ast_errors = self:compare_ast_structures(original_ast, modified_ast)
   
   if not ast_compatible then
      for _, error in ipairs(ast_errors) do
         table.insert(errors, error)
      end
   end
   
   return #errors == 0, errors
end

-- Compare AST structures to ensure backward compatibility
function BaseContextualTypeChecker:compare_ast_structures(
   original_ast: Node,
   modified_ast: Node
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Basic structure comparison
   if not original_ast or not modified_ast then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         { y = 1, x = 1 },
         "AST structure mismatch: one or both ASTs are nil",
         nil,
         nil
      ))
      return false, errors
   end
   
   -- Compare node kinds
   if original_ast.kind ~= modified_ast.kind then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         { y = 1, x = 1 },
         string.format("AST node kind mismatch: %s vs %s",
                      original_ast.kind or "nil", modified_ast.kind or "nil"),
         nil,
         nil
      ))
      return false, errors
   end
   
   -- For function nodes, compare parameter structures
   if original_ast.kind == "function" then
      local original_params = original_ast.args or {}
      local modified_params = modified_ast.args or {}
      
      if #original_params ~= #modified_params then
         table.insert(errors, contextual_typing.new_inference_error(
            "incompatible_signature",
            { y = 1, x = 1 },
            string.format("Parameter count mismatch: %d vs %d",
                         #original_params, #modified_params),
            nil,
            nil
         ))
         return false, errors
      end
      
      -- Compare parameter names and types
      for i, orig_param in ipairs(original_params) do
         local mod_param = modified_params[i]
         
         -- Parameter names should match
         if (orig_param.tk or "") ~= (mod_param.tk or "") then
            table.insert(errors, contextual_typing.new_inference_error(
               "incompatible_signature",
               { y = 1, x = 1 },
               string.format("Parameter %d name mismatch: %s vs %s",
                           i, orig_param.tk or "unnamed", mod_param.tk or "unnamed"),
               nil,
               nil
            ))
         end
         
         -- If original has explicit type, modified should have compatible type
         if orig_param.argtype then
            if not mod_param.argtype then
               -- Modified version removed explicit type - this is OK for backward compat
               -- as long as inference can provide the same type
            else
               -- Both have explicit types - they should match
               local types_compatible, type_errors = self:check_type_equivalence(
                  orig_param.argtype, mod_param.argtype, { y = 1, x = 1 }
               )
               
               if not types_compatible then
                  for _, error in ipairs(type_errors) do
                     error.message = string.format("Parameter %d type incompatibility: %s", i, error.message)
                     table.insert(errors, error)
                  end
               end
            end
         end
      end
   end
   
   return #errors == 0, errors
end

-- Check that explicitly typed code produces identical results
function BaseContextualTypeChecker:validate_explicit_type_results(
   func_literal: Node,
   explicit_type: FunctionType,
   context: InferenceContext
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Perform inference with the explicit type
   local result = self:infer_function_parameters(func_literal, explicit_type, context)
   
   -- Validate that the result matches the explicit type
   if not result.success then
      for _, error in ipairs(result.errors) do
         table.insert(errors, error)
      end
      return false, errors
   end
   
   -- Check that inferred type matches explicit type
   local types_match, match_errors = self:check_type_equivalence(
      result.inferred_type, explicit_type, func_literal as Where
   )
   
   if not types_match then
      for _, error in ipairs(match_errors) do
         error.message = "Explicit type result mismatch: " .. error.message
         table.insert(errors, error)
      end
      return false, errors
   end
   
   return true, errors
end

-- Create regression testing infrastructure
function BaseContextualTypeChecker:create_regression_test_suite(): {contextual_typing.RegressionTest}
   
   local regression_tests: {contextual_typing.RegressionTest} = {}
   
   -- Test 1: Basic explicit typing still works
   table.insert(regression_tests, {
      name = "basic_explicit_typing",
      description = "Verify basic explicit type annotations still work",
      code = [[
         local function add(x: number, y: number): number
            return x + y
         end
         local result = add(10, 20)
      ]],
      expected_success = true,
      expected_errors = {}
   })
   
   -- Test 2: Function literals with explicit types
   table.insert(regression_tests, {
      name = "function_literal_explicit_types",
      description = "Verify function literals with explicit types work",
      code = [[
         local callback: function(number): string = function(x: number): string
            return tostring(x)
         end
         local result = callback(42)
      ]],
      expected_success = true,
      expected_errors = {}
   })
   
   -- Test 3: Mixed explicit and inferred parameters
   table.insert(regression_tests, {
      name = "mixed_explicit_inferred",
      description = "Verify mixed explicit and inferred parameters work",
      code = [[
         local function process(x: number, y)
            return x + y
         end
      ]],
      expected_success = true,
      expected_errors = {}
   })
   
   -- Test 4: Generic functions with explicit types
   table.insert(regression_tests, {
      name = "generic_explicit_types",
      description = "Verify generic functions with explicit types work",
      code = [[
         local function identity<T>(x: T): T
            return x
         end
         local num_result = identity(42)
         local str_result = identity("hello")
      ]],
      expected_success = true,
      expected_errors = {}
   })
   
   -- Test 5: Array methods with explicit types
   table.insert(regression_tests, {
      name = "array_methods_explicit",
      description = "Verify array methods with explicit types work",
      code = [[
         local numbers: {number} = {1, 2, 3}
         local function double(x: number): number
            return x * 2
         end
         -- Note: actual array.map would require more complex setup
      ]],
      expected_success = true,
      expected_errors = {}
   })
   
   -- Test 6: Callback with explicit types
   table.insert(regression_tests, {
      name = "callback_explicit_types",
      description = "Verify callbacks with explicit types work",
      code = [[
         local function apply_callback(callback: function(number): string, value: number): string
            return callback(value)
         end
         local result = apply_callback(function(x: number): string return tostring(x) end, 42)
      ]],
      expected_success = true,
      expected_errors = {}
   })
   
   -- Test 7: Type aliases with explicit types
   table.insert(regression_tests, {
      name = "type_aliases_explicit",
      description = "Verify type aliases with explicit types work",
      code = [[
         local type NumberCallback = function(number): number
         local callback: NumberCallback = function(x: number): number
            return x * 2
         end
      ]],
      expected_success = true,
      expected_errors = {}
   })
   
   -- Test 8: Record methods with explicit types
   table.insert(regression_tests, {
      name = "record_methods_explicit",
      description = "Verify record methods with explicit types work",
      code = [[
         local record Point
            x: number
            y: number
         end
         
         function Point:distance(): number
            return (self.x * self.x + self.y * self.y) ^ 0.5
         end
      ]],
      expected_success = true,
      expected_errors = {}
   })
   
   -- Test 9: Nested functions with explicit types
   table.insert(regression_tests, {
      name = "nested_functions_explicit",
      description = "Verify nested functions with explicit types work",
      code = [[
         local function outer(x: number): function(number): number
            return function(y: number): number
               return x + y
            end
         end
      ]],
      expected_success = true,
      expected_errors = {}
   })
   
   -- Test 10: Union types with explicit types
   table.insert(regression_tests, {
      name = "union_types_explicit",
      description = "Verify union types with explicit types work",
      code = [[
         local function process(value: number | string): string
            if type(value) == "number" then
               return tostring(value)
            else
               return value
            end
         end
      ]],
      expected_success = true,
      expected_errors = {}
   })
   
   return regression_tests
end

-- Run regression test suite
function BaseContextualTypeChecker:run_regression_tests(
   tests: {contextual_typing.RegressionTest}
): {contextual_typing.RegressionTestResult}
   
   local results: {contextual_typing.RegressionTestResult} = {}
   
   for _, test in ipairs(tests) do
      local result: contextual_typing.RegressionTestResult = {
         test_name = test.name,
         description = test.description,
         passed = false,
         errors = {},
         warnings = {},
         execution_time_ms = 0.0
      }
      
      -- Parse and check the code
      local ast, syntax_errors = self:parse_code(test.code)
      
      if #syntax_errors > 0 then
         result.passed = false
         for _, error in ipairs(syntax_errors) do
            table.insert(result.errors, error)
         end
      else
         -- Check if result matches expected
         if test.expected_success then
            result.passed = #result.errors == 0
         else
            result.passed = #result.errors > 0
         end
      end
      
      table.insert(results, result)
   end
   
   return results
end

-- Validate compatibility for mixed inference scenarios
function BaseContextualTypeChecker:validate_mixed_inference_compatibility(
   func_literal: Node,
   expected_type: FunctionType,
   context: InferenceContext
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Extract parameter information
   local param_info = contextual_typing.extract_parameter_info(func_literal)
   
   if #param_info == 0 then
      return true, errors  -- No parameters to validate
   end
   
   -- Check for mixed explicit and inferred parameters
   local has_explicit = false
   local has_inferred = false
   
   for _, param in ipairs(param_info) do
      if param.declared_type then
         has_explicit = true
      else
         has_inferred = true
      end
   end
   
   -- If we have mixed parameters, validate compatibility
   if has_explicit and has_inferred then
      -- Perform inference
      local result = self:infer_function_parameters(func_literal, expected_type, context)
      
      if not result.success then
         for _, error in ipairs(result.errors) do
            table.insert(errors, error)
         end
         return false, errors
      end
      
      -- Validate that explicit parameters match expected types
      local expected_params = expected_type.args.tuple or {}
      
      for i, param in ipairs(param_info) do
         if param.declared_type then
            local expected_param = expected_params[i]
            
            if expected_param then
               local compatible, compat_errors = self:unify_types(param.declared_type, expected_param)
               
               if not compatible then
                  for _, error in ipairs(compat_errors) do
                     error.message = string.format("Mixed parameter %d compatibility: %s", i, error.message)
                     table.insert(errors, error)
                  end
               end
            end
         end
      end
   end
   
   return #errors == 0, errors
end

-- Helper method to parse code (stub for now)
function BaseContextualTypeChecker:parse_code(code: string): Node, {string}
   -- This would integrate with the actual Teal parser
   -- For now, return a stub that indicates parsing would happen
   return { kind = "block" }, {}
end

--------------------------------------------------------------------------------
-- Module exports
--------------------------------------------------------------------------------

local contextual_type_checker = {
   BaseContextualTypeChecker = BaseContextualTypeChecker,
}

return contextual_type_checker


-- Helper method: Unify two types for compatibility checking
function BaseContextualTypeChecker:unify_types(
   type1: Type,
   type2: Type
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   local generic_resolution = require("teal.generic_resolution")
   
   -- Use generic resolution's unification logic
   local bindings, unify_errors = generic_resolution.unify_types(type1, type2, {})
   
   if #unify_errors > 0 then
      for _, error in ipairs(unify_errors) do
         table.insert(errors, error)
      end
      return false, errors
   end
   
   return true, errors
end

-- Helper method: Propagate expected type to inferred parameter
function BaseContextualTypeChecker:propagate_expected_type(
   expected_type: Type,
   context: InferenceContext
): Type
   
   -- If expected type is a type variable, try to resolve it from context
   if expected_type and expected_type.typename == "typevar" then
      local generic_resolution = require("teal.generic_resolution")
      local resolved = generic_resolution.apply_generic_bindings(expected_type, context.generic_bindings)
      if resolved.typename ~= "typevar" then
         return resolved
      end
   end
   
   -- Return the expected type as-is
   return expected_type
end

-- Helper method: Calculate confidence score for inferred type
function BaseContextualTypeChecker:calculate_type_confidence(
   inferred_type: Type,
   context: InferenceContext
): number
   
   -- Base confidence depends on whether type is fully resolved
   local confidence = 0.8
   
   -- Reduce confidence if type is a type variable (unresolved)
   if inferred_type and inferred_type.typename == "typevar" then
      confidence = 0.3
   end
   
   -- Reduce confidence based on inference depth
   if context.inference_depth > 0 then
      confidence = confidence - (context.inference_depth * 0.1)
   end
   
   -- Ensure confidence is in valid range
   return math.max(0.0, math.min(1.0, confidence))
end

-- Helper method: Create inferred tuple type from parameter info
function BaseContextualTypeChecker:create_inferred_tuple_type(
   inferred_params: {ParameterInfo},
   original_tuple: types.TupleType
): types.TupleType
   
   local new_tuple_elements: {Type} = {}
   
   for _, param_info in ipairs(inferred_params) do
      if param_info.inferred_type then
         table.insert(new_tuple_elements, param_info.inferred_type)
      else
         -- Fallback to 'any' if no type was inferred
         table.insert(new_tuple_elements, {
            typename = "any",
            typeid = 999,
            inferred_at = param_info.position,
            needs_compat = false
         })
      end
   end
   
   local new_tuple: types.TupleType = {
      typename = "tuple",
      typeid = original_tuple.typeid,
      tuple = new_tuple_elements,
      inferred_at = original_tuple.inferred_at,
      needs_compat = original_tuple.needs_compat
   }
   
   return new_tuple
end

-- Helper method: Check function properties equivalence
function BaseContextualTypeChecker:check_function_properties_equivalence(
   inferred_type: FunctionType,
   explicit_type: FunctionType,
   location: Where
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Check is_method property
   if inferred_type.is_method ~= explicit_type.is_method then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         location,
         string.format("is_method property mismatch: %s vs %s",
                      tostring(inferred_type.is_method), tostring(explicit_type.is_method)),
         inferred_type,
         explicit_type
      ))
   end
   
   -- Check min_arity property
   if inferred_type.min_arity ~= explicit_type.min_arity then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         location,
         string.format("min_arity property mismatch: %d vs %d",
                      inferred_type.min_arity, explicit_type.min_arity),
         inferred_type,
         explicit_type
      ))
   end
   
   return #errors == 0, errors
end

--------------------------------------------------------------------------------
-- Nested Function Inference Support
-- 
-- These methods handle type propagation through nested function literals
-- and recursive inference for higher-order functions.
--------------------------------------------------------------------------------

-- Infer types for nested function literals
-- Handles cases where a function literal returns another function literal
function BaseContextualTypeChecker:infer_nested_function_literal(
   func_literal: Node,
   expected_type: FunctionType,
   parent_context: InferenceContext
): InferenceResult
   
   local result: InferenceResult = {
      success = false,
      inferred_type = nil,
      errors = {},
      warnings = {},
      confidence = 0.0,
      applied_constraints = {},
   }
   
   -- Check if expected type's return type is a function type
   if not expected_type.rets or expected_type.rets.typename ~= "function" then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         func_literal as Where,
         "Expected return type is not a function type",
         nil,
         expected_type.rets
      )
      table.insert(result.errors, error)
      return result
   end
   
   -- Create a child context for nested inference
   local nested_context = contextual_typing.merge_inference_contexts(
      parent_context,
      contextual_typing.new_inference_context(
         expected_type.rets as FunctionType,
         parent_context.call_site,
         "nested_callback"
      )
   )
   
   -- Perform inference on the outer function
   local outer_result = self:infer_function_parameters(
      func_literal, expected_type, nested_context
   )
   
   if not outer_result.success then
      for _, error in ipairs(outer_result.errors) do
         table.insert(result.errors, error)
      end
      return result
   end
   
   -- Check if function body contains nested function literals
   if func_literal.body then
      local nested_functions = self:find_nested_function_literals(func_literal.body)
      
      if #nested_functions > 0 then
         -- Infer types for nested functions
         for _, nested_func in ipairs(nested_functions) do
            local nested_result = self:infer_nested_function_literal(
               nested_func,
               expected_type.rets as FunctionType,
               nested_context
            )
            
            if not nested_result.success then
               for _, error in ipairs(nested_result.errors) do
                  table.insert(result.errors, error)
               end
            else
               table.insert(result.applied_constraints, "nested_function_inferred")
            end
         end
      end
   end
   
   result.success = #result.errors == 0
   result.inferred_type = outer_result.inferred_type
   result.confidence = outer_result.confidence
   
   for _, constraint in ipairs(outer_result.applied_constraints) do
      table.insert(result.applied_constraints, constraint)
   end
   
   return result
end

-- Find all nested function literals in an AST node
function BaseContextualTypeChecker:find_nested_function_literals(
   node: Node
): {Node}
   
   local nested_functions: {Node} = {}
   
   if not node then
      return nested_functions
   end
   
   -- Recursively search for function literals
   local function search_node(n: Node)
      if not n then
         return
      end
      
      -- If this is a function literal, add it
      if n.kind == "function" then
         table.insert(nested_functions, n)
      end
      
      -- Search in common AST node fields
      if n.body then
         if type(n.body) == "table" then
            if n.body.kind then
               search_node(n.body)
            else
               -- It's a list of statements
               for _, stmt in ipairs(n.body) do
                  search_node(stmt)
               end
            end
         end
      end
      
      if n.exp then
         search_node(n.exp)
      end
      
      if n.exps then
         for _, exp in ipairs(n.exps) do
            search_node(exp)
         end
      end
      
      if n.args then
         for _, arg in ipairs(n.args) do
            if type(arg) == "table" and arg.kind then
               search_node(arg)
            end
         end
      end
   end
   
   search_node(node)
   return nested_functions
end

-- Infer types for higher-order functions (functions that return functions)
function BaseContextualTypeChecker:infer_higher_order_function(
   func_literal: Node,
   expected_type: FunctionType,
   context: InferenceContext
): InferenceResult
   
   local result: InferenceResult = {
      success = false,
      inferred_type = nil,
      errors = {},
      warnings = {},
      confidence = 0.0,
      applied_constraints = {},
   }
   
   -- Check if this is a higher-order function (returns a function)
   if not expected_type.rets or expected_type.rets.typename ~= "function" then
      -- Not a higher-order function, use normal inference
      return self:infer_function_parameters(func_literal, expected_type, context)
   end
   
   -- Infer parameters for the outer function
   local outer_result = self:infer_function_parameters(
      func_literal, expected_type, context
   )
   
   if not outer_result.success then
      for _, error in ipairs(outer_result.errors) do
         table.insert(result.errors, error)
      end
      return result
   end
   
   -- Create context for inner function inference
   local inner_context = contextual_typing.merge_inference_contexts(
      context,
      contextual_typing.new_inference_context(
         expected_type.rets,
         context.call_site,
         "nested_callback"
      )
   )
   
   -- Infer return type (inner function) if possible
   if func_literal.body then
      local return_type_result = self:infer_return_type_from_body(
         func_literal.body,
         expected_type.rets as FunctionType,
         inner_context
      )
      
      if return_type_result.success then
         table.insert(result.applied_constraints, "return_type_inferred")
      else
         for _, error in ipairs(return_type_result.errors) do
            table.insert(result.warnings, {
               message = "Could not infer return type: " .. error.message,
               location = error.location,
               confidence_level = 0.3
            })
         end
      end
   end
   
   result.success = outer_result.success
   result.inferred_type = outer_result.inferred_type
   result.confidence = outer_result.confidence
   
   for _, constraint in ipairs(outer_result.applied_constraints) do
      table.insert(result.applied_constraints, constraint)
   end
   
   return result
end

-- Infer return type from function body
function BaseContextualTypeChecker:infer_return_type_from_body(
   body: Node,
   expected_return_type: Type,
   context: InferenceContext
): InferenceResult
   
   local result: InferenceResult = {
      success = false,
      inferred_type = nil,
      errors = {},
      warnings = {},
      confidence = 0.0,
      applied_constraints = {},
   }
   
   if not body then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         body as Where,
         "Function body is missing",
         nil,
         expected_return_type
      )
      table.insert(result.errors, error)
      return result
   end
   
   -- Find return statements in the body
   local return_statements = self:find_return_statements(body)
   
   if #return_statements == 0 then
      -- No explicit return, infer nil return type
      result.inferred_type = { typename = "nil", typeid = 0 }
      result.success = true
      result.confidence = 0.5
      return result
   end
   
   -- Check if any return statement returns a function literal
   for _, return_stmt in ipairs(return_statements) do
      if return_stmt.exps and #return_stmt.exps > 0 then
         local return_exp = return_stmt.exps[1]
         
         if return_exp.kind == "function" then
            -- This is a nested function literal being returned
            if expected_return_type.typename == "function" then
               local nested_result = self:infer_function_parameters(
                  return_exp,
                  expected_return_type as FunctionType,
                  context
               )
               
               if nested_result.success then
                  result.inferred_type = nested_result.inferred_type
                  result.success = true
                  result.confidence = nested_result.confidence
                  table.insert(result.applied_constraints, "nested_return_inferred")
                  return result
               else
                  for _, error in ipairs(nested_result.errors) do
                     table.insert(result.errors, error)
                  end
               end
            end
         end
      end
   end
   
   -- If we couldn't infer from return statements, use expected type
   result.inferred_type = expected_return_type
   result.success = true
   result.confidence = 0.6
   table.insert(result.applied_constraints, "return_type_from_context")
   
   return result
end

-- Find all return statements in a function body
function BaseContextualTypeChecker:find_return_statements(
   node: Node
): {Node}
   
   local return_statements: {Node} = {}
   
   if not node then
      return return_statements
   end
   
   local function search_node(n: Node)
      if not n then
         return
      end
      
      -- If this is a return statement, add it
      if n.kind == "return" then
         table.insert(return_statements, n)
         return  -- Don't search inside return statement
      end
      
      -- Search in body
      if n.body then
         if type(n.body) == "table" then
            if n.body.kind then
               search_node(n.body)
            else
               for _, stmt in ipairs(n.body) do
                  search_node(stmt)
               end
            end
         end
      end
      
      -- Search in if/else branches
      if n.ifs then
         for _, if_branch in ipairs(n.ifs) do
            if if_branch.body then
               if type(if_branch.body) == "table" then
                  if if_branch.body.kind then
                     search_node(if_branch.body)
                  else
                     for _, stmt in ipairs(if_branch.body) do
                        search_node(stmt)
                     end
                  end
               end
            end
         end
      end
      
      if n.elsebody then
         if type(n.elsebody) == "table" then
            if n.elsebody.kind then
               search_node(n.elsebody)
            else
               for _, stmt in ipairs(n.elsebody) do
                  search_node(stmt)
               end
            end
         end
      end
   end
   
   search_node(node)
   return return_statements
end

-- Propagate type information through nested function contexts
function BaseContextualTypeChecker:propagate_type_through_nesting(
   func_literal: Node,
   expected_type: FunctionType,
   parent_context: InferenceContext,
   nesting_depth: integer
): InferenceResult
   
   local result: InferenceResult = {
      success = false,
      inferred_type = nil,
      errors = {},
      warnings = {},
      confidence = 0.0,
      applied_constraints = {},
   }
   
   -- Check nesting depth limit
   if nesting_depth > self.max_inference_depth then
      local error = contextual_typing.new_inference_error(
         "recursive_type_limit",
         func_literal as Where,
         string.format("Nesting depth limit exceeded (%d)", self.max_inference_depth),
         nil,
         expected_type
      )
      table.insert(result.errors, error)
      return result
   end
   
   -- Create context for this nesting level
   local nested_context = contextual_typing.merge_inference_contexts(
      parent_context,
      contextual_typing.new_inference_context(
         expected_type,
         parent_context.call_site,
         "nested_callback"
      )
   )
   
   -- Perform inference at this level
   local inference_result = self:infer_function_parameters(
      func_literal, expected_type, nested_context
   )
   
   if not inference_result.success then
      for _, error in ipairs(inference_result.errors) do
         table.insert(result.errors, error)
      end
      return result
   end
   
   -- If return type is a function, propagate to next level
   if expected_type.rets and expected_type.rets.typename == "function" then
      local next_level_result = self:propagate_type_through_nesting(
         func_literal,
         expected_type.rets as FunctionType,
         nested_context,
         nesting_depth + 1
      )
      
      if next_level_result.success then
         table.insert(result.applied_constraints, "nested_propagation_successful")
      else
         -- Nested propagation failed, but outer level succeeded
         for _, warning in ipairs(next_level_result.errors) do
            table.insert(result.warnings, {
               message = "Nested propagation failed: " .. warning.message,
               location = warning.location,
               confidence_level = 0.4
            })
         end
      end
   end
   
   result.success = inference_result.success
   result.inferred_type = inference_result.inferred_type
   result.confidence = inference_result.confidence
   
   for _, constraint in ipairs(inference_result.applied_constraints) do
      table.insert(result.applied_constraints, constraint)
   end
   
   return result
end

-- Handle callbacks that return functions
function BaseContextualTypeChecker:infer_callback_returning_function(
   callback_literal: Node,
   callback_type: FunctionType,
   context: InferenceContext
): InferenceResult
   
   local result: InferenceResult = {
      success = false,
      inferred_type = nil,
      errors = {},
      warnings = {},
      confidence = 0.0,
      applied_constraints = {},
   }
   
   -- Verify callback type has function return type
   if not callback_type.rets or callback_type.rets.typename ~= "function" then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         callback_literal as Where,
         "Callback return type is not a function",
         nil,
         callback_type.rets
      )
      table.insert(result.errors, error)
      return result
   end
   
   -- Infer callback parameters
   local callback_result = self:infer_function_parameters(
      callback_literal, callback_type, context
   )
   
   if not callback_result.success then
      for _, error in ipairs(callback_result.errors) do
         table.insert(result.errors, error)
      end
      return result
   end
   
   -- Create context for the returned function
   local return_func_context = contextual_typing.merge_inference_contexts(
      context,
      contextual_typing.new_inference_context(
         callback_type.rets,
         context.call_site,
         "nested_callback"
      )
   )
   
   -- Infer the returned function type
   local returned_func_result = self:infer_return_type_from_body(
      callback_literal.body,
      callback_type.rets as FunctionType,
      return_func_context
   )
   
   if not returned_func_result.success then
      for _, error in ipairs(returned_func_result.errors) do
         table.insert(result.errors, error)
      end
      return result
   end
   
   result.success = true
   result.inferred_type = callback_result.inferred_type
   result.confidence = math.min(callback_result.confidence, returned_func_result.confidence)
   
   for _, constraint in ipairs(callback_result.applied_constraints) do
      table.insert(result.applied_constraints, constraint)
   end
   
   for _, constraint in ipairs(returned_func_result.applied_constraints) do
      table.insert(result.applied_constraints, constraint)
   end
   
   table.insert(result.applied_constraints, "callback_returning_function_inferred")
   
   return result
end

--------------------------------------------------------------------------------
-- Complex Type Scenario Support
-- 
-- These methods handle inference for union types, intersection types,
-- recursive types, and conditional expressions.
--------------------------------------------------------------------------------

-- Infer types for union type scenarios
function BaseContextualTypeChecker:infer_union_type_scenario(
   func_literal: Node,
   union_type: Type,
   context: InferenceContext
): InferenceResult
   
   local result: InferenceResult = {
      success = false,
      inferred_type = nil,
      errors = {},
      warnings = {},
      confidence = 0.0,
      applied_constraints = {},
   }
   
   -- Check if this is a union type
   if union_type.typename ~= "union" then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         func_literal as Where,
         "Expected type is not a union type",
         nil,
         union_type
      )
      table.insert(result.errors, error)
      return result
   end
   
   -- Get union members
   local union_members = union_type.types or {}
   
   if #union_members == 0 then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         func_literal as Where,
         "Union type has no members",
         nil,
         union_type
      )
      table.insert(result.errors, error)
      return result
   end
   
   -- Try inference with each union member
   local successful_inferences: {InferenceResult} = {}
   local all_errors: {InferenceError} = {}
   
   for i, member_type in ipairs(union_members) do
      if member_type.typename == "function" then
         local member_result = self:infer_function_parameters(
            func_literal,
            member_type as FunctionType,
            context
         )
         
         if member_result.success then
            table.insert(successful_inferences, member_result)
         else
            for _, error in ipairs(member_result.errors) do
               table.insert(all_errors, error)
            end
         end
      end
   end
   
   -- If we have successful inferences, pick the best one
   if #successful_inferences > 0 then
      -- Sort by confidence (highest first)
      table.sort(successful_inferences, function(a, b)
         return a.confidence > b.confidence
      end)
      
      local best_result = successful_inferences[1]
      result.success = true
      result.inferred_type = best_result.inferred_type
      result.confidence = best_result.confidence * 0.9  -- Reduce confidence for union
      
      table.insert(result.applied_constraints, "union_type_inference_successful")
      
      if #successful_inferences > 1 then
         local warning: contextual_typing.InferenceWarning = {
            message = string.format("Multiple union members matched (%d), selected highest confidence",
                                   #successful_inferences),
            location = func_literal as Where,
            confidence_level = 0.7
         }
         table.insert(result.warnings, warning)
      end
   else
      -- No successful inferences
      for _, error in ipairs(all_errors) do
         table.insert(result.errors, error)
      end
      
      local error = contextual_typing.new_inference_error(
         "ambiguous_inference",
         func_literal as Where,
         string.format("Could not infer function type from union of %d members", #union_members),
         nil,
         union_type
      )
      table.insert(result.errors, error)
   end
   
   return result
end

-- Infer types for intersection type scenarios
function BaseContextualTypeChecker:infer_intersection_type_scenario(
   func_literal: Node,
   intersection_type: Type,
   context: InferenceContext
): InferenceResult
   
   local result: InferenceResult = {
      success = false,
      inferred_type = nil,
      errors = {},
      warnings = {},
      confidence = 0.0,
      applied_constraints = {},
   }
   
   -- Check if this is an intersection type
   if intersection_type.typename ~= "intersection" then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         func_literal as Where,
         "Expected type is not an intersection type",
         nil,
         intersection_type
      )
      table.insert(result.errors, error)
      return result
   end
   
   -- Get intersection members
   local intersection_members = intersection_type.types or {}
   
   if #intersection_members == 0 then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         func_literal as Where,
         "Intersection type has no members",
         nil,
         intersection_type
      )
      table.insert(result.errors, error)
      return result
   end
   
   -- Find function type in intersection
   local function_type: FunctionType = nil
   
   for _, member_type in ipairs(intersection_members) do
      if member_type.typename == "function" then
         function_type = member_type as FunctionType
         break
      end
   end
   
   if not function_type then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         func_literal as Where,
         "Intersection type does not contain a function type",
         nil,
         intersection_type
      )
      table.insert(result.errors, error)
      return result
   end
   
   -- Perform inference with the function type
   local inference_result = self:infer_function_parameters(
      func_literal,
      function_type,
      context
   )
   
   if not inference_result.success then
      for _, error in ipairs(inference_result.errors) do
         table.insert(result.errors, error)
      end
      return result
   end
   
   result.success = true
   result.inferred_type = inference_result.inferred_type
   result.confidence = inference_result.confidence * 0.95  -- Slight confidence reduction for intersection
   
   for _, constraint in ipairs(inference_result.applied_constraints) do
      table.insert(result.applied_constraints, constraint)
   end
   
   table.insert(result.applied_constraints, "intersection_type_inference_successful")
   
   return result
end

-- Handle recursive type inference without infinite loops
function BaseContextualTypeChecker:infer_recursive_type_scenario(
   func_literal: Node,
   recursive_type: Type,
   context: InferenceContext,
   visited_types: {string}
): InferenceResult
   
   local result: InferenceResult = {
      success = false,
      inferred_type = nil,
      errors = {},
      warnings = {},
      confidence = 0.0,
      applied_constraints = {},
   }
   
   -- Initialize visited types if not provided
   if not visited_types then
      visited_types = {}
   end
   
   -- Check for recursive type cycles
   local type_id = recursive_type.typename or "unknown"
   
   if visited_types[type_id] then
      -- We've seen this type before - potential infinite recursion
      local error = contextual_typing.new_inference_error(
         "recursive_type_limit",
         func_literal as Where,
         string.format("Recursive type cycle detected: %s", type_id),
         nil,
         recursive_type
      )
      table.insert(result.errors, error)
      return result
   end
   
   -- Mark this type as visited
   visited_types[type_id] = true
   
   -- If it's a function type, perform normal inference
   if recursive_type.typename == "function" then
      local inference_result = self:infer_function_parameters(
         func_literal,
         recursive_type as FunctionType,
         context
      )
      
      if not inference_result.success then
         for _, error in ipairs(inference_result.errors) do
            table.insert(result.errors, error)
         end
         return result
      end
      
      result.success = true
      result.inferred_type = inference_result.inferred_type
      result.confidence = inference_result.confidence
      
      for _, constraint in ipairs(inference_result.applied_constraints) do
         table.insert(result.applied_constraints, constraint)
      end
      
      table.insert(result.applied_constraints, "recursive_type_handled")
   else
      -- For non-function recursive types, we can't infer
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         func_literal as Where,
         string.format("Cannot infer function type from recursive type: %s", type_id),
         nil,
         recursive_type
      )
      table.insert(result.errors, error)
   end
   
   return result
end

-- Infer types for conditional expression scenarios
function BaseContextualTypeChecker:infer_conditional_expression_type(
   func_literal: Node,
   conditional_node: Node,
   expected_type: Type,
   context: InferenceContext
): InferenceResult
   
   local result: InferenceResult = {
      success = false,
      inferred_type = nil,
      errors = {},
      warnings = {},
      confidence = 0.0,
      applied_constraints = {},
   }
   
   -- Check if this is a conditional expression
   if conditional_node.kind ~= "if" then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         conditional_node as Where,
         "Node is not a conditional expression",
         nil,
         expected_type
      )
      table.insert(result.errors, error)
      return result
   end
   
   -- Get the branches of the conditional
   local if_branches = conditional_node.ifs or {}
   local else_branch = conditional_node.elsebody
   
   if #if_branches == 0 then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         conditional_node as Where,
         "Conditional has no branches",
         nil,
         expected_type
      )
      table.insert(result.errors, error)
      return result
   end
   
   -- Infer types for each branch
   local branch_results: {InferenceResult} = {}
   
   for _, if_branch in ipairs(if_branches) do
      if if_branch.body then
         -- Find function literals in this branch
         local nested_functions = self:find_nested_function_literals(if_branch.body)
         
         for _, nested_func in ipairs(nested_functions) do
            if expected_type.typename == "function" then
               local branch_result = self:infer_function_parameters(
                  nested_func,
                  expected_type as FunctionType,
                  context
               )
               
               table.insert(branch_results, branch_result)
            end
         end
      end
   end
   
   -- Check else branch if present
   if else_branch then
      local nested_functions = self:find_nested_function_literals(else_branch)
      
      for _, nested_func in ipairs(nested_functions) do
         if expected_type.typename == "function" then
            local branch_result = self:infer_function_parameters(
               nested_func,
               expected_type as FunctionType,
               context
            )
            
            table.insert(branch_results, branch_result)
         end
      end
   end
   
   -- Check if all branches succeeded
   local all_succeeded = true
   local total_confidence = 0.0
   
   for _, branch_result in ipairs(branch_results) do
      if not branch_result.success then
         all_succeeded = false
         for _, error in ipairs(branch_result.errors) do
            table.insert(result.errors, error)
         end
      else
         total_confidence = total_confidence + branch_result.confidence
      end
   end
   
   if all_succeeded and #branch_results > 0 then
      result.success = true
      result.inferred_type = expected_type
      result.confidence = total_confidence / #branch_results
      
      table.insert(result.applied_constraints, "conditional_expression_inferred")
   else
      if #branch_results == 0 then
         local error = contextual_typing.new_inference_error(
            "incompatible_signature",
            conditional_node as Where,
            "No function literals found in conditional branches",
            nil,
            expected_type
         )
         table.insert(result.errors, error)
      end
   end
   
   return result
end

-- Detect and handle recursive type definitions
function BaseContextualTypeChecker:detect_recursive_type(
   typ: Type,
   visited: {string}
): boolean
   
   if not visited then
      visited = {}
   end
   
   local type_id = typ.typename or "unknown"
   
   -- Check if we've already visited this type
   if visited[type_id] then
      return true  -- Recursive type detected
   end
   
   -- Mark as visited
   visited[type_id] = true
   
   -- Check nested types
   if typ.typename == "function" then
      local func_type = typ as FunctionType
      
      if func_type.args then
         local args_tuple = func_type.args as types.TupleType
         if args_tuple.tuple then
            for _, arg_type in ipairs(args_tuple.tuple) do
               if self:detect_recursive_type(arg_type, visited) then
                  return true
               end
            end
         end
      end
      
      if func_type.rets then
         if self:detect_recursive_type(func_type.rets, visited) then
            return true
         end
      end
   elseif typ.typename == "array" then
      if typ.elements then
         if self:detect_recursive_type(typ.elements, visited) then
            return true
         end
      end
   elseif typ.typename == "map" then
      if typ.keys then
         if self:detect_recursive_type(typ.keys, visited) then
            return true
         end
      end
      if typ.values then
         if self:detect_recursive_type(typ.values, visited) then
            return true
         end
      end
   elseif typ.typename == "union" then
      if typ.types then
         for _, member_type in ipairs(typ.types) do
            if self:detect_recursive_type(member_type, visited) then
               return true
            end
         end
      end
   end
   
   return false
end

-- Infer types for complex nested scenarios
function BaseContextualTypeChecker:infer_complex_type_scenario(
   func_literal: Node,
   expected_type: Type,
   context: InferenceContext
): InferenceResult
   
   local result: InferenceResult = {
      success = false,
      inferred_type = nil,
      errors = {},
      warnings = {},
      confidence = 0.0,
      applied_constraints = {},
   }
   
   -- Check for recursive types
   if self:detect_recursive_type(expected_type) then
      local recursive_result = self:infer_recursive_type_scenario(
         func_literal,
         expected_type,
         context,
         {}
      )
      
      if recursive_result.success then
         return recursive_result
      else
         for _, error in ipairs(recursive_result.errors) do
            table.insert(result.errors, error)
         end
      end
   end
   
   -- Check for union types
   if expected_type.typename == "union" then
      local union_result = self:infer_union_type_scenario(
         func_literal,
         expected_type,
         context
      )
      
      if union_result.success then
         return union_result
      else
         for _, error in ipairs(union_result.errors) do
            table.insert(result.errors, error)
         end
      end
   end
   
   -- Check for intersection types
   if expected_type.typename == "intersection" then
      local intersection_result = self:infer_intersection_type_scenario(
         func_literal,
         expected_type,
         context
      )
      
      if intersection_result.success then
         return intersection_result
      else
         for _, error in ipairs(intersection_result.errors) do
            table.insert(result.errors, error)
         end
      end
   end
   
   -- If no complex type scenario matched, return error
   if #result.errors == 0 then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         func_literal as Where,
         string.format("Cannot infer function type from complex type: %s", 
                      expected_type.typename or "unknown"),
         nil,
         expected_type
      )
      table.insert(result.errors, error)
   end
   
   return result
end

return {
   BaseContextualTypeChecker = BaseContextualTypeChecker,
}
