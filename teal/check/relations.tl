local errors = require("teal.errors")
local type Error = errors.Error

local types = require("teal.types")
local type Type = types.Type
local type GenericType = types.GenericType
local type StringType = types.StringType
local type BooleanContextType = types.BooleanContextType
local type TypeDeclType = types.TypeDeclType
local type NominalType = types.NominalType
local type SelfType = types.SelfType
local type ArrayLikeType = types.ArrayLikeType
local type ArrayType = types.ArrayType
local type RecordLikeType = types.RecordLikeType
local type RecordType = types.RecordType
local type InterfaceType = types.InterfaceType
local type InvalidType = types.InvalidType
local type TupleType = types.TupleType
local type TypeArgType = types.TypeArgType
local type TypeVarType = types.TypeVarType
local type MapType = types.MapType
local type EmptyTableType = types.EmptyTableType
local type UnresolvedEmptyTableValueType = types.UnresolvedEmptyTableValueType
local type FunctionType = types.FunctionType
local type AggregateType = types.AggregateType
local type UnionType = types.UnionType
local type TupleTableType = types.TupleTableType
local type PolyType = types.PolyType
local type EnumType = types.EnumType
local type TypeName = types.TypeName
local a_type = types.a_type
local show_arity = types.show_arity
local show_type = types.show_type
local untuple = types.untuple

local type type_checker = require("teal.check.type_checker")
local type TypeChecker = type_checker.TypeChecker

local util = require("teal.util")
local shallow_copy_table = util.shallow_copy_table

local record relations
   type CompareTypes = function(TypeChecker, Type, Type): boolean, {Error}
   type TypePriorities = {TypeName:integer}
   type TypeRelations = {TypeName:{TypeName:CompareTypes}}

   subtype_relations: TypeRelations
   eqtype_relations: TypeRelations
   type_priorities: TypePriorities

   compare_types: function(ck: TypeChecker, prios: TypePriorities, rels: TypeRelations, t1: Type, t2: Type): boolean, {Error}
end

local type CompareTypes = relations.CompareTypes
local type TypePriorities = relations.TypePriorities
local type TypeRelations = relations.TypeRelations

local function compare_true(_: TypeChecker, _: Type, _: Type): boolean, {Error}
   return true
end

local function compare_map(ck: TypeChecker, ak: Type, bk: Type, av: Type, bv: Type, no_hack?: boolean): boolean, {Error}
   local ok1, errs_k = ck:is_a(bk, ak)
   local ok2, errs_v = ck:is_a(av, bv)

   -- FIXME hack for {any:any}
   if bk.typename == "any" and not no_hack then
      ok1, errs_k = true, nil
   end
   if bv.typename == "any" and not no_hack then
      ok2, errs_v = true, nil
   end

   if ok1 and ok2 then
      return true
   end

   -- combine errs_k and errs_v, prefixing errors
   for i = 1, errs_k and #errs_k or 0 do
      errs_k[i].msg = "in map key: " .. errs_k[i].msg
   end
   for i = 1, errs_v and #errs_v or 0 do
      errs_v[i].msg = "in map value: " .. errs_v[i].msg
   end
   if errs_k and errs_v then
      for i = 1, #errs_v do
         table.insert(errs_k, errs_v[i])
      end
      return false, errs_k
   end
   return false, errs_k or errs_v
end

local function compare_or_infer_typevar(ck: TypeChecker, typevar: string, a: Type, b: Type, cmp: CompareTypes): boolean, {Error}
   -- assert((a == nil and b ~= nil) or (a ~= nil and b == nil))

   -- does the typevar currently match to a type?
   local vt, _, constraint = ck:find_var_type(typevar)
   if vt then
      -- If so, compare it to the other type
      return cmp(ck, a or vt, b or vt)
   else
      -- otherwise, infer it to the other type
      local other = a or b

      -- but check interface constraint first if present
      if constraint then
         if not ck:is_a(other, constraint) then
            return false, { types.error("given type %s does not satisfy %s constraint in type variable " .. types.show_typevar(typevar, "typevar"), other, constraint) }
         end

         if ck:same_type(other, constraint) then
            -- do not infer to some type as constraint right away,
            -- to give a chance to more specific inferences
            -- in other arguments/returns
            return true
         end
      end

      local r, errs = ck:resolve_typevars(other)
      if errs then
         return false, errs
      end

      -- do not infer a type variable to a boolean_context
      if r is BooleanContextType then
         return true
      end

      if r is TypeVarType and r.typevar == typevar then
         return true
      end
      ck:add_implied_var(typevar, r)
      return true
   end
