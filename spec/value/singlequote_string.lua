local tl = require("tl")


local function string_trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end


describe("singlequote string", function()
   it("typecheck", function()
      local tokens = tl.lex([[local foo = 'bar']])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("export Lua", function()
      local tokens = tl.lex([[local foo = 'bar']])
      local _, ast = tl.parse_program(tokens)
      local lua = tl.pretty_print_ast(ast)
      assert.equal([[local foo = 'bar']], string_trim(lua))
   end)
end)
