local type node_checker = require("teal.check.node_checker")
local type NodeChecker = node_checker.NodeChecker

local type errors = require("teal.errors")
local type Where = errors.Where

local parser = require("teal.parser")
local type Node = parser.Node
local node_at = parser.node_at

local types = require("teal.types")
local type Type = types.Type
local type StringType = types.StringType
local type IntegerType = types.IntegerType
local type ArrayType = types.ArrayType
local type ArrayLikeType = types.ArrayLikeType
local type RecordLikeType = types.RecordLikeType
local type RecordType = types.RecordType
local type UnionType = types.UnionType
local type InvalidType = types.InvalidType
local type InvalidOrTupleType = types.InvalidOrTupleType
local type TupleType = types.TupleType
local type MapType = types.MapType
local type EmptyTableType = types.EmptyTableType
local type FunctionType = types.FunctionType
local type TupleTableType = types.TupleTableType
local type UnknownType = types.UnknownType
local type SpecialFunctionName = types.SpecialFunctionName
local a_type = types.a_type
local a_function = types.a_function
local a_vararg = types.a_vararg
local ensure_not_method = types.ensure_not_method
local is_unknown = types.is_unknown

--------------------------------------------------------------------------------

local macroexp an_array(w: Where, t: Type): ArrayType
   return a_type(w, "array", { elements = t } as ArrayType)
end

local macroexp a_map(w: Where, k: Type, v: Type): MapType
   return a_type(w, "map", { keys = k, values = v } as MapType)
end

local macroexp a_tuple(w: Where, t: {Type}): TupleType
   return a_type(w, "tuple", { tuple = t } as TupleType)
end

local macroexp a_union(w: Where, t: {Type}): UnionType
   return a_type(w, "union", { types = t } as UnionType)
end

local macroexp an_unknown(w: Where): UnknownType
   return a_type(w, "unknown", {} as UnknownType)
end

--------------------------------------------------------------------------------

local function special_pcall_xpcall(self: NodeChecker, node: Node, a: FunctionType, b: TupleType, argdelta?: integer): Type
   local isx = a.special_function_handler == "xpcall"
   local base_nargs = isx and 2 or 1
   local bool = a_type(node, "boolean", {})
   if #node.e2 < base_nargs then
      self:add_error(node, "wrong number of arguments (given " .. #node.e2 .. ", expects at least " .. base_nargs .. ")")
      return a_tuple(node, { bool })
   end

   local ftype = table.remove(b.tuple, 1)

   -- The function called by pcall/xpcall is invoked as a regular function,
   -- so we wish to avoid incorrect error messages / unnecessary warning messages
   -- associated with calling methods as functions
   ftype = ensure_not_method(ftype)

   local fe2: Node = node_at(node.e2, {})
   if isx then
      base_nargs = 2
      local arg2 = node.e2[2]
      local msgh = table.remove(b.tuple, 1)
      local msgh_type = a_function(arg2, {
         min_arity = self.feat_arity and 1 or 0,
         args = a_tuple(arg2, { a_type(arg2, "any", {}) }),
         rets = a_vararg(arg2, { a_type(arg2, "any", {}) })
      })
      local ok, errs = self:is_a(msgh, msgh_type)
      if not ok then
         self:add_errors_prefixing(arg2, errs, "in message handler: ")
      end
   end
   for i = base_nargs + 1, #node.e2 do
      table.insert(fe2, node.e2[i])
   end
   local fnode: Node = node_at(node, {
      kind = "op",
      op = { op = "@funcall" },
      e1 = node.e2[1],
      e2 = fe2,
   })
   local rets = self:type_check_funcall(fnode, ftype, b, argdelta + base_nargs)
   if rets is InvalidType then
      return rets
   end
   table.insert(rets.tuple, 1, bool)
   return rets
end

local function pattern_findclassend(pat: string, i: integer, strict: boolean): integer, boolean, string
   local c = pat:sub(i, i)
   if c == "%" then
      local peek = pat:sub(i + 1, i + 1)
      if peek == "f" then
         -- frontier
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
      elseif peek:match"[1-9]" then
         return i + 1, false
      elseif strict and not peek:match"[][^$()%%.*+%-?AaCcDdGgLlPpSsUuWwXxZz]" then
         return nil, nil, "malformed pattern: invalid class '" .. peek .. "'"
      else
         return i + 1, true
      end
   elseif c == "[" then
      if pat:sub(i + 1, i + 1) == "^" then
         i = i + 2 -- skip the inverter
      else
         i = i + 1
      end

      local isfirst = true
      repeat
         local c_ = pat:sub(i, i)
         if c_ == "" then
            return nil, nil, "malformed pattern: missing ']'"
         elseif c_ == "%" then
            if strict and not pat:sub(i + 1, i + 1):match"[][^$()%%.*+%-?AaCcDdGgLlPpSsUuWwXxZz]" then
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
               -- don't skip the last one if it is a % or ]
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

local pattern_isop: {string:boolean} = {
   ["?"] = true,
   ["+"] = true,
   ["-"] = true,
   ["*"] = true,
}

local function parse_pattern_string(node: Node, pat: string, inclempty: boolean): {Type}, string
   --[[
      Pattern syntax:

      pat <- start? mid* end?
      start <- "^"
      end <- "$"
      mid <- "(" mid* ")"
           | "[" "^"? set "]" rpt?
           | "%" "b" . .
           | "%" "f" "[" "^"? set "]"
           | "%" [1-9]
           | "%" [][^$()%.*+-?AaCcDdGgLlPpSsUuWwXxZz] rpt?
           | [^][^$()%*+-?] rpt?
      set <- setitem1? setitem*
      setitem1 <- "]"
                | "]" "-" [^]%]
      setitem <- "%" [][^$()%.*+-?AaCcDdGgLlPpSsUuWwXxZz]
               | [^]%] "-" [^]%]
               | [^]%-]
      rpt <- [-*+?]
   --]]
   local strict = false

   local results: {Type} = {}

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
         -- position match
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
      elseif strict and c:match"[]^$()*+%-?]" then -- operations that haven't been handled
         return nil, "malformed pattern: character was unexpected: '" .. c .. "'"
      elseif pattern_isop[peek] and canhavemul then
         i = classend + 2
      else
         -- simple match
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

