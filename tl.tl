
local VERSION = "0.24.6+dev"

local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG
local TL_DEBUG_FACTS = tldebug.TL_DEBUG_FACTS
local TL_DEBUG_MAXLINE = tldebug.TL_DEBUG_MAXLINE

local errors = require("teal.errors")
local type Error = errors.Error
local type WarningKind = errors.WarningKind

local lexer = require("teal.lexer")

local binary_search = require("teal.binary_search")

local prelude = require("teal.embed.prelude")
local stdlib = require("teal.embed.stdlib")

local types = require("teal.types")
local type Type = types.Type
local type GenericType = types.GenericType
local type FirstOrderType = types.FirstOrderType
local type StringType = types.StringType
local type NumericType = types.NumericType
local type IntegerType = types.IntegerType
local type BooleanType = types.BooleanType
local type BooleanContextType = types.BooleanContextType
local type TypeDeclType = types.TypeDeclType
local type LiteralTableItemType = types.LiteralTableItemType
local type NominalType = types.NominalType
local type SelfType = types.SelfType
local type ArrayLikeType = types.ArrayLikeType
local type ArrayType = types.ArrayType
local type RecordLikeType = types.RecordLikeType
local type RecordType = types.RecordType
local type InterfaceType = types.InterfaceType
local type InvalidType = types.InvalidType
local type UnknownType = types.UnknownType
local type TupleType = types.TupleType
local type TypeArgType = types.TypeArgType
local type UnresolvedTypeArgType = types.UnresolvedTypeArgType
local type UnresolvableTypeArgType = types.UnresolvableTypeArgType
local type TypeVarType = types.TypeVarType
local type MapType = types.MapType
local type NilType = types.NilType
local type EmptyTableType = types.EmptyTableType
local type UnresolvedEmptyTableValueType = types.UnresolvedEmptyTableValueType
local type FunctionType = types.FunctionType
local type AggregateType = types.AggregateType
local type UnionType = types.UnionType
local type TupleTableType = types.TupleTableType
local type PolyType = types.PolyType
local type EnumType = types.EnumType
local type FirstClassType = types.FirstClassType
local type TypeName = types.TypeName
local type Where = types.Where
local type SpecialFunctionName = types.SpecialFunctionName
local a_type = types.a_type
local edit_type = types.edit_type
local is_unknown = types.is_unknown
local is_valid_union = types.is_valid_union
local shallow_copy_new_type = types.shallow_copy_new_type
local show_type = types.show_type
local show_type_base = types.show_type_base
local simple_types = types.simple_types

local parser = require("teal.parser")
local type Attribute = parser.Attribute
local type Node = parser.Node
local type NodeKind = parser.NodeKind
local type ParseLang = parser.ParseLang
local node_is_funcall = parser.node_is_funcall
local node_is_require_call = parser.node_is_require_call

local facts = require("teal.facts")
local type Fact = facts.Fact
local type FactType = facts.FactType
local type IsFact = facts.IsFact
local type EqFact = facts.EqFact
local type AndFact = facts.AndFact
local type OrFact = facts.OrFact
local type NotFact = facts.NotFact
local type TruthyFact = facts.TruthyFact

local record Errors
   filename: string
   errors: {Error}
   warnings: {Error}
   unknown_dots: {string:boolean}
end

local record tl
   enum LoadMode
      "b"
      "t"
      "bt"
      "cb"
      "ct"
      "cbt"
   end
   type LoadFunction = function(...:any): any...

   enum GenCompat
      "off"
      "optional"
      "required"
   end

   enum GenTarget
      "5.1"
      "5.3"
      "5.4"
   end

   enum Feat
      "on"
      "off"
   end

   record GenerateOptions
      preserve_indent: boolean
      preserve_newlines: boolean
      preserve_hashbang: boolean
   end

   record CheckOptions
      feat_lax: Feat
      feat_arity: Feat
      gen_compat: GenCompat
      gen_target: GenTarget
      run_internal_compiler_checks: boolean
   end

   record Env
      globals: {string:Variable}
      modules: {string:Type}
      module_filenames: {string:string}
      loaded: {string:Result}
      loaded_order: {string}
      reporter: TypeReporter
      keep_going: boolean
      report_types: boolean
      defaults: CheckOptions
   end

   record Result
      filename: string
      ast: Node
      type: Type
      syntax_errors: {Error}
      type_errors: {Error}
      gen_error: string
      warnings: {Error}
      env: Env
      dependencies: {string:string} -- module name, file found
   end

   typecodes: {string:integer}

   record TypeInfo
      t: integer

      str: string
      file: string
      x: integer
      y: integer
      ref: integer -- NOMINAL
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

   record EnvOptions
      defaults: CheckOptions
      predefined_modules: {string}
   end

   -- abstract type
   type Node = types.Node

   -----------------------------------------------------------------------------
   -- Public API
   -----------------------------------------------------------------------------

   check: function(Node, ? string, ? CheckOptions, ? Env): Result, string
   gen: function(string, ? Env, ? GenerateOptions): string, Result
   generate: function(ast: Node, gen_target: GenTarget, opts?: GenerateOptions): string, string
   get_token_at: function(tks: {Token}, y: integer, x: integer): string
   lex: function(input: string, filename: string): {Token}, {Error}
   load: function(string, ? string, ? LoadMode, ...: {any:any}): LoadFunction, string
   loader: function()
   new_env: function(? EnvOptions): Env, string
   parse: function(input: string, filename: string, parse_lang?: ParseLang): Node, {Error}, {string}
   parse_program: function(tokens: {Token}, errs: {Error}, filename?: string, parse_lang?: ParseLang): Node, {string}
   check_file: function(filename: string, env?: Env, fd?: FILE): (Result, string)
   check_string: function(input: string, env?: Env, filename?: string, parse_lang?: ParseLang): Result
   search_module: function(module_name: string, search_all: boolean): string, FILE, {string}
   symbols_in_scope: function(tr: TypeReport, y: integer, x: integer, filename: string): {string:integer}
   target_from_lua_version: function(str: string): GenTarget
   version: function(): string

   path: string -- if set be the user, this overrides package.path for Teal

   -----------------------------------------------------------------------------
   -- Re-exported entries
   -----------------------------------------------------------------------------

   type WarningKind = errors.WarningKind
   warning_kinds: {WarningKind:boolean}
   type Error = errors.Error
   type TokenKind = lexer.TokenKind
   type Comment = lexer.Comment
   type Token = lexer.Token

   -----------------------------------------------------------------------------
   -- Deprecated, mantained for backwards compatibility:
   -----------------------------------------------------------------------------

   type CompatMode = GenCompat
   type PrettyPrintOptions = GenerateOptions
   type TargetMode = GenTarget

   record TypeCheckOptions
      lax: boolean
      filename: string
      module_name: string
      gen_compat: tl.CompatMode
      gen_target: tl.TargetMode
      env: Env
      run_internal_compiler_checks: boolean
   end

   init_env: function(? boolean, ? boolean | tl.CompatMode, ? tl.TargetMode, ? {string}): Env, string
   pretty_print_ast: function(ast: Node, gen_target?: tl.TargetMode, mode?: boolean | tl.PrettyPrintOptions): string, string
   process: function(filename: string, env?: Env, fd?: FILE): Result, string
   process_string: function(input: string, is_lua: boolean, env: Env, filename: string, _module_name: string): Result
   type_check: function(Node, TypeCheckOptions): Result, string

   -----------------------------------------------------------------------------
   -- Private data:
   -----------------------------------------------------------------------------

   package_loader_env: Env
   load_envs: { {any:any} : Env }
end

tl.warning_kinds = errors.warning_kinds
tl.lex = lexer.lex
tl.get_token_at = lexer.get_token_at
tl.parse = parser.parse
tl.parse_program = parser.parse_program

local record TypeReporter
   typeid_to_num: {integer: integer}
   typename_to_num: {TypeName: integer}
   next_num: integer
   tr: TypeReport

   get_typenum: function(self, Type): integer
end

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
tl.typecodes = {
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

local type Env = tl.Env
local type EnvOptions = tl.EnvOptions
local type Feat = tl.Feat
local type GenCompat = tl.GenCompat
local type GenTarget = tl.GenTarget
local type LoadFunction = tl.LoadFunction
local type LoadMode = tl.LoadMode
local type GenerateOptions = tl.GenerateOptions
local type Result = tl.Result
local type CheckOptions = tl.CheckOptions
local type TypeInfo = tl.TypeInfo
local type TypeReport = tl.TypeReport

local DEFAULT_GEN_COMPAT <const>: GenCompat = "optional"
local DEFAULT_GEN_TARGET <const>: GenTarget = "5.3"

local enum Specialization
   "narrow"
   "narrowed_declaration"
   "localizing"
   "widen"
end

local record Variable
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

local record Scope
   vars: {string:Variable}
   labels: {string:Node}
   pending_labels: {string:{Node}}
   pending_nominals: {string:{NominalType}}
   pending_global_types: {string:boolean}
   narrows: {string:boolean}
   widens: {string:boolean}
   is_transaction: boolean
end

local function shallow_copy_table<T>(t: T): T
   local copy: {any:any} = {}
   for k, v in pairs(t as {any:any}) do
      copy[k] = v
   end
   return copy as T
end

local macroexp a_typedecl(w: Where, def: Type): TypeDeclType
   return a_type(w, "typedecl", { def = def } as TypeDeclType)
end

local macroexp a_union(w: Where, t: {Type}): UnionType
   return a_type(w, "union", { types = t } as UnionType)
end

local macroexp a_self(w: Where, display_type: Type): SelfType
   return a_type(w, "self", { display_type = display_type } as SelfType)
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

local macroexp an_array(w: Where, t: Type): ArrayType
   return a_type(w, "array", { elements = t } as ArrayType)
end

local macroexp a_map(w: Where, k: Type, v: Type): MapType
   return a_type(w, "map", { keys = k, values = v } as MapType)
end

local macroexp a_nominal(w: Where, names: {string}): NominalType
   return a_type(w, "nominal", { names = names } as NominalType)
end

local macroexp an_invalid(w: Where): InvalidType
   return a_type(w, "invalid", {} as InvalidType)
end

local macroexp an_unknown(w: Where): UnknownType
   return a_type(w, "unknown", {} as UnknownType)
end

local function Err(msg: string): Error
   return { msg = msg }
end

--------------------------------------------------------------------------------
-- AST traversal
--------------------------------------------------------------------------------

local record VisitorCallbacks<S, N, T>
   before: function(S, N)
   before_exp: function(S, {N}, {T})
   before_arguments: function(S, {N}, {T})
   before_statements: function(S, {N}, {T})
   before_e2: function(S, {N}, {T})
   after: function(S, N, {T}): T
end

local enum VisitorExtraCallback
   "before_arguments"
   "before_statements"
   "before_exp"
   "before_e2"
end

local type VisitorAfter = function<S, N, T>(S, N, {T}, T): T

local record Visitor<S, K, N, T>
   cbs: {K:VisitorCallbacks<S, N, T>}
   after: VisitorAfter<S, N, T>
   allow_missing_cbs: boolean
end

local enum MetaMode
   "meta"
end

local function fields_of(t: RecordLikeType, meta?: MetaMode): (function(): string, Type)
   local i = 1
   local field_order, fields: {string}, {string:Type}
   if meta then
      field_order, fields = t.meta_field_order, t.meta_fields
   else
      field_order, fields = t.field_order, t.fields
   end
   if not fields then
      return function(): string, Type
      end
   end
   return function(): string, Type
      local name = field_order[i]
      if not name then
         return nil
      end
      i = i + 1
      return name, fields[name]
   end
end

local tl_debug_indent = 0
local record DebugEntry
   mark: string
   y: integer
   x: integer
   msg: string
end
local tl_debug_entry: DebugEntry = nil
local tl_debug_y = 1

local function tl_debug_loc(y: integer, x: integer): string
   return (tostring(y) or "?") .. ":" .. (tostring(x) or "?")
end

local function tl_debug_indent_push(mark: string, y: integer, x: integer, fmt: string, ...: any)
   if tl_debug_entry then
      if tl_debug_entry.y and (tl_debug_entry.y > tl_debug_y) then
         io.stderr:write("\n")
         tl_debug_y = tl_debug_entry.y
      end
      io.stderr:write(("   "):rep(tl_debug_indent) .. tl_debug_entry.mark .. " " ..
                      tl_debug_loc(tl_debug_entry.y, tl_debug_entry.x) .. " " ..
                      tl_debug_entry.msg .. "\n")
      io.stderr:flush()
      tl_debug_entry = nil
      tl_debug_indent = tl_debug_indent + 1
   end
   tl_debug_entry = {
      mark = mark,
      y = y,
      x = x,
      msg = fmt:format(...)
   }
end

local function tl_debug_indent_pop(mark: string, single: string, y: integer, x: integer, fmt?: string, ...: any)
   if tl_debug_entry then
      local msg = tl_debug_entry.msg
      if fmt then
         msg = fmt:format(...)
      end
      if y and (y > tl_debug_y) then
         io.stderr:write("\n")
         tl_debug_y = y
      end
      io.stderr:write(("   "):rep(tl_debug_indent) .. single .. " " .. tl_debug_loc(y, x) .. " " .. msg .. "\n")
      io.stderr:flush()
      tl_debug_entry = nil
   else
      tl_debug_indent = tl_debug_indent - 1
      if fmt then
         io.stderr:write(("   "):rep(tl_debug_indent) .. mark .. " " .. fmt:format(...) .. "\n")
         io.stderr:flush()
      end
   end
end

local recurse_type: function<S, T>(s: S, ast: Type, visit: Visitor<S, TypeName, Type, T>): T

local function aggregate_type_walker<S, T>(s: S, ast: AggregateType, visit: Visitor<S, TypeName, Type, T>): {T}
   local xs: {T} = {}
   for i, child in ipairs(ast.types) do
      xs[i] = recurse_type(s, child, visit)
   end
   return xs
end

local function record_like_type_walker<S, T>(s: S, ast: RecordLikeType, visit: Visitor<S, TypeName, Type, T>): {T}
   local xs: {T} = {}
   if ast.interface_list then
      for _, child in ipairs(ast.interface_list) do
         table.insert(xs, recurse_type(s, child, visit))
      end
   end
   if ast.elements then
      table.insert(xs, recurse_type(s, ast.elements, visit))
   end
   if ast.fields then
      for _, child in fields_of(ast) do
         table.insert(xs, recurse_type(s, child, visit))
      end
   end
   if ast.meta_fields then
      for _, child in fields_of(ast, "meta") do
         table.insert(xs, recurse_type(s, child, visit))
      end
   end
   return xs
end

local type_walkers <total>: {TypeName: boolean | function<S, T>(s: S, ast: Type, visit: Visitor<S, TypeName, Type, T>): {T}} = {
   ["typevar"] = false,
   ["unresolved_typearg"] = false,
   ["unresolvable_typearg"] = false,
   ["self"] = false,
   ["enum"] = false,
   ["boolean"] = false,
   ["string"] = false,
   ["nil"] = false,
   ["thread"] = false,
   ["userdata"] = false,
   ["number"] = false,
   ["integer"] = false,
   ["circular_require"] = false,
   ["boolean_context"] = false,
   ["emptytable"] = false,
   ["unresolved_emptytable_value"] = false,
   ["any"] = false,
   ["unknown"] = false,
   ["invalid"] = false,
   ["none"] = false,
   ["*"] = false,

   ["generic"] = function<S, T>(s: S, ast: GenericType, visit: Visitor<S, TypeName, Type, T>): {T}
      local xs: {T} = {}
      for _, child in ipairs(ast.typeargs) do
         table.insert(xs, recurse_type(s, child, visit))
      end
      table.insert(xs, recurse_type(s, ast.t, visit))
      return xs
   end,
   ["tuple"] = function<S, T>(s: S, ast: TupleType, visit: Visitor<S, TypeName, Type, T>): {T}
      local xs: {T} = {}
      for i, child in ipairs(ast.tuple) do
         xs[i] = recurse_type(s, child, visit)
      end
      return xs
   end,
   ["union"] = aggregate_type_walker,
   ["tupletable"] = aggregate_type_walker,
   ["poly"] = aggregate_type_walker,
   ["map"] = function<S, T>(s: S, ast: MapType, visit: Visitor<S, TypeName, Type, T>): {T}
      return {
         recurse_type(s, ast.keys, visit),
         recurse_type(s, ast.values, visit),
      }
   end,
   ["record"] = record_like_type_walker,
   ["interface"] = record_like_type_walker,
   ["function"] = function<S, T>(s: S, ast: FunctionType, visit: Visitor<S, TypeName, Type, T>): {T}
      local xs: {T} = {}
      if ast.args then
         for _, child in ipairs(ast.args.tuple) do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
      if ast.rets then
         for _, child in ipairs(ast.rets.tuple) do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
      return xs
   end,
   ["nominal"] = function<S, T>(s: S, ast: NominalType, visit: Visitor<S, TypeName, Type, T>): {T}
      local xs: {T} = {}
      if ast.typevals then
         for _, child in ipairs(ast.typevals) do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
      return xs
   end,
   ["typearg"] = function<S, T>(s: S, ast: TypeArgType, visit: Visitor<S, TypeName, Type, T>): {T}
      return {
         ast.constraint and recurse_type(s, ast.constraint, visit)
      }
   end,
   ["array"] = function<S, T>(s: S, ast: ArrayType, visit: Visitor<S, TypeName, Type, T>): {T}
      return {
         recurse_type(s, ast.elements, visit)
      }
   end,
   ["literal_table_item"] = function<S, T>(s: S, ast: LiteralTableItemType, visit: Visitor<S, TypeName, Type, T>): {T}
      return {
         recurse_type(s, ast.ktype, visit),
         recurse_type(s, ast.vtype, visit),
      }
   end,
   ["typedecl"] = function<S, T>(s: S, ast: TypeDeclType, visit: Visitor<S, TypeName, Type, T>): {T}
      return {
         recurse_type(s, ast.def, visit)
      }
   end,
}

recurse_type = function<S, T>(s: S, ast: Type, visit: Visitor<S, TypeName, Type, T>): T
   local kind = ast.typename

   if TL_DEBUG then
      tl_debug_indent_push("---", ast.y, ast.x, "[%s] = %s", kind, show_type(ast))
   end

   local cbs = visit.cbs
   local cbkind = cbs and cbs[kind]
   if cbkind then
      local cbkind_before = cbkind.before
      if cbkind_before then
         cbkind_before(s, ast)
      end
   end

   local xs: {T}
   local walker = type_walkers[ast.typename]
   if not walker is boolean then
      xs = walker(s, ast, visit)
   end

   local ret: T
   local cbkind_after = cbkind and cbkind.after
   if cbkind_after then
      ret = cbkind_after(s, ast, xs)
   end
   local visit_after = visit.after
   if visit_after then
      ret = visit_after(s, ast, xs, ret)
   end

   if TL_DEBUG then
      tl_debug_indent_pop("---", "---", ast.y, ast.x)
   end

   return ret
end

local function recurse_typeargs<S, T>(s: S, ast: Node, visit_type: Visitor<S, TypeName, Type, T>)
   if ast.typeargs then
      for _, typearg in ipairs(ast.typeargs) do
         recurse_type(s, typearg, visit_type)
      end
   end
end

local function extra_callback<S, T>(name: VisitorExtraCallback,
                                    s: S,
                                    ast: Node,
                                    xs: {T},
                                    visit_node: Visitor<S, NodeKind, Node, T>)
   local cbs = visit_node.cbs
   if not cbs then return end
   local nbs = cbs[ast.kind]
   if not nbs then return end
   local bs = nbs[name]
   if not bs then return end
   bs(s, ast, xs)
end

local no_recurse_node: {NodeKind : boolean} = {
   ["..."] = true,
   ["nil"] = true,
   ["cast"] = true,
   ["goto"] = true,
   ["break"] = true,
   ["label"] = true,
   ["number"] = true,
   ["pragma"] = true,
   ["string"] = true,
   ["boolean"] = true,
   ["integer"] = true,
   ["variable"] = true,
   ["error_node"] = true,
   ["identifier"] = true,
   ["type_identifier"] = true,
}

local function recurse_node<S, T>(s: S, root: tl.Node,
                                  visit_node: Visitor<S, NodeKind, Node, T>,
                                  visit_type: Visitor<S, TypeName, Type, T>): T
   if not root then
      -- parse error
      return
   end

   local recurse: function(tl.Node): T

   local function walk_children(ast: Node, xs: {T})
      for i, child in ipairs(ast) do
         xs[i] = recurse(child)
      end
   end

   local function walk_vars_exps(ast: Node, xs: {T})
      xs[1] = recurse(ast.vars)
      if ast.decltuple then
         xs[2] = recurse_type(s, ast.decltuple, visit_type)
      end
      extra_callback("before_exp", s, ast, xs, visit_node)
      if ast.exps then
         xs[3] = recurse(ast.exps)
      end
   end

   local function walk_named_function(ast: Node, xs: {T})
      recurse_typeargs(s, ast, visit_type)
      xs[1] = recurse(ast.name)
      xs[2] = recurse(ast.args)
      xs[3] = recurse_type(s, ast.rets, visit_type)
      extra_callback("before_statements", s, ast, xs, visit_node)
      xs[4] = recurse(ast.body)
   end

   local walkers: {NodeKind : function(Node, {T})} = {
      ["op"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.e1)
         local p1 = ast.e1.op and ast.e1.op.prec or nil
         if ast.op.op == ":" and ast.e1.kind == "string" then
            p1 = -999
         end
         xs[2] = p1 as T
         if ast.op.arity == 2 then
            extra_callback("before_e2", s, ast, xs, visit_node)
            if ast.op.op == "is" or ast.op.op == "as" then
               xs[3] = recurse_type(s, ast.e2.casttype, visit_type)
            else
               xs[3] = recurse(ast.e2)
            end
            xs[4] = (ast.e2.op and ast.e2.op.prec) as T
         end
      end,

      ["statements"] = walk_children,
      ["argument_list"] = walk_children,
      ["literal_table"] = walk_children,
      ["variable_list"] = walk_children,
      ["expression_list"] = walk_children,

      ["literal_table_item"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.key)
         xs[2] = recurse(ast.value)
         if ast.itemtype then
            xs[3] = recurse_type(s, ast.itemtype, visit_type)
         end
      end,

      ["assignment"] = walk_vars_exps,
      ["local_declaration"] = walk_vars_exps,
      ["global_declaration"] = walk_vars_exps,

      ["local_type"] = function(ast: Node, xs: {T})
         -- TODO need to recurse typeargs
         -- recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.var)
         xs[2] = recurse(ast.value)
      end,

      ["global_type"] = function(ast: Node, xs: {T})
         -- TODO need to recurse typeargs
         -- recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.var)
         if ast.value then
            xs[2] = recurse(ast.value)
         end
      end,

      ["if"] = function(ast: Node, xs: {T})
         for _, e in ipairs(ast.if_blocks) do
            table.insert(xs, recurse(e))
         end
      end,

      ["if_block"] = function(ast: Node, xs: {T})
         if ast.exp then
            xs[1] = recurse(ast.exp)
         end
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[2] = recurse(ast.body)
      end,

      ["while"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.exp)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[2] = recurse(ast.body)
      end,

      ["repeat"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.body)
         xs[2] = recurse(ast.exp)
      end,

      ["macroexp"] = function(ast: Node, xs: {T})
         recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.args)
         xs[2] = recurse_type(s, ast.rets, visit_type)
         extra_callback("before_exp", s, ast, xs, visit_node)
         xs[3] = recurse(ast.exp)
      end,

      ["function"] = function(ast: Node, xs: {T})
         recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.args)
         xs[2] = recurse_type(s, ast.rets, visit_type)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[3] = recurse(ast.body)
      end,
      ["local_function"] = walk_named_function,
      ["global_function"] = walk_named_function,
      ["record_function"] = function(ast: Node, xs: {T})
         recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.fn_owner)
         xs[2] = recurse(ast.name)
         extra_callback("before_arguments", s, ast, xs, visit_node)
         xs[3] = recurse(ast.args)
         xs[4] = recurse_type(s, ast.rets, visit_type)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[5] = recurse(ast.body)
      end,
      ["local_macroexp"] = function(ast: Node, xs: {T})
         -- TODO: generic macroexp
         xs[1] = recurse(ast.name)
         xs[2] = recurse(ast.macrodef.args)
         xs[3] = recurse_type(s, ast.macrodef.rets, visit_type)
         extra_callback("before_exp", s, ast, xs, visit_node)
         xs[4] = recurse(ast.macrodef.exp)
      end,

      ["forin"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.vars)
         xs[2] = recurse(ast.exps)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[3] = recurse(ast.body)
      end,

      ["fornum"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.var)
         xs[2] = recurse(ast.from)
         xs[3] = recurse(ast.to)
         xs[4] = ast.step and recurse(ast.step)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[5] = recurse(ast.body)
      end,

      ["return"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.exps)
      end,

      ["do"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.body)
      end,

      ["paren"] = function(ast: Node, xs:{T})
         xs[1] = recurse(ast.e1)
      end,

      ["newtype"] = function(ast: Node, xs:{T})
         xs[1] = recurse_type(s, ast.newtype, visit_type)
      end,

      ["argument"] = function(ast: Node, xs:{T})
         if ast.argtype then
            xs[1] = recurse_type(s, ast.argtype, visit_type)
         end
      end,
   }

   if not visit_node.allow_missing_cbs and not visit_node.cbs then
      error("missing cbs in visit_node")
   end
   local visit_after = visit_node.after

   recurse = function(ast: Node): T
      local xs: {T} = {}
      local kind = assert(ast.kind)
      local kprint: string

      local cbs = visit_node.cbs
      local cbkind = cbs and cbs[kind]
      if cbkind then
         if cbkind.before then
            cbkind.before(s, ast)
         end
      end

      if TL_DEBUG then
         if ast.y > TL_DEBUG_MAXLINE then
            error("Halting execution at input line " .. ast.y)
         end
         kprint = kind == "op" and "op " .. ast.op.op
                  or kind == "identifier" and "identifier " .. ast.tk
                  or kind
         tl_debug_indent_push("{{{", ast.y, ast.x, "[%s]", kprint)
      end

      local fn = walkers[kind]
      if fn then
         fn(ast, xs)
      else
         assert(no_recurse_node[kind])
      end

      local ret: T
      local cbkind_after = cbkind and cbkind.after
      if cbkind_after then
         ret = cbkind_after(s, ast, xs)
      end
      if visit_after then
         ret = visit_after(s, ast, xs, ret)
      end

      if TL_DEBUG then
         local typ = ast.debug_type and " = " .. show_type(ast.debug_type) or ""
         tl_debug_indent_pop("}}}", "***", ast.y, ast.x, "[%s]%s", kprint, typ)
      end

      return ret
   end

   return recurse(root)
end

--------------------------------------------------------------------------------
-- Lua code generation
--------------------------------------------------------------------------------

local tight_op: {integer:{string:boolean}} = {
   [1] = {
      ["-"] = true,
      ["~"] = true,
      ["#"] = true,
   },
   [2] = {
      ["."] = true,
      [":"] = true,
   },
}

local spaced_op: {integer:{string:boolean}} = {
   [1] = {
      ["not"] = true,
   },
   [2] = {
      ["or"] = true,
      ["and"] = true,
      ["<"] = true,
      [">"] = true,
      ["<="] = true,
      [">="] = true,
      ["~="] = true,
      ["=="] = true,
      ["|"] = true,
      ["~"] = true,
      ["&"] = true,
      ["<<"] = true,
      [">>"] = true,
      [".."] = true,
      ["+"] = true,
      ["-"] = true,
      ["*"] = true,
      ["/"] = true,
      ["//"] = true,
      ["%"] = true,
      ["^"] = true,
   },
}


local default_generate_opts: GenerateOptions = {
   preserve_indent = true,
   preserve_newlines = true,
   preserve_hashbang = false,
}

local fast_generate_opts: GenerateOptions = {
   preserve_indent = false,
   preserve_newlines = true,
   preserve_hashbang = false,
}

local primitive: {TypeName:string} = {
   ["function"] = "function",
   ["enum"] = "string",
   ["boolean"] = "boolean",
   ["string"] = "string",
   ["nil"] = "nil",
   ["number"] = "number",
   ["integer"] = "number",
   ["thread"] = "thread",
}

