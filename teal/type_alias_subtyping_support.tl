--------------------------------------------------------------------------------
-- Type Alias and Subtyping Support for Contextual Typing
-- 
-- This module provides integration between contextual typing and the existing
-- type system's type alias resolution and subtyping relationships.
--------------------------------------------------------------------------------

local type types = require("teal.types")
local type Type = types.Type
local type FunctionType = types.FunctionType
local type TypeDeclType = types.TypeDeclType
local type FirstClassType = types.FirstClassType

local type errors = require("teal.errors")
local type Where = errors.Where
local type Error = errors.Error

local type contextual_typing = require("teal.contextual_typing")
local type InferenceError = contextual_typing.InferenceError
local type InferenceContext = contextual_typing.InferenceContext

local type check = require("teal.check.check")
local type TypeChecker = check.TypeChecker

local type relations = require("teal.check.relations")

--------------------------------------------------------------------------------
-- Type Alias Resolution for Contextual Typing
--------------------------------------------------------------------------------

local record TypeAliasSubtypingSupport

   -- Reference to the type checker for accessing type relationships
   type_checker: TypeChecker
   
   -- Cache for resolved type aliases to improve performance
   alias_resolution_cache: {string: Type}
   
   -- Cache for subtype relationship checks
   subtype_cache: {string: boolean}
   
   -- Enable caching for performance optimization
   enable_caching: boolean
end

-- Create a new type alias and subtyping support instance
function TypeAliasSubtypingSupport:new(type_checker: TypeChecker): TypeAliasSubtypingSupport
   local support: TypeAliasSubtypingSupport = {
      type_checker = type_checker,
      alias_resolution_cache = {},
      subtype_cache = {},
      enable_caching = true,
   }
   return support
end

-- Resolve type aliases in expected types during contextual inference
function TypeAliasSubtypingSupport:resolve_type_aliases_in_expected_type(
   expected_type: Type,
   context: InferenceContext
): Type, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- If expected type is a type alias, resolve it
   if expected_type is TypeDeclType then
      local resolved_type, resolution_errors = self:resolve_type_alias(
         expected_type as TypeDeclType
      )
      
      if #resolution_errors > 0 then
         for _, error in ipairs(resolution_errors) do
            table.insert(errors, error)
         end
      end
      
      return resolved_type, errors
   end
   
   -- If expected type is a function type, resolve aliases in parameters and return type
   if expected_type is FunctionType then
      return self:resolve_aliases_in_function_type(expected_type as FunctionType)
   end
   
   -- For other types, return as-is
   return expected_type, errors
end

-- Resolve a single type alias to its underlying type
function TypeAliasSubtypingSupport:resolve_type_alias(
   alias_type: TypeDeclType
): Type, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Check cache first if caching is enabled
   if self.enable_caching then
      local cache_key = self:create_type_cache_key(alias_type)
      if self.alias_resolution_cache[cache_key] then
         return self.alias_resolution_cache[cache_key], errors
      end
   end
   
   -- If this is not an alias, return the type as-is
   if not alias_type.is_alias then
      return alias_type, errors
   end
   
   -- Get the underlying type definition
   local underlying_type = alias_type.def
   
   if not underlying_type then
      local error: InferenceError = {
         kind = "incompatible_signature",
         message = "Type alias has no underlying definition",
         location = alias_type as Where,
         suggested_fix = "Check that the type alias is properly defined",
         related_locations = {},
         inferred_type = alias_type,
         expected_type = nil,
      }
      table.insert(errors, error)
      return alias_type, errors
   end
   
   -- Recursively resolve if the underlying type is also an alias
   local resolved_type = underlying_type
   if underlying_type is TypeDeclType and (underlying_type as TypeDeclType).is_alias then
      resolved_type, errors = self:resolve_type_alias(underlying_type as TypeDeclType)
   end
   
   -- Cache the result if caching is enabled
   if self.enable_caching then
      local cache_key = self:create_type_cache_key(alias_type)
      self.alias_resolution_cache[cache_key] = resolved_type
   end
   
   return resolved_type, errors
end

