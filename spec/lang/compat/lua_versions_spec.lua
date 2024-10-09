local util = require("spec.util")

describe("Lua version compatibility", function()
   it("generates compat code for // operator", util.gen([[
      local function hello(n: number): number
         return 9
      end

      local x = 124 // 3
      local x = hello(12) // hello(hello(12) // 12)
   ]], [[
      local function hello(n)
         return 9
      end

      local x = math.floor(124 / 3)
      local x = math.floor(hello(12) / hello(math.floor(hello(12) / 12)))
   ]], "5.1"))

   it("generates compat code for bitwise operators", util.gen([[


      local c = 0xcafebabe
      local x = 2 & (c >> ~4 | 0xff)
   ]], [[
      local bit32 = bit32; if not bit32 then local p, m = pcall(require, 'bit32'); if p then bit32 = m end end

      local c = 0xcafebabe
      local x = bit32.band(2, (bit32.bor(bit32.rshift(c, bit32.bnot(4)), 0xff)))
   ]], "5.1"))

   it("generates compat code for bitwise unary operator metamethods", util.gen([[

      local type Rec = record
         x: number
         metamethod __bnot: function(Rec): number
      end

      local rec_mt: metatable<Rec> = {
         __bnot = function(self: Rec): number
            return -self.x
         end
      }

      local r = setmetatable({} as Rec, rec_mt)

      print((~r) * 2)
   ]], [[
      local _tl_mt = function(m, s, a, b)    return (getmetatable(s == 1 and a or b)[m](a, b)) end





      local rec_mt = {
         __bnot = function(self)
            return -self.x
         end,
      }

      local r = setmetatable({}, rec_mt)

      print((_tl_mt("__bnot", 1, r)) * 2)
   ]], "5.1"))

   it("generates compat code for bitwise binary operator metamethods", util.gen([[

      local type Rec = record
         x: number
         metamethod __shl: function(Rec, Rec): number
      end

      local rec_mt: metatable<Rec> = {
         __shl = function(a: Rec, b: Rec): number
            return a.x + b.x
         end
      }

      local r = setmetatable({} as Rec, rec_mt)
      local s = setmetatable({} as Rec, rec_mt)

      print(r << s)
   ]], [[
      local _tl_mt = function(m, s, a, b)    return (getmetatable(s == 1 and a or b)[m](a, b)) end





      local rec_mt = {
         __shl = function(a, b)
            return a.x + b.x
         end,
      }

      local r = setmetatable({}, rec_mt)
      local s = setmetatable({}, rec_mt)

      print(_tl_mt("__shl", 1, r, s))
   ]], "5.1"))
end)
