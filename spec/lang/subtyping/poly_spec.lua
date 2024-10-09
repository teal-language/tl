local util = require("spec.util")

describe("subtyping of poly:", function()

   it("t1 poly <: t2 if ∃ t in t1, t <: t2", util.check([[
      local record T1
         poly: function(s: string)
         poly: function(n: number)
      end
      local r: T1

      local t1 = r.poly
      local t2: function(s: string)

      -- ∃ t in t1, t <: t2
      -- ──────────────────   -- a type t1 is a poly if
      --   t1 poly <: t2      -- t1 is some of of the poly's types
      t2 = t1
   ]]))

   it("t1 poly <╱: t2 if ¬∃ t in t1, t <: t2", util.check_type_error([[
      local record T1
         poly: function(s: string)
         poly: function(n: number)
      end
      local r: T1

      local t1 = r.poly
      local t2: function(b: boolean)

      -- ∃ t in t1, t <: t2
      -- ──────────────────   -- a type t1 is a poly if
      --   t1 poly <: t2      -- t1 is some of of the poly's types
      t2 = t1

      -- trivial example
      local s: string = t1
   ]], {
      { y = 13, msg = "cannot match against any alternatives of the polymorphic type" },
      { y = 16, msg = "cannot match against any alternatives of the polymorphic type" },
   }))

   it("t1 <: t2 poly if ∀ t in t2, t1 <: t", util.check([[
      local record T1
         two: function(s: string)
         two: function(n: number)

         three: function(s: string)
         three: function(n: number)
         three: function(b: boolean)
      end
      local r: T1

      local two = r.two
      local three = r.three

      -- ∀ t in t2, t1 <: t
      -- ──────────────────   -- a type t1 is a poly type t2
      --   t1 <: t2 poly      -- if all of t2's poly types are satisfied by t1
      two = three
   ]]))

   it("t1 <╱: t2 poly if ¬∀ t in t2, t1 <: t", util.check_type_error([[
      local record T1
         two: function(s: string)
         two: function(n: number)

         three: function(s: string)
         three: function(n: number)
         three: function(b: boolean)
      end
      local r: T1

      local two = r.two
      local three = r.three

      -- ∀ t in t2, t1 <: t
      -- ──────────────────   -- a type t1 is a poly type t2
      --   t1 <: t2 poly      -- if all of t2's poly types are satisfied by t1
      three = two

      -- trivial example
      local s: string
      three = s
   ]], {
      { y = 17, msg = "cannot match against all alternatives of the polymorphic type" },
      { y = 21, msg = "cannot match against all alternatives of the polymorphic type" },
   }))

end)
