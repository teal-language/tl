local util = require("spec.util")

describe("union argument", function()
   it("reports an invalid type in union", util.check_type_error([[
      local record R
         enum E
            "x"
         end

         f: function(boolean | E)
      end

      R.f = function(a: boolean | E)
      end
   ]], {
      { y = 9, msg = "unknown type E" }
   }))
end)
