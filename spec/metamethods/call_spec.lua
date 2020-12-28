local util = require("spec.util")

describe("metamethod __call", function()
   it("can be set on a record", util.check [[
      local type Rec = record
         x: number
         metamethod __call: function(Rec, string, number): string
      end

      local rec_mt: metatable<Rec> = {
         __call = function(self: Rec, s: string, n: number): string
            return tostring(self.x + n) .. s
         end
      }

      local r = setmetatable({} as Rec, rec_mt)

      r.x = 12
      print(r("!!!", 34))
   ]])

   it("can type check arguments and argument count skips self", util.check_type_error([[
      local type Rec = record
         x: number
         metamethod __call: function(Rec, string, number): string
      end

      local rec_mt: metatable<Rec> = {
         __call = function(self: Rec, s: string, n: number): string
            return tostring(self.x + n) .. s
         end
      }

      local r = setmetatable({} as Rec, rec_mt)

      r.x = 12
      print(r("!!!", r))
   ]], {
      { msg = "argument 2: got Rec, expected number" },
   }))

   it("cannot be typechecked if the metamethod is not defined in the record", util.check_type_error([[
      local type Rec = record
         x: number
      end

      local rec_mt: metatable<Rec> = {
         __call = function(self: Rec, s: string): string
            return tostring(self.x) .. s
         end
      }

      -- this is not sufficient to tell the compiler that r supports __call,
      -- because setmetatable is a dynamic operation.
      local r = setmetatable({} as Rec, rec_mt)

      r.x = 12
      print(r("!!!"))
   ]], {
      { msg = "not a function" }
   }))

   -- this is failing because the definition and implementations are not being cross-checked
   -- this causes the test to output an error on line 15, because the call doesn't match the
   -- metamethod definition inside Rec.
   pending("record definition and implementations must match their types", util.check_type_error([[
      local type Rec = record
         x: number
         metamethod __call: function(Rec, number, number): string
      end

      local rec_mt: metatable<Rec> = {
         __call = function(self: Rec, s: string): string
            return tostring(self.x) .. s
         end
      }

      local r = setmetatable({} as Rec, rec_mt)

      r.x = 12
      print(r("!!!"))
   ]], {
      { y = 7, msg = "in assignment: argument 2: got string, expected number" }
   }))
end)
