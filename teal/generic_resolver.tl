--------------------------------------------------------------------------------
-- Generic Resolver Implementation
-- 
-- This module provides the base implementation of the GenericResolver interface
-- for resolving generic type parameters during contextual type inference.
--------------------------------------------------------------------------------

local generic_resolution = require("teal.generic_resolution")
local type GenericResolver = generic_resolution.GenericResolver
local type GenericParameter = generic_resolution.GenericParameter
local type GenericResolutionResult = generic_resolution.GenericResolutionResult
local type GenericResolutionState = generic_resolution.GenericResolutionState
local type ConstraintSolver = generic_resolution.ConstraintSolver

local type contextual_typing = require("teal.contextual_typing")
local type InferenceConstraint = contextual_typing.InferenceConstraint
local type ConstraintKind = contextual_typing.ConstraintKind
local type InferenceError = contextual_typing.InferenceError
local type CallSite = contextual_typing.CallSite

local type types = require("teal.types")
local type Type = types.Type
local type FunctionType = types.FunctionType
local type TypeVarType = types.TypeVarType
local type TupleType = types.TupleType

local type errors = require("teal.errors")
local type Where = errors.Where

--------------------------------------------------------------------------------
-- Base Generic Resolver Implementation
--------------------------------------------------------------------------------

local record BaseGenericResolver
   is GenericResolver

   -- Internal state for resolution process
   resolution_state: GenericResolutionState
   constraint_solver: ConstraintSolver
   max_resolution_depth: integer
   enable_performance_monitoring: boolean
end

-- Create a new base generic resolver instance
function BaseGenericResolver:new(): BaseGenericResolver
   local resolver: BaseGenericResolver = {
      resolution_state = {
         parameters = {},
         constraints = {},
         resolved_bindings = {},
         unresolved_parameters = {},
         resolution_order = {},
         constraint_graph = {},
      },
      constraint_solver = {
         constraints = {},
         bindings = {},
         resolution_history = {},
         max_iterations = 100,
      },
      max_resolution_depth = 10,
      enable_performance_monitoring = true,
   }
   return resolver
end

