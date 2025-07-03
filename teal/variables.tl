local type attributes = require("teal.attributes")
local type Attribute = attributes.Attribute

local type types = require("teal.types")
local type Type = types.Type
local type TypeDeclType = types.TypeDeclType
local type NominalType = types.NominalType
local type RecordLikeType = types.RecordLikeType

local type parser = require("teal.parser")
local type Node = parser.Node

local record variables
   enum Specialization
      "narrow"
      "narrowed_declaration"
      "localizing"
      "widen"
   end

   record Variable
      t: Type
      attribute: Attribute
      needs_compat: boolean
      specialized_from: Type
      is_specialized: Specialization
      declared_at: Node
      is_func_arg: boolean
      used_as_type: boolean
      aliasing: Variable
      implemented: {string:boolean}
      has_been_read_from: boolean
      has_been_written_to: boolean
   end

   record Scope
      vars: {string:Variable}
      labels: {string:Node}
      pending_labels: {string:{Node}}
      pending_nominals: {string:{NominalType}}
      pending_global_types: {string:boolean}
      narrows: {string:boolean}
      widens: {string:boolean}
      is_transaction: boolean
   end
end

local type Scope = variables.Scope
local type Variable = variables.Variable

function variables.has_var_been_used(var: Variable): boolean
   return var.has_been_read_from or var.has_been_written_to
end

local function close_nested_records(t: TypeDeclType)
   if t.closed then
      return
   end
   local tdef = t.def
   if tdef is RecordLikeType then
      t.closed = true
      for _, ft in pairs(tdef.fields) do
         if ft is TypeDeclType then
            close_nested_records(ft)
         end
      end
   end
end

function variables.close_types(scope: Scope)
   for _, var in pairs(scope.vars) do
      local t = var.t
      if t is TypeDeclType then
         close_nested_records(t)
      end
   end
end

return variables
