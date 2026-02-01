local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table; local ast = require("teal.ast")
local reader = require("teal.reader")














local parser = {}




















parser.parse_blocks = ast.parse_blocks
parser.parse_program_block = ast.parse_program_block
parser.parse_type = ast.parse_type
parser.parse_type_list = ast.parse_type_list
parser.operator = ast.operator
parser.node_is_funcall = ast.node_is_funcall
parser.node_is_require_call = ast.node_is_require_call
parser.node_at = ast.node_at
parser.lang_heuristic = ast.lang_heuristic

function parser.parse(input, filename, parse_lang)
   local block_ast, read_errs = reader.read(input, filename, parse_lang)
   read_errs = read_errs or {}

   local ast_nodes, parse_errs, required = ast.parse_blocks(block_ast, filename, parse_lang)
   for _, e in ipairs(parse_errs) do
      table.insert(read_errs, e)
   end

   return ast_nodes, read_errs, required
end

function parser.parse_program(tokens, errs, filename, parse_lang)
   errs = errs or {}
   local block_ast = reader.read_program(tokens, errs, filename, parse_lang)
   local ast_nodes, parse_errs, required = ast.parse_program_block(block_ast, filename or "input", parse_lang)
   for _, e in ipairs(parse_errs) do
      table.insert(errs, e)
   end
   return ast_nodes, required
end

return parser
