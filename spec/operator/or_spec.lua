local util = require("spec.util")

describe("or", function()
   it("map or record matching map", util.check [[
      local Ty = record
         name: string
         foo: number
      end
      local t: Ty = { name = "bla" }
      local m1: {string:Ty} = {}
      local m2: {string:Ty} = m1 or { foo = t }
   ]])

   it("string or enum matches enum", util.check [[
      local Dir = enum
         "left"
         "right"
      end

      local v: Dir = "left"
      local x: Dir = v or "right"
      local y: Dir = "right" or v
   ]])

   it("invalid string or enum matches string", util.check_type_error([[
      local Dir = enum
         "left"
         "right"
      end

      local v: Dir = "left"
      local x = v or "don't know"
      v = x
   ]], {
      { y = 8, msg = "in assignment: string is not a Dir" }
   }))
end)
