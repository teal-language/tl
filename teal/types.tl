local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG

local errors = require("teal.errors")
local type Error = errors.Error

local interface Node
end

local interface Where
   f: string
   y: integer
   x: integer
end

local enum TypeName
   "generic"
   "typedecl"
   "typevar"
   "typearg"
   "function"
   "array"
   "map"
   "tupletable"
   "record"
   "interface"
   "self"
   "enum"
   "boolean"
   "string"
   "nil"
   "thread"
   "userdata"
   "number"
   "integer"
   "union"
   "nominal"
   "emptytable"
   "literal_table_item"
   "unresolved_emptytable_value"
   "unresolved_typearg"
   "unresolvable_typearg"
   "circular_require"
   "boolean_context"
   "tuple"
   "poly"
   "any"
   "unknown"
   "invalid"
   "none"
   "*"
end

local simple_types: {TypeName:boolean} = {
   ["nil"] = true,
   ["any"] = true,
   ["number"] = true,
   ["string"] = true,
   ["thread"] = true,
   ["boolean"] = true,
   ["integer"] = true,
   ["self"] = true,
}

-- TODO double-check no_nested_types vs. simple_types
local no_nested_types: {string:boolean} = {
   ["string"] = true,
   ["number"] = true,
   ["integer"] = true,
   ["boolean"] = true,
   ["thread"] = true,
   ["any"] = true,
   ["enum"] = true,
   ["nil"] = true,
   ["unknown"] = true,
}

local table_types <total>: {TypeName:boolean} = {
   ["array"] = true,
   ["map"] = true,
   ["record"] = true,
   ["interface"] = true,
   ["self"] = true,
   ["emptytable"] = true,
   ["tupletable"] = true,

   ["generic"] = false,
   ["typedecl"] = false,
   ["typevar"] = false,
   ["typearg"] = false,
   ["function"] = false,
   ["enum"] = false,
   ["boolean"] = false,
   ["string"] = false,
   ["nil"] = false,
   ["thread"] = false,
   ["userdata"] = false,
   ["number"] = false,
   ["integer"] = false,
   ["union"] = false,
   ["nominal"] = false,
   ["literal_table_item"] = false,
   ["unresolved_emptytable_value"] = false,
   ["unresolved_typearg"] = false,
   ["unresolvable_typearg"] = false,
   ["circular_require"] = false,
   ["boolean_context"] = false,
   ["tuple"] = false,
   ["poly"] = false,
   ["any"] = false,
   ["unknown"] = false,
   ["invalid"] = false,
   ["none"] = false,
   ["*"] = false,
}

local interface Type
   is Where
   where self.typename

   typename: TypeName    -- discriminator
   typeid: integer       -- unique identifier
   inferred_at: Where    -- for error messages
   needs_compat: boolean -- for Lua compatibilty
end

local record GenericType
   is Type
   where self.typename == "generic"

   typeargs: {TypeArgType}
   t: FirstOrderType
   fresh: boolean
end

local interface FirstOrderType
   is Type
end

local type FirstClassType = GenericType | FirstOrderType

local interface StructuralType
   is FirstOrderType
end

local record StringType
   is StructuralType
   where self.typename == "string"

   literal: string
end

-- FIXME because of the module split, this needs to be global
global function is_numeric_type(t:Type): boolean
   return t.typename == "number" or t.typename == "integer"
end

local interface NumericType
   is StructuralType
   where is_numeric_type(self)
end

local record IntegerType
   is NumericType
   where self.typename == "integer"
end

local record BooleanType
   is StructuralType
   where self.typename == "boolean"
end

-- This is a special internal type, to be used only as the node.expected
-- type in boolean contexts such as `if _ then`. It behaves exactly like
-- boolean except that type variables do not infer to it.
local record BooleanContextType
   is StructuralType
   where self.typename == "boolean_context"
end

local record TypeDeclType
   is Type
   where self.typename == "typedecl"

   def: FirstClassType
   closed: boolean
   is_alias: boolean
   is_nested_alias: boolean
