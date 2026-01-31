--------------------------------------------------------------------------------
-- Mixed Parameter Handler for Contextual Typing
-- 
-- This module provides specialized handling for function literals with mixed
-- explicit and inferred parameters. It ensures consistent type resolution
-- across parameter combinations and provides detailed error reporting.
--------------------------------------------------------------------------------

local contextual_typing = require("teal.contextual_typing")
local type InferenceResult = contextual_typing.InferenceResult
local type InferenceContext = contextual_typing.InferenceContext
local type InferenceError = contextual_typing.InferenceError
local type ParameterInfo = contextual_typing.ParameterInfo
local type CallSite = contextual_typing.CallSite

local type types = require("teal.types")
local type Type = types.Type
local type FunctionType = types.FunctionType
local type TupleType = types.TupleType

local type parser = require("teal.parser")
local type Node = parser.Node

local type errors = require("teal.errors")
local type Where = errors.Where

--------------------------------------------------------------------------------
-- Mixed Parameter Handler Implementation
--------------------------------------------------------------------------------

local record MixedParameterHandler
   -- Configuration for mixed parameter handling
   strict_mode: boolean                    -- If true, require all parameters to be consistent
   allow_partial_inference: boolean        -- If true, allow inference for some parameters
   track_inference_sources: boolean        -- If true, track where each type came from
end

-- Create a new mixed parameter handler
function MixedParameterHandler:new(): MixedParameterHandler
   return {
      strict_mode = false,
      allow_partial_inference = true,
      track_inference_sources = true,
   }
end

--------------------------------------------------------------------------------
-- Core Mixed Parameter Resolution
--------------------------------------------------------------------------------

-- Analyze parameter mix and determine resolution strategy
function MixedParameterHandler:analyze_parameter_mix(
   param_info: {ParameterInfo}
): {
   has_explicit: boolean,
   has_untyped: boolean,
   explicit_count: integer,
   untyped_count: integer,
   explicit_positions: {integer},
   untyped_positions: {integer},
   is_pure_explicit: boolean,
   is_pure_untyped: boolean,
   is_mixed: boolean
}
   
   local analysis = {
      has_explicit = false,
      has_untyped = false,
      explicit_count = 0,
      untyped_count = 0,
      explicit_positions = {},
      untyped_positions = {},
      is_pure_explicit = false,
      is_pure_untyped = false,
      is_mixed = false,
   }
   
   for i, param in ipairs(param_info) do
      if param.declared_type then
         analysis.has_explicit = true
         analysis.explicit_count = analysis.explicit_count + 1
         table.insert(analysis.explicit_positions, i)
      else
         analysis.has_untyped = true
         analysis.untyped_count = analysis.untyped_count + 1
         table.insert(analysis.untyped_positions, i)
      end
   end
   
   analysis.is_pure_explicit = analysis.has_explicit and not analysis.has_untyped
   analysis.is_pure_untyped = analysis.has_untyped and not analysis.has_explicit
   analysis.is_mixed = analysis.has_explicit and analysis.has_untyped
   
   return analysis
end

-- Resolve mixed parameter types using explicit types where provided
function MixedParameterHandler:resolve_mixed_parameters(
   param_info: {ParameterInfo},
   expected_type: FunctionType,
   context: InferenceContext
): {ParameterInfo}, {InferenceError}
   
   local errors: {InferenceError} = {}
   local resolved_params: {ParameterInfo} = {}
   
   -- Analyze the parameter mix
   local analysis = self:analyze_parameter_mix(param_info)
   
   -- If pure explicit, just validate against expected type
   if analysis.is_pure_explicit then
      return self:resolve_pure_explicit_parameters(param_info, expected_type, context)
   end
   
   -- If pure untyped, infer all from expected type
   if analysis.is_pure_untyped then
      return self:resolve_pure_untyped_parameters(param_info, expected_type, context)
   end
   
   -- Mixed case: use explicit where provided, infer where needed
   if analysis.is_mixed then
      return self:resolve_mixed_parameter_combination(param_info, expected_type, context)
   end
   
   return resolved_params, errors
end

