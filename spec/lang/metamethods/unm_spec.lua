local util = require("spec.util")

describe("unary metamethod __unm", function()
   it("can be set on a record", util.check([[
      local type Rec = record
         x: number
         metamethod __unm: function(Rec): string
      end

      local rec_mt: metatable<Rec> = {
         __unm = function(self: Rec): string
            return tostring(self.x)
         end
      }

      local r = setmetatable({} as Rec, rec_mt)

      print((-r):upper())
   ]]))

   it("can return arbitrary types", util.check([[
      local type Rec = record
         x: number
         metamethod __unm: function(Rec): Rec
      end

      local rec_mt: metatable<Rec> = {
         __unm = function(self: Rec): Rec
            return self
         end
      }

      local r = setmetatable({} as Rec, rec_mt)

      print((-r).x)
   ]]))
end)
