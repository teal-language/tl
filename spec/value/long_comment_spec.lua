local tl = require("tl")


local function string_trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end


describe("long comment", function()
   it("typecheck a level 0 long comment", function()
      local tokens = tl.lex([=[
         --[[
            long comment line 1
            long comment line 2
         ]]
         local foo = 1
      ]=])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("typecheck a level 1 long comment", function()
      local tokens = tl.lex([[
         --[=[
            long comment line 1
            long comment line 2
         ]=]
         local foo = 1
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("typecheck a level 1 long comment inside a level 2 long comment", function()
      local tokens = tl.lex([[
         --[=[
            long comment line 1
            --[==[
              long comment within long comment
            ]==]
            long comment line 2
         ]=]
         local foo = 1
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("typecheck a level 2 long comment inside a level 1 long comment", function()
      local tokens = tl.lex([[
         --[==[
            long comment line 1
            --[=[
              long comment within long comment
            ]=]
            long comment line 2
         ]==]
         local foo = 1
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("long comments can contain quotes and double quotes", function()
      local tokens = tl.lex([=[
         --[[
            ' "
         ]]
         local foo = 1
      ]=])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("wrongly nested long comments result in a parse error", function()
      local tokens = tl.lex([[
         --[==[
            long comment line 1
            --[=[
              long comment within long comment
            ]==]
            long comment line 2
         ]=]
         local foo = 1
      ]])
      local errs = {}
      tl.parse_program(tokens, errs)
      assert.is_true(#errs > 0)
   end)

   pending("export Lua", function()
      local tokens = tl.lex([=[
         --[[
            long comment line 1
            long comment line 2
         ]]
         local foo = 1
      ]=])
      local _, ast = tl.parse_program(tokens)
      local lua = tl.pretty_print_ast(ast)
      assert.equal([=[--[[
            long comment line 1
            long comment line 2
         ]]
         local foo = 1]=], string_trim(lua))
   end)
end)
