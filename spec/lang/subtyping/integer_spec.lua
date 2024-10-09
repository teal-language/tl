local util = require("spec.util")

describe("subtyping of integer:", function()

   it("integer <╱: nil", util.check_type_error([[
      local n: nil
      n = 42
   ]], {
      { msg = "got integer, expected nil" }
   }))

   it("integer <: any", util.check([[
      local a: any
      a = 42
   ]]))

   it("integer <: unknown", util.lax_check([[
      local function f(unk)
         unk = 42
      end
   ]], {
      "unk"
   }))

   it("integer <╱: string", util.check_type_error([[
      local n: string
      n = 42
   ]], {
      { msg = "got integer, expected string" }
   }))

   it("integer <: number", util.check([[
      local n: number
      n = 42
   ]]))

   it("integer <: integer", util.check([[
      local n: integer
      n = 42
   ]]))

   it("integer <╱: boolean", util.check_type_error([[
      local n: boolean
      n = 42
   ]], {
      { msg = "got integer, expected boolean" }
   }))

   it("integer <╱: thread", util.check_type_error([[
      local c = coroutine.create(function() end)
      c = 42
   ]], {
      { msg = "got integer, expected thread" }
   }))

   it("integer <╱: poly", util.check_type_error([[
      local record R
         poly: function(s: string)
         poly: function(n: integer)
      end

      local r: R = {}
      r.poly = 42
   ]], {
      { msg = "in assignment: cannot match against all alternatives of the polymorphic type" },
   }))

   it("integer <: union including integer", util.check([[
      local u: string | integer
      local i: integer = 42
      u = i
   ]]))

   it("integer <: union including number", util.check([[
      local u: string | number
      local i: integer = 42
      u = i
   ]]))

   it("integer <╱: union not including integer", util.check_type_error([[
      local u: string | boolean
      u = 42
   ]], {
      { msg = "got integer, expected string | boolean" },
   }))

   it("integer <╱: nominal record", util.check_type_error([[
      local record R
      end

      local n: R
      n = 42
   ]], {
      { msg = "got integer, expected R" },
   }))

   it("integer <: nominal type alias for integer", util.check([[
      local type R = integer

      local n: R
      n = 42
   ]]))

   it("integer <╱: enum", util.check_type_error([[
      local enum E
         "a"
         "b"
      end

      local e: E
      e = 42
   ]], {
      { msg = "got integer, expected E" },
   }))

   it("integer <╱: emptytable", util.check_type_error([[
      local et = {}
      et = 42
   ]], {
      { msg = "assigning integer to a variable declared with {}" },
   }))

   it("integer <╱: array", util.check_type_error([[
      local a: {string}
      a = 42
   ]], {
      { msg = "got integer, expected {string}" },
   }))

   it("integer <╱: arrayrecord", util.check_type_error([[
      local record AR
         {integer}
         x: string
      end
      local ar: AR
      ar = 42
   ]], {
      { msg = "got integer, expected AR" },
   }))

   it("integer <╱: map", util.check_type_error([[
      local m: {string:integer}
      m = 42
   ]], {
      { msg = "got integer, expected {string : integer}" },
   }))

   it("integer <╱: record", util.check_type_error([[
      local m = {}
      function m.method()
      end

      m = 42
   ]], {
      { msg = "got integer, expected record" },
   }))

   it("integer <╱: function", util.check_type_error([[
      local f = function()
      end

      f = 42
   ]], {
      { msg = "got integer, expected function" },
   }))
end)
