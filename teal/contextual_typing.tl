--------------------------------------------------------------------------------
-- Contextual Typing Infrastructure for Teal
-- 
-- This module provides the core data structures and interfaces for implementing
-- contextual typing (target type inference) in the Teal programming language.
--------------------------------------------------------------------------------

local type errors = require("teal.errors")
local type Where = errors.Where
local type Error = errors.Error

local type types = require("teal.types")
local type Type = types.Type
local type FunctionType = types.FunctionType
local type TypeArgType = types.TypeArgType
local type FirstOrderType = types.FirstOrderType

local type parser = require("teal.parser")
local type Node = parser.Node

--------------------------------------------------------------------------------
-- Core Contextual Typing Data Structures
--------------------------------------------------------------------------------

local record contextual_typing

   -- Inference source tracking for error reporting and debugging
   enum InferenceSource
      "call_site"           -- Inferred from function call context
      "assignment"          -- Inferred from assignment target type
      "return_type"         -- Inferred from function return type
      "generic_constraint"  -- Inferred from generic type constraints
      "nested_callback"     -- Inferred from nested function context
   end

   -- Error kinds for contextual inference failures
   enum InferenceErrorKind
      "no_contextual_information"     -- No expected type available
      "ambiguous_inference"           -- Multiple possible types
      "constraint_violation"          -- Generic constraints not satisfied
      "recursive_type_limit"          -- Recursive type depth exceeded
      "incompatible_signature"        -- Function signature mismatch
      "mixed_parameter_conflict"      -- Conflict between explicit and inferred types
   end

   -- Detailed error information for inference failures
   record InferenceError
      kind: InferenceErrorKind
      message: string
      location: Where
      suggested_fix: string
      related_locations: {Where}
      inferred_type: Type          -- The type that was attempted to be inferred
      expected_type: Type          -- The type that was expected
   end

   -- Warning information for inference edge cases
   record InferenceWarning
      message: string
      location: Where
      confidence_level: number     -- 0.0 to 1.0, how confident we are in the inference
   end

   -- Context information for type inference
   record InferenceContext
      expected_type: Type
      call_site: CallSite
      generic_bindings: {string: Type}  -- TypeVariable name -> resolved Type
      inference_depth: integer
      source: InferenceSource
      parent_context: InferenceContext  -- For nested inference scenarios
   end

   -- Call site information for error reporting and context tracking
   record CallSite
      function_name: string
      argument_position: integer
      source_location: Where
      generic_context: {string: Type}   -- Generic type bindings at call site
      is_method_call: boolean
   end

   -- Result of contextual inference with diagnostics
   record InferenceResult
      success: boolean
      inferred_type: FunctionType
      errors: {InferenceError}
      warnings: {InferenceWarning}
      confidence: number               -- Overall confidence in inference (0.0 to 1.0)
      applied_constraints: {string}    -- List of constraints that were applied
   end

   -- Enhanced parameter information with inference metadata
   record ParameterInfo
      name: string
      declared_type: Type              -- nil if untyped
      inferred_type: Type              -- nil if not inferred
      position: Where
      is_inferred: boolean
      inference_confidence: number     -- 0.0 to 1.0
      inference_source: InferenceSource
   end

   -- Enhanced function signature with inference capabilities
   record InferredFunctionType
      is FunctionType
      
      parameters: {ParameterInfo}
      is_contextually_typed: boolean
      inference_metadata: InferenceMetadata
   end

   -- Metadata tracking inference process and results
   record InferenceMetadata
      inference_attempts: integer
      successful_inferences: integer
      failed_inferences: integer
      inference_time_ms: number        -- For performance monitoring
      constraint_violations: {string}
      fallback_used: boolean
   end

   -- State management for inference process
   record InferenceState
      expected_types: {Node: FunctionType}     -- Function literal -> expected type
      generic_bindings: {string: Type}         -- Current generic type bindings
      inference_stack: {InferenceContext}     -- Stack for nested inference
      error_accumulator: {InferenceError}     -- Accumulated errors
      depth_limit: integer                     -- Maximum inference depth
      current_depth: integer
   end

   -- Constraint information for generic type resolution
   record InferenceConstraint
      kind: ConstraintKind
      left_type: Type
      right_type: Type
      source_location: Where
      priority: integer                -- Higher priority constraints resolved first
   end

   enum ConstraintKind
      "subtype"           -- left_type <: right_type
      "equality"          -- left_type = right_type
      "generic_bound"     -- Generic type parameter constraint
      "contextual_match"  -- Contextual type matching constraint
   end

   -- Regression test case for backward compatibility
   record RegressionTest
      name: string
      description: string
      code: string
      expected_success: boolean
      expected_errors: {string}
   end

   -- Result of running a regression test
   record RegressionTestResult
      test_name: string
      description: string
      passed: boolean
      errors: {string}
      warnings: {string}
      execution_time_ms: number
   end

   ---------------------------------------------------------------------------------
   -- Core Contextual Type Checker Interface
   ---------------------------------------------------------------------------------

   interface ContextualTypeChecker
      -- Main inference method: infer parameter types from expected function type
      infer_function_parameters: function(
         self: ContextualTypeChecker,
         func_literal: Node,
         expected_type: FunctionType,
         context: InferenceContext
      ): InferenceResult

      -- Check if contextual inference is applicable for a function literal
      can_infer_contextually: function(
         self: ContextualTypeChecker,
         func_literal: Node,
         context: InferenceContext
      ): boolean

      -- Resolve generic type variables during inference
      resolve_generics: function(
         self: ContextualTypeChecker,
         expected_type: FunctionType,
         call_context: CallSite
      ): FunctionType, {string: Type}

      -- Create inference context from call site information
      create_inference_context: function(
         self: ContextualTypeChecker,
         expected_type: Type,
         call_site: CallSite,
         source: InferenceSource
      ): InferenceContext

      -- Validate inferred types against constraints
      validate_inference: function(
         self: ContextualTypeChecker,
         inferred_type: FunctionType,
         constraints: {InferenceConstraint}
      ): boolean, {InferenceError}

      -- Handle inference fallback when contextual inference fails
      handle_inference_fallback: function(
         self: ContextualTypeChecker,
         func_literal: Node,
         errors: {InferenceError}
      ): InferenceResult

      -- Performance monitoring and optimization
      get_inference_stats: function(
         self: ContextualTypeChecker
      ): InferenceMetadata
   end

   ---------------------------------------------------------------------------------
   -- Utility Functions
   ---------------------------------------------------------------------------------

   -- Create a new inference error with standard formatting
   new_inference_error: function(
      kind: InferenceErrorKind,
      location: Where,
      message: string,
      inferred_type?: Type,
      expected_type?: Type
   ): InferenceError

   -- Create a new inference context
   new_inference_context: function(
      expected_type: Type,
      call_site: CallSite,
      source: InferenceSource
   ): InferenceContext

   -- Create a new call site record
   new_call_site: function(
      function_name: string,
      argument_position: integer,
      location: Where
   ): CallSite

   -- Check if two function types are compatible for inference
   are_function_types_compatible: function(
      inferred: FunctionType,
      expected: FunctionType
   ): boolean, {InferenceError}

   -- Extract parameter information from function literal AST node
   extract_parameter_info: function(
      func_literal: Node
   ): {ParameterInfo}

   -- Merge inference contexts for nested scenarios
   merge_inference_contexts: function(
      parent: InferenceContext,
      child: InferenceContext
   ): InferenceContext

   -- Calculate confidence score for inference result
   calculate_inference_confidence: function(
      result: InferenceResult,
      constraints_satisfied: integer,
      total_constraints: integer
   ): number