local function parse_format_string(node: Node, pat: string): {Type}, string
   local pos = 1
   local results: {Type} = {}
   while pos <= #pat do
      -- TODO: remove once bootstrap
      local endc = pat:match("%%[-+#0-9. ]*()", pos) as integer
      if not endc then return results end
      local c = pat:sub(endc, endc)
      if c == "" then
         return nil, "missing pattern specifier at end"
      end
      if c:match"[AaEefGg]" then
         table.insert(results, a_type(node, "number", {}))
      elseif c:match"[cdiouXx]" then
         table.insert(results, a_type(node, "integer", {}))
      elseif c == "q" then
         table.insert(results,
            a_union(node, {
               a_type(node, "string", {}),
               a_type(node, "number", {}),
               a_type(node, "integer", {}),
               a_type(node, "boolean", {}),
               a_type(node, "nil", {}),
            })
         )
      elseif c == "p" or c == "s" then
         table.insert(results, a_type(node, "any", {}))
      elseif c == "%" then
         -- escaped percent sign
      else
         return nil, "invalid pattern specifier: '" .. c .. "'"
      end
      pos = endc + 1
   end
   return results
end

local function pack_string_skipnum(pos: integer, pat: string): integer
   -- TODO: remove cast once bootstrap is updated
   return pat:match("[0-9]*()", pos) as integer
end

local function parse_pack_string(node: Node, pat: string): {Type}, string
   local pos = 1
   local results: {Type} = {}
   local skip_next = false
   while pos <= #pat do
      local c = pat:sub(pos, pos)
      local to_add: Type
      local goto_next: boolean
      if c:match"[<> =x]" then
         -- nothing to do with argument
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
      elseif c:match"[Ii]" then
         pos = pack_string_skipnum(pos + 1, pat)
         to_add = a_type(node, "integer", {})
      elseif c:match"[bBhHlLjJT]" then
         pos = pos + 1
         to_add = a_type(node, "integer", {})
      elseif c:match"[fdn]" then
         pos = pos + 1
         to_add = a_type(node, "number", {})
      elseif c == "z" or c == "s" or c == "c" then
         if c == "z" then
            pos = pos + 1
         else
            pos = pack_string_skipnum(pos + 1, pat)
         end
         -- string.pack accepts numbers here, but unpacks them as strings so we just skip it
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

