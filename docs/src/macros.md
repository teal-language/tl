# Macros

Teal macros are compile-time code generators. They let you write Lua code that
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
TYPELIST.FIRST

MACROEXP.RETS
MACROEXP.ARGS
MACROEXP.EXP

GLOBAL_TYPE.VALUE
GLOBAL_TYPE.VAR

ASSIGNMENT.VARS
ASSIGNMENT.EXPS

MACRO_INVOCATION.ARGS
MACRO_INVOCATION.MACRO

UNION_TYPE.FIRST

PAREN.EXP

DO.BODY

EXPRESSION_LIST.FIRST
EXPRESSION_LIST.SECOND

FUNCTION.BODY
FUNCTION.RETS
FUNCTION.TYPEARGS
FUNCTION.ARGS

LOCAL_MACROEXP.NAME
LOCAL_MACROEXP.EXP

TYPEARGS.FIRST

LOCAL_TYPE.VALUE
LOCAL_TYPE.VAR

MACRO_VAR.NAME

VARIABLE_LIST.FIRST

GLOBAL_DECLARATION.EXPS
GLOBAL_DECLARATION.VARS
GLOBAL_DECLARATION.DECL

RECORD.FIELDS
RECORD.META_FIELDS
RECORD.ARRAY_TYPE
RECORD.WHERE_CLAUSE
RECORD.INTERFACES

RECORD_FUNCTION.ARGS
RECORD_FUNCTION.BODY
RECORD_FUNCTION.RETS
RECORD_FUNCTION.TYPEARGS
RECORD_FUNCTION.NAME
RECORD_FUNCTION.OWNER

INTERFACE_LIST.FIRST

RETURN.EXPS

MAP_TYPE.KEYS
MAP_TYPE.VALUES

OP.E1
OP.E2

ARRAY_TYPE.ELEMENT

IF.BLOCKS

TUPLE_TYPE.FIRST
TUPLE_TYPE.SECOND

NOMINAL_TYPE.NAME

NEWTYPE.TYPEDECL

GENERIC_TYPE.TYPEARGS
GENERIC_TYPE.BASE

TYPEARG.NAME
TYPEARG.CONSTRAINT

ARGUMENT_TYPE.NAME

TYPEDECL.TYPE

PRAGMA.KEY
PRAGMA.VALUE

WHILE.BODY
WHILE.COND

RECORD_FIELD.DEFAULT_VAL
RECORD_FIELD.VAL
RECORD_FIELD.TYPE
RECORD_FIELD.NAME
RECORD_FIELD.METHOD

ARGUMENT_LIST.FIRST

RECORD_BODY.META_FIELDS
RECORD_BODY.FIELDS

MACRO_QUOTE.BLOCK

INTERFACE.FIELDS
INTERFACE.INTERFACES
INTERFACE.ARRAY_TYPE

CAST.TYPE

LITERAL_TABLE_ITEM.VALUE
LITERAL_TABLE_ITEM.KEY
LITERAL_TABLE_ITEM.TYPED_VALUE

FUNCTION_TYPE.MACROEXP
FUNCTION_TYPE.ARGS
FUNCTION_TYPE.RETS

LOCAL_DECLARATION.EXPS
LOCAL_DECLARATION.VARS
LOCAL_DECLARATION.DECL

LOCAL_FUNCTION.RETS
LOCAL_FUNCTION.BODY
LOCAL_FUNCTION.TYPEARGS
LOCAL_FUNCTION.NAME
LOCAL_FUNCTION.ARGS

FORIN.EXPS
FORIN.VARS
FORIN.BODY

GOTO.LABEL

GLOBAL_FUNCTION.RETS
GLOBAL_FUNCTION.BODY
GLOBAL_FUNCTION.TYPEARGS
GLOBAL_FUNCTION.NAME
GLOBAL_FUNCTION.ARGS

VARIABLE.ANNOTATION

REPEAT.BODY
REPEAT.COND

LABEL.NAME

IF_BLOCK.BODY
IF_BLOCK.COND

LOCAL_MACRO.RETS
LOCAL_MACRO.BODY
LOCAL_MACRO.TYPEARGS
LOCAL_MACRO.NAME
LOCAL_MACRO.ARGS

FORNUM.TO
FORNUM.VAR
FORNUM.FROM
FORNUM.BODY
FORNUM.STEP

ARGUMENT.ANNOTATION
```