-- Resolve pure explicit parameters (all have type annotations)
function MixedParameterHandler:resolve_pure_explicit_parameters(
   param_info: {ParameterInfo},
   expected_type: FunctionType,
   context: InferenceContext
): {ParameterInfo}, {InferenceError}
   
   local errors: {InferenceError} = {}
   local resolved_params: {ParameterInfo} = {}
   
   if not expected_type.args or not expected_type.args.tuple then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         context.call_site.source_location,
         "Expected function type has no parameter information",
         nil,
         expected_type
      )
      table.insert(errors, error)
      return param_info, errors
   end
   
   local expected_params = expected_type.args.tuple
   
   -- Validate each explicit parameter against expected type
   for i, param in ipairs(param_info) do
      local resolved_param: ParameterInfo = {
         name = param.name,
         declared_type = param.declared_type,
         inferred_type = param.declared_type,
         position = param.position,
         is_inferred = false,
         inference_confidence = 1.0,
         inference_source = "explicit_annotation",
      }
      
      if i <= #expected_params then
         local expected_param = expected_params[i]
         
         -- Check compatibility between explicit and expected types
         local compatible, compat_errors = self:check_parameter_compatibility(
            param.declared_type, expected_param, i, param.position
         )
         
         if not compatible then
            for _, error in ipairs(compat_errors) do
               table.insert(errors, error)
            end
         end
      end
      
      table.insert(resolved_params, resolved_param)
   end
   
   return resolved_params, errors
end

-- Resolve pure untyped parameters (all need inference)
function MixedParameterHandler:resolve_pure_untyped_parameters(
   param_info: {ParameterInfo},
   expected_type: FunctionType,
   context: InferenceContext
): {ParameterInfo}, {InferenceError}
   
   local errors: {InferenceError} = {}
   local resolved_params: {ParameterInfo} = {}
   
   if not expected_type.args or not expected_type.args.tuple then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         context.call_site.source_location,
         "Expected function type has no parameter information",
         nil,
         expected_type
      )
      table.insert(errors, error)
      return param_info, errors
   end
   
   local expected_params = expected_type.args.tuple
   
   -- Infer each untyped parameter from expected type
   for i, param in ipairs(param_info) do
      local inferred_type: Type
      
      if i <= #expected_params then
         inferred_type = expected_params[i]
      else
         -- No expected type for this parameter
         inferred_type = {
            typename = "any",
            typeid = 999,
            inferred_at = param.position,
            needs_compat = false
         }
      end
      
      local resolved_param: ParameterInfo = {
         name = param.name,
         declared_type = nil,
         inferred_type = inferred_type,
         position = param.position,
         is_inferred = true,
         inference_confidence = 0.9,
         inference_source = context.source,
      }
      
      table.insert(resolved_params, resolved_param)
   end
   
   return resolved_params, errors
end

-- Resolve mixed parameter combination (some explicit, some untyped)
function MixedParameterHandler:resolve_mixed_parameter_combination(
   param_info: {ParameterInfo},
   expected_type: FunctionType,
   context: InferenceContext
): {ParameterInfo}, {InferenceError}
   
   local errors: {InferenceError} = {}
   local resolved_params: {ParameterInfo} = {}
   
   if not expected_type.args or not expected_type.args.tuple then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         context.call_site.source_location,
         "Expected function type has no parameter information",
         nil,
         expected_type
      )
      table.insert(errors, error)
      return param_info, errors
   end
   
   local expected_params = expected_type.args.tuple
   
   -- Process each parameter
   for i, param in ipairs(param_info) do
      local resolved_param: ParameterInfo
      
      if param.declared_type then
         -- Use explicit type, validate against expected
         resolved_param = {
            name = param.name,
            declared_type = param.declared_type,
            inferred_type = param.declared_type,
            position = param.position,
            is_inferred = false,
            inference_confidence = 1.0,
            inference_source = "explicit_annotation",
         }
         
         if i <= #expected_params then
            local expected_param = expected_params[i]
            local compatible, compat_errors = self:check_parameter_compatibility(
               param.declared_type, expected_param, i, param.position
            )
            
            if not compatible then
               for _, error in ipairs(compat_errors) do
                  table.insert(errors, error)
               end
            end
         end
      else
         -- Infer type from expected
         local inferred_type: Type
         
         if i <= #expected_params then
            inferred_type = expected_params[i]
         else
            inferred_type = {
               typename = "any",
               typeid = 999,
               inferred_at = param.position,
               needs_compat = false
            }
         end
         
         resolved_param = {
            name = param.name,
            declared_type = nil,
            inferred_type = inferred_type,
            position = param.position,
            is_inferred = true,
            inference_confidence = 0.9,
            inference_source = context.source,
         }
      end
      
      table.insert(resolved_params, resolved_param)
   end
   
   return resolved_params, errors
