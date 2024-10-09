local util = require("spec.util")

describe("unary metamethod __bnot", function()
   it("can be set on a record", util.check([[
      local type Rec = record
         x: number
         metamethod __bnot: function(Rec): string
      end

      local rec_mt: metatable<Rec> = {
         __bnot = function(self: Rec): string
            return tostring(self.x)
         end
      }

      local r = setmetatable({} as Rec, rec_mt)

      print((~r):upper())
   ]]))

   it("can return arbitrary types", util.check([[
      local type Rec = record
         x: number
         metamethod __bnot: function(Rec): Rec
      end

      local rec_mt: metatable<Rec> = {
         __bnot = function(self: Rec): Rec
            return self
         end
      }

      local r = setmetatable({} as Rec, rec_mt)

      print((~r).x)
   ]]))
end)
