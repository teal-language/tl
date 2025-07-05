local types = require("teal.types")
local type Type = types.Type
local type TypeName = types.TypeName
local type GenericType = types.GenericType
local type TypeDeclType = types.TypeDeclType
local type NominalType = types.NominalType
local type ArrayLikeType = types.ArrayLikeType
local type RecordLikeType = types.RecordLikeType
local type TupleType = types.TupleType
local type MapType = types.MapType
local type FunctionType = types.FunctionType
local type AggregateType = types.AggregateType
local type EnumType = types.EnumType
local show_type = types.show_type

local type parser = require("teal.parser")
local type Node = parser.Node

local type variables = require("teal.variables")
local type Variable = variables.Variable

local util = require("teal.util")
local binary_search = util.binary_search
local sorted_keys = util.sorted_keys

local record type_reporter
   typecodes: {string:integer}

   record TypeCollector
      record Symbol
         x: integer
         y: integer
         name: string
         typ: Type
         skip: boolean
      end

      filename: string
      symbol_list: {Symbol}

      store_type: function(y: integer, x: integer, typ: Type)
      reserve_symbol_list_slot: function(Node)
      add_to_symbol_list: function(node: Node, name: string, t: Type)
      begin_symbol_list_scope: function(node: Node)
      rollback_symbol_list_scope: function()
      end_symbol_list_scope: function(node: Node)
   end

   record TypeInfo
      t: integer

      str: string
      file: string
      x: integer
      y: integer
      ref: integer -- NOMINAL
      typeargs: {{string, integer}} -- FUNCTION, RECORD (optional)
      fields: {string: integer} -- RECORD
      meta_fields: {string: integer} -- RECORD (optional)
      enums: {string} -- ENUM
      args: {{integer, string}} -- FUNCTION
      rets: {{integer, string}} -- FUNCTION
      vararg: boolean -- FUNCTION
      varret: boolean -- FUNCTION
      types: {integer} -- UNION, POLY, TUPLE
      keys: integer -- MAP
      values: integer -- MAP
      elements: integer -- ARRAY
   end

   record TypeReport
      type Symbol = {integer, integer, string, integer}

      by_pos: {string: {integer: {integer: integer}}}
      types: {integer: TypeInfo}
      symbols: {Symbol}
      symbols_by_file: {string: {Symbol}}
      globals: {string: integer}
   end

   record TypeReporter
      typeid_to_num: {integer: integer}
      typename_to_num: {TypeName: integer}
      next_num: integer
      tr: TypeReport

      get_typenum: function(self, Type): integer
   end
end

local type TypeCollector = type_reporter.TypeCollector
local type TypeInfo = type_reporter.TypeInfo
local type TypeReport = type_reporter.TypeReport
local type TypeReporter = type_reporter.TypeReporter

-- Implementation rationale:
-- * bit 31: (MSB) special ("any", "unknown", "invalid")
--   * "any" satisfies all Lua masks
-- * bits 30-27: if valid: other Teal types ("nominal", "poly", "union", "typevar")
-- * bits 24-26: reserved
-- * bits 20-23: abstract types ("interface")
-- * bits 16-19: if valid: Teal types ("array", "record", "map", "tuple", "enum") that map to a Lua type ("table", "string")
-- * bit 15: if not valid: value is unknown
-- * bits 8-14: reserved
-- * bits 0-7: (LSB) Lua types, one bit for each ("nil", "number", "boolean", "string", table, "function", "userdata", "thread")
--   * every valid value has a Lua type bit set
local typecodes: {string:integer} = {
   -- Lua types
   NIL                    = 0x00000001,
   NUMBER                 = 0x00000002,
   BOOLEAN                = 0x00000004,
   STRING                 = 0x00000008,
   TABLE                  = 0x00000010,
   FUNCTION               = 0x00000020,
   USERDATA               = 0x00000040,
   THREAD                 = 0x00000080,
   -- Teal types
   INTEGER                = 0x00010002,
   ENUM                   = 0x00010004,
   EMPTY_TABLE            = 0x00000008,
   ARRAY                  = 0x00010008,
   RECORD                 = 0x00020008,
   MAP                    = 0x00040008,
   TUPLE                  = 0x00080008,
   INTERFACE              = 0x00100008,
   SELF                   = 0x00200008,
   POLY                   = 0x20000020,
   UNION                  = 0x40000000,
   -- Indirect types
   NOMINAL                = 0x10000000,
   TYPE_VARIABLE          = 0x08000000,
   -- Special types
   ANY                    = 0xffffffff,
   UNKNOWN                = 0x80008000,
   INVALID                = 0x80000000,
}