end

local function subtype_record(ck: TypeChecker, a: RecordType, b: RecordLikeType): boolean, {Error}
   if a.elements and b.elements then
      if not ck:is_a(a.elements, b.elements) then
         return false, { errors.new("array parts have incompatible element types") }
      end
   end

   if a.is_userdata ~= b.is_userdata then
      return false, { errors.new(a.is_userdata and "userdata is not a record"
                                               or  "record is not a userdata") }
   end

   local errs: {Error} = {}
   for _, k in ipairs(a.field_order) do
      local ak = a.fields[k]
      local bk = b.fields[k]
      if bk then
         local ok, fielderrs = ck:is_a(ak, bk)
         if not ok then
            ck:add_errors_prefixing(nil, fielderrs, "record field doesn't match: " .. k .. ": ", errs)
         end
      elseif b.typename == "record" then
         table.insert(errs, errors.new("record field doesn't exist: " .. k))
      end
   end
   if #errs > 0 then
      for _, err in ipairs(errs) do
         err.msg = show_type(a) .. " is not a " .. show_type(b) .. ": " .. err.msg
      end
      return false, errs
   end

   return true
end

local function eqtype_record(ck: TypeChecker, a: RecordType, b: RecordType): boolean, {Error}
   -- checking array interface
   if (a.elements ~= nil) ~= (b.elements ~= nil) then
      return false, { errors.new("types do not have the same array interface") }
   end
   if a.elements then
      local ok, errs = ck:same_type(a.elements, b.elements)
      if not ok then
         return ok, errs
      end
   end

   local ok, errs = subtype_record(ck, a, b)
   if not ok then
      return ok, errs
   end
   ok, errs = subtype_record(ck, b, a)
   if not ok then
      return ok, errs
   end
   return true
end


local function compare_true_inferring_emptytable(ck: TypeChecker, a: Type, b: EmptyTableType): boolean, {Error}
   ck:infer_emptytable(b, ck:infer_at(b, a))
   return true
end

local function compare_true_inferring_emptytable_if_not_userdata(ck: TypeChecker, a: RecordLikeType, b: EmptyTableType): boolean, {Error}
   if a.is_userdata then
      return false, { types.error("{} cannot be used with userdata type %s", a) }
   end
   return compare_true_inferring_emptytable(ck, a, b)
end

local function is_in_interface_list(ck: TypeChecker, r: RecordLikeType, iface: Type): boolean
   if not r.interface_list then
      return false
   end

   for _, t in ipairs(r.interface_list) do
      if ck:is_a(t, iface) then
         return true
      end
   end

   return false
end

local function a_is_interface_b(ck: TypeChecker, a: NominalType, b: NominalType): boolean, {Error}
   if (not a.found) or (not b.found) then
      return false
   end

   local af = a.found.def
   if af is GenericType then
      af = ck:apply_generic(a, af, a.typevals)
   end

   if af is RecordLikeType then
      if is_in_interface_list(ck, af, b) then
         return true
      end
   end

   return ck:is_a(a, ck:resolve_nominal(b))
end