end

--------------------------------------------------------------------------------
-- Parameter Compatibility Checking
--------------------------------------------------------------------------------

-- Check if a parameter type is compatible with expected type
function MixedParameterHandler:check_parameter_compatibility(
   param_type: Type,
   expected_type: Type,
   param_index: integer,
   location: Where
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- If types are identical, they're compatible
   if self:types_are_identical(param_type, expected_type) then
      return true, errors
   end
   
   -- Check for subtyping relationship
   local is_subtype, subtype_errors = self:check_subtype_relationship(
      param_type, expected_type
   )
   
   if is_subtype then
      return true, errors
   end
   
   -- Types are not compatible
   local error = contextual_typing.new_inference_error(
      "mixed_parameter_conflict",
      location,
      string.format(
         "Parameter %d type mismatch: explicit type '%s' is not compatible with expected type '%s'",
         param_index,
         param_type.typename or "unknown",
         expected_type.typename or "unknown"
      ),
      param_type,
      expected_type
   )
   
   error.suggested_fix = string.format(
      "Change parameter %d type from '%s' to '%s', or adjust the expected function type",
      param_index,
      param_type.typename or "unknown",
      expected_type.typename or "unknown"
   )
   
   table.insert(errors, error)
   return false, errors
end

-- Check if two types are identical
function MixedParameterHandler:types_are_identical(
   type1: Type,
   type2: Type
): boolean
   
   if not type1 or not type2 then
      return type1 == type2
   end
   
   -- Compare type names
   if type1.typename ~= type2.typename then
      return false
   end
   
   -- For simple types, typename comparison is sufficient
   if type1.typename == "number" or type1.typename == "string" or 
      type1.typename == "boolean" or type1.typename == "nil" or
      type1.typename == "any" then
      return true
   end
   
   -- For complex types, would need deeper comparison
   -- This is a simplified version
   return type1.typeid == type2.typeid
end

-- Check subtype relationship between two types
function MixedParameterHandler:check_subtype_relationship(
   subtype: Type,
   supertype: Type
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- 'any' is both subtype and supertype of everything
   if supertype.typename == "any" or subtype.typename == "any" then
      return true, errors
   end
   
   -- nil is subtype of everything (in Lua)
   if subtype.typename == "nil" then
      return true, errors
   end
   
   -- For now, only identical types are subtypes
   -- Full subtyping would require more sophisticated checking
   return self:types_are_identical(subtype, supertype), errors
end

--------------------------------------------------------------------------------
-- Error Reporting for Mixed Parameters
--------------------------------------------------------------------------------

-- Generate detailed error message for mixed parameter conflict
function MixedParameterHandler:generate_mixed_parameter_error(
   param_info: ParameterInfo,
   expected_type: Type,
   param_index: integer,
   location: Where
): InferenceError
   
   local error = contextual_typing.new_inference_error(
      "mixed_parameter_conflict",
      location,
      string.format(
         "Parameter %d ('%s'): explicit type '%s' conflicts with expected type '%s'",
         param_index,
         param_info.name,
         param_info.declared_type.typename or "unknown",
         expected_type.typename or "unknown"
      ),
      param_info.declared_type,
      expected_type
   )
   
   error.suggested_fix = self:generate_fix_suggestion(param_info, expected_type, param_index)
   
   return error
end

-- Generate suggestion for fixing mixed parameter conflicts
function MixedParameterHandler:generate_fix_suggestion(
   param_info: ParameterInfo,
   expected_type: Type,
   param_index: integer
): string
   
   local suggestions = {}
   
   -- Suggest changing explicit type
   table.insert(suggestions, string.format(
      "Change parameter %d type from '%s' to '%s'",
      param_index,
      param_info.declared_type.typename or "unknown",
      expected_type.typename or "unknown"
   ))
   
   -- Suggest removing explicit type to allow inference
   table.insert(suggestions, string.format(
      "Remove explicit type from parameter %d to allow inference",
      param_index
   ))
   
   -- Suggest adjusting expected type
   table.insert(suggestions, string.format(
      "Adjust the expected function type to accept '%s' for parameter %d",
      param_info.declared_type.typename or "unknown",
      param_index
   ))
   
   return "Possible fixes: " .. table.concat(suggestions, "; ")
end

-- Create location tracking information for inference sources
function MixedParameterHandler:create_location_tracking(
   param_info: {ParameterInfo},
   expected_type: FunctionType,
   context: InferenceContext
): {
   parameter_sources: {integer: {
      is_explicit: boolean,
      source_location: Where,
      source_type: string
   }},
   expected_type_location: Where,
   call_site_location: Where
}
   
   local tracking = {
      parameter_sources = {},
      expected_type_location = expected_type.inferred_at,
      call_site_location = context.call_site.source_location,
   }
   
   for i, param in ipairs(param_info) do
      tracking.parameter_sources[i] = {
         is_explicit = param.declared_type ~= nil,
         source_location = param.position,
         source_type = param.declared_type and "explicit_annotation" or "inference_context",
      }
   end
   
   return tracking
end

--------------------------------------------------------------------------------
-- Validation and Consistency Checking
--------------------------------------------------------------------------------

-- Validate consistency of mixed parameter resolution
function MixedParameterHandler:validate_mixed_parameter_consistency(
   resolved_params: {ParameterInfo},
   expected_type: FunctionType,
   context: InferenceContext
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   if not expected_type.args or not expected_type.args.tuple then
      return true, errors
   end
   
   local expected_params = expected_type.args.tuple
   
   -- Check parameter count consistency
   if #resolved_params ~= #expected_params then
      local error = contextual_typing.new_inference_error(
         "incompatible_signature",
         context.call_site.source_location,
         string.format(
            "Parameter count mismatch: function has %d parameters, expected %d",
            #resolved_params,
            #expected_params
         ),
         nil,
         expected_type
      )
      table.insert(errors, error)
      return false, errors
   end
   
   -- Check that each parameter has a resolved type
   for i, param in ipairs(resolved_params) do
      if not param.inferred_type and not param.declared_type then
         local error = contextual_typing.new_inference_error(
            "incompatible_signature",
            param.position,
            string.format("Parameter %d has no type information", i),
            nil,
            nil
         )
         table.insert(errors, error)
      end
   end
   
   return #errors == 0, errors
end

-- Check for conflicts between explicit and inferred types
function MixedParameterHandler:check_explicit_inferred_conflicts(
   resolved_params: {ParameterInfo},
   expected_type: FunctionType,
   context: InferenceContext
): {InferenceError}
   
   local errors: {InferenceError} = {}
   
   if not expected_type.args or not expected_type.args.tuple then
      return errors
   end
   
   local expected_params = expected_type.args.tuple
   
   for i, param in ipairs(resolved_params) do
      if param.declared_type and i <= #expected_params then
         local expected_param = expected_params[i]
         
         -- Check if explicit type conflicts with expected type
         if not self:types_are_identical(param.declared_type, expected_param) then
            local is_subtype, _ = self:check_subtype_relationship(
               param.declared_type, expected_param
            )
            
            if not is_subtype then
               local error = self:generate_mixed_parameter_error(
                  param, expected_param, i, param.position
               )
               table.insert(errors, error)
            end
         end
      end
   end
   
   return errors
end

--------------------------------------------------------------------------------
-- Module exports
--------------------------------------------------------------------------------

local mixed_parameter_handler = {
   MixedParameterHandler = MixedParameterHandler,
}

return mixed_parameter_handler
