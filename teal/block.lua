local errors = require("teal.errors")


local block = { Block = { ExpectedContext = {} } }





































































































































local BLOCK_INDEXES = {
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

local BLOCK_KINDS = {
   ["nil"] = true,
   ["string"] = true,
   ["number"] = true,
   ["integer"] = true,
   ["boolean"] = true,
   ["literal_table"] = true,
   ["literal_table_item"] = true,
   ["function"] = true,
   ["expression_list"] = true,
   ["if"] = true,
   ["if_block"] = true,
   ["while"] = true,
   ["fornum"] = true,
   ["forin"] = true,
   ["goto"] = true,
   ["label"] = true,
   ["repeat"] = true,
   ["do"] = true,
   ["break"] = true,
   ["return"] = true,
   ["newtype"] = true,
   ["argument"] = true,
   ["type_identifier"] = true,
   ["variable"] = true,
   ["variable_list"] = true,
   ["statements"] = true,
   ["assignment"] = true,
   ["argument_list"] = true,
   ["local_function"] = true,
   ["global_function"] = true,
   ["local_type"] = true,
   ["global_type"] = true,
   ["record_function"] = true,
   ["local_declaration"] = true,
   ["global_declaration"] = true,
   ["identifier"] = true,
   ["cast"] = true,
   ["..."] = true,
   [":"] = true,
   [";"] = true,
   ["comment"] = true,
   ["hashbang"] = true,
   ["paren"] = true,
   ["macroexp"] = true,
   ["local_macroexp"] = true,
   ["local_macro"] = true,
   ["macro_quote"] = true,
   ["macro_var"] = true,
   ["macro_invocation"] = true,
   ["interface"] = true,
   ["pragma"] = true,
   ["error_block"] = true,
   ["userdata"] = true,

   ["op_not"] = true,
   ["op_len"] = true,
   ["op_unm"] = true,
   ["op_bnot"] = true,
   ["op_or"] = true,
   ["op_and"] = true,
   ["op_is"] = true,
   ["op_lt"] = true,
   ["op_gt"] = true,
   ["op_le"] = true,
   ["op_ge"] = true,
   ["op_ne"] = true,
   ["op_eq"] = true,
   ["op_bor"] = true,
   ["op_bxor"] = true,
   ["op_band"] = true,
   ["op_shl"] = true,
   ["op_shr"] = true,
   ["op_concat"] = true,
   ["op_add"] = true,
   ["op_sub"] = true,
   ["op_mul"] = true,
   ["op_div"] = true,
   ["op_idiv"] = true,
   ["op_mod"] = true,
   ["op_pow"] = true,
   ["op_as"] = true,
   ["op_funcall"] = true,
   ["op_index"] = true,
   ["op_dot"] = true,
   ["op_colon"] = true,

   ["typeargs"] = true,
   ["typelist"] = true,
   ["generic_type"] = true,
   ["typedecl"] = true,
   ["tuple_type"] = true,
   ["nominal_type"] = true,
   ["map_type"] = true,
   ["array_type"] = true,
   ["union_type"] = true,
   ["argument_type"] = true,
   ["interface_list"] = true,
   ["record_body"] = true,
   ["record_field"] = true,
   ["question"] = true,
}

block.BLOCK_INDEXES = BLOCK_INDEXES
block.BLOCK_KINDS = BLOCK_KINDS

return block
