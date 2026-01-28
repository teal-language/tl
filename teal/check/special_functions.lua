local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table





local parser = require("teal.parser")

local node_at = parser.node_at

local types = require("teal.types")

















local a_type = types.a_type
local a_function = types.a_function
local a_vararg = types.a_vararg
local ensure_not_method = types.ensure_not_method
local is_unknown = types.is_unknown

























local function special_pcall_xpcall(self, node, a, b, argdelta)
   local isx = a.special_function_handler == "xpcall"
   local base_nargs = isx and 2 or 1
   local bool = a_type(node, "boolean", {})
   if #node.e2 < base_nargs then
      self:add_error(node, "wrong number of arguments (given " .. #node.e2 .. ", expects at least " .. base_nargs .. ")")
      return a_type(node, "tuple", { tuple = { bool } })
   end

   local ftype = table.remove(b.tuple, 1)




   ftype = ensure_not_method(ftype)

   local fe2 = node_at(node.e2, {})
   if isx then
      base_nargs = 2
      local arg2 = node.e2[2]
      local msgh = table.remove(b.tuple, 1)
      local msgh_type = a_function(arg2, {
         min_arity = self.feat_arity and 1 or 0,
         args = a_type(arg2, "tuple", { tuple = { a_type(arg2, "any", {}) } }),
         rets = a_vararg(arg2, { a_type(arg2, "any", {}) }),
      })
      local ok, errs = self:is_a(msgh, msgh_type)
      if not ok then
         self:add_errors_prefixing(arg2, errs, "in message handler: ")
      end
   end
   for i = base_nargs + 1, #node.e2 do
      table.insert(fe2, node.e2[i])
   end
   local fnode = node_at(node, {
      kind = "op",
      op = { op = "@funcall" },
      e1 = node.e2[1],
      e2 = fe2,
   })
   local rets = self:type_check_funcall(fnode, ftype, b, argdelta + base_nargs)
   if rets.typename == "invalid" then
      return rets
   end
   table.insert(rets.tuple, 1, bool)
   return rets
end

local function pattern_findclassend(pat, i, strict)
   local c = pat:sub(i, i)
   if c == "%" then
      local peek = pat:sub(i + 1, i + 1)
      if peek == "f" then

         if pat:sub(i + 2, i + 2) ~= "[" then
            return nil, nil, "malformed pattern: missing '[' after %f"
         end
         local e, _, err = pattern_findclassend(pat, i + 2, strict)
         if not e then
            return nil, nil, err
         else
            return e, false
         end
      elseif peek == "b" then
         if pat:sub(i + 3, i + 3) == "" then
            return nil, nil, "malformed pattern: need balanced characters"
         end
         return i + 3, false
      elseif peek == "" then
         return nil, nil, "malformed pattern: expected class"
      elseif peek:match("[1-9]") then
         return i + 1, false
      elseif strict and not peek:match("[][^$()%%.*+%-?AaCcDdGgLlPpSsUuWwXxZz]") then
         return nil, nil, "malformed pattern: invalid class '" .. peek .. "'"
      else
         return i + 1, true
      end
   elseif c == "[" then
      if pat:sub(i + 1, i + 1) == "^" then
         i = i + 2
      else
         i = i + 1
      end

      local isfirst = true
      repeat
         local c_ = pat:sub(i, i)
         if c_ == "" then
            return nil, nil, "malformed pattern: missing ']'"
         elseif c_ == "%" then
            if strict and not pat:sub(i + 1, i + 1):match("[][^$()%%.*+%-?AaCcDdGgLlPpSsUuWwXxZz]") then
               return nil, nil, "malformed pattern: invalid escape"
            end
            i = i + 2
         elseif c_ == "-" and strict and not isfirst then
            return nil, nil, "malformed pattern: unexpected '-'"
         else
            local c2 = pat:sub(i + 1, i + 1)
            local c3 = pat:sub(i + 2, i + 2)
            if c2 == "-" then
               if strict and c3 == "]" then
                  return nil, nil, "malformed pattern: unexpected ']'"
               elseif strict and c3 == "-" then
                  return nil, nil, "malformed pattern: unexpected '-'"
               elseif strict and c3 == "%" then
                  return nil, nil, "malformed pattern: unexpected '%'"
               end

               i = i + 2
            else
               i = i + 1
            end
         end
         isfirst = false
      until pat:sub(i, i) == "]"

      return i, true
   else
      return i, true
   end
end

local pattern_isop = {
   ["?"] = true,
   ["+"] = true,
   ["-"] = true,
   ["*"] = true,
}

local function parse_pattern_string(node, pat, inclempty)





















   local strict = false

   local results = {}

   local i = pat:sub(1, 1) == "^" and 2 or 1
   local unclosed = 0

   while i <= #pat do
      local c = pat:sub(i, i)

      if i == #pat and c == "$" then
         break
      end

      local classend, canhavemul, err = pattern_findclassend(pat, i, strict)
      if not classend then
         return nil, err
      end

      local peek = pat:sub(classend + 1, classend + 1)

      if c == "(" and peek == ")" then

         table.insert(results, a_type(node, "integer", {}))
         i = i + 2
      elseif c == "(" then
         table.insert(results, a_type(node, "string", {}))
         unclosed = unclosed + 1
         i = i + 1
      elseif c == ")" then
         unclosed = unclosed - 1
         if unclosed < 0 then
            return nil, "malformed pattern: unexpected ')'"
         end
         i = i + 1
      elseif strict and c:match("[]^$()*+%-?]") then
         return nil, "malformed pattern: character was unexpected: '" .. c .. "'"
      elseif pattern_isop[peek] and canhavemul then
         i = classend + 2
      else

         i = classend + 1
      end
   end

   if inclempty and not results[1] then
      results[1] = a_type(node, "string", {})
   end
   if unclosed ~= 0 then
      return nil, "malformed pattern: " .. unclosed .. " capture" .. (unclosed == 1 and "" or "s") .. " not closed"
   end
   return results
end

local function parse_format_string(node, pat)
   local pos = 1
   local results = {}
   while pos <= #pat do

      local endc = pat:match("%%[-+#0-9. ]*()", pos)
      if not endc then return results end
      local c = pat:sub(endc, endc)
      if c == "" then
         return nil, "missing pattern specifier at end"
      end
      if c:match("[AaEefGg]") then
         table.insert(results, a_type(node, "number", {}))
      elseif c:match("[cdiouXx]") then
         table.insert(results, a_type(node, "integer", {}))
      elseif c == "q" then
         table.insert(results,
         a_type(node, "union", { types = {
            a_type(node, "string", {}),
            a_type(node, "number", {}),
            a_type(node, "integer", {}),
            a_type(node, "boolean", {}),
            a_type(node, "nil", {}),
         } }))

      elseif c == "p" or c == "s" then
         table.insert(results, a_type(node, "any", {}))
      elseif c == "%" then

      else
         return nil, "invalid pattern specifier: '" .. c .. "'"
      end
      pos = endc + 1
   end
   return results
end

local function pack_string_skipnum(pos, pat)

   return pat:match("[0-9]*()", pos)
end

local function parse_pack_string(node, pat)
   local pos = 1
   local results = {}
   local skip_next = false
   while pos <= #pat do
      local c = pat:sub(pos, pos)
      local to_add
      local goto_next
      if c:match("[<> =x]") then

         if skip_next then
            return nil, "expected argument for 'X'"
         end
         pos = pos + 1
         goto_next = true
      elseif c == "X" then
         if skip_next then
            return nil, "expected argument for 'X'"
         end
         skip_next = true
         pos = pos + 1
         goto_next = true
      elseif c == "!" then
         if skip_next then
            return nil, "expected argument for 'X'"
         end
         pos = pack_string_skipnum(pos + 1, pat)
         goto_next = true
      elseif c:match("[Ii]") then
         pos = pack_string_skipnum(pos + 1, pat)
         to_add = a_type(node, "integer", {})
      elseif c:match("[bBhHlLjJT]") then
         pos = pos + 1
         to_add = a_type(node, "integer", {})
      elseif c:match("[fdn]") then
         pos = pos + 1
         to_add = a_type(node, "number", {})
      elseif c == "z" or c == "s" or c == "c" then
         if c == "z" then
            pos = pos + 1
         else
            pos = pack_string_skipnum(pos + 1, pat)
         end

         to_add = a_type(node, "string", {})
      else
         return nil, "invalid format option: '" .. c .. "'"
      end
      if not goto_next then
         if skip_next then
            skip_next = false
         else
            table.insert(results, to_add)
         end
      end
   end
   if skip_next then
      return nil, "expected argument for 'X'"
   end
   return results
end

local special_functions = {
   ["pairs"] = function(self, node, a, b, argdelta)
      if not b.tuple[1] then
         return self:invalid_at(node, "pairs requires an argument")
      end
      local t = self:to_structural(b.tuple[1])
      if t.elements then
         self:add_warning("hint", node, "hint: applying pairs on an array: did you intend to apply ipairs?")
      end

      if not (t.typename == "map") then
         if not (self.feat_lax and is_unknown(t)) then
            if t.fields then
               self:match_all_record_field_names(node.e2, t, t.field_order,
               "attempting pairs on a record with attributes of different types")
               local ct = t.typename == "record" and "{string:any}" or "{any:any}"
               self:add_warning("hint", node.e2, "hint: if you want to iterate over fields of a record, cast it to " .. ct)
            else
               self:add_error(node.e2, "cannot apply pairs on values of type: %s", t)
            end
         end
      end

      return (self:type_check_function_call(node, a, b, argdelta))
   end,

   ["ipairs"] = function(self, node, a, b, argdelta)
      if not b.tuple[1] then
         return self:invalid_at(node, "ipairs requires an argument")
      end
      local orig_t = b.tuple[1]
      local t = self:to_structural(orig_t)

      if t.typename == "tupletable" then
         local arr_type = self:arraytype_from_tuple(node.e2, t)
         if not arr_type then
            return self:invalid_at(node.e2, "attempting ipairs on tuple that's not a valid array: %s", orig_t)
         end
      elseif not t.elements then
         if not (self.feat_lax and (is_unknown(t) or t.typename == "emptytable")) then
            return self:invalid_at(node.e2, "attempting ipairs on something that's not an array: %s", orig_t)
         end
      end

      return (self:type_check_function_call(node, a, b, argdelta))
   end,

   ["rawget"] = function(self, node, _a, b, _argdelta)

      if #b.tuple == 2 then
         return a_type(node, "tuple", { tuple = { self:type_check_index(node.e2[1], node.e2[2], b.tuple[1], b.tuple[2]) } })
      else
         return self:invalid_at(node, "rawget expects two arguments")
      end
   end,

   ["require"] = function(self, node, _a, b, _argdelta)
      if #b.tuple ~= 1 then
         return self:invalid_at(node, "require expects one literal argument")
      end
      if node.e2[1].kind ~= "string" then
         return a_type(node, "tuple", { tuple = { a_type(node, "any", {}) } })
      end

      local module_name = assert(node.e2[1].conststr)
      local t, module_filename = self.env:require_module(module_name)
      if not t then
         return self:invalid_at(node, "module not found: '" .. module_name .. "'")
      end

      if self.feat_lax then
         if t.typename == "invalid" then
            return a_type(node, "tuple", { tuple = { a_type(node, "unknown", {}) } })
         end
      elseif module_filename and module_filename:match("%.lua$") then
         return self:invalid_at(node, "no type information for required module: '" .. module_name .. "'")
      end

      self.dependencies[module_name] = module_filename
      return a_type(node, "tuple", { tuple = { t } })
   end,

   ["pcall"] = special_pcall_xpcall,
   ["xpcall"] = special_pcall_xpcall,
   ["assert"] = function(self, node, a, b, argdelta)
      self.fdb:set_truthy(node)
      local r = self:type_check_function_call(node, a, b, argdelta)
      if node.e2[1] then
         self:apply_facts_from(node, node.e2[1])
      end
      return r
   end,
   ["string.pack"] = function(self, node, a, b, argdelta)
      if #b.tuple < 1 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects at least 1)")
      end

      local packstr = b.tuple[1]

      if packstr.typename == "string" and packstr.literal and a.typename == "function" then
         local st = packstr.literal
         local items, e = parse_pack_string(node, st)

         if e then
            if items then

               self:add_warning("hint", packstr, e)
            else
               return self:invalid_at(packstr, e)
            end
         end

         table.insert(items, 1, a_type(node, "string", {}))

         if #items ~= #b.tuple then
            return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects " .. #items .. ")")
         end

         return (self:type_check_function_call(node, a, b, argdelta, a_type(node, "tuple", { tuple = items }), nil))
      else
         return (self:type_check_function_call(node, a, b, argdelta))
      end
   end,

   ["string.unpack"] = function(self, node, a, b, argdelta)
      if #b.tuple < 2 or #b.tuple > 3 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 2 or 3)")
      end

      local packstr = b.tuple[1]

      local rets

      if packstr.typename == "string" and packstr.literal then
         local st = packstr.literal
         local items, e = parse_pack_string(node, st)

         if e then
            if items then

               self:add_warning("hint", packstr, e)
            else
               return self:invalid_at(packstr, e)
            end
         end

         table.insert(items, a_type(node, "integer", {}))


         rets = a_type(node, "tuple", { tuple = items })
      end

      return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
   end,

   ["string.format"] = function(self, node, a, b, argdelta)
      if #b.tuple < 1 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects at least 1)")
      end

      local fstr = b.tuple[1]

      if fstr.typename == "string" and fstr.literal and a.typename == "function" then
         local st = fstr.literal
         local items, e = parse_format_string(node, st)

         if e then
            if items then

               self:add_warning("hint", fstr, e)
            else
               return self:invalid_at(fstr, e)
            end
         end

         table.insert(items, 1, a_type(node, "string", {}))

         if #items ~= #b.tuple then
            return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects " .. #items .. ")")
         end


         return (self:type_check_function_call(node, a, b, argdelta, a_type(node, "tuple", { tuple = items }), nil))
      else
         return (self:type_check_function_call(node, a, b, argdelta))
      end
   end,

   ["string.match"] = function(self, node, a, b, argdelta)
      if #b.tuple < 2 or #b.tuple > 3 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 2 or 3)")
      end

      local rets
      local pat = b.tuple[2]

      if pat.typename == "string" and pat.literal then
         local st = pat.literal
         local items, e = parse_pattern_string(node, st, true)

         if e then
            if items then

               self:add_warning("hint", pat, e)
            else
               return self:invalid_at(pat, e)
            end
         end


         rets = a_type(node, "tuple", { tuple = items })
      end
      return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
   end,

   ["string.find"] = function(self, node, a, b, argdelta)
      if #b.tuple < 2 or #b.tuple > 4 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects at least 2 and at most 4)")
      end

      local plainarg = node.e2[4 + (argdelta or 0)]
      local pat = b.tuple[2]

      local rets

      if pat.typename == "string" and pat.literal and
         ((not plainarg) or (plainarg.kind == "boolean" and plainarg.tk == "false")) then

         local st = pat.literal

         local items, e = parse_pattern_string(node, st, false)

         if e then
            if items then

               self:add_warning("hint", pat, e)
            else
               return self:invalid_at(pat, e)
            end
         end

         table.insert(items, 1, a_type(pat, "integer", {}))
         table.insert(items, 1, a_type(pat, "integer", {}))


         rets = a_type(node, "tuple", { tuple = items })
      end

      return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
   end,

   ["string.gmatch"] = function(self, node, a, b, argdelta)
      if #b.tuple < 2 or #b.tuple > 3 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 2 or 3)")
      end

      local rets
      local pat = b.tuple[2]

      if pat.typename == "string" and pat.literal then
         local st = pat.literal
         local items, e = parse_pattern_string(node, st, true)

         if e then
            if items then

               self:add_warning("hint", pat, e)
            else
               return self:invalid_at(pat, e)
            end
         end


         rets = a_type(node, "tuple", { tuple = {
            a_function(node, {
               min_arity = 0,
               args = a_type(node, "tuple", { tuple = {} }),
               rets = a_type(node, "tuple", { tuple = items }),
            }),
         } })
      end

      return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
   end,

   ["string.gsub"] = function(self, node, a, b, argdelta)



      if #b.tuple < 3 or #b.tuple > 4 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 3 or 4)")
      end
      local pat = b.tuple[2]
      local orig_t = b.tuple[3]
      local trepl = self:to_structural(orig_t)

      local has_fourth = b.tuple[4]

      local args

      if pat.typename == "string" and pat.literal then
         local st = pat.literal
         local items, e = parse_pattern_string(node, st, true)

         if e then
            if items then

               self:add_warning("hint", pat, e)
            else
               return self:invalid_at(pat, e)
            end
         end

         local i1 = items[1]






         local replarg_type

         local expected_pat_return = a_type(node, "union", { types = {
            a_type(node, "string", {}),
            a_type(node, "integer", {}),
            a_type(node, "number", {}),
         } })
         if self:is_a(trepl, expected_pat_return) then

            replarg_type = expected_pat_return
         elseif trepl.typename == "map" then
            replarg_type = a_type(node, "map", { keys = i1, values = expected_pat_return })
         elseif trepl.fields then
            if not (i1.typename == "string") then
               self:invalid_at(trepl, "expected a table with integers as keys")
            end
            replarg_type = a_type(node, "map", { keys = i1, values = expected_pat_return })
         elseif trepl.elements then
            if not (i1.typename == "integer") then
               self:invalid_at(trepl, "expected a table with strings as keys")
            end
            replarg_type = a_type(node, "array", { elements = expected_pat_return })
         elseif trepl.typename == "function" then
            local validftype = a_function(node, {
               min_arity = self.feat_arity and #items or 0,
               args = a_type(node, "tuple", { tuple = items }),
               rets = a_vararg(node, { expected_pat_return }),
            })
            replarg_type = validftype
         end


         if replarg_type then
            args = a_type(node, "tuple", { tuple = {
               a_type(node, "string", {}),
               a_type(node, "string", {}),
               replarg_type,
               has_fourth and a_type(node, "integer", {}) or nil,
            } })
         end
      end

      return (self:type_check_function_call(node, a, b, argdelta, args, nil))
   end,
}

return special_functions
