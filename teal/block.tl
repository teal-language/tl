local errors = require("teal.errors")
local type Where = errors.Where

local record block
   enum BlockKind
      "nil"
      "string"
      "number"
      "integer"
      "boolean"
      "literal_table"
      "literal_table_item"
      "function"
      "expression_list"
      "if"
      "if_block"
      "while"
      "fornum"
      "forin"
      "goto"
      "label"
      "repeat"
      "do"
      "break"
      "return"
      "newtype"
      "argument"
      "type_identifier"
      "variable"
      "variable_list"
      "statements"
      "assignment"
      "argument_list"
      "local_function"
      "global_function"
      "local_type"
      "global_type"
      "record_function"
      "local_declaration"
      "global_declaration"
      "identifier"
      "cast"
      "..."
      ":"
      ";"
      "hashbang"
      "paren"
      "macroexp"
      "local_macroexp"
      "local_macro"
      "macro_quote"
      "macro_var"
      "macro_invocation"
      "interface"
      "pragma"
      "error_block"
      "userdata"

      "op_not"
      "op_len"
      "op_unm"
      "op_bnot"
      "op_or"
      "op_and"
      "op_is"
      "op_lt"
      "op_gt"
      "op_le"
      "op_ge"
      "op_ne"
      "op_eq"
      "op_bor"
      "op_bxor"
      "op_band"
      "op_shl"
      "op_shr"
      "op_concat"
      "op_add"
      "op_sub"
      "op_mul"
      "op_div"
      "op_idiv"
      "op_mod"
      "op_pow"
      "op_as"
      "op_funcall"
      "op_index"
      "op_dot"
      "op_colon"

      "typeargs"
      "typelist"
      "generic_type"
      "typedecl"
      "tuple_type"
      "nominal_type"
      "map_type"
      "array_type"
      "union_type"
      "argument_type"
      "interface_list"
      "record_body"
      "record_field"
      "question"
   end

   record Block
      is {Block}, Where
      where self.kind ~= nil

      record ExpectedContext
         kind: BlockKind
         name: string
      end

      tk: string
      kind: BlockKind
      yend: integer
      xend: integer
      constnum: number
      conststr: string
      is_longstring: boolean
   end

   enum BlockLang
      "lua"
      "tl"
   end

   -- Alias to keep compatibility with parser's ParseLang
   type ParseLang = BlockLang

   BLOCK_INDEXES: {string : {string : integer}}
end

local BLOCK_INDEXES <const> = {
   PRAGMA = {
      KEY = 1,
      VALUE = 2,
   },
   IF = {
      BLOCKS = 1,
   },
   IF_BLOCK = {
      COND = 1,
      BODY = 2,
   },
   WHILE = {
      COND = 1,
      BODY = 2,
   },
   FORNUM = {
      VAR = 1,
      FROM = 2,
      TO = 3,
      STEP = 4,
      BODY = 5,
   },
   FORIN = {
      VARS = 1,
      EXPS = 2,
      BODY = 3,
   },
   REPEAT = {
      BODY = 1,
      COND = 2,
   },
   DO = {
      BODY = 1,
   },
   GOTO = {
      LABEL = 1,
   },
   LABEL = {
      NAME = 1,
   },
   RETURN = {
      EXPS = 1,
   },
   FUNCTION = {
      TYPEARGS = 2,
      ARGS = 3,
      RETS = 4,
      BODY = 5,
   },
   LOCAL_FUNCTION = {
      NAME = 1,
      TYPEARGS = 2,
      ARGS = 3,
      RETS = 4,
      BODY = 5,
   },
   GLOBAL_FUNCTION = {
      NAME = 1,
      TYPEARGS = 2,
      ARGS = 3,
      RETS = 4,
      BODY = 5,
   },
   RECORD_FUNCTION = {
      OWNER = 1,
      NAME = 2,
      TYPEARGS = 3,
      ARGS = 4,
      RETS = 5,
      BODY = 6,
   },
   LOCAL_MACRO = {
      NAME = 1,
      TYPEARGS = 2,
      ARGS = 3,
      RETS = 4,
      BODY = 5,
   },
   LOCAL_MACROEXP = {
      NAME = 1,
      EXP = 2,
   },
   LOCAL_DECLARATION = {
      VARS = 1,
      DECL = 2,
      EXPS = 3,
   },
   GLOBAL_DECLARATION = {
      VARS = 1,
      DECL = 2,
      EXPS = 3,
   },
   LOCAL_TYPE = {
      VAR = 1,
      VALUE = 2,
   },
   GLOBAL_TYPE = {
      VAR = 1,
      VALUE = 2,
   },
   ASSIGNMENT = {
      VARS = 1,
      EXPS = 3,
   },
   VARIABLE = {
      ANNOTATION = 1,
   },
   ARGUMENT = {
      ANNOTATION = 1,
   },
   ARGUMENT_LIST = {
      FIRST = 1,
   },
   VARIABLE_LIST = {
      FIRST = 1,
   },
   EXPRESSION_LIST = {
      FIRST = 1,
      SECOND = 2,
   },
   LITERAL_TABLE_ITEM = {
      KEY = 1,
      VALUE = 2,
      TYPED_VALUE = 3,
   },
   OP = {
      E1 = 1,
      E2 = 2,
   },
   PAREN = {
      EXP = 1,
   },
   MACRO_QUOTE = {
      BLOCK = 1,
   },
   MACRO_VAR = {
      NAME = 1,
   },
   MACRO_INVOCATION = {
      MACRO = 1,
      ARGS = 2,
   },
   CAST = {
      TYPE = 1,
   },
   NEWTYPE = {
      TYPEDECL = 1,
   },
   TYPEDECL = {
      TYPE = 1,
   },
   FUNCTION_TYPE = {
      ARGS = 1,
      RETS = 2,
      MACROEXP = 4,
   },
   MACROEXP = {
      ARGS = 1,
      RETS = 2,
      EXP = 3,
   },
   RECORD = {
      ARRAY_TYPE = 1,
      INTERFACES = 2,
      FIELDS = 3,
      META_FIELDS = 4,
      WHERE_CLAUSE = 5,
   },
   INTERFACE = {
      ARRAY_TYPE = 1,
      INTERFACES = 2,
      FIELDS = 3,
   },
   RECORD_BODY = {
      FIELDS = 1,
      META_FIELDS = 2,
   },
   RECORD_FIELD = {
      NAME = 1,
      TYPE = 2,
      VAL = 3,
      METHOD = 4,
      DEFAULT_VAL = 5,
   },
   ARGUMENT_TYPE = {
      NAME = 1,
   },
   TYPEARGS = {
      FIRST = 1,
   },
   TYPEARG = {
      NAME = 1,
      CONSTRAINT = 2,
   },
   GENERIC_TYPE = {
      TYPEARGS = 1,
      BASE = 2,
   },
   NOMINAL_TYPE = {
      NAME = 1,
   },
   UNION_TYPE = {
      FIRST = 1,
   },
   TUPLE_TYPE = {
      FIRST = 1,
      SECOND = 2,
   },
   ARRAY_TYPE = {
      ELEMENT = 1,
   },
   MAP_TYPE = {
      KEYS = 1,
      VALUES = 2,
   },
   TYPELIST = {
      FIRST = 1,
   },
   INTERFACE_LIST = {
      FIRST = 1,
   },
}

block.BLOCK_INDEXES = BLOCK_INDEXES

return block
