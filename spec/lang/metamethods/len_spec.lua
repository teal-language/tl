local util = require("spec.util")

describe("unary metamethod __len", function()
   it("can be set on a record", util.check([[
      local type Rec = record
         x: number
         metamethod __len: function(Rec): string
      end

      local rec_mt: metatable<Rec> = {
         __len = function(self: Rec): string
            return tostring(self.x)
         end
      }

      local r = setmetatable({} as Rec, rec_mt)

      print((#r):upper())
   ]]))

   it("checks the type of self in the metatable", util.check_type_error([[
      local record Test
         metamethod __len: function(Test): number
      end

      local test_mt: metatable<Test> = {
         __len = function(self: number): number
            return self
         end
      }

      local test: Test = setmetatable({}, test_mt)
      print(#test)
   ]], {
      { msg = "__len: argument 1: got number, expected Test" },
   }))

   it("can return arbitrary types", util.check([[
      local type Rec = record
         x: number
         metamethod __len: function(Rec): Rec
      end

      local rec_mt: metatable<Rec> = {
         __len = function(self: Rec): Rec
            return self
         end
      }

      local r = setmetatable({} as Rec, rec_mt)

      print((#r).x)
   ]]))
end)
