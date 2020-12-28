local util = require("spec.util")

describe("binary metamethod __add", function()
   it("can be set on a record", util.check [[
      local type Rec = record
         x: number
         metamethod __call: function(Rec, string, number): string
         metamethod __add: function(Rec, Rec): Rec
      end

      local rec_mt: metatable<Rec>
      rec_mt = {
         __call = function(self: Rec, s: string, n: number): string
            return tostring(self.x + n) .. s
         end,
         __add = function(a: Rec, b: Rec): Rec
            local res = setmetatable({} as Rec, rec_mt)
            res.x = a.x + b.x
            return res
         end
      }

      local r = setmetatable({ x = 10 } as Rec, rec_mt)
      local s = setmetatable({ x = 20 } as Rec, rec_mt)

      print((r + s).x)
      print(r("!!!", 34))
   ]])

   it("can be used via the second argument", util.check [[
      local type Rec = record
         x: number
         metamethod __add: function(number, Rec): Rec
      end

      local rec_mt: metatable<Rec>
      rec_mt = {
         __add = function(a: number, b: Rec): Rec
            local res = setmetatable({} as Rec, rec_mt)
            res.x = a + b.x
            return res
         end
      }

      local s = setmetatable({ y = 20 } as Rec, rec_mt)

      print((10 + s).x)
   ]])
end)
