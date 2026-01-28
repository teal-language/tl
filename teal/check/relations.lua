local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local errors = require("teal.errors")


local types = require("teal.types")


























local a_type = types.a_type
local show_arity = types.show_arity
local show_type = types.show_type
local untuple = types.untuple




local util = require("teal.util")
local shallow_copy_table = util.shallow_copy_table

local relations = {}















local function compare_true(_, _, _)
   return true
end

local function compare_map(ck, ak, bk, av, bv, no_hack)
   local ok1, errs_k = ck:is_a(bk, ak)
   local ok2, errs_v = ck:is_a(av, bv)


   if bk.typename == "any" and not no_hack then
      ok1, errs_k = true, nil
   end
   if bv.typename == "any" and not no_hack then
      ok2, errs_v = true, nil
   end

   if ok1 and ok2 then
      return true
   end


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

local function compare_or_infer_typevar(ck, typevar, a, b, cmp)



   local vt, _, constraint = ck:find_var_type(typevar)
   if vt then

      return cmp(ck, a or vt, b or vt)
   else

      local other = a or b


      if constraint then
         if not ck:is_a(other, constraint) then
            return false, { types.error("given type %s does not satisfy %s constraint in type variable " .. types.show_typevar(typevar, "typevar"), other, constraint) }
         end

         if ck:same_type(other, constraint) then



            return true
         end
      end

      local r, errs = ck:resolve_typevars(other)
      if errs then
         return false, errs
      end


      if r.typename == "boolean_context" then
         return true
      end

      if r.typename == "typevar" and r.typevar == typevar then
         return true
      end
      ck:add_implied_var(typevar, r)
      return true
   end
end

local function subtype_record(ck, a, b)
   if a.elements and b.elements then
      if not ck:is_a(a.elements, b.elements) then
         return false, { errors.new("array parts have incompatible element types") }
      end
   end

   if a.is_userdata ~= b.is_userdata then
      return false, { errors.new(a.is_userdata and "userdata is not a record" or
"record is not a userdata"), }
   end

   local errs = {}
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

local function eqtype_record(ck, a, b)

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


local function compare_true_inferring_emptytable(ck, a, b)
   ck:infer_emptytable(b, ck:infer_at(b, a))
   return true
end

local function compare_true_inferring_emptytable_if_not_userdata(ck, a, b)
   if a.is_userdata then
      return false, { types.error("{} cannot be used with userdata type %s", a) }
   end
   return compare_true_inferring_emptytable(ck, a, b)
end

local function is_in_interface_list(ck, r, iface)
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

local function a_is_interface_b(ck, a, b)
   if (not a.found) or (not b.found) then
      return false
   end

   local af = a.found.def
   if af.typename == "generic" then
      af = ck:apply_generic(a, af, a.typevals)
   end

   if af.fields then
      if is_in_interface_list(ck, af, b) then
         return true
      end
   end

   return ck:is_a(a, ck:resolve_nominal(b))
end

local are_same_nominals
do
   local function are_same_unresolved_global_type(ck, t1, t2)

      if t1.names[1] == t2.names[1] then
         if ck:is_pending_global(t1.names[1]) then
            return true
         end
      end
      return false
   end

   local function fail_nominals(ck, t1, t2)
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

   local function nominal_found_type(ck, nom)
      local typedecl = nom.found
      if not typedecl then
         typedecl = ck:find_type(nom.names)
         if not typedecl then
            return nil
         end
      end
      local t = typedecl.def

      if t.typename == "generic" then
         t = t.t
      end

      return t
   end

   are_same_nominals = function(ck, t1, t2)
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
         return false, {}
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


      return true
   end
end

local function has_all_types_of(ck, t1s, t2s)
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


local emptytable_relations = {
   ["emptytable"] = compare_true,
   ["array"] = compare_true,
   ["map"] = compare_true,
   ["tupletable"] = compare_true,
   ["interface"] = function(_ck, _a, b)
      return not b.is_userdata
   end,
   ["record"] = function(_ck, _a, b)
      return not b.is_userdata
   end,
}