local special_functions <total>: {SpecialFunctionName : function(NodeChecker, Node, Type, TupleType, ? integer):InvalidOrTupleType } = {
   ["pairs"] = function(self: NodeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
      if not b.tuple[1] then
         return self:invalid_at(node, "pairs requires an argument")
      end
      local t = self:to_structural(b.tuple[1])
      if t is ArrayLikeType then
         self:add_warning("hint", node, "hint: applying pairs on an array: did you intend to apply ipairs?")
      end

      if not t is MapType then
         if not (self.feat_lax and is_unknown(t)) then
            if t is RecordLikeType then
               self:match_all_record_field_names(node.e2, t, t.field_order,
                  "attempting pairs on a record with attributes of different types")
               local ct = t is RecordType and "{string:any}" or "{any:any}"
               self:add_warning("hint", node.e2, "hint: if you want to iterate over fields of a record, cast it to " .. ct)
            else
               self:add_error(node.e2, "cannot apply pairs on values of type: %s", t)
            end
         end
      end

      return (self:type_check_function_call(node, a, b, argdelta))
   end,

   ["ipairs"] = function(self: NodeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
      if not b.tuple[1] then
         return self:invalid_at(node, "ipairs requires an argument")
      end
      local orig_t = b.tuple[1]
      local t = self:to_structural(orig_t)

      if t is TupleTableType then
         local arr_type = self:arraytype_from_tuple(node.e2, t)
         if not arr_type then
            return self:invalid_at(node.e2, "attempting ipairs on tuple that's not a valid array: %s", orig_t)
         end
      elseif not t is ArrayLikeType then
         if not (self.feat_lax and (is_unknown(t) or t is EmptyTableType)) then
            return self:invalid_at(node.e2, "attempting ipairs on something that's not an array: %s", orig_t)
         end
      end

      return (self:type_check_function_call(node, a, b, argdelta))
   end,

   ["rawget"] = function(self: NodeChecker, node: Node, _a: Type, b: TupleType, _argdelta?: integer): InvalidOrTupleType
      -- TODO should those offsets be fixed by _argdelta?
      if #b.tuple == 2 then
         return a_tuple(node, { self:type_check_index(node.e2[1], node.e2[2], b.tuple[1], b.tuple[2]) })
      else
         return self:invalid_at(node, "rawget expects two arguments")
      end
   end,

   ["require"] = function(self: NodeChecker, node: Node, _a: Type, b: TupleType, _argdelta?: integer): InvalidOrTupleType
      if #b.tuple ~= 1 then
         return self:invalid_at(node, "require expects one literal argument")
      end
      if node.e2[1].kind ~= "string" then
         return a_tuple(node, { a_type(node, "any", {}) })
      end

      local module_name = assert(node.e2[1].conststr)
      local t, module_filename = self.env:require_module(module_name)
      if not t then
         return self:invalid_at(node, "module not found: '" .. module_name .. "'")
      end

      if self.feat_lax then
         if t is InvalidType then
            return a_tuple(node, { an_unknown(node) })
         end
      elseif module_filename and module_filename:match("%.lua$") then
         return self:invalid_at(node, "no type information for required module: '" .. module_name .. "'")
      end

      self.dependencies[module_name] = module_filename
      return a_tuple(node, { t })
   end,

   ["pcall"] = special_pcall_xpcall,
   ["xpcall"] = special_pcall_xpcall,
   ["assert"] = function(self: NodeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
      self.fdb:set_truthy(node)
      local r = self:type_check_function_call(node, a, b, argdelta)
      if node.e2[1] then
         self:apply_facts_from(node, node.e2[1])
      end
      return r
   end,
   ["string.pack"] = function(self: NodeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
      if #b.tuple < 1 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects at least 1)")
      end

      local packstr = b.tuple[1]

      if packstr is StringType and packstr.literal and a is FunctionType then
         local st = packstr.literal
         local items, e = parse_pack_string(node, st)

         if e then
            if items then
               -- just a warning
               self:add_warning("hint", packstr, e)
            else
               return self:invalid_at(packstr, e)
            end
         end

         table.insert(items, 1, a_type(node, "string", {}))

         if #items ~= #b.tuple then
            return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects " .. #items .. ")")
         end

         return (self:type_check_function_call(node, a, b, argdelta, a_tuple(node, items), nil))
      else
         return (self:type_check_function_call(node, a, b, argdelta))
      end
   end,

   ["string.unpack"] = function(self: NodeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
      if #b.tuple < 2 or #b.tuple > 3 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 2 or 3)")
      end

      local packstr = b.tuple[1]

      local rets: TupleType

      if packstr is StringType and packstr.literal then
         local st = packstr.literal
         local items, e = parse_pack_string(node, st)

         if e then
            if items then
               -- just a warning
               self:add_warning("hint", packstr, e)
            else
               return self:invalid_at(packstr, e)
            end
         end

         table.insert(items, a_type(node, "integer", {}))

         -- set the returns to match the response
         rets = a_tuple(node, items)
      end

      return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
   end,

   ["string.format"] = function(self: NodeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
      if #b.tuple < 1 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects at least 1)")
      end

      local fstr = b.tuple[1]

      if fstr is StringType and fstr.literal and a is FunctionType then
         local st = fstr.literal
         local items, e = parse_format_string(node, st)

         if e then
            if items then
               -- just a warning
               self:add_warning("hint", fstr, e)
            else
               return self:invalid_at(fstr, e)
            end
         end

         table.insert(items, 1, a_type(node, "string", {}))

         if #items ~= #b.tuple then
            return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects " .. #items .. ")")
         end

         -- check the arguments now
         return (self:type_check_function_call(node, a, b, argdelta, a_tuple(node, items), nil))
      else
         return (self:type_check_function_call(node, a, b, argdelta))
      end
   end,

   ["string.match"] = function(self: NodeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
      if #b.tuple < 2 or #b.tuple > 3 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 2 or 3)")
      end

      local rets: TupleType
      local pat = b.tuple[2]

      if pat is StringType and pat.literal then
         local st = pat.literal
         local items, e = parse_pattern_string(node, st, true)

         if e then
            if items then
               -- just a warning
               self:add_warning("hint", pat, e)
            else
               return self:invalid_at(pat, e)
            end
         end

         -- set the returns to match the response
         rets = a_tuple(node, items)
      end
      return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
   end,

   ["string.find"] = function(self: NodeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
      if #b.tuple < 2 or #b.tuple > 4 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects at least 2 and at most 4)")
      end

      local plainarg = node.e2[4 + (argdelta or 0)]
      local pat = b.tuple[2]

      local rets: TupleType

      if pat is StringType and pat.literal
         and ((not plainarg) or (plainarg.kind == "boolean" and plainarg.tk == "false")) then
         -- we have a nice constant string that we can modify
         local st = pat.literal

         local items, e = parse_pattern_string(node, st, false)

         if e then
            if items then
               -- just a warning
               self:add_warning("hint", pat, e)
            else
               return self:invalid_at(pat, e)
            end
         end

         table.insert(items, 1, a_type(pat, "integer", {}))
         table.insert(items, 1, a_type(pat, "integer", {}))

         -- set the returns to match the response
         rets = a_tuple(node, items)
      end

      return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
   end,

   ["string.gmatch"] = function(self: NodeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
      if #b.tuple < 2 or #b.tuple > 3 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 2 or 3)")
      end

      local rets: TupleType
      local pat = b.tuple[2]

      if pat is StringType and pat.literal then
         local st = pat.literal
         local items, e = parse_pattern_string(node, st, true)

         if e then
            if items then
               -- just a warning
               self:add_warning("hint", pat, e)
            else
               return self:invalid_at(pat, e)
            end
         end

         -- set the returns to match the response
         rets = a_tuple(node, {
            a_function(node, {
               min_arity = 0,
               args = a_tuple(node, {}),
               rets = a_tuple(node, items),
            })
         })
      end

      return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
   end,

   ["string.gsub"] = function(self: NodeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
      -- if the second argument is a literal, we can parse it and change the matchers
      -- gsub: function(string, string, <matcher>, ? integer): string, integer

      if #b.tuple < 3 or #b.tuple > 4 then
         return self:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 3 or 4)")
      end
      local pat = b.tuple[2]
      local orig_t = b.tuple[3]
      local trepl = self:to_structural(orig_t)

      local has_fourth = b.tuple[4]

      local args: TupleType

      if pat is StringType and pat.literal then
         local st = pat.literal
         local items, e = parse_pattern_string(node, st, true)

         if e then
            if items then
               -- just a warning
               self:add_warning("hint", pat, e)
            else
               return self:invalid_at(pat, e)
            end
         end

         local i1 = items[1]

         -- we expect replarg to be one of:
         -- string
         -- {(items[1]):string}
         -- function(table.unpack(items)): ((string|integer|number)...)

         local replarg_type: Type

         local expected_pat_return = a_union(node, {
            a_type(node, "string", {}),
            a_type(node, "integer", {}),
            a_type(node, "number", {}),
         })
         if self:is_a(trepl, expected_pat_return) then
            -- fine
            replarg_type = expected_pat_return
         elseif trepl is MapType then
            replarg_type = a_map(node, i1, expected_pat_return)
         elseif trepl is RecordLikeType then
            if not (i1 is StringType) then
               self:invalid_at(trepl, "expected a table with integers as keys")
            end
            replarg_type = a_map(node, i1, expected_pat_return)
         elseif trepl is ArrayLikeType then
            if not (i1 is IntegerType) then
               self:invalid_at(trepl, "expected a table with strings as keys")
            end
            replarg_type = an_array(node, expected_pat_return)
         elseif trepl is FunctionType then
            local validftype = a_function(node, {
               min_arity = self.feat_arity and #items or 0,
               args = a_tuple(node, items),
               rets = a_vararg(node, { expected_pat_return }),
            })
            replarg_type = validftype
         end
         -- other types should be taken care of by the type_check_function_call below

         if replarg_type then
            args = a_tuple(node, {
               a_type(node, "string", {}),
               a_type(node, "string", {}),
               replarg_type,
               has_fourth and a_type(node, "integer", {}) or nil,
            })
         end
      end

      return (self:type_check_function_call(node, a, b, argdelta, args, nil))
   end,
}

return special_functions