-- Resolve type aliases within a function type's parameters and return type
function TypeAliasSubtypingSupport:resolve_aliases_in_function_type(
   func_type: FunctionType
): Type, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Create a new function type with resolved aliases
   local resolved_func_type: FunctionType = {
      typename = "function",
      typeid = func_type.typeid,
      inferred_at = func_type.inferred_at,
      needs_compat = func_type.needs_compat,
      is_method = func_type.is_method,
      maybe_method = func_type.maybe_method,
      is_record_function = func_type.is_record_function,
      min_arity = func_type.min_arity,
      args = func_type.args,
      rets = func_type.rets,
      macroexp = func_type.macroexp,
      special_function_handler = func_type.special_function_handler,
   }
   
   -- Resolve aliases in parameter types
   if func_type.args and func_type.args.tuple then
      local resolved_params: {Type} = {}
      
      for _, param_type in ipairs(func_type.args.tuple) do
         local resolved_param, param_errors = self:resolve_type_aliases_in_expected_type(
            param_type, nil
         )
         
         if #param_errors > 0 then
            for _, error in ipairs(param_errors) do
               table.insert(errors, error)
            end
         end
         
         table.insert(resolved_params, resolved_param)
      end
      
      -- Create new tuple type with resolved parameters
      resolved_func_type.args = {
         typename = "tuple",
         typeid = func_type.args.typeid,
         inferred_at = func_type.args.inferred_at,
         needs_compat = func_type.args.needs_compat,
         tuple = resolved_params,
      }
   end
   
   -- Resolve aliases in return type
   if func_type.rets then
      local resolved_rets, rets_errors = self:resolve_type_aliases_in_expected_type(
         func_type.rets, nil
      )
      
      if #rets_errors > 0 then
         for _, error in ipairs(rets_errors) do
            table.insert(errors, error)
         end
      end
      
      resolved_func_type.rets = resolved_rets
   end
   
   return resolved_func_type, errors
end

