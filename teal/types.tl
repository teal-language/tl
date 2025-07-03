local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG

local type errors = require("teal.errors")
local type Where = errors.Where
local type Error = errors.Error

local type lexer = require("teal.lexer")
local type Comment = lexer.Comment

-- FIXME because of the module split, this needs to be global
global is_numeric_type: function(t: Type): boolean

local record types
   interface Node
   end

   enum TypeName
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

   interface Type
      is Where
      where self.typename

      typename: TypeName    -- discriminator
      typeid: integer       -- unique identifier
      inferred_at: Where    -- for error messages
      needs_compat: boolean -- for Lua compatibilty
   end

   record GenericType
      is Type
      where self.typename == "generic"

      typeargs: {TypeArgType}
      t: FirstOrderType
      fresh: boolean
   end

   interface FirstOrderType
      is Type
   end

   type FirstClassType = GenericType | FirstOrderType

   interface StructuralType
      is FirstOrderType
   end

   record StringType
      is StructuralType
      where self.typename == "string"

      literal: string
   end

   interface NumericType
      is StructuralType
      where is_numeric_type(self)
   end

   record IntegerType
      is NumericType
      where self.typename == "integer"
   end

   record BooleanType
      is StructuralType
      where self.typename == "boolean"
   end

   -- This is a special internal type, to be used only as the node.expected
   -- type in boolean contexts such as `if _ then`. It behaves exactly like
   -- boolean except that type variables do not infer to it.
   record BooleanContextType
      is StructuralType
      where self.typename == "boolean_context"
   end

   record TypeDeclType
      is Type
      where self.typename == "typedecl"

      def: FirstClassType
      closed: boolean
      is_alias: boolean
      is_nested_alias: boolean
   end

   record LiteralTableItemType
      is Type
      where self.typename == "literal_table_item"

      -- table items
      kname: string
      ktype: FirstClassType
      vtype: FirstClassType
   end

   interface HasDeclName
      declname: string
   end

   record NominalType
      is FirstOrderType
      where self.typename == "nominal"

      names: {string}
      typevals: {FirstClassType}
      found: TypeDeclType      -- type is found but typeargs are not resolved
      resolved: Type           -- type is found and typeargs are resolved
   end

   record SelfType
      is FirstOrderType
      where self.typename == "self"

      -- to be used only in error reports, not for type resolution
      display_type: RecordLikeType
   end

   interface ArrayLikeType
      is StructuralType
      where self.elements

      elements: Type
      consttypes: {Type}
      inferred_len: integer
   end

   record ArrayType
      is ArrayLikeType
      where self.typename == "array"
   end

   interface RecordLikeType
      is StructuralType, HasDeclName, ArrayLikeType
      where self.fields

      interface_list: {ArrayType | NominalType}
      interfaces_expanded: boolean
      fields: {string: Type}
      field_order: {string}
      field_comments: {string: {{Comment}}}
      meta_fields: {string: Type}
      meta_field_order: {string}
      meta_field_comments: {string: {{Comment}}}
      is_userdata: boolean
   end

   record RecordType
      is RecordLikeType
      where self.typename == "record"
   end

   record InterfaceType
      is RecordLikeType
      where self.typename == "interface"
   end

   -- producing a new value of this type (not propagating)
   -- must always produce a type error
   record InvalidType
      is Type
      where self.typename == "invalid"
   end

   -- To be used in lax mode only:
   -- this represents non-annotated types in .lua files.
   record UnknownType
      is Type
      where self.typename == "unknown"
   end

   record TupleType
      is FirstOrderType
      where self.typename == "tuple"

      is_va: boolean
      tuple: {Type}
   end

   interface TypeArgType
      is Type
      where self.typename == "typearg"

      typearg: string
      constraint: Type
   end

   record UnresolvedTypeArgType
      is TypeArgType
      where self.typename == "unresolved_typearg"
   end

   record UnresolvableTypeArgType
      is Type
      where self.typename == "unresolvable_typearg"

      typearg: string
   end

   record TypeVarType
      is FirstOrderType
      where self.typename == "typevar"

      typevar: string
      constraint: Type
   end

   record MapType
      is StructuralType
      where self.typename == "map"

      keys: Type
      values: Type
   end

   record NilType
      is StructuralType
      where self.typename == "nil"
   end

   record EmptyTableType
      is Type
      where self.typename == "emptytable"

      is_global: boolean
      assigned_to: string
      keys: Type
   end

   record UnresolvedEmptyTableValueType
      is Type
      where self.typename == "unresolved_emptytable_value"

      emptytable_type: EmptyTableType
   end

   enum SpecialFunctionName
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

   record FunctionType
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

   interface AggregateType
      is StructuralType
      where self.types

      types: {Type}
   end

   record UnionType
      is AggregateType
      where self.typename == "union"
   end

   record TupleTableType
      is AggregateType
      where self.typename == "tupletable"
   end

   -- Intersection types, currently restricted to polymorphic functions
   -- defined inside records, representing polymorphic Lua APIs.
   record PolyType
      is AggregateType
      where self.typename == "poly"

      types: {FunctionType | GenericType}
   end

   record EnumType
      is StructuralType, HasDeclName
      where self.typename == "enum"

      enumset: {string:boolean}
      value_comments: {string:{Comment}}
   end

   type InvalidOrTupleType = InvalidType | TupleType
   type InvalidOrTypeDeclType = InvalidType | TypeDeclType

   lua_primitives: {TypeName:string}
   simple_types: {TypeName:boolean}
   table_types: {TypeName:boolean}

   a_type: function<T is Type>(w: Where, typename: TypeName, t: T): T
   a_function: function(w: Where, t: FunctionType): FunctionType
   a_vararg: function(w: Where, t: {Type}): TupleType

   edit_type: function(w: Where, t: Type, typename: TypeName): Type
   ensure_not_method: function<T is Type>(t: T): T
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

