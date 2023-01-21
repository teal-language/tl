local util = require("spec.util")

describe("binary metamethod __idiv", function()
   describe("with number", function()
      it("can be set on a record", util.check([[
         local type Rec = record
            x: number
            metamethod __idiv: function(Rec, Rec): Rec
         end

         local rec_mt: metatable<Rec>
         rec_mt = {
            __idiv = function(a: Rec, b: Rec): Rec
               local res = setmetatable({} as Rec, rec_mt)
               res.x = a.x // b.x
               return res
            end
         }

         local r = setmetatable({ x = 10 } as Rec, rec_mt)
         local s = setmetatable({ y = 20 } as Rec, rec_mt)

         print((r // s).x)
      ]]))

      it("can be used via the second argument", util.check([[
         local type Rec = record
            x: number
            metamethod __idiv: function(number, Rec): Rec
         end

         local rec_mt: metatable<Rec>
         rec_mt = {
            __idiv = function(a: number, b: Rec): Rec
               local res = setmetatable({} as Rec, rec_mt)
               res.x = a // b.x
               return res
            end
         }

         local s = setmetatable({ y = 20 } as Rec, rec_mt)

         print((10 // s).x)
      ]]))
   end)

   describe("with integer", function()
      it("can be set on a record", util.check([[
         local type Rec = record
            x: integer
            metamethod __idiv: function(Rec, Rec): Rec
         end

         local rec_mt: metatable<Rec>
         rec_mt = {
            __idiv = function(a: Rec, b: Rec): Rec
               local res = setmetatable({} as Rec, rec_mt)
               res.x = a.x // b.x
               return res
            end
         }

         local r = setmetatable({ x = 10 } as Rec, rec_mt)
         local s = setmetatable({ y = 20 } as Rec, rec_mt)

         print((r // s).x)
      ]]))

      it("can be used via the second argument", util.check([[
         local type Rec = record
            x: integer
            metamethod __idiv: function(integer, Rec): Rec
         end

         local rec_mt: metatable<Rec>
         rec_mt = {
            __idiv = function(a: integer, b: Rec): Rec
               local res = setmetatable({} as Rec, rec_mt)
               res.x = a // b.x
               return res
            end
         }

         local s = setmetatable({ y = 20 } as Rec, rec_mt)

         print((10 // s).x)
      ]]))
   end)

end)