function tl.generate(ast: tl.Node, gen_target: GenTarget, opts?: GenerateOptions): string, string
   local err: string
   local indent = 0

   opts = opts or default_generate_opts

   local record Output
      {string}
      y: integer
      h: integer
   end

   local save_indent: {integer} = {}

   local function increment_indent(_: nil, node: Node)
      local child = node.body or node[1]
      if not child then
         return
      end
      if child.y ~= node.y then
         if indent == 0 and #save_indent > 0 then
            indent = save_indent[#save_indent] + 1
         else
            indent = indent + 1
         end
      else
         table.insert(save_indent, indent)
         indent = 0
      end
   end

   local function decrement_indent(node: Node, child: Node)
      if child.y ~= node.y then
         indent = indent - 1
      else
         indent = table.remove(save_indent)
      end
   end

   if not opts.preserve_indent then
      increment_indent = nil
      decrement_indent = function() end
   end

   local function add_string(out: Output, s: string)
      table.insert(out, s)
      if string.find(s, "\n", 1, true) then
         for _nl in s:gmatch("\n") do
            out.h = out.h + 1
         end
      end
   end

   local function add_child(out: Output, child: Output, space?: string, current_indent?: integer): integer
      if #child == 0 then
         return
      end

      if child.y ~= -1 and child.y < out.y then
         out.y = child.y
      end

      if child.y > out.y + out.h and opts.preserve_newlines then
         local delta = child.y - (out.y + out.h)
         out.h = out.h + delta
         table.insert(out, ("\n"):rep(delta))
      else
         if space then
            if space ~= "" then
               table.insert(out, space)
            end
            current_indent = nil
         end
      end
      if current_indent and opts.preserve_indent then
         table.insert(out, ("   "):rep(current_indent))
      end
      table.insert(out, child as string)
      out.h = out.h + child.h
   end

   local function concat_output(out: Output): string
      for i, s in ipairs(out) do
         if type(s) == "table" then
            out[i] = concat_output(s as Output)
         end
      end
      return table.concat(out)
   end

   local function print_record_def(typ: RecordLikeType): string
      local out: {string} = { "{" }
      local i = 0
      for fname, ftype in fields_of(typ) do
         if ftype is TypeDeclType then
            local def = ftype.def
            if def is GenericType then
               def = def.t
            end
            if def is RecordType then
               if i > 0 then
                  table.insert(out, ",")
               end
               i = i + 1
               table.insert(out, " ")
               table.insert(out, fname)
               table.insert(out, " = ")
               table.insert(out, print_record_def(def))
            end
         end
      end
      if i > 0 then
         table.insert(out, " ")
      end
      table.insert(out, "}")
      return table.concat(out)
   end

   local visit_node: Visitor<nil, NodeKind, Node, Output> = {}

   local lua_54_attribute <total>: {Attribute:string} = {
      ["const"] = " <const>",
      ["close"] = " <close>",
      ["total"] = " <const>",
   }

   local function emit_exactly(_: nil, node: Node, _children: {Output}): Output
      local out: Output = { y = node.y, h = 0 }
      add_string(out, node.tk)
      return out
   end

   local emit_exactly_visitor_cbs <const>: VisitorCallbacks<nil, Node, Output> = { after = emit_exactly }

   local emit_nothing_visitor_cbs <const>: VisitorCallbacks<nil, Node, Output> = {
      after = function(_: nil, node: Node, _children: {Output}): Output
         local out: Output = { y = node.y, h = 0 }
         return out
      end
   }

   local function starts_with_longstring(n: Node): boolean
      while n.e1 do n = n.e1 end
      return n.is_longstring
   end

   visit_node.cbs = {
      ["statements"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output
            if opts.preserve_hashbang and node.hashbang then
               out = { y = 1, h = 0 }
               table.insert(out, node.hashbang)
            else
               out = { y = node.y, h = 0 }
            end
            local space: string
            for i, child in ipairs(children) do
               add_child(out, child, space, indent)
               if node[i].semicolon then
                  table.insert(out, ";")
                  space = " "
               else
                  space = "; "
               end
            end
            return out
         end
      },
      ["local_declaration"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "local ")
            for i, var in ipairs(node.vars) do
               if i > 1 then
                  add_string(out, ", ")
               end
               add_string(out, var.tk)
               if var.attribute then
                  if gen_target ~= "5.4" and var.attribute == "close" then
                     err = "attempt to emit a <close> attribute for a non 5.4 target"
                  end

                  if gen_target == "5.4" then
                     add_string(out, lua_54_attribute[var.attribute])
                  end
               end
            end
            if children[3] then
               table.insert(out, " =")
               add_child(out, children[3], " ")
            end
            return out
         end,
      },
      ["local_type"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if not node.var.elide_type then
               table.insert(out, "local")
               add_child(out, children[1], " ")
               table.insert(out, " =")
               add_child(out, children[2], " ")
            end
            return out
         end,
      },
      ["global_type"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if children[2] then
               add_child(out, children[1])
               table.insert(out, " =")
               add_child(out, children[2], " ")
            end
            return out
         end,
      },
      ["global_declaration"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if children[3] then
               add_child(out, children[1])
               table.insert(out, " =")
               add_child(out, children[3], " ")
            end
            return out
         end,
      },
      ["assignment"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            add_child(out, children[1])
            table.insert(out, " =")
            add_child(out, children[3], " ")
            return out
         end,
      },
      ["if"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            for i, child in ipairs(children) do
               add_child(out, child, i > 1 and " ", child.y ~= node.y and indent)
            end
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["if_block"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if node.if_block_n == 1 then
               table.insert(out, "if")
            elseif not node.exp then
               table.insert(out, "else")
            else
               table.insert(out, "elseif")
            end
            if node.exp then
               add_child(out, children[1], " ")
               table.insert(out, " then")
            end
            add_child(out, children[2], " ")
            decrement_indent(node, node.body)
            return out
         end,
      },
      ["while"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "while")
            add_child(out, children[1], " ")
            table.insert(out, " do")
            add_child(out, children[2], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["repeat"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "repeat")
            add_child(out, children[1], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "until " }, " ", indent)
            add_child(out, children[2])
            return out
         end,
      },
      ["do"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "do")
            add_child(out, children[1], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["forin"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "for")
            add_child(out, children[1], " ")
            table.insert(out, " in")
            add_child(out, children[2], " ")
            table.insert(out, " do")
            add_child(out, children[3], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["fornum"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "for")
            add_child(out, children[1], " ")
            table.insert(out, " =")
            add_child(out, children[2], " ")
            table.insert(out, ",")
            add_child(out, children[3], " ")
            if children[4] then
               table.insert(out, ",")
               add_child(out, children[4], " ")
            end
            table.insert(out, " do")
            add_child(out, children[5], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["return"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "return")
            if #children[1] > 0 then
               add_child(out, children[1], " ")
            end
            return out
         end,
      },
      ["break"] = {
         after = function(_: nil, node: Node, _children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "break")
            return out
         end,
      },
      ["variable_list"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            local space: string
            for i, child in ipairs(children) do
               if i > 1 then
                  table.insert(out, ",")
                  space = " "
               end
               add_child(out, child, space, child.y ~= node.y and indent)
            end
            return out
         end,
      },
      ["literal_table"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if #children == 0 then
               table.insert(out, "{}")
               return out
            end
            table.insert(out, "{")
            local n = #children
            for i, child in ipairs(children) do
               add_child(out, child, " ", child.y ~= node.y and indent)
               if i < n or node.yend ~= node.y then
                  table.insert(out, ",")
               end
            end
            decrement_indent(node, node[1])
            add_child(out, { y = node.yend, h = 0, [1] = "}" }, " ", indent)
            return out
         end,
      },
      ["literal_table_item"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if node.key_parsed ~= "implicit" then
               if node.key_parsed == "short" then
                  children[1][1] = children[1][1]:sub(2, -2)
                  add_child(out, children[1])
                  table.insert(out, " = ")
               else
                  table.insert(out, "[")
                  if node.key_parsed == "long" and node.key.is_longstring then
                     table.insert(children[1], 1, " ")
                     table.insert(children[1], " ")
                  end
                  add_child(out, children[1])
                  table.insert(out, "] = ")
               end
            end
            add_child(out, children[2])
            return out
         end,
      },
      ["local_macroexp"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, _children: {Output}): Output
            return { y = node.y, h = 0 }
         end,
      },
      ["local_function"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "local function")
            add_child(out, children[1], " ")
            table.insert(out, "(")
            add_child(out, children[2])
            table.insert(out, ")")
            add_child(out, children[4], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["global_function"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "function")
            add_child(out, children[1], " ")
            table.insert(out, "(")
            add_child(out, children[2])
            table.insert(out, ")")
            add_child(out, children[4], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["record_function"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "function")
            add_child(out, children[1], " ")
            table.insert(out, node.is_method and ":" or ".")
            add_child(out, children[2])
            table.insert(out, "(")
            if node.is_method then
               -- remove self
               table.remove(children[3], 1)
               if children[3][1] == "," then
                  table.remove(children[3], 1)
                  if children[3][1] == " " then
                     table.remove(children[3], 1)
                  end
               end
            end
            add_child(out, children[3])
            table.insert(out, ")")
            add_child(out, children[5], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["function"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "function(")
            add_child(out, children[1])
            table.insert(out, ")")
            add_child(out, children[3], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["paren"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "(")
            add_child(out, children[1], "", indent)
            table.insert(out, ")")
            return out
         end,
      },
      ["op"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if node.op.op == "@funcall" then
               add_child(out, children[1], "", indent)
               table.insert(out, "(")
               add_child(out, children[3], "", indent)
               table.insert(out, ")")
            elseif node.op.op == "@index" then
               add_child(out, children[1], "", indent)
               table.insert(out, "[")
               if starts_with_longstring(node.e2) then
                  table.insert(children[3], 1, " ")
                  table.insert(children[3], " ")
               end
               add_child(out, children[3], "", indent)
               table.insert(out, "]")
            elseif node.op.op == "as" then
               add_child(out, children[1], "", indent)
            elseif node.op.op == "is" then
               if node.e2.casttype.typename == "integer" then
                  table.insert(out, "math.type(")
                  add_child(out, children[1], "", indent)
                  table.insert(out, ") == \"integer\"")
               elseif node.e2.casttype.typename == "nil" then
                  add_child(out, children[1], "", indent)
                  table.insert(out, " == nil")
               else
                  table.insert(out, "type(")
                  add_child(out, children[1], "", indent)
                  table.insert(out, ") == \"")
                  add_child(out, children[3], "", indent)
                  table.insert(out, "\"")
               end
            elseif spaced_op[node.op.arity][node.op.op] or tight_op[node.op.arity][node.op.op] then
               local space = spaced_op[node.op.arity][node.op.op] and " " or ""
               if children[2] and node.op.prec > tonumber(children[2]) then
                  table.insert(children[1], 1, "(")
                  table.insert(children[1], ")")
               end
               if node.op.arity == 1 then
                  table.insert(out, node.op.op)
                  add_child(out, children[1], space, indent)
               elseif node.op.arity == 2 then
                  add_child(out, children[1], "", indent)
                  if space == " " then
                     table.insert(out, " ")
                  end
                  table.insert(out, node.op.op)
                  if children[4] and node.op.prec > tonumber(children[4]) then
                     table.insert(children[3], 1, "(")
                     table.insert(children[3], ")")
                  end
                  add_child(out, children[3], space, indent)
               end
            else
               error("unknown node op " .. node.op.op)
            end
            return out
         end,
      },
      ["newtype"] = {
         after = function(_: nil, node: Node, _children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            local nt = node.newtype
            if nt is TypeDeclType then
               local def = nt.def
               if def is RecordLikeType then
                  table.insert(out, print_record_def(def))
               elseif def is NominalType then
                  table.insert(out, table.concat(def.names, "."))
               else
                  table.insert(out, "{}")
               end
            end
            return out
         end,
      },
      ["goto"] = {
         after = function(_: nil, node: Node, _children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "goto ")
            table.insert(out, node.label)
            return out
         end,
      },
      ["label"] = {
         after = function(_: nil, node: Node, _children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "::")
            table.insert(out, node.label)
            table.insert(out, "::")
            return out
         end,
      },
      ["string"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            -- translate escape sequences not supported by Lua 5.1
            -- in particular:
            --  - \z : removes trailing whitespace
            --  - \xXX : hex byte
            --  - \u{} : unicode

            if node.tk:sub(1, 1) == "[" or gen_target ~= "5.1" or not node.tk:find("\\", 1, true) then
               return emit_exactly(nil, node, children)
            end

            local str = node.tk
            local replaced: {string} = {}

            local i = 1
            local currstrstart = 1
            while true do
               local slashpos = str:find("\\", i)
               if not slashpos then break end
               local nextc = str:sub(slashpos + 1, slashpos + 1)
               if nextc == "z" then
                  table.insert(replaced, str:sub(currstrstart, slashpos - 1))
                  local wsend = str:find("%S", slashpos + 2) -- next non-whitespace
                  currstrstart = wsend
                  i = currstrstart
               elseif nextc == "x" then
                  table.insert(replaced, str:sub(currstrstart, slashpos - 1))
                  local digits <const> = str:sub(slashpos + 2, slashpos + 3)
                  local byte <const> = tonumber(digits, 16)
                  table.insert(replaced, string.format("\\%03d", byte))
                  currstrstart = slashpos + 4
                  i = currstrstart
               elseif nextc == "u" then
                  table.insert(replaced, str:sub(currstrstart, slashpos - 1))
                  local _, e, hex_digits = str:find("{(.-)}", slashpos + 2)
                  local codepoint <const> = tonumber(hex_digits, 16)
                  local sequence <const> = utf8.char(codepoint)
                  table.insert(replaced, (sequence:gsub(".", function(c: string): string
                     return ("\\%03d"):format(string.byte(c))
                  end)))
                  currstrstart = e + 1
                  i = currstrstart
               else
                  i = slashpos + 2
               end
            end
            if currstrstart <= #str then
               table.insert(replaced, str:sub(currstrstart))
            end

            local h = 0
            local finalstr = table.concat(replaced)
            for _ in finalstr:gmatch("\n") do
               h = h + 1
            end
            return {
               y = node.y,
               h = h,
               finalstr,
            }
         end,
      },

      ["variable"] = emit_exactly_visitor_cbs,
      ["identifier"] = emit_exactly_visitor_cbs,
      ["number"] = emit_exactly_visitor_cbs,
      ["integer"] = emit_exactly_visitor_cbs,
      ["nil"] = emit_exactly_visitor_cbs,
      ["boolean"] = emit_exactly_visitor_cbs,
      ["..."] = emit_exactly_visitor_cbs,
      ["argument"] = emit_exactly_visitor_cbs,
      ["type_identifier"] = emit_exactly_visitor_cbs,

      ["cast"] = emit_nothing_visitor_cbs,
      ["pragma"] = emit_nothing_visitor_cbs,
   }

   local visit_type: Visitor<nil, TypeName, Type, Output> = {}
   visit_type.cbs = {}
   local default_type_visitor = {
      after = function(_: nil, typ: Type, _children: {Output}): Output
         local out: Output = { y = typ.y or -1, h = 0 }
         local r = typ is NominalType and typ.resolved or typ
         local lua_type = primitive[r.typename] or "table"
         if r is RecordLikeType and r.is_userdata then
            lua_type = "userdata"
         end
         table.insert(out, lua_type)
         return out
      end,
   }

   visit_type.cbs["string"] = default_type_visitor
   visit_type.cbs["typedecl"] = default_type_visitor
   visit_type.cbs["typevar"] = default_type_visitor
   visit_type.cbs["typearg"] = default_type_visitor
   visit_type.cbs["function"] = default_type_visitor
   visit_type.cbs["thread"] = default_type_visitor
   visit_type.cbs["array"] = default_type_visitor
   visit_type.cbs["map"] = default_type_visitor
   visit_type.cbs["tupletable"] = default_type_visitor
   visit_type.cbs["record"] = default_type_visitor
   visit_type.cbs["enum"] = default_type_visitor
   visit_type.cbs["boolean"] = default_type_visitor
   visit_type.cbs["nil"] = default_type_visitor
   visit_type.cbs["number"] = default_type_visitor
   visit_type.cbs["integer"] = default_type_visitor
   visit_type.cbs["union"] = default_type_visitor
   visit_type.cbs["nominal"] = default_type_visitor
   visit_type.cbs["emptytable"] = default_type_visitor
   visit_type.cbs["literal_table_item"] = default_type_visitor
   visit_type.cbs["unresolved_emptytable_value"] = default_type_visitor
   visit_type.cbs["tuple"] = default_type_visitor
   visit_type.cbs["poly"] = default_type_visitor
   visit_type.cbs["any"] = default_type_visitor
   visit_type.cbs["unknown"] = default_type_visitor
   visit_type.cbs["invalid"] = default_type_visitor
   visit_type.cbs["none"] = default_type_visitor

   visit_node.cbs["expression_list"] = visit_node.cbs["variable_list"]
   visit_node.cbs["argument_list"] = visit_node.cbs["variable_list"]

   local out = recurse_node(nil, ast, visit_node, visit_type)
   if err then
      return nil, err
   end

   local code: Output
   if opts.preserve_newlines then
      code = { y = 1, h = 0 }
      add_child(code, out)
   else
      code = out
   end
   return (concat_output(code):gsub(" *\n", "\n"))
end

--------------------------------------------------------------------------------
-- Type collection for report
--------------------------------------------------------------------------------

local typename_to_typecode <total>: {TypeName:integer} = {
   ["typevar"] = tl.typecodes.TYPE_VARIABLE,
   ["typearg"] = tl.typecodes.TYPE_VARIABLE,
   ["unresolved_typearg"] = tl.typecodes.TYPE_VARIABLE,
   ["unresolvable_typearg"] = tl.typecodes.TYPE_VARIABLE,
   ["function"] = tl.typecodes.FUNCTION,
   ["array"] = tl.typecodes.ARRAY,
   ["map"] = tl.typecodes.MAP,
   ["tupletable"] = tl.typecodes.TUPLE,
   ["interface"] = tl.typecodes.INTERFACE,
   ["self"] = tl.typecodes.SELF,
   ["record"] = tl.typecodes.RECORD,
   ["enum"] = tl.typecodes.ENUM,
   ["boolean"] = tl.typecodes.BOOLEAN,
   ["string"] = tl.typecodes.STRING,
   ["nil"] = tl.typecodes.NIL,
   ["thread"] = tl.typecodes.THREAD,
   ["userdata"] = tl.typecodes.USERDATA,
   ["number"] = tl.typecodes.NUMBER,
   ["integer"] = tl.typecodes.INTEGER,
   ["union"] = tl.typecodes.UNION,
   ["nominal"] = tl.typecodes.NOMINAL,
   ["circular_require"] = tl.typecodes.NOMINAL,
   ["boolean_context"] = tl.typecodes.BOOLEAN,
   ["emptytable"] = tl.typecodes.EMPTY_TABLE,
   ["unresolved_emptytable_value"] = tl.typecodes.EMPTY_TABLE,
   ["poly"] = tl.typecodes.POLY,
   ["any"] = tl.typecodes.ANY,
   ["unknown"] = tl.typecodes.UNKNOWN,
   ["invalid"] = tl.typecodes.INVALID,
   -- types that should be skipped or not present:
   ["none"] = tl.typecodes.UNKNOWN,
   ["tuple"] = tl.typecodes.UNKNOWN,
   ["literal_table_item"] = tl.typecodes.UNKNOWN,
   ["typedecl"] = tl.typecodes.UNKNOWN,
   ["generic"] = tl.typecodes.UNKNOWN,
   ["*"] = tl.typecodes.UNKNOWN,
}

local skip_types: {TypeName: boolean} = {
   ["none"] = true,
   ["tuple"] = true,
   ["literal_table_item"] = true,
}

local function sorted_keys<A,B>(m: {A:B}):{A}
   local keys = {}
   for k, _ in pairs(m) do
      table.insert(keys, k)
   end
   table.sort(keys)
   return keys
end

-- mark array for JSON-encoded reports in `tl types`
local function mark_array<T>(x: T): T
   local arr = x as {boolean}
   arr[0] = false
   return x
end

function tl.new_type_reporter(): TypeReporter
   local self: TypeReporter = setmetatable({
      next_num = 1,
      typeid_to_num = {},
      typename_to_num = {},
      tr = {
         by_pos = {},
         types = {},
         symbols_by_file = {},
         globals = {},
      },
   }, { __index = TypeReporter })

   local names = {}
   for name, _ in pairs(simple_types) do
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

   -- CHECK is this sufficient?
   if rt is GenericType then
      rt = rt.t
   end

   local ti: TypeInfo = {
      t = assert(typename_to_typecode[rt.typename]),
      str = show_type(t, true),
      file = t.f,
      y = t.y,
      x = t.x,
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

local record TypeCollector
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
-- Report types
--------------------------------------------------------------------------------

function tl.symbols_in_scope(tr: TypeReport, y: integer, x: integer, filename: string): {string:integer}
   local function find(symbols: {TypeReport.Symbol}, at_y: integer, at_x: integer): integer
      local function le(a: {integer, integer}, b: {integer, integer}): boolean
         return a[1] < b[1]
            or (a[1] == b[1] and a[2] <= b[2])
      end
      return binary_search(symbols, {at_y, at_x}, le) or 0
   end

   local ret: {string:integer} = {}

   local symbols = tr.symbols_by_file[filename]
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

--------------------------------------------------------------------------------
-- Errors
--------------------------------------------------------------------------------

function Errors.new(filename: string): Errors
   local self = {
      errors = {},
      warnings = {},
      unknown_dots = {},
      filename = filename,
   }
   return setmetatable(self, { __index = Errors })
end

local function Err_at(w: Where, msg: string): Error
   return {
      msg = msg,
      x = assert(w.x),
      y = assert(w.y),
      filename = assert(w.f),
   }
end

local function insert_error(self: Errors, y: integer, x: integer, f: string, err: Error)
   err.y = assert(y)
   err.x = assert(x)
   err.filename = assert(f)

   if TL_DEBUG then
      io.stderr:write("ERROR:" .. err.y .. ":" .. err.x .. ": " .. err.msg .. "\n")
   end

   table.insert(self.errors, err)
end

function Errors:add(w: Where, msg: string, t?: Type, ...:Type)
   local e: Error
   if t then
      e = types.error(msg, t, ...)
   else
      e = { msg = msg }
   end
   if e then
      insert_error(self, w.y, w.x, w.f, e)
   end
end

local context_name: {NodeKind: string} = {
   ["local_declaration"] = "in local declaration",
   ["global_declaration"] = "in global declaration",
   ["assignment"] = "in assignment",
   ["literal_table_item"] = "in table item",
}

function Errors:get_context(ctx: Node|string, name?: string): string
   if not ctx then
      return ""
   end
   local ec = (ctx is Node)   and ctx.expected_context
   local cn = (ctx is string) and ctx or
              (ctx is Node)   and context_name[ec and ec.kind or ctx.kind]
   return (cn and cn .. ": " or "") .. (ec and ec.name and ec.name .. ": " or "") .. (name and name .. ": " or "")
end

function Errors:add_in_context(w: Where, ctx: Node, msg: string, ...:Type)
   local prefix = self:get_context(ctx)
   msg = prefix .. msg
   return self:add(w, msg, ...)
end


function Errors:collect(errs: {Error})
   for _, e in ipairs(errs) do
      insert_error(self, e.y, e.x, e.filename, e)
   end
end

function Errors:add_warning(tag: WarningKind, w: Where, fmt: string, ...: any)
   assert(w.y)
   table.insert(self.warnings, {
      y = w.y,
      x = w.x,
      msg = fmt:format(...),
      filename = assert(w.f),
      tag = tag,
   })
end

function Errors:invalid_at(w: Where, msg: string, ...:Type): InvalidType
   self:add(w, msg, ...)
   return an_invalid(w)
end

function Errors:add_unknown(node: Node, name: string)
   self:add_warning("unknown", node, "unknown variable: %s", name)
end

function Errors:redeclaration_warning(at: Where, var_name: string, var_kind: string, old_var?: Variable)
   if var_name:sub(1, 1) == "_" then return end

   local short_error = var_kind .. " shadows previous declaration of '%s'"
   if old_var and old_var.declared_at then
      self:add_warning("redeclaration", at, short_error .. " (originally declared at %d:%d)", var_name, old_var.declared_at.y, old_var.declared_at.x)
   else
      self:add_warning("redeclaration", at, short_error, var_name)
   end
end

local function var_should_be_ignored_for_warnings(name: string, var: Variable): boolean
   local prefix <const> = name:sub(1,1)
   return (not var.declared_at)
      or var.is_specialized == "narrow"
      or prefix == "_"
      or prefix == "@"
end

local function user_facing_variable_description(var: Variable): string
   local t <const> = var.t
   return var.is_func_arg and "argument"
      or t is FunctionType and "function"
      or t is TypeDeclType and "type"
      or "variable"
end

function Errors:unused_warning(name: string, var: Variable)
   if var_should_be_ignored_for_warnings(name, var) then
      return
   end
   self:add_warning(
      "unused",
      var.declared_at,
      "unused %s %s: %s",
      user_facing_variable_description(var),
      name,
      show_type(var.t)
   )
end

function Errors:add_prefixing(w: Where, src: {Error}, prefix: string, dst?: {Error})
   if not src then
      return
   end

   for _, err in ipairs(src) do
      err.msg = prefix .. err.msg
      if w and (
         (err.filename ~= w.f)
         or (not err.y)
         or (w.y > err.y or (w.y == err.y and w.x > err.x))
      ) then
         err.y = w.y
         err.x = w.x
         err.filename = w.f
      end

      if dst then
         table.insert(dst, err)
      else
         insert_error(self, err.y, err.x, err.filename, err)
      end
   end
end

local function ensure_not_abstract_type(def: Type, node?: Node): boolean, string
   if def is RecordType then
      return true
   elseif def is GenericType then
      return ensure_not_abstract_type(def.t)
   elseif node and node_is_require_call(node) then
      return nil, "module type is abstract: " .. tostring(def)
   elseif def is InterfaceType then
      return nil, "interfaces are abstract; consider using a concrete record"
   end
   return nil, "cannot use a type definition as a concrete value"
end

local function ensure_not_abstract(t: Type, node?: Node): boolean, string
   if t is FunctionType and t.macroexp then
      return nil, "macroexps are abstract; consider using a concrete function"
   elseif t is GenericType then
      return ensure_not_abstract(t.t, node)
   elseif t is TypeDeclType then
      return ensure_not_abstract_type(t.def, node)
   end
   return true
end

local record UsageWarning
   y: integer
   x: integer
   name: string
   var: Variable
   kind: Kind

   enum Kind
      "unused"
      "written but not read"
   end
end

local function has_var_been_used(var: Variable): boolean
   return var.has_been_read_from or var.has_been_written_to
end

local function check_var_usage(scope: Scope, is_global?: boolean): {UsageWarning}
   local vars = scope.vars
   if not next(vars) then
      return
   end
   local usage_warnings: {UsageWarning}
   for name, var in pairs(vars) do
      local t <const> = var.t
      if not var_should_be_ignored_for_warnings(name, var) then
         if var.has_been_written_to and not var.has_been_read_from then
            usage_warnings = usage_warnings or {}
            table.insert(usage_warnings, {
               y = var.declared_at.y,
               x = var.declared_at.x,
               name = name,
               var = var,
               kind = "written but not read",
            })
         end

      end

      if var.declared_at and not has_var_been_used(var) then
         if var.used_as_type then
            var.declared_at.elide_type = true
         else
            if t is TypeDeclType and not is_global then
               var.declared_at.elide_type = true
            end
            usage_warnings = usage_warnings or {}
            table.insert(usage_warnings, { y = var.declared_at.y, x = var.declared_at.x, name = name, var = var, kind = "unused" })
         end
      elseif has_var_been_used(var) and t is TypeDeclType and var.aliasing then
         var.aliasing.has_been_written_to = var.has_been_written_to
         var.aliasing.has_been_read_from = var.has_been_read_from
         if ensure_not_abstract(t) then
            var.aliasing.declared_at.elide_type = false
         end
      end
   end
   if usage_warnings then
      table.sort(usage_warnings, function(a: UsageWarning, b: UsageWarning): boolean
         return a.y < b.y or (a.y == b.y and a.x < b.x)
      end)
   end
   return usage_warnings
end

function Errors:check_var_usage(scope: Scope, is_global?: boolean)
   local usage_warnings <const> = check_var_usage(scope, is_global)
   if usage_warnings then
      for _, u in ipairs(usage_warnings) do
         if u.kind == "unused" then
            self:unused_warning(u.name, u.var)
         elseif u.kind == "written but not read" then
            self:add_warning(
               "unread",
               u.var.declared_at,
               "%s %s (of type %s) is never read",
               user_facing_variable_description(u.var),
               u.name,
               show_type(u.var.t)
            )
         end
      end
   end

   if scope.labels then
      for name, node in pairs(scope.labels) do
         if not node.used_label then
            self:add_warning("unused", node, "unused label ::%s::", name)
         end
      end
   end
end

function Errors:add_unknown_dot(node: Node, name: string)
   if not self.unknown_dots[name] then
      self.unknown_dots[name] = true
      self:add_unknown(node, name)
   end
end

function Errors:fail_unresolved_labels(scope: Scope)
   if scope.pending_labels then
      for name, nodes in pairs(scope.pending_labels) do
         for _, node in ipairs(nodes) do
            self:add(node, "no visible label '" .. name .. "' for goto")
         end
      end
   end
end

function Errors:fail_unresolved_nominals(scope: Scope, global_scope: Scope)
   if global_scope and scope.pending_nominals then
      for name, typs in pairs(scope.pending_nominals) do
         if not global_scope.pending_global_types[name] then
            for _, typ in ipairs(typs) do
               assert(typ.x)
               assert(typ.y)
               self:add(typ, "unknown type %s", typ)
            end
         end
      end
   end
end

local type CheckableKey = string | number | boolean

function Errors:check_redeclared_key(w: Where, ctx: Node, seen_keys: {CheckableKey:Where}, key: CheckableKey)
   if key ~= nil then
      local s = seen_keys[key]
      if s then
         self:add_in_context(w, ctx, "redeclared key " .. tostring(key) .. " (previously declared at " .. self.filename .. ":" .. s.y .. ":" .. s.x .. ")")
      else
         seen_keys[key] = w
      end
   end
end

--------------------------------------------------------------------------------
-- Type check
--------------------------------------------------------------------------------

local numeric_binop = {
   ["number"] = {
      ["number"] = "number",
      ["integer"] = "number",
   },
   ["integer"] = {
      ["integer"] = "integer",
      ["number"] = "number",
   },
}

local float_binop = {
   ["number"] = {
      ["number"] = "number",
      ["integer"] = "number",
   },
   ["integer"] = {
      ["integer"] = "number",
      ["number"] = "number",
   },
}

local integer_binop = {
   ["number"] = {
      ["number"] = "integer",
      ["integer"] = "integer",
   },
   ["integer"] = {
      ["integer"] = "integer",
      ["number"] = "integer",
   },
}

local relational_binop = {
   ["number"] = {
      ["integer"] = "boolean",
      ["number"] = "boolean",
   },
   ["integer"] = {
      ["number"] = "boolean",
      ["integer"] = "boolean",
   },
   ["string"] = {
      ["string"] = "boolean",
   },
   ["boolean"] = {
      ["boolean"] = "boolean",
   },
}

local equality_binop = {
   ["number"] = {
      ["number"] = "boolean",
      ["integer"] = "boolean",
      ["nil"] = "boolean",
   },
   ["integer"] = {
      ["number"] = "boolean",
      ["integer"] = "boolean",
      ["nil"] = "boolean",
   },
   ["string"] = {
      ["string"] = "boolean",
      ["nil"] = "boolean",
   },
   ["boolean"] = {
      ["boolean"] = "boolean",
      ["nil"] = "boolean",
   },
   ["record"] = {
      ["emptytable"] = "boolean",
      ["record"] = "boolean",
      ["nil"] = "boolean",
   },
   ["array"] = {
      ["emptytable"] = "boolean",
      ["array"] = "boolean",
      ["nil"] = "boolean",
   },
   ["map"] = {
      ["emptytable"] = "boolean",
      ["map"] = "boolean",
      ["nil"] = "boolean",
   },
   ["thread"] = {
      ["thread"] = "boolean",
      ["nil"] = "boolean",
   }
}

local unop_types: {string:{TypeName:TypeName}} = {
   ["#"] = {
      ["enum"] = "integer",
      ["string"] = "integer",
      ["array"] = "integer",
      ["tupletable"] = "integer",
      ["map"] = "integer",
      ["emptytable"] = "integer",
   },
   ["-"] = {
      ["number"] = "number",
      ["integer"] = "integer",
   },
   ["~"] = {
      ["number"] = "integer",
      ["integer"] = "integer",
   },
   ["not"] = {
      ["string"] = "boolean",
      ["number"] = "boolean",
      ["integer"] = "boolean",
      ["boolean"] = "boolean",
      ["record"] = "boolean",
      ["array"] = "boolean",
      ["tupletable"] = "boolean",
      ["map"] = "boolean",
      ["emptytable"] = "boolean",
      ["thread"] = "boolean",
   },
}

local unop_to_metamethod: {string:string} = {
   ["#"] = "__len",
   ["-"] = "__unm",
   ["~"] = "__bnot",
}

local binop_types: {string:{TypeName:{TypeName:TypeName}}} = {
   ["+"] = numeric_binop,
   ["-"] = numeric_binop,
   ["*"] = numeric_binop,
   ["%"] = numeric_binop,
   ["/"] = float_binop,
   ["//"] = numeric_binop,
   ["^"] = float_binop,
   ["&"] = integer_binop,
   ["|"] = integer_binop,
   ["<<"] = integer_binop,
   [">>"] = integer_binop,
   ["~"] = integer_binop,
   ["=="] = equality_binop,
   ["~="] = equality_binop,
   ["<="] = relational_binop,
   [">="] = relational_binop,
   ["<"] = relational_binop,
   [">"] = relational_binop,
   ["or"] = {
      ["boolean"] = {
         ["boolean"] = "boolean",
      },
      ["number"] = {
         ["integer"] = "number",
         ["number"] = "number",
         ["boolean"] = "boolean",
      },
      ["integer"] = {
         ["integer"] = "integer",
         ["number"] = "number",
         ["boolean"] = "boolean",
      },
      ["string"] = {
         ["string"] = "string",
         ["boolean"] = "boolean",
         ["enum"] = "string",
      },
      ["function"] = {
         ["boolean"] = "boolean",
      },
      ["array"] = {
         ["boolean"] = "boolean",
      },
      ["record"] = {
         ["boolean"] = "boolean",
      },
      ["map"] = {
         ["boolean"] = "boolean",
      },
      ["enum"] = {
         ["string"] = "string",
      },
      ["thread"] = {
         ["boolean"] = "boolean",
      }
   },
   [".."] = {
      ["string"] = {
         ["string"] = "string",
         ["enum"] = "string",
         ["number"] = "string",
         ["integer"] = "string",
      },
      ["number"] = {
         ["integer"] = "string",
         ["number"] = "string",
         ["string"] = "string",
         ["enum"] = "string",
      },
      ["integer"] = {
         ["integer"] = "string",
         ["number"] = "string",
         ["string"] = "string",
         ["enum"] = "string",
      },
      ["enum"] = {
         ["number"] = "string",
         ["integer"] = "string",
         ["string"] = "string",
         ["enum"] = "string",
      }
   },
}

local binop_to_metamethod: {string:string} = {
   ["+"] = "__add",
   ["-"] = "__sub",
   ["*"] = "__mul",
   ["/"] = "__div",
   ["%"] = "__mod",
   ["^"] = "__pow",
   ["//"] = "__idiv",
   ["&"] = "__band",
   ["|"] = "__bor",
   ["~"] = "__bxor",
   ["<<"] = "__shl",
   [">>"] = "__shr",
   [".."] = "__concat",
   ["=="] = "__eq",
   ["<"] = "__lt",
   ["<="] = "__le",
   ["@index"] = "__index",
   ["is"] = "__is",
}

local flip_binop_to_metamethod: {string:string} = {
   [">"] = "__lt",
   [">="] = "__le",
}

local function search_for(module_name: string, suffix: string, path: string, tried: {string}): string, FILE, {string}
   for entry in path:gmatch("[^;]+") do
      local slash_name = module_name:gsub("%.", "/")
      local filename = entry:gsub("?", slash_name)
      local tl_filename = filename:gsub("%.lua$", suffix)
      local fd = io.open(tl_filename, "rb")
      if fd then
         return tl_filename, fd, tried
      end
      table.insert(tried, "no file '" .. tl_filename .. "'")
   end
   return nil, nil, tried
end

tl.search_module = function(module_name: string, search_all: boolean): string, FILE, {string}
   local found: string
   local fd: FILE
   local tried: {string} = {}
   local path = os.getenv("TL_PATH") or tl.path or package.path
   if search_all then
      found, fd, tried = search_for(module_name, ".d.tl", path, tried)
      if found then
         return found, fd
      end
   end
   found, fd, tried = search_for(module_name, ".tl", path, tried)
   if found then
      return found, fd
   end
   if search_all then
      found, fd, tried = search_for(module_name, ".lua", path, tried)
      if found then
         return found, fd
      end
   end
   return nil, nil, tried
end

local function require_module(w: Where, module_name: string, opts: CheckOptions, env: Env): Type, string
   local mod = env.modules[module_name]
   if mod then
      return mod, env.module_filenames[module_name]
   end

   local found, fd = tl.search_module(module_name, true)
   if found and (opts.feat_lax == "on" or found:match("tl$") as boolean) then

      env.module_filenames[module_name] = found
      env.modules[module_name] = a_typedecl(w, a_type(w, "circular_require", {}))

      local save_defaults = env.defaults
      local defaults <total>: CheckOptions = {
         feat_lax = opts.feat_lax or save_defaults.feat_lax,
         feat_arity = opts.feat_arity or save_defaults.feat_arity,
         gen_compat = opts.gen_compat or save_defaults.gen_compat,
         gen_target = opts.gen_target or save_defaults.gen_target,
         run_internal_compiler_checks = opts.run_internal_compiler_checks or save_defaults.run_internal_compiler_checks,
      }
      env.defaults = defaults

      local found_result, err: Result, string = tl.check_file(found, env, fd)
      assert(found_result, err)

      env.defaults = save_defaults

      env.modules[module_name] = found_result.type

      return found_result.type, found
   elseif fd then
      fd:close()
   end

   return an_invalid(w), found
end

local compat_code_cache: {string:Node} = {}

local function add_compat_entries(program: Node, used_set: {string: boolean}, gen_compat: GenCompat)
   if gen_compat == "off" or not next(used_set) then
      return
   end

   local tl_debug = TL_DEBUG
   TL_DEBUG = nil

   local used_list: {string} = sorted_keys(used_set)

   local compat_loaded = false

   local n = 1
   local function load_code(name: string, text: string)
      local code: Node = compat_code_cache[name]
      if not code then
         code = parser.parse(text, "@internal", "lua") as Node
         tl.check(code, "@internal", { feat_lax = "off", gen_compat = "off" })
         compat_code_cache[name] = code
      end
      for _, c in ipairs(code) do
         table.insert(program, n, c)
         n = n + 1
      end
   end

   local function req(m: string): string
      return (gen_compat == "optional")
             and "pcall(require, '" .. m .. "')"
             or  "true, require('" .. m .. "')"
   end

   for _, name in ipairs(used_list) do
      if name == "table.unpack" then
         load_code(name, "local _tl_table_unpack = unpack or table.unpack")
      elseif name == "table.pack" then
         load_code(name, [[local _tl_table_pack = table.pack or function(...) return { n = select("#", ...), ... } end]])
      elseif name == "bit32" then
         load_code(name, "local bit32 = bit32; if not bit32 then local p, m = " .. req("bit32") .. "; if p then bit32 = m end")
      elseif name == "mt" then
         load_code(name, "local _tl_mt = function(m, s, a, b) return (getmetatable(s == 1 and a or b)[m](a, b) end")
      elseif name == "math.maxinteger" then
         load_code(name, "local _tl_math_maxinteger = math.maxinteger or math.pow(2,53)")
      elseif name == "math.mininteger" then
         load_code(name, "local _tl_math_mininteger = math.mininteger or -math.pow(2,53) - 1")
      elseif name == "type" then
         load_code(name, "local type = type")
      else
         if not compat_loaded then
            load_code("compat", "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = " .. req("compat53.module") .. "; if p then _tl_compat = m end")
            compat_loaded = true
         end
         load_code(name, (("local $NAME = _tl_compat and _tl_compat.$NAME or $NAME"):gsub("$NAME", name)))
      end
   end
   program.y = 1

   TL_DEBUG = tl_debug
end

local function get_stdlib_compat(): {string:boolean}
   return {
      ["io"] = true,
      ["math"] = true,
      ["string"] = true,
      ["table"] = true,
      ["utf8"] = true,
      ["coroutine"] = true,
      ["os"] = true,
      ["package"] = true,
      ["debug"] = true,
      ["load"] = true,
      ["loadfile"] = true,
      ["assert"] = true,
      ["pairs"] = true,
      ["ipairs"] = true,
      ["pcall"] = true,
      ["xpcall"] = true,
      ["rawlen"] = true,
   }
end

local bit_operators: {string:string} = {
   ["&"] = "band",
   ["|"] = "bor",
   ["~"] = "bxor",
   [">>"] = "rshift",
   ["<<"] = "lshift",
}

local function node_at(w: Where, n: Node): Node
   n.f = assert(w.f)
   n.x = w.x
   n.y = w.y
   return n
end

local function convert_node_to_compat_call(node: Node, mod_name: string, fn_name: string, e1: Node, e2?: Node)
   node.op.op = "@funcall"
   node.op.arity = 2
   node.op.prec = 100
   node.e1 = node_at(node, { kind = "op", op = parser.operator(node, 2, ".") })
   node.e1.e1 = node_at(node, { kind = "identifier", tk = mod_name })
   node.e1.e2 = node_at(node, { kind = "identifier", tk = fn_name })
   node.e2 = node_at(node, { kind = "expression_list" })
   node.e2[1] = e1
   node.e2[2] = e2
end

local function convert_node_to_compat_mt_call(node: Node, mt_name: string, which_self: integer, e1: Node, e2?: Node)
   node.op.op = "@funcall"
   node.op.arity = 2
   node.op.prec = 100
   node.e1 = node_at(node, { kind = "identifier", tk = "_tl_mt" })
   node.e2 = node_at(node, { kind = "expression_list" })
   node.e2[1] = node_at(node, { kind = "string", tk = "\"" .. mt_name .. "\"" })
   node.e2[2] = node_at(node, { kind = "integer", tk = tostring(which_self) })
   node.e2[3] = e1
   node.e2[4] = e2
end

local stdlib_globals: {string:Variable} = nil
local fresh_typevar_ctr = 1

local function assert_no_errors(errs: {Error}, msg: string)
   if #errs ~= 0 then
      local out = {}
      for _, err in ipairs(errs) do
         table.insert(out, err.y .. ":" .. err.x .. " " .. err.msg .. "\n")
      end
      error("Internal Compiler Error: " .. msg .. ":\n" .. table.concat(out), 2)
   end
end

local function resolve_for_special_function(t: Type): FunctionType
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

local function set_special_function(t: Type, fname: SpecialFunctionName)
   t = resolve_for_special_function(t)
   t.special_function_handler = fname
end

tl.new_env = function(opts?: EnvOptions): Env, string
   opts = opts or {}

   local env: Env = {
      modules = {},
      module_filenames = {},
      loaded = {},
      loaded_order = {},
      globals = {},
      defaults = opts.defaults or {},
   }

   if env.defaults.gen_target == "5.4" and env.defaults.gen_compat ~= "off" then
      return nil, "gen-compat must be explicitly 'off' when gen-target is '5.4'"
   end

   if not stdlib_globals then
      local tl_debug = TL_DEBUG
      TL_DEBUG = nil

      do
         local program, syntax_errors = tl.parse(prelude, "prelude.d.tl", "tl")
         assert_no_errors(syntax_errors, "prelude contains syntax errors")
         local result = tl.check(program, "@prelude", {}, env)
         assert_no_errors(result.type_errors, "prelude contains type errors")
      end

      do
         local program, syntax_errors = tl.parse(stdlib, "stdlib.d.tl", "tl")
         assert_no_errors(syntax_errors, "standard library contains syntax errors")
         local result = tl.check(program, "@stdlib", {}, env)
         assert_no_errors(result.type_errors, "standard library contains type errors")
      end

      stdlib_globals = env.globals

      TL_DEBUG = tl_debug

      -- special cases for compatibility
      local math_t = (stdlib_globals["math"].t as TypeDeclType).def as RecordType
      local table_t = (stdlib_globals["table"].t as TypeDeclType).def as RecordType
      math_t.fields["maxinteger"].needs_compat = true
      math_t.fields["mininteger"].needs_compat = true
      table_t.fields["pack"].needs_compat = true
      table_t.fields["unpack"].needs_compat = true

      -- special cased functions
      local string_t = (stdlib_globals["string"].t as TypeDeclType).def as RecordType
      set_special_function(string_t.fields["find"], "string.find")
      set_special_function(string_t.fields["format"], "string.format")
      set_special_function(string_t.fields["gmatch"], "string.gmatch")
      set_special_function(string_t.fields["gsub"], "string.gsub")
      set_special_function(string_t.fields["match"], "string.match")
      set_special_function(string_t.fields["pack"], "string.pack")
      set_special_function(string_t.fields["unpack"], "string.unpack")

      set_special_function(stdlib_globals["assert"].t, "assert")
      set_special_function(stdlib_globals["ipairs"].t, "ipairs")
      set_special_function(stdlib_globals["pairs"].t, "pairs")
      set_special_function(stdlib_globals["pcall"].t, "pcall")
      set_special_function(stdlib_globals["xpcall"].t, "xpcall")
      set_special_function(stdlib_globals["rawget"].t, "rawget")
      set_special_function(stdlib_globals["require"].t, "require")

      -- only global scope and vararg functions accept `...`:
      -- `@is_va` is an internal sentinel value which is
      -- `any` if `...` is accepted in this scope or `nil` if it isn't.
      local w: Where = { f = "@prelude", x = 1, y = 1 }
      stdlib_globals["..."] = { t = a_vararg(w, { a_type(w, "string", {}) }) }
      stdlib_globals["@is_va"] = { t = a_type(w, "any", {}) }

      env.globals = {}
   end

   local stdlib_compat = get_stdlib_compat()
   for name, var in pairs(stdlib_globals) do
      env.globals[name] = var
      var.needs_compat = stdlib_compat[name]
      local t = var.t
      if t is TypeDeclType then
         -- make standard library tables available as modules for require()
         env.modules[name] = t
      end
   end

   if opts.predefined_modules then
      for _, name in ipairs(opts.predefined_modules) do
         local tc_opts = {
            feat_lax = env.defaults.feat_lax,
            feat_arity = env.defaults.feat_arity,
         }
         local w: Where = { f = "@predefined", x = 1, y = 1 }
         local module_type = require_module(w, name, tc_opts, env)

         if module_type is InvalidType then
            return nil, string.format("Error: could not predefine module '%s'", name)
         end
      end
   end

   return env
end


do
   local type TypeRelations = {TypeName:{TypeName:CompareTypes}}
   local type InvalidOrTupleType = InvalidType | TupleType

   local record TypeChecker
      env: Env
      st: {Scope}

      filename: string
      errs: Errors
      module_type: Type

      subtype_relations: TypeRelations
      eqtype_relations: TypeRelations
      type_priorities: {TypeName:integer}

      all_needs_compat: {string:boolean}
      dependencies: {string:string}
      collector: TypeCollector

      cache_std_metatable_type: Type

      gen_compat: GenCompat
      gen_target: GenTarget
      feat_arity: boolean
      feat_lax: boolean

      same_type: function(self, Type, Type): boolean, {Error}
      is_a: function(self, Type, Type): boolean, {Error}

      type_check_funcall: function(TypeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType

      expand_type: function(TypeChecker, w: Where, old: Type, new: Type): Type
      resolve_self: function(TypeChecker, Type, resolve_interface?: boolean): Type, {Error}

      get_rets: function(TupleType): TupleType
   end

   local enum VarUse
      "use"
      "lvalue"
      "use_type"
      "check_only"
   end

   local function get_real_var_from_lower_scope(st: {Scope}, i: integer, name: string): Variable
      for j = i - 1, 1, -1 do
         local scope = st[j]
         local sv = scope.vars[name]
         if sv and ((not sv.is_specialized) or (sv.specialized_from)) then
            return sv
         end
      end
   end

   function TypeChecker:find_var(name: string, use?: VarUse): Variable, integer, Attribute
      for i = #self.st, 1, -1 do
         local scope = self.st[i]
         local var = scope.vars[name]
         if var then
            if use == "lvalue" and var.is_specialized and var.is_specialized ~= "localizing" then
               if var.specialized_from then
                  var.has_been_written_to = true
                  return { t = var.specialized_from, attribute = var.attribute }, i, var.attribute
               end
            else
               if i == 1 and var.needs_compat then
                  self.all_needs_compat[name] = true
               end

               local real_var = var
               if var.is_specialized and var.is_specialized ~= "localizing" then
                  real_var = get_real_var_from_lower_scope(self.st, i, name) or real_var
               end
               if use == "use_type" then
                  --var.used_as_type = true
                  real_var.used_as_type = true
               elseif use ~= "check_only" then
                  if use == "lvalue" then
                     --var.has_been_written_to = true
                     real_var.has_been_written_to = true
                  else
                     --var.has_been_read_from = true
                     real_var.has_been_read_from = true
                  end
               end

               return var, i, var.attribute
            end
         end
      end
   end

   function TypeChecker:simulate_g(): RecordType, Attribute
      -- this is a static approximation of _G
      local globals: {string:Type} = {}
      for k, v in pairs(self.st[1].vars) do
         if k:sub(1,1) ~= "@" then
            globals[k] = v.t
         end
      end
      return {
         typeid = types.globals_typeid,
         typename = "record",
         field_order = sorted_keys(globals),
         fields = globals,
      }, nil
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

   local function fresh_typeargs(self: TypeChecker, g: GenericType): GenericType
      fresh_typevar_ctr = fresh_typevar_ctr + 1

      local newg, errs = types.map(g.typeargs, g, fresh_typevar_fns)
      if newg is InvalidType then
         self.errs:collect(errs)
         return g
      end
      assert(newg is GenericType, "Internal Compiler Error: error creating fresh type variables")
      assert(newg ~= g)
      newg.fresh = true

      return newg
   end

   local function wrap_generic_if_typeargs<T is Type>(typeargs: {TypeArgType}, t: T): T | GenericType
      if not typeargs then
         return t
      end

      assert(not t is TypeDeclType)

      local gt = a_type(t, "generic", { t = t } as GenericType)
      gt.typeargs = typeargs
      return gt
   end

   function TypeChecker:find_var_type(name: string, use?: VarUse): Type, Attribute, Type
      local var = self:find_var(name, use)
      if var then
         local t = var.t
         if t is UnresolvedTypeArgType then
            return nil, nil, t.constraint
         end

         if t is GenericType then
            t = fresh_typeargs(self, t)
         end

         return t, var.attribute
      end
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

   local function unwrap_for_find_type(typ: Type): Type
      if typ is NominalType and typ.found then
         return unwrap_for_find_type(typ.found)
      elseif typ is TypeDeclType then
         return unwrap_for_find_type(typ.def)
      elseif typ is GenericType then
         return unwrap_for_find_type(typ.t)
      end
      return typ
   end

   function TypeChecker:find_type(names: {string}): TypeDeclType, TypeArgType
      local typ = self:find_var_type(names[1], "use_type")
      if not typ then
         if #names == 1 and names[1] == "metatable" then
            return self:find_type({"_metatable"})
         end
         return nil
      end
      for i = 2, #names do
         typ = unwrap_for_find_type(typ)
         if typ == nil then
            return nil
         end

         local fields = typ is RecordLikeType and typ.fields
         if not fields then
            return nil
         end

         typ = fields[names[i]]
         if typ == nil then
            return nil
         end
      end

      -- FIXME doing this at the and lets all nominals be used as types (see #891)
      if typ and typ is NominalType then
         typ = typ.found
      end
      if typ == nil then
         return nil
      end

      if typ is TypeDeclType then
         return typ
      elseif typ is TypeArgType then
         return nil, typ
      end
   end

   local function show_arity(f: FunctionType): string
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

   local function drop_constant_value(t: Type): Type
      if t is StringType and t.literal then
         local ret = shallow_copy_new_type(t)
         ret.literal = nil
         return ret
      end
      return t
   end

   local function resolve_typedecl(t: Type): Type
      if t is TypeDeclType then
         return t.def
      else
         return t
      end
   end


   local resolve_typevars: function(self: TypeChecker, t: Type): FirstClassType, {Error}
   do
      local record ResolveTypeVarState
         tc: TypeChecker
         resolved: {string:Type}
      end

      local resolve_typevar_fns: types.TypeFunctionMap<ResolveTypeVarState> = {
         ["typevar"] = function(s: ResolveTypeVarState, t: TypeVarType): Type, boolean
            local rt = s.tc:find_var_type(t.typevar)
            if not rt then
               return t, false
            end

            rt = drop_constant_value(rt)
            s.resolved[t.typevar] = rt

            return rt, true
         end,
      }

      local function clear_resolved_typeargs(copy: GenericType, resolved: {string:Type}): Type
         for i = #copy.typeargs, 1, -1 do
            local r = resolved[copy.typeargs[i].typearg]
            if r then
               table.remove(copy.typeargs, i)
            end
         end
         if not copy.typeargs[1] then
            return copy.t
         end
         return copy
      end

      resolve_typevars = function(self: TypeChecker, t: Type): Type, {Error}
         local state: ResolveTypeVarState = {
            tc = self,
            resolved = {},
         }
         local rt, errs = types.map(state, t, resolve_typevar_fns)
         if errs then
            return rt, errs
         end

         if rt is GenericType then
            rt = clear_resolved_typeargs(rt, state.resolved)
         end

         return rt
      end
   end


   function TypeChecker:infer_emptytable(emptytable: EmptyTableType, fresh_t: Type)
      local nst = emptytable.is_global and 1 or #self.st
      for i = nst, 1, -1 do
         local scope = self.st[i]
         if scope.vars[emptytable.assigned_to] then
            scope.vars[emptytable.assigned_to] = { t = fresh_t }
         end
      end
   end

   local function resolve_tuple(t: Type): Type
      local rt = t
      if rt is TupleType then
         rt = rt.tuple[1]
      end
      if rt == nil then
         return a_type(t, "nil", {})
      end
      return rt
   end

   function TypeChecker:check_if_redeclaration(new_name: string, node: Node, t: Type)
      local old: Variable
      if simple_types[new_name as TypeName] then
         if t.typename ~= "typedecl" then
            return
         end
      else
         old = self:find_var(new_name, "check_only")
         if not old then
            return
         end
      end
      local var_name = node.tk
      local var_kind = "variable"
      if node.kind == "local_function" or node.kind == "record_function" then
         var_kind = "function"
         var_name = node.name.tk
      end
      self.errs:redeclaration_warning(node, var_name, var_kind, old)
   end

   local function type_at<T is Type>(w: Where, t: T): T
      t.x = w.x
      t.y = w.y
      return t
   end

   function TypeChecker:assert_resolved_typevars_at(w: Where, t: Type): Type
      local ret, errs = resolve_typevars(self, t)
      if errs then
         assert(w.y)
         self.errs:add_prefixing(w, errs, "")
      end

      -- recurse until fixed point
      if ret.typeid ~= t.typeid then
         return self:assert_resolved_typevars_at(w, ret)
      end

      if ret == t or t is TypeVarType then
         ret = shallow_copy_new_type(ret)
      end
      return type_at(w, ret)
   end

   function TypeChecker:infer_at<T is Type>(w: Where, t: T): T
      local ret = self:assert_resolved_typevars_at(w, t)
      if ret is InvalidType then
         ret = t -- errors are produced by assert_resolved_typevars_at
      end

      if ret == t or t is TypeVarType then
         ret = shallow_copy_new_type(ret)
      end
      assert(w.f)
      ret.inferred_at = w
      return ret
   end

   do
      local function specialize_var(scope: Scope, node: Node, name: string, t: Type, attribute: Attribute, specialization: Specialization): Variable
         local var = scope.vars[name]
         if var then
            if var.is_specialized then
               var.t = t
               return var
            end

            var.is_specialized = specialization
            var.specialized_from = var.t
            var.t = t
         else
            var = { t = t, attribute = attribute, is_specialized = specialization, declared_at = node }
            scope.vars[name] = var
         end

         if specialization == "widen" then
            scope.widens = scope.widens or {}
            scope.widens[name] = true
         else
            scope.narrows = scope.narrows or {}
            scope.narrows[name] = true
         end

         return var
      end

      function TypeChecker:add_var(node: Node, name: string, t: Type, attribute?: Attribute, specialization?: Specialization): Variable

         if self.feat_lax and node and is_unknown(t) and (name ~= "self" and name ~= "...") and not specialization then
            self.errs:add_unknown(node, name)
         end
         if not attribute then
            t = drop_constant_value(t)
         end

         if self.collector and node then
            self.collector.add_to_symbol_list(node, name, t)
         end

         local scope <const> = self.st[#self.st]
         if specialization then
            return specialize_var(scope, node, name, t, attribute, specialization)
         end

         if node then
            if name ~= "self" and name ~= "..." and name:sub(1, 1) ~= "@" then
               self:check_if_redeclaration(name, node, t)
            end
            if not ensure_not_abstract(t) then
               node.elide_type = true
            end
         end

         local var = scope.vars[name]
         if var and not has_var_been_used(var) then
            -- the old var is removed from the scope and won't be checked when it closes,
            -- so check it here
            self.errs:unused_warning(name, var)
         end

         var = { t = t, attribute = attribute, declared_at = node }
         scope.vars[name] = var

         return var
      end
   end

   local type CompareTypes = function(TypeChecker, Type, Type): boolean, {Error}

   function TypeChecker:has_all_types_of(t1s: {Type}, t2s: {Type}): boolean
      for _, t1 in ipairs(t1s) do
         local found = false
         for _, t2 in ipairs(t2s) do
            if self:same_type(t2, t1) then
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

   local function any_errors(all_errs: {Error}): boolean, {Error}
      if #all_errs == 0 then
         return true
      else
         return false, all_errs
      end
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

   local function close_types(scope: Scope)
      for _, var in pairs(scope.vars) do
         local t = var.t
         if t is TypeDeclType then
            close_nested_records(t)
         end
      end
   end

   function TypeChecker:widen_in_scope(n: integer, var: string): boolean
      local scope = self.st[n]
      local v = scope.vars[var]
      assert(v, "no " .. var .. " in scope")
      local specialization = scope.vars[var].is_specialized
      if (not specialization)
         or not (specialization == "narrow"
         or specialization == "narrowed_declaration")
      then
         return false
      end

      local top = #self.st
      if n ~= top then
         local t = v.specialized_from
         if not t then
            local old: Variable
            for i = n - 1, 1, -1 do
               old = self.st[i].vars[var]
               if old then
                  if old.specialized_from then
                     t = old.specialized_from
                     break
                  elseif old.is_specialized == "localizing" or not old.is_specialized then
                     t = old.t
                     break
                  end
               end
            end

            -- this should only trigger in generated compat code
            if not t then
               return false
            end
         end
         self:add_var(nil, var, t, nil, "widen")
         return true
      end

      if v.specialized_from then
         v.t = v.specialized_from
         v.specialized_from = nil
         v.is_specialized = nil
      else
         scope.vars[var] = nil
      end

      if scope.narrows then
         scope.narrows[var] = nil
      end

      return true
   end

   function TypeChecker:widen_back_var(name: string): boolean
      local widened = false
      for i = #self.st, 1, -1 do
         local scope = self.st[i]
         if scope.vars[name] then
            if self:widen_in_scope(i, name) then
               widened = true
            else
               break
            end
         end
      end
      return widened
   end

   function TypeChecker:collect_if_widens(widens: {string:boolean}): {string:boolean}
      local st = self.st
      local scope = st[#st]
      if scope.widens then
         widens = widens or {}
         for k, _ in pairs(scope.widens) do
            widens[k] = true
         end
         scope.widens = nil
      end
      return widens
   end

   function TypeChecker:widen_all(widens: {string:boolean}, widen_types: {string:Type})
      for name, _ in pairs(widens) do
         local curr = self:find_var(name, "check_only")
         local prev = widen_types[name]
         if (not prev) or (curr and not self:same_type(curr.t, prev)) then
            self:widen_back_var(name)
         end
      end
   end

   function TypeChecker:begin_scope(node?: Node)
      table.insert(self.st, { vars = {} })

      if self.collector and node then
         self.collector.begin_symbol_list_scope(node)
      end
   end

   function TypeChecker:end_scope(node?: Node)
      local st = self.st
      local scope = st[#st]

      local widen_types: {string:Type}
      if scope.widens then
         widen_types = {}
         for name, _ in pairs(scope.widens) do
            local var = self:find_var(name, "check_only")
            widen_types[name] = var.t
         end
      end

      table.remove(st)
      local next_scope = st[#st]

      assert(not scope.is_transaction)

      close_types(scope)
      self.errs:check_var_usage(scope)

      if scope.widens then
         self:widen_all(scope.widens, widen_types)
      end

      if self.collector and node then
         self.collector.end_symbol_list_scope(node)
      end

      if not next_scope then
         return
      end

      if scope.pending_labels then
         if next_scope.pending_labels then
            for name, nodes in pairs(scope.pending_labels) do
               for _, n in ipairs(nodes) do
                  next_scope.pending_labels[name] = next_scope.pending_labels[name] or {}
                  table.insert(next_scope.pending_labels[name], n)
               end
            end
         else
            next_scope.pending_labels = scope.pending_labels
         end
      end

      if scope.pending_nominals then
         if next_scope.pending_nominals then
            for name, typs in pairs(scope.pending_nominals) do
               for _, typ in ipairs(typs) do
                  next_scope.pending_nominals[name] = next_scope.pending_nominals[name] or {}
                  table.insert(next_scope.pending_nominals[name], typ)
               end
            end
         else
            next_scope.pending_nominals = scope.pending_nominals
         end
      end
   end

   function TypeChecker:begin_scope_transaction(node: Node)
      self:begin_scope(node)
      local st = self.st
      st[#st].is_transaction = true
   end

   function TypeChecker:rollback_scope_transaction()
      local st = self.st
      local scope = st[#st]
      assert(scope.is_transaction)

      local vars = scope.vars
      for k, _ in pairs(vars) do
         vars[k] = nil
      end

      if self.collector then
         self.collector.rollback_symbol_list_scope()
      end
   end

   function TypeChecker:commit_scope_transaction(node: Node)
      local st = self.st
      local scope = st[#st]
      local next_scope = st[#st - 1]

      assert(scope.is_transaction)
      assert(not scope.pending_labels)
      assert(not scope.pending_nominals)

      for name, var in pairs(scope.vars) do
         local t = var.t
         next_scope.vars[name] = var
         assert(t)
      end

      table.remove(st)

      if self.collector and node then
         self.collector.end_symbol_list_scope(node)
      end
   end

   -- This type must never be used for any values
   local NONE = a_type({ f = "@none", x = -1, y = -1 }, "none", {})

   local function end_scope_and_none_type(self: TypeChecker, node: Node, _children: {Type}): Type
      self:end_scope(node)
      return NONE
   end

   local function unresolved_typeargs_for(g: GenericType): {Type}
      local ts = {}
      for _, ta in ipairs(g.typeargs) do
         table.insert(ts, a_type(ta, "unresolved_typearg", {
            constraint = ta.constraint
         } as UnresolvedTypeArgType))
      end
      return ts
   end

   function TypeChecker:apply_generic(w: Where, g: GenericType, typeargs?: {Type}): FirstOrderType, {TypeArgType}
      if not g.fresh then
         g = fresh_typeargs(self, g)
      end

      if not typeargs then
         typeargs = unresolved_typeargs_for(g)
      end

      assert(#g.typeargs == #typeargs)

      for i, ta in ipairs(g.typeargs) do
         self:add_var(nil, ta.typearg, typeargs[i])
      end
      local applied, errs = resolve_typevars(self, g)
      if errs then
         self.errs:add_prefixing(w, errs, "")
         return nil
      end

      if applied is GenericType then
         return applied.t, g.typeargs
      else
         return applied, g.typeargs
      end
   end

   local type InvalidOrTypeDeclType = InvalidType | TypeDeclType

   do
      local function check_metatable_contract(self: TypeChecker, tv: Type, ret: Type)
         if not ret or not tv is NominalType then
            return
         end
         local found = tv.found
         if not found then
            return
         end
         local rec = found.def
         if not (rec is RecordLikeType and rec.meta_fields and ret is RecordLikeType) then
            return
         end
         for fname, ftype in pairs(rec.meta_fields) do
            if ret.fields[fname] then
               if not self:is_a(ftype, ret.fields[fname]) then
                  self.errs:add(ftype, fname .. " does not follow metatable contract: got %s, expected %s", ftype, ret.fields[fname])
               end
            end
            ret.fields[fname] = ftype
         end
      end

      local function match_typevals(self: TypeChecker, t: NominalType, def: GenericType): Type
         if not t.typevals then
            -- HACK: accept function nominal without arguments
            local deft = def.t
            if (not deft is FunctionType) and (not deft is PolyType) then
               self.errs:add(t, "missing type arguments in %s", def)
               return nil
            end
         elseif #t.typevals ~= #def.typeargs then
            self.errs:add(t, "mismatch in number of type arguments")
            return nil
         end

         self:begin_scope()

         local ret = self:apply_generic(t, def, t.typevals)
         if def == self.cache_std_metatable_type then
            check_metatable_contract(self, t.typevals[1], ret)
         end

         self:end_scope()

         return ret
      end

      local function find_nominal_type_decl(self: TypeChecker, t: NominalType): Type, TypeDeclType
         if t.resolved then
            return t.resolved
         end

         local found = t.found or self:find_type(t.names)
         if not found then
            return self.errs:invalid_at(t, "unknown type %s", t)
         end

         if found is TypeDeclType and found.is_alias then
            local def = found.def
            if def is NominalType then
               found = def.found
            end
            -- if found.def is GenericType, return found as-is
         end

         if not found then
            return self.errs:invalid_at(t, table.concat(t.names, ".") .. " is not a resolved type")
         end

         if not found is TypeDeclType then
            return self.errs:invalid_at(t, table.concat(t.names, ".") .. " is not a type")
         end

         local def = found.def
         if def.typename == "circular_require" then
            -- return, but do not store resolution
            return def
         end

         assert(not def is NominalType)

         t.found = found

         if self.collector then
            self.env.reporter:set_ref(t, found)
         end

         return nil, found
      end

      local function resolve_decl_in_nominal(self: TypeChecker, t: NominalType, found: TypeDeclType): Type
         local def = found.def
         local resolved: Type
         if def is GenericType then
            resolved = match_typevals(self, t, def)
            if not resolved then
               resolved = an_invalid(t)
            end
         elseif t.typevals then
            resolved = self.errs:invalid_at(t, "unexpected type argument")
         else
            resolved = def
         end

         t.resolved = resolved

         return resolved
      end

      function TypeChecker:resolve_nominal(t: NominalType): Type
         local immediate, found = find_nominal_type_decl(self, t)
         if immediate then
            return immediate
         end

         return resolve_decl_in_nominal(self, t, found)
      end

      function TypeChecker:resolve_typealias(ta: TypeDeclType): InvalidOrTypeDeclType
         local def = ta.def

         local nom = def
         if def is GenericType then
            nom = def.t
         end

         if not nom is NominalType then
            return ta
         end
         -- given a typealias that points to a nominal,

         local immediate, found = find_nominal_type_decl(self, nom)
         -- if it was previously resolved (or a circular require, or an error), return that;
         if immediate and immediate is InvalidOrTypeDeclType then
            return immediate
         end

         -- if nominal has no type arguments, resolve alias to that;
         if not nom.typevals then
            nom.resolved = found
            return found
         end

         -- otherwise, this can't be an alias.

         -- resolve the nominal into a structural type
         local struc = resolve_decl_in_nominal(self, nom, found or nom.found)

         if def is GenericType then
            struc = wrap_generic_if_typeargs(def.typeargs, struc)
         end

         -- wrap it into a new non-alias typedecl
         local td = a_type(ta, "typedecl", { def = struc } as TypeDeclType)
         nom.resolved = td

         -- and return it
         return td
      end
   end

   local enum ArgCheckMode
      "argument"
      "return"
      "self"
   end

   local enum VarianceMode
      "covariant"
      "contravariant"
      "bivariant"
      "invariant"
   end

   function TypeChecker:arg_check(w: Where, all_errs: {Error}, a: Type, b: Type, v: VarianceMode, mode: ArgCheckMode, n?: integer): boolean
      local ok, err, errs: boolean, string, {Error}

      if v == "covariant" then
         ok, errs = self:is_a(a, b)
      elseif v == "contravariant" then
         ok, errs = self:is_a(b, a)
      elseif v == "bivariant" then
         ok, errs = self:is_a(a, b)
         if ok then
            return true
         end
         ok = self:is_a(b, a)
         if ok then
            return true
         end
      elseif v == "invariant" then
         ok, errs = self:same_type(a, b)
      end

      if ok and b is NominalType then
         local rb = self:resolve_nominal(b)
         ok, err = ensure_not_abstract(rb)
         if not ok then
            errs = { Err_at(w, err) }
         end
      end

      if not ok then
         self.errs:add_prefixing(w, errs, mode .. (n and " " .. n or "") .. ": ", all_errs)
         return false
      end
      return true
   end

   do
      local function are_same_unresolved_global_type(self: TypeChecker, t1: NominalType, t2: NominalType): boolean
         -- FIXME shouldn't this be allowed only when `#t1.names == 1 and #t2.names == 1`?
         if t1.names[1] == t2.names[1] then
            local global_scope = self.st[1]
            if global_scope.pending_global_types[t1.names[1]] then
               return true
            end
         end
         return false
      end

      local function fail_nominals(self: TypeChecker, t1: NominalType, t2: NominalType): boolean, {Error}
         local t1name = show_type(t1)
         local t2name = show_type(t2)
         if t1name == t2name then
            self:resolve_nominal(t1)
            if t1.found then
               t1name = t1name .. " (defined in " .. t1.found.f .. ":" .. t1.found.y .. ")"
            end
            self:resolve_nominal(t2)
            if t2.found then
               t2name = t2name .. " (defined in " .. t2.found.f .. ":" .. t2.found.y .. ")"
            end
         end
         return false, { Err(t1name .. " is not a " .. t2name) }
      end

      local function nominal_found_type(self: TypeChecker, nom: NominalType): Type
         local typedecl = nom.found
         if not typedecl then
            typedecl = self:find_type(nom.names)
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

      function TypeChecker:are_same_nominals(t1: NominalType, t2: NominalType): boolean, {Error}
         local t1f = nominal_found_type(self, t1)
         local t2f = nominal_found_type(self, t2)
         if (not t1f or not t2f) then
            if are_same_unresolved_global_type(self, t1, t2) then
               return true
            end

            if not t1f then
               self.errs:add(t1, "unknown type %s", t1)
            end
            if not t2f then
               self.errs:add(t2, "unknown type %s", t2)
            end
            return false, {} -- errors were already produced
         end

         if t1f.typeid ~= t2f.typeid then
            return fail_nominals(self, t1, t2)
         end

         if t1.typevals == nil and t2.typevals == nil then
            return true
         end

         if t1.typevals and t2.typevals and #t1.typevals == #t2.typevals then
            local errs = {}
            for i = 1, #t1.typevals do
               local _, typeval_errs = self:same_type(t1.typevals[i], t2.typevals[i])
               self.errs:add_prefixing(nil, typeval_errs, "type parameter <" .. show_type(t2.typevals[i]) .. ">: ", errs)
            end
            return any_errors(errs)
         end

         -- FIXME what if presence and arities of typevals don't match?...
         return true
      end
   end

   local is_lua_table_type: function(t: Type): boolean

   function TypeChecker:to_structural(t: Type): Type
      assert(not t is TupleType)
      if t is TypeVarType and t.constraint then
         t = t.constraint
      end
      if t is NominalType then
         t = self:resolve_nominal(t)
      end
      return t
   end

   local function unite(w: Where, typs: {Type}, flatten_constants?: boolean): Type
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
         t = resolve_tuple(t)
         if t is UnionType then
            for _, s in ipairs(t.types) do
               table.insert(stack, s)
            end
         else
            if primitive[t.typename] and (flatten_constants or (t is StringType and not t.literal)) then
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
         return a_union(w, ts)
      end
   end

   do
      local known_table_types: {TypeName:boolean} = {
         array = true,
         map = true,
         record = true,
         tupletable = true,
         interface = true,
      }

      -- Is the type represented concretely as a Lua table?
      is_lua_table_type = function(t: Type): boolean
         return known_table_types[t.typename]
                and not (t is RecordLikeType and t.is_userdata)
      end
   end

   function TypeChecker:arraytype_from_tuple(w: Where, tupletype: TupleTableType): ArrayType, {Error}
      -- first just try a basic union
      local element_type = unite(w, tupletype.types, true)
      local valid = (not element_type is UnionType) and true or is_valid_union(element_type)
      if valid then
         return an_array(w, element_type)
      end

      -- failing a basic union, expand the types
      local arr_type = an_array(w, tupletype.types[1])
      for i = 2, #tupletype.types do
         local expanded = self:expand_type(w, arr_type, an_array(w, tupletype.types[i]))
         if not expanded is ArrayType then
            return nil, { types.error("unable to convert tuple %s to array", tupletype) }
         end
         arr_type = expanded
      end
      return arr_type
   end

   local function compare_true(_: TypeChecker, _: Type, _: Type): boolean, {Error}
      return true
   end

   function TypeChecker:subtype_nominal(a: Type, b: Type): boolean, {Error}
      local ra = a is NominalType and self:resolve_nominal(a) or a
      local rb = b is NominalType and self:resolve_nominal(b) or b
      local ok, errs = self:is_a(ra, rb)
      if errs and #errs == 1 and errs[1].msg:match("^got ") then
         return false -- translate to got-expected error with unresolved types
      end
      return ok, errs
   end

   function TypeChecker:subtype_array(a: ArrayLikeType, b: ArrayLikeType): boolean, {Error}
      if (not a.elements) or (not self:is_a(a.elements, b.elements)) then
         return false
      end
      if a.consttypes and #a.consttypes > 1 then
         -- constant array, check elements (useful for array of enums)
         for _, e in ipairs(a.consttypes) do
            if not self:is_a(e, b.elements) then
               return false, { types.error("%s is not a member of %s", e, b.elements) }
            end
         end
      end
      return true
   end

   function TypeChecker:in_interface_list(r: RecordLikeType, iface: Type): boolean
      if not r.interface_list then
         return false
      end

      for _, t in ipairs(r.interface_list) do
         if self:is_a(t, iface) then
            return true
         end
      end

      return false
   end

   function TypeChecker:subtype_record(a: RecordLikeType, b: RecordLikeType): boolean, {Error}
      -- assert(b.typename == "record")
      if a.elements and b.elements then
         if not self:is_a(a.elements, b.elements) then
            return false, { Err("array parts have incompatible element types") }
         end
      end

      if a.is_userdata ~= b.is_userdata then
         return false, { Err(a.is_userdata and "userdata is not a record"
                                              or  "record is not a userdata") }
      end

      local errs: {Error} = {}
      for _, k in ipairs(a.field_order) do
         local ak = a.fields[k]
         local bk = b.fields[k]
         if bk then
            local ok, fielderrs = self:is_a(ak, bk)
            if not ok then
               self.errs:add_prefixing(nil, fielderrs, "record field doesn't match: " .. k .. ": ", errs)
            end
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

   function TypeChecker:eqtype_record(a: RecordType, b: RecordType): boolean, {Error}
      -- checking array interface
      if (a.elements ~= nil) ~= (b.elements ~= nil) then
         return false, { Err("types do not have the same array interface") }
      end
      if a.elements then
         local ok, errs = self:same_type(a.elements, b.elements)
         if not ok then
            return ok, errs
         end
      end

      local ok, errs = self:subtype_record(a, b)
      if not ok then
         return ok, errs
      end
      ok, errs = self:subtype_record(b, a)
      if not ok then
         return ok, errs
      end
      return true
   end

   local function compare_map(self: TypeChecker, ak: Type, bk: Type, av: Type, bv: Type, no_hack?: boolean): boolean, {Error}
      local ok1, errs_k = self:is_a(bk, ak)
      local ok2, errs_v = self:is_a(av, bv)

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

   function TypeChecker:compare_or_infer_typevar(typevar: string, a: Type, b: Type, cmp: CompareTypes): boolean, {Error}
      -- assert((a == nil and b ~= nil) or (a ~= nil and b == nil))

      -- does the typevar currently match to a type?
      local vt, _, constraint = self:find_var_type(typevar)
      if vt then
         -- If so, compare it to the other type
         return cmp(self, a or vt, b or vt)
      else
         -- otherwise, infer it to the other type
         local other = a or b

         -- but check interface constraint first if present
         if constraint then
            if not self:is_a(other, constraint) then
               return false, { types.error("given type %s does not satisfy %s constraint in type variable " .. types.show_typevar(typevar, "typevar"), other, constraint) }
            end

            if self:same_type(other, constraint) then
               -- do not infer to some type as constraint right away,
               -- to give a chance to more specific inferences
               -- in other arguments/returns
               return true
            end
         end

         local r, errs = resolve_typevars(self, other)
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
         self:add_var(nil, typevar, r)
         return true
      end
   end

   function TypeChecker:type_of_self(w: Where): Type, TypeDeclType
      local t = self:find_var_type("@self")
      if not t then
         return an_invalid(w), nil
      end
      assert(t is TypeDeclType)
      return t.def, t
   end

   -- ∃ x ∈ xs. t <: x
   function TypeChecker:exists_supertype_in(t: Type, xs: AggregateType): Type
      for _, x in ipairs(xs.types) do
         if self:is_a(t, x) then
            return x
         end
      end
   end

   -- ∀ x ∈ xs, x <: t
   function TypeChecker:forall_are_subtype_of(xs: AggregateType, t: Type): boolean
      for _, x in ipairs(xs.types) do
         if not self:is_a(x, t) then
            return false
         end
      end
      return true
   end

   local function compare_true_inferring_emptytable(self: TypeChecker, a: Type, b: EmptyTableType): boolean, {Error}
      self:infer_emptytable(b, self:infer_at(b, a))
      return true
   end

   local function compare_true_inferring_emptytable_if_not_userdata(self: TypeChecker, a: RecordLikeType, b: EmptyTableType): boolean, {Error}
      if a.is_userdata then
         return false, { types.error("{} cannot be used with userdata type %s", a) }
      end
      return compare_true_inferring_emptytable(self, a, b)
   end

   local function infer_emptytable_from_unresolved_value(self: TypeChecker, w: Where, u: UnresolvedEmptyTableValueType, values: Type)
      local et = u.emptytable_type
      assert(et is EmptyTableType, u.typename)
      local keys = et.keys
      if not (values is EmptyTableType or values is UnresolvedEmptyTableValueType) then
         local infer_to = keys is NumericType -- ideally integer only
                          and an_array(w, values)
                          or  a_map(w, keys, values)
         self:infer_emptytable(et, self:infer_at(w, infer_to))
      end
   end

   local function a_is_interface_b(self: TypeChecker, a: NominalType, b: NominalType): boolean, {Error}
      if (not a.found) or (not b.found) then
         return false
      end

      local af = a.found.def
      if af is GenericType then
         af = self:apply_generic(a, af, a.typevals)
      end

      if af is RecordLikeType then
         if self:in_interface_list(af, b) then
            return true
         end
      end

      return self:is_a(a, self:resolve_nominal(b))
   end

   -- emptytable rules are the same in eqtype_relations and subtype_relations
   local emptytable_relations: {TypeName:CompareTypes} = {
      ["emptytable"] = compare_true,
      ["array"] = compare_true,
      ["map"] = compare_true,
      ["tupletable"] = compare_true,
      ["interface"] = function(_self: TypeChecker, _a: Type, b: InterfaceType): boolean, {Error}
         return not b.is_userdata
      end,
      ["record"] = function(_self: TypeChecker, _a: Type, b: RecordType): boolean, {Error}
         return not b.is_userdata
      end,
   }

   TypeChecker.eqtype_relations = {
      ["typevar"] = {
         ["typevar"] = function(self: TypeChecker, a: TypeVarType, b: TypeVarType): boolean, {Error}
            if a.typevar == b.typevar then
               return true
            end

            return self:compare_or_infer_typevar(b.typevar, a, nil, self.same_type)
         end,
         ["*"] = function(self: TypeChecker, a: TypeVarType, b: Type): boolean, {Error}
            return self:compare_or_infer_typevar(a.typevar, nil, b, self.same_type)
         end,
      },
      ["emptytable"] = emptytable_relations,
      ["tupletable"] = {
         ["tupletable"] = function(self: TypeChecker, a: TupleTableType, b: TupleTableType): boolean, {Error}
            for i = 1, math.min(#a.types, #b.types) do
               if not self:same_type(a.types[i], b.types[i]) then
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
         ["array"] = function(self: TypeChecker, a: ArrayType, b: ArrayType): boolean, {Error}
            return self:same_type(a.elements, b.elements)
         end,
         ["emptytable"] = compare_true_inferring_emptytable,
      },
      ["map"] = {
         ["map"] = function(self: TypeChecker, a: MapType, b: MapType): boolean, {Error}
            return compare_map(self, a.keys, b.keys, a.values, b.values, true)
         end,
         ["emptytable"] = compare_true_inferring_emptytable,
      },
      ["union"] = {
         ["union"] = function(self: TypeChecker, a: UnionType, b: UnionType): boolean, {Error}
            return (self:has_all_types_of(a.types, b.types)
                and self:has_all_types_of(b.types, a.types))
         end,
      },
      ["nominal"] = {
         ["nominal"] = TypeChecker.are_same_nominals,
         ["typedecl"] = function(self: TypeChecker, a: NominalType, b: TypeDeclType): boolean, {Error}
            -- used when resolving type parameters
            return self:same_type(self:resolve_nominal(a), b.def)
         end,
      },
      ["record"] = {
         ["record"] = TypeChecker.eqtype_record,
         ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
      },
      ["interface"] = {
         ["interface"] = function(_self:TypeChecker, a: InterfaceType, b: InterfaceType): boolean, {Error}
            return a.typeid == b.typeid
         end,
         ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
      },
      ["function"] = {
         ["function"] = function(self:TypeChecker, a: FunctionType, b: FunctionType): boolean, {Error}
            local argdelta = a.is_method and 1 or 0
            local naargs, nbargs = #a.args.tuple, #b.args.tuple
            if naargs ~= nbargs then
               if (not not a.is_method) ~= (not not b.is_method) then
                  return false, { Err("different number of input arguments: method and non-method are not the same type") }
               end
               return false, { Err("different number of input arguments: got " .. naargs - argdelta .. ", expected " .. nbargs - argdelta) }
            end
            local narets, nbrets = #a.rets.tuple, #b.rets.tuple
            if narets ~= nbrets then
               return false, { Err("different number of return values: got " .. narets .. ", expected " .. nbrets) }
            end
            local errs = {}
            for i = 1, naargs do
               self:arg_check(a, errs, a.args.tuple[i], b.args.tuple[i], "invariant", "argument", i - argdelta)
            end
            for i = 1, narets do
               self:arg_check(a, errs, a.rets.tuple[i], b.rets.tuple[i], "invariant", "return", i)
            end
            return any_errors(errs)
         end,
      },
      ["self"] = {
         ["self"] = function(_self: TypeChecker, _a: SelfType, _b: SelfType): boolean, {Error}
            return true
         end,
         ["*"] = function(self: TypeChecker, a: SelfType, b: Type): boolean, {Error}
            return self:same_type(self:type_of_self(a), b)
         end,
      },
      ["boolean_context"] = {
         ["boolean"] = compare_true,
      },
      ["generic"] = {
         ["generic"] = function(self: TypeChecker, a: GenericType, b: GenericType): boolean, {Error}
            if #a.typeargs ~= #b.typeargs then
               return false
            end
            for i = 1, #a.typeargs do
               if not self:same_type(a.typeargs[i], b.typeargs[i]) then
                  return false
               end
            end
            return self:same_type(a.t, b.t)
         end,
      },
      ["*"] = {
         ["boolean_context"] = compare_true,
         ["self"] = function(self: TypeChecker, a: Type, b: SelfType): boolean, {Error}
            return self:same_type(a, (self:type_of_self(b)))
         end,
         ["typevar"] = function(self: TypeChecker, a: Type, b: TypeVarType): boolean, {Error}
            return self:compare_or_infer_typevar(b.typevar, a, nil, self.same_type)
         end,
      },
   }

   TypeChecker.subtype_relations = {
      ["nil"] = {
         ["*"] = compare_true,
      },
      ["tuple"] = {
         ["tuple"] = function(self: TypeChecker, a: TupleType, b: TupleType): boolean, {Error}  -- ∀ a[i] ∈ a, b[i] ∈ b. a[i] <: b[i]
            local at, bt = a.tuple, b.tuple                                  -- ──────────────────────────────────
            if #at ~= #bt then                                               --        a tuple <: b tuple
               return false
            end
            for i = 1, #at do
               if not self:is_a(at[i], bt[i]) then
                  return false
               end
            end
            return true
         end,
         ["*"] = function(self: TypeChecker, a: Type, b: Type): boolean, {Error}
            return self:is_a(resolve_tuple(a), b)
         end,
      },
      ["typevar"] = {
         ["typevar"] = function(self: TypeChecker, a: TypeVarType, b: TypeVarType): boolean, {Error}
            if a.typevar == b.typevar then
               return true
            end

            return self:compare_or_infer_typevar(b.typevar, a, nil, self.is_a)
         end,
         ["*"] = function(self: TypeChecker, a: TypeVarType, b: Type): boolean, {Error}
            return self:compare_or_infer_typevar(a.typevar, nil, b, self.is_a)
         end,
      },
      ["union"] = {
         ["nominal"] = function(self: TypeChecker, a: UnionType, b: NominalType): boolean, {Error}
            -- match unions structurally
            local rb = self:resolve_nominal(b)
            if rb is UnionType then
               return self:is_a(a, rb)
            end

            return self:forall_are_subtype_of(a, b)
         end,
         ["union"] = function(self: TypeChecker, a: UnionType, b: UnionType): boolean, {Error} -- ∀ t ∈ a. ∃ u ∈ b. t <: u
            local used = {}                                                 -- ────────────────────────
            for _, t in ipairs(a.types) do                                  --    a union <: b union
               self:begin_scope()
               local u = self:exists_supertype_in(t, b)
               self:end_scope() -- don't preserve failed inferences
               if not u then
                  return false
               end
               if not used[u] then -- FIXME the order of declared union items affects inference behavior
                  used[u] = t
               end
            end
            for u, t in pairs(used) do
               self:is_a(t, u) -- preserve valid inferences
            end
            return true
         end,
         ["*"] = TypeChecker.forall_are_subtype_of as CompareTypes,
      },
      ["poly"] = {
         ["*"] = function(self: TypeChecker, a: PolyType, b: Type): boolean, {Error}    -- ∃ t ∈ a, t <: b
            if self:exists_supertype_in(b, a) then                                      -- ───────────────
               return true                                                              --   a poly <: b
            end
            return false, { Err("cannot match against any alternatives of the polymorphic type") }
         end,
      },
      ["nominal"] = {
         ["nominal"] = function(self: TypeChecker, a: NominalType, b: NominalType): boolean, {Error}
            local ok, errs = self:are_same_nominals(a, b)
            if ok then
               return true
            end

            local ra = self:resolve_nominal(a)
            local rb = self:resolve_nominal(b)

            -- match unions structurally
            local union_a = ra is UnionType
            local union_b = rb is UnionType
            if union_a or union_b then
               return self:is_a(union_a and ra or a, union_b and rb or b)
            end

            -- match interface subtyping
            if rb is InterfaceType then
               return a_is_interface_b(self, a, b)
            end

            -- all other types nominally
            return ok, errs
         end,
         ["union"] = function(self: TypeChecker, a: NominalType, b: UnionType): boolean, {Error}
            -- match unions structurally
            local ra = self:resolve_nominal(a)
            if ra is UnionType then
               return self:is_a(ra, b)
            end

            return not not self:exists_supertype_in(a, b)
         end,
         ["*"] = TypeChecker.subtype_nominal,
      },
      ["enum"] = {
         ["string"] = compare_true,
      },
      ["string"] = {
         ["enum"] = function(_self: TypeChecker, a: StringType, b: EnumType): boolean, {Error}
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
         ["interface"] = function(self: TypeChecker, a: InterfaceType, b: InterfaceType): boolean, {Error}
            if self:in_interface_list(a, b) then
               return true
            end
            return self:same_type(a, b)
         end,
         ["array"] = TypeChecker.subtype_array,
         ["tupletable"] = function(self: TypeChecker, a: Type, b: Type): boolean, {Error}
            return self.subtype_relations["record"]["tupletable"](self, a, b)
         end,
         ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
      },
      ["emptytable"] = emptytable_relations,
      ["tupletable"] = {
         ["tupletable"] = function(self: TypeChecker, a: TupleTableType, b: TupleTableType): boolean, {Error}
            for i = 1, math.min(#a.types, #b.types) do
               if not self:is_a(a.types[i], b.types[i]) then
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
         ["record"] = function(self: TypeChecker, a: Type, b: RecordType): boolean, {Error}
            if b.elements then
               return self.subtype_relations["tupletable"]["array"](self, a, b)
            end
         end,
         ["array"] = function(self: TypeChecker, a: TupleTableType, b: ArrayType): boolean, {Error}
            if b.inferred_len and b.inferred_len > #a.types then
               return false, { Err("incompatible length, expected maximum length of " .. tostring(#a.types) .. ", got " .. tostring(b.inferred_len)) }
            end
            local aa, err = self:arraytype_from_tuple(a.inferred_at or a, a)
            if not aa then
               return false, err
            end
            if not self:is_a(aa, b) then
               return false, { types.error("got %s (from %s), expected %s", aa, a, b) }
            end
            return true
         end,
         ["map"] = function(self: TypeChecker, a: TupleTableType, b: MapType): boolean, {Error}
            local aa = self:arraytype_from_tuple(a.inferred_at or a, a)
            if not aa then
               return false, { types.error("Unable to convert tuple %s to map", a) }
            end

            return compare_map(self, a_type(a, "integer", {}), b.keys, aa.elements, b.values)
         end,
         ["emptytable"] = compare_true_inferring_emptytable,
      },
      ["record"] = {
         ["record"] = TypeChecker.subtype_record,
         ["interface"] = function(self: TypeChecker, a: RecordType, b: InterfaceType): boolean, {Error}
            if self:in_interface_list(a, b) then
               return true
            end
            if not a.declname then
               -- match inferred table (anonymous record) structurally to interface
               return self:subtype_record(a, b)
            end
         end,
         ["array"] = TypeChecker.subtype_array,
         ["map"] = function(self: TypeChecker, a: RecordType, b: MapType): boolean, {Error}
            if not self:is_a(b.keys, a_type(b, "string", {})) then
               return false, { Err("can't match a record to a map with non-string keys") }
            end

            for _, k in ipairs(a.field_order) do
               local bk = b.keys
               if bk is EnumType and not bk.enumset[k] then
                  return false, { Err("key is not an enum value: " .. k) }
               end
               if not self:is_a(a.fields[k], b.values) then
                  return false, { Err("record is not a valid map; not all fields have the same type") }
               end
            end

            return true
         end,
         ["tupletable"] = function(self: TypeChecker, a: RecordType, b: Type): boolean, {Error}
            if a.elements then
               return self.subtype_relations["array"]["tupletable"](self, a, b)
            end
         end,
         ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
      },
      ["array"] = {
         ["array"] = TypeChecker.subtype_array,
         ["record"] = function(self: TypeChecker, a: ArrayType, b: RecordType): boolean, {Error}
            if b.elements then
               return self:subtype_array(a, b)
            end
         end,
         ["map"] = function(self: TypeChecker, a: ArrayType, b: MapType): boolean, {Error}
            return compare_map(self, a_type(a, "integer", {}), b.keys, a.elements, b.values)
         end,
         ["tupletable"] = function(self: TypeChecker, a: ArrayType, b: TupleTableType): boolean, {Error}
            local alen = a.inferred_len or 0
            if alen > #b.types then
               return false, { Err("incompatible length, expected maximum length of " .. tostring(#b.types) .. ", got " .. tostring(alen)) }
            end

            -- for array literals (which is the only case where inferred_len is defined),
            -- only check the entries that are present
            for i = 1, (alen > 0) and alen or #b.types do
               if not self:is_a(a.elements, b.types[i]) then
                  return false, { types.error("tuple entry " .. i .. " of type %s does not match type of array elements, which is %s", b.types[i], a.elements) }
               end
            end
            return true
         end,
         ["emptytable"] = compare_true_inferring_emptytable,
      },
      ["map"] = {
         ["map"] = function(self: TypeChecker, a: MapType, b: MapType): boolean, {Error}
            return compare_map(self, a.keys, b.keys, a.values, b.values)
         end,
         ["array"] = function(self: TypeChecker, a: MapType, b: ArrayType): boolean, {Error}
            return compare_map(self, a.keys, a_type(b, "integer", {}), a.values, b.elements)
         end,
         ["emptytable"] = compare_true_inferring_emptytable,
      },
      ["typedecl"] = {
         ["*"] = function(self: TypeChecker, a: TypeDeclType, b: RecordType): boolean, {Error}
            return self:is_a(a.def, b)
         end,
      },
      ["function"] = {
         ["function"] = function(self: TypeChecker, a: FunctionType, b: FunctionType): boolean, {Error}
            local errs = {}

            local aa, ba = a.args.tuple, b.args.tuple
            if (not b.args.is_va) and (self.feat_arity and (#aa > #ba and a.min_arity > b.min_arity)) then
               table.insert(errs, types.error("incompatible number of arguments: got " .. show_arity(a) .. " %s, expected " .. show_arity(b) .. " %s", a.args, b.args))
            else
               for i = ((a.is_method or b.is_method) and 2 or 1), #aa do
                  local ai = aa[i]
                  local bi = ba[i] or (b.args.is_va and ba[#ba])
                  if bi then
                     self:arg_check(nil, errs, ai, bi, "bivariant", "argument", i)
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
                  self:arg_check(nil, errs, ar[i], br[i], "bivariant", "return", i)
               end
            end

            return any_errors(errs)
         end,
      },
      ["self"] = {
         ["self"] = function(_self: TypeChecker, _a: SelfType, _b: SelfType): boolean, {Error}
            return true
         end,
         ["*"] = function(self: TypeChecker, a: SelfType, b: Type): boolean, {Error}
            return self:is_a(self:type_of_self(a), b)
         end,
      },
      ["typearg"] = {
         ["typearg"] = function(_self: TypeChecker, a: TypeArgType, b: TypeArgType): boolean, {Error}
            return a.typearg == b.typearg
         end,
         ["*"] = function(self: TypeChecker, a: TypeArgType, b: Type): boolean, {Error}
            if a.constraint then
               return self:is_a(a.constraint, b)
            end
         end,
      },
      ["boolean_context"] = {
         ["boolean"] = compare_true,
      },
      ["generic"] = {
         ["*"] = function(self: TypeChecker, a: GenericType, b: Type): boolean, {Error}
            -- TODO check if commenting this out causes variable leaks anywhere
            -- self:begin_scope()
            local aa = self:apply_generic(a, a)
            local ok, errs = self:is_a(aa, b)
            -- self:end_scope()
            return ok, errs
         end,
      },
      ["*"] = {
         ["any"] = compare_true,
         ["boolean_context"] = compare_true,
         ["emptytable"] = function(_self: TypeChecker, a: Type, _b: EmptyTableType): boolean, {Error}
            return false, { types.error("assigning %s to a variable declared with {}", a) }
         end,
         ["unresolved_emptytable_value"] = function(self: TypeChecker, a: Type, b: UnresolvedEmptyTableValueType): boolean, {Error}
            infer_emptytable_from_unresolved_value(self, b, b, a)
            return true
         end,
         ["generic"] = function(self: TypeChecker, a: Type, b: GenericType): boolean, {Error}
            -- TODO check if commenting this out causes variable leaks anywhere
            -- self:begin_scope()
            local bb = self:apply_generic(b, b)
            local ok, errs = self:is_a(a, bb)
            -- self:end_scope()
            return ok, errs
         end,
         ["self"] = function(self: TypeChecker, a: Type, b: SelfType): boolean, {Error}
            return self:is_a(a, (self:type_of_self(b)))
         end,
         ["tuple"] = function(self: TypeChecker, a: Type, b: Type): boolean, {Error}
            return self:is_a(a_tuple(a, {a}), b)
         end,
         ["typedecl"] = function(self: TypeChecker, a: Type, b: TypeDeclType): boolean, {Error}
            return self:is_a(a, b.def)
         end,
         ["typevar"] = function(self: TypeChecker, a: Type, b: TypeVarType): boolean, {Error}
            return self:compare_or_infer_typevar(b.typevar, a, nil, self.is_a)
         end,
         ["typearg"] = function(self: TypeChecker, a: Type, b: TypeArgType): boolean, {Error}
            if b.constraint then
               return self:is_a(a, b.constraint)
            end
         end,
         ["union"] = TypeChecker.exists_supertype_in as CompareTypes,                   -- ∃ t ∈ b, a <: t
                                                                                        -- ───────────────
                                                                                        --  a <: b union
         ["nominal"] = TypeChecker.subtype_nominal,
         ["poly"] = function(self: TypeChecker, a: Type, b: PolyType): boolean, {Error} -- ∀ t ∈ b, a <: t
            for _, t in ipairs(b.types) do                                              -- ───────────────
               if not self:is_a(a, t) then                                              --   a <: b poly
                  return false, { Err("cannot match against all alternatives of the polymorphic type") }
               end
            end
            return true
         end,
      },
   }

   -- evaluation strategy
   TypeChecker.type_priorities = {
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

   local function compare_types(self: TypeChecker, relations: TypeRelations, t1: Type, t2: Type): boolean, {Error}
      if t1.typeid == t2.typeid then
         return true
      end

      local s1 = relations[t1.typename]
      local fn = s1 and s1[t2.typename]
      if not fn then
         local p1 = self.type_priorities[t1.typename] or 999
         local p2 = self.type_priorities[t2.typename] or 999
         fn = (p1 < p2 and (s1 and s1["*"]) or (relations["*"][t2.typename]))
      end

      local ok, err: boolean, {Error}
      if fn then
         if fn == compare_true then
            return true
         end
         ok, err = fn(self, t1, t2)
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
            return false, { Err_at(t1, "types are incompatible") }
         else
            return false, { Err_at(t1, "got " .. show_t1 .. ", expected " .. show_t2) }
         end
      end
      return ok, err
   end

   -- subtyping comparison
   function TypeChecker:is_a(t1: Type, t2: Type): boolean, {Error}
      return compare_types(self, self.subtype_relations, t1, t2)
   end

   -- invariant type comparison
   function TypeChecker:same_type(t1: Type, t2: Type): boolean, {Error}
      -- except for error messages, behavior is the same as
      -- `return (is_a(t1, t2) and self:is_a(t2, t1))`
      return compare_types(self, self.eqtype_relations, t1, t2)
   end

   if TL_DEBUG then
      local orig_is_a = TypeChecker.is_a
      TypeChecker.is_a = function(self: TypeChecker, t1: Type, t2: Type): boolean, {Error}
         assert(type(t1) == "table")
         assert(type(t2) == "table")

         if t1.typeid == t2.typeid then
            local st1, st2 = show_type_base(t1, false, {}), show_type_base(t2, false, {})
            assert(st1 == st2, st1 .. " ~= " .. st2)
            return true
         end

         return orig_is_a(self, t1, t2)
      end
   end

   function TypeChecker:assert_is_a(w: Where, t1: Type, t2: Type, ctx?: string | Node, name?: string): boolean
      t1 = resolve_tuple(t1)
      t2 = resolve_tuple(t2)
      if self.feat_lax and (is_unknown(t1) or t2 is UnknownType) then
         return true
      end

      if t2 is EmptyTableType then
         t2 = type_at(w, t2) -- minor hack: tweak point of inference
      end

      local ok, match_errs = self:is_a(t1, t2)
      if not ok then
         self.errs:add_prefixing(w, match_errs, self.errs:get_context(ctx, name))
      end
      return ok
   end

   local function type_is_closable(t: Type): boolean
      if t is InvalidType then
         return false
      end
      if t is NilType then
         return true
      end
      if t is NominalType then
         t = assert(t.resolved)
      end
      if t is RecordLikeType then
         return t.meta_fields and t.meta_fields["__close"] ~= nil
      end
   end

   local definitely_not_closable_exprs <const>: {NodeKind:boolean} = {
      ["string"] = true,
      ["number"] = true,
      ["integer"] = true,
      ["boolean"] = true,
      ["literal_table"] = true,
   }
   local function expr_is_definitely_not_closable(e: Node): boolean
      return definitely_not_closable_exprs[e.kind]
   end

   function TypeChecker:same_in_all_union_entries<T is Type, F is Type>(u: UnionType, check: function(Type): (T, F)): F
      assert(#u.types > 0)

      local t1, f = check(u.types[1])
      if not t1 then
         return nil
      end
      for i = 2, #u.types do
         local t2 = check(u.types[i])
         if not t2 or not self:same_type(t1, t2) then
            return nil
         end
      end
      return f
   end

   function TypeChecker:same_call_mt_in_all_union_entries(u: UnionType): FunctionType
      return self:same_in_all_union_entries(u, function(t: Type): (TupleType, FunctionType)
         t = self:to_structural(t)
         if t is RecordLikeType then
            local call_mt = t.meta_fields and t.meta_fields["__call"]
            if call_mt is FunctionType then
               local args_tuple = a_tuple(u, {})
               for i = 2, #call_mt.args.tuple do
                  table.insert(args_tuple.tuple, call_mt.args.tuple[i])
               end
               return args_tuple, call_mt
            end
         end
      end)
   end

   function TypeChecker:resolve_for_call(func: Type, args: TupleType, is_method: boolean): Type, boolean
      -- resolve unknown in lax mode, produce a general unknown function
      if self.feat_lax and is_unknown(func) then
         local unk = func
         func = a_function(func, {
            min_arity = 0,
            args = a_vararg(func, { unk }),
            rets = a_vararg(func, { unk })
         })
      end
      -- unwrap if tuple, resolve if nominal
      func = self:to_structural(func)

      if func is GenericType then
         func = self:apply_generic(func, func)
      end

      if func is FunctionType or func is PolyType then
         return func, is_method
      end

      -- resolve if union
      if func is UnionType then
         local r = self:same_call_mt_in_all_union_entries(func)
         if r then
            table.insert(args.tuple, 1, func.types[1]) -- FIXME: is this right?
            return r, true
         end
      -- resolve if prototype
      elseif func is TypeDeclType then
         return self:resolve_for_call(func.def, args, is_method)
      -- resolve if metatable
      elseif func is RecordLikeType and func.meta_fields and func.meta_fields["__call"] then
         table.insert(args.tuple, 1, func)
         func = func.meta_fields["__call"]
         func = self:to_structural(func)
         is_method = true
      end

      if func is GenericType then
         func = self:apply_generic(func, func)
      end

      return func, is_method
   end

   local type OnArgId = function<T>(node: Node, i: integer): T
   local type OnNode = function<S, T>(s: S, node: Node, children: {T}, ret: T): T

   local function traverse_macroexp<T>(macroexp: Node, on_arg_id: OnArgId<T>, on_node: OnNode<nil, T>): T
      local root = macroexp.exp
      local argnames = {}
      for i, a in ipairs(macroexp.args) do
         argnames[a.tk] = i
      end

      local visit_node: Visitor<nil, NodeKind, Node, T> = {
         cbs = {
            ["variable"] = {
               after = function(_: nil, node: Node, _children: {T}): T
                  local i = argnames[node.tk]
                  if not i then
                     return nil
                  end

                  return on_arg_id(node, i)
               end
            },
            ["..."] = {
               after = function(_: nil, node: Node, _children: {T}): T
                  local i = argnames[node.tk]
                  if not i then
                     return nil
                  end

                  return on_arg_id(node, i)
               end
            }
         },
         after = on_node as VisitorAfter<nil, Node, T>,
      }

      return recurse_node(nil, root, visit_node, {})
   end

   local function expand_macroexp(orignode: Node, args: {Node}, macroexp: types.Node)
      local on_arg_id = function(node: Node, i: integer): {Node, Node}
         if node.kind == '...' then
            -- we have to handle varargs specifically
            local nd: Node = node_at(orignode, {
               kind = "expression_list",
            })
            for n = i, #args do
               nd[n - i + 1] = args[n]
            end
            return { Node, nd }
         else
            -- the function should have already been typechecked for optional
            -- parameters.
            -- this one is optional, so return nil
            local nd: Node = args[i] or node_at(orignode, { kind = "nil", tk = "nil" })
            return { Node, nd }
         end
      end

      local on_node = function(_: nil, node: Node, children: {{Node, Node}}, ret: {Node, Node}): {Node, Node}
         local orig = ret and ret[2] or node

         local out = shallow_copy_table(orig)

         local map = {}
         for _, pair in pairs(children as {integer:{Node, Node}}) do
            if type(pair) == "table" then
               map[pair[1]] = pair[2]
            end
         end

         for k, v in pairs(orig as {any:Node}) do
            if type(v) == "table" and map[v] then
               (out as {any:any})[k] = map[v]
            end
         end

         out.yend = out.yend and (orignode.y + (out.yend - out.y)) or nil
         out.xend = nil
         out.y = orignode.y
         out.x = orignode.x
         return { node, out }
      end

      local p = traverse_macroexp(macroexp as Node, on_arg_id, on_node)
      orignode.expanded = p[2]
   end

   function TypeChecker:check_macroexp_arg_use(macroexp: Node)
      local used: {string:boolean} = {}

      local on_arg_id = function(node: Node, _i: integer): {Node, Node}
         if used[node.tk] then
            self.errs:add(node, "cannot use argument '" .. node.tk .. "' multiple times in macroexp")
         else
            used[node.tk] = true
         end
      end

      traverse_macroexp(macroexp, on_arg_id, nil)
   end

   local function apply_macroexp(orignode: Node)
      local expanded = orignode.expanded
      local saveknown = orignode.known
      orignode.expanded = nil

      for k, _ in pairs(orignode as {any:any}) do
         (orignode as {any:any})[k] = nil
      end
      for k, v in pairs(expanded as {any:any}) do
         (orignode as {any:any})[k] = v
      end
      orignode.known = saveknown
   end

   do
      local function mark_invalid_typeargs(self: TypeChecker, typeargs: {TypeArgType})
         for _, a in ipairs(typeargs) do
            if not self:find_var_type(a.typearg) then
               if a.constraint then
                  self:add_var(nil, a.typearg, a.constraint)
               else
                  self:add_var(nil, a.typearg, self.feat_lax and an_unknown(a) or a_type(a, "unresolvable_typearg", {
                     typearg = a.typearg
                  } as UnresolvableTypeArgType))
               end
            end
         end
      end

      local function infer_emptytables(self: TypeChecker, w: Where, wheres: {Where}, xs: TupleType, ys: TupleType, delta: integer)
         local xt, yt = xs.tuple, ys.tuple
         local n_xs = #xt
         local n_ys = #yt
         -- resolve inference of emptytables used as arguments or returns
         for i = 1, n_xs do
            local x = xt[i]
            if x is EmptyTableType then
               local y = yt[i] or (ys.is_va and yt[n_ys])
               if y then -- y may not be present when inferring returns
                  local iw = wheres and wheres[i + delta] or w -- for self, a + argdelta is 0
                  local inferred_y = self:infer_at(iw, y)
                  self:infer_emptytable(x, inferred_y)
                  xt[i] = inferred_y
               end
            end
         end
      end

      local enum CallMode
         "method"   -- a method colon-call, e.g. `my_object:my_method()`
         "plain"    -- a plain call or a dot-call, e.g `my_func()` or `my_object.my_func()`
         "type_dot" -- a dot-call where the receiver is a type, e.g. `MyRecord.my_func()`
      end

      local check_call: function(self: TypeChecker, w: Where, wargs: {Where}, f: FunctionType, args: TupleType, expected_rets: TupleType, cm: CallMode, argdelta: integer, or_args: TupleType, or_rets: TupleType): boolean, {Error}
      do
         local check_args_rets: function(TypeChecker, w: Where, wargs: {Where}, f: FunctionType, args: TupleType, expected_rets: TupleType, argdelta: integer, or_args: TupleType, or_rets: TupleType): boolean, {Error}
         do
            -- check if a tuple `xs` matches tuple `ys`
            local function check_func_type_list(self: TypeChecker, w: Where, wheres: {Where}, xs: TupleType, ys: TupleType, from: integer, delta: integer, v: VarianceMode, mode: ArgCheckMode): boolean, {Error}
               local errs = {}
               local xt, yt = xs.tuple, ys.tuple
               local n_xs = #xt
               local n_ys = #yt

               for i = from, math.max(n_xs, n_ys) do
                  local pos = i + delta
                  local x = xt[i] or (xs.is_va and xt[n_xs]) or a_type(w, "nil", {})
                  local y = yt[i] or (ys.is_va and yt[n_ys])
                  if y then
                     local iw = wheres and wheres[pos] or w
                     if not self:arg_check(iw, errs, x, y, v, mode, pos) then
                        return nil, errs
                     end
                  end
               end

               return true
            end

            check_args_rets = function(self: TypeChecker, w: Where, wargs: {Where}, f: FunctionType, args: TupleType, expected_rets: TupleType, argdelta: integer, or_args: TupleType, or_rets: TupleType): boolean, {Error}
               local rets_ok = true
               local args_ok, args_errs: boolean, {Error} = true, nil

               local fargs = or_args or f.args
               local frets = or_rets or f.rets

               local from = 1
               if argdelta == -1 then
                  from = 2
                  local errs = {}
                  local first = fargs.tuple[1]
                  if (not first is SelfType) and not self:arg_check(w, errs, first, args.tuple[1], "contravariant", "self") then
                     return nil, errs
                  end
               end

               if expected_rets then
                  expected_rets = self:infer_at(w, expected_rets)
                  infer_emptytables(self, w, nil, expected_rets, frets, 0)

                  rets_ok = check_func_type_list(self, w, nil, frets, expected_rets, 1, 0, "covariant", "return")
               end

               args_ok, args_errs = check_func_type_list(self, w, wargs, fargs, args, from, argdelta, "contravariant", "argument")
               if (not args_ok) or (not rets_ok) then
                  return nil, args_errs or {}
               end

               infer_emptytables(self, w, wargs, args, fargs, argdelta)

               return true
            end
         end

         local function is_method_mismatch(self: TypeChecker, w: Where, arg1: Type, farg1: Type, cm: CallMode): boolean
            if cm == "method" or not farg1 then
               return false
            end
            if not (arg1 and self:is_a(arg1, farg1)) then
               self.errs:add(w, "invoked method as a regular function: use ':' instead of '.'")
               return true
            end
            if cm == "plain" then
               self.errs:add_warning("hint", w, "invoked method as a regular function: consider using ':' instead of '.'")
            end
            return false
         end

         check_call = function(self: TypeChecker, w: Where, wargs: {Where}, f: FunctionType, args: TupleType, expected_rets: TupleType, cm: CallMode, argdelta: integer, or_args: TupleType, or_rets: TupleType): boolean, {Error}
            local arg1 = args.tuple[1]
            if cm == "method" and arg1 then
               local selftype = arg1
               if selftype is SelfType then
                  selftype = self:type_of_self(selftype)
               end
               self:add_var(nil, "@self", a_typedecl(w, selftype))
            end

            local fargs = (or_args or f.args).tuple
            if f.is_method and is_method_mismatch(self, w, arg1, fargs[1], cm) then
               return false
            end

            local given = #args.tuple
            local wanted = #fargs
            local min_arity = self.feat_arity and f.min_arity or 0

            if given < min_arity or (given > wanted and not (or_args or f.args).is_va) then
               return nil, { Err_at(w, "wrong number of arguments (given " .. given .. ", expects " .. show_arity(f) .. ")") }
            end

            return check_args_rets(self, w, wargs, f, args, expected_rets, argdelta, or_args, or_rets)
         end
      end

      function TypeChecker:iterate_poly(p: PolyType): function(): integer, FunctionType
         local i = 0
         return function(): integer, FunctionType
            i = i + 1
            local fg = p.types[i]
            if not fg then
               return
            elseif fg is FunctionType then
               return i, fg
            elseif fg is GenericType then
               return i, self:apply_generic(p, fg) as FunctionType
            end
         end
      end

      local check_poly_call: function(self: TypeChecker, w: Where, wargs: {Where}, p: PolyType, args: TupleType, expected_rets: TupleType, cm: CallMode, argdelta: integer, or_args: TupleType, or_rets: TupleType): FunctionType, TupleType, {Error}
      do
         local function fail_poly_call_arity(self: TypeChecker, w: Where, p: PolyType, given: integer): {Error}
            local expects: {string} = {}
            for _, f in self:iterate_poly(p) do
               table.insert(expects, show_arity(f))
            end
            table.sort(expects)
            for i = #expects, 1, -1 do
               if expects[i] == expects[i+1] then
                  table.remove(expects, i)
               end
            end
            return { Err_at(w, "wrong number of arguments (given " .. given .. ", expects " .. table.concat(expects, " or ") .. ")") }
         end

         check_poly_call = function(self: TypeChecker, w: Where, wargs: {Where}, p: PolyType, args: TupleType, expected_rets: TupleType, cm: CallMode, argdelta: integer, or_args: TupleType, or_rets: TupleType): FunctionType, TupleType, {Error}
            local given = #args.tuple

            local tried: {integer:boolean} = {}
            local first_rets: TupleType
            local first_errs: {Error}

            for pass = 1, 3 do
               for i, f in self:iterate_poly(p) do
                  assert(f is FunctionType, f.typename)
                  assert(f.args)
                  first_rets = first_rets or or_rets or f.rets

                  local wanted = #f.args.tuple
                  local min_arity = self.feat_arity and f.min_arity or 0

                  if (not tried[i]) and
                     -- try exact arity matches first
                     (  (pass == 1 and given == wanted)
                     -- then try adjusting with nils to missing arguments or using '...'
                     or (pass == 2 and (given < wanted and given >= min_arity))
                     -- then finally try vararg functions
                     or (pass == 3 and (f.args.is_va and given > wanted)) )
                  then
                     local ok, errs = check_call(self, w, wargs, f, args, expected_rets, cm, argdelta, or_args, or_rets)
                     if ok then
                        return f, or_rets or f.rets
                     elseif expected_rets then
                        -- revert inferred returns
                        infer_emptytables(self, w, wargs, or_rets or f.rets, or_rets or f.rets, argdelta)
                     end

                     self:rollback_scope_transaction()

                     first_errs = first_errs or errs
                     tried[i] = true
                  end
               end
            end

            if not first_errs then
               return nil, first_rets, fail_poly_call_arity(self, w, p, given)
            end

            return nil, first_rets, first_errs
         end
      end

      local function should_warn_dot(node: Node, e1: Node, is_method: boolean): CallMode
         if is_method then
            return "method"
         end
         if node_is_funcall(node) and e1 and e1.receiver then
            local receiver = e1.receiver
            if receiver is NominalType then
               local resolved = receiver.resolved
               if resolved and resolved is TypeDeclType then
                  return "type_dot"
               end
            end
         end
         return "plain"
      end

      function TypeChecker:type_check_function_call(node: Node, func: Type, args: TupleType, argdelta: integer, or_args ?: TupleType, or_rets ?: TupleType, e1?: Node, e2?: {Node}): InvalidOrTupleType, FunctionType
         e1 = e1 or node.e1
         e2 = e2 or node.e2

         local expected = node.expected
         local expected_rets: TupleType
         if expected and expected is TupleType then
            expected_rets = expected
         else
            expected_rets = a_tuple(node, { node.expected })
         end

         self:begin_scope_transaction(node)

         local g: GenericType
         local typeargs: {TypeArgType}
         if func is GenericType then
            g = func
            func, typeargs = self:apply_generic(node, func)
         end

         local is_method = (argdelta == -1)

         if not (func is FunctionType or func is PolyType) then
            func, is_method = self:resolve_for_call(func, args, is_method)
            if is_method then
               argdelta = -1
            end
         end

         local cm = should_warn_dot(node, e1, is_method)

         local errs: {Error}
         local f, ret: FunctionType, InvalidOrTupleType

         if func is PolyType then
            f, ret, errs = check_poly_call(self, node, e2, func, args, expected_rets, cm, argdelta, or_args, or_rets)
         elseif func is FunctionType then
            local _: boolean
            _, errs = check_call(self, node, e2, func, args, expected_rets, cm, argdelta, or_args, or_rets)
            f, ret = func, or_rets or func.rets
         else
            ret = self.errs:invalid_at(node, "not a function: %s", func)
         end

         if errs then
            self.errs:collect(errs)
         end

         if g then
            mark_invalid_typeargs(self, typeargs)
         end

         self:commit_scope_transaction(node)

         ret = self:assert_resolved_typevars_at(node, ret) as InvalidOrTupleType

         if self.collector then
            self.collector.store_type(e1.y, e1.x, f)
         end

         if f and f.macroexp then
            local argexps: {Node}
            if is_method then
               argexps = {}
               if e1.kind == "op" then -- obj:method
                  table.insert(argexps, e1.e1)
               else -- __call metamethod
                  table.insert(argexps, e1)
               end
               for _, e in ipairs(e2) do
                  table.insert(argexps, e)
               end
            else
               argexps = e2
            end
            expand_macroexp(node, argexps, f.macroexp)
         end

         return ret, f
      end
   end

   function TypeChecker:check_metamethod(node: Node, method_name: string, a: Type, b: Type, orig_a: Type, orig_b: Type, flipped?: boolean): Type, integer
      if self.feat_lax and ((a and is_unknown(a)) or (b and is_unknown(b))) then
         return an_unknown(node), nil
      end

      local ameta = a is RecordLikeType and a.meta_fields
      local bmeta = b and b is RecordLikeType and b.meta_fields

      if not ameta and not bmeta then
         return nil, nil
      end

      local meta_on_operator = 1
      local metamethod: Type
      if method_name ~= "__is" then
         metamethod = ameta and ameta[method_name or ""]
      end
      if (not metamethod) and b and method_name ~= "__index" then
         metamethod = bmeta and bmeta[method_name or ""]
         meta_on_operator = 2
      end

      if metamethod then
         local e2 = { node.e1 }
         local args = a_tuple(node, { orig_a })
         if b and method_name ~= "__is" then
            e2[2] = node.e2
            args.tuple[2] = orig_b
         end
         if flipped then
            e2[2], e2[1] = e2[1], e2[2]
         end

         local mtdelta = metamethod is FunctionType and metamethod.is_method and -1 or 0
         local ret_call <const> = self:type_check_function_call(node, metamethod, args, mtdelta, nil, nil, node, e2)
         local ret_unary <const> = resolve_tuple(ret_call)
         local ret <const> = self:to_structural(ret_unary)
         return ret, meta_on_operator
      else
         return nil, nil
      end
   end

   local function make_is_node(self: TypeChecker, var: Node, v: Type, t: Type): Node, integer
      local node = node_at(var, { kind = "op", op = { op = "is", arity = 2, prec = 3 } })
      node.e1 = var
      node.e2 = node_at(var, { kind = "cast", casttype = self:infer_at(var, t) })
      local _, has = self:check_metamethod(node, "__is", self:to_structural(v), self:to_structural(t), v, t)
      if node.expanded then
         apply_macroexp(node)
      end
      node.known = IsFact { var = var.tk, typ = t, w = node }
      return node, has
   end

   local function convert_is_of_union_to_or_of_is(self: TypeChecker, node: Node, v: Type, u: UnionType): boolean
      local var = node.e1
      node.op.op = "or"
      node.op.arity = 2
      node.op.prec = 1
      local has_any: integer = nil
      node.e1, has_any = make_is_node(self, var, v, u.types[1])
      local at = node
      local n = #u.types
      for i = 2, n - 1 do
         at.e2 = node_at(var, { kind = "op", op = { op = "or", arity = 2, prec = 1 } })
         local has: integer
         at.e2.e1, has = make_is_node(self, var, v, u.types[i])
         has_any = has_any or has
         node.known = OrFact { f1 = at.e1.known, f2 = at.e2.known, w = node }
         at = at.e2
      end
      at.e2 = make_is_node(self, var, v, u.types[n])
      node.known = OrFact { f1 = at.e1.known, f2 = at.e2.known, w = node }
      return not not has_any
   end

   function TypeChecker:match_record_key(t: Type, rec: Node, key: string): Type, string
      t = self:to_structural(t)

      if t is SelfType then
         t = self:type_of_self(t)
      end

      if t is StringType or t is EnumType then
         -- simulate string metatable
         t = self.env.modules["string"]
         self.all_needs_compat["string"] = true
      end

      if t is TypeDeclType then
         if t.is_nested_alias then
            return nil, "cannot use a nested type alias as a concrete value"
         end
         local def = t.def
         if def is NominalType then
            assert(t.is_alias)
            t = self:resolve_nominal(def)
         else
            t = def
         end
      end

      if t is GenericType then
         t = self:apply_generic(t, t)
      end

      if t is UnionType then
         local ty = self:same_in_all_union_entries(t, function(typ: Type): (Type, Type)
            local v = self:match_record_key(typ, rec, key)
            return v, v
         end)
         if ty then
            return ty
         end
      end

      if (t is TypeVarType or t is TypeArgType) and t.constraint then
         local ty = self:match_record_key(t.constraint, rec, key)
         if ty then
            return ty
         end
      end

      local keyg = key:gsub("%%", "%%%%")

      if t is RecordLikeType then
         assert(t.fields, "record has no fields!?")

         if t.fields[key] then
            return t.fields[key]
         end

         local str = a_type(rec, "string", {})
         local meta_t = self:check_metamethod(rec, "__index", t, str, t, str)
         if meta_t then
            return meta_t
         end

         if rec.kind == "variable" then
            if t is InterfaceType then
               return nil, "invalid key '" .. keyg .. "' in '" .. rec.tk .. "' of interface type %s"
            else
               return nil, "invalid key '" .. keyg .. "' in record '" .. rec.tk .. "' of type %s"
            end
         else
            return nil, "invalid key '" .. keyg .. "' in type %s"
         end
      elseif t is EmptyTableType or is_unknown(t) then
         if self.feat_lax then
            return an_unknown(rec)
         end
         return nil, "cannot index a value of unknown type"
      end

      if rec.kind == "variable" then
         return nil, "cannot index key '" .. keyg .. "' in variable '" .. rec.tk .. "' of type %s"
      else
         return nil, "cannot index key '" .. keyg .. "' in type %s"
      end
   end

   local function assigned_anywhere(name: string, root: Node): boolean
      local visit_node: Visitor<nil, NodeKind, Node, boolean> = {
         cbs = {
            ["assignment"] = {
               after = function(_: nil, node: Node, _children: {boolean}): boolean
                  for _, v in ipairs(node.vars) do
                     if v.kind == "variable" and v.tk == name then
                        return true
                     end
                  end
                  return false
               end
            }
         },
         after = function(_: nil, _node: Node, children: {boolean}, ret: boolean): boolean
            ret = ret or false
            for _, c in ipairs(children) do
               local ca = c as any
               if ca is boolean then
                  ret = ret or c
               end
            end
            return ret
         end
      }

      local visit_type: Visitor<nil, TypeName, Type, boolean> = {
         after = function(): boolean
            return false
         end
      }

      return recurse_node(nil, root, visit_node, visit_type)
   end

   function TypeChecker:widen_all_unions(node?: Node)
      for i = #self.st, 1, -1 do
         local scope = self.st[i]
         if scope.narrows then
            for name, _ in pairs(scope.narrows) do
               if not node or assigned_anywhere(name, node) then
                  self:widen_in_scope(i, name)
               end
            end
         end
      end
   end

   function TypeChecker:add_global(node: Node, varname: string, valtype: Type, is_assigning?: boolean): Variable
      if self.feat_lax and is_unknown(valtype) and (varname ~= "self" and varname ~= "...") then
         self.errs:add_unknown(node, varname)
      end

      local is_const = node.attribute ~= nil
      local existing, scope, existing_attr = self:find_var(varname)
      if existing then
         if scope > 1 then
            self.errs:add(node, "cannot define a global when a local with the same name is in scope")
         elseif is_assigning and existing_attr then
            self.errs:add(node, "cannot reassign to <" .. existing_attr .. "> global: " .. varname)
         elseif existing_attr and not is_const then
            self.errs:add(node, "global was previously declared as <" .. existing_attr .. ">: " .. varname)
         elseif (not existing_attr) and is_const then
            self.errs:add(node, "global was previously declared as not <" .. node.attribute .. ">: " .. varname)
         elseif valtype and not self:same_type(existing.t, valtype) then
            self.errs:add(node, "cannot redeclare global with a different type: previous type of " .. varname .. " is %s", existing.t)
         end
         return nil
      end

      local var = { t = valtype, attribute = is_const and "const" or nil }
      self.st[1].vars[varname] = var

      return var
   end

   function TypeChecker:add_internal_function_variables(node: Node, args: TupleType)
      self:add_var(nil, "@is_va", a_type(node, args.is_va and "any" or "nil", {}))
      self:add_var(nil, "@return", node.rets or a_tuple(node, {}))

      if node.typeargs then
         for _, t in ipairs(node.typeargs) do
            local v = self:find_var(t.typearg, "check_only")
            if not v or not v.used_as_type then
               self.errs:add(t, "type argument '%s' is not used in function signature", t)
            end
         end
      end
   end

   function TypeChecker:add_function_definition_for_recursion(node: Node, fnargs: TupleType, feat_arity: boolean)
      self:add_var(nil, node.name.tk, wrap_generic_if_typeargs(node.typeargs, a_function(node, {
         min_arity = feat_arity and node.min_arity or 0,
         args = fnargs,
         rets = self.get_rets(node.rets),
      })))
   end

   function TypeChecker:end_function_scope(node: Node)
      self.errs:fail_unresolved_labels(self.st[#self.st])
      self:end_scope(node)
   end

   local function flat_tuple(w: Where, vt: {FirstClassType | TupleType}): TupleType
      local n_vals = #vt
      local ret = a_tuple(w, {})
      local rt = ret.tuple

      if n_vals == 0 then
         return ret
      end

      -- get all arguments except the last...
      for i = 1, n_vals - 1 do
         rt[i] = resolve_tuple(vt[i])
      end

      local last = vt[n_vals]
      if last is TupleType then
         -- ...then unpack the last tuple
         local lt = last.tuple
         for _, v in ipairs(lt) do
            table.insert(rt, v)
         end
         ret.is_va = last.is_va
      else
         rt[n_vals] = vt[n_vals]
      end

      return ret
   end

   local function get_assignment_values(w: Where, vals: TupleType, wanted: integer): TupleType
      if vals == nil then
         return a_tuple(w, {})
      end

      -- ...if the last is vararg, repeat its type until it matches the number of wanted args
      if vals.is_va then
         local vt = vals.tuple
         local n_vals = #vt
         if n_vals > 0 and n_vals < wanted then
            local last = vt[n_vals]
            local ret = a_tuple(w, {})
            local rt = ret.tuple
            for i = 1, n_vals do
               table.insert(rt, vt[i])
            end
            for _ = n_vals + 1, wanted do
               table.insert(rt, last)
            end
            return ret
         end
      end
      return vals
   end

   function TypeChecker:match_all_record_field_names(node: Node, a: RecordLikeType, field_names: {string}, errmsg: string): Type
      local t: Type
      for _, k in ipairs(field_names) do
         local f = a.fields[k]
         if not t then
            t = f
         else
            if not self:same_type(f, t) then
               errmsg = errmsg .. string.format(" (types of fields '%s' and '%s' do not match)", field_names[1], k)
               t = nil
               break
            end
         end
      end
      if t then
         return t
      else
         return self.errs:invalid_at(node, errmsg)
      end
   end

   function TypeChecker:type_check_index(anode: Node, bnode: Node, a: Type, b: Type): Type
      assert(not a is TupleType)
      assert(not b is TupleType)

      local ra = resolve_typedecl(self:to_structural(a))
      local rb = self:to_structural(b)

      if self.feat_lax and is_unknown(a) then
         return a
      end

      local errm: string
      local erra: Type
      local errb: Type

      if ra is TupleTableType and rb is IntegerType then
         if bnode.constnum then
            if bnode.constnum >= 1 and bnode.constnum <= #ra.types and bnode.constnum == math.floor(bnode.constnum) then
               return ra.types[bnode.constnum as integer]
            end

            errm, erra = "index " .. tostring(bnode.constnum) .. " out of range for tuple %s", ra
         else
            local array_type = self:arraytype_from_tuple(bnode, ra)
            if array_type then
               return array_type.elements
            end

            errm = "cannot index this tuple with a variable because it would produce a union type that cannot be discriminated at runtime"
         end
      elseif ra is SelfType then
         return self:type_check_index(anode, bnode, self:type_of_self(a), b)
      elseif ra is ArrayLikeType and rb is IntegerType then
         return ra.elements
      elseif ra is EmptyTableType then
         if ra.keys == nil then
            ra.keys = self:infer_at(bnode, b)
         end

         if self:is_a(b, ra.keys) then
            return a_type(anode, "unresolved_emptytable_value", {
               emptytable_type = ra
            } as UnresolvedEmptyTableValueType)
         end

         errm, erra, errb = "inconsistent index type: got %s, expected %s" .. types.inferred_msg(ra.keys, "type of keys "), b, ra.keys
      elseif ra is UnresolvedEmptyTableValueType then
         local et = a_type(ra, "emptytable", { keys = b } as EmptyTableType)
         infer_emptytable_from_unresolved_value(self, a, ra, et)
         return a_type(anode, "unresolved_emptytable_value", {
            emptytable_type = et
         } as UnresolvedEmptyTableValueType)
      elseif ra is MapType then
         if self:is_a(b, ra.keys) then
            return ra.values
         end

         errm, erra, errb = "wrong index type: got %s, expected %s", b, ra.keys
      elseif rb is StringType and rb.literal then
         local t, e = self:match_record_key(a, anode, rb.literal)
         if t then

            if t is FunctionType and t.is_method then
               local t2 = shallow_copy_new_type(t)
               t2.args = shallow_copy_new_type(t.args)
               t2.args.tuple = shallow_copy_table(t2.args.tuple)
               for i, p in ipairs(t2.args.tuple) do
                  if p is SelfType then
                     t2.args.tuple[i] = a
                  end
               end
               return t2
            end

            return t
         end

         errm, erra = e, a
      elseif ra is RecordLikeType then
         if rb is EnumType then
            local field_names: {string} = sorted_keys(rb.enumset)
            for _, k in ipairs(field_names) do
               if not ra.fields[k] then
                  errm, erra = "enum value '" .. k:gsub("%%", "%%%%") .. "' is not a field in %s", ra
                  break
               end
            end
            if not errm then
               return self:match_all_record_field_names(bnode, ra, field_names,
                         "cannot index, not all enum values map to record fields of the same type")
            end
         elseif rb is StringType then
            errm, erra = "cannot index object of type %s with a string, consider using an enum", a
         else
            errm, erra, errb = "cannot index object of type %s with %s", a, b
         end
      else
         errm, erra, errb = "cannot index object of type %s with %s", a, b
      end

      local meta_t = self:check_metamethod(anode, "__index", ra, b, a, b)
      if meta_t then
         return meta_t
      end

      return self.errs:invalid_at(bnode, errm, erra, errb)
   end

   function TypeChecker:expand_type(w: Where, old: Type, new: Type): Type
      if not old or old is NilType then
         return new
      end
      if self:is_a(new, old) then
         return old
      end

      if new is RecordLikeType then
         local keys: Type
         local values: Type
         if old is MapType then
            keys = old.keys
            if not keys is StringType then
               self.errs:add(w, "cannot determine table literal type")
               return old
            end
            values = old.values
         elseif old is RecordLikeType then
            keys = a_type(w, "string", {})
            for _, ftype in fields_of(old) do
               values = self:expand_type(w, values, ftype)
            end
         end

         for _, ftype in fields_of(new) do
            values = self:expand_type(w, values, ftype)
         end

         return a_map(w, keys, values)
      end

      return unite(w, { old, new }, true)
   end

   function TypeChecker:find_record_to_extend(exp: Node): Type, Variable, string
      -- base
      if exp.kind == "type_identifier" then
         local v = self:find_var(exp.tk)
         if not v then
            return nil, nil, exp.tk
         end

         local t = v.t
         if t is TypeDeclType then
            if t.closed then
               return nil, nil, exp.tk
            end

            return t.def, v, exp.tk
         end

         return t, v, exp.tk
      -- recurse
      elseif exp.kind == "op" then -- assert(exp.op.op == ".")
         local t, v, rname = self:find_record_to_extend(exp.e1)
         local fname = exp.e2.tk
         local dname = rname .. "." .. fname
         if not t then
            return nil, nil, dname
         end
         if not t is RecordLikeType then
            return nil, nil, dname
         end
         t = t.fields[fname]

         if t is TypeDeclType then
            local def = t.def
            if def is NominalType then
               assert(t.is_alias)
               t = def.resolved
            else
               t = def
            end
         end

         return t, v, dname
      end
   end

   local function typedecl_to_nominal(w: Where, name: string, t: TypeDeclType, resolved?: Type): Type
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
      local nom = a_nominal(w, { name })
      nom.typevals = typevals
      nom.found = t
      nom.resolved = resolved
      return nom
   end

   function TypeChecker:get_self_type(exp: Node): Type
      -- base
      if exp.kind == "type_identifier" then
         local t = self:find_var_type(exp.tk)
         if not t then
            return nil
         end

         if t is TypeDeclType then
            return typedecl_to_nominal(exp, exp.tk, t)
         else
            return t
         end
      -- recurse
      elseif exp.kind == "op" then -- assert(exp.op.op == ".")
         local t = self:get_self_type(exp.e1)
         if not t then
            return nil
         end

         if t is NominalType then
            local found = t.found
            if found then
               if found is TypeDeclType then
                  local def = found.def
                  if def is RecordLikeType and def.fields[exp.e2.tk] then
                     table.insert(t.names, exp.e2.tk)
                     local ft = def.fields[exp.e2.tk]
                     if ft is TypeDeclType then
                        t.found = ft
                     else
                        return nil
                     end
                  end
               end
            end
         elseif t is RecordLikeType then
            return t.fields and t.fields[exp.e2.tk]
         end
         return t
      end
   end

   -- Inference engine for 'is' operator
   local facts_and: function(w: Where, f1: Fact, f2: Fact): Fact
   local facts_or: function(w: Where, f1: Fact, f2: Fact): Fact
   local facts_not: function(w: Where, f1: Fact): Fact
   local FACT_TRUTHY: Fact
   do
      local IsFact_mt: metatable<IsFact> = {
         __tostring = function(f: IsFact): string
            return ("(%s is %s)"):format(f.var, show_type(f.typ))
         end
      }

      setmetatable(IsFact, {
         __call = function(_: IsFact, fact: Fact): IsFact
            fact.fact = "is"
            assert(fact.w)
            return setmetatable(fact as IsFact, IsFact_mt)
         end,
      })

      local EqFact_mt: metatable<EqFact> = {
         __tostring = function(f: EqFact): string
            return ("(%s == %s)"):format(f.var, show_type(f.typ))
         end
      }

      setmetatable(EqFact, {
         __call = function(_: EqFact, fact: Fact): EqFact
            fact.fact = "=="
            assert(fact.w)
            return setmetatable(fact as EqFact, EqFact_mt)
         end,
      })

      local TruthyFact_mt: metatable<TruthyFact> = {
         __tostring = function(_f: TruthyFact): string
            return "*"
         end
      }

      setmetatable(TruthyFact, {
         __call = function(_: TruthyFact, fact: Fact): TruthyFact
            fact.fact = "truthy"
            return setmetatable(fact as TruthyFact, TruthyFact_mt)
         end,
      })

      local NotFact_mt: metatable<NotFact> = {
         __tostring = function(f: NotFact): string
            return ("(not %s)"):format(tostring(f.f1))
         end
      }

      setmetatable(NotFact, {
         __call = function(_: NotFact, fact: Fact): NotFact
            fact.fact = "not"
            return setmetatable(fact as NotFact, NotFact_mt)
         end,
      })

      local AndFact_mt: metatable<AndFact> = {
         __tostring = function(f: AndFact): string
            return ("(%s and %s)"):format(tostring(f.f1), tostring(f.f2))
         end
      }

      setmetatable(AndFact, {
         __call = function(_: AndFact, fact: Fact): AndFact
            fact.fact = "and"
            return setmetatable(fact as AndFact, AndFact_mt)
         end,
      })

      local OrFact_mt: metatable<OrFact> = {
         __tostring = function(f: OrFact): string
            return ("(%s or %s)"):format(tostring(f.f1), tostring(f.f2))
         end
      }

      setmetatable(OrFact, {
         __call = function(_: OrFact, fact: Fact): OrFact
            fact.fact = "or"
            return setmetatable(fact as OrFact, OrFact_mt)
         end,
      })

      FACT_TRUTHY = TruthyFact {}

      facts_and = function(w: Where, f1: Fact, f2: Fact): Fact
         if not f1 and not f2 then
            return
         end
         return AndFact { f1 = f1, f2 = f2, w = w }
      end

      facts_or = function(w: Where, f1: Fact, f2: Fact): Fact
         return OrFact({ f1 = f1 or FACT_TRUTHY, f2 = f2 or FACT_TRUTHY, w = w })
      end

      facts_not = function(w: Where, f1: Fact): Fact
         if f1 then
            return NotFact { f1 = f1, w = w }
         else
            return nil
         end
      end

      -- t1 ∪ t2
      local function unite_types(w: Where, t1: Type, t2: Type): Type, string
         return unite(w, {t2, t1})
      end

      -- t1 ∩ t2
      local function intersect_types(self: TypeChecker, w: Where, t1: Type, t2: Type): Type, string
         if t2 is UnionType then
            t1, t2 = t2, t1
         end
         if t1 is UnionType then
            local out = {}
            for _, t in ipairs(t1.types) do
               if self:is_a(t, t2) then
                  table.insert(out, t)
               end
            end
            if #out > 0 then
               return unite(w, out)
            end
         end
         if self:is_a(t1, t2) then
            return t1
         elseif self:is_a(t2, t1) then
            return t2
         else
            return a_type(w, "nil", {}) -- because of implicit nil in all unions
         end
      end

      function TypeChecker:resolve_if_union(t: Type): Type
         local rt = self:to_structural(t)
         if rt is UnionType then
            return rt
         end
         return t
      end

      -- t1 - t2
      local function subtract_types(self: TypeChecker, w: Where, t1: Type, t2: Type): Type
         local typs: {Type} = {}

         t1 = self:resolve_if_union(t1)

         -- poly are not first-class, so we don't handle them here
         if not t1 is UnionType then
            return t1
         end

         t2 = self:resolve_if_union(t2)
         local t2types = t2 is UnionType and t2.types or { t2 }

         for _, at in ipairs(t1.types) do
            local not_present = true
            for _, bt in ipairs(t2types) do
               if self:same_type(at, bt) then
                  not_present = false
                  break
               end
            end
            if not_present then
               table.insert(typs, at)
            end
         end

         if #typs == 0 then
            return a_type(w, "nil", {}) -- because of implicit nil in all unions
         end

         return unite(w, typs)
      end

      local eval_not: function(TypeChecker, f: Fact): {string:IsFact|EqFact}
      local not_facts: function(TypeChecker, fs: {string:IsFact|EqFact}): {string:IsFact|EqFact}
      local or_facts: function(TypeChecker, fs1: {string:IsFact|EqFact}, fs2: {string:IsFact|EqFact}): {string:IsFact|EqFact}
      local and_facts: function(TypeChecker, fs1: {string:IsFact|EqFact}, fs2: {string:IsFact|EqFact}): {string:IsFact|EqFact}
      local eval_fact: function(TypeChecker, f: Fact): {string:IsFact|EqFact}

      local function invalid_from(f: IsFact): IsFact
         return IsFact { fact = "is", var = f.var, typ = a_type(f.w, "invalid", {}), w = f.w }
      end

      not_facts = function(self: TypeChecker, fs: {string:IsFact|EqFact}): {string:IsFact|EqFact}
         local ret: {string:IsFact|EqFact} = {}
         for var, f in pairs(fs) do
            local typ = self:find_var_type(f.var, "check_only")

            if not typ then
               ret[var] = EqFact { var = var, typ = an_invalid(f.w), w = f.w, no_infer = f.no_infer }
            elseif f is EqFact then
               -- nothing is known from negation of equality; widen back
               ret[var] = EqFact { var = var, typ = typ, w = f.w, no_infer = true }
            elseif typ is TypeVarType then
               assert(f.fact == "is")
               -- nothing is known from negation on typeargs; widen back
               ret[var] = EqFact { var = var, typ = typ, w = f.w, no_infer = true }
            elseif not self:is_a(f.typ, typ) then
               assert(f.fact == "is")
               self.errs:add_warning("branch", f.w, f.var .. " (of type %s) can never be a %s", show_type(typ), show_type(f.typ))
               ret[var] = EqFact { var = var, typ = an_invalid(f.w), w = f.w, no_infer = f.no_infer }
            else
               assert(f.fact == "is")
               ret[var] = IsFact { var = var, typ = subtract_types(self, f.w, typ, f.typ), w = f.w, no_infer = f.no_infer }
            end
         end
         return ret
      end

      eval_not = function(self: TypeChecker, f: Fact): {string:IsFact|EqFact}
         if not f then
            return {}
         elseif f is IsFact then
            return not_facts(self, {[f.var] = f})
         elseif f is NotFact then
            return eval_fact(self, f.f1)
         elseif f is AndFact and f.f2 and f.f2.fact == "truthy" then
            return eval_not(self, f.f1)
         elseif f is OrFact and f.f2 and f.f2.fact == "truthy" then
            return eval_not(self, f.f1)
         elseif f is AndFact then
            return or_facts(self, eval_not(self, f.f1), eval_not(self, f.f2))
         elseif f is OrFact then
            return and_facts(self, eval_not(self, f.f1), eval_not(self, f.f2))
         else
            return not_facts(self, eval_fact(self, f))
         end
      end

      or_facts = function(_self: TypeChecker, fs1: {string:IsFact|EqFact}, fs2: {string:IsFact|EqFact}): {string:IsFact|EqFact}
         local ret: {string:IsFact|EqFact} = {}

         for var, f in pairs(fs2) do
            if fs1[var] then
               local united = unite_types(f.w, f.typ, fs1[var].typ)
               if fs1[var].fact == "is" and f.fact == "is" then
                  ret[var] = IsFact { var = var, typ = united, w = f.w }
               else
                  ret[var] = EqFact { var = var, typ = united, w = f.w }
               end
            end
         end

         return ret
      end

      and_facts = function(self: TypeChecker, fs1: {string:IsFact|EqFact}, fs2: {string:IsFact|EqFact}): {string:IsFact|EqFact}
         local ret: {string:IsFact|EqFact} = {}
         local has: {FactType:boolean} = {}

         for var, f in pairs(fs1) do
            local rt: Type
            local ctor: IsFact | EqFact = EqFact
            if fs2[var] then
               if fs2[var].fact == "is" and f.fact == "is" then
                  ctor = IsFact
               end
               rt = intersect_types(self, f.w, f.typ, fs2[var].typ)
            else
               rt = f.typ
            end
            local ff = ctor { var = var, typ = rt, w = f.w, no_infer = f.no_infer }
            ret[var] = ff
            has[ff.fact] = true
         end

         for var, f in pairs(fs2) do
            if not fs1[var] then
               ret[var] = EqFact { var = var, typ = f.typ, w = f.w, no_infer = f.no_infer }
               has["=="] = true
            end
         end

         if has["is"] and has["=="] then
            for _, f in pairs(ret) do
               f.fact = "=="
            end
         end

         return ret
      end

      eval_fact = function(self: TypeChecker, f: Fact): {string:IsFact|EqFact}
         if not f then
            return {}
         elseif f is IsFact then
            local typ = self:find_var_type(f.var, "check_only")
            if not typ then
               return { [f.var] = invalid_from(f) }
            end
            if not typ is TypeVarType then
               if self:is_a(typ, f.typ) then
                  -- drop this warning because of implicit nil in all unions
                  -- self.errs:add_warning("branch", f.w, f.var .. " (of type %s) is always a %s", show_type(typ), show_type(f.typ))
                  return { [f.var] = f }
               elseif not self:is_a(f.typ, typ) then
                  self.errs:add(f.w, f.var .. " (of type %s) can never be a %s", typ, f.typ)
                  return { [f.var] = invalid_from(f) }
               end
            end
            return { [f.var] = f }
         elseif f is EqFact then
            return { [f.var] = f }
         elseif f is NotFact then
            return eval_not(self, f.f1)
         elseif f is TruthyFact then
            return {}
         elseif f is AndFact and f.f2 and f.f2.fact == "truthy" then
            return eval_fact(self, f.f1)
         elseif f is OrFact and f.f2 and f.f2.fact == "truthy" then
            return eval_not(self, f.f1)
         elseif f is AndFact then
            return and_facts(self, eval_fact(self, f.f1), eval_fact(self, f.f2))
         elseif f is OrFact then
            return or_facts(self, eval_fact(self, f.f1), eval_fact(self, f.f2))
         end
      end

      function TypeChecker:apply_facts(w: Where, known: Fact)
         if not known then
            return
         end

         local fcts = eval_fact(self, known)

         for v, f in pairs(fcts) do
            if f.typ.typename == "invalid" then
               self.errs:add(w, "cannot resolve a type for " .. v .. " here")
            end
            local t = f.no_infer and f.typ or self:infer_at(w, f.typ)
            if f.no_infer then
               t.inferred_at = nil
            end
            self:add_var(nil, v, t, "const", "narrow")
         end
      end

      if TL_DEBUG_FACTS then
         local eval_indent = -1
         local real_eval_fact = eval_fact
         eval_fact = function(self: TypeChecker, known: Fact): {string: IsFact|EqFact}
            eval_indent = eval_indent + 1
            io.stderr:write(("   "):rep(eval_indent))
            io.stderr:write("eval fact: ", tostring(known), "\n")
            local fcts = real_eval_fact(self, known)
            if fcts then
               for _, k in ipairs(sorted_keys(fcts)) do
                  local f = fcts[k]
                  io.stderr:write(("   "):rep(eval_indent), "=> ", tostring(f), "\n")
               end
            else
               io.stderr:write(("   "):rep(eval_indent), "=> .\n")
            end
            eval_indent = eval_indent - 1
            return fcts
         end
      end
   end

   function TypeChecker:dismiss_unresolved(name: string)
      for i = #self.st, 1, -1 do
         local scope = self.st[i]
         local uses = scope.pending_nominals and scope.pending_nominals[name]
         if uses then
            for _, t in ipairs(uses) do
               self:resolve_nominal(t)
            end
            scope.pending_nominals[name] = nil
            return
         end
      end
   end

   local function special_pcall_xpcall(self: TypeChecker, node: Node, a: FunctionType, b: TupleType, argdelta?: integer): Type
      local isx = a.special_function_handler == "xpcall"
      local base_nargs = isx and 2 or 1
      local bool = a_type(node, "boolean", {})
      if #node.e2 < base_nargs then
         self.errs:add(node, "wrong number of arguments (given " .. #node.e2 .. ", expects at least " .. base_nargs .. ")")
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
            rets = a_tuple(arg2, {})
         })
         self:assert_is_a(arg2, msgh, msgh_type, "in message handler")
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

   local special_functions <total>: {SpecialFunctionName : function(TypeChecker, Node, Type, TupleType, ? integer):InvalidOrTupleType } = {
      ["pairs"] = function(self: TypeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
         if not b.tuple[1] then
            return self.errs:invalid_at(node, "pairs requires an argument")
         end
         local t = self:to_structural(b.tuple[1])
         if t is ArrayLikeType then
            self.errs:add_warning("hint", node, "hint: applying pairs on an array: did you intend to apply ipairs?")
         end

         if not t is MapType then
            if not (self.feat_lax and is_unknown(t)) then
               if t is RecordLikeType then
                  self:match_all_record_field_names(node.e2, t, t.field_order,
                     "attempting pairs on a record with attributes of different types")
                  local ct = t is RecordType and "{string:any}" or "{any:any}"
                  self.errs:add_warning("hint", node.e2, "hint: if you want to iterate over fields of a record, cast it to " .. ct)
               else
                  self.errs:add(node.e2, "cannot apply pairs on values of type: %s", t)
               end
            end
         end

         return (self:type_check_function_call(node, a, b, argdelta))
      end,

      ["ipairs"] = function(self: TypeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
         if not b.tuple[1] then
            return self.errs:invalid_at(node, "ipairs requires an argument")
         end
         local orig_t = b.tuple[1]
         local t = self:to_structural(orig_t)

         if t is TupleTableType then
            local arr_type = self:arraytype_from_tuple(node.e2, t)
            if not arr_type then
               return self.errs:invalid_at(node.e2, "attempting ipairs on tuple that's not a valid array: %s", orig_t)
            end
         elseif not t is ArrayLikeType then
            if not (self.feat_lax and (is_unknown(t) or t is EmptyTableType)) then
               return self.errs:invalid_at(node.e2, "attempting ipairs on something that's not an array: %s", orig_t)
            end
         end

         return (self:type_check_function_call(node, a, b, argdelta))
      end,

      ["rawget"] = function(self: TypeChecker, node: Node, _a: Type, b: TupleType, _argdelta?: integer): InvalidOrTupleType
         -- TODO should those offsets be fixed by _argdelta?
         if #b.tuple == 2 then
            return a_tuple(node, { self:type_check_index(node.e2[1], node.e2[2], b.tuple[1], b.tuple[2]) })
         else
            return self.errs:invalid_at(node, "rawget expects two arguments")
         end
      end,

      ["require"] = function(self: TypeChecker, node: Node, _a: Type, b: TupleType, _argdelta?: integer): InvalidOrTupleType
         if #b.tuple ~= 1 then
            return self.errs:invalid_at(node, "require expects one literal argument")
         end
         if node.e2[1].kind ~= "string" then
            return a_tuple(node, { a_type(node, "any", {}) })
         end

         local module_name = assert(node.e2[1].conststr)
         local tc_opts: CheckOptions = {
            feat_lax = self.feat_lax and "on" or "off",
            feat_arity = self.feat_arity and "on" or "off",
         }
         local t, module_filename = require_module(node, module_name, tc_opts, self.env)

         if t is InvalidType then
            if not module_filename then
               return self.errs:invalid_at(node, "module not found: '" .. module_name .. "'")
            end

            if self.feat_lax then
               return a_tuple(node, { an_unknown(node) })
            end
            return self.errs:invalid_at(node, "no type information for required module: '" .. module_name .. "'")
         end

         self.dependencies[module_name] = module_filename
         return a_tuple(node, { t })
      end,

      ["pcall"] = special_pcall_xpcall,
      ["xpcall"] = special_pcall_xpcall,
      ["assert"] = function(self: TypeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
         node.known = FACT_TRUTHY
         local r = self:type_check_function_call(node, a, b, argdelta)
         self:apply_facts(node, node.e2[1].known)
         return r
      end,
      ["string.pack"] = function(self: TypeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
         if #b.tuple < 1 then
            return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects at least 1)")
         end

         local packstr = b.tuple[1]

         if packstr is StringType and packstr.literal and a is FunctionType then
            local st = packstr.literal
            local items, e = parse_pack_string(node, st)

            if e then
               if items then
                  -- just a warning
                  self.errs:add_warning("hint", packstr, e)
               else
                  return self.errs:invalid_at(packstr, e)
               end
            end

            table.insert(items, 1, a_type(node, "string", {}))

            if #items ~= #b.tuple then
               return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects " .. #items .. ")")
            end

            return (self:type_check_function_call(node, a, b, argdelta, a_tuple(node, items), nil))
         else
            return (self:type_check_function_call(node, a, b, argdelta))
         end
      end,

      ["string.unpack"] = function(self: TypeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
         if #b.tuple < 2 or #b.tuple > 3 then
            return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 2 or 3)")
         end

         local packstr = b.tuple[1]

         local rets: TupleType

         if packstr is StringType and packstr.literal then
            local st = packstr.literal
            local items, e = parse_pack_string(node, st)

            if e then
               if items then
                  -- just a warning
                  self.errs:add_warning("hint", packstr, e)
               else
                  return self.errs:invalid_at(packstr, e)
               end
            end

            table.insert(items, a_type(node, "integer", {}))

            -- set the returns to match the response
            rets = a_tuple(node, items)
         end

         return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
      end,

      ["string.format"] = function(self: TypeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
         if #b.tuple < 1 then
            return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects at least 1)")
         end

         local fstr = b.tuple[1]

         if fstr is StringType and fstr.literal and a is FunctionType then
            local st = fstr.literal
            local items, e = parse_format_string(node, st)

            if e then
               if items then
                  -- just a warning
                  self.errs:add_warning("hint", fstr, e)
               else
                  return self.errs:invalid_at(fstr, e)
               end
            end

            table.insert(items, 1, a_type(node, "string", {}))

            if #items ~= #b.tuple then
               return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects " .. #items .. ")")
            end

            -- check the arguments now
            return (self:type_check_function_call(node, a, b, argdelta, a_tuple(node, items), nil))
         else
            return (self:type_check_function_call(node, a, b, argdelta))
         end
      end,

      ["string.match"] = function(self: TypeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
         if #b.tuple < 2 or #b.tuple > 3 then
            return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 2 or 3)")
         end

         local rets: TupleType
         local pat = b.tuple[2]

         if pat is StringType and pat.literal then
            local st = pat.literal
            local items, e = parse_pattern_string(node, st, true)

            if e then
               if items then
                  -- just a warning
                  self.errs:add_warning("hint", pat, e)
               else
                  return self.errs:invalid_at(pat, e)
               end
            end

            -- set the returns to match the response
            rets = a_tuple(node, items)
         end
         return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
      end,

      ["string.find"] = function(self: TypeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
         if #b.tuple < 2 or #b.tuple > 4 then
            return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects at least 2 and at most 4)")
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
                  self.errs:add_warning("hint", pat, e)
               else
                  return self.errs:invalid_at(pat, e)
               end
            end

            table.insert(items, 1, a_type(pat, "integer", {}))
            table.insert(items, 1, a_type(pat, "integer", {}))

            -- set the returns to match the response
            rets = a_tuple(node, items)
         end

         return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
      end,

      ["string.gmatch"] = function(self: TypeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
         if #b.tuple < 2 or #b.tuple > 3 then
            return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 2 or 3)")
         end

         local rets: TupleType
         local pat = b.tuple[2]

         if pat is StringType and pat.literal then
            local st = pat.literal
            local items, e = parse_pattern_string(node, st, true)

            if e then
               if items then
                  -- just a warning
                  self.errs:add_warning("hint", pat, e)
               else
                  return self.errs:invalid_at(pat, e)
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

      ["string.gsub"] = function(self: TypeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
         -- if the second argument is a literal, we can parse it and change the matchers
         -- gsub: function(string, string, <matcher>, ? integer): string, integer

         if #b.tuple < 3 or #b.tuple > 4 then
            return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 3 or 4)")
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
                  self.errs:add_warning("hint", pat, e)
               else
                  return self.errs:invalid_at(pat, e)
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
                  self.errs:invalid_at(trepl, "expected a table with integers as keys")
               end
               replarg_type = a_map(node, i1, expected_pat_return)
            elseif trepl is ArrayLikeType then
               if not (i1 is IntegerType) then
                  self.errs:invalid_at(trepl, "expected a table with strings as keys")
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

   function TypeChecker:type_check_funcall(node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
      if node.e1.op and node.e1.op.op == ":" then
         table.insert(b.tuple, 1, node.e1.receiver)
         argdelta = -1
      else
         argdelta = argdelta or 0
      end

      local sa = resolve_for_special_function(a)
      if sa then
         local special_tyck = special_functions[sa.special_function_handler]
         if special_tyck then
            return special_tyck(self, node, a, b, argdelta)
         end
      end

      return (self:type_check_function_call(node, a, b, argdelta))
   end

   -- is the i-th assignment in a local declaration of the form `x = x` ?
   local function is_localizing_a_variable(node: Node, i: integer): boolean
      return node.exps
         and node.exps[i]
         and node.exps[i].kind == "variable"
         and node.exps[i].tk == node.vars[i].tk
   end

   function TypeChecker:missing_initializer(node: Node, i: integer, name: string): (InvalidType | UnknownType)
      if self.feat_lax then
         return an_unknown(node)
      else
         if node.exps then
            return self.errs:invalid_at(node.vars[i], "assignment in declaration did not produce an initial value for variable '" .. name .. "'")
         else
            return self.errs:invalid_at(node.vars[i], "variable '" .. name .. "' has no type or initial value")
         end
      end
   end

   local function set_expected_types_to_decltuple(self: TypeChecker, node: Node, children: {Type})
      local decltuple = node.kind == "assignment" and children[1] or node.decltuple
      assert(decltuple is TupleType)
      local decls = decltuple.tuple
      if decls and node.exps then
         local ndecl = #decls
         local nexps = #node.exps
         for i = 1, nexps do
            local typ: Type
            typ = decls[i]
            if typ then
               if i == nexps and ndecl > nexps and node_is_funcall(node.exps[i]) then
                  typ = a_tuple(node, {})
                  for a = i, ndecl do
                     table.insert(typ.tuple, decls[a])
                  end
               end
               node.exps[i].expected = typ
               node.exps[i].expected_context = { kind = node.kind, name = node.vars[i].tk }
            end
         end
      end

      if node.decltuple then
         local ndecltuple = #node.decltuple.tuple
         local nvars = #node.vars
         if ndecltuple > nvars then
            self.errs:add(node.decltuple.tuple[nvars + 1], "number of types exceeds number of variables")
         end
      end
   end

   local function is_positive_int(n: number): boolean
      return n and n >= 1 and math.floor(n) == n
   end

   local function infer_table_literal(self: TypeChecker, node: Node, children: {LiteralTableItemType}): Type
      local is_record = false
      local is_array = false
      local is_map = false

      local is_tuple = false
      local is_not_tuple = false

      local last_array_idx = 1
      local largest_array_idx = -1

      local seen_keys: {CheckableKey:Where} = {}

      -- array, tupletable
      local typs: {Type}
      -- record
      local fields: {string:Type}
      local field_order: {string}
      -- array, record
      local elements: Type
      -- map
      local keys, values: Type, Type

      for i, child in ipairs(children) do
         local ck = child.kname
         local cktype = child.ktype
         local key: CheckableKey = ck
         local n: number
         if not key then
            n = node[i].key.constnum
            key = n
            if not key and node[i].key.kind == "boolean" then
               key = (node[i].key.tk == "true")
            end
         end

         self.errs:check_redeclared_key(node[i], nil, seen_keys, key)

         local uvtype = resolve_tuple(child.vtype)
         if ck then
            is_record = true
            if not fields then
               fields = {}
               field_order = {}
            end
            fields[ck] = uvtype
            table.insert(field_order, ck)
         elseif cktype is NumericType then
            is_array = true
            if not is_not_tuple then
               is_tuple = true
            end
            if not typs then
               typs = {}
            end

            if node[i].key_parsed == "implicit" then
               local cv = child.vtype
               if i == #children and cv is TupleType then
                  -- need to expand last item in an array (e.g { 1, 2, 3, f() })
                  for _, c in ipairs(cv.tuple) do
                     elements = self:expand_type(node, elements, c)
                     typs[last_array_idx] = resolve_tuple(c)
                     last_array_idx = last_array_idx + 1
                  end
               else
                  typs[last_array_idx] = uvtype
                  last_array_idx = last_array_idx + 1
                  elements = self:expand_type(node, elements, uvtype)
               end
            else -- explicit
               if not is_positive_int(n) then
                  elements = self:expand_type(node, elements, uvtype)
                  is_not_tuple = true
               elseif n then
                  typs[n as integer] = uvtype
                  if n > largest_array_idx then
                     largest_array_idx = n as integer
                  end
                  elements = self:expand_type(node, elements, uvtype)
               end
            end

            if last_array_idx > largest_array_idx then
               largest_array_idx = last_array_idx
            end
            if not elements then
               is_array = false
            end
         else
            is_map = true
            keys = self:expand_type(node, keys, drop_constant_value(cktype))
            values = self:expand_type(node, values, uvtype)
         end
      end

      local t: Type

      if is_array and is_map then
         self.errs:add(node, "cannot determine type of table literal")
         t = a_map(node,
            self:expand_type(node, keys, a_type(node, "integer", {})),
            self:expand_type(node, values, elements)
         )
      elseif is_record and is_array then
         t = a_type(node, "record", {
            fields = fields,
            field_order = field_order,
            elements = elements,
            interface_list = {
               an_array(node, elements)
            }
         } as RecordType)
         -- TODO adopt logic from self:is_array below when we accept tupletable as an interface
      elseif is_record and is_map then
         if keys is StringType then
            for _, fname in ipairs(field_order) do
               values = self:expand_type(node, values, fields[fname])
            end
            t = a_map(node, keys, values)
         else
            self.errs:add(node, "cannot determine type of table literal")
         end
      elseif is_array then
         local pure_array = true
         if not is_not_tuple then
            local last_t: Type
            for _, current_t in pairs(typs as {integer:Type}) do
               if last_t then
                  if not self:same_type(last_t, current_t) then
                     pure_array = false
                     break
                  end
               end
               last_t = current_t
            end
         end
         if pure_array then
            t = an_array(node, elements)
            t.consttypes = typs
            t.inferred_len = largest_array_idx - 1
         else
            t = a_type(node, "tupletable", { inferred_at = node }) as TupleTableType
            t.types = typs
         end
      elseif is_record then
         t = a_type(node, "record", {
            fields = fields,
            field_order = field_order,
         } as RecordType)
      elseif is_map then
         t = a_map(node, keys, values)
      elseif is_tuple then
         t = a_type(node, "tupletable", { inferred_at = node }) as TupleTableType
         t.types = typs
         if not typs or #typs == 0 then
            self.errs:add(node, "cannot determine type of tuple elements")
         end
      end

      if not t then
         t = a_type(node, "emptytable", {})
      end

      return type_at(node, t)
   end

   function TypeChecker:infer_negation_of_if_blocks(w: Where, ifnode: Node, n: integer)
      local f = facts_not(w, ifnode.if_blocks[1].exp.known)
      for e = 2, n do
         local b = ifnode.if_blocks[e]
         if b.exp then
            f = facts_and(w, f, facts_not(w, b.exp.known))
         end
      end
      self:apply_facts(w, f)
   end

   function TypeChecker:determine_declaration_type(var: Node, node: Node, infertypes: TupleType, i: integer): boolean, Type, boolean
      local ok = true
      local name = var.tk
      local infertype = infertypes and infertypes.tuple[i]
      if self.feat_lax and infertype and infertype is NilType then
         infertype = nil
      end

      local decltype = node.decltuple and node.decltuple.tuple[i]
      if decltype then
         local rdecltype = self:to_structural(decltype)
         if rdecltype is InvalidType then
            decltype = rdecltype
         end

         if infertype then
            local w = node.exps and node.exps[i] or node.vars[i]
            ok = self:assert_is_a(w, infertype, decltype, context_name[node.kind], name)
         end
      else
         if infertype then
            if infertype is UnresolvableTypeArgType then
               ok = false
               infertype = self.errs:invalid_at(node.vars[i], "cannot infer declaration type; an explicit type annotation is necessary")
            else
               -- If we assign a method to a variable, e.g:
               -- `local myfunc = myobj.dothing`,
               -- the variable should not be treated as a method
               infertype = ensure_not_method(infertype)
            end
         end
      end

      if var.attribute == "total" then
         local rd = decltype and self:to_structural(decltype)
         if rd and (not rd is MapType) and (not rd is RecordType) then
            self.errs:add(var, "attribute <total> only applies to maps and records")
            ok = false
         elseif not infertype then
            self.errs:add(var, "variable declared <total> does not declare an initialization value")
            ok = false
         else
            local valnode = node.exps[i]
            if not valnode or valnode.kind ~= "literal_table" then
               self.errs:add(var, "attribute <total> only applies to literal tables")
               ok = false
            else
               if not valnode.is_total then
                  local missing = ""
                  if valnode.missing then
                     missing = " (missing: " .. table.concat(valnode.missing, ", ") .. ")"
                  end
                  local ri = self:to_structural(infertype)
                  if ri is MapType then
                     self.errs:add(var, "map variable declared <total> does not declare values for all possible keys" .. missing)
                     ok = false
                  elseif ri is RecordType then
                     self.errs:add(var, "record variable declared <total> does not declare values for all fields" .. missing)
                     ok = false
                  end
               end
            end
         end
      end

      local t = decltype or infertype
      if t == nil then
         t = self:missing_initializer(node, i, name)
      elseif t is EmptyTableType then
         t.is_global = node.kind == "global_declaration"
         t.assigned_to = name
      elseif t is ArrayLikeType then
         t.inferred_len = nil
      elseif t is NominalType then
         self:resolve_nominal(t)
         local rt = t.resolved
         if rt and rt is TypeDeclType then
            t.resolved = rt.def
         end
      end

      return ok, t, infertype ~= nil
   end

   local function aliasing_variable(self: TypeChecker, def: Type): Variable
      if def is NominalType then
         return (self:find_var(def.names[1], "use_type"))
      end

      if def is GenericType then
         local nom = def.t
         if nom is NominalType then
            return (self:find_var(nom.names[1], "use_type"))
         end
      end
   end

   local function recurse_type_declaration(self: TypeChecker, n: Node): InvalidOrTypeDeclType, Variable
      if n.kind == "op" then
         -- recursive case: e1.e2
         if n.op.op == "." then
            local ty = recurse_type_declaration(self, n.e1)
            if not ty is TypeDeclType then
               return ty
            end
            local def = ty.def
            if not def is RecordType then
               return self.errs:invalid_at(n.e1, "type is not a record")
            end
            local t = def.fields[n.e2.tk]
            if t and t is TypeDeclType then
               return t
            end
            return self.errs:invalid_at(n.e2, "nested type '" .. n.e2.tk .. "' not found in record")
         -- base case: require(e2)
         elseif n.op.op == "@funcall"
            and n.e1.kind == "variable"
            and n.e1.tk == "require"
         then
            local ty = resolve_tuple(
               special_functions["require"](
                  self, n, self:find_var_type("require"),
                  a_tuple(n.e2, { a_type(n.e2[1], "string", {}) })
               )
            )
            if not ty is TypeDeclType then
               return self.errs:invalid_at(n.e1, "'require' did not return a type, got %s", ty)
            end
            if ty.is_alias then
               return self:resolve_typealias(ty)
            end
            return ty
         end
      end
      -- base case: type
      local newtype = n.newtype
      if newtype.is_alias then
         return self:resolve_typealias(newtype), aliasing_variable(self, newtype.def)
      end
      return newtype, nil
   end

   function TypeChecker:get_typedecl(value: Node): InvalidOrTypeDeclType, Variable
      local resolved, aliasing = recurse_type_declaration(self, value)
      local nt = value.newtype
      if nt and nt.is_alias and resolved is TypeDeclType then
         local ntdef = nt.def
         local rdef = resolved.def
         if ntdef is GenericType and rdef is GenericType then
            -- FIXME this looks sketchy; not sure if just overwriting the
            -- type variables in a resolved alias won't have bad side-effects.
            -- Is it guaranteed to be a fresh type?
            ntdef.typeargs = rdef.typeargs
         end
      end
      return resolved, aliasing
   end

   local function total_check_key(key: CheckableKey, seen_keys: {CheckableKey:Where}, is_total: boolean, missing: {string}): boolean, {string}
      if not seen_keys[key] then
         missing = missing or {}
         table.insert(missing, tostring(key))
         return false, missing
      end
      return is_total, missing
   end

   local function total_record_check(t: RecordLikeType, seen_keys: {CheckableKey:Where}): boolean, {string}
      local is_total = true
      local missing: {string}
      for _, key in ipairs(t.field_order) do
         local ftype = t.fields[key]
         if not (ftype is TypeDeclType or (ftype is FunctionType and ftype.is_record_function)) then
            is_total, missing = total_check_key(key, seen_keys, is_total, missing)
         end
      end
      return is_total, missing
   end

   local function total_map_check(keys: Type, seen_keys: {CheckableKey:Where}): boolean, {string}
      local is_total = true
      local missing: {string}
      if keys is EnumType then
         for _, key in ipairs(sorted_keys(keys.enumset)) do
            is_total, missing = total_check_key(key, seen_keys, is_total, missing)
         end
      elseif keys is BooleanType then
         for _, key in ipairs({ true, false }) do
            is_total, missing = total_check_key(key, seen_keys, is_total, missing)
         end
      else
         is_total = false
      end
      return is_total, missing
   end

   local enum MissingError
      "missing"
   end

   function TypeChecker:check_assignment(varnode: Node, vartype: Type, valtype: Type): Type, Type, MissingError
      local varname = varnode.tk
      local attr = varnode.attribute

      if varname then
         if self:widen_back_var(varname) then
            vartype, attr = self:find_var_type(varname)
            if not vartype then
               self.errs:add(varnode, "unknown variable")
               return nil
            end
         end
      end
      if attr == "close" or attr == "const" or attr == "total" then
         self.errs:add(varnode, "cannot assign to <" .. attr .. "> variable")
         return nil
      end

      local var = self:to_structural(vartype)
      if var is TypeDeclType then
         self.errs:add(varnode, "cannot reassign a type")
         return nil
      end

      if not valtype then
         self.errs:add(varnode, "variable is not being assigned a value")
         return nil, nil, "missing"
      end

      self:assert_is_a(varnode, valtype, vartype, "in assignment")

      local val = self:to_structural(valtype)

      return var, val
   end

   local function discard_tuple(node: Node, t: Type, b: Type): Type
      if b is TupleType then
         node.discarded_tuple = true
      end
      return resolve_tuple(t)
   end

   local visit_node: Visitor<TypeChecker, NodeKind, Node, Type> = {}

   visit_node.cbs = {
      ["statements"] = {
         before = function(self: TypeChecker, node: Node)
            self:begin_scope(node)
         end,
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            -- if at the top level
            if #self.st == 2 then
               self.errs:fail_unresolved_labels(self.st[2])
               self.errs:fail_unresolved_nominals(self.st[2], self.st[1])
            end

            if not node.is_repeat then
               self:end_scope(node)
            end

            return NONE
         end
      },
      ["local_type"] = {
         before = function(self: TypeChecker, node: Node)
            local name = node.var.tk
            local resolved, aliasing = self:get_typedecl(node.value)
            local var = self:add_var(node.var, name, resolved, node.var.attribute)
            if aliasing then
               var.aliasing = aliasing
            end
         end,
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            self:dismiss_unresolved(node.var.tk)
            return NONE
         end,
      },
      ["global_type"] = {
         before = function(self: TypeChecker, node: Node)
            local global_scope = self.st[1]
            local name = node.var.tk
            if node.value then
               local resolved, aliasing = self:get_typedecl(node.value)
               local added = self:add_global(node.var, name, resolved)
               if resolved is InvalidType then
                  return
               end
               node.value.newtype = resolved
               if aliasing then
                  added.aliasing = aliasing
               end

               if global_scope.pending_global_types[name] then
                  global_scope.pending_global_types[name] = nil
               end
            else
               if not self.st[1].vars[name] then
                  global_scope.pending_global_types[name] = true
               end
            end
         end,
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            self:dismiss_unresolved(node.var.tk)
            return NONE
         end,
      },
      ["local_declaration"] = {
         before = function(self: TypeChecker, node: Node)
            if self.collector then
               for _, var in ipairs(node.vars) do
                  self.collector.reserve_symbol_list_slot(var)
               end
            end
         end,
         before_exp = set_expected_types_to_decltuple,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local valtuple = children[3] as TupleType -- may be nil

            local encountered_close = false
            local infertypes = get_assignment_values(node, valtuple, #node.vars)
            for i, var in ipairs(node.vars) do
               if var.attribute == "close" then
                  if self.gen_target == "5.4" then
                     if encountered_close then
                        self.errs:add(var, "only one <close> per declaration is allowed")
                     else
                        encountered_close = true
                     end
                  else
                     self.errs:add(var, "<close> attribute is only valid for Lua 5.4 (current target is " .. tostring(self.gen_target) .. ")")
                  end
               end

               local ok, t = self:determine_declaration_type(var, node, infertypes, i)

               if var.attribute == "close" then
                  if not type_is_closable(t) then
                     self.errs:add(var, "to-be-closed variable " .. var.tk .. " has a non-closable type %s", t)
                  elseif node.exps and node.exps[i] and expr_is_definitely_not_closable(node.exps[i]) then
                     self.errs:add(var, "to-be-closed variable " .. var.tk .. " assigned a non-closable value")
                  end
               end

               assert(var)
               self:add_var(var, var.tk, t, var.attribute, is_localizing_a_variable(node, i) and "localizing")
               if var.elide_type then
                  self.errs:add_warning("hint", node, "hint: consider using 'local type' instead")
               end

               local infertype = infertypes.tuple[i]
               if ok and infertype then
                  local w = node.exps[i] or node.exps

                  local rt = self:to_structural(t)
                  if (not rt is EnumType)
                     and ((not t is NominalType) or (rt is UnionType))
                     and not self:same_type(t, infertype)
                  then
                     t = self:infer_at(w, infertype)
                     self:add_var(w, var.tk, t, "const", "narrowed_declaration")
                  end
               end

               if self.collector then
                  self.collector.store_type(var.y, var.x, t)
               end

               self:dismiss_unresolved(var.tk)
            end
            return NONE
         end,
      },
      ["global_declaration"] = {
         before_exp = set_expected_types_to_decltuple,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local valtuple = children[3] as TupleType -- may be nil

            local infertypes = get_assignment_values(node, valtuple, #node.vars)
            for i, var in ipairs(node.vars) do
               local _, t, is_inferred = self:determine_declaration_type(var, node, infertypes, i)

               if var.attribute == "close" then
                  self.errs:add(var, "globals may not be <close>")
               end

               self:add_global(var, var.tk, t, is_inferred)
               if var.elide_type then
                  self.errs:add_warning("hint", node, "hint: consider using 'global type' instead")
               end

               self:dismiss_unresolved(var.tk)
            end
            return NONE
         end,
      },
      ["assignment"] = {
         before_exp = set_expected_types_to_decltuple,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local vartuple = children[1]
            assert(vartuple is TupleType)
            local vartypes = vartuple.tuple
            local valtuple = children[3]
            assert(valtuple is TupleType)
            local valtypes = get_assignment_values(node, valtuple, #vartypes)
            for i, vartype in ipairs(vartypes) do
               local varnode = node.vars[i]
               local varname = varnode.tk
               local valtype = valtypes.tuple[i]
               local rvar, rval, err = self:check_assignment(varnode, vartype, valtype)
               if err == "missing" then
                  if #node.exps == 1 and node_is_funcall(node.exps[1]) then
                     local msg = #valtuple.tuple == 1
                                 and "only 1 value is returned by the function"
                                 or ("only " .. #valtuple.tuple .. " values are returned by the function")
                     self.errs:add_warning("hint", varnode, msg)
                  end
               end

               if rval and rvar then
                  -- assigning a function
                  if rval is FunctionType then
                     self:widen_all_unions()
                  end

                  if varname and (rvar is UnionType or rvar is InterfaceType) then
                     -- narrow unions and interfaces
                     self:add_var(varnode, varname, valtype, nil, "narrow")
                  end

                  if self.collector then
                     self.collector.store_type(varnode.y, varnode.x, valtype)
                  end
               end
            end

            return NONE
         end,
      },
      ["if"] = {
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            if node.if_widens then
               -- TODO we could collect the types from each if_block
               -- and narrow the type to their union
               self:widen_all(node.if_widens, {})
            end

            local all_return = true
            for _, b in ipairs(node.if_blocks) do
               if not b.block_returns then
                  all_return = false
                  break
               end
            end
            if all_return then
               node.block_returns = true
               self:infer_negation_of_if_blocks(node, node, #node.if_blocks)
            end

            return NONE
         end,
      },
      ["if_block"] = {
         before = function(self: TypeChecker, node: Node)
            self:begin_scope(node)
            if node.if_block_n > 1 then
               self:infer_negation_of_if_blocks(node, node.if_parent, node.if_block_n - 1)
            end
            if node.exp then
               node.exp.expected = a_type(node, "boolean_context", {})
            end
         end,
         before_statements = function(self: TypeChecker, node: Node)
            if node.exp then
               self:apply_facts(node.exp, node.exp.known)
            end
         end,
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            node.if_parent.if_widens = self:collect_if_widens(node.if_parent.if_widens)

            self:end_scope(node)

            if #node.body > 0 and node.body[#node.body].block_returns then
               node.block_returns = true
            end

            return NONE
         end
      },
      ["while"] = {
         before = function(self: TypeChecker, node: Node)
            -- widen all narrowed variables because we don't calculate a fixpoint yet
            self:widen_all_unions(node)
            node.exp.expected = a_type(node, "boolean_context", {})
         end,
         before_statements = function(self: TypeChecker, node: Node)
            self:begin_scope(node)
            self:apply_facts(node.exp, node.exp.known)
         end,
         after = end_scope_and_none_type,
      },
      ["label"] = {
         before = function(self: TypeChecker, node: Node)
            -- widen all narrowed variables because we don't calculate a fixpoint yet
            self:widen_all_unions()
            local label_id = node.label
            do
               local scope = self.st[#self.st]
               scope.labels = scope.labels or {}
               if scope.labels[label_id] then
                  self.errs:add(node, "label '" .. node.label .. "' already defined")
               else
                  scope.labels[label_id] = node
               end
            end

            --for i = #self.st, 1, -1 do
               local scope = self.st[#self.st]
               if scope.pending_labels and scope.pending_labels[label_id] then
                  node.used_label = true
                  scope.pending_labels[label_id] = nil
                  --break
               end
            --end
         end,
         after = function(): Type
            return NONE
         end
      },
      ["goto"] = {
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            local label_id = node.label
            local found_label: Node
            for i = #self.st, 1, -1 do
               local scope = self.st[i]
               if scope.labels and scope.labels[label_id] then
                  found_label = scope.labels[label_id]
                  break
               end
            end

            if found_label then
               found_label.used_label = true
            else
               local scope = self.st[#self.st]
               scope.pending_labels = scope.pending_labels or {}
               scope.pending_labels[label_id] = scope.pending_labels[label_id] or {}
               table.insert(scope.pending_labels[label_id], node)
            end

            return NONE
         end,
      },
      ["repeat"] = {
         before = function(self: TypeChecker, node: Node)
            -- widen all narrowed variables because we don't calculate a fixpoint yet
            self:widen_all_unions(node)
            node.exp.expected = a_type(node, "boolean_context", {})
         end,
         -- only end scope after checking `until`, `statements` in repeat body has is_repeat == true
         after = end_scope_and_none_type,
      },
      ["forin"] = {
         before = function(self: TypeChecker, node: Node)
            self:begin_scope(node)
         end,
         before_statements = function(self: TypeChecker, node: Node, children: {Type})
            local exptuple = children[2]
            assert(exptuple is TupleType)
            local exptypes = exptuple.tuple

            local exp1 = node.exps[1]
            if #exptypes < 1 then
               self.errs:invalid_at(exp1, "expression in 'for' statement does not return any values")
               return
            end

            self:widen_all_unions(node)

            local args = a_tuple(node.exps, {
               node.exps[2] and exptypes[2],
               node.exps[3] and exptypes[3]
            })
            local exp1type = self:resolve_for_call(exptypes[1], args, false)

            if exp1type is PolyType then
               local _r, f: Type, Type
               _r, f = self:type_check_function_call(exp1, exp1type, args, 0, nil, nil, exp1, {node.exps[2], node.exps[3]})
               if f then
                  exp1type = f
               else
                  self.errs:add(exp1, "cannot resolve polymorphic function given arguments")
               end
            end

            if exp1type is FunctionType then
               -- TODO: check that exp1's arguments match with (optional self, explicit iterator, state)
               local last: Type
               local rets = exp1type.rets
               for i, v in ipairs(node.vars) do
                  local r = rets.tuple[i]
                  if not r then
                     if rets.is_va then
                        r = last
                     else
                        r = self.feat_lax and an_unknown(v) or an_invalid(v)
                     end
                  end
                  self:add_var(v, v.tk, r)

                  if self.collector then
                     self.collector.store_type(v.y, v.x, r)
                  end

                  last = r
               end
               local nrets = #rets.tuple
               if (not self.feat_lax) and (not rets.is_va and #node.vars > nrets) then
                  local at = node.vars[nrets + 1]
                  local n_values = nrets == 1 and "1 value" or tostring(nrets) .. " values"
                  self.errs:add(at, "too many variables for this iterator; it produces " .. n_values)
               end
            else
               if not (self.feat_lax and is_unknown(exp1type)) then
                  self.errs:add(exp1, "expression in for loop does not return an iterator")
               end
            end
         end,
         after = end_scope_and_none_type,
      },
      ["fornum"] = {
         before_statements = function(self: TypeChecker, node: Node, children: {Type})
            self:widen_all_unions(node)
            self:begin_scope(node)
            local from_t = self:to_structural(resolve_tuple(children[2]))
            local to_t = self:to_structural(resolve_tuple(children[3]))
            local step_t = children[4] and self:to_structural(children[4])
            local typename: TypeName = (from_t is IntegerType and
                                        to_t is IntegerType and
                                        (not step_t or step_t is IntegerType))
                                       and "integer"
                                       or  "number"
            self:add_var(node.var, node.var.tk, a_type(node.var, typename, {}))
         end,
         after = end_scope_and_none_type,
      },
      ["return"] = {
         before = function(self: TypeChecker, node: Node)
            local rets = self:find_var_type("@return")
            if rets and rets is TupleType then
               for i, exp in ipairs(node.exps) do
                  exp.expected = rets.tuple[i]
               end
            end
         end,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local got = children[1]
            assert(got is TupleType)
            local got_t = got.tuple
            local n_got = #got_t

            node.block_returns = true
            local expected = self:find_var_type("@return") as TupleType
            if not expected then
               -- if at the toplevel
               local module_type = resolve_tuple(got)
               if module_type is NominalType then
                  self:resolve_nominal(module_type)
                  self.module_type = module_type.resolved
               else
                  self.module_type = drop_constant_value(module_type)
               end

               expected = self:infer_at(node, got)
               self.st[2].vars["@return"] = { t = expected }
            end
            local expected_t = expected.tuple

            local what = "in return value"
            if expected.inferred_at then
               what = what .. types.inferred_msg(expected)
            end

            local n_expected = #expected_t
            local vatype: Type
            if n_expected > 0 then
               vatype = expected.is_va and expected.tuple[n_expected]
            end

            if n_got > n_expected and (not self.feat_lax) and not vatype then
               self.errs:add(node, what ..": excess return values, expected " .. n_expected .. " %s, got " .. n_got .. " %s", expected, got)
            end

            if n_expected > 1
            and #node.exps == 1
            and node.exps[1].kind == "op"
            and (node.exps[1].op.op == "and" or node.exps[1].op.op == "or")
            and node.exps[1].discarded_tuple then
               self.errs:add_warning("hint", node.exps[1].e2, "additional return values are being discarded due to '" .. node.exps[1].op.op .. "' expression; suggest parentheses if intentional")
            end

            for i = 1, n_got do
               local e = expected_t[i] or vatype
               if e then
                  e = resolve_tuple(e)
                  local w = (node.exps[i] and node.exps[i].x)
                            and node.exps[i]
                            or  node.exps
                  assert(w and w.x)
                  self:assert_is_a(w, got_t[i], e, what)
               end
            end

            return NONE
         end,
      },
      ["variable_list"] = {
         after = function(self: TypeChecker, node: Node, children: {FirstClassType | TupleType}): Type
            local tuple = flat_tuple(node, children)

            for i, t in ipairs(tuple.tuple) do
               local ok, err = ensure_not_abstract(t, node[i])
               if not ok then
                  self.errs:add(node[i], err)
               end
            end

            return tuple
         end,
      },
      ["literal_table"] = {
         before = function(self: TypeChecker, node: Node)
            if node.expected then
               local decltype = self:to_structural(node.expected)

               if decltype is TypeVarType and decltype.constraint then
                  decltype = resolve_typedecl(self:to_structural(decltype.constraint))
               end

               if decltype is GenericType then
                  decltype = self:apply_generic(node, decltype)
               end

               if decltype is TupleTableType then
                  for _, child in ipairs(node) do
                     local n = child.key.constnum
                     if n and is_positive_int(n) then
                        child.value.expected = decltype.types[n as integer]
                     end
                  end
               elseif decltype is ArrayLikeType then
                  for _, child in ipairs(node) do
                     if child.key.constnum then
                        child.value.expected = decltype.elements
                     end
                  end
               elseif decltype is MapType then
                  for _, child in ipairs(node) do
                     child.key.expected = decltype.keys
                     child.value.expected = decltype.values
                  end
               end

               if decltype is RecordLikeType then
                  for _, child in ipairs(node) do
                     if child.key.conststr then
                        child.value.expected = decltype.fields[child.key.conststr]
                     end
                  end
               end
            end
         end,
         after = function(self: TypeChecker, node: Node, children: {LiteralTableItemType}): Type
            node.known = FACT_TRUTHY

            if not node.expected then
               return infer_table_literal(self, node, children)
            end

            local decltype = self:to_structural(node.expected)

            local constraint: Type
            if decltype is TypeVarType and decltype.constraint then
               constraint = resolve_typedecl(decltype.constraint)
               decltype = self:to_structural(constraint)
            end

            if decltype is GenericType then
               decltype = self:apply_generic(node, decltype)
            end

            if decltype is UnionType then
               local single_table_type: Type
               local single_table_rt: Type

               for _, t in ipairs(decltype.types) do
                  local rt = self:to_structural(t)
                  if is_lua_table_type(rt) then
                     if single_table_type then
                        -- multiple table types in union, give up
                        single_table_type = nil
                        single_table_rt = nil
                        break
                     end

                     single_table_type = t
                     single_table_rt = rt
                  end
               end

               if single_table_type then
                  node.expected = single_table_type
                  decltype = single_table_rt
               end
            end

            if not is_lua_table_type(decltype) then
               return infer_table_literal(self, node, children)
            end

            if decltype is RecordLikeType then
               self:begin_scope()
               self:add_var(nil, "@self", a_typedecl(node, decltype))
               decltype = self:resolve_self(decltype, true)
               self:end_scope()
            end

            local force_array: Type = nil

            local seen_keys: {CheckableKey:Where} = {}

            for i, child in ipairs(children) do
               local cvtype = resolve_tuple(child.vtype)
               local ck = child.kname
               local cktype = child.ktype
               local n = node[i].key.constnum
               local b: boolean = nil
               if cktype is BooleanType then
                  b = (node[i].key.tk == "true")
               end
               self.errs:check_redeclared_key(node[i], node, seen_keys, ck or n or b)
               if decltype is RecordLikeType and ck then
                  local df = decltype.fields[ck]
                  if not df then
                     self.errs:add_in_context(node[i], node, "unknown field " .. ck)
                  else
                     if df is TypeDeclType then
                        self.errs:add_in_context(node[i], node, "cannot reassign a type")
                     else
                        self:assert_is_a(node[i], cvtype, df, "in record field", ck)
                     end
                  end
               elseif decltype is TupleTableType and cktype is NumericType then
                  local dt = decltype.types[n as integer]
                  if not n then
                     self.errs:add_in_context(node[i], node, "unknown index in tuple %s", decltype)
                  elseif not dt then
                     self.errs:add_in_context(node[i], node, "unexpected index " .. n .. " in tuple %s", decltype)
                  else
                     self:assert_is_a(node[i], cvtype, dt, node, "in tuple: at index " .. tostring(n))
                  end
               elseif decltype is ArrayLikeType and cktype is NumericType then
                  local cv = child.vtype
                  if cv is TupleType and i == #children and node[i].key_parsed == "implicit" then
                     -- need to expand last item in an array (e.g { 1, 2, 3, f() })
                     for ti, tt in ipairs(cv.tuple) do
                        self:assert_is_a(node[i], tt, decltype.elements, node, "expected an array: at index " .. tostring(i + ti - 1))
                     end
                  else
                     self:assert_is_a(node[i], cvtype, decltype.elements, node, "expected an array: at index " .. tostring(n))
                  end
               elseif node[i].key_parsed == "implicit" then
                  if decltype is MapType then
                     self:assert_is_a(node[i].key, a_type(node[i].key, "integer", {}), decltype.keys, node, "in map key")
                     self:assert_is_a(node[i].value, cvtype, decltype.values, node, "in map value")
                  end
                  force_array = self:expand_type(node[i], force_array, child.vtype)
               elseif decltype is MapType then
                  force_array = nil
                  self:assert_is_a(node[i].key, cktype, decltype.keys, node, "in map key")
                  self:assert_is_a(node[i].value, cvtype, decltype.values, node, "in map value")
               else
                  self.errs:add_in_context(node[i], node, "unexpected key of type %s in table of type %s", cktype, decltype)
               end
            end

            local t = force_array and an_array(node, force_array) or node.expected
            t = self:infer_at(node, t)

            if decltype is RecordType then
               local rt = self:to_structural(t)
               if rt is RecordType then
                  node.is_total, node.missing = total_record_check(decltype, seen_keys)
               end
            elseif decltype is MapType then
               local rt = self:to_structural(t)
               if rt is MapType then
                  local rk = self:to_structural(rt.keys)
                  node.is_total, node.missing = total_map_check(rk, seen_keys)
               end
            end

            if constraint then
               return constraint
            end

            return t
         end,
      },
      ["literal_table_item"] = {
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local kname = node.key.conststr
            local ktype = children[1]
            local vtype = children[2]
            if node.itemtype then
               vtype = node.itemtype
               self:assert_is_a(node.value, children[2], node.itemtype, node)
            end
            -- If we assign a method to a table item, e.g.
            -- `local a = { myfunc = myobj.dothing }`
            -- the table item should not be treated as a method
            vtype = ensure_not_method(vtype)
            return a_type(node, "literal_table_item", {
               kname = kname,
               ktype = ktype,
               vtype = vtype,
            } as LiteralTableItemType)
         end,
      },
      ["local_function"] = {
         before = function(self: TypeChecker, node: Node)
            self:widen_all_unions()
            if self.collector then
               self.collector.reserve_symbol_list_slot(node)
            end
            self:begin_scope(node)
         end,
         before_statements = function(self: TypeChecker, node: Node, children: {Type})
            local args = children[2]
            assert(args is TupleType)

            self:add_internal_function_variables(node, args)
            self:add_function_definition_for_recursion(node, args, self.feat_arity)
         end,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local args = children[2]
            assert(args is TupleType)
            local rets = children[3]
            assert(rets is TupleType)

            self:end_function_scope(node)

            local t = wrap_generic_if_typeargs(node.typeargs, a_function(node, {
               min_arity = self.feat_arity and node.min_arity or 0,
               args = args,
               rets = self.get_rets(rets),
            }))

            self:add_var(node, node.name.tk, t)
            return t
         end,
      },
      ["local_macroexp"] = {
         before = function(self: TypeChecker, node: Node)
            self:widen_all_unions()
            if self.collector then
               self.collector.reserve_symbol_list_slot(node)
            end
            self:begin_scope(node)
         end,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local args = children[2]
            assert(args is TupleType)
            local rets = children[3]
            assert(rets is TupleType)

            self:end_function_scope(node)

            self:check_macroexp_arg_use(node.macrodef)

            local t = wrap_generic_if_typeargs(node.typeargs, a_function(node, {
               min_arity = self.feat_arity and node.macrodef.min_arity or 0,
               args = args,
               rets = self.get_rets(rets),
               macroexp = node.macrodef,
            }))

            self:add_var(node, node.name.tk, t)
            return t
         end,
      },
      ["global_function"] = {
         before = function(self: TypeChecker, node: Node)
            self:widen_all_unions()
            self:begin_scope(node)
            if node.implicit_global_function then
               local typ = self:find_var_type(node.name.tk)
               if typ then
                  if typ is FunctionType then
                     node.is_predeclared_local_function = true
                  elseif not self.feat_lax then
                     self.errs:add(node, "cannot declare function: type of " .. node.name.tk .. " is %s", typ)
                  end
               elseif not self.feat_lax then
                  self.errs:add(node, "functions need an explicit 'local' or 'global' annotation")
               end
            end
         end,
         before_statements = function(self: TypeChecker, node: Node, children: {Type})
            local args = children[2]
            assert(args is TupleType)

            self:add_internal_function_variables(node, args)
            self:add_function_definition_for_recursion(node, args, self.feat_arity)
         end,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local args = children[2]
            assert(args is TupleType)
            local rets = children[3]
            assert(rets is TupleType)

            self:end_function_scope(node)
            if node.is_predeclared_local_function then
               return NONE
            end

            self:add_global(node, node.name.tk, wrap_generic_if_typeargs(node.typeargs, a_function(node, {
               min_arity = self.feat_arity and node.min_arity or 0,
               args = args,
               rets = self.get_rets(rets),
            })))

            return NONE
         end,
      },
      ["record_function"] = {
         before = function(self: TypeChecker, node: Node)
            self:widen_all_unions()
            self:begin_scope(node)
         end,
         before_arguments = function(self: TypeChecker, _node: Node, children: {Type})
            local rtype = self:to_structural(resolve_typedecl(children[1]))

            -- add type arguments from the record implicitly
            if rtype is GenericType then
               for _, typ in ipairs(rtype.typeargs) do
                  self:add_var(nil, typ.typearg, a_type(typ, "typearg", {
                     typearg = typ.typearg,
                     constraint = typ.constraint,
                  } as TypeArgType))
               end
            end
         end,
         before_statements = function(self: TypeChecker, node: Node, children: {Type})
            local args = children[3]
            assert(args is TupleType)
            local rets = children[4]
            assert(rets is TupleType)

            local t = children[1]
            local rtype = self:to_structural(resolve_typedecl(t))

            if rtype is GenericType then
               rtype = rtype.t
            end

            do
               local ok, err = ensure_not_abstract(t)
               if not ok then
                  self.errs:add(node, err)
               end
            end

            if self.feat_lax and rtype is UnknownType then
               return
            end

            if rtype is EmptyTableType then
               edit_type(rtype, rtype, "record")
               local r = rtype as RecordType
               r.fields = {}
               r.field_order = {}
            end

            if not rtype is RecordLikeType then
               self.errs:add(node, "not a record: %s", rtype)
               return
            end

            local selftype = self:get_self_type(node.fn_owner)
            if node.is_method then
               if not selftype then
                  self.errs:add(node, "could not resolve type of self")
                  return
               end
               args.tuple[1] = a_self(node, selftype)
               self:add_var(nil, "self", selftype)
               self:add_var(nil, "@self", a_typedecl(node, selftype))
               if self.collector then
                  self.collector.add_to_symbol_list(node.fn_owner, "self", selftype)
               end
            end

            local fn_type = wrap_generic_if_typeargs(node.typeargs, a_function(node, {
               min_arity = self.feat_arity and node.min_arity or 0,
               is_method = node.is_method,
               args = args,
               rets = self.get_rets(rets),
               is_record_function = true,
            }))

            local open_t, open_v, owner_name = self:find_record_to_extend(node.fn_owner)
            local open_k = owner_name .. "." .. node.name.tk
            local rfieldtype = rtype.fields[node.name.tk]
            if rfieldtype then
               rfieldtype = self:to_structural(rfieldtype)

               if open_v and open_v.implemented and open_v.implemented[open_k] then
                  self.errs:redeclaration_warning(node, node.name.tk, "function")
               end

               if fn_type is GenericType and not rfieldtype is GenericType then
                  self:begin_scope()
                  fn_type = self:apply_generic(node, fn_type) as FunctionType
                  self:end_scope()
               end

               local ok, err = self:same_type(fn_type, rfieldtype)
               if not ok then
                  if rfieldtype is PolyType then
                     self.errs:add_prefixing(node, err, "type signature does not match declaration: field has multiple function definitions (such polymorphic declarations are intended for Lua module interoperability): ")
                     return
                  end

                  local shortname = selftype and show_type(selftype) or owner_name
                  local msg = "type signature of '" .. node.name.tk .. "' does not match its declaration in " .. shortname .. ": "
                  self.errs:add_prefixing(node, err, msg)
                  return
               end
            else
               if open_t and open_t is GenericType then
                  open_t = open_t.t
               end
               if self.feat_lax or rtype == open_t then
                  -- TODO is this needed?
                  -- if fn_type is GenericType then
                  --    fn_type = fresh_typeargs(self, fn_type)
                  -- end

                  rtype.fields[node.name.tk] = fn_type
                  table.insert(rtype.field_order, node.name.tk)

                  if self.collector then
                     self.env.reporter:add_field(rtype, node.name.tk, fn_type)
                  end
               else
                  self.errs:add(node, "cannot add undeclared function '" .. node.name.tk .. "' outside of the scope where '" .. owner_name .. "' was originally declared")
                  return
               end

            end

            if open_v then
               if not open_v.implemented then
                  open_v.implemented = {}
               end
               open_v.implemented[open_k] = true
            end

            self:add_internal_function_variables(node, args)
         end,
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            self:end_function_scope(node)
            return NONE
         end,
      },
      ["function"] = {
         before = function(self: TypeChecker, node: Node)
            self:widen_all_unions(node)
            self:begin_scope(node)

            local expected = node.expected
            if expected and expected is FunctionType then
               for i, t in ipairs(expected.args.tuple) do
                  if node.args[i] then
                     node.args[i].expected = t
                  end
               end
            end
         end,
         before_statements = function(self: TypeChecker, node: Node, children: {Type})
            local args = children[1]
            assert(args is TupleType)

            self:add_internal_function_variables(node, args)
         end,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local args = children[1]
            assert(args is TupleType)
            local rets = children[2]
            assert(rets is TupleType)

            self:end_function_scope(node)

            return wrap_generic_if_typeargs(node.typeargs, a_function(node, {
               min_arity = self.feat_arity and node.min_arity or 0,
               args = args,
               rets = self.get_rets(rets),
            }))
         end,
      },
      ["macroexp"] = {
         before = function(self: TypeChecker, node: Node)
            self:widen_all_unions(node)
            self:begin_scope(node)
         end,
         before_exp = function(self: TypeChecker, node: Node, children: {Type})
            local args = children[1]
            assert(args is TupleType)

            self:add_internal_function_variables(node, args)
         end,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local args = children[1]
            assert(args is TupleType)
            local rets = children[2]
            assert(rets is TupleType)

            self:end_function_scope(node)
            return wrap_generic_if_typeargs(node.typeargs, a_function(node, {
               min_arity = self.feat_arity and node.min_arity or 0,
               args = args,
               rets = rets,
            }))
         end,
      },
      ["cast"] = {
         after = function(_self: TypeChecker, node: Node, _children: {Type}): Type
            return node.casttype
         end
      },
      ["paren"] = {
         before = function(_self: TypeChecker, node: Node)
            node.e1.expected = node.expected
         end,
         after = function(_self: TypeChecker, node: Node, children: {Type}): Type
            node.known = node.e1 and node.e1.known
            return resolve_tuple(children[1])
         end,
      },
      ["op"] = {
         before = function(self: TypeChecker, node: Node)
            self:begin_scope()
            if node.expected then
               if node.op.op == "and" then
                  node.e2.expected = node.expected
               elseif node.op.op == "or" then
                  node.e1.expected = node.expected
                  if not (node.e2.kind == "literal_table" and #node.e2 == 0) then
                     node.e2.expected = node.expected
                  end
               end
            end
            if node.op.op == "not" then
               node.e1.expected = a_type(node, "boolean_context", {})
            end
         end,
         before_e2 = function(self: TypeChecker, node: Node, children: {Type})
            local e1type = children[1]

            if node.op.op == "and" then
               self:apply_facts(node, node.e1.known)
            elseif node.op.op == "or" then
               self:apply_facts(node, facts_not(node, node.e1.known))

               -- special-case `v is T and v or _` when T is a truthy type
               if node.e1.kind == "op" and node.e1.op.op == "and"
                  and node.e1.e1.kind == "op" and node.e1.e1.op.op == "is"
                  and node.e1.e2.kind == "variable"
                  and node.e1.e2.tk == node.e1.e1.e1.tk
                  and node.e1.e1.e2.casttype.typename ~= "boolean"
                  and node.e1.e1.e2.casttype.typename ~= "nil"
               then
                  self:apply_facts(node, facts_not(node, IsFact { var = node.e1.e1.e1.tk, typ = node.e1.e1.e2.casttype, w = node }))
               end

            elseif node.op.op == "@funcall" then
               if e1type is GenericType then
                  e1type = self:apply_generic(node, e1type)
               end
               if e1type is FunctionType then
                  local argdelta = (node.e1.op and node.e1.op.op == ":") and -1 or 0
                  if node.expected then
                     -- this forces typevars in function return types
                     self:is_a(e1type.rets, node.expected)
                  end
                  local e1args = e1type.args.tuple
                  local at = argdelta
                  for _, typ in ipairs(e1args) do
                     at = at + 1
                     if node.e2[at] then
                        node.e2[at].expected = self:infer_at(node.e2[at], typ)
                     end
                  end
                  if e1type.args.is_va then
                     local typ = e1args[#e1args]
                     for i = at + 1, #node.e2 do
                        node.e2[i].expected = self:infer_at(node.e2[i], typ)
                     end
                  end
               end
            elseif node.op.op == "@index" then
               if e1type is MapType then
                  node.e2.expected = e1type.keys
               end
            end
         end,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            self:end_scope()

            -- given a and b: may be TupleType
            local ga: Type = children[1]
            local gb: Type = children[3]

            -- unary a and b: not TupleType
            local ua = resolve_tuple(ga)
            local ub: Type

            -- resolved a and b: not NominalType
            local ra: Type = self:to_structural(ua)
            local rb: Type

            if ra.typename == "circular_require" or (ra is TypeDeclType and ra.def and ra.def.typename == "circular_require") then
               return self.errs:invalid_at(node, "cannot dereference a type from a circular require")
            end

            if node.op.op == "@funcall" then
               if self.feat_lax and is_unknown(ua) then
                  if node.e1.op and node.e1.op.op == ":" and node.e1.e1.kind == "variable" then
                     self.errs:add_unknown_dot(node, node.e1.e1.tk .. "." .. node.e1.e2.tk)
                  end
               end
               assert(gb is TupleType)
               local t = self:type_check_funcall(node, ua, gb)
               return t

            elseif node.op.op == "as" then
               local ok, err = ensure_not_abstract(ra)
               if not ok then
                  return self.errs:invalid_at(node.e1, err)
               end
               return gb

            elseif node.op.op == "is" and ra is TypeDeclType then
               return self.errs:invalid_at(node, "can only use 'is' on variables, not types")
            end

            local ok, err = ensure_not_abstract(ra)
            if not ok then
               return self.errs:invalid_at(node.e1, err)
            end
            if ra is TypeDeclType and ra.def.typename == "record" then
               ra = ra.def
            end

            -- "@funcall" and "as" are the only operators that use tuples, and always in the b position;
            -- after they are handled above, we can resolve b's tuple and only use that instead.
            if gb then
               ub = resolve_tuple(gb)
               rb = self:to_structural(ub)
               ok, err = ensure_not_abstract(rb)
               if not ok then
                  return self.errs:invalid_at(node.e2, err)
               end
               if rb is TypeDeclType and rb.def.typename == "record" then
                  rb = rb.def
               end
            end

            if node.op.op == "." then
               node.receiver = ua

               assert(node.e2.kind == "identifier")
               local bnode: Node = node_at(node.e2, {
                  tk = node.e2.tk,
                  kind = "string",
               })
               local btype = a_type(node.e2, "string", { literal = node.e2.tk } as StringType)
               local t = self:type_check_index(node.e1, bnode, ua, btype)

               if t.needs_compat and self.gen_compat ~= "off" then
                  -- only apply to a literal use, not a propagated type
                  if node.e1.kind == "variable" and node.e2.kind == "identifier" then
                     local key = node.e1.tk .. "." .. node.e2.tk
                     node.kind = "variable"
                     node.tk = "_tl_" .. node.e1.tk .. "_" .. node.e2.tk
                     self.all_needs_compat[key] = true
                  end
               end

               return t
            end

            if node.op.op == "@index" then
               return self:type_check_index(node.e1, node.e2, ua, ub)
            end

            if node.op.op == "is" then
               local add_type = false
               if rb is IntegerType then
                  self.all_needs_compat["math"] = true
               elseif not rb is NilType then
                  add_type = true
               end
               if ra is TypeDeclType then
                  self.errs:add(node, "can only use 'is' on variables, not types")
               elseif node.e1.kind == "variable" then
                  local has_meta: boolean
                  if rb is UnionType then
                     has_meta = convert_is_of_union_to_or_of_is(self, node, ra, rb)
                  else
                     local _, meta = self:check_metamethod(node, "__is", ra, resolve_typedecl(rb), ua, ub)
                     node.known = IsFact { var = node.e1.tk, typ = ub, w = node }
                     has_meta = not not meta
                  end
                  if has_meta then
                     add_type = false
                  end
               else
                  self.errs:add(node, "can only use 'is' on variables")
               end
               if add_type then
                  self.all_needs_compat["type"] = true
               end
               return a_type(node, "boolean", {})
            end

            if node.op.op == ":" then
               node.receiver = ua

               -- we handle ':' separately from '.' because ':' is specific to records,
               -- so we produce different error messages
               if self.feat_lax and (is_unknown(ua) or ua is TypeVarType) then
                  if node.e1.kind == "variable" then
                     self.errs:add_unknown_dot(node.e1, node.e1.tk .. "." .. node.e2.tk)
                  end
                  return an_unknown(node)
               end

               local t, e = self:match_record_key(ra, node.e1, node.e2.conststr or node.e2.tk)
               if not t then
                  return self.errs:invalid_at(node.e2, e, ua)
               end

               return t
            end

            if node.op.op == "not" then
               node.known = facts_not(node, node.e1.known)
               return a_type(node, "boolean", {})
            end

            if node.op.op == "and" then
               node.known = facts_and(node, node.e1.known, node.e2.known)
               return discard_tuple(node, ub, gb)
            end

            if node.op.op == "or" then
               local t: Type

               local expected = node.expected and self:to_structural(resolve_tuple(node.expected))

               if ub is NilType then
                  node.known = nil
                  t = ua

               elseif is_lua_table_type(ra) and rb is EmptyTableType then
                  node.known = nil
                  t = ua

               elseif ((ra is EnumType and rb is StringType and self:is_a(rb, ra))
                  or (ra is StringType and rb is EnumType and self:is_a(ra, rb))) then
                  node.known = nil
                  t = (ra is EnumType and ra or rb)

               elseif expected and expected is UnionType then
                  -- must be checked after string/enum above
                  node.known = facts_or(node, node.e1.known, node.e2.known)
                  local u = unite(node, {ra, rb}, true)
                  if u is UnionType then
                     ok, err = is_valid_union(u)
                     if not ok then
                        u = err and self.errs:invalid_at(node, err, u) or an_invalid(node)
                     end
                  end
                  t = u

               -- prefer the union type if it already works and the other one isn't a union
               elseif ra is UnionType and not (rb is UnionType) and self:is_a(rb, ra) then
                  -- convert it to the union type
                  t = drop_constant_value(ra)

               elseif rb is UnionType and not (ra is UnionType) and self:is_a(ra, rb) then
                  -- convert it to the union type
                  t = drop_constant_value(rb)

               else
                  -- these compare using the unresolved type to prevent nominal types resolving into
                  -- each other.
                  local a_ge_b = self:is_a(ub, ua)
                  local b_ge_a = self:is_a(ua, ub)
                  node.known = facts_or(node, node.e1.known, node.e2.known)
                  -- TODO: change this to use unresolved types, but make sure that it works with
                  -- table literal and nominal type
                  local is_same = self:same_type(ra, rb)

                  -- we can have some types that can be converted into either
                  local ambiguous = a_ge_b and b_ge_a and not is_same

                  -- prefer a type that we can easily work out rather than defaulting to the expected one
                  -- (the expected one might need to be collapsed later with special functions)
                  if is_same then
                     t = ua
                  elseif (a_ge_b or b_ge_a) and not ambiguous then
                     local larger_type = b_ge_a and ub or ua
                     t = larger_type
                  elseif expected and self:is_a(ua, expected) and self:is_a(ub, expected) then
                     t = self:infer_at(node, expected)
                  end

                  if ambiguous and not t then
                     if TL_DEBUG then
                        self.errs:add_warning("debug", node, "the resulting type is ambiguous: %s or %s", ua, ub)
                        self.errs:add_warning("debug", node, "currently choosing %s", ub)
                     end
                     -- workaround to keep existing code working
                     t = ub
                  end
                  if t then
                     t = drop_constant_value(t)
                  end

                  if expected and expected is BooleanContextType then
                     t = a_type(node, "boolean", {})
                  end
               end

               if t then
                  return discard_tuple(node, t, gb)
               end
               -- else fallthrough to general binop handler
            end

            if node.op.op == "==" or node.op.op == "~=" then
               if is_lua_table_type(ra) and is_lua_table_type(rb) then
                  self:check_metamethod(node, binop_to_metamethod[node.op.op], ra, rb, ua, ub)
               end

               if ra is EnumType and rb is StringType then
                  if not (rb.literal and ra.enumset[rb.literal]) then
                     return self.errs:invalid_at(node, "%s is not a member of %s", ub, ua)
                  end
               elseif ra is TupleTableType and rb is TupleTableType and #ra.types ~= #rb.types then
                  return self.errs:invalid_at(node, "tuples are not the same size")
               elseif self:is_a(ub, ua) or ua is TypeVarType then
                  if node.op.op == "==" and node.e1.kind == "variable" then
                     node.known = EqFact { var = node.e1.tk, typ = ub, w = node }
                  end
               elseif self:is_a(ua, ub) or ub is TypeVarType then
                  if node.op.op == "==" and node.e2.kind == "variable" then
                     node.known = EqFact { var = node.e2.tk, typ = ua, w = node }
                  end
               elseif self.feat_lax and (is_unknown(ua) or is_unknown(ub)) then
                  return an_unknown(node)
               else
                  return self.errs:invalid_at(node, "types are not comparable for equality: %s and %s", ua, ub)
               end

               return a_type(node, "boolean", {})
            end

            if node.op.arity == 1 and unop_types[node.op.op] then
               if ra is UnionType then
                  ra = unite(node, ra.types, true) -- squash unions of string constants
               end

               local types_op = unop_types[node.op.op]

               local tn = types_op[ra.typename]
               local t = tn and a_type(node, tn, {})

               if not t and ra is RecordLikeType then
                  if ra.interface_list then
                     for _, iface in ipairs(ra.interface_list) do
                        if types_op[iface.typename] then
                           t = a_type(node, types_op[iface.typename], {})
                           break
                        end
                     end
                  end
               end

               local meta_on_operator: integer
               if not t then
                  local mt_name = unop_to_metamethod[node.op.op]
                  if mt_name then
                     t, meta_on_operator = self:check_metamethod(node, mt_name, ra, nil, ua, nil)
                  end
               end

               if ra is MapType then
                  if ra.keys.typename == "number" or ra.keys.typename == "integer" then
                      self.errs:add_warning("hint", node, "using the '#' operator on a map with numeric key type may produce unexpected results")
                  else
                      self.errs:add(node, "using the '#' operator on this map will always return 0")
                  end
               end

               if node.op.op == "~" and self.gen_target == "5.1" then
                  if meta_on_operator then
                     self.all_needs_compat["mt"] = true
                     convert_node_to_compat_mt_call(node, unop_to_metamethod[node.op.op], 1, node.e1)
                  else
                     self.all_needs_compat["bit32"] = true
                     convert_node_to_compat_call(node, "bit32", "bnot", node.e1)
                  end
               end

               if not t then
                  return self.errs:invalid_at(node, "cannot use operator '" .. node.op.op:gsub("%%", "%%%%") .. "' on type %s", ua)
               end

               if not (t is BooleanType or is_unknown(t)) then
                  node.known = FACT_TRUTHY
               end

               return t
            end

            if node.op.arity == 2 and binop_types[node.op.op] then
               if node.op.op == "or" then
                  node.known = facts_or(node, node.e1.known, node.e2.known)
               end

               if ra is UnionType then
                  ra = unite(ra, ra.types, true) -- squash unions of string constants
               end
               if rb is UnionType then
                  rb = unite(rb, rb.types, true) -- squash unions of string constants
               end

               local types_op = binop_types[node.op.op]

               local tn = types_op[ra.typename] and types_op[ra.typename][rb.typename]
               local t = tn and a_type(node, tn, {})

               local meta_on_operator: integer
               if not t then
                  local mt_name = binop_to_metamethod[node.op.op]
                  local flipped = false
                  if not mt_name then
                     mt_name = flip_binop_to_metamethod[node.op.op]
                     if mt_name then
                        flipped = true
                        ra, rb = rb, ra
                        ua, ub = ub, ua
                     end
                  end
                  if mt_name then
                     t, meta_on_operator = self:check_metamethod(node, mt_name, ra, rb, ua, ub, flipped)
                     if flipped and not meta_on_operator then
                        ra, rb = rb, ra
                        ua, ub = ub, ua
                     end
                  end
               end

               if (not t) and ua is NominalType and ub is NominalType and not meta_on_operator then
                  if self:is_a(ua, ub) then
                     t = ua
                  end
               end

               if types_op == numeric_binop or node.op.op == ".." then
                  node.known = FACT_TRUTHY
               end

               if node.op.op == "//" and self.gen_target == "5.1" then
                  if meta_on_operator then
                     self.all_needs_compat["mt"] = true
                     convert_node_to_compat_mt_call(node, "__idiv", meta_on_operator, node.e1, node.e2)
                  else
                     local div: Node = node_at(node, { kind = "op", op = parser.operator(node, 2, "/"), e1 = node.e1, e2 = node.e2 })
                     convert_node_to_compat_call(node, "math", "floor", div)
                  end
               elseif bit_operators[node.op.op] and self.gen_target == "5.1" then
                  if meta_on_operator then
                     self.all_needs_compat["mt"] = true
                     convert_node_to_compat_mt_call(node, binop_to_metamethod[node.op.op], meta_on_operator, node.e1, node.e2)
                  else
                     self.all_needs_compat["bit32"] = true
                     convert_node_to_compat_call(node, "bit32", bit_operators[node.op.op], node.e1, node.e2)
                  end
               end

               if not t then
                  if node.op.op == "or" then
                     local u = unite(node, {ua, ub})
                     if u is UnionType and is_valid_union(u) then
                        self.errs:add_warning("hint", node, "if a union type was intended, consider declaring it explicitly")
                     end
                  end
                  return self.errs:invalid_at(node, "cannot use operator '" .. node.op.op:gsub("%%", "%%%%") .. "' for types %s and %s", ua, ub)
               end

               return t
            end

            error("unknown node op " .. node.op.op)
         end,
      },
      ["variable"] = {
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            if node.tk == "..." then
               local va_sentinel = self:find_var_type("@is_va")
               if not va_sentinel or va_sentinel is NilType then
                  return self.errs:invalid_at(node, "cannot use '...' outside a vararg function")
               end
            end

            local t: Type
            if node.tk == "_G" then
               t, node.attribute = self:simulate_g()
            else
               local use: VarUse = node.is_lvalue and "lvalue" or "use"
               t, node.attribute = self:find_var_type(node.tk, use)
            end
            if not t then
               if self.feat_lax then
                  self.errs:add_unknown(node, node.tk)
                  return an_unknown(node)
               end

               return self.errs:invalid_at(node, "unknown variable: " .. node.tk)
            end

            if t is TypeDeclType then
               t = typedecl_to_nominal(node, node.tk, t, t)
            end

            return t
         end,
      },
      ["type_identifier"] = {
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            local typ, attr = self:find_var_type(node.tk)
            node.attribute = attr
            if typ then
               return typ
            end

            if self.feat_lax then
               self.errs:add_unknown(node, node.tk)
               return an_unknown(node)
            end

            return self.errs:invalid_at(node, "unknown variable: " .. node.tk)
         end,
      },
      ["argument"] = {
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local t = children[1]
            if not t then
               if node.expected and node.tk == "self" then
                  t = node.expected
               else
                  t = self.feat_lax
                      and an_unknown(node)
                      or  a_type(node, "any", {})
               end
            end
            if node.tk == "..." then
               t = a_vararg(node, { t })
            end
            self:add_var(node, node.tk, t).is_func_arg = true
            return t
         end,
      },
      ["identifier"] = {
         after = function(_self: TypeChecker, _node: Node, _children: {Type}): Type
            return NONE -- type is resolved elsewhere
         end,
      },
      ["newtype"] = {
         after = function(_self: TypeChecker, node: Node, _children: {Type}): Type
            return node.newtype
         end,
      },
      ["pragma"] = {
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            if node.pkey == "arity" then
               if node.pvalue == "on" then
                  self.feat_arity = true
               elseif node.pvalue == "off" then
                  self.feat_arity = false
               else
                  return self.errs:invalid_at(node, "invalid value for pragma 'arity': " .. node.pvalue)
               end
            else
               return self.errs:invalid_at(node, "invalid pragma: " .. node.pkey)
            end
            return NONE
         end,
      },
      ["error_node"] = {
         after = function(_self: TypeChecker, node: Node, _children: {Type}): Type
            return an_invalid(node)
         end,
      }
   }

   visit_node.cbs["break"] = {
      after = function(_self: TypeChecker, _node: Node, _children: {Type}): Type
         return NONE
      end,
   }
   visit_node.cbs["do"] = visit_node.cbs["break"]

   local function after_literal(_self: TypeChecker, node: Node): Type
      node.known = FACT_TRUTHY
      return a_type(node, node.kind as TypeName, {})
   end

   visit_node.cbs["string"] = {
      after = function(self: TypeChecker, node: Node, _children: {Type}): Type
         local t = after_literal(self, node) as StringType
         t.literal = node.conststr

         local expected = node.expected and self:to_structural(node.expected)
         if expected and expected is EnumType and self:is_a(t, expected) then
            return node.expected
         end

         return t
      end,
   }
   visit_node.cbs["number"] = { after = after_literal }
   visit_node.cbs["integer"] = { after = after_literal }

   visit_node.cbs["boolean"] = {
      after = function(self: TypeChecker, node: Node, _children: {Type}): Type
         local t = after_literal(self, node)
         node.known = (node.tk == "true") and FACT_TRUTHY or nil
         return t
      end,
   }
   visit_node.cbs["nil"] = visit_node.cbs["boolean"]

   visit_node.cbs["..."] = visit_node.cbs["variable"]
   visit_node.cbs["argument_list"] = visit_node.cbs["variable_list"]
   visit_node.cbs["expression_list"] = visit_node.cbs["variable_list"]

   visit_node.after = function(_self: TypeChecker, node: Node, _children: {Type}, t: Type): Type
      if node.expanded then
         apply_macroexp(node)
      end

      return t
   end

   function TypeChecker:resolve_self(t: Type, resolve_interface?: boolean): Type, {Error}
      local selftype, selfdecl = self:type_of_self(t)
      local checktype = selftype
      if selftype is GenericType then
         checktype = selftype.t
      end

      if (resolve_interface and checktype is InterfaceType) or checktype is RecordType then
         return types.map(self, t, {
            ["self"] = function(_: TypeChecker, typ: SelfType): Type, boolean
               return typedecl_to_nominal(typ, checktype.declname, selfdecl)
            end,
         })
      else
         return t
      end
   end

   do
      local function add_interface_fields(self: TypeChecker, fields: {string:Type}, field_order: {string}, resolved: RecordLikeType, named: NominalType, list?: MetaMode)
         for fname, ftype in fields_of(resolved, list) do
            if fields[fname] then
               if not self:is_a(fields[fname], ftype) then
                  local what = list == "meta" and "metamethod" or "field"
                  self.errs:add(fields[fname], what .." '" .. fname .. "' does not match definition in interface %s", named)
               end
            else
               table.insert(field_order, fname)
               if ftype is TypeDeclType then
                  fields[fname] = ftype
               else
                  fields[fname] = self:resolve_self(ftype)
               end
            end
         end
      end

      local function collect_interfaces(self: TypeChecker, list: {ArrayType | NominalType}, t: RecordLikeType, seen:{Type:boolean}): {ArrayType | NominalType}
         if t.interface_list then
            for _, iface in ipairs(t.interface_list) do
               if iface is NominalType then
                  local ri = self:resolve_nominal(iface)
                  if ri is InterfaceType then
                     table.insert(list, iface)
                     if ri.interfaces_expanded and not seen[ri] then
                        seen[ri] = true
                        collect_interfaces(self, list, ri, seen)
                     end
                  else
                     self.errs:add(iface, "attempted to use %s as interface, but its type is %s", iface, ri)
                  end
               else
                  if not seen[iface] then
                     seen[iface] = true
                     table.insert(list, iface)
                  end
               end
            end
         end
         return list
      end

      function TypeChecker:expand_interfaces(t: RecordLikeType)
         if t.interfaces_expanded then
            return
         end
         t.interfaces_expanded = true

         t.interface_list = collect_interfaces(self, {}, t, {})

         for _, iface in ipairs(t.interface_list) do
            if iface is NominalType then
               local ri = self:resolve_nominal(iface)
               assert(ri is InterfaceType)
               add_interface_fields(self, t.fields, t.field_order, ri, iface)
               if ri.meta_fields then
                  t.meta_fields = t.meta_fields or {}
                  t.meta_field_order = t.meta_field_order or {}
                  add_interface_fields(self, t.meta_fields, t.meta_field_order, ri, iface, "meta")
               end
            else
               if not t.elements then
                  t.elements = iface
               else
                  if not self:same_type(iface.elements, t.elements) then
                     self.errs:add(t, "incompatible array interfaces")
                  end
               end
            end
         end
      end
   end

   function TypeChecker:begin_temporary_record_types(typ: RecordType)
      self:add_var(nil, "@self", a_typedecl(typ, typ))

      for fname, ftype in fields_of(typ) do
         if ftype is TypeDeclType then
            local def = ftype.def
            if def is NominalType then
               assert(ftype.is_alias)
               self:resolve_nominal(def)
            end
            self:add_var(nil, fname, ftype)
         end
      end
   end

   function TypeChecker:end_temporary_record_types(typ: RecordType)
      -- drop @self and nested records from scope
      -- to avoid closing them prematurely in end_scope()
      local scope = self.st[#self.st]
      scope.vars["@self"] = nil
      for fname, ftype in fields_of(typ) do
         if ftype is TypeDeclType then
            scope.vars[fname] = nil
         end
      end
   end

   local function ensure_is_method_self(typ: RecordLikeType, selfarg: Type, g?: GenericType): boolean
      if selfarg is SelfType then
         return true
      end
      if not selfarg is NominalType then
         return false
      end

      if #selfarg.names ~= 1 or selfarg.names[1] ~= typ.declname then
         return false
      end

      if g then
         if not selfarg.typevals then
            return false
         end

         if g.t.typeid ~= typ.typeid then
            return false
         end

         for j=1,#g.typeargs do
            local tv = selfarg.typevals[j]
            if not (tv and tv is TypeVarType and tv.typevar == g.typeargs[j].typearg) then
               return false
            end
         end
      end

      return true
   end

   local metamethod_is_method: {string: boolean} = {
      ["__bnot"] = true,
      ["__call"] = true,
      ["__close"] = true,
      ["__gc"] = true,
      ["__index"] = true,
      ["__is"] = true,
      ["__len"] = true,
      ["__newindex"] = true,
      ["__pairs"] = true,
      ["__tostring"] = true,
      ["__unm"] = true,
   }

   local visit_type: Visitor<TypeChecker, TypeName, Type, Type>
   visit_type = {
      cbs = {
         ["generic"] = {
            before = function(self: TypeChecker, typ: GenericType)
               self:begin_scope()
               self:add_var(nil, "@generic", typ)
            end,
            after = function(self: TypeChecker, typ: GenericType, _children: {Type}): Type
               self:end_scope()
               return fresh_typeargs(self, typ)
            end,
         },
         ["function"] = {
            after = function(self: TypeChecker, typ: FunctionType, _children: {Type}): Type
               if self.feat_arity == false then
                  typ.min_arity = 0
               end
               return typ
            end
         },
         ["record"] = {
            before = function(self: TypeChecker, typ: RecordType)
               self:begin_scope()
               self:begin_temporary_record_types(typ)
            end,
            after = function(self: TypeChecker, typ: RecordType, children: {Type}): Type
               local i = 1
               if typ.interface_list then
                  for j, _ in ipairs(typ.interface_list) do
                     local iface = children[i]
                     if iface is ArrayType then
                        typ.interface_list[j] = iface
                     elseif iface is NominalType then
                        local ri = self:resolve_nominal(iface)
                        if ri is InterfaceType then
                           typ.interface_list[j] = iface
                        else
                           self.errs:add(children[i], "%s is not an interface", children[i])
                        end
                     end
                     i = i + 1
                  end
               end
               if typ.elements then
                  typ.elements = children[i]
                  i = i + 1
               end
               local fmacros: {FunctionType}
               local g: Variable
               for name, _ in fields_of(typ) do
                  local ftype = children[i]
                  if ftype is FunctionType then
                     if ftype.macroexp then
                        fmacros = fmacros or {}
                        table.insert(fmacros, ftype)
                     end

                     if ftype.is_method then
                        local fargs = ftype.args.tuple
                        if fargs[1] then
                           if not g then
                              g = self:find_var("@generic")
                           end
                           ftype.is_method = ensure_is_method_self(typ, fargs[1], g and g.t as GenericType)
                           if ftype.is_method then
                              fargs[1] = a_self(fargs[1], typ)
                           end
                        end
                     end
                  elseif ftype is TypeDeclType and ftype.is_alias then
                     self:resolve_typealias(ftype)
                  end

                  typ.fields[name] = ftype
                  i = i + 1
               end
               for name, _ in fields_of(typ, "meta") do
                  local ftype = children[i]
                  if ftype is FunctionType then
                     if ftype.macroexp then
                        fmacros = fmacros or {}
                        table.insert(fmacros, ftype)
                     end
                     ftype.is_method = metamethod_is_method[name]
                  end
                  typ.meta_fields[name] = ftype
                  i = i + 1
               end

               if typ.interface_list then
                  self:expand_interfaces(typ)

                  if self.collector then
                     for fname, ftype in fields_of(typ) do
                        self.env.reporter:add_field(typ, fname, ftype)
                     end
                  end
               end

               if fmacros then
                  for _, t in ipairs(fmacros) do
                     local macroexp_type = recurse_node(self, t.macroexp, visit_node, visit_type)

                     self:check_macroexp_arg_use(t.macroexp as Node)

                     if not self:is_a(macroexp_type, t) then
                        self.errs:add(macroexp_type, "macroexp type does not match declaration")
                     end
                  end
               end

               self:end_temporary_record_types(typ)
               self:end_scope()

               return typ
            end,
         },
         ["typearg"] = {
            after = function(self: TypeChecker, typ: TypeArgType, _children: {Type}): Type
               local name = typ.typearg
               local old <const> = self:find_var(name, "check_only")
               if old then
                  self.errs:redeclaration_warning(typ, name, "type argument", old)
               end
               if simple_types[name as TypeName] then
                  self.errs:add(typ, "cannot use base type name '" .. name .. "' as a type variable")
               end

               self:add_var(nil, name, a_type(typ, "typearg", {
                  typearg = name,
                  constraint = typ.constraint,
               } as TypeArgType))
               return typ
            end,
         },
         ["typevar"] = {
            after = function(self: TypeChecker, typ: TypeVarType, _children: {Type}): Type
               if not self:find_var_type(typ.typevar) then
                  self.errs:add(typ, "undefined type variable " .. typ.typevar)
               end
               return typ
            end,
         },
         ["nominal"] = {
            after = function(self: TypeChecker, typ: NominalType, _children: {Type}): Type
               if typ.found then
                  return typ
               end

               local t, typearg = self:find_type(typ.names)
               if t then
                  local def = t.def
                  if t.is_alias then
                     if def is GenericType then
                        def = def.t
                     end
                     if def is NominalType then
                        typ.found = def.found
                     end
                  elseif def.typename ~= "circular_require" then
                     typ.found = t
                  end
               elseif typearg then
                  -- convert nominal into a typevar
                  typ.names = nil
                  edit_type(typ, typ, "typevar")
                  local tv = typ as TypeVarType
                  tv.typevar = typearg.typearg
                  tv.constraint = typearg.constraint
               else
                  local name = typ.names[1]
                  local scope = self.st[#self.st]
                  scope.pending_nominals = scope.pending_nominals or {}
                  scope.pending_nominals[name] = scope.pending_nominals[name] or {}
                  table.insert(scope.pending_nominals[name], typ)
               end
               return typ
            end,
         },
         ["union"] = {
            after = function(self: TypeChecker, typ: UnionType, _children: {Type}): Type
               local _, err = is_valid_union(typ)
               if err then
                  return self.errs:invalid_at(typ, err, typ)
               end
               return typ
            end
         },
      },
   }

   local default_type_visitor = {
      after = function(_self: TypeChecker, typ: Type, _children: {Type}): Type
         return typ
      end,
   }

   visit_type.cbs["interface"] = visit_type.cbs["record"]

   visit_type.cbs["typedecl"] = default_type_visitor
   visit_type.cbs["self"] = default_type_visitor
   visit_type.cbs["string"] = default_type_visitor
   visit_type.cbs["tupletable"] = default_type_visitor
   visit_type.cbs["array"] = default_type_visitor
   visit_type.cbs["map"] = default_type_visitor
   visit_type.cbs["enum"] = default_type_visitor
   visit_type.cbs["boolean"] = default_type_visitor
   visit_type.cbs["nil"] = default_type_visitor
   visit_type.cbs["number"] = default_type_visitor
   visit_type.cbs["integer"] = default_type_visitor
   visit_type.cbs["thread"] = default_type_visitor
   visit_type.cbs["emptytable"] = default_type_visitor
   visit_type.cbs["literal_table_item"] = default_type_visitor
   visit_type.cbs["unresolved_emptytable_value"] = default_type_visitor
   visit_type.cbs["tuple"] = default_type_visitor
   visit_type.cbs["poly"] = default_type_visitor
   visit_type.cbs["any"] = default_type_visitor
   visit_type.cbs["unknown"] = default_type_visitor
   visit_type.cbs["invalid"] = default_type_visitor
   visit_type.cbs["none"] = default_type_visitor

   local type VisitorAfterPatcher = function<S, N, T>(VisitorAfter<S, N, T>): VisitorAfter<S, N, T>

   local function internal_compiler_check<S, N>(fn: VisitorAfter<S, N, Type>): VisitorAfter<S, N, Type>
      return function(s: S, n: N, children: {Type}, t: Type): Type
         t = fn and fn(s, n, children, t) or t

         if type(t) ~= "table" then
            error(((n as Node).kind or (n as Type).typename) .. " did not produce a type")
         end
         if type(t.typename) ~= "string" then
            error(((n as Node).kind or (n as Type).typename) .. " type does not have a typename")
         end

         return t
      end
   end

   local function store_type_after<N>(fn: VisitorAfter<TypeChecker, N, Type>): VisitorAfter<TypeChecker, N, Type>
      return function(self: TypeChecker, n: N, children: {Type}, t: Type): Type
         t = fn and fn(self, n, children, t) or t

         local w = n as Where

         if w.y then
            self.collector.store_type(w.y, w.x, t)
         end

         return t
      end
   end

   local function debug_type_after<S>(fn: VisitorAfter<S, Node, Type>): VisitorAfter<S, Node, Type>
      return function(s: S, node: Node, children: {Type}, t: Type): Type
         t = fn and fn(s, node, children, t) or t

         node.debug_type = t
         return t
      end
   end

   local function patch_visitors(my_visit_node: Visitor<TypeChecker, NodeKind, Node, Type>,
                                 after_node: VisitorAfterPatcher<TypeChecker, Node, Type>,
                                 my_visit_type?: Visitor<TypeChecker, TypeName, Type, Type>,
                                 after_type?: VisitorAfterPatcher<TypeChecker, Type, Type>):
                                 Visitor<TypeChecker, NodeKind, Node, Type>,
                                 Visitor<TypeChecker, TypeName, Type, Type>
      if my_visit_node == visit_node then
         my_visit_node = shallow_copy_table(my_visit_node)
      end
      my_visit_node.after = after_node(my_visit_node.after)
      if my_visit_type then
         if my_visit_type == visit_type then
            my_visit_type = shallow_copy_table(my_visit_type)
         end
         my_visit_type.after = after_type(my_visit_type.after)
      else
         my_visit_type = visit_type
      end
      return my_visit_node, my_visit_type
   end

   local function set_feat(feat: Feat, default: boolean): boolean
      if feat then
         return (feat == "on")
      else
         return default
      end
   end

   tl.check = function(ast: Node, filename?: string, opts?: CheckOptions, env?: Env): Result, string
      filename = filename or "?"

      opts = opts or {}

      if not env then
         local err: string
         env, err = tl.new_env({ defaults = opts })
         if err then
            return nil, err
         end
      end

      local self: TypeChecker = {
         filename = filename,
         env = env,
         st = {
            {
               vars = env.globals,
               pending_global_types = {},
            },
         },
         errs = Errors.new(filename),
         all_needs_compat = {},
         dependencies = {},
         subtype_relations = TypeChecker.subtype_relations,
         eqtype_relations = TypeChecker.eqtype_relations,
         type_priorities = TypeChecker.type_priorities,
      }

      self.cache_std_metatable_type = env.globals["metatable"] and (env.globals["metatable"].t as TypeDeclType).def

      setmetatable(self, {
         __index = TypeChecker,
         __tostring = function(): string return "TypeChecker" end,
      })

      self.feat_lax   = set_feat(opts.feat_lax   or env.defaults.feat_lax,   false)
      self.feat_arity = set_feat(opts.feat_arity or env.defaults.feat_arity, true)
      self.gen_compat = opts.gen_compat or env.defaults.gen_compat or DEFAULT_GEN_COMPAT
      self.gen_target = opts.gen_target or env.defaults.gen_target or DEFAULT_GEN_TARGET

      if self.feat_lax then
         self.feat_arity = false
      end

      if self.gen_target == "5.4" and self.gen_compat ~= "off" then
         return nil, "gen-compat must be explicitly 'off' when gen-target is '5.4'"
      end

      if self.feat_lax then
         self.type_priorities = shallow_copy_table(self.type_priorities)
         self.type_priorities["unknown"] = 0

         self.subtype_relations = shallow_copy_table(self.subtype_relations)

         self.subtype_relations["unknown"] = {}
         self.subtype_relations["unknown"]["*"] = compare_true

         self.subtype_relations["*"] = shallow_copy_table(self.subtype_relations["*"])
         self.subtype_relations["*"]["unknown"] = compare_true
         -- in .lua files, all values can be used in a boolean context
         self.subtype_relations["*"]["boolean"] = compare_true

         self.get_rets = function(rets: TupleType): TupleType
            if #rets.tuple == 0 then
               return a_vararg(rets, { an_unknown(rets) })
            end
            return rets
         end
      else
         self.get_rets = function(rets: TupleType): TupleType
            return rets
         end
      end

      if env.report_types then
         env.reporter = env.reporter or tl.new_type_reporter()
         self.collector = env.reporter:get_collector(filename)
      end

      local visit_node, visit_type = visit_node, visit_type
      if opts.run_internal_compiler_checks then
         visit_node, visit_type = patch_visitors(
            visit_node, internal_compiler_check,
            visit_type, internal_compiler_check
         )
      end
      if self.collector then
         visit_node, visit_type = patch_visitors(
            visit_node, store_type_after,
            visit_type, store_type_after
         )
      end
      if TL_DEBUG then
         visit_node, visit_type = patch_visitors(
            visit_node, debug_type_after
         )
      end

      assert(ast.kind == "statements")
      recurse_node(self, ast, visit_node, visit_type)

      local global_scope = self.st[1]
      close_types(global_scope)
      self.errs:check_var_usage(global_scope, true)

      errors.clear_redundant_errors(self.errs.errors)

      add_compat_entries(ast, self.all_needs_compat, self.gen_compat)

      local result = {
         ast = ast,
         env = env,
         type = self.module_type or a_type(ast, "boolean", {}),
         filename = filename,
         warnings = self.errs.warnings,
         type_errors = self.errs.errors,
         dependencies = self.dependencies,
      }

      env.loaded[filename] = result
      table.insert(env.loaded_order, filename or "")

      if self.collector then
         env.reporter:store_result(self.collector, env.globals)
      end

      return result
   end
end

--------------------------------------------------------------------------------
-- High-level API
--------------------------------------------------------------------------------

local function read_full_file(fd: FILE): string, string
   local bom <const> = "\239\187\191" -- "\xEF\xBB\xBF"
   local content, err = fd:read("*a")
   if not content then
      return nil, err
   end

   if content:sub(1, bom:len()) == bom then
      content = content:sub(bom:len() + 1)
   end
   return content, err
end

local function lang_heuristic(filename?: string, input?: string): ParseLang
   if filename then
      local pattern <const> = "(.*)%.([a-z]+)$"
      local _, extension = filename:match(pattern)
      extension = extension and extension:lower()

      if extension == "tl" then
         return "tl"
      elseif extension == "lua" then
         return "lua"
      end
   end
   if input then
      return (input:match("^#![^\n]*lua[^\n]*\n")) and "lua" or "tl"
   end
   return "tl"
end

local function feat_lax_heuristic(lang: ParseLang): Feat
   return lang == "tl" and "off" or "on"
end

tl.check_file = function(filename: string, env?: Env, fd?: FILE): Result, string
   if env and env.loaded and env.loaded[filename] then
      return env.loaded[filename]
   end

   local input, err: string, string

   if not fd then
      fd, err = io.open(filename, "rb")
      if not fd then
         return nil, "could not open " .. filename .. ": " .. err
      end
   end

   input, err = read_full_file(fd)
   fd:close()
   if not input then
      return nil, "could not read " .. filename .. ": " .. err
   end

   return tl.check_string(input, env, filename)
end

function tl.target_from_lua_version(str: string): GenTarget
   if str == "Lua 5.1"
      or str == "Lua 5.2" then
      return "5.1"
   elseif str == "Lua 5.3" then
      return "5.3"
   elseif str == "Lua 5.4" then
      return "5.4"
   end
end

local function default_env_opts(runtime: boolean, parse_lang: ParseLang): EnvOptions
   local gen_target = runtime and tl.target_from_lua_version(_VERSION) or DEFAULT_GEN_TARGET
   local gen_compat: GenCompat = (gen_target == "5.4") and "off" or DEFAULT_GEN_COMPAT
   return {
      defaults = {
         feat_lax = feat_lax_heuristic(parse_lang),
         gen_target = gen_target,
         gen_compat = gen_compat,
         run_internal_compiler_checks = false,
      }
   }
end

function tl.check_string(input: string, env?: Env, filename?: string, parse_lang?: ParseLang): Result
   parse_lang = parse_lang or lang_heuristic(filename, input)
   env = env or tl.new_env(default_env_opts(false, parse_lang))

   if env.loaded and env.loaded[filename] then
      return env.loaded[filename]
   end
   filename = filename or ""

   local program, syntax_errors = tl.parse(input, filename, parse_lang)

   if (not env.keep_going) and #syntax_errors > 0 then
      local result = {
         ok = false,
         filename = filename,
         type = a_type({ f = filename, y = 1, x = 1 }, "boolean", {}),
         type_errors = {},
         syntax_errors = syntax_errors,
         env = env,
      }
      env.loaded[filename] = result
      table.insert(env.loaded_order, filename)
      return result
   end

   local result = tl.check(program, filename, env.defaults, env)

   result.syntax_errors = syntax_errors

   return result
end

tl.gen = function(input: string, env?: Env, opts?: GenerateOptions, parse_lang?: ParseLang): string, Result
   parse_lang = parse_lang or lang_heuristic(nil, input)
   env = env or assert(tl.new_env(default_env_opts(false, parse_lang)), "Default environment initialization failed")
   local result = tl.check_string(input, env)

   if (not result.ast) or #result.syntax_errors > 0 then
      return nil, result
   end

   local code: string
   code, result.gen_error = tl.generate(result.ast, env.defaults.gen_target, opts)
   return code, result
end

local function tl_package_loader(module_name: string): any, any
   local found_filename, fd, tried = tl.search_module(module_name, false)
   if found_filename then
      local parse_lang = lang_heuristic(found_filename)
      local input = read_full_file(fd)
      if not input then
         return table.concat(tried, "\n\t")
      end
      fd:close()
      local program, errs = tl.parse(input, found_filename, parse_lang)
      if #errs > 0 then
         error(found_filename .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg)
      end

      local env = tl.package_loader_env
      if not env then
         tl.package_loader_env = assert(tl.new_env(), "Default environment initialization failed")
         env = tl.package_loader_env
      end

      local opts = default_env_opts(true, parse_lang)

      local w = { f = found_filename, x = 1, y = 1 }
      env.modules[module_name] = a_typedecl(w, a_type(w, "circular_require", {}))

      local result = tl.check(program, found_filename, opts.defaults, env)

      env.modules[module_name] = result.type

      -- TODO: should this be a hard error? this seems analogous to
      -- finding a lua file with a syntax error in it
      local code = assert(tl.generate(program, opts.defaults.gen_target, fast_generate_opts))
      local chunk, err = load(code, "@" .. found_filename, "t")
      if chunk then
         return function(modname: string, loader_data: string): any
            if loader_data == nil then
               loader_data = found_filename
            end
            local ret = chunk(modname, loader_data)
            return ret
         end, found_filename
      else
         error("Internal Compiler Error: Teal generator produced invalid Lua. Please report a bug at https://github.com/teal-language/tl\n\n" .. err)
      end
   end
   return table.concat(tried, "\n\t")
end

function tl.loader()
   if package.searchers then
      table.insert(package.searchers, 2, tl_package_loader)
   else
      table.insert(package.loaders, 2, tl_package_loader)
   end
end

local function env_for(opts: EnvOptions, env_tbl: {any:any}): Env
   if not env_tbl then
      if not tl.package_loader_env then
         tl.package_loader_env = tl.new_env(opts)
      end
      return tl.package_loader_env
   end

   if not tl.load_envs then
      tl.load_envs = setmetatable({}, { __mode = "k" })
   end

   tl.load_envs[env_tbl] = tl.load_envs[env_tbl] or tl.new_env(opts)
   return tl.load_envs[env_tbl]
end

tl.load = function(input: string, chunkname?: string, mode?: LoadMode, ...: {any:any}): LoadFunction, string
   local parse_lang = lang_heuristic(chunkname)
   local program, errs = tl.parse(input, chunkname, parse_lang)
   if #errs > 0 then
      return nil, (chunkname or "") .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg
   end

   local opts = default_env_opts(true, parse_lang)

   if not tl.package_loader_env then
      tl.package_loader_env = tl.new_env(opts)
   end

   local filename = chunkname or ("string \"" .. input:sub(45) .. (#input > 45 and "..." or "") .. "\"")
   local result = tl.check(program, filename, opts.defaults, env_for(opts, ...))

   if mode and mode:match("c") then
      if #result.type_errors > 0 then
         local errout = {}
         for _, err in ipairs(result.type_errors) do
            table.insert(errout, err.filename .. ":" .. err.y .. ":" .. err.x .. ": " .. (err.msg or ""))
         end
         return nil, table.concat(errout, "\n")
      end

      mode = mode:gsub("c", "") as LoadMode
   end

   local code, err = tl.generate(program, opts.defaults.gen_target, fast_generate_opts)
   if not code then
      return nil, err
   end

   return load(code, chunkname, mode, ...)
end

tl.version = function(): string
   return VERSION
end

--------------------------------------------------------------------------------
-- Backwards compatibility
--------------------------------------------------------------------------------

function tl.get_types(result: Result): TypeReport, TypeReporter
   return result.env.reporter:get_report(), result.env.reporter
end

tl.init_env = function(lax?: boolean, gen_compat?: boolean | GenCompat, gen_target?: GenTarget, predefined?: {string}): Env, string
   local opts = {
      defaults = {
         feat_lax = (lax and "on" or "off") as Feat,
         gen_compat = ((gen_compat is GenCompat) and gen_compat) or
                       (gen_compat == false and "off") or
                       (gen_compat == true or gen_compat == nil) and "optional",
         gen_target = gen_target or
                      ((_VERSION == "Lua 5.1" or _VERSION == "Lua 5.2") and "5.1") or
                      "5.3",
      },
      predefined_modules = predefined,
   }

   return tl.new_env(opts)
end

tl.type_check = function(ast: Node, tc_opts?: tl.TypeCheckOptions): Result, string
   local opts: CheckOptions = {
      feat_lax = tc_opts.lax and "on" or "off",
      feat_arity = tc_opts.env and tc_opts.env.defaults.feat_arity or "on",
      gen_compat = tc_opts.gen_compat,
      gen_target = tc_opts.gen_target,
      run_internal_compiler_checks = tc_opts.run_internal_compiler_checks,
   }
   return tl.check(ast, tc_opts.filename, opts, tc_opts.env)
end

tl.pretty_print_ast = function(ast: Node, gen_target?: tl.TargetMode, mode?: boolean | tl.PrettyPrintOptions): string, string
   local opts: GenerateOptions
   if mode is tl.PrettyPrintOptions then
      opts = mode
   elseif mode == true then
      opts = fast_generate_opts
   else
      opts = default_generate_opts
   end

   return tl.generate(ast, gen_target, opts)
end

tl.process = function(filename: string, env?: Env, fd?: FILE): Result, string
   return tl.check_file(filename, env, fd)
end

tl.process_string = function(input: string, is_lua: boolean, env: Env, filename: string, _module_name: string): Result
   return tl.check_string(input, env or tl.init_env(is_lua), filename)
end

return tl