--------------------------------------------------------------------------------
-- Type collection for report
--------------------------------------------------------------------------------

local typename_to_typecode <total>: {TypeName:integer} = {
   ["typevar"] = typecodes.TYPE_VARIABLE,
   ["typearg"] = typecodes.TYPE_VARIABLE,
   ["unresolved_typearg"] = typecodes.TYPE_VARIABLE,
   ["unresolvable_typearg"] = typecodes.TYPE_VARIABLE,
   ["function"] = typecodes.FUNCTION,
   ["array"] = typecodes.ARRAY,
   ["map"] = typecodes.MAP,
   ["tupletable"] = typecodes.TUPLE,
   ["interface"] = typecodes.INTERFACE,
   ["self"] = typecodes.SELF,
   ["record"] = typecodes.RECORD,
   ["enum"] = typecodes.ENUM,
   ["boolean"] = typecodes.BOOLEAN,
   ["string"] = typecodes.STRING,
   ["nil"] = typecodes.NIL,
   ["thread"] = typecodes.THREAD,
   ["userdata"] = typecodes.USERDATA,
   ["number"] = typecodes.NUMBER,
   ["integer"] = typecodes.INTEGER,
   ["union"] = typecodes.UNION,
   ["nominal"] = typecodes.NOMINAL,
   ["circular_require"] = typecodes.NOMINAL,
   ["boolean_context"] = typecodes.BOOLEAN,
   ["emptytable"] = typecodes.EMPTY_TABLE,
   ["unresolved_emptytable_value"] = typecodes.EMPTY_TABLE,
   ["poly"] = typecodes.POLY,
   ["any"] = typecodes.ANY,
   ["unknown"] = typecodes.UNKNOWN,
   ["invalid"] = typecodes.INVALID,
   -- types that should be skipped or not present:
   ["none"] = typecodes.UNKNOWN,
   ["tuple"] = typecodes.UNKNOWN,
   ["literal_table_item"] = typecodes.UNKNOWN,
   ["typedecl"] = typecodes.UNKNOWN,
   ["generic"] = typecodes.UNKNOWN,
   ["*"] = typecodes.UNKNOWN,
}

local skip_types: {TypeName: boolean} = {
   ["none"] = true,
   ["tuple"] = true,
   ["literal_table_item"] = true,
}

-- mark array for JSON-encoded reports in `tl types`
local function mark_array<T>(x: T): T
   local arr = x as {boolean}
   arr[0] = false
   return x
end

function type_reporter.new(): TypeReporter
   local self: TypeReporter = setmetatable({
      next_num = 1,
      typeid_to_num = {},
      typename_to_num = {},
      tr = setmetatable({
         by_pos = {},
         types = {},
         symbols_by_file = {},
         globals = {},
      }, { __index = TypeReport }),
   }, { __index = TypeReporter })

   local names = {}
   for name, _ in pairs(types.simple_types) do
      table.insert(names, name)
   end
   table.sort(names)

   for _, name in ipairs(names) do
      local ti: TypeInfo = {
         t = assert(typename_to_typecode[name]),
         str = name,
      }
      local n = self.next_num
      self.typename_to_num[name] = n
      self.tr.types[n] = ti
      self.next_num = self.next_num + 1
   end

   return self
end

function TypeReporter:store_function(ti: TypeInfo, rt: FunctionType)
   local args: {{integer, string}} = {}
   for _, fnarg in ipairs(rt.args.tuple) do
      table.insert(args, mark_array { self:get_typenum(fnarg), nil })
   end
   ti.args = mark_array(args)
   local rets: {{integer, string}} = {}
   for _, fnarg in ipairs(rt.rets.tuple) do
      table.insert(rets, mark_array { self:get_typenum(fnarg), nil })
   end
   ti.rets = mark_array(rets)
   ti.vararg = not not rt.args.is_va
   ti.varret = not not rt.rets.is_va