local type Type = types.Type
local type GenericType = types.GenericType
local type StringType = types.StringType
local type TypeDeclType = types.TypeDeclType
local type NominalType = types.NominalType
local type SelfType = types.SelfType
local type ArrayType = types.ArrayType
local type RecordLikeType = types.RecordLikeType
local type RecordType = types.RecordType
local type InterfaceType = types.InterfaceType
local type InvalidType = types.InvalidType
local type TupleType = types.TupleType
local type TypeArgType = types.TypeArgType
local type UnresolvableTypeArgType = types.UnresolvableTypeArgType
local type TypeVarType = types.TypeVarType
local type MapType = types.MapType
local type NilType = types.NilType
local type EmptyTableType = types.EmptyTableType
local type UnresolvedEmptyTableValueType = types.UnresolvedEmptyTableValueType
local type FunctionType = types.FunctionType
local type UnionType = types.UnionType
local type TupleTableType = types.TupleTableType
local type PolyType = types.PolyType
local type EnumType = types.EnumType
local type TypeName = types.TypeName

global function is_numeric_type(t: Type): boolean
   return t.typename == "number" or t.typename == "integer"
end

types.lua_primitives = {
   ["function"] = "function",
   ["enum"] = "string",
   ["boolean"] = "boolean",
   ["string"] = "string",
   ["nil"] = "nil",
   ["number"] = "number",
   ["integer"] = "number",
   ["thread"] = "thread",
}

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

-- global state for unique internal identifiers
local fresh_typevar_ctr = 1
local fresh_typeid_ctr = 0

local function new_typeid(): integer
   fresh_typeid_ctr = fresh_typeid_ctr + 1
   return fresh_typeid_ctr
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

local function a_function(w: Where, t: FunctionType): FunctionType
   assert(t.min_arity)
   return a_type(w, "function", t)
end

local macroexp a_tuple(w: Where, t: {Type}): TupleType
   return a_type(w, "tuple", { tuple = t } as TupleType)
end

local function a_vararg(w: Where, t: {Type}): TupleType
   local typ = a_tuple(w, t)
   typ.is_va = true
   return typ
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

do
   function types.internal_typevar_ctr(): integer
      return fresh_typevar_ctr
   end

   local type ResolveFunction = function<T is Type>(t: T, all_same: boolean): T, boolean
   local fresh_typevar_fns: types.TypeFunctionMap<{TypeArgType}> = {
      ["typevar"] = function(typeargs: {TypeArgType}, t: TypeVarType, resolve: ResolveFunction<Type>): Type, boolean
         for _, ta in ipairs(typeargs) do
            if ta.typearg == t.typevar then
               return a_type(t, "typevar", {
                  typevar = (t.typevar:gsub("@.*", "")) .. "@" .. fresh_typevar_ctr,
                  constraint = t.constraint and resolve(t.constraint, false),
               } as TypeVarType), true
            end
         end
         return t, false
      end,
      ["typearg"] = function(typeargs: {TypeArgType}, t: TypeArgType, resolve: ResolveFunction<Type>): Type, boolean
         for _, ta in ipairs(typeargs) do
            if ta.typearg == t.typearg then
               return a_type(t, "typearg", {
                  typearg = (t.typearg:gsub("@.*", "")) .. "@" .. fresh_typevar_ctr,
                  constraint = t.constraint and resolve(t.constraint, false),
               } as TypeArgType), true
            end
         end
         return t, false
      end,
   }

   function types.fresh_typeargs(g: GenericType): GenericType | InvalidType, {Error}
      fresh_typevar_ctr = fresh_typevar_ctr + 1

      local newg, errs = types.map(g.typeargs, g, fresh_typevar_fns)
      if newg is InvalidType then
         return newg, errs
      end

      assert(newg is GenericType, "Internal Compiler Error: error creating fresh type variables")
      assert(newg ~= g)
      newg.fresh = true

      return newg
   end
end