local are_same_nominals: CompareTypes
do
   local function are_same_unresolved_global_type(ck: TypeChecker, t1: NominalType, t2: NominalType): boolean
      -- FIXME shouldn't this be allowed only when `#t1.names == 1 and #t2.names == 1`?
      if t1.names[1] == t2.names[1] then
         if ck:is_pending_global(t1.names[1]) then
            return true
         end
      end
      return false
   end

   local function fail_nominals(ck: TypeChecker, t1: NominalType, t2: NominalType): boolean, {Error}
      local t1name = show_type(t1)
      local t2name = show_type(t2)
      if t1name == t2name then
         ck:resolve_nominal(t1)
         if t1.found then
            t1name = t1name .. " (defined in " .. t1.found.f .. ":" .. t1.found.y .. ")"
         end
         ck:resolve_nominal(t2)
         if t2.found then
            t2name = t2name .. " (defined in " .. t2.found.f .. ":" .. t2.found.y .. ")"
         end
      end
      return false, { errors.new(t1name .. " is not a " .. t2name) }
   end

   local function nominal_found_type(ck: TypeChecker, nom: NominalType): Type
      local typedecl = nom.found
      if not typedecl then
         typedecl = ck:find_type(nom.names)
         if not typedecl then
            return nil
         end
      end
      local t = typedecl.def

      if t is GenericType then
         t = t.t
      end

      return t
   end

   are_same_nominals = function(ck: TypeChecker, t1: NominalType, t2: NominalType): boolean, {Error}
      local t1f = nominal_found_type(ck, t1)
      local t2f = nominal_found_type(ck, t2)
      if (not t1f or not t2f) then
         if are_same_unresolved_global_type(ck, t1, t2) then
            return true
         end

         if not t1f then
            ck:add_error(t1, "unknown type %s", t1)
         end
         if not t2f then
            ck:add_error(t2, "unknown type %s", t2)
         end
         return false, {} -- errors were already produced
      end

      if t1f.typeid ~= t2f.typeid then
         return fail_nominals(ck, t1, t2)
      end

      if t1.typevals == nil and t2.typevals == nil then
         return true
      end

      if t1.typevals and t2.typevals and #t1.typevals == #t2.typevals then
         local errs = {}
         for i = 1, #t1.typevals do
            local _, typeval_errs = ck:same_type(t1.typevals[i], t2.typevals[i])
            ck:add_errors_prefixing(nil, typeval_errs, "type parameter <" .. show_type(t2.typevals[i]) .. ">: ", errs)
         end
         return errors.any(errs)
      end

      -- FIXME what if presence and arities of typevals don't match?...
      return true
   end
end

local function has_all_types_of(ck: TypeChecker, t1s: {Type}, t2s: {Type}): boolean
   for _, t1 in ipairs(t1s) do
      local found = false
      for _, t2 in ipairs(t2s) do
         if ck:same_type(t2, t1) then
            found = true
            break
         end
      end
      if not found then
         return false
      end
   end
   return true
end

-- emptytable rules are the same in eqtype_relations and subtype_relations
local emptytable_relations: {TypeName:CompareTypes} = {
   ["emptytable"] = compare_true,
   ["array"] = compare_true,
   ["map"] = compare_true,
   ["tupletable"] = compare_true,
   ["interface"] = function(_ck: TypeChecker, _a: Type, b: InterfaceType): boolean, {Error}
      return not b.is_userdata
   end,
   ["record"] = function(_ck: TypeChecker, _a: Type, b: RecordType): boolean, {Error}
      return not b.is_userdata
   end,
}