-- Check if a type is a subtype of another type during contextual inference
function TypeAliasSubtypingSupport:is_subtype_of(
   subtype: Type,
   supertype: Type,
   location: Where
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- First, resolve any type aliases
   local resolved_subtype, sub_errors = self:resolve_type_aliases_in_expected_type(subtype, nil)
   local resolved_supertype, super_errors = self:resolve_type_aliases_in_expected_type(supertype, nil)
   
   if #sub_errors > 0 or #super_errors > 0 then
      for _, error in ipairs(sub_errors) do
         table.insert(errors, error)
      end
      for _, error in ipairs(super_errors) do
         table.insert(errors, error)
      end
      return false, errors
   end
   
   -- Check cache first if caching is enabled
   if self.enable_caching then
      local cache_key = self:create_subtype_cache_key(resolved_subtype, resolved_supertype)
      if self.subtype_cache[cache_key] ~= nil then
         return self.subtype_cache[cache_key], errors
      end
   end
   
   -- Use the type checker's subtype relationship checking
   local is_subtype, subtype_errors = self.type_checker:is_a(resolved_subtype, resolved_supertype)
   
   if #subtype_errors > 0 then
      for _, error in ipairs(subtype_errors) do
         table.insert(errors, error)
      end
   end
   
   -- Cache the result if caching is enabled
   if self.enable_caching then
      local cache_key = self:create_subtype_cache_key(resolved_subtype, resolved_supertype)
      self.subtype_cache[cache_key] = is_subtype
   end
   
   return is_subtype, errors
end

-- Preserve subtyping relationships during contextual inference
function TypeAliasSubtypingSupport:preserve_subtyping_relationships(
   inferred_type: Type,
   expected_type: Type,
   location: Where
): boolean, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- The inferred type should be a subtype of the expected type
   local is_valid_subtype, subtype_errors = self:is_subtype_of(
      inferred_type, expected_type, location
   )
   
   if not is_valid_subtype then
      local error: InferenceError = {
         kind = "constraint_violation",
         message = string.format(
            "Inferred type is not a subtype of expected type: %s is not a subtype of %s",
            inferred_type.typename or "unknown",
            expected_type.typename or "unknown"
         ),
         location = location,
         suggested_fix = "Ensure the inferred type is compatible with the expected type",
         related_locations = {},
         inferred_type = inferred_type,
         expected_type = expected_type,
      }
      table.insert(errors, error)
      
      for _, error in ipairs(subtype_errors) do
         table.insert(errors, error)
      end
      
      return false, errors
   end
   
   return true, errors
end

-- Integrate type aliases and subtyping with existing type system components
function TypeAliasSubtypingSupport:integrate_with_type_system(
   inferred_type: Type,
   expected_type: Type,
   context: InferenceContext
): Type, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Step 1: Resolve type aliases in both types
   local resolved_inferred, inferred_errors = self:resolve_type_aliases_in_expected_type(
      inferred_type, context
   )
   local resolved_expected, expected_errors = self:resolve_type_aliases_in_expected_type(
      expected_type, context
   )
   
   if #inferred_errors > 0 or #expected_errors > 0 then
      for _, error in ipairs(inferred_errors) do
         table.insert(errors, error)
      end
      for _, error in ipairs(expected_errors) do
         table.insert(errors, error)
      end
   end
   
   -- Step 2: Check subtyping relationships are preserved
   local subtyping_valid, subtyping_errors = self:preserve_subtyping_relationships(
      resolved_inferred, resolved_expected, inferred_type as Where
   )
   
   if not subtyping_valid then
      for _, error in ipairs(subtyping_errors) do
         table.insert(errors, error)
      end
   end
   
   -- Step 3: Return the resolved inferred type
   return resolved_inferred, errors
end

-- Handle type alias resolution in mixed parameter scenarios
function TypeAliasSubtypingSupport:resolve_aliases_in_mixed_parameters(
   explicit_type: Type,
   inferred_type: Type,
   location: Where
): Type, {InferenceError}
   
   local errors: {InferenceError} = {}
   
   -- Resolve the explicit type first
   local resolved_explicit, explicit_errors = self:resolve_type_aliases_in_expected_type(
      explicit_type, nil
   )
   
   if #explicit_errors > 0 then
      for _, error in ipairs(explicit_errors) do
         table.insert(errors, error)
      end
   end
   
   -- Resolve the inferred type
   local resolved_inferred, inferred_errors = self:resolve_type_aliases_in_expected_type(
      inferred_type, nil
   )
   
   if #inferred_errors > 0 then
      for _, error in ipairs(inferred_errors) do
         table.insert(errors, error)
      end
   end
   
   -- Check that they are compatible
   local compatible, compat_errors = self:is_subtype_of(
      resolved_inferred, resolved_explicit, location
   )
   
   if not compatible then
      local error: InferenceError = {
         kind = "mixed_parameter_conflict",
         message = string.format(
            "Inferred type %s is not compatible with explicit type %s",
            resolved_inferred.typename or "unknown",
            resolved_explicit.typename or "unknown"
         ),
         location = location,
         suggested_fix = "Ensure explicit and inferred types are compatible",
         related_locations = {},
         inferred_type = resolved_inferred,
         expected_type = resolved_explicit,
      }
      table.insert(errors, error)
      
      for _, error in ipairs(compat_errors) do
         table.insert(errors, error)
      end
      
      return resolved_explicit, errors
   end
   
   -- Return the resolved explicit type (explicit takes precedence)
   return resolved_explicit, errors
end

-- Clear caches to free memory
function TypeAliasSubtypingSupport:clear_caches()
   self.alias_resolution_cache = {}
   self.subtype_cache = {}
end

-- Get cache statistics for performance monitoring
function TypeAliasSubtypingSupport:get_cache_stats(): {string: integer}
   return {
      alias_cache_size = self:count_table_entries(self.alias_resolution_cache),
      subtype_cache_size = self:count_table_entries(self.subtype_cache),
   }
end

--------------------------------------------------------------------------------
-- Helper Methods
--------------------------------------------------------------------------------

-- Create a cache key for type alias resolution
function TypeAliasSubtypingSupport:create_type_cache_key(typ: Type): string
   -- Use the type's typename and typeid as cache key
   local typename = typ.typename or "unknown"
   local typeid = typ.typeid or 0
   return typename .. "_" .. tostring(typeid)
end

-- Create a cache key for subtype relationship checks
function TypeAliasSubtypingSupport:create_subtype_cache_key(subtype: Type, supertype: Type): string
   local sub_key = self:create_type_cache_key(subtype)
   local super_key = self:create_type_cache_key(supertype)
   return sub_key .. "_subtype_of_" .. super_key
end

-- Count entries in a table
function TypeAliasSubtypingSupport:count_table_entries(tbl: {any: any}): integer
   local count = 0
   for _ in pairs(tbl) do
      count = count + 1
   end
   return count
end

return TypeAliasSubtypingSupport