end

function TypeReporter:get_typenum(t: Type): integer
   -- try simple types first
   local n = self.typename_to_num[t.typename]
   if n then
      return n
   end

   assert(t.typeid)
   -- try by typeid
   n = self.typeid_to_num[t.typeid]
   if n then
      return n
   end

   local tr = self.tr

   -- it's a new entry: store and increment
   n = self.next_num

   local rt = t
   if rt is TupleType and #rt.tuple == 1 then
      rt = rt.tuple[1]
   end

   if rt is TypeDeclType then
      return self:get_typenum(rt.def)
   end

   local typeargs: {{string, integer}}
   if rt is GenericType then
      typeargs = mark_array {}
      for _, typearg in ipairs(rt.typeargs) do
         local tn: integer
         if typearg.constraint then
            tn = self:get_typenum(typearg.constraint)
         end
         table.insert(typeargs, mark_array { typearg.typearg, tn })
      end
      rt = rt.t
   end

   local ti: TypeInfo = {
      t = assert(typename_to_typecode[rt.typename]),
      str = show_type(t, true),
      file = t.f,
      y = t.y,
      x = t.x,
      typeargs = typeargs,
   }
   tr.types[n] = ti
   self.typeid_to_num[t.typeid] = n
   self.next_num = self.next_num + 1

   if t is NominalType then
      if t.found then
         ti.ref = self:get_typenum(t.found)
      end
      if t.resolved then
         rt = t
      end
   end
   assert(not (rt is TypeDeclType))

   if rt is RecordLikeType then
      -- store record field info
      local r = {}
      for _, k in ipairs(rt.field_order) do
         local v = rt.fields[k]
         r[k] = self:get_typenum(v)
      end
      ti.fields = r
      if rt.meta_fields then
         -- store record metafield info
         local m = {}
         for _, k in ipairs(rt.meta_field_order) do
            local v = rt.meta_fields[k]
            m[k] = self:get_typenum(v)
         end
         ti.meta_fields = m
      end
   end

   if rt is ArrayLikeType then
      ti.elements = self:get_typenum(rt.elements)
   end

   if rt is MapType then
      ti.keys = self:get_typenum(rt.keys)
      ti.values = self:get_typenum(rt.values)
   elseif rt is EnumType then
      ti.enums = mark_array(sorted_keys(rt.enumset))
   elseif rt is FunctionType then
      self:store_function(ti, rt)
   elseif rt is AggregateType then
      local tis = {}
      for _, pt in ipairs(rt.types) do
         table.insert(tis, self:get_typenum(pt))
      end
      ti.types = mark_array(tis)
   end

   return n
end

function TypeReporter:add_field(rtype: RecordLikeType, fname: string, ftype: Type)
   local n = self:get_typenum(rtype)
   local ti = self.tr.types[n]
   assert(ti.fields)
   ti.fields[fname] = self:get_typenum(ftype)
end

function TypeReporter:set_ref(nom: NominalType, resolved: Type)
   local n = self:get_typenum(nom)
   local ti = self.tr.types[n]
   ti.ref = self:get_typenum(resolved)
end

function TypeReporter:get_collector(filename: string): TypeCollector
   local collector: TypeCollector = {
      filename = filename,
      symbol_list = {},
   }

   local ft: {integer:{integer:integer}} = {}
   self.tr.by_pos[filename] = ft

   local symbol_list = collector.symbol_list
   local symbol_list_n = 0

   collector.store_type = function(y: integer, x: integer, typ: Type)
      if not typ or skip_types[typ.typename] then
         return
      end

      local yt = ft[y]
      if not yt then
         yt = {}
         ft[y] = yt
      end

      yt[x] = self:get_typenum(typ)
   end

   collector.reserve_symbol_list_slot = function(node: Node)
      symbol_list_n = symbol_list_n + 1
      node.symbol_list_slot = symbol_list_n
   end

   collector.add_to_symbol_list = function(node: Node, name: string, t: Type)
      if not node then
         return
      end
      local slot: integer
      if node.symbol_list_slot then
         slot = node.symbol_list_slot
      else
         symbol_list_n = symbol_list_n + 1
         slot = symbol_list_n
      end
      symbol_list[slot] = { y = node.y, x = node.x, name = name, typ = t }
   end

   collector.begin_symbol_list_scope = function(node: Node)
      symbol_list_n = symbol_list_n + 1
      symbol_list[symbol_list_n] = { y = node.y, x = node.x, name = "@{" }
   end

   collector.rollback_symbol_list_scope = function()
      while symbol_list[symbol_list_n].name ~= "@{" do
         symbol_list[symbol_list_n] = nil
         symbol_list_n = symbol_list_n - 1
      end
   end

   collector.end_symbol_list_scope = function(node: Node)
      if symbol_list[symbol_list_n].name == "@{" then
         symbol_list[symbol_list_n] = nil
         symbol_list_n = symbol_list_n - 1
      else
         symbol_list_n = symbol_list_n + 1
         symbol_list[symbol_list_n] = { y = assert(node.yend), x = assert(node.xend), name = "@}" }
      end
   end

   return collector