end

local record LiteralTableItemType
   is Type
   where self.typename == "literal_table_item"

   -- table items
   kname: string
   ktype: FirstClassType
   vtype: FirstClassType
end

local interface HasDeclName
   declname: string
end

local record NominalType
   is FirstOrderType
   where self.typename == "nominal"

   names: {string}
   typevals: {FirstClassType}
   found: TypeDeclType      -- type is found but typeargs are not resolved
   resolved: Type       -- type is found and typeargs are resolved
end

local record SelfType
   is FirstOrderType
   where self.typename == "self"

   -- to be used only in error reports, not for type resolution
   display_type: RecordLikeType
end

local interface ArrayLikeType
   is StructuralType
   where self.elements

   elements: Type
   consttypes: {Type}
   inferred_len: integer
end

local record ArrayType
   is ArrayLikeType
   where self.typename == "array"
end

local interface RecordLikeType
   is StructuralType, HasDeclName, ArrayLikeType
   where self.fields

   interface_list: {ArrayType | NominalType}
   interfaces_expanded: boolean
   fields: {string: Type}
   field_order: {string}
   meta_fields: {string: Type}
   meta_field_order: {string}
   is_userdata: boolean
end

local record RecordType
   is RecordLikeType
   where self.typename == "record"
end

local record InterfaceType
   is RecordLikeType
   where self.typename == "interface"
end

-- producing a new value of this type (not propagating)
-- must always produce a type error
local record InvalidType
   is Type
   where self.typename == "invalid"
end

-- To be used in lax mode only:
-- this represents non-annotated types in .lua files.
local record UnknownType
   is Type
   where self.typename == "unknown"
end

local record TupleType
   is FirstOrderType
   where self.typename == "tuple"

   is_va: boolean
   tuple: {Type}
end

local interface TypeArgType
   is Type
   where self.typename == "typearg"

   typearg: string
   constraint: Type
end

local record UnresolvedTypeArgType
   is TypeArgType
   where self.typename == "unresolved_typearg"
end

local record UnresolvableTypeArgType
   is Type
   where self.typename == "unresolvable_typearg"

   typearg: string
end

local record TypeVarType
   is FirstOrderType
   where self.typename == "typevar"

   typevar: string
   constraint: Type
end

local record MapType
   is StructuralType
   where self.typename == "map"

   keys: Type
   values: Type
end

local record NilType
   is StructuralType
   where self.typename == "nil"
end

local record EmptyTableType
   is Type
   where self.typename == "emptytable"

   is_global: boolean
   assigned_to: string
   keys: Type
end

local record UnresolvedEmptyTableValueType
   is Type
   where self.typename == "unresolved_emptytable_value"

   emptytable_type: EmptyTableType
end

local enum SpecialFunctionName
   "assert"
   "ipairs"
   "pairs"
   "pcall"
   "xpcall"
   "rawget"
   "require"
   "string.find"
   "string.format"
   "string.gmatch"
   "string.gsub"
   "string.match"
   "string.pack"
   "string.unpack"
end

local record FunctionType
   is StructuralType
   where self.typename == "function"

   is_method: boolean
   maybe_method: boolean
   is_record_function: boolean
   min_arity: integer
   args: TupleType
   rets: TupleType
   macroexp: Node
   special_function_handler: SpecialFunctionName -- special handling for format strings etc
end

local interface AggregateType
   is StructuralType
   where self.types

   types: {Type}
end

local record UnionType
   is AggregateType
   where self.typename == "union"
end

local record TupleTableType
   is AggregateType
   where self.typename == "tupletable"
end

-- Intersection types, currently restricted to polymorphic functions
-- defined inside records, representing polymorphic Lua APIs.
local record PolyType
   is AggregateType
   where self.typename == "poly"

   types: {FunctionType | GenericType}
end

local record EnumType
   is StructuralType, HasDeclName
   where self.typename == "enum"

   enumset: {string:boolean}
end

local show_type: function(Type, ? boolean, ? {Type:string}): string

