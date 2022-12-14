local type Rec = record
   x: number
   metamethod __call: function(Rec, string, number): string
   metamethod __add: function(Rec, Rec): Rec
end

local rec_mt: metatable<Rec>
rec_mt = {
   __call = function(self: Rec, s: string, n: number): string
      return tostring(self.x * n) .. s
   end,
   __add = function(a: Rec, b: Rec): Rec
      local res = setmetatable({} as Rec, rec_mt)
      res.x = a.x + b.x
      return res
   end,
}

local r = setmetatable({ x = 10 } as Rec, rec_mt)
local s = setmetatable({ x = 20 } as Rec, rec_mt)

r.x = 12
print(r("!!!", 1000)) -- prints 12000!!!
print((r + s).x)      -- prints 32
