local tl = require("tl")


local function string_trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end


describe("long string", function()
   it("accepts a level 0 long string", function()
      local tokens = tl.lex([=[
         local foo = [[
               long string line 1
               long string line 2
            ]]
      ]=])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("accepts a level 1 long string", function()
      local tokens = tl.lex([[
         local foo = [=[
               long string line 1
               long string line 2
            ]=]
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

  it("does not get confused by a ] when closing a level 1 long string", function()
      local tokens = tl.lex([===[
         local foo = [=[hello]]=]
      ]===])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

  it("does not get confused by multiple ] when closing a level 1 long string", function()
      local tokens = tl.lex([===[
         local foo = [=[hello]]]]]]=]
      ]===])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("accepts a level 1 long string inside a level 2 long string", function()
      local tokens = tl.lex([[
         local foo = [=[
               long string line 1
               [==[
                 long string within long string
               ]==]
               long string line 2
            ]=]
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("accepts a level 2 long string inside a level 1 long string", function()
      local tokens = tl.lex([[
         local foo = [==[
               long string line 1
               [=[
                 long string within long string
               ]=]
               long string line 2
            ]==]
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("long strings can contain quotes and double quotes", function()
      local tokens = tl.lex([=[
         local foo = [[
               ' "
            ]]
      ]=])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("wrongly nested long strings result in a parse error", function()
      local tokens = tl.lex([[
         local foo = [==[
               long string line 1
               [=[
                 long string within long string
               ]==]
               long string line 2
            ]=]
      ]])
      local errs = {}
      tl.parse_program(tokens, errs)
      assert.is_true(#errs > 0)
   end)

   it("export Lua", function()
      local tokens = tl.lex([==[
         local foo = [=[
               long string line 1
               long string line 2
            ]=]
      ]==])
      local _, ast = tl.parse_program(tokens)
      local lua = tl.pretty_print_ast(ast)
      assert.equal([==[local foo = [=[
               long string line 1
               long string line 2
            ]=]]==], string_trim(lua))
   end)
end)