relations.eqtype_relations = {
   ["typevar"] = {
      ["typevar"] = function(ck: TypeChecker, a: TypeVarType, b: TypeVarType): boolean, {Error}
         if a.typevar == b.typevar then
            return true
         end

         return compare_or_infer_typevar(ck, b.typevar, a, nil, ck.same_type)
      end,
      ["*"] = function(ck: TypeChecker, a: TypeVarType, b: Type): boolean, {Error}
         return compare_or_infer_typevar(ck, a.typevar, nil, b, ck.same_type)
      end,
   },
   ["emptytable"] = emptytable_relations,
   ["tupletable"] = {
      ["tupletable"] = function(ck: TypeChecker, a: TupleTableType, b: TupleTableType): boolean, {Error}
         for i = 1, math.min(#a.types, #b.types) do
            if not ck:same_type(a.types[i], b.types[i]) then
               return false, { types.error("in tuple entry " .. tostring(i) .. ": got %s, expected %s", a.types[i], b.types[i]) }
            end
         end
         if #a.types ~= #b.types then
            return false, { types.error("tuples have different size", a, b) }
         end
         return true
      end,
      ["emptytable"] = compare_true_inferring_emptytable,
   },
   ["array"] = {
      ["array"] = function(ck: TypeChecker, a: ArrayType, b: ArrayType): boolean, {Error}
         return ck:same_type(a.elements, b.elements)
      end,
      ["emptytable"] = compare_true_inferring_emptytable,
   },
   ["map"] = {
      ["map"] = function(ck: TypeChecker, a: MapType, b: MapType): boolean, {Error}
         return compare_map(ck, a.keys, b.keys, a.values, b.values, true)
      end,
      ["emptytable"] = compare_true_inferring_emptytable,
   },
   ["union"] = {
      ["union"] = function(ck: TypeChecker, a: UnionType, b: UnionType): boolean, {Error}
         return (has_all_types_of(ck, a.types, b.types)
             and has_all_types_of(ck, b.types, a.types))
      end,
   },
   ["nominal"] = {
      ["nominal"] = are_same_nominals,
      ["typedecl"] = function(ck: TypeChecker, a: NominalType, b: TypeDeclType): boolean, {Error}
         -- used when resolving type parameters
         return ck:same_type(ck:resolve_nominal(a), b.def)
      end,
   },
   ["record"] = {
      ["record"] = eqtype_record,
      ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
   },
   ["interface"] = {
      ["interface"] = function(_ck:TypeChecker, a: InterfaceType, b: InterfaceType): boolean, {Error}
         return a.typeid == b.typeid
      end,
      ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
   },
   ["function"] = {
      ["function"] = function(ck:TypeChecker, a: FunctionType, b: FunctionType): boolean, {Error}
         local argdelta = a.is_method and 1 or 0
         local naargs, nbargs = #a.args.tuple, #b.args.tuple
         if naargs ~= nbargs then
            if (not not a.is_method) ~= (not not b.is_method) then
               return false, { errors.new("different number of input arguments: method and non-method are not the same type") }
            end
            return false, { errors.new("different number of input arguments: got " .. naargs - argdelta .. ", expected " .. nbargs - argdelta) }
         end
         local narets, nbrets = #a.rets.tuple, #b.rets.tuple
         if narets ~= nbrets then
            return false, { errors.new("different number of return values: got " .. narets .. ", expected " .. nbrets) }
         end
         local errs = {}
         for i = 1, naargs do
            ck:arg_check(a, errs, a.args.tuple[i], b.args.tuple[i], "invariant", "argument", i - argdelta)
         end
         for i = 1, narets do
            ck:arg_check(a, errs, a.rets.tuple[i], b.rets.tuple[i], "invariant", "return", i)
         end
         return errors.any(errs)
      end,
   },
   ["self"] = {
      ["self"] = function(_ck: TypeChecker, _a: SelfType, _b: SelfType): boolean, {Error}
         return true
      end,
      ["*"] = function(ck: TypeChecker, a: SelfType, b: Type): boolean, {Error}
         return ck:same_type(ck:type_of_self(a), b)
      end,
   },
   ["boolean_context"] = {
      ["boolean"] = compare_true,
   },
   ["generic"] = {
      ["generic"] = function(ck: TypeChecker, a: GenericType, b: GenericType): boolean, {Error}
         if #a.typeargs ~= #b.typeargs then
            return false
         end
         for i = 1, #a.typeargs do
            if not ck:same_type(a.typeargs[i], b.typeargs[i]) then
               return false
            end
         end
         return ck:same_type(a.t, b.t)
      end,
   },
   ["*"] = {
      ["boolean_context"] = compare_true,
      ["self"] = function(ck: TypeChecker, a: Type, b: SelfType): boolean, {Error}
         return ck:same_type(a, (ck:type_of_self(b)))
      end,
      ["typevar"] = function(ck: TypeChecker, a: Type, b: TypeVarType): boolean, {Error}
         return compare_or_infer_typevar(ck, b.typevar, a, nil, ck.same_type)
      end,
   },
}

-- ∃ x ∈ xs. t <: x
local function exists_supertype_in(ck: TypeChecker, t: Type, xs: AggregateType): Type
   for _, x in ipairs(xs.types) do
      if ck:is_a(t, x) then
         return x
      end
   end
end

-- ∀ x ∈ xs, x <: t
local function forall_are_subtype_of(ck: TypeChecker, xs: AggregateType, t: Type): boolean
   for _, x in ipairs(xs.types) do
      if not ck:is_a(x, t) then
         return false
      end
   end
   return true
end

local function subtype_nominal(ck: TypeChecker, a: Type, b: Type): boolean, {Error}
   local ra = a is NominalType and ck:resolve_nominal(a) or a
   local rb = b is NominalType and ck:resolve_nominal(b) or b
   local ok, errs = ck:is_a(ra, rb)
   if errs and #errs == 1 and errs[1].msg:match("^got ") then
      return false -- translate to got-expected error with unresolved types
   end
   return ok, errs
end

local function subtype_array(ck: TypeChecker, a: ArrayLikeType, b: ArrayLikeType): boolean, {Error}
   if (not a.elements) or (not ck:is_a(a.elements, b.elements)) then
      return false
   end
   if a.consttypes and #a.consttypes > 1 then
      -- constant array, check elements (useful for array of enums)
      for _, e in ipairs(a.consttypes) do
         if not ck:is_a(e, b.elements) then
            return false, { types.error("%s is not a member of %s", e, b.elements) }
         end
      end
   end
   return true
end

relations.subtype_relations = {
   ["nil"] = {
      ["*"] = compare_true,
   },
   ["tuple"] = {
      ["tuple"] = function(ck: TypeChecker, a: TupleType, b: TupleType): boolean, {Error}  -- ∀ a[i] ∈ a, b[i] ∈ b. a[i] <: b[i]
         local at, bt = a.tuple, b.tuple                                  -- ──────────────────────────────────
         if #at ~= #bt then                                               --        a tuple <: b tuple
            return false
         end
         for i = 1, #at do
            if not ck:is_a(at[i], bt[i]) then
               return false
            end
         end
         return true
      end,
      ["*"] = function(ck: TypeChecker, a: Type, b: Type): boolean, {Error}
         return ck:is_a(untuple(a), b)
      end,
   },
   ["typevar"] = {
      ["typevar"] = function(ck: TypeChecker, a: TypeVarType, b: TypeVarType): boolean, {Error}
         if a.typevar == b.typevar then
            return true
         end

         return compare_or_infer_typevar(ck, b.typevar, a, nil, ck.is_a)
      end,
      ["*"] = function(ck: TypeChecker, a: TypeVarType, b: Type): boolean, {Error}
         return compare_or_infer_typevar(ck, a.typevar, nil, b, ck.is_a)
      end,
   },
   ["union"] = {
      ["nominal"] = function(ck: TypeChecker, a: UnionType, b: NominalType): boolean, {Error}
         -- match unions structurally
         local rb = ck:resolve_nominal(b)
         if rb is UnionType then
            return ck:is_a(a, rb)
         end

         return forall_are_subtype_of(ck, a, b)
      end,
      ["union"] = function(ck: TypeChecker, a: UnionType, b: UnionType): boolean, {Error} -- ∀ t ∈ a. ∃ u ∈ b. t <: u
         local used = {}                                                 -- ────────────────────────
         for _, t in ipairs(a.types) do                                  --    a union <: b union
            ck:begin_implied_scope()
            local u = exists_supertype_in(ck, t, b)
            ck:end_implied_scope() -- don't preserve failed inferences
            if not u then
               return false
            end
            if not used[u] then -- FIXME the order of declared union items affects inference behavior
               used[u] = t
            end
         end
         for u, t in pairs(used) do
            ck:is_a(t, u) -- preserve valid inferences
         end
         return true
      end,
      ["*"] = forall_are_subtype_of as CompareTypes,
   },
   ["poly"] = {
      -- ∃ t ∈ a, t <: b
      -- ───────────────
      --   a poly <: b
      ["*"] = function(ck: TypeChecker, a: PolyType, b: Type): boolean, {Error}
         if exists_supertype_in(ck, b, a) then
            return true
         end
         return false, { errors.new("cannot match against any alternatives of the polymorphic type") }
      end,
   },
   ["nominal"] = {
      ["nominal"] = function(ck: TypeChecker, a: NominalType, b: NominalType): boolean, {Error}
         local ok, errs = are_same_nominals(ck, a, b)
         if ok then
            return true
         end

         local ra = ck:resolve_nominal(a)
         local rb = ck:resolve_nominal(b)

         -- match unions structurally
         local union_a = ra is UnionType
         local union_b = rb is UnionType
         if union_a or union_b then
            return ck:is_a(union_a and ra or a, union_b and rb or b)
         end

         -- match interface subtyping
         if rb is InterfaceType then
            return a_is_interface_b(ck, a, b)
         end

         -- all other types nominally
         return ok, errs
      end,
      ["union"] = function(ck: TypeChecker, a: NominalType, b: UnionType): boolean, {Error}
         -- match unions structurally
         local ra = ck:resolve_nominal(a)
         if ra is UnionType then
            return ck:is_a(ra, b)
         end

         return not not exists_supertype_in(ck, a, b)
      end,
      ["*"] = subtype_nominal,
   },
   ["enum"] = {
      ["string"] = compare_true,
   },
   ["string"] = {
      ["enum"] = function(_ck: TypeChecker, a: StringType, b: EnumType): boolean, {Error}
         if not a.literal then
            return false, { types.error("%s is not a %s", a, b) }
         end

         if b.enumset[a.literal] then
            return true
         end

         return false, { types.error("%s is not a member of %s", a, b) }
      end,
   },
   ["integer"] = {
      ["number"] = compare_true,
   },
   ["interface"] = {
      ["interface"] = function(ck: TypeChecker, a: InterfaceType, b: InterfaceType): boolean, {Error}
         if is_in_interface_list(ck, a, b) then
            return true
         end
         return ck:same_type(a, b)
      end,
      ["array"] = subtype_array,
      ["tupletable"] = function(ck: TypeChecker, a: Type, b: Type): boolean, {Error}
         return relations.subtype_relations["record"]["tupletable"](ck, a, b)
      end,
      ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
   },
   ["emptytable"] = emptytable_relations,
   ["tupletable"] = {
      ["tupletable"] = function(ck: TypeChecker, a: TupleTableType, b: TupleTableType): boolean, {Error}
         for i = 1, math.min(#a.types, #b.types) do
            if not ck:is_a(a.types[i], b.types[i]) then
               return false, { types.error("in tuple entry "
                  .. tostring(i) .. ": got %s, expected %s",
                  a.types[i], b.types[i]) }
            end
         end
         if #a.types > #b.types then
            return false, { types.error("tuple %s is too big for tuple %s", a, b) }
         end
         return true
      end,
      ["record"] = function(ck: TypeChecker, a: Type, b: RecordType): boolean, {Error}
         if b.elements then
            return relations.subtype_relations["tupletable"]["array"](ck, a, b)
         end
      end,
      ["array"] = function(ck: TypeChecker, a: TupleTableType, b: ArrayType): boolean, {Error}
         if b.inferred_len and b.inferred_len > #a.types then
            return false, { errors.new("incompatible length, expected maximum length of " .. tostring(#a.types) .. ", got " .. tostring(b.inferred_len)) }
         end
         local aa, err = ck:arraytype_from_tuple(a.inferred_at or a, a)
         if not aa then
            return false, err
         end
         if not ck:is_a(aa, b) then
            return false, { types.error("got %s (from %s), expected %s", aa, a, b) }
         end
         return true
      end,
      ["map"] = function(ck: TypeChecker, a: TupleTableType, b: MapType): boolean, {Error}
         local aa = ck:arraytype_from_tuple(a.inferred_at or a, a)
         if not aa then
            return false, { types.error("Unable to convert tuple %s to map", a) }
         end

         return compare_map(ck, a_type(a, "integer", {}), b.keys, aa.elements, b.values)
      end,
      ["emptytable"] = compare_true_inferring_emptytable,
   },
   ["record"] = {
      ["record"] = subtype_record,
      ["interface"] = function(ck: TypeChecker, a: RecordType, b: InterfaceType): boolean, {Error}
         if is_in_interface_list(ck, a, b) then
            return true
         end
         if not a.declname then
            -- match inferred table (anonymous record) structurally to interface
            return subtype_record(ck, a, b)
         end
      end,
      ["array"] = subtype_array,
      ["map"] = function(ck: TypeChecker, a: RecordType, b: MapType): boolean, {Error}
         if not ck:is_a(b.keys, a_type(b, "string", {})) then
            return false, { errors.new("can't match a record to a map with non-string keys") }
         end

         for _, k in ipairs(a.field_order) do
            local bk = b.keys
            if bk is EnumType and not bk.enumset[k] then
               return false, { errors.new("key is not an enum value: " .. k) }
            end
            if not ck:is_a(a.fields[k], b.values) then
               return false, { errors.new("record is not a valid map; not all fields have the same type") }
            end
         end

         return true
      end,
      ["tupletable"] = function(ck: TypeChecker, a: RecordType, b: Type): boolean, {Error}
         if a.elements then
            return relations.subtype_relations["array"]["tupletable"](ck, a, b)
         end
      end,
      ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
   },
   ["array"] = {
      ["array"] = subtype_array,
      ["record"] = function(ck: TypeChecker, a: ArrayType, b: RecordType): boolean, {Error}
         if b.elements then
            return subtype_array(ck, a, b)
         end
      end,
      ["map"] = function(ck: TypeChecker, a: ArrayType, b: MapType): boolean, {Error}
         return compare_map(ck, a_type(a, "integer", {}), b.keys, a.elements, b.values)
      end,
      ["tupletable"] = function(ck: TypeChecker, a: ArrayType, b: TupleTableType): boolean, {Error}
         local alen = a.inferred_len or 0
         if alen > #b.types then
            return false, { errors.new("incompatible length, expected maximum length of " .. tostring(#b.types) .. ", got " .. tostring(alen)) }
         end

         -- for array literals (which is the only case where inferred_len is defined),
         -- only check the entries that are present
         for i = 1, (alen > 0) and alen or #b.types do
            if not ck:is_a(a.elements, b.types[i]) then
               return false, { types.error("tuple entry " .. i .. " of type %s does not match type of array elements, which is %s", b.types[i], a.elements) }
            end
         end
         return true
      end,
      ["emptytable"] = compare_true_inferring_emptytable,
   },
   ["map"] = {
      ["map"] = function(ck: TypeChecker, a: MapType, b: MapType): boolean, {Error}
         return compare_map(ck, a.keys, b.keys, a.values, b.values)
      end,
      ["array"] = function(ck: TypeChecker, a: MapType, b: ArrayType): boolean, {Error}
         return compare_map(ck, a.keys, a_type(b, "integer", {}), a.values, b.elements)
      end,
      ["emptytable"] = compare_true_inferring_emptytable,
   },
   ["typedecl"] = {
      ["*"] = function(ck: TypeChecker, a: TypeDeclType, b: RecordType): boolean, {Error}
         return ck:is_a(a.def, b)
      end,
   },
   ["function"] = {
      ["function"] = function(ck: TypeChecker, a: FunctionType, b: FunctionType): boolean, {Error}
         local errs = {}

         local aa, ba = a.args.tuple, b.args.tuple
         if (not b.args.is_va) and (ck.feat_arity and (#aa > #ba and a.min_arity > b.min_arity)) then
            table.insert(errs, types.error("incompatible number of arguments: got " .. show_arity(a) .. " %s, expected " .. show_arity(b) .. " %s", a.args, b.args))
         else
            for i = ((a.is_method or b.is_method) and 2 or 1), #aa do
               local ai = aa[i]
               local bi = ba[i] or (b.args.is_va and ba[#ba])
               if bi then
                  ck:arg_check(nil, errs, ai, bi, "bivariant", "argument", i)
               end
            end
         end

         local ar, br = a.rets.tuple, b.rets.tuple
         local diff_by_va = #br - #ar == 1 and b.rets.is_va
         if #ar < #br and not diff_by_va then
            table.insert(errs, types.error("incompatible number of returns: got " .. #ar .. " %s, expected " .. #br .. " %s", a.rets, b.rets))
         else
            local nrets = #br
            if diff_by_va then
               nrets = nrets - 1
            end
            for i = 1, nrets do
               ck:arg_check(nil, errs, ar[i], br[i], "bivariant", "return", i)
            end
         end

         return errors.any(errs)
      end,
   },
   ["self"] = {
      ["self"] = function(_ck: TypeChecker, _a: SelfType, _b: SelfType): boolean, {Error}
         return true
      end,
      ["*"] = function(ck: TypeChecker, a: SelfType, b: Type): boolean, {Error}
         return ck:is_a(ck:type_of_self(a), b)
      end,
   },
   ["typearg"] = {
      ["typearg"] = function(_ck: TypeChecker, a: TypeArgType, b: TypeArgType): boolean, {Error}
         return a.typearg == b.typearg
      end,
      ["*"] = function(ck: TypeChecker, a: TypeArgType, b: Type): boolean, {Error}
         if a.constraint then
            return ck:is_a(a.constraint, b)
         end
      end,
   },
   ["boolean_context"] = {
      ["boolean"] = compare_true,
   },
   ["generic"] = {
      ["*"] = function(ck: TypeChecker, a: GenericType, b: Type): boolean, {Error}
         -- TODO check if commenting this out causes variable leaks anywhere
         -- ck:begin_scope()
         local aa = ck:apply_generic(a, a)
         local ok, errs = ck:is_a(aa, b)
         -- ck:end_scope()
         return ok, errs
      end,
   },
   ["*"] = {
      ["any"] = compare_true,
      ["boolean_context"] = compare_true,
      ["emptytable"] = function(_ck: TypeChecker, a: Type, _b: EmptyTableType): boolean, {Error}
         return false, { types.error("assigning %s to a variable declared with {}", a) }
      end,
      ["unresolved_emptytable_value"] = function(ck: TypeChecker, a: Type, b: UnresolvedEmptyTableValueType): boolean, {Error}
         ck:infer_emptytable_from_unresolved_value(b, b, a)
         return true
      end,
      ["generic"] = function(ck: TypeChecker, a: Type, b: GenericType): boolean, {Error}
         -- TODO check if commenting this out causes variable leaks anywhere
         -- ck:begin_scope()
         local bb = ck:apply_generic(b, b)
         local ok, errs = ck:is_a(a, bb)
         -- ck:end_scope()
         return ok, errs
      end,
      ["self"] = function(ck: TypeChecker, a: Type, b: SelfType): boolean, {Error}
         return ck:is_a(a, (ck:type_of_self(b)))
      end,
      ["tuple"] = function(ck: TypeChecker, a: Type, b: Type): boolean, {Error}
         local tuple = a_type(a, "tuple", { tuple = {a} } as TupleType)
         return ck:is_a(tuple, b)
      end,
      ["typedecl"] = function(ck: TypeChecker, a: Type, b: TypeDeclType): boolean, {Error}
         return ck:is_a(a, b.def)
      end,
      ["typevar"] = function(ck: TypeChecker, a: Type, b: TypeVarType): boolean, {Error}
         return compare_or_infer_typevar(ck, b.typevar, a, nil, ck.is_a)
      end,
      ["typearg"] = function(ck: TypeChecker, a: Type, b: TypeArgType): boolean, {Error}
         if b.constraint then
            return ck:is_a(a, b.constraint)
         end
      end,
      -- ∃ t ∈ b, a <: t
      -- ───────────────
      --  a <: b union
      ["union"] = exists_supertype_in as CompareTypes,
      ["nominal"] = subtype_nominal,
      -- ∀ t ∈ b, a <: t
      -- ───────────────
      --   a <: b poly
      ["poly"] = function(ck: TypeChecker, a: Type, b: PolyType): boolean, {Error}
         for _, t in ipairs(b.types) do
            if not ck:is_a(a, t) then
               return false, { errors.new("cannot match against all alternatives of the polymorphic type") }
            end
         end
         return true
      end,
   },
}

-- evaluation strategy
relations.type_priorities = {
   -- types that have catch-all rules evaluate first
   ["generic"] = -1,
   ["nil"] = 0,
   ["unresolved_emptytable_value"] = 1,
   ["emptytable"] = 2,
   ["self"] = 3,
   ["tuple"] = 4,
   ["typevar"] = 5,
   ["typedecl"] = 6,
   ["any"] = 7,
   ["boolean_context"] = 8,
   ["union"] = 9,
   ["poly"] = 10,
   -- then typeargs
   ["typearg"] = 11,
   -- then nominals
   ["nominal"] = 12,
   -- then base types
   ["enum"] = 13,
   ["string"] = 13,
   ["integer"] = 13,
   ["boolean"] = 13,
   -- then interfaces
   ["interface"] = 14,
   -- then special cases of tables
   ["tupletable"] = 15,
   ["record"] = 15,
   ["array"] = 15,
   ["map"] = 15,
   ["function"] = 15,
}

function relations.compare_types(ck: TypeChecker, prios: TypePriorities, rels: TypeRelations, t1: Type, t2: Type): boolean, {Error}
   if t1.typeid == t2.typeid then
      return true
   end

   local s1 = rels[t1.typename]
   local fn = s1 and s1[t2.typename]
   if not fn then
      local p1 = prios[t1.typename] or 999
      local p2 = prios[t2.typename] or 999
      fn = (p1 < p2 and (s1 and s1["*"]) or (rels["*"][t2.typename]))
   end

   local ok, err: boolean, {Error}
   if fn then
      if fn == compare_true then
         return true
      end
      ok, err = fn(ck, t1, t2)
   else
      ok = t1.typename == t2.typename
   end

   if (not ok) and not err then
      if t1 is InvalidType or t2 is InvalidType then
         return false, {}
      end
      local show_t1 = show_type(t1)
      local show_t2 = show_type(t2)
      if show_t1 == show_t2 then
         return false, { errors.at(t1, "types are incompatible") }
      else
         return false, { errors.at(t1, "got " .. show_t1 .. ", expected " .. show_t2) }
      end
   end
   return ok, err
end

function relations.lax_type_priorities(): {TypeName:integer}
   local copy = shallow_copy_table(relations.type_priorities)
   copy["unknown"] = -10
   return copy
end

function relations.lax_subtype_relations(): TypeRelations
   local copy = shallow_copy_table(relations.subtype_relations)

   copy["unknown"] = {}
   copy["unknown"]["*"] = compare_true

   copy["*"] = shallow_copy_table(copy["*"])
   copy["*"]["unknown"] = compare_true
   -- in .lua files, all values can be used in a boolean context
   copy["*"]["boolean"] = compare_true

   return copy
end

return relations
