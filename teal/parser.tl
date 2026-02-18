local ast = require("teal.ast")
local reader = require("teal.reader")
local type errors = require("teal.errors")
local type Error = errors.Error
local type Where = errors.Where

local type block = require("teal.block")
local type Block = block.Block

local type types = require("teal.types")
local type Type = types.Type
local type TupleType = types.TupleType

local type lexer = require("teal.lexer")
local type Token = lexer.Token

local record parser
   type Node = ast.Node
   type NodeKind = ast.NodeKind
   type Operator = ast.Operator
   type ParseLang = ast.ParseLang

   parse: function(input: string, filename: string, parse_lang?: ParseLang): types.Node, {Error}, {string}
   parse_blocks: function(input: Block, filename: string, parse_lang?: ParseLang): types.Node, {Error}, {string}
   parse_program: function(tokens: {Token}, errs: {Error}, filename?: string, parse_lang?: ParseLang): types.Node, {string}
   parse_program_block: function(input: Block, filename: string, parse_lang?: ParseLang): types.Node, {Error}, {string}
   operator: function(ast.Node, integer, string): ast.Operator

   parse_type: function(state: any, block: Block): Type
   parse_type_list: function(state: any, block: Block, mode: any): TupleType, boolean, integer

   node_is_funcall: function(ast.Node): boolean
   node_is_require_call: function(ast.Node): string
   node_at: function(Where, ast.Node): ast.Node
   lang_heuristic: function(filename?: string, input?: string): ParseLang
end

parser.parse_blocks = ast.parse_blocks
parser.parse_program_block = ast.parse_program_block
parser.parse_type = ast.parse_type
parser.parse_type_list = ast.parse_type_list
parser.operator = ast.operator
parser.node_is_funcall = ast.node_is_funcall
parser.node_is_require_call = ast.node_is_require_call
parser.node_at = ast.node_at
parser.lang_heuristic = ast.lang_heuristic

function parser.parse(input: string, filename: string, parse_lang?: parser.ParseLang): types.Node, {Error}, {string}
   local block_ast, read_errs = reader.read(input, filename, parse_lang)
   read_errs = read_errs or {}

   local ast_nodes, parse_errs, required = ast.parse_blocks(block_ast, filename, parse_lang)
   for _, e in ipairs(parse_errs) do
      table.insert(read_errs, e)
   end

   return ast_nodes, read_errs, required
end

function parser.parse_program(tokens: {Token}, errs: {Error}, filename?: string, parse_lang?: parser.ParseLang): types.Node, {string}
   errs = errs or {}
   local block_ast = reader.read_program(tokens, errs, filename, parse_lang)
   local ast_nodes, parse_errs, required = ast.parse_program_block(block_ast, filename or "input", parse_lang)
   for _, e in ipairs(parse_errs) do
      table.insert(errs, e)
   end
   return ast_nodes, required
end

return parser
