local types = require("teal.types")
local type Type = types.Type
local type GenericType = types.GenericType
local type NominalType = types.NominalType
local type RecordLikeType = types.RecordLikeType
local type TypeDeclType = types.TypeDeclType
local type StringType = types.StringType
local type TypeArgType = types.TypeArgType
local type TypeVarType = types.TypeVarType
local type ArrayType = types.ArrayType
local type MapType = types.MapType
local type UnionType = types.UnionType
local type FunctionType = types.FunctionType
local type EnumType = types.EnumType
local type Node = require("teal.ast").Node

local record luacats
   for_node: function(Node): string
   type_string: function(Type): string
end

local primitive_types: {string:boolean} = {
   any=true,
   boolean=true,
   integer=true,
   ["nil"]=true,
   number=true,
   string=true,
   thread=true,
   userdata=true,
}

local type_string_context: function(Type, boolean): string

local function nominal_type_string(nominal: NominalType): string
   local result = table.concat(nominal.names, ".")
   if not nominal.typevals or #nominal.typevals == 0 then
      return result
   end

   local type_values = {}
   for _, type_value in ipairs(nominal.typevals) do
      table.insert(type_values, type_string_context(type_value, false))
   end

   return result .. "<" .. table.concat(type_values, ", ") .. ">"
end

local function union_type_string(union: UnionType): string
   local union_types = {}
   for _, union_type in ipairs(union.types) do
      table.insert(union_types, type_string_context(union_type, false))
   end

   return table.concat(union_types, "|")
end

