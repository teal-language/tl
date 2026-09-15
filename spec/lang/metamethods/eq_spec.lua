local util = require("spec.util")

describe("binary metamethod __eq", function()
   it("type checks the metamethod call with ==", util.check_type_error([[
      local record Rec
         x: number
         metamethod __eq: function(Rec, number): boolean
      end

      local a: Rec = { x = 1 }
      local b: Rec = { x = 2 }

      print(a == b)
   ]], {
      { y = 9, msg = "argument 2: got Rec, expected number" },
   }))

   it("type checks the metamethod call with ~=", util.check_type_error([[
      local record Rec
         x: number
         metamethod __eq: function(Rec, number): boolean
      end

      local a: Rec = { x = 1 }
      local b: Rec = { x = 2 }

      print(a ~= b)
   ]], {
      { y = 9, msg = "argument 2: got Rec, expected number" },
   }))
end)
