util = require("spec.util")

describe("function calls", function()
   it("does not crash attempting to infer an emptytable when there's no return type", util.check_type_error([[
      local function f()
      end

      local x = {}

      x = f()
   ]], {
      { y = 6, msg = "variable is not being assigned a value" },
   }))
end)