-- If type is a tuple, return the first item.
-- If there is no first item, return a `NilType`.
-- If type is not a tuple, return the type itself.
-- This essentially ensures the resulting type
-- is unary (discarding an extras from multiple
-- return values or multiple assignments).
function types.untuple(t: Type): Type
   local rt = t
   if rt is TupleType then
      rt = rt.tuple[1]
   end
   if rt == nil then
      return a_type(t, "nil", {})
   end
   return rt
end

function types.unite(w: Where, typs: {Type}, flatten_constants?: boolean): Type
   if #typs == 1 then
      return typs[1]
   end

   local ts: {Type} = {}
   local stack: {Type} = {}

   -- Make things like number | number resolve to number
   local types_seen: {(integer|string):boolean} = {}
   -- but never add nil as a type in the union
   types_seen["nil"] = true

   local i = 1
   while typs[i] or stack[1] do
      local t: Type
      if stack[1] then
         t = table.remove(stack)
      else
         t = typs[i]
         i = i + 1
      end
      t = types.untuple(t)
      if t is UnionType then
         for _, s in ipairs(t.types) do
            table.insert(stack, s)
         end
      else
         if types.lua_primitives[t.typename] and (flatten_constants or (t is StringType and not t.literal)) then
            if not types_seen[t.typename] then
               types_seen[t.typename] = true
               table.insert(ts, t)
            end
         else
            local typeid = t.typeid
            if t is NominalType and t.found then
               typeid = t.found.typeid
            end
            if not types_seen[typeid] then
               types_seen[typeid] = true
               table.insert(ts, t)
            end
         end
      end
   end

   if types_seen["invalid"] then
      return a_type(w, "invalid", {})
   end

   if #ts == 1 then
      return ts[1]
   else
      return a_type(w, "union", { types = ts } as UnionType)
   end
end

function types.resolve_for_special_function(t: Type): FunctionType
   if t is PolyType then
      t = t.types[1]
   end
   if t is GenericType then
      t = t.t
   end
   if t is FunctionType then
      return t
   end
end

function types.drop_constant_value(t: Type): Type
   if t is StringType and t.literal then
      local ret = shallow_copy_new_type(t)
      ret.literal = nil
      return ret
   elseif t.needs_compat then
      local ret = shallow_copy_new_type(t)
      ret.needs_compat = nil
      return ret
   end
   return t
end

function types.type_at<T is Type>(w: Where, t: T): T
   t.x = w.x
   t.y = w.y
   return t
end

function types.wrap_generic_if_typeargs<T is Type>(typeargs: {TypeArgType}, t: T): T | GenericType
   if not typeargs then
      return t
   end

   assert(not t is TypeDeclType)

   local gt = a_type(t, "generic", { t = t } as GenericType)
   gt.typeargs = typeargs
   return gt
end

function types.show_arity(f: FunctionType): string
   local nfargs = #f.args.tuple
   if f.min_arity < nfargs then
      if f.min_arity > 0 then
         return "at least " .. f.min_arity .. (f.args.is_va and "" or " and at most " .. nfargs)
      else
         return (f.args.is_va and "any number" or "at most " .. nfargs)
      end
   else
      return tostring(nfargs or 0)
   end
end

function types.typedecl_to_nominal(w: Where, name: string, t: TypeDeclType, resolved?: Type): Type
   local typevals: {TypeVarType}
   local def = t.def
   if def is GenericType then
      typevals = {}
      for _, a in ipairs(def.typeargs) do
         table.insert(typevals, a_type(a, "typevar", {
            typevar = a.typearg,
            constraint = a.constraint,
         } as TypeVarType))
      end
   end
   local nom = a_type(w, "nominal", { names = { name } } as NominalType)
   nom.typevals = typevals
   nom.found = t
   nom.resolved = resolved
   return nom
end

local function ensure_not_method<T is Type>(t: T): T
   if t is GenericType then
      local tt = ensure_not_method(t.t)
      if tt ~= t.t then
         local gg = shallow_copy_new_type(t)
         gg.t = tt
         return gg
      end
   end

   if t is FunctionType and t.is_method then
      t = shallow_copy_new_type(t)
      (t as FunctionType).is_method = false
   end
   return t
end

function types.internal_get_state(): integer, integer
   return fresh_typeid_ctr, fresh_typevar_ctr
end

function types.internal_force_state(typeid_ctr: integer, typevar_ctr: integer)
   fresh_typeid_ctr = typeid_ctr
   fresh_typevar_ctr = typevar_ctr
end

types.globals_typeid = new_typeid()
types.simple_types = simple_types
types.table_types = table_types
types.a_type = a_type
types.a_function = a_function
types.a_vararg = a_vararg
types.edit_type = edit_type
types.ensure_not_method = ensure_not_method
types.is_unknown = is_unknown
types.inferred_msg = inferred_msg
types.raw_type = raw_type
types.shallow_copy_new_type = shallow_copy_new_type
types.show_type = show_type
types.show_typevar = show_typevar
types.show_type_base = show_type_base

return types