local function function_type_string(fn: FunctionType): string, boolean
   if fn.rets.is_va then
      return "function", false
   end

   local arguments = {}
   for i, argument in ipairs(fn.args.tuple) do
      if fn.args.is_va and i == #fn.args.tuple then
         table.insert(arguments, "...: " .. type_string_context(argument, false))
      else
         local argument_type = type_string_context(argument, false)
         if i > fn.min_arity then
            argument_type = argument_type .. "|nil"
         end
         table.insert(arguments, "arg" .. i .. ": " .. argument_type)
      end
   end

   local returns = {}
   for i, return_type in ipairs(fn.rets.tuple) do
      table.insert(returns, type_string_context(return_type, false) .. (fn.rets.is_va and i == #fn.rets.tuple and "..." or ""))
   end

   local return_annotation = #returns == 0 and "" or
                             #returns == 1 and ": " .. returns[1] or
                             ": (" .. table.concat(returns, ", ") .. ")"
   return "fun(" .. table.concat(arguments, ", ") .. ")" .. return_annotation, true
end

local function array_component_string(result: string, is_array_component: boolean, is_compound: boolean): string
   return is_array_component and is_compound and "(" .. result .. ")" or result
end

type_string_context = function(t: Type, is_array_component: boolean): string
   if not t then
      return "any"
   end

   if t.typename == "string" and (t as StringType).literal then
      return string.format("%q", (t as StringType).literal)
   end

   if t.typename == "nominal" then
      return nominal_type_string(t as NominalType)
   end

   if t.typename == "typearg" then
      local name = ((t as TypeArgType).typearg or "any"):gsub("@.*$", "")
      return name
   end

   if t.typename == "typevar" then
      local name = ((t as TypeVarType).typevar or "any"):gsub("@.*$", "")
      return name
   end

   if t.typename == "generic" then
      local generic = t as GenericType
      return generic.t.typename == "function" and "function" or type_string_context(generic.t, is_array_component)
   end

   if t.typename == "array" then
      return type_string_context((t as ArrayType).elements, true) .. "[]"
   end

   if t.typename == "map" then
      local map = t as MapType
      return "table<" .. type_string_context(map.keys, false) .. ", " .. type_string_context(map.values, false) .. ">"
   end

   if t.typename == "union" then
      return array_component_string(union_type_string(t as UnionType), is_array_component, true)
   end

   if t.typename == "function" then
      local result, is_compound = function_type_string(t as FunctionType)
      return array_component_string(result, is_array_component, is_compound)
   end

   return primitive_types[t.typename] and t.typename or "any"
end

local function type_string(t: Type): string
   return type_string_context(t, false)
end

local function function_annotations(node: Node): string
   local out = {}
   if node.typeargs and #node.typeargs > 0 then
      local a = {}
      for _, t in ipairs(node.typeargs) do
         local constraint = t.constraint and type_string(t.constraint)
         local name = t.typearg:gsub("@.*$", "")
         table.insert(a, name .. (constraint and constraint ~= "any" and ": " .. constraint or ""))
      end
      table.insert(out, "---@generic " .. table.concat(a, ", "))
   end

   for _, param in ipairs(node.args or {}) do
      if not param.is_self and param.argtype then
         table.insert(out, "---@param " .. (param.tk == "..." and "..." or param.tk .. (param.opt and "?" or "")) .. " " .. type_string(param.argtype))
      end
   end

   if node.rets then
      for i, r in ipairs(node.rets.tuple) do
         table.insert(out, "---@return " .. type_string(r) .. (node.rets.is_va and i == #node.rets.tuple and " ..." or ""))
      end
   end

   return #out > 0 and table.concat(out, "\n") .. "\n" or ""
end

local function field_name(name: string): string
   return name:match("^[%a_][%w_]*$") and name or "[" .. string.format("%q", name) .. "]"
end

local function generic_suffix(typeargs: {TypeArgType}): string
   if not typeargs or #typeargs == 0 then return "" end

   local names = {}
   for _, typearg in ipairs(typeargs) do
      local name = typearg.typearg:gsub("@.*$", "")
      table.insert(names, name)
   end

   return "<" .. table.concat(names, ", ") .. ">"
end

local function is_checker_method(field_type: Type): boolean
   return field_type.typename == "poly" or
          (field_type.typename == "function" and (field_type as FunctionType).is_record_function) or
          (field_type is GenericType and field_type.t.typename == "function")
end

local function record_annotation(name: string, suffix: string, record_type: RecordLikeType): string
   local annotations = { "---@class " .. name .. suffix }
   for _, field in ipairs(record_type.field_order or {}) do
      local field_type = record_type.fields[field]
      if not field_type is TypeDeclType and not is_checker_method(field_type) then
         table.insert(annotations, "---@field " .. field_name(field) .. " " .. type_string(field_type))
      end
   end

   return table.concat(annotations, "\n") .. "\n"
end

local function enum_annotation(name: string, suffix: string, enum_type: EnumType): string
   local values = {}
   for value in pairs(enum_type.enumset) do
      table.insert(values, string.format("%q", value))
   end

   table.sort(values)
   return "---@alias " .. name .. suffix .. " " .. table.concat(values, "|") .. "\n"
end

local function type_annotations(node: Node): string
   local nt = node.value and node.value.newtype

   if not nt then
      return ""
   end

   local name, def = node.var.tk, (nt as TypeDeclType).def
   local typeargs: {TypeArgType}

   if def is GenericType then
      typeargs, def = def.typeargs, def.t
   end

   if typeargs and #typeargs > 0 and not def is RecordLikeType then
      return ""
   end

   local suffix = generic_suffix(typeargs)
   if def is RecordLikeType then
      return record_annotation(name, suffix, def)
   end

   if def.typename == "enum" then
      return enum_annotation(name, suffix, def as EnumType)
   end

   return "---@alias " .. name .. suffix .. " " .. type_string(def) .. "\n"
end

local function declaration_annotation(node: Node): string
   if #node.vars ~= 1 or (node.kind == "global_declaration" and not node.exps) then
      return ""
   end

   local declaration_type = node.decltuple and node.decltuple.tuple[1]
   return declaration_type and "---@type " .. type_string(declaration_type) .. "\n" or ""
end

function luacats.for_node(node: Node): string
   if node.kind == "local_function" or node.kind == "global_function" or node.kind == "record_function" then
      return function_annotations(node)
   end

   if node.kind == "local_type" or node.kind == "global_type" then
      return type_annotations(node)
   end

   if node.kind == "local_declaration" or node.kind == "global_declaration" then
      return declaration_annotation(node)
   end

   return ""
end

luacats.type_string = type_string
return luacats
