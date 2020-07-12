local util = require("spec.util")

describe("nested long strings and comments", function()
   it("long comment within long string", util.check [=[
      local foo = [===[
            long string line 1
            --[[
               long comment within long string
            ]]
            long string line 2
         ]===]
   ]=])

   it("long string within long comment", util.check [=[
      --[===[
         long comment line 1
         [[
            long string within long comment
         ]]
         long comment line 2
      ]===]
      local foo = 1
   ]=])
end)