relations.eqtype_relations = {
   ["typevar"] = {
      ["typevar"] = function(ck, a, b)
         if a.typevar == b.typevar then
            return true
         end

         return compare_or_infer_typevar(ck, b.typevar, a, nil, ck.same_type)
      end,
      ["*"] = function(ck, a, b)
         return compare_or_infer_typevar(ck, a.typevar, nil, b, ck.same_type)
      end,
   },
   ["emptytable"] = emptytable_relations,
   ["tupletable"] = {
      ["tupletable"] = function(ck, a, b)
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
      ["array"] = function(ck, a, b)
         return ck:same_type(a.elements, b.elements)
      end,
      ["emptytable"] = compare_true_inferring_emptytable,
   },
   ["map"] = {
      ["map"] = function(ck, a, b)
         return compare_map(ck, a.keys, b.keys, a.values, b.values, true)
      end,
      ["emptytable"] = compare_true_inferring_emptytable,
   },
   ["union"] = {
      ["union"] = function(ck, a, b)
         return (has_all_types_of(ck, a.types, b.types) and
         has_all_types_of(ck, b.types, a.types))
      end,
   },
   ["nominal"] = {
      ["nominal"] = are_same_nominals,
      ["typedecl"] = function(ck, a, b)

         return ck:same_type(ck:resolve_nominal(a), b.def)
      end,
   },
   ["record"] = {
      ["record"] = eqtype_record,
      ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
   },
   ["interface"] = {
      ["interface"] = function(_ck, a, b)
         return a.typeid == b.typeid
      end,
      ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
   },
   ["function"] = {
      ["function"] = function(ck, a, b)
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
      ["self"] = function(_ck, _a, _b)
         return true
      end,
      ["*"] = function(ck, a, b)
         return ck:same_type(ck:type_of_self(a), b)
      end,
   },
   ["boolean_context"] = {
      ["boolean"] = compare_true,
   },
   ["generic"] = {
      ["generic"] = function(ck, a, b)
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
      ["self"] = function(ck, a, b)
         return ck:same_type(a, (ck:type_of_self(b)))
      end,
      ["typevar"] = function(ck, a, b)
         return compare_or_infer_typevar(ck, b.typevar, a, nil, ck.same_type)
      end,
   },
}


local function exists_supertype_in(ck, t, xs)
   for _, x in ipairs(xs.types) do
      if ck:is_a(t, x) then
         return x
      end
   end
end


local function forall_are_subtype_of(ck, xs, t)
   for _, x in ipairs(xs.types) do
      if not ck:is_a(x, t) then
         return false
      end
   end
   return true
end

local function subtype_nominal(ck, a, b)
   local ra = a.typename == "nominal" and ck:resolve_nominal(a) or a
   local rb = b.typename == "nominal" and ck:resolve_nominal(b) or b
   local ok, errs = ck:is_a(ra, rb)
   if errs and #errs == 1 and errs[1].msg:match("^got ") then
      return false
   end
   return ok, errs
end

