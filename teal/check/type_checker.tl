local type attributes = require("teal.attributes")
local type Attribute = attributes.Attribute

local type errors = require("teal.errors")
local type Error = errors.Error
local type ErrorContext = errors.ErrorContext
local type WarningKind = errors.WarningKind
local type Where = errors.Where

local type types = require("teal.types")
local type Type = types.Type
local type FirstClassType = types.FirstClassType
local type NominalType = types.NominalType
local type InvalidType = types.InvalidType
local type ArrayType = types.ArrayType
local type EmptyTableType = types.EmptyTableType
local type FirstOrderType = types.FirstOrderType
local type GenericType = types.GenericType
local type TupleTableType = types.TupleTableType
local type TypeArgType = types.TypeArgType
local type TypeDeclType = types.TypeDeclType
local type UnresolvedEmptyTableValueType = types.UnresolvedEmptyTableValueType

local type variables = require("teal.variables")
local type Variable = variables.Variable

--------------------------------------------------------------------------------

local record type_checker
   enum VarUse
      "use"
      "lvalue"
      "use_type"
      "check_only"
   end

   enum ArgCheckMode
      "argument"
      "return"
      "self"
   end

   enum VarianceMode
      "covariant"
      "contravariant"
      "bivariant"
      "invariant"
   end

   interface TypeChecker
      feat_arity: boolean
      feat_lax: boolean

      add_implied_var: function(self, name: string, t: Type)
      add_error: function(self, w: Where, msg: string, t?: Type, ...:Type)
      add_errors_prefixing: function(self, w: Where, src: {Error}, prefix: string, dst?: {Error})
      add_warning: function(self, tag: WarningKind, w: Where, fmt: string, ...: any)
      apply_facts_from: function(self, w: Where, from?: Where)
      apply_generic: function(self, w: Where, g: GenericType, typeargs?: {Type}): FirstOrderType, {TypeArgType}
      arg_check: function(self, w: Where, all_errs: {Error}, a: Type, b: Type, v: VarianceMode, mode: ArgCheckMode, n?: integer): boolean
      arraytype_from_tuple: function(self, w: Where, tupletype: TupleTableType): ArrayType, {Error}
      assert_is_a: function(self, w: Where, t1: Type, t2: Type, ctx?: ErrorContext, name?: string): boolean
      begin_implied_scope: function(self)
      end_implied_scope: function(self)
      find_type: function(self, names: {string}): TypeDeclType, TypeArgType
      find_var_type: function(self, name: string, use?: VarUse): Type, Attribute, Type
      infer_at: function<T is Type>(self, w: Where, t: T): T
      infer_emptytable: function(self, emptytable: EmptyTableType, fresh_t: Type)
      infer_emptytable_from_unresolved_value: function(self, w: Where, u: UnresolvedEmptyTableValueType, values: Type)
      invalid_at: function(self, w: Where, msg: string, ...: Type): InvalidType
      is_a: function(self, Type, Type): boolean, {Error}
      is_pending_global: function(self, name: string): boolean
      resolve_nominal: function(self, t: NominalType): Type
      resolve_typevars: function(self, t: Type): FirstClassType, {Error}
      same_type: function(self, Type, Type): boolean, {Error}
      to_structural: function(self, t: Type): Type
      type_of_self: function(self, w: Where): Type, TypeDeclType

      find_var: function(self, name: string, use?: VarUse): Variable, integer, Attribute
   end
end

return type_checker
