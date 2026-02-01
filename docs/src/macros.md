# Macros

Teal macros are compile-time code generators. They let you write Teal code that
constructs and returns AST blocks, which are then spliced into your program
before type checking and code generation. Macros are a separate feature from
macro expressions (see [Macro expressions](./macroexp.md)).

Macros are **local** and **compile-time only**: their declarations are removed
after expansion and produce no Lua code at runtime.

## Declaring a macro

A macro is declared with `local macro`, a name ending in `!`, and a function
body:

```lua
local macro inc!(x: Expression)
   return `$x + 1`
end

local y = inc!(2)
```

Here, `inc!` receives an expression AST and returns a new expression AST built
from a quote.

## Invoking a macro

A macro call uses the `!` postfix operator and accepts the same argument forms
as function calls:

```lua
foo!(a, b)
foo!"string"
foo!{ key = "value" }
```

Macros can appear in expression or statement positions, as long as the macro
returns a compatible kind of block.

## Macro arguments

Macro parameters must be annotated as one of:

- `Expression`
- `Statement`
- `...: Expression` (vararg)
- `...: Statement` (vararg)

Example:

```lua
local macro wrap!(s: Statement, e: Expression)
   local out = block("statements")
   table.insert(out, s)
   table.insert(out, `print($e)`)
   return out
end

wrap!(do
   local x = 1
end, "ok")
```

`Statement` arguments are passed as a `statements` block, which can contain one
or more statements.

Macro arguments are **AST blocks**, not runtime values. Macros transform the
syntax tree and return new blocks to be spliced into the program.

## Quoting and splicing

Macros usually construct AST blocks by quoting Teal syntax:

- **Single backticks** quote an expression: `` `a + 1` ``
- **Triple backticks** quote statements: use three backticks (```` ``` ````)

Inside a macro quote, `$name` splices the macro argument named `name`:

```lua
local macro twice!(x: Expression)
   return `$x + $x`
end
```

For statement quotes, you can splice a `Statement` argument by putting `$name`
on its own line (optional semicolon):

~~~lua
local macro insert!(s: Statement)
   return ```
      $s
      print("after")
   ```
end
~~~

## Building AST blocks directly

The macro sandbox provides helpers for manual AST construction:

- `block(kind)` creates a block of a given kind
- `BLOCK_INDEXES` gives numeric indices for block fields
- `clone(b)` makes a deep copy of a block

Example:

```lua
local macro make_local!(name: Expression, value: Expression)
   local BI = BLOCK_INDEXES
   local decl = block("local_declaration")
   decl[BI.LOCAL_DECLARATION.VARS] = block("variable_list")
   decl[BI.LOCAL_DECLARATION.VARS][BI.VARIABLE_LIST.FIRST] = name
   decl[BI.LOCAL_DECLARATION.EXPS] = block("expression_list")
   decl[BI.LOCAL_DECLARATION.EXPS][BI.EXPRESSION_LIST.FIRST] = value
   return decl
end
```

## By-design limitations

| Detail | Notes |
| --- | --- |
| Local only | Macros must be declared with `local macro` and are scoped to a single file. They cannot be exported or imported. |
| Compile-time only | Macros run before type checking, and their declarations produce no runtime code. |
| Restricted environment | Macro bodies run in a sandbox with a limited standard library (no `require`, file I/O, or OS access beyond basic timing functions). |
| Argument types are fixed | Every parameter must be annotated as `Statement` or `Expression` (varargs allowed). Other annotations are errors. |
| Quotes are only valid inside macros | Backtick quotes and `$name` splices are rejected outside `local macro` bodies. |
| No nested macro invocations | You cannot use `other!()` inside a macro body to expand another macro; build the block directly or with quotes. |
| Statement args with top-level commas need a wrapper | When passing a statement argument like `local a, b = 1, 2`, wrap it in `do ... end` to avoid parsing ambiguity. |

## Block kinds

All block kinds that can be returned from macros are listed below (from
`teal/block.tl`):

```
nil
string
number
integer
boolean
literal_table
literal_table_item
function
expression_list
if
if_block
while
fornum
forin
goto
label
repeat
do
break
return
newtype
argument
type_identifier
variable
variable_list
statements
assignment
argument_list
local_function
global_function
local_type
global_type
record_function
local_declaration
global_declaration
identifier
cast
...
:
;
comment
hashbang
paren
macroexp
local_macroexp
local_macro
macro_quote
macro_var
macro_invocation
interface
pragma
error_block
userdata
op_not
op_len
op_unm
op_bnot
op_or
op_and
op_is
op_lt
op_gt
op_le
op_ge
op_ne
op_eq
op_bor
op_bxor
op_band
op_shl
op_shr
op_concat
op_add
op_sub
op_mul
op_div
op_idiv
op_mod
op_pow
op_as
op_funcall
op_index
op_dot
op_colon
typeargs
typelist
generic_type
typedecl
tuple_type
nominal_type
map_type
array_type
union_type
argument_type
interface_list
record_body
record_field
question
```

## BLOCK_INDEXES reference

`BLOCK_INDEXES` maps block kinds to the numeric slots used by their children.
This is the full table used by the macro API (from `teal/block.tl`):

```lua
BLOCK_INDEXES = {
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
```
