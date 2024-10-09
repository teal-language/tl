local tl = require("tl")
local util = require("spec.util")


local function string_trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function multitrim(s)
   return s:gsub("^%s*", ""):gsub("%s*\n%s*", "\n"):gsub("%s*$", "")
end

describe("long string", function()
   it("accepts a level 0 long string", util.check [=[
      local foo = [[
            long string line 1
            long string line 2
         ]]
   ]=])

   it("accepts a level 1 long string", util.check([[
      local foo = [=[
            long string line 1
            long string line 2
         ]=]
   ]]))

   it("does not get confused by a ] when closing a level 1 long string", util.check [===[
      local foo = [=[hello]]=]
   ]===])

   it("does not get confused by multiple ] when closing a level 1 long string", util.check [===[
      local foo = [=[hello]]]]]]=]
   ]===])

   it("accepts a level 1 long string inside a level 2 long string", util.check([[
      local foo = [=[
            long string line 1
            [==[
              long string within long string
            ]==]
            long string line 2
         ]=]
   ]]))

   it("accepts a level 2 long string inside a level 1 long string", util.check([[
      local foo = [==[
            long string line 1
            [=[
              long string within long string
            ]=]
            long string line 2
         ]==]
   ]]))

   it("long strings can contain quotes and double quotes", util.check [=[
      local foo = [[
            ' "
         ]]
   ]=])

   it("wrongly nested long strings result in a parse error", util.check_syntax_error([[
      local foo = [==[
            long string line 1
            [=[
              long string within long string
            ]==]
            long string line 2
         ]=]
   ]], {
      { y = 6, x = 18, msg = "syntax error" },
      { y = 7, x = 10, msg = "syntax error" },
   }))

   it("export Lua", function()
      local result = tl.process_string([==[
         local foo = [=[
               long string line 1
               long string line 2
            ]=]
      ]==])
      local lua = tl.pretty_print_ast(result.ast)
      assert.equal([==[local foo = [=[
               long string line 1
               long string line 2
            ]=]]==], string_trim(lua))
   end)

   it("can use long strings and preserve spacing on table items", function()
      local result = tl.process_string([==[
         local t: {string: boolean} = {
            [ [["random_string"]] ] = true,
         }]==])
      local lua = tl.pretty_print_ast(result.ast)
      assert.equal(multitrim([==[
         local t = {
            [ [["random_string"]] ] = true,
         }
      ]==]), multitrim(lua))
   end)

   it("can use long strings and preserve spacing on indices", function()
      local result = tl.process_string([==[
         local t: {string: boolean} = {}
         t[ [["random_string"]] ] = true
      ]==])
      local lua = tl.pretty_print_ast(result.ast)
      assert.equal(multitrim([==[
         local t = {}
         t[ [["random_string"]] ] = true
      ]==]), multitrim(lua))
   end)

end)
