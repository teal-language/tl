local util = require("spec.util")

describe("unary metamethod __tostring", function()
   it("can be set on a record", util.check([[
      local type Rec = record
         x: number
         metamethod __tostring: function(Rec): string
      end

      local rec_mt: metatable<Rec>
      rec_mt = {
         __tostring = function(self: Rec): string
            return "Rec {x: " .. tostring(self.x) .. "}"
         end,
      }

      local r = setmetatable({ x = 10 } as Rec, rec_mt)
      print(r)
   ]]))

   it("can be used on a record prototype", util.check([[
      local record A
         value: number
         metamethod __tostring: function(A): string
      end
      local A_mt: metatable<A>
      A_mt = {
         __tostring = function(a: A): string
            return "A { value: " .. tostring(a.value) .. " }"
         end,
      }

      A.value = 10
      print(A)
   ]]))
end)
