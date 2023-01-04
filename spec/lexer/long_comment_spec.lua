local tl = require("tl")
local util = require("spec.util")


local function string_trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end


describe("long comment", function()
   it("accepts a level 0 long comment", util.check [=[
      --[[
         long comment line 1
         long comment line 2
      ]]
      local foo = 1
   ]=])

   it("accepts a level 1 long comment", util.check [[
      --[=[
         long comment line 1
         long comment line 2
      ]=]
      local foo = 1
   ]])

   it("accepts a level 1 long comment inside a level 2 long comment", util.check [[
      --[=[
         long comment line 1
         --[==[
           long comment within long comment
         ]==]
         long comment line 2
      ]=]
      local foo = 1
   ]])

   it("accepts a level 2 long comment inside a level 1 long comment", util.check [[
      --[==[
         long comment line 1
         --[=[
           long comment within long comment
         ]=]
         long comment line 2
      ]==]
      local foo = 1
   ]])

   it("long comments can contain quotes and double quotes", util.check [=[
      --[[
         ' "
      ]]
      local foo = 1
   ]=])

   it("wrongly nested long comments result in a parse error", util.check_syntax_error([[
      --[==[
         long comment line 1
         --[=[
           long comment within long comment
         ]==]
         long comment line 2
      ]=]
      local foo = 1
   ]], {
      { y = 6, msg = "syntax error" },
      { y = 7, msg = "syntax error" },
   }))

   it("catches unfinished long comment", util.check_syntax_error(
      "print --[[ unfinished long comment\n", {
      { y = 1, msg = "unfinished long comment" },
   }))
end)