local function subtype_array(ck, a, b)
   if (not a.elements) or (not ck:is_a(a.elements, b.elements)) then
      return false
   end
   if a.consttypes and #a.consttypes > 1 then

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
      ["tuple"] = function(ck, a, b)
         local at, bt = a.tuple, b.tuple
         if #at ~= #bt then
            return false
         end
         for i = 1, #at do
            if not ck:is_a(at[i], bt[i]) then
               return false
            end
         end
         return true
      end,
      ["*"] = function(ck, a, b)
         return ck:is_a(untuple(a), b)
      end,
   },
   ["typevar"] = {
      ["typevar"] = function(ck, a, b)
         if a.typevar == b.typevar then
            return true
         end

         return compare_or_infer_typevar(ck, b.typevar, a, nil, ck.is_a)
      end,
      ["*"] = function(ck, a, b)
         return compare_or_infer_typevar(ck, a.typevar, nil, b, ck.is_a)
      end,
   },
   ["union"] = {
      ["nominal"] = function(ck, a, b)

         local rb = ck:resolve_nominal(b)
         if rb.typename == "union" then
            return ck:is_a(a, rb)
         end

         return forall_are_subtype_of(ck, a, b)
      end,
      ["union"] = function(ck, a, b)
         local used = {}
         for _, t in ipairs(a.types) do
            ck:begin_implied_scope()
            local u = exists_supertype_in(ck, t, b)
            ck:end_implied_scope()
            if not u then
               return false
            end
            if not used[u] then
               used[u] = t
            end
         end
         for u, t in pairs(used) do
            ck:is_a(t, u)
         end
         return true
      end,
      ["*"] = forall_are_subtype_of,
   },
   ["poly"] = {



      ["*"] = function(ck, a, b)
         if exists_supertype_in(ck, b, a) then
            return true
         end
         return false, { errors.new("cannot match against any alternatives of the polymorphic type") }
      end,
   },
   ["nominal"] = {
      ["nominal"] = function(ck, a, b)
         local ok, errs = are_same_nominals(ck, a, b)
         if ok then
            return true
         end

         local ra = ck:resolve_nominal(a)
         local rb = ck:resolve_nominal(b)


         local union_a = ra.typename == "union"
         local union_b = rb.typename == "union"
         if union_a or union_b then
            return ck:is_a(union_a and ra or a, union_b and rb or b)
         end


         if rb.typename == "interface" then
            return a_is_interface_b(ck, a, b)
         end


         return ok, errs
      end,
      ["union"] = function(ck, a, b)

         local ra = ck:resolve_nominal(a)
         if ra.typename == "union" then
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
      ["enum"] = function(_ck, a, b)
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
      ["interface"] = function(ck, a, b)
         if is_in_interface_list(ck, a, b) then
            return true
         end
         return ck:same_type(a, b)
      end,
      ["array"] = subtype_array,
      ["tupletable"] = function(ck, a, b)
         return relations.subtype_relations["record"]["tupletable"](ck, a, b)
      end,
      ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
   },
   ["emptytable"] = emptytable_relations,
   ["tupletable"] = {
      ["tupletable"] = function(ck, a, b)
         for i = 1, math.min(#a.types, #b.types) do
            if not ck:is_a(a.types[i], b.types[i]) then
               return false, { types.error("in tuple entry " ..
tostring(i) .. ": got %s, expected %s",
a.types[i], b.types[i]), }
            end
         end
         if #a.types > #b.types then
            return false, { types.error("tuple %s is too big for tuple %s", a, b) }
         end
         return true
      end,
      ["record"] = function(ck, a, b)
         if b.elements then
            return relations.subtype_relations["tupletable"]["array"](ck, a, b)
         end
      end,
      ["array"] = function(ck, a, b)
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
      ["map"] = function(ck, a, b)
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
      ["interface"] = function(ck, a, b)
         if is_in_interface_list(ck, a, b) then
            return true
         end
         if not a.declname then

            return subtype_record(ck, a, b)
         end
      end,
      ["array"] = subtype_array,
      ["map"] = function(ck, a, b)
         if not ck:is_a(b.keys, a_type(b, "string", {})) then
            return false, { errors.new("can't match a record to a map with non-string keys") }
         end

         for _, k in ipairs(a.field_order) do
            local bk = b.keys
            if bk.typename == "enum" and not bk.enumset[k] then
               return false, { errors.new("key is not an enum value: " .. k) }
            end
            if not ck:is_a(a.fields[k], b.values) then
               return false, { errors.new("record is not a valid map; not all fields have the same type") }
            end
         end

         return true
      end,
      ["tupletable"] = function(ck, a, b)
         if a.elements then
            return relations.subtype_relations["array"]["tupletable"](ck, a, b)
         end
      end,
      ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
   },
   ["array"] = {
      ["array"] = subtype_array,
      ["record"] = function(ck, a, b)
         if b.elements then
            return subtype_array(ck, a, b)
         end
      end,
      ["map"] = function(ck, a, b)
         return compare_map(ck, a_type(a, "integer", {}), b.keys, a.elements, b.values)
      end,
      ["tupletable"] = function(ck, a, b)
         local alen = a.inferred_len or 0
         if alen > #b.types then
            return false, { errors.new("incompatible length, expected maximum length of " .. tostring(#b.types) .. ", got " .. tostring(alen)) }
         end



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
      ["map"] = function(ck, a, b)
         return compare_map(ck, a.keys, b.keys, a.values, b.values)
      end,
      ["array"] = function(ck, a, b)
         return compare_map(ck, a.keys, a_type(b, "integer", {}), a.values, b.elements)
      end,
      ["emptytable"] = compare_true_inferring_emptytable,
   },
   ["typedecl"] = {
      ["*"] = function(ck, a, b)
         return ck:is_a(a.def, b)
      end,
   },
   ["function"] = {
      ["function"] = function(ck, a, b)
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
      ["self"] = function(_ck, _a, _b)
         return true
      end,
      ["*"] = function(ck, a, b)
         return ck:is_a(ck:type_of_self(a), b)
      end,
   },
   ["typearg"] = {
      ["typearg"] = function(_ck, a, b)
         return a.typearg == b.typearg
      end,
      ["*"] = function(ck, a, b)
         if a.constraint then
            return ck:is_a(a.constraint, b)
         end
      end,
   },
   ["boolean_context"] = {
      ["boolean"] = compare_true,
   },
   ["generic"] = {
      ["*"] = function(ck, a, b)


         local aa = ck:apply_generic(a, a)
         local ok, errs = ck:is_a(aa, b)

         return ok, errs
      end,
   },
   ["*"] = {
      ["any"] = compare_true,
      ["boolean_context"] = compare_true,
      ["emptytable"] = function(_ck, a, _b)
         return false, { types.error("assigning %s to a variable declared with {}", a) }
      end,
      ["unresolved_emptytable_value"] = function(ck, a, b)
         ck:infer_emptytable_from_unresolved_value(b, b, a)
         return true
      end,
      ["generic"] = function(ck, a, b)


         local bb = ck:apply_generic(b, b)
         local ok, errs = ck:is_a(a, bb)

         return ok, errs
      end,
      ["self"] = function(ck, a, b)
         return ck:is_a(a, (ck:type_of_self(b)))
      end,
      ["tuple"] = function(ck, a, b)
         local tuple = a_type(a, "tuple", { tuple = { a } })
         return ck:is_a(tuple, b)
      end,
      ["typedecl"] = function(ck, a, b)
         return ck:is_a(a, b.def)
      end,
      ["typevar"] = function(ck, a, b)
         return compare_or_infer_typevar(ck, b.typevar, a, nil, ck.is_a)
      end,
      ["typearg"] = function(ck, a, b)
         if b.constraint then
            return ck:is_a(a, b.constraint)
         end
      end,



      ["union"] = exists_supertype_in,
      ["nominal"] = subtype_nominal,



      ["poly"] = function(ck, a, b)
         for _, t in ipairs(b.types) do
            if not ck:is_a(a, t) then
               return false, { errors.new("cannot match against all alternatives of the polymorphic type") }
            end
         end
         return true
      end,
   },
}


relations.type_priorities = {

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

   ["typearg"] = 11,

   ["nominal"] = 12,

   ["enum"] = 13,
   ["string"] = 13,
   ["integer"] = 13,
   ["boolean"] = 13,

   ["interface"] = 14,

   ["tupletable"] = 15,
   ["record"] = 15,
   ["array"] = 15,
   ["map"] = 15,
   ["function"] = 15,
}

function relations.compare_types(ck, prios, rels, t1, t2)
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

   local ok, err
   if fn then
      if fn == compare_true then
         return true
      end
      ok, err = fn(ck, t1, t2)
   else
      ok = t1.typename == t2.typename
   end

   if (not ok) and not err then
      if t1.typename == "invalid" or t2.typename == "invalid" then
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

function relations.lax_type_priorities()
   local copy = shallow_copy_table(relations.type_priorities)
   copy["unknown"] = -10
   return copy
end

function relations.lax_subtype_relations()
   local copy = shallow_copy_table(relations.subtype_relations)

   copy["unknown"] = {}
   copy["unknown"]["*"] = compare_true

   copy["*"] = shallow_copy_table(copy["*"])
   copy["*"]["unknown"] = compare_true

   copy["*"]["boolean"] = compare_true

   return copy
end

return relations