end

--------------------------------------------------------------------------------
-- Implementation of utility functions
--------------------------------------------------------------------------------

function contextual_typing.new_inference_error(
   kind: contextual_typing.InferenceErrorKind,
   location: Where,
   message: string,
   inferred_type?: Type,
   expected_type?: Type
): contextual_typing.InferenceError
   return {
      kind = kind,
      message = message,
      location = location,
      suggested_fix = "",
      related_locations = {},
      inferred_type = inferred_type,
      expected_type = expected_type,
   }
end

function contextual_typing.new_inference_context(
   expected_type: Type,
   call_site: contextual_typing.CallSite,
   source: contextual_typing.InferenceSource
): contextual_typing.InferenceContext
   return {
      expected_type = expected_type,
      call_site = call_site,
      generic_bindings = {},
      inference_depth = 0,
      source = source,
      parent_context = nil,
   }
end

function contextual_typing.new_call_site(
   function_name: string,
   argument_position: integer,
   location: Where
): contextual_typing.CallSite
   return {
      function_name = function_name,
      argument_position = argument_position,
      source_location = location,
      generic_context = {},
      is_method_call = false,
   }
end

function contextual_typing.are_function_types_compatible(
   inferred: FunctionType,
   expected: FunctionType
): boolean, {contextual_typing.InferenceError}
   local errors: {contextual_typing.InferenceError} = {}
   
   -- Check parameter count compatibility
   local inferred_params = #inferred.args.tuple
   local expected_params = #expected.args.tuple
   
   if inferred_params ~= expected_params then
      table.insert(errors, contextual_typing.new_inference_error(
         "incompatible_signature",
         inferred as Where,
         string.format("Parameter count mismatch: inferred %d, expected %d", 
                      inferred_params, expected_params),
         inferred,
         expected
      ))
      return false, errors
   end
   
   -- Additional compatibility checks would go here
   -- (parameter types, return types, etc.)
   
   return #errors == 0, errors