end

function TypeReporter:store_result(collector: TypeCollector, globals: {string:Variable})
   local tr = self.tr

   local filename = collector.filename
   local symbol_list = collector.symbol_list

   tr.by_pos[filename][0] = nil

   -- mark unneeded scope blocks to be skipped
   do
      local n = 0 -- number of symbols in current scope
      local p = 0 -- opening position of current scope block
      local n_stack, p_stack = {}, {}
      local level = 0
      for i, s in ipairs(symbol_list) do
         if s.typ then
            n = n + 1
         elseif s.name == "@{" then
            level = level + 1
            n_stack[level], p_stack[level] = n, p -- push current scope
            n, p = 0, i -- begin new scope
         else
            if n == 0 then -- nothing declared in this scope
               symbol_list[p].skip = true -- skip @{
               s.skip = true -- skip @}
            end
            n, p = n_stack[level], p_stack[level] -- pop previous scope
            level = level - 1
         end
      end
   end

   local symbols: {TypeReport.Symbol} = mark_array {}
   tr.symbols_by_file[filename] = symbols

   -- resolve scope cross references, skipping unneeded scope blocks
   do
      local stack = {}
      local level = 0
      local i = 0
      for _, s in ipairs(symbol_list) do
         if not s.skip then
            i = i + 1
            local id: integer
            if s.typ then
               id = self:get_typenum(s.typ)
            elseif s.name == "@{" then
               level = level + 1
               stack[level] = i
               id = -1 -- will be overwritten
            else
               local other = stack[level]
               level = level - 1
               symbols[other][4] = i -- overwrite id from @{
               id = other - 1
            end
            local sym = mark_array({ s.y, s.x, s.name, id })
            table.insert(symbols, sym)
         end
      end
   end

   local gkeys = sorted_keys(globals)
   for _, name in ipairs(gkeys) do
      if name:sub(1, 1) ~= "@" then
         local var = globals[name]
         tr.globals[name] = self:get_typenum(var.t)
      end
   end

   if not tr.symbols then
      tr.symbols = tr.symbols_by_file[filename]
   end
end

function TypeReporter:get_report(): TypeReport
   return self.tr
end

--------------------------------------------------------------------------------
-- Type report
--------------------------------------------------------------------------------

function TypeReport:symbols_in_scope(filename: string, y: integer, x: integer): {string:integer}
   local function find(symbols: {TypeReport.Symbol}, at_y: integer, at_x: integer): integer
      local function le(a: {integer, integer}, b: {integer, integer}): boolean
         return a[1] < b[1]
            or (a[1] == b[1] and a[2] <= b[2])
      end
      return binary_search(symbols, {at_y, at_x}, le) or 0
   end

   local ret: {string:integer} = {}

   local symbols = self.symbols_by_file[filename]
   if not symbols then
      return ret
   end

   local n = find(symbols, y, x)

   while n >= 1 do
      local s = symbols[n]
      local symbol_name = s[3]
      if symbol_name == "@{" then
         n = n - 1
      elseif symbol_name == "@}" then
         n = s[4]
      else
         if ret[symbol_name] == nil then
            ret[symbol_name] = s[4]
         end
         n = n - 1
      end
   end

   return ret
end

return type_reporter
