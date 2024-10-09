local util = require("spec.util")

describe("subtyping of union:", function()

   it("t1 <: t2 union if ∃ t in t2, t1 <: t", util.check([[
      local record T1
         poly: function(s: string)
         poly: function(n: number)
      end
      local r: T1

      local t1 = r.poly
      local u2: function(s: string)

      -- t1 <: u2, t1 ~= u2
      u2 = t1

      local t2: function(s: string) | number

      -- ∃ t in t2, t1 <: t   -- (t == u2)
      -- ──────────────────
      --   t1 <: t2 union
      t2 = t1
   ]]))

   it("t1 <╱: t2 union if ¬∃ t in t2, t1 <: t", util.check_type_error([[
      local record T1
         poly: function(s: string)
         poly: function(n: number)
      end
      local r: T1

      local t1 = r.poly
      local u2: function(s: string)

      -- t1 <: u2
      u2 = t1

      local t2: function(b: boolean) | number

      -- ∃ t in t2, t1 <: t   -- (t == u2)
      -- ──────────────────
      --   t1 <: t2 union
      t2 = t1
   ]], {
      { y = 18, msg = "expected function(boolean) | number" },
   }))

   it("t1 union <: t2 if ∀ t in t1, t <: t2", util.check([[
      local record AR
         {number}
         x: string
      end

      local u1: AR
      local u2: {number}

      -- u1 <: u2, u1 ~= u2
      u2 = u1

      local t1: AR | string
      local t2: {number} | string

      -- ∀ t in t1, t <: t2
      -- ──────────────────
      --   t1 <: t2 union
      t2 = t1
   ]]))

   it("t1 union <╱: t2 if ¬∀ t in t1, t <: t2", util.check_type_error([[
      local record AR
         {boolean}
         x: string
      end

      local u1: AR
      local u2: {number}

      -- u1 <: u2, u1 ~= u2
      u2 = u1

      local t1: AR | string
      local t2: {number} | string

      -- ∀ t in t1, t <: t2
      -- ──────────────────
      --   t1 <: t2 union
      t2 = t1
   ]], {
      { y = 10, msg = "got AR, expected {number}" },
      { y = 18, msg = "got AR | string, expected {number} | string" },
   }))

   it("t1 union <: t2 union if ∀ t in t1, ∃ u in t2 t <: u (regression test for #507)", util.check([[
      local record Rec<T>
          value: T | string
          new: (function(Rec<T>, T): Rec<T>)
      end

      function Rec:new<T>(value: T): Rec<T>
          return setmetatable({value=value} as Rec<T>, {__index = self})
      end

      local a = Rec:new(nil)
      local b = Rec:new(10)
   ]]))

   it("a potentially more idiomatic rendition of the code from #507", util.check([[
      local record Rec<T>
        value: T | string
        new: function<T>(T): Rec<T>
      end

      function Rec.new<T>(v: T): Rec<T>
        return setmetatable({value = v} as Rec<T>, {__index = Rec})
      end

      local a = Rec.new(nil)
      local b = Rec.new(10)
   ]]))

end)