end

function contextual_typing.extract_parameter_info(
   func_literal: Node
): {contextual_typing.ParameterInfo}
   local params: {contextual_typing.ParameterInfo} = {}
   
   if func_literal.args then
      for i, arg in ipairs(func_literal.args) do
         local param_info: contextual_typing.ParameterInfo = {
            name = arg.tk or ("param" .. i),
            declared_type = arg.argtype,
            inferred_type = nil,
            position = arg as Where,
            is_inferred = arg.argtype == nil,
            inference_confidence = 0.0,
            inference_source = "call_site",
         }
         table.insert(params, param_info)
      end
   end
   
   return params
end

function contextual_typing.merge_inference_contexts(
   parent: contextual_typing.InferenceContext,
   child: contextual_typing.InferenceContext
): contextual_typing.InferenceContext
   local merged = contextual_typing.new_inference_context(
      child.expected_type,
      child.call_site,
      child.source
   )
   
   -- Merge generic bindings from parent
   for name, typ in pairs(parent.generic_bindings) do
      merged.generic_bindings[name] = typ
   end
   
   -- Add child bindings (child takes precedence)
   for name, typ in pairs(child.generic_bindings) do
      merged.generic_bindings[name] = typ
   end
   
   merged.inference_depth = parent.inference_depth + 1
   merged.parent_context = parent
   
   return merged
end

function contextual_typing.calculate_inference_confidence(
   result: contextual_typing.InferenceResult,
   constraints_satisfied: integer,
   total_constraints: integer
): number
   if total_constraints == 0 then
      return 1.0
   end
   
   local base_confidence = constraints_satisfied / total_constraints
   
   -- Reduce confidence based on number of errors
   local error_penalty = #result.errors * 0.1
   
   -- Reduce confidence based on number of warnings
   local warning_penalty = #result.warnings * 0.05
   
   local final_confidence = math.max(0.0, base_confidence - error_penalty - warning_penalty)
   
   return math.min(1.0, final_confidence)
end

return contextual_typing