-- Resolve generic type parameters from a function type and expected type
function BaseGenericResolver:resolve_generic_parameters(
   generic_function: FunctionType,
   expected_type: FunctionType,
   call_context: CallSite
): GenericResolutionResult
   
   local result: GenericResolutionResult = {
      success = false,
      resolved_bindings = {},
      unresolved_parameters = {},
      errors = {},
      warnings = {},
      resolution_steps = {},
   }

   -- Extract generic parameters from the generic function
   local generic_params = self:extract_generic_parameters(generic_function)
   
   if #generic_params == 0 then
      -- No generic parameters to resolve
      result.success = true
      return result
   end

   table.insert(result.resolution_steps, "Extracted " .. #generic_params .. " generic parameters")

   -- Build constraints from function signature matching
   local constraints = self:build_constraints_from_signature_match(
      generic_function, expected_type, generic_params
   )

   table.insert(result.resolution_steps, "Built " .. #constraints .. " constraints from signature matching")

   -- Build constraint dependency graph
   local constraint_graph = self:build_constraint_graph(constraints)
   
   table.insert(result.resolution_steps, "Built constraint dependency graph")

   -- Apply existing generic context from call site
   local initial_bindings = {}
   if call_context.generic_context then
      for name, typ in pairs(call_context.generic_context) do
         initial_bindings[name] = typ
      end
   end

   table.insert(result.resolution_steps, "Applied " .. 
      (next(initial_bindings) and "existing generic context" or "no existing generic context"))

   -- Solve constraints to determine generic bindings
   local solved_bindings, solve_errors = self:solve_constraints(constraints, initial_bindings)

   if #solve_errors > 0 then
      for _, error in ipairs(solve_errors) do
         table.insert(result.errors, error)
      end
      table.insert(result.resolution_steps, "Constraint solving failed with " .. #solve_errors .. " errors")
   else
      table.insert(result.resolution_steps, "Constraint solving succeeded")
   end

   -- Check if all constraints are satisfied
   local all_satisfied, satisfaction_errors = self:check_constraint_satisfaction(
      constraints, solved_bindings
   )

   if not all_satisfied then
      for _, error in ipairs(satisfaction_errors) do
         table.insert(result.errors, error)
      end
      table.insert(result.resolution_steps, "Constraint satisfaction check failed")
   else
      table.insert(result.resolution_steps, "All constraints satisfied")
   end

   -- Validate generic consistency
   local consistent, consistency_errors = self:validate_generic_consistency(
      solved_bindings, constraints
   )

   if not consistent then
      for _, error in ipairs(consistency_errors) do
         table.insert(result.errors, error)
      end
      table.insert(result.resolution_steps, "Generic consistency validation failed")
   else
      table.insert(result.resolution_steps, "Generic consistency validated")
   end

   -- Identify unresolved parameters
   local unresolved: {string} = {}
   for _, param in ipairs(generic_params) do
      if not solved_bindings[param.name] then
         table.insert(unresolved, param.name)
      end
   end

   result.resolved_bindings = solved_bindings
   result.unresolved_parameters = unresolved
   result.success = #result.errors == 0 and #unresolved == 0

   if #unresolved > 0 then
      local warning: contextual_typing.InferenceWarning = {
         message = "Unresolved generic parameters: " .. table.concat(unresolved, ", "),
         location = generic_function as Where,
         confidence_level = 0.5
      }
      table.insert(result.warnings, warning)
   end

   return result
end

-- Extract generic parameters from a function type
function BaseGenericResolver:extract_generic_parameters(
   func_type: FunctionType
): {GenericParameter}
   local params: {GenericParameter} = {}

   -- Check if function has generic parameters
   if not func_type.generic_parameters then
      return params
   end

   -- Extract each generic parameter
   for _, type_var in ipairs(func_type.generic_parameters) do
      if generic_resolution.is_type_variable(type_var) then
         local var_name = generic_resolution.get_type_variable_name(type_var)
         if var_name then
            local param = generic_resolution.new_generic_parameter(var_name)
            table.insert(params, param)
         end
      end
   end

   return params
end

-- Build constraints from signature matching
function BaseGenericResolver:build_constraints_from_signature_match(
   generic_function: FunctionType,
   expected_type: FunctionType,
   generic_params: {GenericParameter}
): {InferenceConstraint}
   local constraints: {InferenceConstraint} = {}

   -- Match function arguments
   if generic_function.args and expected_type.args then
      local generic_args = generic_function.args.tuple or {}
      local expected_args = expected_type.args.tuple or {}

      for i, generic_arg in ipairs(generic_args) do
         local expected_arg = expected_args[i]
         if expected_arg then
            -- Create equality constraint for argument types
            local constraint = generic_resolution.new_constraint(
               "equality",
               generic_arg,
               expected_arg,
               generic_function as Where
            )
            constraint.priority = 10  -- High priority for argument matching
            table.insert(constraints, constraint)
         end
      end
   end

   -- Match return types
   if generic_function.rets and expected_type.rets then
      local constraint = generic_resolution.new_constraint(
         "equality",
         generic_function.rets,
         expected_type.rets,
         generic_function as Where
      )
      constraint.priority = 10  -- High priority for return type matching
      table.insert(constraints, constraint)
   end

   -- Add generic bounds constraints
   for _, param in ipairs(generic_params) do
      if #param.constraints > 0 then
         for _, bound_constraint in ipairs(param.constraints) do
            table.insert(constraints, bound_constraint)
         end
      end
   end

   return constraints
end

-- Build constraint graph for generic parameters
function BaseGenericResolver:build_constraint_graph(
   constraints: {InferenceConstraint}
): {string: {string}}
   local graph: {string: {string}} = {}

   for _, constraint in ipairs(constraints) do
      -- Extract type variable names from constraint
      local left_vars = generic_resolution.collect_type_variables(constraint.left_type)
      local right_vars = generic_resolution.collect_type_variables(constraint.right_type)

      -- Add edges for dependencies
      for _, left_var in ipairs(left_vars) do
         if not graph[left_var] then
            graph[left_var] = {}
         end
         for _, right_var in ipairs(right_vars) do
            table.insert(graph[left_var], right_var)
         end
      end

      for _, right_var in ipairs(right_vars) do
         if not graph[right_var] then
            graph[right_var] = {}
         end
         for _, left_var in ipairs(left_vars) do
            table.insert(graph[right_var], left_var)
         end
      end
   end

   return graph
end

-- Solve constraints to determine generic bindings
function BaseGenericResolver:solve_constraints(
   constraints: {InferenceConstraint},
   initial_bindings: {string: Type}
): {string: Type}, {InferenceError}
   local errors: {InferenceError} = {}
   local bindings = {}

   -- Copy initial bindings
   for k, v in pairs(initial_bindings) do
      bindings[k] = v
   end

   -- Sort constraints by priority (higher priority first)
   table.sort(constraints, function(a, b)
      return (a.priority or 0) > (b.priority or 0)
   end)

   -- Iteratively solve constraints
   local iteration = 0
   local max_iterations = self.constraint_solver.max_iterations

   while iteration < max_iterations do
      iteration = iteration + 1
      local progress = false

      for _, constraint in ipairs(constraints) do
         if constraint.kind == "equality" then
            -- Try to unify types
            local new_bindings, unify_errors = generic_resolution.unify_types(
               constraint.left_type, constraint.right_type, bindings
            )

            if #unify_errors == 0 then
               -- Check if we made progress
               for k, v in pairs(new_bindings) do
                  if not bindings[k] or bindings[k].typename ~= v.typename then
                     progress = true
                  end
                  bindings[k] = v
               end
            else
               for _, error in ipairs(unify_errors) do
                  table.insert(errors, error)
               end
            end

         elseif constraint.kind == "subtype" then
            -- Check subtype relationship
            local is_subtype, subtype_errors = generic_resolution.check_subtype_with_generics(
               constraint.left_type, constraint.right_type, bindings
            )

            if not is_subtype then
               for _, error in ipairs(subtype_errors) do
                  table.insert(errors, error)
               end
            end

         elseif constraint.kind == "generic_bound" then
            -- Handle generic bounds
            local is_valid, bound_errors = generic_resolution.check_subtype_with_generics(
               constraint.left_type, constraint.right_type, bindings
            )

            if not is_valid then
               for _, error in ipairs(bound_errors) do
                  table.insert(errors, error)
               end
            end
         end
      end

      -- If no progress was made, we're done
      if not progress then
         break
      end
   end

   if iteration >= max_iterations then
      local error = contextual_typing.new_inference_error(
         "constraint_violation",
         { y = 1, x = 1 },
         "Constraint solving exceeded maximum iterations",
         nil,
         nil
      )
      table.insert(errors, error)
   end

   return bindings, errors
end

-- Check if all generic constraints are satisfied
function BaseGenericResolver:check_constraint_satisfaction(
   constraints: {InferenceConstraint},
   bindings: {string: Type}
): boolean, {InferenceError}
   local errors: {InferenceError} = {}
   local satisfied_count = 0

   for _, constraint in ipairs(constraints) do
      local satisfied = false

      if constraint.kind == "equality" then
         local resolved_left = generic_resolution.apply_generic_bindings(constraint.left_type, bindings)
         local resolved_right = generic_resolution.apply_generic_bindings(constraint.right_type, bindings)

         satisfied = resolved_left.typename == resolved_right.typename

      elseif constraint.kind == "subtype" then
         local is_subtype, _ = generic_resolution.check_subtype_with_generics(
            constraint.left_type, constraint.right_type, bindings
         )
         satisfied = is_subtype

      elseif constraint.kind == "generic_bound" then
         local is_valid, _ = generic_resolution.check_subtype_with_generics(
            constraint.left_type, constraint.right_type, bindings
         )
         satisfied = is_valid
      end

      if satisfied then
         satisfied_count = satisfied_count + 1
      else
         local error = contextual_typing.new_inference_error(
            "constraint_violation",
            constraint.source_location,
            string.format("Constraint not satisfied: %s %s %s",
                         constraint.left_type.typename or "unknown",
                         constraint.kind,
                         constraint.right_type.typename or "unknown"),
            constraint.left_type,
            constraint.right_type
         )
         table.insert(errors, error)
      end
   end

   return #errors == 0, errors
end

-- Validate generic type consistency
function BaseGenericResolver:validate_generic_consistency(
   bindings: {string: Type},
   constraints: {InferenceConstraint}
): boolean, {InferenceError}
   local errors: {InferenceError} = {}

   -- Check for conflicting bindings
   local binding_conflicts: {string: {Type}} = {}

   for _, constraint in ipairs(constraints) do
      local left_vars = generic_resolution.collect_type_variables(constraint.left_type)
      local right_vars = generic_resolution.collect_type_variables(constraint.right_type)

      -- Check for conflicting bindings for the same variable
      for _, var in ipairs(left_vars) do
         if bindings[var] then
            if not binding_conflicts[var] then
               binding_conflicts[var] = {}
            end
            table.insert(binding_conflicts[var], bindings[var])
         end
      end

      for _, var in ipairs(right_vars) do
         if bindings[var] then
            if not binding_conflicts[var] then
               binding_conflicts[var] = {}
            end
            table.insert(binding_conflicts[var], bindings[var])
         end
      end
   end

   -- Check for inconsistencies
   for var, types_list in pairs(binding_conflicts) do
      if #types_list > 1 then
         -- Check if all types are the same
         local first_type = types_list[1]
         for i = 2, #types_list do
            if types_list[i].typename ~= first_type.typename then
               local error = contextual_typing.new_inference_error(
                  "constraint_violation",
                  first_type as Where,
                  string.format("Inconsistent bindings for type variable %s: %s vs %s",
                               var, first_type.typename or "unknown",
                               types_list[i].typename or "unknown"),
                  first_type,
                  types_list[i]
               )
               table.insert(errors, error)
            end
         end
      end
   end

   return #errors == 0, errors
end

-- Handle ambiguous generic resolution
function BaseGenericResolver:handle_ambiguous_resolution(
   candidates: {{string: Type}},
   constraints: {InferenceConstraint}
): {string: Type}, {InferenceError}
   local errors: {InferenceError} = {}

   if #candidates == 0 then
      local error = contextual_typing.new_inference_error(
         "ambiguous_inference",
         { y = 1, x = 1 },
         "No valid generic resolution candidates found",
         nil,
         nil
      )
      table.insert(errors, error)
      return {}, errors
   end

   if #candidates == 1 then
      -- Only one candidate, use it
      return candidates[1], errors
   end

   -- Multiple candidates - try to find the most specific one
   local best_candidate = candidates[1]
   local best_score = 0

   for _, candidate in ipairs(candidates) do
      local score = 0

      -- Score based on constraint satisfaction
      for _, constraint in ipairs(constraints) do
         local satisfied = false

         if constraint.kind == "equality" then
            local resolved_left = generic_resolution.apply_generic_bindings(constraint.left_type, candidate)
            local resolved_right = generic_resolution.apply_generic_bindings(constraint.right_type, candidate)
            satisfied = resolved_left.typename == resolved_right.typename
         end

         if satisfied then
            score = score + 1
         end
      end

      if score > best_score then
         best_score = score
         best_candidate = candidate
      end
   end

   -- If we still have ambiguity, report it
   if best_score < #constraints then
      local error = contextual_typing.new_inference_error(
         "ambiguous_inference",
         { y = 1, x = 1 },
         string.format("Ambiguous generic resolution: %d candidates satisfy %d/%d constraints",
                      #candidates, best_score, #constraints),
         nil,
         nil
      )
      error.suggested_fix = "Provide explicit type arguments to resolve ambiguity"
      table.insert(errors, error)
   end

   return best_candidate, errors
end

return {
   BaseGenericResolver = BaseGenericResolver,
}