local function is_unknown(t: Type): boolean
   return t.typename == "unknown"
       or t.typename == "unresolved_emptytable_value"
end

local function show_typevar(typevar: string, what: TypeName): string
   return TL_DEBUG
      and (what .. " " .. typevar)
      or typevar:gsub("@.*", "")
end

local function show_fields(t: RecordLikeType, show: function(Type):(string)): string
   if t.declname then
      return " " .. t.declname
   end

   local out: {string} = {}
   table.insert(out, " (")
   if t.elements then
      table.insert(out, "{" .. show(t.elements) .. "}")
   end
   local fs = {}
   for _, k in ipairs(t.field_order) do
      local v = t.fields[k]
      table.insert(fs, k .. ": " .. show(v))
   end
   table.insert(out, table.concat(fs, "; "))
   table.insert(out, ")")
   return table.concat(out)
end

local function show_type_base(t: Type, short: boolean, seen: {Type:string}): string
   -- FIXME this is a control for recursively built types, which should in principle not exist
   if seen[t] then
      return seen[t]
   end
   seen[t] = "..."

   local function show(typ: Type): string
      return show_type(typ, short, seen)
   end

   if t is NominalType then
      local ret: string
      if t.typevals then
         local out = { table.concat(t.names, "."), "<" }
         local vals: {string} = {}
         for _, v in ipairs(t.typevals) do
            table.insert(vals, show(v))
         end
         table.insert(out, table.concat(vals, ", "))
         table.insert(out, ">")
         ret = table.concat(out)
      else
         ret = table.concat(t.names, ".")
      end
      if TL_DEBUG then
         ret = "nominal " .. ret
      end
      return ret
   elseif t is SelfType then
      if t.display_type then
         local ret = show_type_base(t.display_type, short, seen)
         if TL_DEBUG then
            ret = "self " .. ret
         end
         return ret
      end
      return "self"
   elseif t is TupleType then
      local out: {string} = {}
      for _, v in ipairs(t.tuple) do
         table.insert(out, show(v))
      end
      local list = table.concat(out, ", ")
      if t.is_va then
         list = list .. "..."
      end
      if short then
         return list
      end
      return "(" .. list .. ")"
   elseif t is TupleTableType then
      local out: {string} = {}
      for _, v in ipairs(t.types) do
         table.insert(out, show(v))
      end
      return "{" .. table.concat(out, ", ") .. "}"
   elseif t is PolyType then
      local out: {string} = {}
      for _, v in ipairs(t.types) do
         table.insert(out, show(v))
      end
      return "polymorphic function (with types " .. table.concat(out, " and ") .. ")"
   elseif t is UnionType then
      local out: {string} = {}
      for _, v in ipairs(t.types) do
         table.insert(out, show(v))
      end
      return table.concat(out, " | ")
   elseif t is EmptyTableType then
      return "{}"
   elseif t is MapType then
      return "{" .. show(t.keys) .. " : " .. show(t.values) .. "}"
   elseif t is ArrayType then
      return "{" .. show(t.elements) .. "}"
   elseif t is EnumType then
      return t.declname or "enum"
   elseif t is RecordLikeType then
      return short and (t.declname or t.typename) or t.typename .. show_fields(t, show)
   elseif t is FunctionType then
      local out: {string} = {"function("}
      local args = {}
      for i, v in ipairs(t.args.tuple) do
         table.insert(args, ((i == #t.args.tuple and t.args.is_va) and "...: "
                            or (i > t.min_arity) and "? "
                            or "") .. show(v))
      end
      table.insert(out, table.concat(args, ", "))
      table.insert(out, ")")
      if t.rets.tuple and #t.rets.tuple > 0 then
         table.insert(out, ": ")
         local rets = {}
         if #t.rets.tuple > 1 then
            table.insert(out, "(")
         end
         for i, v in ipairs(t.rets.tuple) do
            table.insert(rets, show(v) .. (i == #t.rets.tuple and t.rets.is_va and "..." or ""))
         end
         table.insert(out, table.concat(rets, ", "))
         if #t.rets.tuple > 1 then
            table.insert(out, ")")
         end
      end
      return table.concat(out)
   elseif t is GenericType then
      local out: {string} = {}
      local name, rest: string, string
      local tt = t.t
      if tt is RecordType or tt is InterfaceType or tt is FunctionType then
         name, rest = show(tt):match("^(%a+)(.*)")
         table.insert(out, name)
      else
         rest = " " .. show(tt)
         table.insert(out, "generic")
      end
      table.insert(out, "<")
      local typeargs = {}
      for _, v in ipairs(t.typeargs) do
         table.insert(typeargs, show(v))
      end
      table.insert(out, table.concat(typeargs, ", "))
      table.insert(out, ">")
      table.insert(out, rest)
      return table.concat(out)
   elseif t.typename == "number"
       or t.typename == "integer"
       or t.typename == "boolean"
       or t.typename == "thread" then
      return t.typename
   elseif t is StringType then
      if short then
         return "string"
      else
         return t.typename ..
                (t.literal and string.format(" %q", t.literal) or "")
      end
   elseif t is TypeVarType then
      return show_typevar(t.typevar, "typevar")
   elseif t is TypeArgType then
      local out = show_typevar(t.typearg, "typearg")
      if t.constraint then
         out = out .. " is " .. show(t.constraint)
      end
      return out
   elseif t is UnresolvableTypeArgType then
      return show_typevar(t.typearg, "typearg") .. " (unresolved generic)"
   elseif is_unknown(t) then
      return "<unknown type>"
   elseif t is InvalidType then
      return "<invalid type>"
   elseif t.typename == "any" then
      return "<any type>"
   elseif t is NilType then
      return "nil"
   elseif t.typename == "boolean_context" then
      return "boolean"
   elseif t.typename == "none" then
      return ""
   elseif t is TypeDeclType then
      return (t.is_alias and "type alias to " or "type ") .. show(t.def)
   else
      return "<" .. t.typename .. ">" -- TODO add string.format("%p", t) with compat-5.4
   end
end

local function inferred_msg(t: Type, prefix?: string): string
   return " (" .. (prefix or "") .. "inferred at "..t.inferred_at.f..":"..t.inferred_at.y..":"..t.inferred_at.x..")"
end

show_type = function(t: Type, short?: boolean, seen?: {Type:string}): string
   seen = seen or {}
   if seen[t] then
      return seen[t]
   end
   local ret = show_type_base(t, short, seen)
   if t.inferred_at then
      ret = ret .. inferred_msg(t)
   end
   seen[t] = ret
   return ret
end

local type_mt: metatable<Type> = {
   __tostring = function(t: Type): string
      return show_type(t)
   end
}

local last_typeid = 0

local function new_typeid(): integer
   last_typeid = last_typeid + 1
   return last_typeid
end

local function a_type<T is Type>(w: Where, typename: TypeName, t: T): T
   t.typeid = new_typeid()
   t.f = w.f
   t.x = w.x
   t.y = w.y
   t.typename = typename
   do
      local ty: Type = t
      setmetatable(ty, type_mt)
   end
   return t
end

local function raw_type(f: string, y: integer, x: integer, typename: TypeName): Type
   local t: Type = setmetatable({}, type_mt)
   t.typeid = new_typeid()
   t.f = f
   t.x = x
   t.y = y
   t.typename = typename
   return t
end

local function shallow_copy_new_type<T is Type>(t: T): T
   local copy: {any:any} = {}
   for k, v in pairs(t as {any:any}) do
      copy[k] = v
   end
   copy.typeid = new_typeid()
   do
      local ty: Type = copy as T
      setmetatable(ty, type_mt)
   end
   return copy as T
end

local function edit_type(w: Where, t: Type, typename: TypeName): Type
   t.typeid = new_typeid()
   t.f = w.f
   t.x = w.x
   t.y = w.y
   t.typename = typename
   setmetatable(t, type_mt)
   return t
end

local function type_for_union(t: Type): string, Type
   if t is TypeDeclType then
      return type_for_union(t.def)
   elseif t is TupleType then
      return type_for_union(t.tuple[1]), t.tuple[1]
   elseif t is NominalType then
      local typedecl = t.found
      if not typedecl then
         return "invalid"
      end
      return type_for_union(typedecl)
   elseif t is RecordLikeType then
      if t.is_userdata then
         return "userdata", t
      end
      return "table", t
   elseif t is GenericType then
      return type_for_union(t.t)
   elseif table_types[t.typename] then
      return "table", t
   else
      return t.typename, t
   end
end

local record types
   type Type = Type
   type GenericType = GenericType
   type FirstOrderType = FirstOrderType
   type StructuralType = StructuralType
   type StringType = StringType
   type NumericType = NumericType
   type IntegerType = IntegerType
   type BooleanType = BooleanType
   type BooleanContextType = BooleanContextType
   type TypeDeclType = TypeDeclType
   type LiteralTableItemType = LiteralTableItemType
   type NominalType = NominalType
   type SelfType = SelfType
   type ArrayLikeType = ArrayLikeType
   type ArrayType = ArrayType
   type RecordLikeType = RecordLikeType
   type RecordType = RecordType
   type InterfaceType = InterfaceType
   type InvalidType = InvalidType
   type UnknownType = UnknownType
   type TupleType = TupleType
   type TypeArgType = TypeArgType
   type UnresolvedTypeArgType = UnresolvedTypeArgType
   type UnresolvableTypeArgType = UnresolvableTypeArgType
   type TypeVarType = TypeVarType
   type MapType = MapType
   type NilType = NilType
   type EmptyTableType = EmptyTableType
   type UnresolvedEmptyTableValueType = UnresolvedEmptyTableValueType
   type FunctionType = FunctionType
   type AggregateType = AggregateType
   type UnionType = UnionType
   type TupleTableType = TupleTableType
   type PolyType = PolyType
   type EnumType = EnumType
   type FirstClassType = FirstClassType
   type Node = Node
   type TypeName = TypeName
   type Where = Where
   type SpecialFunctionName = SpecialFunctionName

   simple_types: {TypeName:boolean}
   table_types: {TypeName:boolean}

   a_type: function<T is Type>(w: Where, typename: TypeName, t: T): T
   edit_type: function(w: Where, t: Type, typename: TypeName): Type
   is_unknown: function(t: Type): boolean
   inferred_msg: function(t: Type, prefix?: string): string
   raw_type: function(f: string, y: integer, x: integer, typename: TypeName): Type
   shallow_copy_new_type: function<T is Type>(t: T): T
   show_type: function(Type, ? boolean, ? {Type:string}): string
   show_typevar: function(typevar: string, what: TypeName): string
   show_type_base: function(t: Type, short: boolean, seen: {Type:string}): string

   type TypeFunction = function<S>(S, Type, function<T is Type>(t: T, all_same: boolean): T, boolean): Type, boolean
   type TypeFunctionMap<S> = {TypeName: TypeFunction<S>}
   map: function<S>(s: S, ty: Type, fns: TypeFunctionMap<S>): Type, {Error}
   globals_typeid: integer
end

types.globals_typeid = new_typeid()
types.simple_types = simple_types
types.table_types = table_types

types.a_type = a_type
types.edit_type = edit_type
types.is_unknown = is_unknown
types.inferred_msg = inferred_msg
types.raw_type = raw_type
types.shallow_copy_new_type = shallow_copy_new_type
types.show_type = show_type
types.show_typevar = show_typevar
types.show_type_base = show_type_base

function types.is_valid_union(typ: UnionType): boolean, string
   -- check for limitations in our union support
   -- due to codegen limitations (we only check with type() so far)
   local n_table_types = 0
   local n_table_is_types = 0
   local n_function_types = 0
   local n_userdata_types = 0
   local n_userdata_is_types = 0
   local n_string_enum = 0
   local has_primitive_string_type = false
   for _, t in ipairs(typ.types) do
      local ut, rt = type_for_union(t)
      if ut == "userdata" then -- must be tested before table_types
         assert(rt is RecordLikeType)
         if rt.meta_fields and rt.meta_fields["__is"] then
            n_userdata_is_types = n_userdata_is_types + 1
            if n_userdata_types > 0 then
               return false, "cannot mix userdata types with and without __is metamethod: %s"
            end
         else
            n_userdata_types = n_userdata_types + 1
            if n_userdata_types > 1 then
               return false, "cannot discriminate a union between multiple userdata types: %s"
            end
            if n_userdata_is_types > 0 then
               return false, "cannot mix userdata types with and without __is metamethod: %s"
            end
         end
      elseif ut == "table" then
         if rt is RecordLikeType and rt.meta_fields and rt.meta_fields["__is"] then
            n_table_is_types = n_table_is_types + 1
            if n_table_types > 0 then
               return false, "cannot mix table types with and without __is metamethod: %s"
            end
         else
            n_table_types = n_table_types + 1
            if n_table_types > 1 then
               return false, "cannot discriminate a union between multiple table types: %s"
            end
            if n_table_is_types > 0 then
               return false, "cannot mix table types with and without __is metamethod: %s"
            end
         end
      elseif ut == "function" then
         n_function_types = n_function_types + 1
         if n_function_types > 1 then
            return false, "cannot discriminate a union between multiple function types: %s"
         end
      elseif ut == "enum" or (ut == "string" and not has_primitive_string_type) then
         n_string_enum = n_string_enum + 1
         if n_string_enum > 1 then
            return false, "cannot discriminate a union between multiple string/enum types: %s"
         end
         if ut == "string" then
            has_primitive_string_type = true
         end
      elseif ut == "invalid" then
         return false, nil -- error message comes from invalid type
      end
   end
   return true
end

function types.error(msg: string, t1: Type, t2?: Type, t3?: Type): Error
   local s1, s2, s3: string, string, string
   if t1 is InvalidType then
      return nil
   end
   s1 = show_type(t1)
   if t2 then
      if t2 is InvalidType then
         return nil
      end
      s2 = show_type(t2)
   end
   if t3 then
      if t3 is InvalidType then
         return nil
      end
      s3 = show_type(t3)
   end
   msg = msg:format(s1, s2, s3)
   return {
      msg = msg,
      x = t1.x,
      y = t1.y,
      filename = t1.f,
   }
end

types.map = function<S>(self: S, ty: Type, fns: types.TypeFunctionMap<S>): Type, {Error}
   local errs: {Error}
   local seen: {Type:Type} = {}
   local resolve: function<T is Type>(t: T, all_same: boolean): T, boolean

   resolve = function<T is Type>(t: T, all_same: boolean): T, boolean
      local same = true

      -- avoid copies of types that do not contain type variables
      if no_nested_types[t.typename] or (t is NominalType and not t.typevals) then
         return t, all_same
      end

      if seen[t] then
         return seen[t], all_same
      end

      local orig_t = t
      local fn = fns[t.typename]
      if fn then
         local rt, is_resolved = fn(self, t, resolve)
         if rt ~= t then
            if is_resolved then
               seen[t] = rt
               return rt, false
            end
            return resolve(rt, false)
         end
      end

      local copy: Type = {}
      seen[orig_t] = copy

      setmetatable(copy, type_mt)
      copy.typename = t.typename
      copy.f = t.f
      copy.x = t.x
      copy.y = t.y

      if t is GenericType then
         assert(copy is GenericType)

         local ct = {}
         for i, tf in ipairs(t.typeargs) do
            ct[i], same = resolve(tf, same)
         end
         copy.typeargs = ct
         copy.t, same = resolve(t.t, same)
      elseif t is ArrayType then
         assert(copy is ArrayType)

         copy.elements, same = resolve(t.elements, same)
         -- inferred_len is not propagated
      elseif t is TypeArgType then
         assert(copy is TypeArgType)
         copy.typearg = t.typearg
         if t.constraint then
            copy.constraint, same = resolve(t.constraint, same)
         end
      elseif t is UnresolvableTypeArgType then
         assert(copy is UnresolvableTypeArgType)
         copy.typearg = t.typearg
      elseif t is UnresolvedEmptyTableValueType then
         assert(copy is UnresolvedEmptyTableValueType)
         copy.emptytable_type = t.emptytable_type
      elseif t is TypeVarType then
         assert(copy is TypeVarType)
         copy.typevar = t.typevar
         if t.constraint then
            copy.constraint, same = resolve(t.constraint, same)
         end
      elseif t is TypeDeclType then
         assert(copy is TypeDeclType)
         copy.def, same = resolve(t.def, same)
         copy.is_alias = t.is_alias
         copy.is_nested_alias = t.is_nested_alias
      elseif t is NominalType then
         assert(copy is NominalType)
         copy.names = t.names
         copy.typevals = {}
         for i, tf in ipairs(t.typevals) do
            copy.typevals[i], same = resolve(tf, same)
         end
         copy.found = t.found
      elseif t is FunctionType then
         assert(copy is FunctionType)
         copy.macroexp = t.macroexp
         copy.min_arity = t.min_arity
         copy.is_method = t.is_method
         copy.is_record_function = t.is_record_function
         copy.args, same = resolve(t.args, same) as (TupleType, boolean)
         copy.rets, same = resolve(t.rets, same) as (TupleType, boolean)
         copy.special_function_handler = t.special_function_handler
      elseif t is RecordLikeType then
         assert(copy is RecordType or copy is InterfaceType)
         copy.declname = t.declname

         -- checking array interface
         if t.elements then
            copy.elements, same = resolve(t.elements, same)
         end

         if t.interface_list then
            copy.interface_list = {}
            for i, v in ipairs(t.interface_list) do
               copy.interface_list[i], same = resolve(v, same)
            end
         end

         copy.is_userdata = t.is_userdata

         copy.fields = {}
         copy.field_order = {}
         for i, k in ipairs(t.field_order) do
            copy.field_order[i] = k
            copy.fields[k], same = resolve(t.fields[k], same)
         end

         if t.meta_fields then
            copy.meta_fields = {}
            copy.meta_field_order = {}
            for i, k in ipairs(t.meta_field_order) do
               copy.meta_field_order[i] = k
               copy.meta_fields[k], same = resolve(t.meta_fields[k], same)
            end
         end
      elseif t is MapType then
         assert(copy is MapType)
         copy.keys, same = resolve(t.keys, same)
         copy.values, same = resolve(t.values, same)
      elseif t is UnionType then
         assert(copy is UnionType)
         copy.types = {}
         for i, tf in ipairs(t.types) do
            copy.types[i], same = resolve(tf, same)
         end

         local _, err = types.is_valid_union(copy)
         if err then
            errs = errs or {}
            table.insert(errs, types.error(err, copy))
         end
      elseif t is PolyType then
         assert(copy is PolyType)
         copy.types = {}
         for i, tf in ipairs(t.types) do
            copy.types[i], same = resolve(tf, same)
         end
      elseif t is TupleTableType then
         assert(copy is TupleTableType)
         copy.inferred_at = t.inferred_at
         copy.types = {}
         for i, tf in ipairs(t.types) do
            copy.types[i], same = resolve(tf, same)
         end
      elseif t is TupleType then
         assert(copy is TupleType)
         copy.is_va = t.is_va
         copy.tuple = {}
         for i, tf in ipairs(t.tuple) do
            copy.tuple[i], same = resolve(tf, same)
         end
      elseif t is SelfType then
         assert(copy is SelfType)
         if t.display_type ~= nil then
            copy.display_type, same = resolve(t.display_type, same)
         end
      end

      copy.typeid = same and t.typeid or new_typeid()
      return copy, same and all_same
   end

   local copy = resolve(ty, true)
   if errs then
      return a_type(ty, "invalid", {} as InvalidType), errs
   end

   return copy
end

return types


