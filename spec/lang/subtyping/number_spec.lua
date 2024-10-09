local util = require("spec.util")

describe("subtyping of number:", function()

   it("number <╱: nil", util.check_type_error([[
      local n: nil
      n = 1.5
   ]], {
      { msg = "got number, expected nil" }
   }))

   it("number <: any", util.check([[
      local a: any
      a = 1.5
   ]]))

   it("number <: unknown", util.lax_check([[
      local function f(unk)
         unk = 1.5
      end
   ]], {
      "unk"
   }))

   it("number <╱: string", util.check_type_error([[
      local n: string
      n = 1.5
   ]], {
      { msg = "got number, expected string" }
   }))

   it("number <: number", util.check([[
      local n: number
      n = 1.5
   ]]))

   it("number <╱: integer", util.check_type_error([[
      local n: integer
      n = 1.5
   ]], {
      { msg = "got number, expected integer" }
   }))

   it("number <╱: boolean", util.check_type_error([[
      local n: boolean
      n = 1.5
   ]], {
      { msg = "got number, expected boolean" }
   }))

   it("number <╱: thread", util.check_type_error([[
      local c = coroutine.create(function() end)
      c = 1.5
   ]], {
      { msg = "got number, expected thread" }
   }))

   it("number <╱: poly", util.check_type_error([[
      local record R
         poly: function(s: string)
         poly: function(n: number)
      end

      local r: R = {}
      r.poly = 1.5
   ]], {
      { msg = "in assignment: cannot match against all alternatives of the polymorphic type" },
   }))

   it("number <: union including number", util.check([[
      local u: string | number
      u = 1.5
   ]]))

   it("number <╱: union not including number", util.check_type_error([[
      local u: string | integer
      u = 1.5
   ]], {
      { msg = "got number, expected string | integer" },
   }))

   it("number <╱: nominal record", util.check_type_error([[
      local record R
      end

      local n: R
      n = 1.5
   ]], {
      { msg = "got number, expected R" },
   }))

   it("number <: nominal type alias for number", util.check([[
      local type R = number

      local n: R
      n = 1.5
   ]]))

   it("number <╱: enum", util.check_type_error([[
      local enum E
         "a"
         "b"
      end

      local e: E
      e = 1.5
   ]], {
      { msg = "got number, expected E" },
   }))

   it("number <╱: emptytable", util.check_type_error([[
      local et = {}
      et = 1.5
   ]], {
      { msg = "assigning number to a variable declared with {}" },
   }))

   it("number <╱: array", util.check_type_error([[
      local a: {string}
      a = 1.5
   ]], {
      { msg = "got number, expected {string}" },
   }))

   it("number <╱: arrayrecord", util.check_type_error([[
      local record AR
         {number}
         x: string
      end
      local ar: AR
      ar = 1.5
   ]], {
      { msg = "got number, expected AR" },
   }))

   it("number <╱: map", util.check_type_error([[
      local m: {string:number}
      m = 1.5
   ]], {
      { msg = "got number, expected {string : number}" },
   }))

   it("number <╱: record", util.check_type_error([[
      local m = {}
      function m.method()
      end

      m = 1.5
   ]], {
      { msg = "got number, expected record" },
   }))

   it("number <╱: function", util.check_type_error([[
      local f = function()
      end

      f = 1.5
   ]], {
      { msg = "got number, expected function" },
   }))
end)
